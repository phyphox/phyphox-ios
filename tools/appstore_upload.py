#!/usr/bin/env python3
"""Build the App Store listing metadata and hand it, with the screenshots, to deliver.

The other half of the release step described in the working root's
STORE-RELEASE-PLAN.md: tools/store_screenshots.py writes every locale and form
factor into `screenshots/ios/`, and this puts the text next to it and uploads
both. The Android counterpart is phyphox-android/tools/play_upload.py.

    tools/appstore_upload.py                   # build and check, change nothing
    tools/appstore_upload.py --upload          # hand it to deliver

**Nothing reaches Apple without --upload**, and even then deliver renders its
own HTML preview and waits for a yes before writing anything; `--force` is
deliberately not passed. Unlike Play there is no such thing as a server-side
rehearsal here - the App Store Connect API has no draft edit that can be
validated and thrown away, so the checking all happens before the first call.

**Why deliver rather than the REST API** (the Android side deliberately uses
neither fastlane nor a client library): screenshots. Play takes an image in one
POST; App Store Connect wants a screenshot set, a reservation, a part-by-part
upload against per-part URLs and a commit carrying the file's MD5. That is a lot
of protocol to reimplement, and deliver already has it. The text half would be
easy either way.

WHAT IS WRITTEN, AND WHAT IS DELIBERATELY NOT
---------------------------------------------
Only two files per locale, `name.txt` and `description.txt`, because those are
the only two fields the store PO files are a source for.

**deliver sets a field only when it finds a file for it**, so leaving a file out
keeps whatever is live on the store, while an EMPTY file would blank it. That is
what makes the following safe, and it is why nothing here ever writes an empty
file:

  subtitle, keywords        maintained by hand in App Store Connect
                            (maintainer, 2026-09-01, deciding D4). The PO files
                            carry no source for either and they are not worth a
                            translation round.
  promotional_text          same reasoning: no source. Play's short description
                            is not it - Apple's `subtitle` is the field in that
                            position, and that one is manual.
  release_notes             belongs to a version, and this tool is about the
                            listing.
  support_url, marketing_url, privacy_url
                            no source in this repository, and the live values
                            are right.

The description needs one iOS-specific step. `updateMetadata.py`'s
`formatDescription` is shared - it is the one definition of the bullet and
unescaping rules - but it also wraps bare URLs in `<a href>`, which Google Play
and F-Droid render and the App Store does not: there the description is plain
text, and a tag would appear literally. So the anchors are unwrapped again
afterwards, and anything else that still looks like a tag stops the run.

Dependencies: PyYAML and polib, plus fastlane for --upload. Same virtualenv as
the capture script:

    ~/.venvs/phyphox-screenshots/bin/pip install pyyaml polib
"""

import argparse
import contextlib
import glob
import importlib.util
import io
import os
import re
import shutil
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
ROOT = os.path.normpath(os.path.join(REPO, ".."))
DOCS = os.path.join(ROOT, "phyphox-docs")
TRANSLATION = os.path.join(ROOT, "phyphox-translation")
SHOTS = os.path.join(ROOT, "screenshots", "ios")
# Build output, not a fixture: regenerated from the PO files on every run, the
# same way the capture script regenerates its scene files.
METADATA = os.path.join(REPO, "build", "appstore", "metadata")
BUNDLE_ID = "de.rwth-aachen.physics.phyphox"
# An App Store Connect individual API key, in fastlane's own JSON shape
# (key_id, issuer_id, key). Kept out of the working root, which syncs.
DEFAULT_KEY = os.path.expanduser("~/.config/phyphox-store/asc_key.json")

# App Store Connect's limits. Checked before anything is sent, so an over-long
# string is reported by name instead of coming back as an API error at the end.
LIMITS = {"name": 30, "description": 4000}

# The screenshot sizes this listing uses, and which display type each belongs
# to. deliver decides that from the image's dimensions alone, so a size its
# table does not know is silently not uploaded - see known_sizes().
SIZES = {(1320, 2868): '6.9" iPhone', (2064, 2752): '13" iPad'}


def formatter():
    """phyphox-translation's own formatting rules, imported rather than copied.

    That repository must come out of this byte-for-byte unchanged, so the module
    is executed with an argv pointing nowhere - it then says "invalid
    destination" and writes nothing - with stdout swallowed and bytecode writing
    off, so not even a __pycache__ is left behind. Same trick as play_upload.py.
    """
    path = os.path.join(TRANSLATION, "python", "updateMetadata.py")
    spec = importlib.util.spec_from_file_location("phyphox_updateMetadata", path)
    mod = importlib.util.module_from_spec(spec)
    argv, cwd, bytecode = sys.argv, os.getcwd(), sys.dont_write_bytecode
    try:
        sys.argv = ["updateMetadata.py", os.path.join(os.sep, "nonexistent")]
        os.chdir(os.path.join(TRANSLATION, "python"))
        sys.dont_write_bytecode = True
        with contextlib.redirect_stdout(io.StringIO()):
            spec.loader.exec_module(mod)
    finally:
        sys.argv, sys.dont_write_bytecode = argv, bytecode
        os.chdir(cwd)
    return mod


