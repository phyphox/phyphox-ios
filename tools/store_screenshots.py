#!/usr/bin/env python3
"""Capture the App Store screenshots, from the shipped experiments.

The iOS half of the store release system described in the working root's
STORE-RELEASE-PLAN.md. The shared half - which six scenes, what data they show,
which locale maps to which store listing, and how a scene's experiment file is
built - lives in the sibling phyphox-docs checkout, because Android needs
exactly the same answers. The Android counterpart is
phyphox-android/tools/store_screenshots.py; read it before changing anything
here, most of what it knows was learned the hard way.

    tools/store_screenshots.py --form-factor iphone --build
    tools/store_screenshots.py --form-factor iphone \
        --languages en,de --scenes accelerometer,strobe      # a quick look

What it does per simulator, in this order, and why each step is there:

1.  Creates (once) and boots a simulator of its own, named phyphox-shot-*. Not
    "whatever is booted": another session on this machine has its own
    simulators, and Apple's required sizes are exactly two device types.
2.  Installs the app, grants camera, microphone, motion and location, and
    overrides the status bar to 9:41 with a full battery.
3.  For each language and scene: composes the scene's experiment file from the
    CURRENT shipped collection, serves it over HTTP, launches the app at it,
    waits for the view to settle, and captures.
4.  Composites the camera preview into the one scene that needs it (plan 6.1).

The device never runs the remote interface: its banner would be in every
screenshot. That is why the recorded data is baked into the experiment file as
init values rather than pushed in with /set.

**Almost nothing here needs the app's own UI.** Everything Android has to walk a
menu for - the theme, the damage warning, the two hint bubbles - is a
UserDefaults key on iOS, and a launch argument of the form `-<key> <value>`
lands in NSArgumentDomain, which outranks every stored value for that launch
only. So each capture states the state it wants instead of inheriting whatever
the previous one left behind, and no coordinate or localized label is ever
matched. The keys are listed in LAUNCH_DEFAULTS below.

Dependencies: lxml, PyYAML and Pillow. Keep them in a virtualenv outside the
(synced) working root, e.g.

    python3 -m venv ~/.venvs/phyphox-screenshots
    ~/.venvs/phyphox-screenshots/bin/pip install lxml pyyaml pillow
    ~/.venvs/phyphox-screenshots/bin/python tools/store_screenshots.py ...
"""

import argparse
import json
import os
import plistlib
import shutil
import struct
import subprocess
import sys
import threading
import time
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
DOCS = os.path.normpath(os.path.join(REPO, "..", "phyphox-docs"))
COLLECTION = os.path.join(REPO, "phyphox-experiments")
PROJECT = os.path.join(REPO, "phyphox-iOS", "phyphox.xcodeproj")
BUILD = os.path.join(REPO, "build", "screenshots")
# The working root's screenshots/ios/<app-store-locale>/, which is not a
# repository: the App Store is API-only, so unlike Android's F-Droid half
# nothing of this is committed anywhere.
METADATA = os.path.normpath(os.path.join(REPO, "..", "screenshots", "ios"))
BUNDLE_ID = "de.rwth-aachen.physics.phyphox"
PORT = 8099

# Apple requires exactly two sizes; App Store Connect scales everything else
# down from them. The resolutions are checked against a real capture before the
# run starts, because a device type that renders at another size would produce
# an upload the store rejects at the very end of a two-hour run.
FORM_FACTORS = {
    "iphone": {
        "device_type": "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max",
        "size": (1320, 2868),
        "scale": 3,
        "simulator": "phyphox-shot-phone",
        "note": '6.9" iPhone',
    },
    "ipad": {
        "device_type": "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB",
        "size": (2064, 2752),
        "scale": 2,
        "simulator": "phyphox-shot-ipad",
        "note": '13" iPad',
    },
}

# The app's own layout constants, in points (CameraUIView: spacing, sideMargins).
# The composite reproduces the box the preview is laid out in, so `scale` above
# has to be the device's point scale - the two form factors are 3x and 2x.
CAMERA_SPACING = 10.0

