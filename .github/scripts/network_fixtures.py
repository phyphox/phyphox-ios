#!/usr/bin/env python3
"""Network fixture runner for the iOS simulator (test-matrix rows network-http, network-mqtt).

Implements the runner contract of phyphox-docs fixtures/network/README.md:
for every fixture experiment, substitute the FIXTURE-HOST/FIXTURE-PORT
placeholders, hand the file to the app through its real loading path, start the
experiment through the remote API, let it poll, stop it and assert the buffer
contents the README states.

    python3 .github/scripts/network_fixtures.py --udid <simulator udid>
        [--fixtures ../phyphox-docs/fixtures/network] [--seconds 4]
        [--only http] [--keep-going]

Pieces started here: phyphox-docs' tools/network_fixture.py (the deterministic
HTTP endpoints) and, for the mqtt row, mosquitto with the fixture's conf. The
substituted experiments are served over http from a temporary directory, which
is how they reach the app: the launch argument seam opens
phyphox://127.0.0.1:<port>/<fixture>.phyphox, the same route a scanned QR code
takes.

Exit status 1 if any fixture behaved differently than the README asserts - a
difference is a finding to report, not something to code around.

The experiments open with -phyphoxAutoConfirm: the network privacy notice gates
the connection setup, so without it no fixture would ever connect.
"""

import argparse
import functools
import http.server
import json
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

BUNDLE = "de.rwth-aachen.physics.phyphox"
HOST = "127.0.0.1"  # the iOS simulator reaches the host directly


def get(url, timeout=5):
    with urllib.request.urlopen(url, timeout=timeout) as response:
        return response.read()


def api(base, path, timeout=10):
    try:
        return json.loads(get(base + path, timeout=timeout))
    except Exception as error:
        return {"error": str(error)}


def wait_for_api(base, seconds):
    deadline = time.time() + seconds
    while time.time() < deadline:
        try:
            get(base + "/config", timeout=2)
            return True
        except Exception:
            time.sleep(0.5)
    return False


def buffers(base, names):
    query = "&".join(urllib.parse.quote(name) + "=full" for name in names)
    answer = api(base, "/get?" + query, timeout=20)
    got = answer.get("buffer", {})
    return {name: [v for v in got.get(name, {}).get("buffer", [])] for name in names}


def free_port():
    with socket.socket() as s:
        s.bind((HOST, 0))
        return s.getsockname()[1]