ANCHOR = re.compile(r'<a href="[^"]*">([^<]*)</a>')
TAG = re.compile(r"</?[a-zA-Z][^>]*>")


def description_for(mod, po_locale):
    """The long description, formatted for a store that renders plain text."""
    import polib
    path = os.path.join(TRANSLATION, "store", f"{po_locale}.po")
    if not os.path.isfile(path):
        return None, f"no PO file {po_locale}.po"
    text = None
    for entry in polib.pofile(path):
        if entry.msgid == "store_long_description" and entry.msgstr:
            text = entry.msgstr
    if text is None:
        return None, f"{po_locale}.po has no store_long_description"
    text = ANCHOR.sub(r"\1", mod.formatDescription(text))
    left = sorted(set(TAG.findall(text)))
    if left:
        return None, (f"{po_locale}: markup the App Store would print literally: "
                      f"{', '.join(left)}")
    return text, None


def png_size(path):
    with open(path, "rb") as f:
        data = f.read(24)
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return struct.unpack(">II", data[16:24])


def known_sizes():
    """The screenshot dimensions the INSTALLED deliver recognises.

    deliver maps an image to a display type by its dimensions and quietly
    ignores one it cannot place, so a fastlane that predates a device would
    upload nothing and say nothing. Rather than trusting the version number this
    reads the table out of the installed copy; if it cannot be found the caller
    is told that, instead of being told everything is fine.
    """
    exe = shutil.which("fastlane")
    if not exe:
        return None
    try:
        out = subprocess.run(["fastlane", "--version"], capture_output=True,
                             text=True, timeout=120).stdout
    except (subprocess.SubprocessError, OSError):
        return None
    m = re.search(r"(\S+/fastlane-[^/]+)/bin/fastlane", out)
    if not m:
        return None
    table = os.path.join(m.group(1), "deliver", "lib", "deliver", "app_screenshot.rb")
    if not os.path.isfile(table):
        return None
    with open(table) as f:
        body = f.read()
    return {(int(a), int(b))
            for a, b in re.findall(r"\[\s*(\d+)\s*,\s*(\d+)\s*\]", body)}


def build_tree(rows, out, mod):
    """Write the metadata tree, and return what went into it."""
    shutil.rmtree(out, ignore_errors=True)
    written, problems = {}, []
    for row in rows:
        locale, po_locale = row["ios"], row["app"].replace("-", "_")
        text, why = description_for(mod, po_locale)
        if text is None:
            problems.append(f"{locale}: {why}")
            continue
        name = "phyphox"
        over = [(k, len(v)) for k, v in (("name", name), ("description", text))
                if len(v) > LIMITS[k]]
        if over:
            problems.append("; ".join(
                f"{locale}: {k} is {n} characters, the App Store allows {LIMITS[k]}"
                for k, n in over))
            continue
        d = os.path.join(out, locale)
        os.makedirs(d, exist_ok=True)
        # Never an empty file: deliver would take that as "blank this field",
        # and for name that is not even a legal listing.
        for fn, value in (("name.txt", name), ("description.txt", text)):
            assert value.strip(), f"{locale}/{fn} would be empty"
            with open(os.path.join(d, fn), "w", encoding="utf-8") as f:
                f.write(value)
        written[locale] = len(text)
    if problems:
        raise SystemExit(
            "refusing to build the metadata tree:\n  " + "\n  ".join(problems)
            + "\nThese are translations - shorten or fix them in Weblate; "
              "nothing here edits phyphox-translation.")
    return written


def screenshots_for(locale):
    d = os.path.join(SHOTS, locale)
    if not os.path.isdir(d):
        return {}
    found = {}
    for p in sorted(glob.glob(os.path.join(d, "*.png"))):
        size = png_size(p)
        if size:
            found.setdefault(size, []).append(p)
    return found