# UserDefaults keys the app reads, set per launch through NSArgumentDomain so a
# capture never depends on what an earlier one stored. Values that do not
# change between scenes; the theme is added per scene.
#
#   donotshowagain                     the "do not damage your phone" alert on
#                                      the collection (ExperimentsCollection-
#                                      ViewController, viewDidLoad)
#   supportHintVersion                 the tooltip pointing at the support
#                                      entries. It shows while the app's
#                                      version equals the hardcoded
#                                      phyphoxCatHintRelease AND this key does
#                                      not, so passing the BUILT BUNDLE's
#                                      CFBundleShortVersionString settles it
#                                      either way: equal to the constant, and
#                                      the hint is marked seen; not equal, and
#                                      there was no hint to begin with.
#   experiment_start_hint_dismiss_count,
#   experiment_info_hint_dismiss_count the two bubbles on the experiment
#                                      screen, shown until dismissed three
#                                      times (ExperimentPageViewController,
#                                      presentNextHint)
LAUNCH_DEFAULTS = {
    "donotshowagain": "YES",
    "experiment_start_hint_dismiss_count": "3",
    "experiment_info_hint_dismiss_count": "3",
}

# appModeKey, the app's own dark/light setting - "1" dark (the default),
# "2" light, "3" follow the system (Utility.swift, SettingsBundleHelper).
APP_MODE = {"dark": "1", "light": "2"}


def sh(*args, check=True):
    r = subprocess.run(args, capture_output=True, text=True)
    if check and r.returncode:
        raise RuntimeError(f"{' '.join(args)}\n{r.stdout}{r.stderr}")
    return r.stdout


def simctl(*args, **kw):
    return sh("xcrun", "simctl", *args, **kw)


def png_size(data):
    """(width, height) of a complete PNG, or None if these bytes are not one.

    Both halves matter. `simctl io screenshot` writes what it managed to
    produce, and a simulator that died mid-capture leaves a truncated file that
    only fails much later - when something opens it, or worse, when the store
    does.
    """
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[-8:-4] != b"IEND":
        return None
    return struct.unpack(">II", data[16:24])


class Simulator:
    def __init__(self, udid):
        self.udid = udid

    def simctl(self, *args, **kw):
        return simctl(*args[:1], self.udid, *args[1:], **kw)

    def screenshot(self, path, expect=None, tries=3):
        """Capture, and refuse to write anything that is not a whole PNG of the
        expected size."""
        tmp = os.path.join(BUILD, "_shot.png")
        for attempt in range(tries):
            data = b""
            r = subprocess.run(
                ["xcrun", "simctl", "io", self.udid, "screenshot", "--type", "png", tmp],
                capture_output=True, text=True)
            if r.returncode == 0 and os.path.exists(tmp):
                with open(tmp, "rb") as f:
                    data = f.read()
            size = png_size(data)
            if size and (expect is None or size == tuple(expect)):
                os.makedirs(os.path.dirname(path), exist_ok=True)
                with open(path, "wb") as f:
                    f.write(data)
                return
            print(f"    incomplete or wrong-sized capture ({len(data)} bytes, "
                  f"{size}), retrying")
            time.sleep(3)
        raise RuntimeError(
            f"could not capture {os.path.basename(path)}: got {len(data)} bytes "
            f"that are not a complete {expect} PNG. The simulator is probably "
            f"gone - check `xcrun simctl list devices booted`.")

    def size(self):
        tmp = os.path.join(BUILD, "_probe.png")
        os.makedirs(BUILD, exist_ok=True)
        self.simctl("io", "screenshot", "--type", "png", tmp)
        with open(tmp, "rb") as f:
            return png_size(f.read())

    def installed_stamp(self):
        """Where the installed bundle lives and when it was written.

        Checked again during the run: another session on this machine can
        install over us - `xcodebuild test` and any `simctl install` reach a
        simulator by udid, and nothing warns when one is replaced - and the
        plates from that point on would show a different build.
        """
        try:
            path = self.simctl("get_app_container", BUNDLE_ID, "app").strip()
        except RuntimeError:
            return None
        info = os.path.join(path, "Info.plist")
        return f"{path}@{os.path.getmtime(info)}" if os.path.exists(info) else path


def create_or_find(name, device_type):
    """The named simulator, created on first use.

    A simulator of our own rather than whatever is booted: this machine also
    runs the test suite and the T1 driver, and Apple's two required sizes are
    two specific device types anyway.
    """
    devices = json.loads(simctl("list", "devices", "--json"))["devices"]
    for runtime, entries in devices.items():
        for d in entries:
            if d["name"] == name and d.get("isAvailable"):
                return d["udid"]
    runtimes = [r for r in json.loads(simctl("list", "runtimes", "--json"))["runtimes"]
                if r["isAvailable"] and r["identifier"].startswith(
                    "com.apple.CoreSimulator.SimRuntime.iOS-")]
    if not runtimes:
        raise RuntimeError("no iOS simulator runtime is installed")
    newest = sorted(runtimes, key=lambda r: [int(p) for p in r["version"].split(".")])[-1]
    print(f"  creating simulator {name} ({newest['name']})")
    return simctl("create", name, device_type, newest["identifier"]).strip()


