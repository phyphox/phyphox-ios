#!/usr/bin/env python3
"""The whole App Store release, in one command.

    tools/store_release.py                  # everything, asking once before uploading
    tools/store_release.py --skip-capture   # reuse the plates already in ../screenshots/ios
    tools/store_release.py --no-upload      # stop after the checks

The pieces this drives - tools/store_screenshots.py, phyphox-docs's verify.py
and tools/appstore_upload.py - all keep their own options, and those are what
a rehearsal or a repair uses. This is the routine: the order they go in, the
checks between them, and the one question that has to be answered before
anything reaches the store. The Android counterpart is
phyphox-android/tools/store_release.py, run on the Linux machine; the two are
meant to feel like the same tool.

Run it with the same virtualenv as the capture script - the pieces need lxml,
Pillow, PyYAML and polib, and they are started with this interpreter:

    ~/.venvs/phyphox-screenshots/bin/python tools/store_release.py

WHAT IT DOES, AND WHY IN THIS ORDER

1.  Preflight. Everything that can be known before the work starts is checked
    first, because step 3 takes an hour or two and finding out afterwards that
    the API key is not in the keychain is that time wasted.

2.  Release notes, asked for now rather than at the end. They are the only step
    that needs a person at the keyboard, and answering while the simulators
    are still cold means the rest can run unattended. They are written into
    phyphox-android's fastlane/metadata/android/<lang>/changelogs/, which is
    where F-Droid reads them and what both stores take their text from - see
    phyphox-android/tools/changelog.py, which appstore_upload.py imports.

3.  Screenshots, both form factors, from ONE build. The Release configuration
    is built once and photographed on the iPhone and the iPad simulator:
    building per form factor would risk two different builds in one listing,
    and the scenes are composed from the experiment collection in this working
    tree either way.

4.  The mechanical check over every plate (verify.py). It catches broken and
    blank captures, not ugly ones - those still need eyes, and this says so.

5.  (Nothing. Android copies its English phone plates into git for F-Droid
    here; the App Store is API-only and nothing of this is committed.)

6.  A rehearsal. There is no server-side one - App Store Connect has no draft
    edit that can be validated and thrown away, which appstore_upload.py's
    docstring explains - so this is the live listing downloaded and compared
    field by field, and the store's screenshots read back against the plates.

7.  THE QUESTION. Everything up to here is local or read-only. Answering yes
    runs the listing upload and then the release-notes upload, two deliver
    runs because they are two metadata trees by design: the release-notes
    tree holds nothing but release_notes.txt so it cannot drag the listing
    along. deliver renders an HTML preview of each and waits for a yes of its
    own, so you answer three times in all; that is deliver's review step, not
    a bug.

8.  What is left to do by hand, printed last so it is on the screen.

WHAT IT DELIBERATELY DOES NOT DO

**It never touches git.** The release notes land in the OTHER repository,
phyphox-android, and when that is committed and pushed is the maintainer's
call in this project; the run ends by saying exactly what is waiting. It also
does not build, upload or release the app binary - that is Xcode and App Store
Connect, and releasing the version there is a separate act from filling in
its listing and its notes.
"""

import argparse
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
ROOT = os.path.normpath(os.path.join(REPO, ".."))
DOCS = os.path.join(ROOT, "phyphox-docs")
TRANSLATION = os.path.join(ROOT, "phyphox-translation")
ANDROID = os.path.join(ROOT, "phyphox-android")
SHOTS = os.path.join(ROOT, "screenshots", "ios")

# The two form factors Apple's required sizes come down to, in the order they
# are captured: the iPhone run builds, the iPad run reuses the build. The
# simulators themselves are created by store_screenshots.py when missing.
FORM_FACTORS = ["iphone", "ipad"]

sys.path.insert(0, HERE)
import appstore_upload as au        # noqa: E402  (the shared checks)


def step(n, what):
    print(f"\n{'=' * 72}\n{n}. {what}\n{'=' * 72}")


def run(*cmd, cwd=REPO):
    print("  $ " + " ".join(str(c) for c in cmd))
    return subprocess.call([str(c) for c in cmd], cwd=cwd)


def must(*cmd, cwd=REPO, why=""):
    rc = run(*cmd, cwd=cwd)
    if rc:
        raise SystemExit(f"\nstopped: {' '.join(str(c) for c in cmd)} "
                         f"exited {rc}{'. ' + why if why else ''}")


def ask(question):
    try:
        return input(f"\n{question} [y/N] ").strip().lower() in ("y", "yes")
    except EOFError:
        return False


