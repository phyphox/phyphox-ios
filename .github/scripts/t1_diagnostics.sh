#!/bin/bash
# Collect what a failing T1 job leaves behind (crash reports, device log) into t1-diagnostics/ for the
# job's artifact. Takes the simulator's UDID; every step is best-effort so a missing log cannot mask the failure.
set -uo pipefail

UDID="${1:-}"
mkdir -p t1-diagnostics

cp ~/Library/Logs/DiagnosticReports/phyphox-*.ips t1-diagnostics/ 2>/dev/null || true

if [ -n "$UDID" ]; then
  xcrun simctl spawn "$UDID" log show --last 20m --style compact \
    --predicate 'process == "phyphox"' > t1-diagnostics/phyphox-device.log 2>&1 || true
  # Who took the foreground: the app tears its remote server down on resigning active; SpringBoard's log says why.
  xcrun simctl spawn "$UDID" log show --last 20m --style compact \
    --predicate 'process == "SpringBoard" OR process == "runningboardd"' 2>/dev/null \
    | tail -c 12000000 > t1-diagnostics/springboard.log || true
  # 12 MB, not 4: at debug level 4 MB of SpringBoard/runningboardd is the last six minutes of a twenty-minute job.
fi

ls -la t1-diagnostics