def boot(udid, timeout=300):
    simctl("boot", udid, check=False)
    r = subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"],
                       capture_output=True, text=True, timeout=timeout)
    if r.returncode:
        raise RuntimeError(f"simulator {udid} did not boot:\n{r.stdout}{r.stderr}")
    return Simulator(udid)


def build_app():
    """Build the Release configuration for the simulator, from this checkout.

    Release rather than Debug on principle - it is what users get - and it is
    cheap here: nothing in the app branches on the configuration. Code signing
    is off because a simulator does not check it.

    There is deliberately no --ref: the scenes are composed from the experiment
    collection in THIS working tree, so building another commit while composing
    this tree's experiments would photograph two versions at once. Check the
    tree out where you want it and build from there.
    """
    print("  building the Release configuration")
    sh("xcodebuild", "-project", PROJECT, "-scheme", "phyphox",
       "-configuration", "Release", "-destination", "generic/platform=iOS Simulator",
       "-derivedDataPath", os.path.join(BUILD, "dd"),
       "CODE_SIGNING_ALLOWED=NO", "build")
    return last_built_app()


def last_built_app():
    app = os.path.join(BUILD, "dd", "Build", "Products",
                       "Release-iphonesimulator", "phyphox.app")
    return app if os.path.exists(app) else None


def app_version(app):
    with open(os.path.join(app, "Info.plist"), "rb") as f:
        return plistlib.load(f).get("CFBundleShortVersionString", "")


def has_seams(app):
    """Whether this build carries the automation launch arguments.

    Cheap guard against the failure that would otherwise be found only by
    looking at the plates afterwards and noticing that the audio spectrum is on
    the wrong tab and half the collection is greyed out.

    Only -phyphoxAssumeSensors is looked for, and that is not laziness:
    a Swift literal of fifteen bytes or fewer is encoded inside the
    instructions rather than stored as a string, so "-phyphoxView" and
    "-phyphoxUrl" are simply not in the binary as text. Both arrived in the
    same commit as the flag below (4e9eabe2), which is what makes it a usable
    stand-in for all three.
    """
    with open(os.path.join(app, "phyphox"), "rb") as f:
        return b"-phyphoxAssumeSensors" in f.read()


class SceneServer(ThreadingHTTPServer):
    """Serves the composed experiments, and remembers what was fetched.

    The record is a check, not a log: if the app never asked for the scene
    file, it never opened it, and whatever is on the screen is not the scene -
    most likely because the launch arguments went to an already running process
    (see --terminate-running-process below).
    """
    fetched = None

    def note(self, path):
        self.fetched.add(path.lstrip("/"))


class SceneHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        self.server.note(self.path)
        return super().do_GET()

    def log_message(self, *args):
        pass


def serve(directory):
    handler = partial(SceneHandler, directory=directory)
    httpd = SceneServer(("127.0.0.1", PORT), handler)
    httpd.fetched = set()
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return httpd


def prepare(sim, app):
    """Everything that has to be true before the first capture."""
    print(f"  installing {os.path.basename(app)}")
    sim.simctl("install", app)
    # The camera is granted even though the simulator has no camera: with the
    # permission denied the app puts up its own "camera required" alert, which
    # nothing here can dismiss. Granted, AVFoundation still finds no device and
    # -phyphoxAssumeSensors keeps the resulting loading error off the screen,
    # leaving the empty preview rectangle the composite fills in.
    for service in ("camera", "microphone", "motion", "location"):
        sim.simctl("privacy", "grant", service, BUNDLE_ID, check=False)
    status_bar(sim)
    return sim.installed_stamp()


def status_bar(sim, on=True):
    """A store status bar: 9:41, full battery with no charging bolt, full bars."""
    if not on:
        sim.simctl("status_bar", "clear", check=False)
        return
    sim.simctl("status_bar", "override",
               "--time", "9:41",
               "--dataNetwork", "wifi", "--wifiMode", "active", "--wifiBars", "3",
               "--cellularMode", "active", "--cellularBars", "4",
               # "charged" draws a bolt through the battery; a full battery that
               # is simply not charging is the cleaner picture and is what the
               # Android side shows.
               "--batteryState", "discharging", "--batteryLevel", "100",
               check=False)