def main():
    try:
        sys.stdout.reconfigure(line_buffering=True)
    except AttributeError:
        pass

    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--metadata", default=METADATA)
    ap.add_argument("--screenshots", default=SHOTS)
    ap.add_argument("--languages", help="comma separated App Store locales; "
                                        "default: every one in locales.yml")
    ap.add_argument("--api-key", default=DEFAULT_KEY,
                    help="fastlane's App Store Connect API key JSON "
                         f"(default: {DEFAULT_KEY})")
    ap.add_argument("--skip-screenshots", action="store_true",
                    help="upload only the text")
    ap.add_argument("--upload", action="store_true",
                    help="hand the result to deliver. Even then deliver shows "
                         "its HTML preview and waits for confirmation.")
    args = ap.parse_args()

    sys.path.insert(0, os.path.join(DOCS, "tools", "screenshots"))
    import yaml
    with open(os.path.join(DOCS, "screenshots", "locales.yml")) as f:
        locales = yaml.safe_load(f)
    rows = [r for r in locales["locales"] if r.get("ios")]
    if args.languages:
        wanted = args.languages.split(",")
        unknown = [w for w in wanted if w not in {r["ios"] for r in rows}]
        if unknown:
            sys.exit(f"no such App Store locale in locales.yml: "
                     f"{', '.join(unknown)}")
        rows = [r for r in rows if r["ios"] in wanted]

    written = build_tree(rows, args.metadata, formatter())
    print(f"metadata for {len(written)} locale(s) in {args.metadata}")
    print("  (name and description only - subtitle, keywords, promotional text, "
          "release notes\n   and the URLs are left to the store on purpose; see "
          "this file's docstring)")

    known = known_sizes()
    total, missing = 0, []
    for row in rows:
        locale = row["ios"]
        found = screenshots_for(locale)
        counts = ", ".join(f"{SIZES.get(s, f'{s[0]}x{s[1]}')}: {len(v)}"
                           for s, v in sorted(found.items()))
        total += sum(len(v) for v in found.values())
        if not found:
            missing.append(locale)
        print(f"  {locale:8s} description {written[locale]:5d} chars"
              + (f"   {counts}" if counts else "   no screenshots"))
    if missing:
        # Not an error: the store falls back to the default listing's images,
        # and a locale with text but no screenshots is a normal state.
        print(f"  no screenshots for {', '.join(missing)} - the store will fall "
              f"back to the default listing's images")

    if known is not None:
        unusable = [f"{w}x{h} ({SIZES[(w, h)]})" for (w, h) in SIZES
                    if (w, h) not in known]
        if unusable:
            print("\n  !! the installed fastlane does not recognise "
                  + " or ".join(unusable) + ".")
            print("     deliver places a screenshot by its dimensions and "
                  "ignores a size it cannot\n     place, so these would be "
                  "left out without a word. Upgrade fastlane\n     "
                  "(brew upgrade fastlane) and run this again.")
            if args.upload and not args.skip_screenshots:
                raise SystemExit(
                    "refusing to upload: the screenshots would silently not "
                    "arrive. Upgrade fastlane, or pass --skip-screenshots to "
                    "send only the text.")
    else:
        print("\n  (could not read deliver's screenshot size table - check by "
              "hand that this\n   fastlane knows "
              + " and ".join(f"{w}x{h}" for w, h in SIZES) + ")")

    if not args.upload:
        print(f"\n{total} screenshot(s) ready. Nothing was sent - add --upload "
              f"to hand this to deliver.")
        return

    if not os.path.isfile(args.api_key):
        raise SystemExit(
            f"no App Store Connect API key at {args.api_key}. Create an "
            f"INDIVIDUAL key (App Store Connect -> Users and Access -> the "
            f"phyphox user -> Edit Profile -> Generate an Individual API Key; "
            f"a team key cannot be restricted to one app), then write "
            f"fastlane's JSON form of it there:\n"
            f'  {{"key_id": "...", "issuer_id": "...", "key": '
            f'"-----BEGIN PRIVATE KEY-----\\n..."}}')

    cmd = ["fastlane", "deliver",
           "--api_key_path", args.api_key,
           "--app_identifier", BUNDLE_ID,
           "--metadata_path", args.metadata,
           "--screenshots_path", args.screenshots,
           # This tool is about the listing; the binary goes up through Xcode.
           "--skip_binary_upload", "true",
           # deliver ADDS screenshots otherwise, so a second run would leave the
           # store with two of everything. Checked before trusting it: the
           # deletion is scoped to the locales being uploaded
           # ("next unless screenshots_per_language.keys.include?", deliver's
           # upload_screenshots.rb), so a locale this run does not cover keeps
           # the images it has.
           "--overwrite_screenshots", "true",
           "--submit_for_review", "false",
           "--precheck_include_in_app_purchases", "false"]
    if args.skip_screenshots:
        cmd += ["--skip_screenshots", "true"]
    # No --force: deliver renders an HTML preview of exactly what it is about to
    # write and waits for a yes. That preview is the review step this whole
    # tool is arranged around, so it must not be skipped.
    print("\n" + " ".join(cmd) + "\n")
    raise SystemExit(subprocess.call(cmd, cwd=REPO))


if __name__ == "__main__":
    main()
