#!/bin/bash
# Wait for a simulator to finish booting, but not forever.
#
# "xcrun simctl bootstatus <udid> -b" waits with no timeout of its own, and a device that never
# finishes booting then holds the job until GitHub kills it - which is what a second simulator did
# on a runner: 30 minutes in the preparation step and nothing to show for it. Here the wait is
# bounded, so a device that does not come up costs a warning and the test that needed it, not the
# whole job.
#
#   wait_for_boot.sh <udid> [seconds]
#
# Exits 0 once the device is booted, 1 if it is not booted within the budget.
set -uo pipefail

UDID="${1:?usage: wait_for_boot.sh <udid> [seconds]}"
BUDGET="${2:-300}"

xcrun simctl bootstatus "$UDID" -b &
WAITER=$!

ELAPSED=0
while kill -0 "$WAITER" 2>/dev/null; do
  if [ "$ELAPSED" -ge "$BUDGET" ]; then
    kill "$WAITER" 2>/dev/null
    wait "$WAITER" 2>/dev/null
    echo "$UDID did not finish booting within ${BUDGET}s"
    exit 1
  fi
  sleep 5
  ELAPSED=$((ELAPSED + 5))
done

wait "$WAITER"