def check_still_ours(sim, stamp):
    now = sim.installed_stamp()
    if stamp and now and now != stamp:
        raise RuntimeError(
            f"the app was reinstalled while this run was capturing\n  {stamp}\n"
            f"  -> {now}\nAnother session on this machine probably installed "
            f"over it, so the plates from here on would show a different "
            f"build. Re-run when the simulator is yours alone.")


def launch(sim, scene, language, theme, view, version, url=None):
    # --terminate-running-process has to come before the udid, and it is not
    # optional: launching onto an already running app delivers no new arguments
    # at all, so the previous scene would stay on screen.
    args = ["launch", "--terminate-running-process", sim.udid, BUNDLE_ID,
            # Every capture states its own state instead of inheriting the last
            # one's: these all land in NSArgumentDomain, which outranks anything
            # the app has stored, and only for this launch.
            "-AppleLanguages", f"({language})",
            "-AppleLocale", language.replace("-", "_"),
            "-appModeKey", APP_MODE[theme],
            "-supportHintVersion", version,
            "-phyphoxAssumeSensors", "-phyphoxAutoConfirm",
            "-phyphoxView", str(view)]
    for key, value in LAUNCH_DEFAULTS.items():
        args += [f"-{key}", value]
    if url:
        args += ["-phyphoxUrl", url]
    simctl(*args)


def store_locales(row):
    """The App Store listings one app language feeds. Usually one.

    Portuguese is one language in the app and two listings on both stores,
    knowingly given the same translation - so it gets the same screenshots,
    captured once and written to each.
    """
    ios = row["ios"]
    return ios if isinstance(ios, list) else [ios]


ORANGE = (255, 126, 34)


def check_screen(path, kind):
    """Refuse a plate that is not showing what the scene asked for.

    The app's navigation bar is solid orange behind the status bar on an
    experiment screen and absent on the collection, in both themes and every
    language, so the top of the picture decides which of the two we are looking
    at. It catches the failure that matters here: an experiment that did not
    load, or loaded and bounced back to the collection, which otherwise produces
    six plausible-looking plates of the wrong screen per language.

    Measured over the top TWENTIETH of the picture rather than a thin band at a
    fixed height, which is what the first version did: the bar is a different
    height on the two form factors, so a band chosen to sit inside it on the
    phone only clipped its lower edge on the iPad. Over the whole top twentieth
    the two screens are 62-78% orange against 0.00%, on both form factors, in
    both themes.
    """
    from PIL import Image
    im = Image.open(path).convert("RGB")
    w, h = im.size
    band = im.crop((0, 0, w, int(0.05 * h)))
    counts = dict((c, n) for n, c in (band.getcolors(1 << 20) or []))
    orange = counts.get(ORANGE, 0) / (band.width * band.height)
    if kind == "collection" and orange > 0.02:
        raise RuntimeError(f"{os.path.basename(path)}: the collection screenshot "
                           f"shows an experiment's navigation bar ({orange:.0%} "
                           f"orange in the top band)")
    if kind != "collection" and orange < 0.4:
        raise RuntimeError(
            f"{os.path.basename(path)}: no experiment navigation bar ({orange:.0%} "
            f"orange in the top band). The experiment did not open, or it opened "
            f"and returned to the collection.")


def preview_band(im):
    """The camera preview rectangle: the topmost tall run of blank rows.

    On a simulator that rectangle is simply an empty area of the app's
    background colour, so it is found in the picture rather than hardcoded per
    form factor - a layout change then moves the composite with it instead of
    pasting a photograph over the graph.

    Topmost rather than tallest, which is what the first version did and what
    the iPad caught: an experiment that does not fill a 13" screen leaves a
    larger blank area BELOW its last element than the preview rectangle is, so
    "tallest" pasted the photograph under the description text. Everything
    above the preview is a graph or text, none of which produces a run of
    identical full-width rows anywhere near this tall.
    """
    w, h = im.size
    px = im.load()
    bands = []
    start, colour = None, None
    for y in range(h + 1):
        row = None
        if y < h:
            first = px[0, y]
            if all(px[x, y] == first for x in range(1, w, 3)):
                row = first
        if row is not None and row == colour:
            continue
        if colour is not None and y - start >= 0.12 * h and start >= 0.2 * h:
            bands.append((start, y - 1, colour))
        start, colour = y, row
    return bands[0] if bands else None


