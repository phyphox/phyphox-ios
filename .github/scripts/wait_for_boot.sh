#!/bin/bash
# Wait for a simulator to finish booting, but not forever: "xcrun simctl bootstatus -b" has no timeout,
# and a device that never boots would hold the job until GitHub kills it.
#   wait_for_boot.sh <udid> [seconds]     exits 0 once booted, 1 if not booted within the budget
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

wait "$WAITER" || exit 1

# bootstatus exits 0 either way ("Finished", status 4294967295), so the verdict has to come from the device list.
if ! xcrun simctl list devices | grep -q "$UDID.*Booted"; then
  echo "$UDID is not booted although bootstatus finished"
  exit 1
fi
