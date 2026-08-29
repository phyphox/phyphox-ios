#!/usr/bin/env python3
"""Set environment variables on a test target of a prebuilt .xctestrun.

The T1 jobs run what the build job produced (xcodebuild test-without-building), and a test bundle
running on a simulator does not inherit the environment of the xcodebuild that started it - the
variables have to be in the .xctestrun. That is how the language sweep is told which shard it is
(PHYPHOX_TEST_LANGUAGE_SHARD, see TranslationsUITests), the same way an Android instrumentation
run is told with -e.

    xctestrun_env.py <file.xctestrun> <target> KEY=VALUE [KEY=VALUE ...]
"""

import plistlib
import sys


def main(argv):
    if len(argv) < 4:
        print(__doc__, file=sys.stderr)
        return 2

    path, target = argv[1], argv[2]
    assignments = []
    for pair in argv[3:]:
        if "=" not in pair:
            print(f"not a KEY=VALUE assignment: {pair}", file=sys.stderr)
            return 2
        key, _, value = pair.partition("=")
        assignments.append((key, value))

    with open(path, "rb") as f:
        document = plistlib.load(f)

    patched = 0
    for configuration in document.get("TestConfigurations", []):
        for test_target in configuration.get("TestTargets", []):
            if test_target.get("BlueprintName") != target:
                continue
            environment = test_target.setdefault("EnvironmentVariables", {})
            for key, value in assignments:
                environment[key] = value
            patched += 1

    if patched == 0:
        # A silently unset variable would run the whole sweep in every shard, which looks like a
        # slow but green run rather than the mistake it is
        print(f"no test target named {target} in {path}", file=sys.stderr)
        return 1

    with open(path, "wb") as f:
        plistlib.dump(document, f)

    print(f"{target}: set {', '.join(k for k, _ in assignments)} in {patched} configuration(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
