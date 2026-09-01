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

THE API KEY
-----------
It is a private key that can rewrite this app's listing and submit builds for
it, so it goes in the login keychain, not in a file - see KEYCHAIN_SERVICE
below for why that one and not age, gpg or pass.

    tools/appstore_upload.py --import-key ~/Downloads/AuthKey_XXXXXXXXXX.p8 \\
        --issuer-id <the UUID under Users and Access -> Integrations>

taking Apple's download as it comes - the JSON that fastlane wants around it is
assembled here rather than by hand. Delete the .p8 afterwards.

`--upload` reads it back from there and writes it out as a 0600 file in a 0700
directory only for as long as deliver runs, because fastlane takes a path
rather than the key itself. `--api-key <file>` still works for a machine with
some other arrangement - but keep that file out of the working root, which
syncs.

Dependencies: PyYAML and polib, plus fastlane for --upload. Same virtualenv as
the capture script:

    ~/.venvs/phyphox-screenshots/bin/pip install pyyaml polib

fastlane must be new enough to know the two screenshot sizes this listing uses;
2.214.0 is not, 2.238.0 is. The check below reads that out of the installed
copy rather than trusting a version number.
"""

import argparse
import contextlib
import glob
import importlib.util
import io
import json
import os
import re
import shutil
import stat
import struct
import subprocess
import sys
import tempfile

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

# WHERE THE API KEY LIVES
#
# An App Store Connect individual API key, in fastlane's own JSON shape
# (key_id, issuer_id, key). It is a private key that can rewrite this app's
# listing and submit builds for it, so:
#
#   - never in the working root, which syncs to Nextcloud;
#   - never in a repository, this one included;
#   - not lying about as a plain file if that can be avoided.
#
# The login keychain is what this machine offers (no age, gpg or pass): it is
# encrypted at rest under the login password, it does not sync anywhere, and it
# reads back in one command. --import-key puts it there; the value is only ever
# written out as a 0600 temporary file for as long as deliver runs, because
# fastlane takes a path rather than the key itself.
#
# A plain file is still accepted, for a machine that has some other arrangement
# or a one-off run - hence --api-key.
KEYCHAIN_SERVICE = "phyphox-asc-key"
KEYCHAIN_ACCOUNT = "phyphox"

# App Store Connect's limits. Checked before anything is sent, so an over-long
# string is reported by name instead of coming back as an API error at the end.
LIMITS = {"name": 30, "description": 4000}

# The screenshot sizes this listing uses, and which display type each belongs
# to. deliver decides that from the image's dimensions alone, so a size its
# table does not know is silently not uploaded - see known_sizes().
SIZES = {(1320, 2868): '6.9" iPhone', (2064, 2752): '13" iPad'}


def store_locales(row):
    """The App Store listings one app language feeds. Usually one.

    Portuguese is one language in the app and two listings on the store,
    knowingly given the same translation (maintainer, 2026-09-01), the same
    compromise already made on Play.
    """
    ios = row["ios"]
    return ios if isinstance(ios, list) else [ios]


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
# A separator line: nothing but dashes. "--" is what the source uses and what
# updateMetadata.py's bullet rule deliberately leaves alone ("^-(?!-)"); three
# translations have worn it down to "-" or "- ", which is the same intent.
SEPARATOR = re.compile(r"^\s*-{1,5}\s*$")


def strip_android_section(text, where):
    """Drop the Android permissions explanation from a store description.

    Every store description ends with a section explaining the Android
    permissions the app asks for - which is required reading on Play and is
    nonsense on the App Store, where those permissions do not exist and Apple
    would rightly object to being told about them.

    The section is marked off by a separator line of dashes, and every
    translation mentions "Android" exactly once, inside it. So: cut at the last
    separator before that mention. Where a translation has lost the separator
    altogether (nl, 2026-09-01), fall back to the paragraph before the one that
    mentions Android, which is the section's own heading in all twenty
    languages.

    Then CHECK, because a heuristic that quietly does nothing is worse than one
    that fails: the result must no longer mention Android, must not have lost
    most of the text, and must not be empty. Anything else stops the run for
    that locale rather than sending Apple a description of Android permissions.
    """
    lines = text.split("\n")
    hits = [i for i, l in enumerate(lines) if "android" in l.lower()]
    if not hits:
        return text, None
    first = hits[0]

    seps = [i for i in range(first) if SEPARATOR.match(lines[i])]
    if seps:
        cut, how = seps[-1], "separator"
    else:
        # start of the paragraph mentioning Android, then back over the blank
        # line, then to the start of the paragraph before it - the heading
        i = first
        while i > 0 and lines[i - 1].strip():
            i -= 1
        while i > 0 and not lines[i - 1].strip():
            i -= 1
        while i > 0 and lines[i - 1].strip():
            i -= 1
        cut, how = i, "heading"

    kept = lines[:cut]
    while kept and (not kept[-1].strip() or SEPARATOR.match(kept[-1])):
        kept.pop()
    out = "\n".join(kept)

    if "android" in out.lower():
        raise SystemExit(f"{where}: the Android permissions section is still "
                         f"there after cutting at the {how} - look at it by "
                         f"hand rather than uploading this.")
    if not out.strip():
        raise SystemExit(f"{where}: cutting the Android section left nothing")
    if len(out) < 0.5 * len(text):
        raise SystemExit(
            f"{where}: cutting at the {how} would drop "
            f"{100 - 100 * len(out) // len(text)}% of the description "
            f"({len(text)} -> {len(out)} characters). That is not a permissions "
            f"section - check the translation.")
    return out, how


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
    # Before formatting, so the separator is still a separator: formatDescription
    # turns a lone "- " into a bullet.
    text, _how = strip_android_section(text, po_locale)
    text, dropped = drop_light_sensor(text, po_locale)
    text = ANCHOR.sub(r"\1", mod.formatDescription(text))
    left = sorted(set(TAG.findall(text)))
    if left:
        return None, (f"{po_locale}: markup the App Store would print literally: "
                      f"{', '.join(left)}")
    return (text, dropped), None


BULLET = re.compile(r"^\s*-\s*\S")
# The sensor list, in the order every translation keeps it: accelerometer,
# magnetometer, gyroscope, LIGHT, pressure, microphone, proximity, GPS.
SENSOR_LIST_LENGTH = 8
LIGHT_SENSOR_POSITION = 3


def drop_light_sensor(text, where):
    """Remove the ambient light sensor from the list of supported sensors.

    iOS exposes no ambient light sensor on any device - it is the one entry the
    app itself always greys out (ExperimentSensorInput.verifySensorAvailibility
    keeps failing for .light even under -phyphoxAssumeSensors) - so a listing
    that advertises it is promising something the app cannot do there. Four of
    the twenty App Store listings had the line removed by hand; the other
    sixteen still carry it (maintainer, 2026-09-01: remove it in all twenty).

    Found by position, not by word: the store text names the sensor differently
    from the app in eleven of the twenty languages, so matching a translation of
    "light" would quietly miss more than half of them. Every description has
    exactly one bulleted block of eight items and the light sensor is the
    fourth, which was checked in all twenty by reading them.

    The guards are the point. A description without exactly one eight-item
    block stops the run rather than losing some other line, and the line that
    was dropped is printed on every run, so a translation that reorders the
    list shows up in the review instead of silently costing the app a sensor.
    """
    lines = text.split("\n")
    blocks, cur = [], []
    for i, l in enumerate(lines):
        if BULLET.match(l):
            cur.append(i)
        else:
            if cur:
                blocks.append(cur)
            cur = []
    if cur:
        blocks.append(cur)
    eight = [b for b in blocks if len(b) == SENSOR_LIST_LENGTH]
    if len(eight) != 1:
        raise SystemExit(
            f"{where}: expected exactly one bulleted block of "
            f"{SENSOR_LIST_LENGTH} items - the list of supported sensors - but "
            f"found {len(eight)} (block sizes: "
            f"{', '.join(str(len(b)) for b in blocks)}). The description was "
            f"restructured; check by hand which line names the light sensor.")
    at = eight[0][LIGHT_SENSOR_POSITION]
    dropped = lines[at].strip()
    return "\n".join(lines[:at] + lines[at + 1:]), dropped


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


def key_json(text, where):
    """Parse and sanity-check the API key blob without ever printing it."""
    try:
        blob = json.loads(text)
    except ValueError:
        raise SystemExit(f"{where} is not JSON. fastlane wants "
                         '{"key_id": "...", "issuer_id": "...", "key": '
                         '"-----BEGIN PRIVATE KEY-----\\n..."}')
    missing = [k for k in ("key_id", "issuer_id", "key") if not blob.get(k)]
    if missing:
        raise SystemExit(f"{where} is missing {', '.join(missing)}")
    if "PRIVATE KEY" not in blob["key"]:
        raise SystemExit(f"{where}: \"key\" should be the .p8 file's contents, "
                         f"beginning -----BEGIN PRIVATE KEY-----")
    return blob


KEY_ID_FROM_NAME = re.compile(r"AuthKey_([A-Z0-9]{8,12})\.p8$", re.IGNORECASE)


def key_blob_from(path, key_id, issuer_id):
    """fastlane's key JSON, from either a .p8 or an already-assembled JSON.

    Apple hands out `AuthKey_<KEYID>.p8` and nothing else; the JSON is
    fastlane's own wrapper (spaceship's Token.from_json_file wants `key_id` and
    `key`, and the App Store Connect API needs `issuer_id` to sign with). Asking
    for that JSON to be written by hand means pasting a PEM into a string with
    its newlines escaped, which is a fine way to spend an afternoon on an
    authentication error - so this builds it.

    The key id is taken from the file name, which is where Apple already put it;
    --key-id overrides that for a file that has been renamed.
    """
    with open(path) as f:
        text = f.read()
    if text.lstrip().startswith("{"):
        return key_json(text, path)
    if "PRIVATE KEY" not in text:
        raise SystemExit(f"{path} is neither a .p8 private key nor a key JSON")
    if not key_id:
        m = KEY_ID_FROM_NAME.search(os.path.basename(path))
        if not m:
            raise SystemExit(
                f"cannot tell the key id from {os.path.basename(path)} - Apple "
                f"names the download AuthKey_<KEYID>.p8. Pass --key-id.")
        key_id = m.group(1)
    if not issuer_id:
        raise SystemExit(
            "--issuer-id is required with a .p8. It is the UUID at the top of "
            "App Store Connect -> Users and Access -> Integrations -> App Store "
            "Connect API, the same for every key on the team.")
    return {"key_id": key_id, "issuer_id": issuer_id, "key": text}


def import_key(path, key_id=None, issuer_id=None):
    """Put a key into the login keychain, replacing any earlier one."""
    blob = key_blob_from(path, key_id, issuer_id)
    text = json.dumps(blob)
    subprocess.run(["security", "add-generic-password",
                    "-a", KEYCHAIN_ACCOUNT, "-s", KEYCHAIN_SERVICE,
                    "-w", text, "-U",
                    "-D", "App Store Connect API key",
                    "-j", "phyphox store release (tools/appstore_upload.py)"],
                   check=True)
    print(f"stored key {blob['key_id']} in the login keychain as "
          f"{KEYCHAIN_SERVICE!r}")
    print(f"Now delete the file - it is the same secret lying about:\n"
          f"  rm -P {path}\n"
          f"Losing it is survivable: revoke the key in App Store Connect and "
          f"generate another.")


def key_from_keychain():
    r = subprocess.run(["security", "find-generic-password",
                        "-a", KEYCHAIN_ACCOUNT, "-s", KEYCHAIN_SERVICE, "-w"],
                       capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 and r.stdout.strip() else None


@contextlib.contextmanager
def key_file(explicit):
    """A path deliver can read, and no key left on disk afterwards.

    fastlane takes a path rather than the key itself, so a key held in the
    keychain has to be written out for the length of the run. It goes into a
    0700 directory as a 0600 file and is removed in a finally, including when
    deliver fails or the run is interrupted.
    """
    if explicit:
        with open(explicit) as f:
            key_json(f.read(), explicit)
        yield explicit
        return
    text = key_from_keychain()
    if not text:
        raise SystemExit(
            "no App Store Connect API key.\n"
            "Create an INDIVIDUAL key (App Store Connect -> Users and Access -> "
            "the phyphox user -> Edit Profile -> Generate an Individual API Key; "
            "a team key cannot be restricted to one app). Apple downloads it "
            "once, as AuthKey_<KEYID>.p8. Put that in the login keychain:\n"
            "  tools/appstore_upload.py --import-key ~/Downloads/AuthKey_XXXX.p8 "
            "--issuer-id <uuid>\n"
            "and then delete the file. The issuer id is the UUID on the same "
            "page, under Integrations.\n"
            "A key file is still accepted directly with --api-key, but keep it "
            "out of the working root - that syncs.")
    key_json(text, "the keychain entry")
    d = tempfile.mkdtemp(prefix="phyphox-asc-")
    os.chmod(d, stat.S_IRWXU)
    path = os.path.join(d, "asc_key.json")
    try:
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL,
                     stat.S_IRUSR | stat.S_IWUSR)
        with os.fdopen(fd, "w") as f:
            f.write(text)
        yield path
    finally:
        shutil.rmtree(d, ignore_errors=True)


# What deliver would write if a file existed, beyond the two this tool
# generates. Shown by --diff so it is visible that they are being left alone
# rather than quietly blanked.
LEFT_ALONE = ["subtitle", "keywords", "promotional_text", "release_notes",
              "support_url", "marketing_url", "privacy_url"]


def download_live(key_path, out):
    """The listing as it is on the store right now. Read-only."""
    os.makedirs(out, exist_ok=True)
    cmd = ["fastlane", "deliver", "download_metadata",
           "--api_key_path", key_path,
           "--app_identifier", BUNDLE_ID,
           "--platform", "ios",
           "--metadata_path", out,
           "--force", "true"]
    print("  " + " ".join(cmd[:3]) + " ... (this only reads)")
    if subprocess.call(cmd, cwd=REPO) != 0:
        raise SystemExit("could not download the current listing")
    # deliver also pulls down review_information/, which is the reviewer contact
    # details and any demo account - a phone number, an email address and a
    # password. Nothing here reads them, and this tree sits in a working root
    # that syncs, so they go straight back out again.
    shutil.rmtree(os.path.join(out, "review_information"), ignore_errors=True)
    return out


def read_field(root, locale, field):
    path = os.path.join(root, locale, f"{field}.txt")
    if not os.path.isfile(path):
        return None
    with open(path, encoding="utf-8") as f:
        return f.read().strip()


def show_diff(live, ours, rows):
    """What --upload would change, field by field, and what it would not."""
    print("\nwhat --upload would change:")
    for locale, _row in rows:
        if not os.path.isdir(os.path.join(live, locale)):
            seeded = [f for f in SEEDED if read_field(ours, locale, f)]
            print(f"  {locale:8s} NEW LISTING - name, description"
                  + (f", {', '.join(seeded)}" if seeded else "")
                  + (" (copied from the seed locale)" if seeded else ""))
            continue
        for field in ("name", "description"):
            before, after = read_field(live, locale, field), read_field(ours, locale, field)
            if after is None:
                continue
            if before == after:
                print(f"  {locale:8s} {field:11s} unchanged")
            elif before is None:
                print(f"  {locale:8s} {field:11s} NEW ({len(after)} chars)")
            else:
                # The listing on the store was written by hand from the same
                # source and uses "- " where formatDescription produces "-".
                # Reporting that on every line would bury the two or three
                # that matter, so it is normalised away and mentioned once.
                def norm(t):
                    return [re.sub(r"^[\u2022-]\s+", "- ", l)
                            for l in t.split("\n") if l.strip()]
                a, b = norm(before), norm(after)
                if a == b:
                    print(f"  {locale:8s} {field:11s} same text, bullets restyled")
                    continue
                added = [l for l in b if l not in a]
                removed = [l for l in a if l not in b]
                if not added and not removed:
                    # same lines, different order - worth saying so, because
                    # "+0 -0 lines" on its own reads like a bug
                    print(f"  {locale:8s} {field:11s} same lines, reordered")
                    continue
                print(f"  {locale:8s} {field:11s} CHANGED "
                      f"({len(before)} -> {len(after)} chars, "
                      f"+{len(added)} -{len(removed)} lines)")
                for l in added[:3]:
                    print(f"           + {l[:86]}")
                for l in removed[:3]:
                    print(f"           - {l[:86]}")
    print("\nleft exactly as it is (no file is written for these):")
    for field in LEFT_ALONE:
        have = sorted(loc for loc, _r in rows if read_field(live, loc, field))
        if have:
            print(f"  {field:17s} set in {len(have)} locale(s): "
                  + ", ".join(have[:8]) + (" ..." if len(have) > 8 else ""))
        else:
            print(f"  {field:17s} not set anywhere on the store either")


# Copied into a locale that does not exist on the store yet, from the source
# locale, because there is nothing there to leave alone (maintainer,
# 2026-09-01). Everywhere else these are the store's to keep - see D4 above.
SEEDED = ["subtitle", "keywords", "support_url", "privacy_url"]


def build_tree(rows, out, mod, live=None, seed_from=None):
    """Write the metadata tree, and return what went into it."""
    shutil.rmtree(out, ignore_errors=True)
    written, problems = {}, []
    for locale, row in rows:
        po_locale = row["app"].replace("-", "_")
        result, why = description_for(mod, po_locale)
        if result is None:
            problems.append(f"{locale}: {why}")
            continue
        text, dropped = result
        print(f"  {locale:8s} dropped the light sensor: {dropped}")
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
        if seed_from and live and not os.path.isdir(os.path.join(live, locale)):
            copied = []
            for field in SEEDED:
                value = read_field(live, seed_from, field)
                if not value:
                    continue
                with open(os.path.join(d, f"{field}.txt"), "w",
                          encoding="utf-8") as f:
                    f.write(value)
                copied.append(field)
            if copied:
                print(f"  {locale:8s} new on the store - copied "
                      f"{', '.join(copied)} from {seed_from}")
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
    ap.add_argument("--api-key",
                    help="a key JSON file to use instead of the login keychain")
    ap.add_argument("--import-key", metavar="FILE",
                    help="put Apple's AuthKey_<KEYID>.p8 (or an assembled key "
                         "JSON) into the login keychain and exit; delete the "
                         "file afterwards")
    ap.add_argument("--key-id", help="with --import-key, if the .p8 has been "
                                     "renamed away from AuthKey_<KEYID>.p8")
    ap.add_argument("--issuer-id", help="with --import-key: the UUID from App "
                                        "Store Connect -> Users and Access -> "
                                        "Integrations")
    ap.add_argument("--skip-screenshots", action="store_true",
                    help="upload only the text")
    ap.add_argument("--seed-new-from", metavar="LOCALE",
                    help="for a locale that has no listing yet, copy "
                         + ", ".join(SEEDED) + " from this one - there is "
                         "nothing on the store to leave alone. Reads the live "
                         "listing, so it needs the key.")
    ap.add_argument("--diff", action="store_true",
                    help="download the live listing and show what --upload "
                         "would change. Reads the store, writes nothing.")
    ap.add_argument("--upload", action="store_true",
                    help="hand the result to deliver. Even then deliver shows "
                         "its HTML preview and waits for confirmation.")
    args = ap.parse_args()

    if args.import_key:
        import_key(args.import_key, args.key_id, args.issuer_id)
        return

    sys.path.insert(0, os.path.join(DOCS, "tools", "screenshots"))
    import yaml
    with open(os.path.join(DOCS, "screenshots", "locales.yml")) as f:
        locales = yaml.safe_load(f)
    # One entry per App Store LISTING, not per app language: Portuguese is one
    # language and two listings.
    rows = [(locale, r) for r in locales["locales"] if r.get("ios")
            for locale in store_locales(r)]
    if args.languages:
        wanted = args.languages.split(",")
        unknown = [w for w in wanted if w not in {loc for loc, _ in rows}]
        if unknown:
            sys.exit(f"no such App Store locale in locales.yml: "
                     f"{', '.join(unknown)}")
        rows = [(loc, r) for loc, r in rows if loc in wanted]

    # The live listing is needed before the tree is built when new locales are
    # to be seeded from it, so the download happens first either way.
    live = None
    if args.diff or args.seed_new_from:
        if args.api_key and not os.path.isfile(args.api_key):
            raise SystemExit(f"no key file at {args.api_key}")
        with key_file(args.api_key) as key_path:
            live = os.path.join(REPO, "build", "appstore", "live")
            shutil.rmtree(live, ignore_errors=True)
            download_live(key_path, live)
        if args.seed_new_from and not os.path.isdir(
                os.path.join(live, args.seed_new_from)):
            raise SystemExit(f"--seed-new-from {args.seed_new_from}: that "
                             f"locale is not on the store either")

    written = build_tree(rows, args.metadata, formatter(), live,
                         args.seed_new_from)
    print(f"metadata for {len(written)} locale(s) in {args.metadata}")
    print("  (name and description only - subtitle, keywords, promotional text, "
          "release notes\n   and the URLs are left to the store on purpose; see "
          "this file's docstring)")

    known = known_sizes()
    total, missing = 0, []
    for locale, _row in rows:
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

    if args.diff:
        show_diff(live, args.metadata, rows)

    if not args.upload:
        print(f"\n{total} screenshot(s) ready. Nothing was sent - add --upload "
              f"to hand this to deliver.")
        return

    if args.api_key and not os.path.isfile(args.api_key):
        raise SystemExit(f"no key file at {args.api_key}")

    with key_file(args.api_key) as key_path:
        raise SystemExit(deliver(key_path, args))


def deliver(key_path, args):
    cmd = ["fastlane", "deliver",
           "--api_key_path", key_path,
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
    # The key path is a throwaway temporary file, so printing the command is
    # not printing a secret - but say where it came from, because a path under
    # /var/folders looks like something went wrong otherwise.
    print("\n" + " ".join(cmd))
    print("  (the key was written out of the login keychain for this run and is "
          "deleted after it)\n")
    return subprocess.call(cmd, cwd=REPO)


if __name__ == "__main__":
    main()
