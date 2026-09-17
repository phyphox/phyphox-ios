#!/usr/bin/env python3
"""Readable live log and a summary table for an xcodebuild test run.

    xcodebuild test-without-building ... 2>&1 | python3 xctest_progress.py "<title>" <full-log>

Prints one line per test case as it finishes (the simulator noise goes to <full-log>, for the
diagnostics artifact) and appends a pass/fail table per test class to $GITHUB_STEP_SUMMARY.
Always exits 0: with `set -o pipefail` the step's verdict stays xcodebuild's own.
"""
import os
import re
import sys
import time
from collections import OrderedDict

CASE = re.compile(r"^Test Case '-\[\w+\.(\w+) (\w+)\]' (passed|failed) \((\d+\.\d+) seconds\)")
SUITE = re.compile(r"^Test Suite '(\w+)' started")
PASSTHROUGH = re.compile(r": error: |^xcodebuild: error|^\*\* TEST |^Testing failed|^Executed \d+ tests?, with")


def main():
    title, log_path = sys.argv[1], sys.argv[2]
    os.makedirs(os.path.dirname(os.path.abspath(log_path)), exist_ok=True)
    classes = OrderedDict()  # class -> {"passed": n, "failed": [names], "seconds": s}
    started = time.time()
    with open(log_path, "w") as log:
        for line in sys.stdin:
            log.write(line)
            m = CASE.match(line)
            if m:
                cls, name, verdict, seconds = m.groups()
                stats = classes.setdefault(cls, {"passed": 0, "failed": [], "seconds": 0.0})
                stats["seconds"] += float(seconds)
                if verdict == "passed":
                    stats["passed"] += 1
                else:
                    stats["failed"].append(name)
                mark = "ok  " if verdict == "passed" else "FAIL"
                print(f"  {mark} {cls}.{name}  {float(seconds):6.1f} s", flush=True)
            elif SUITE.match(line):
                suite = SUITE.match(line).group(1)
                if suite.endswith("Tests"):
                    print(f"{suite}", flush=True)
            elif PASSTHROUGH.search(line):
                print(line.rstrip()[:300], flush=True)
    summary(title, classes, time.time() - started)


def summary(title, classes, elapsed):
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not path:
        return
    failed = sum(len(s["failed"]) for s in classes.values())
    passed = sum(s["passed"] for s in classes.values())
    verdict = "no tests ran" if not classes else ("all passed" if not failed else f"{failed} failed")
    lines = [f"### {title}: {passed} passed, {verdict} ({elapsed / 60:.1f} min)", "",
             "| Test class | Passed | Failed | Time |", "|---|---:|---:|---:|"]
    for cls, s in classes.items():
        lines.append(f"| {cls} | {s['passed']} | {len(s['failed'])} | {s['seconds'] / 60:.1f} min |")
    for cls, s in classes.items():
        for name in s["failed"]:
            lines.append(f"- FAILED `{cls}.{name}`")
    with open(path, "a") as f:
        f.write("\n".join(lines) + "\n\n")


if __name__ == "__main__":
    main()