def serve_directory(directory):
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=directory)
    handler.log_message = lambda *a, **k: None
    server = http.server.ThreadingHTTPServer((HOST, free_port()), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def prepare_fixtures(source, fixture_port):
    """Substitute the placeholders into a temporary directory that is served."""
    directory = tempfile.mkdtemp(prefix="phyphox-network-fixtures-")
    for name in sorted(os.listdir(source)):
        if not name.endswith(".phyphox"):
            continue
        with open(os.path.join(source, name), "rb") as f:
            data = f.read()
        data = data.replace(b"FIXTURE-HOST", HOST.encode())
        data = data.replace(b"FIXTURE-PORT", str(fixture_port).encode())
        with open(os.path.join(directory, name), "wb") as f:
            f.write(data)
    return directory


def run_fixture(args, base, experiment_url, names):
    subprocess.run(["xcrun", "simctl", "terminate", args.udid, BUNDLE],
                   capture_output=True)
    subprocess.run(["xcrun", "simctl", "launch", "--terminate-running-process",
                    args.udid, BUNDLE, "-phyphoxUrl", experiment_url,
                    "-phyphoxRemote", "-phyphoxRemotePort", str(args.port),
                    "-phyphoxAutoConfirm"],
                   capture_output=True, check=True)
    if not wait_for_api(base, args.api_wait):
        return None, ["the remote API never came up - did the experiment load?"]
    problems = []
    started = api(base, "/control?cmd=start")
    if started.get("result") is not True:
        problems.append(f"start was not accepted: {started}")
    time.sleep(args.seconds)
    api(base, "/control?cmd=stop")
    data = buffers(base, names)
    if not wait_for_api(base, 5):
        problems.append("the app stopped answering after the run")
    return data, problems


def consecutive_from_one(values):
    return values == list(range(1, len(values) + 1))


def check_http_get_receive(data):
    seq, value = data["seq"], data["value"]
    problems = []
    if not seq:
        return ["seq is empty - no poll produced data"]
    if not consecutive_from_one(seq):
        problems.append(f"seq must be the consecutive integers 1..k, got {seq}")
    for n, v in zip(seq, value):
        if v is None or abs(v - n / 2) > 1e-9:
            problems.append(f"value must be seq/2, got {v} for seq {n}")
            break
    if len(value) != len(seq):
        problems.append(f"seq and value differ in length: {len(seq)} vs {len(value)}")
    return problems


def check_http_get_send_roundtrip(data):
    back, seq = data["back"], data["seq"]
    problems = []
    if not back:
        return ["back is empty - the sent value never came back"]
    if any(v is None or abs(v - 42.5) > 1e-9 for v in back):
        problems.append(f"back must hold 42.5 for every round trip, got {back}")
    if not seq:
        problems.append("seq is empty - no round trip was counted")
    return problems


def check_http_post_roundtrip(data):
    back, seq = data["back"], data["seq"]
    pattern = [1.0, 2.5, 3.0]
    problems = []
    if not back:
        return ["back is empty - the sent array never came back"]
    if len(back) % len(pattern) != 0:
        problems.append(f"back must repeat the sent array per poll, got {back}")
    for i, v in enumerate(back):
        expected = pattern[i % len(pattern)]
        if v is None or abs(v - expected) > 1e-9:
            problems.append(f"back must repeat 1, 2.5, 3 per poll, got {back}")
            break
    if not seq:
        problems.append("seq is empty - no round trip was counted")
    return problems


def check_error_fixture(data):
    never = data["never"]
    return [] if not never else [f"never must stay empty, got {never}"]


def check_mqtt_roundtrip(data):
    back = data["back"]
    if not back:
        return ["back is empty - the message did not come back through the broker"]
    if any(v is None or abs(v - 7.25) > 1e-9 for v in back):
        return [f"back must hold 7.25, got {back}"]
    return []


# phyphox-test: network-http
HTTP_FIXTURES = [
    ("http-get-receive", ["seq", "value"], check_http_get_receive),
    ("http-get-send-roundtrip", ["back", "seq"], check_http_get_send_roundtrip),
    ("http-post-roundtrip", ["back", "seq"], check_http_post_roundtrip),
    ("http-error-malformed", ["never"], check_error_fixture),
    ("http-error-down", ["never"], check_error_fixture),
]

# phyphox-test: network-mqtt
MQTT_FIXTURES = [
    ("mqtt-json-roundtrip", ["back"], check_mqtt_roundtrip),
]


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    default_fixtures = os.path.normpath(
        os.path.join(here, "..", "..", "..", "phyphox-docs", "fixtures", "network"))

    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--udid", default="booted", help="simulator udid")
    parser.add_argument("--fixtures", default=default_fixtures,
                        help="phyphox-docs fixtures/network directory")
    parser.add_argument("--port", type=int, default=8080,
                        help="port the app serves remote access on")
    parser.add_argument("--fixture-port", type=int, default=8113)
    parser.add_argument("--seconds", type=float, default=4.0,
                        help="how long each fixture polls")
    parser.add_argument("--api-wait", type=float, default=20.0)
    parser.add_argument("--only", choices=["http", "mqtt"],
                        help="run only one of the two matrix rows")
    parser.add_argument("--keep-going", action="store_true",
                        help="report every fixture instead of stopping at the first failure")
    args = parser.parse_args()

    fixtures = os.path.normpath(args.fixtures)
    if not os.path.isdir(fixtures):
        sys.exit(f"no fixture directory at {fixtures} - is phyphox-docs checked out?")
    tools = os.path.join(os.path.dirname(os.path.dirname(fixtures)), "tools")

    base = f"http://{HOST}:{args.port}"
    directory = prepare_fixtures(fixtures, args.fixture_port)
    served = serve_directory(directory)
    fixture_server = subprocess.Popen(
        [sys.executable, os.path.join(tools, "network_fixture.py"), str(args.fixture_port)],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    broker = None
    selected = []
    if args.only != "mqtt":
        selected += HTTP_FIXTURES
    if args.only != "http":
        selected += MQTT_FIXTURES
        broker = subprocess.Popen(
            ["mosquitto", "-c", os.path.join(fixtures, "mosquitto.conf")],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(1.0)

    failures = 0
    try:
        for name, names, check in selected:
            print(f"== {name}")
            # /reset makes every fixture's counters start at 1 again
            api(f"http://{HOST}:{args.fixture_port}", "/reset")
            url = f"phyphox://{HOST}:{served.server_address[1]}/{name}.phyphox"
            data, problems = run_fixture(args, base, url, names)
            if data is not None:
                problems += check(data)
                print(f"   {json.dumps(data)}")
            for problem in problems:
                print(f"   ! {problem}")
            if problems:
                failures += 1
                if not args.keep_going:
                    break
            else:
                print("   ok")
    finally:
        subprocess.run(["xcrun", "simctl", "terminate", args.udid, BUNDLE],
                       capture_output=True)
        served.shutdown()
        fixture_server.terminate()
        if broker:
            broker.terminate()
        shutil.rmtree(directory, ignore_errors=True)

    print(f"\n{len(selected)} fixture(s), {failures} with findings")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
