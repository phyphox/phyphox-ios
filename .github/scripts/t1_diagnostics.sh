#!/bin/bash
# What a failing T1 job leaves behind. A failure usually means the app stopped answering, and the
# reason is in the crash reports and the device log - neither of which survives the runner, so
# both are collected into t1-diagnostics/ for the job's artifact.
#
# Takes the simulator's UDID; every step is best-effort, a missing log must not mask the failure
# that is being reported.
set -uo pipefail

UDID="${1:-}"
mkdir -p t1-diagnostics

cp ~/Library/Logs/DiagnosticReports/phyphox-*.ips t1-diagnostics/ 2>/dev/null || true

if [ -n "$UDID" ]; then
  xcrun simctl spawn "$UDID" log show --last 20m --style compact \
    --predicate 'process == "phyphox"' > t1-diagnostics/phyphox-device.log 2>&1 || true
  # Who took the foreground: the app tears its remote server down when it resigns active, so a
  # run can end with the app alive and silent, and the reason is in SpringBoard's log rather
  # than the app's.
  xcrun simctl spawn "$UDID" log show --last 20m --style compact \
    --predicate 'process == "SpringBoard" OR process == "runningboardd"' 2>/dev/null \
    | tail -c 4000000 > t1-diagnostics/springboard.log || true
fi

ls -la t1-diagnostics