def preflight(args):
    """Everything knowable before an hour or two of capturing starts."""
    problems = []
    for name, path in (("phyphox-docs", DOCS),
                       ("phyphox-translation", TRANSLATION),
                       ("phyphox-android", args.android)):
        if not os.path.isdir(path):
            problems.append(f"no {name} checkout at {path}")
    # The last one is where the release notes live - see step 2
    if not os.path.isfile(os.path.join(args.android, "tools", "changelog.py")):
        problems.append(f"no tools/changelog.py in {args.android} - the "
                        f"release notes are read through it")
    for mod in ("yaml", "polib", "lxml", "PIL"):
        try:
            __import__(mod)
        except ImportError:
            problems.append(f"python module {mod} is not installed in "
                            f"{sys.executable}")

    if not args.skip_capture:
        try:
            subprocess.run(["xcrun", "simctl", "help"], capture_output=True,
                           check=True, timeout=120)
        except (OSError, subprocess.SubprocessError):
            problems.append("xcrun simctl does not work - is Xcode installed "
                            "and selected (xcode-select)?")

    if not args.no_upload:
        # fastlane is only used at the end, but a copy too old to know the
        # screenshot sizes would leave every image out without a word.
        # appstore_upload.py reads the table out of the installed copy; the
        # same check, not a second one.
        known = au.known_sizes()
        if known is None:
            problems.append("fastlane is not on the PATH, or its screenshot "
                            "size table could not be read")
        else:
            unusable = [f"{w}x{h} ({au.SIZES[(w, h)]})" for (w, h) in au.SIZES
                        if (w, h) not in known]
            if unusable:
                problems.append("the installed fastlane does not recognise "
                                + " or ".join(unusable)
                                + " - brew upgrade fastlane")
        # And the key, which is the most common way for a run to fall over
        # and free to find out now
        if not au.key_from_keychain():
            problems.append(
                "no App Store Connect API key in the login keychain - "
                "tools/appstore_upload.py --import-key ... (see its docstring)")

    if problems:
        raise SystemExit("cannot start:\n  - " + "\n  - ".join(problems))

    # Not a problem, but the one thing the run cannot check for you: the scenes
    # are composed from the collection in THIS working tree.
    out = subprocess.run(["git", "-C", REPO, "status", "--short"],
                         capture_output=True, text=True).stdout.strip()
    print(f"  phyphox-ios at "
          + subprocess.run(["git", "-C", REPO, "describe", "--always", "--dirty"],
                           capture_output=True, text=True).stdout.strip())
    if out:
        print("  !! the working tree is not clean. The screenshots are "
              "composed from the\n     experiment collection as it is HERE, so "
              "they will show whatever this tree\n     contains - check that "
              "it is what you are shipping.")


def have_plates(shots):
    """{form factor: number of plates} already captured, across all locales.

    The capture tree is flat - <locale>/<factor>-NN-<scene>.png - because
    deliver wants one folder per locale and tells the device from the image
    size, so the form factor is in the file name.
    """
    counts = {}
    if not os.path.isdir(shots):
        return counts
    for locale in os.listdir(shots):
        d = os.path.join(shots, locale)
        if not os.path.isdir(d):
            continue
        for name in os.listdir(d):
            for factor in FORM_FACTORS:
                if name.startswith(f"{factor}-") and name.endswith(".png"):
                    counts[factor] = counts.get(factor, 0) + 1
    return counts


def capture(args):
    """One build, both form factors, into the working root's screenshots/."""
    import store_screenshots
    for i, factor in enumerate(FORM_FACTORS):
        print(f"\n  --- {factor} ---")
        cmd = [sys.executable, os.path.join(HERE, "store_screenshots.py"),
               "--form-factor", factor, "--out", args.shots]
        if i == 0:
            cmd += ["--build"]
        else:
            # The app the first run built, passed explicitly so this run
            # cannot rebuild - or, worse, quietly photograph an older build
            # it found lying in the Release output
            app = store_screenshots.last_built_app()
            if not app:
                raise SystemExit("the iPhone run left no built app in "
                                 f"{store_screenshots.BUILD} - nothing to "
                                 f"photograph on the iPad")
            cmd += ["--app", app]
        if args.languages:
            cmd += ["--languages", args.languages]
        if args.scenes:
            cmd += ["--scenes", args.scenes]
        must(*cmd, why="the plates for the other form factor were not taken")


def verify(args):
    """The mechanical sweep, per form factor. Fails the run; does not judge."""
    bad = []
    for factor in FORM_FACTORS:
        print(f"\n  --- {factor} ---")
        if run(sys.executable,
               os.path.join(DOCS, "tools", "screenshots", "verify.py"),
               args.shots, "--form-factor", factor):
            bad.append(factor)
    if bad:
        raise SystemExit(
            f"\nstopped: verify.py found problems in {', '.join(bad)}.\n"
            f"Re-capture the affected plates with tools/store_screenshots.py "
            f"--form-factor <x>\n--languages <...> --scenes <...>, then run "
            f"this again with --skip-capture.")
    print("\n  No broken or blank plates. It does not judge whether a "
          "screenshot is a GOOD one -\n  a plate on the wrong tab or a graph "
          "with unfortunate data still needs eyes.")


def upload_cmd(args, *more):
    cmd = [sys.executable, os.path.join(HERE, "appstore_upload.py"),
           "--screenshots", args.shots]
    if args.android != ANDROID:
        cmd += ["--android", args.android]
    return cmd + list(more)


