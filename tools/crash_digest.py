#!/usr/bin/env python3
"""Summarise the App Store crash reports that Xcode's Organizer has cached locally.

Apple exposes App Store crash reports only through the Organizer (the App Store
Connect API serves hangs, launch and disk-write diagnostics, not crashes), and
the Organizer caches everything it downloads as plain files under

    ~/Library/Developer/Xcode/Products/<bundle id>/Crashes/

This script reads that cache. It downloads nothing itself, so the workflow is:
open the Organizer, let the Crashes tab load for the version you care about,
click the points whose stacks you want (that is what makes the Organizer fetch
their logs), then run

    tools/crash_digest.py                       # ranked points, every version the Organizer listed
    tools/crash_digest.py --version 1.2.1       # one version
    tools/crash_digest.py --compare 1.2.0 1.2.1 # old vs new, with a per-point ratio against the baseline
    tools/crash_digest.py --point B7bekG5z      # the stacks behind one point (id prefix is enough)

THINGS TO KNOW ABOUT THE CACHE
------------------------------
* The ranked lists are the Organizer's own, one per version filter it was
  opened with, and carry unique device counts for the period selected there
  (usually the last 365 days). A version released days ago is compared against
  a year of the old one, hence --compare's baseline: the ratio of total new to
  total old counts, so a point well above it grew and one well below shrank.
* Points are grouped by Apple on the top frame plus its offset inside the
  library. One bug therefore fragments into several points whenever the OS
  build shifts an offset, and the fragments trade places between iOS releases.
  Judge by the app frames in the stacks (--point), not by point names.
* At most five logs are downloaded per point and version filter, so log counts
  rank nothing; only the unique device counts do.
* The converted .crash files carry no exception message for ObjC exceptions,
  only the "Last Exception Backtrace", which this script uses when present.
"""

import argparse
import collections
import glob
import json
import os
import re
import sys

DEFAULT_BUNDLE = "de.rwth-aachen.physics.phyphox"
APP_MODULE = "phyphox"

NOISE = re.compile(
    r"^(libdispatch|libsystem_pthread|libsystem_kernel|libsystem_c\.dylib:abort|"
    r"libc\+\+abi|libobjc|libswiftCore\.dylib:swift::fatalError|"
    r"libswiftCore\.dylib:_swift_release_dealloc|libswiftCore\.dylib:bool swift::RefCounts|"
    r"CoreFoundation:__CF|CoreFoundation:_CF|Foundation:__NS|"
    r"GraphicsServices|UIKitCore:UIApplicationMain|UIKitCore:-\[UIApplication _run\]|"
    r"phyphox:<dedup|phyphox:thunk|phyphox:partial|phyphox:specialized autoreleasepool)"
)


def cache_dir(bundle):
    d = os.path.expanduser(f"~/Library/Developer/Xcode/Products/{bundle}/Crashes")
    if not os.path.isdir(d):
        sys.exit(f"no Organizer crash cache at {d} - open Xcode's Organizer, Crashes tab, first")
    return d


# --- the Organizer's ranked lists -------------------------------------------------------

def ranked_lists(cache):
    """{version: (access date, [(point id, name, unique devices)])}, freshest list per version."""
    items = json.load(open(os.path.join(cache, "ListablePoints.json")))["recentItems"]
    out = {}
    params = None
    for item in items:  # the list alternates parameter records and value records
        if "value" not in item:
            params = item
            continue
        versions = [v.get("version", {}).get("version") for v in (params or {}).get("pageAgnosticParameters", {})
                    .get("indexedSelectedProductVersions", [])]
        versions = [v for v in versions if v]
        version = versions[0] if versions else "all"
        points = [(p["analyticsPointIdentifier"], p["analyticsPointName"],
                   p.get("uniqueDeviceCountFilteredWithTimePeriod", 0))
                  for p in item["value"].get("crashPoints", [])]
        if not points:
            continue
        period = item["value"]["header"].get("timePeriod", "")
        when = item["lastAccess"]
        if version not in out or when > out[version][0]:
            out[version] = (when, period, points)
    return out


def point_names(cache):
    names = {}
    for f in glob.glob(os.path.join(cache, "Points/*.xccrashpoint/Filters/*/PointInfo.json")):
        pid = re.search(r"Points/([^/]+)\.xccrashpoint", f).group(1)
        try:
            names[pid] = json.load(open(f)).get("analyticsPointName", "?")
        except (OSError, ValueError):
            pass
    return names


def log_files(cache, pid):
    return sorted(glob.glob(os.path.join(cache, f"Points/{pid}.xccrashpoint/Filters/*/Logs/**/*.crash"),
                            recursive=True))


def version_key(v):
    return tuple(int(x) if x.isdigit() else 0 for x in v.split("."))


# --- one log -----------------------------------------------------------------------------

FRAME = re.compile(r"^\d+\s+(\S+)\s+0x[0-9a-f]+\s+(.*?)(?:\s+\((.*?)\))?\s*$")