def composite_camera(path, asset, point_scale):
    """Paste a real camera preview into the empty preview rectangle.

    The iOS simulator has no camera at all, so that one rectangle is the only
    part of the six screenshots the app did not draw (plan 6.1). The image is
    the Android capture's own preview, so both stores show the same scene and
    nothing was invented.

    Where it goes is the app's own rule rather than "the whole blank area",
    which is what the first version did and what it looked like - the preview
    touching the label above it and the description below. CameraUIView lays the
    preview out inside a box inset from the element: the header sits at
    `spacing` with the box starting `spacing` below it, the box ends
    `3 * spacing` above the element's lower edge, and the frame is aspect-fitted
    and centred in what is left (`layoutSubviews`, metalView). So the blank band
    found in the picture is inset by the same margins before fitting.

    The aspect is the ASSET'S, not a number from here. On a device the app fits
    the selected capture format, which its own format picker calls "probably
    always 4:3 anyway" (CameraService.setBestInputFormat); the Android frame is
    505x652, i.e. 3:4 within three percent. Fitting the image as it is keeps it
    undistorted, which matters more than the last three percent of width.
    """
    from PIL import Image
    im = Image.open(path).convert("RGB")
    band = preview_band(im)
    if not band:
        raise RuntimeError(
            f"{os.path.basename(path)}: no empty band tall enough to be the "
            f"camera preview. Either the layout changed or the app drew "
            f"something there - do not composite blind.")
    band_top, band_bottom, _ = band
    margin = CAMERA_SPACING * point_scale
    top = round(band_top + margin)
    bottom = round(band_bottom - 3 * margin)
    box_w, box_h = im.size[0] - 2 * round(margin), bottom - top + 1
    preview = Image.open(asset).convert("RGB")
    scale = min(box_w / preview.size[0], box_h / preview.size[1])
    size = (round(preview.size[0] * scale), round(preview.size[1] * scale))
    preview = preview.resize(size, Image.LANCZOS)
    im.paste(preview, ((im.size[0] - size[0]) // 2, top + (box_h - size[1]) // 2))
    im.save(path)
    return (top, bottom)


def main():
    # A full run is 120 captures over an hour or two; with stdout redirected to
    # a log, block buffering would show nothing until it ended.
    try:
        sys.stdout.reconfigure(line_buffering=True)
    except AttributeError:
        pass

    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--form-factor", required=True, choices=sorted(FORM_FACTORS))
    ap.add_argument("--udid", help="an existing simulator to use instead of the "
                                   "phyphox-shot-* one this creates")
    ap.add_argument("--app", help="the .app to photograph; default: whatever "
                                  "--build produced")
    ap.add_argument("--build", action="store_true",
                    help="build the Release configuration from the CURRENT checkout")
    ap.add_argument("--languages", help="comma separated app language tags "
                                        "(default: all of them)")
    ap.add_argument("--scenes", help="comma separated scene ids (default: all)")
    ap.add_argument("--out", default=METADATA)
    ap.add_argument("--keep-simulator", action="store_true")
    args = ap.parse_args()

    if not os.path.isdir(DOCS):
        sys.exit(f"phyphox-docs is not checked out at {DOCS}; the scenes, the "
                 f"recorded data and the locale mapping all live there")
    sys.path.insert(0, os.path.join(DOCS, "tools", "screenshots"))
    import compose as composer
    import yaml

    scenes = composer.load_scenes()
    with open(os.path.join(DOCS, "screenshots", "locales.yml")) as f:
        locales = yaml.safe_load(f)
    # `order` stays the FULL scene list: it is what numbers the files, and the
    # store shows them in that order. --scenes narrows what gets captured, not
    # what things are called - otherwise a one-scene re-run writes
    # 01-tone-generator.png beside a stale 06-tone-generator.png.
    with open(os.path.join(DOCS, "screenshots", "scenes.yml")) as f:
        order = [s["id"] for s in yaml.safe_load(f)["scenes"]]
    capture = order
    if args.scenes:
        asked = args.scenes.split(",")
        unknown = [s for s in asked if s not in order]
        if unknown:
            sys.exit(f"unknown scene(s): {', '.join(unknown)}")
        capture = [s for s in order if s in asked]
    wanted = args.languages.split(",") if args.languages else None
    # An app language with no App Store localization is skipped rather than
    # captured: Georgian and Serbian have none, so those listings fall back to
    # English images. A limit of the store, not a decision (locales.yml).
    rows = [l for l in locales["locales"]
            if l.get("ios") and (not wanted or l["app"] in wanted)]
    if wanted:
        missing = [t for t in wanted
                   if not any(l["app"] == t and l.get("ios") for l in locales["locales"])]
        if missing:
            sys.exit(f"no App Store locale for: {', '.join(missing)}")

    build = os.path.join(BUILD, "scenes")
    shutil.rmtree(build, ignore_errors=True)
    os.makedirs(build, exist_ok=True)
    views = {}
    for sid in capture:
        scene = scenes[sid]
        if scene.get("kind") == "collection":
            views[sid] = 0
            continue
        blob, view, touched = composer.compose(scene, COLLECTION)
        composer.check(os.path.join(COLLECTION, scene["experiment"]), blob,
                       touched, False)
        views[sid] = view
        with open(os.path.join(build, f"{sid}.phyphox"), "wb") as f:
            f.write(blob)
    httpd = serve(build)

    app = args.app or (build_app() if args.build else last_built_app())
    if not app or not os.path.exists(app):
        raise SystemExit("no built app in the Release output - pass --app, or "
                         "--build to make one")
    if not has_seams(app):
        raise SystemExit(
            f"{app} has no -phyphoxView / -phyphoxAssumeSensors: it predates the "
            f"automation seams, so the audio-spectrum scene cannot reach its "
            f"History tab and the collection would be half greyed out. Build "
            f"from a checkout that includes them.")
    version = app_version(app)

    factor = FORM_FACTORS[args.form_factor]
    udid = args.udid or create_or_find(factor["simulator"], factor["device_type"])
    sim = boot(udid)
    size = sim.size()
    if size != factor["size"]:
        raise SystemExit(
            f"{factor['note']} must be {factor['size'][0]}x{factor['size'][1]}, "
            f"this simulator renders at {size[0]}x{size[1]} - App Store Connect "
            f"takes the two required sizes literally")

    asset = os.path.join(DOCS, "screenshots", "assets", "camera-preview.png")
    total = 0
    try:
        stamp = prepare(sim, app)
        for row in rows:
            check_still_ours(sim, stamp)
            targets = [os.path.join(args.out, name) for name in store_locales(row)]
            target = targets[0]
            for sid in capture:
                scene = scenes[sid]
                n = order.index(sid) + 1        # the store's display order
                theme = scene.get("theme", "dark")
                url = (None if scene.get("kind") == "collection"
                       else f"http://127.0.0.1:{PORT}/{sid}.phyphox")
                httpd.fetched.discard(f"{sid}.phyphox")
                launch(sim, scene, row["app"], theme, views[sid], version, url)
                time.sleep(scene.get("settle", 16))
                if url and f"{sid}.phyphox" not in httpd.fetched:
                    raise RuntimeError(
                        f"{sid}: the app never fetched the scene file, so it is "
                        f"not showing the scene. The launch arguments did not "
                        f"reach a new process.")
                # The form factor is part of the NAME, not of the directory:
                # deliver wants one folder per locale and works out the device
                # from the image size, but two sizes under one name means the
                # second run silently overwrites the first - which is exactly
                # what the iPad run did to the phone set on 2026-09-01.
                shot = os.path.join(target, f"{args.form_factor}-{n:02d}-{sid}.png")
                sim.screenshot(shot, expect=factor["size"])
                check_screen(shot, scene.get("kind"))
                extra = ""
                if scene.get("composite") == "camera":
                    top, bottom = composite_camera(shot, asset, factor["scale"])
                    extra = f"  (preview composited into y {top}-{bottom})"
                for other in targets[1:]:
                    os.makedirs(other, exist_ok=True)
                    shutil.copyfile(shot, os.path.join(other,
                                                       os.path.basename(shot)))
                total += len(targets)
                print(f"  {'/'.join(store_locales(row)):8s} {theme:5s} "
                      f"{n:02d}-{sid}{extra}")
        print(f"{total} screenshot(s) into {args.out}")
    finally:
        status_bar(sim, on=False)
        httpd.shutdown()
        if not args.udid and not args.keep_simulator:
            simctl("shutdown", udid, check=False)


if __name__ == "__main__":
    main()