def main():
    try:
        sys.stdout.reconfigure(line_buffering=True)
    except AttributeError:
        pass

    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--skip-capture", action="store_true",
                    help="reuse the plates already in ../screenshots/ios "
                         "instead of taking new ones")
    ap.add_argument("--capture", action="store_true",
                    help="take new plates without asking, even though some "
                         "are already there")
    ap.add_argument("--languages", help="comma separated app language tags, "
                                        "passed to the capture (default: all)")
    ap.add_argument("--scenes", help="comma separated scene ids, passed to the "
                                     "capture (default: all)")
    ap.add_argument("--no-upload", action="store_true",
                    help="stop after the checks, without talking to the "
                         "store at all")
    ap.add_argument("--version-code", type=int,
                    help="the Android versionCode the release notes are "
                         "filed under, when it is not the one in "
                         "phyphox-android/app/build.gradle")
    # For exercising the routine without the real neighbours: another
    # phyphox-android checkout to read and write the release notes in, and
    # another plate tree
    ap.add_argument("--android", default=ANDROID, help=argparse.SUPPRESS)
    ap.add_argument("--shots", default=SHOTS, help=argparse.SUPPRESS)
    args = ap.parse_args()

    step(1, "Preflight")
    preflight(args)

    step(2, "Release notes")
    cl = au.changelog_module(args.android)
    version = au.marketing_version()
    code = args.version_code or cl.code_for(version, args.android)
    cl.ensure(code, version, args.android)

    step(3, "Screenshots - one build, both form factors")
    counts = have_plates(args.shots)
    if args.skip_capture:
        if not counts:
            raise SystemExit(f"--skip-capture, but there are no plates in "
                             f"{args.shots}")
        print("  reusing " + ", ".join(f"{k}: {n}" for k, n in sorted(counts.items())))
    else:
        if counts and not args.capture:
            print("  plates are already there: "
                  + ", ".join(f"{k}: {n}" for k, n in sorted(counts.items())))
            print("  A full capture is an hour or two.")
            if not ask("take new ones?"):
                print("  keeping them")
                counts = None
        if counts is not None:
            capture(args)

    step(4, "Checking every plate")
    verify(args)

    step(5, "(no F-Droid half on this side - nothing is committed for the App Store)")

    step(6, "Rehearsal - the live listing compared, the store's screenshots read back")
    if args.no_upload:
        print("  --no-upload: not talking to App Store Connect at all")
    else:
        must(*upload_cmd(args, "--diff"), why="nothing was uploaded")
        # Informational: before an upload the store is EXPECTED to differ
        # wherever the plates are new. What matters is that it could be read.
        if run(*upload_cmd(args, "--verify-screenshots")):
            print("  (the store's screenshots differ from the plates here, or "
                  "could not be read -\n   that is what --upload changes; the "
                  "same check runs again afterwards)")

    step(7, "Uploading")
    uploaded = False
    if args.no_upload:
        print("  --no-upload: stopping here. Everything above is on disk.")
    else:
        print("  This sends the listing text and every plate, then the "
              "release notes for the\n  draft version, as two deliver runs. "
              "deliver shows an HTML preview of each and\n  asks again before "
              "writing - so after this yes there are two more, deliver's own.\n"
              "  Uploading is not releasing: the listing and the notes go live "
              "with the version\n  when you release it in App Store Connect.")
        if ask("upload the listing and the release notes to App Store Connect?"):
            must(*upload_cmd(args, "--upload"),
                 why="the release notes were not uploaded either")
            notes = ["--release-notes", "--upload"]
            if args.version_code:
                notes += ["--version-code", str(args.version_code)]
            must(*upload_cmd(args, *notes))
            uploaded = True
        else:
            print("  nothing uploaded. Everything above is on disk; "
                  "tools/store_release.py\n  --skip-capture picks up from here.")

    step(8, "What is left")
    print(f"\n{'=' * 72}\nDone.\n{'=' * 72}")
    if uploaded:
        print("- The listing and the release notes are on the draft in App "
              "Store Connect. They go\n  live when you release the version "
              "there, with the build from Xcode.")
    out = subprocess.run(["git", "-C", args.android, "status", "--short",
                          "fastlane/metadata/android"],
                         capture_output=True, text=True).stdout.rstrip()
    if out:
        print("- Still waiting for you in git, in the OTHER repository: the "
              "release notes under\n  phyphox-android/fastlane/metadata/android/"
              "<lang>/changelogs/. F-Droid reads those\n  out of the repository, "
              "so they are not published until you commit and push them\n  "
              "there.")
        print(f"\n  git -C {os.path.relpath(args.android, REPO)} status --short "
              f"fastlane/metadata/android\n" + out)
    else:
        print("- Nothing is waiting in phyphox-android's metadata tree: the "
              "release notes for this\n  version were committed before, or "
              "were not written by this run.")


if __name__ == "__main__":
    main()