def parse_log(path):
    text = open(path, errors="replace").read()

    def header(key):
        m = re.search(rf"^{key}:\s*(.*)$", text, re.M)
        return m.group(1).strip() if m else ""

    body = None
    m = re.search(r"^Last Exception Backtrace:\n((?:\d+\s+.*\n)+)", text, re.M)
    if m:
        body = m.group(1)
    m = re.search(r"^Thread \d+ Crashed:\n((?:\d+\s+.*\n)+)", text, re.M)
    if m and body is None:
        body = m.group(1)
    frames = []
    for line in (body or "").splitlines():
        fm = FRAME.match(line)
        if not fm:
            continue
        lib, sym, loc = fm.group(1), re.sub(r"\s\+\s\d+$", "", fm.group(2)), fm.group(3) or ""
        if loc in (":-1", "/<compiler-generated>:0", "<compiler-generated>:0"):
            loc = ""
        frames.append(f"{lib}:{sym}" + (f" ({loc})" if loc else ""))
    os_version = header("OS Version")
    os_short = os_version.split(" ")[2] if len(os_version.split(" ")) > 2 else os_version
    return {
        "version": header("Version").split(" ")[0],
        "os": os_short,
        "exception": (header("Exception Type") + " " + header("Exception Subtype")).strip()[:90],
        "termination": header("Termination Reason")[:60],
        "date": os.path.basename(path)[:10],
        "frames": frames,
    }


def signature(frames):
    """The app's own frames decide the grouping; the top system frame breaks ties."""
    app = [f for f in frames if f.startswith(APP_MODULE + ":") and not NOISE.match(f)]
    top = next((f for f in frames if not NOISE.match(f)), frames[0] if frames else "")
    return tuple(app[:4]) or (top,)


# --- commands ----------------------------------------------------------------------------

def cmd_list(cache, only_version):
    lists = ranked_lists(cache)
    for version in sorted(lists, key=version_key):
        if only_version and version != only_version:
            continue
        when, period, points = lists[version]
        print(f"\n== {version}: {len(points)} points, unique devices over {period}, list fetched {when[:10]}")
        print(f"{'devices':>8}  {'logs':>4}  {'point':24}  name")
        for pid, name, uniq in points:
            print(f"{uniq:8}  {len(log_files(cache, pid)):4}  {pid:24}  {name[:100]}")
    if not lists:
        print("the Organizer has not listed any crash points yet")


def cmd_compare(cache, old, new):
    lists = ranked_lists(cache)
    for v in (old, new):
        if v not in lists:
            sys.exit(f"no Organizer list for version {v}; open the Organizer with that version selected")
    old_pts = {pid: (name, n) for pid, name, n in lists[old][2]}
    new_pts = {pid: (name, n) for pid, name, n in lists[new][2]}
    total_old = sum(n for _, n in old_pts.values())
    total_new = sum(n for _, n in new_pts.values())
    baseline = total_new / total_old if total_old else 0
    print(f"\n== {old} ({lists[old][1]}, fetched {lists[old][0][:10]}) vs {new} ({lists[new][1]}, fetched {lists[new][0][:10]})")
    print(f"   baseline: {total_new} / {total_old} = {baseline:.3f} of the old count is what an unchanged point shows")
    print(f"   lists are the Organizer's top {len(old_pts)} / {len(new_pts)}; a point missing from one may just be below its cut\n")
    print(f"{'old':>7} {'new':>6} {'x base':>7}  {'point':24}  name")
    rows = []
    for pid in set(old_pts) | set(new_pts):
        name, n_old = old_pts.get(pid, (None, 0))
        name2, n_new = new_pts.get(pid, (None, 0))
        ratio = (n_new / (n_old * baseline)) if n_old and baseline else None
        rows.append((n_new, n_old, ratio, pid, name or name2))
    rows.sort(key=lambda r: (-(r[0] or 0), -(r[1] or 0)))
    for n_new, n_old, ratio, pid, name in rows:
        r = "new" if n_old == 0 else f"{ratio:6.1f}" if ratio is not None else "     ?"
        print(f"{n_old:7} {n_new:6} {r:>7}  {pid:24}  {name[:90]}")


def cmd_point(cache, prefix, max_frames):
    names = point_names(cache)
    matches = [pid for pid in names if pid.startswith(prefix)]
    if not matches:
        sys.exit(f"no downloaded point starts with {prefix!r}; click it in the Organizer so its logs get fetched")
    for pid in matches:
        logs = log_files(cache, pid)
        print(f"\n##### {pid}  {names[pid]}  ({len(logs)} logs downloaded)")
        groups = collections.OrderedDict()
        for path in logs:
            log = parse_log(path)
            g = groups.setdefault(signature(log["frames"]), {"n": 0, "versions": set(), "os": set(), "exc": set(),
                                                             "term": set(), "dates": [], "frames": log["frames"]})
            g["n"] += 1
            g["versions"].add(log["version"])
            g["os"].add(log["os"])
            g["exc"].add(log["exception"])
            g["term"].add(log["termination"])
            g["dates"].append(log["date"])
        for g in sorted(groups.values(), key=lambda g: -g["n"]):
            dates = sorted(g["dates"])
            print(f"\n  --- {g['n']} logs  versions {sorted(g['versions'], key=version_key)}  iOS {sorted(g['os'])}  {dates[0]}..{dates[-1]}")
            for e in sorted(g["exc"]):
                print(f"      {e}")
            shown = 0
            for f in g["frames"]:
                if NOISE.match(f):
                    continue
                print(f"      {f[:150]}")
                shown += 1
                if shown >= max_frames:
                    break


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--bundle", default=DEFAULT_BUNDLE)
    ap.add_argument("--version", help="only this app version's list")
    ap.add_argument("--compare", nargs=2, metavar=("OLD", "NEW"), help="old vs new version")
    ap.add_argument("--point", metavar="ID", help="stacks behind one point (prefix of its id)")
    ap.add_argument("--frames", type=int, default=8, help="frames per stack with --point (default 8)")
    args = ap.parse_args()
    cache = cache_dir(args.bundle)
    if args.point:
        cmd_point(cache, args.point, args.frames)
    elif args.compare:
        cmd_compare(cache, *args.compare)
    else:
        cmd_list(cache, args.version)


if __name__ == "__main__":
    main()
