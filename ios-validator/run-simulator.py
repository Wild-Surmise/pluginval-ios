#!/usr/bin/env python3
"""Run pluginval against a registered AUv3 on a booted iOS simulator."""

import argparse
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import time
from uuid import uuid4


BUNDLE = "com.wildsurmise.pluginval-ios"


def run(device, app, target, timeout, device_set=None):
    simctl = ["xcrun", "simctl"]
    if device_set is not None:
        simctl.extend(["--set", str(device_set)])
    with (app / "Info.plist").open("rb") as file:
        if plistlib.load(file)["CFBundleIdentifier"] != BUNDLE:
            raise ValueError("The app is not the pluginval iOS validator.")

    subprocess.run([*simctl, "install", device, str(app)], check=True, timeout=180)
    container = subprocess.check_output(
        [*simctl, "get_app_container", device, BUNDLE, "data"], text=True, timeout=90
    ).strip()
    report = Path(container) / "Documents/pluginval-result.json"
    run_id = uuid4().hex
    launch = subprocess.check_output(
        [*simctl, "launch", "--terminate-running-process", device, BUNDLE, target],
        env={**os.environ, "SIMCTL_CHILD_PLUGINVAL_RUN_ID": run_id},
        text=True, timeout=120,
    ).strip()
    reported_app, _, pid = launch.rpartition(":")
    if reported_app != BUNDLE or not pid.strip().isdecimal():
        raise RuntimeError(f"simctl did not report the validator PID: {launch}")

    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            result = json.loads(report.read_text(encoding="utf-8"))
        except (FileNotFoundError, json.JSONDecodeError):
            result = {}
        if result.get("run_id") == run_id:
            print(json.dumps(result, indent=2))
            return 0 if result["passed"] is True else 1
        state = subprocess.run(
            ["ps", "-p", pid.strip(), "-o", "stat="], capture_output=True, text=True, timeout=10
        )
        if state.returncode or state.stdout.strip().startswith("Z"):
            raise RuntimeError("The validator exited before writing a report.")
        time.sleep(0.5)
    raise RuntimeError(f"The validator did not finish within {timeout}s.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("device", help="UDID of the booted simulator with the AUv3 installed")
    parser.add_argument("app", type=Path, help="Built pluginval iOS.app")
    parser.add_argument("target", help="A registered AudioUnit: selector")
    parser.add_argument("--device-set", type=Path, help="CoreSimulator device set containing the device")
    parser.add_argument("--timeout", type=int, default=180, help="Maximum seconds to wait for test results")
    args = parser.parse_args()
    if not args.target.startswith("AudioUnit:") or args.timeout < 1:
        parser.error("Provide an AudioUnit: selector and a positive timeout.")
    try:
        return run(args.device, args.app, args.target, args.timeout, args.device_set)
    except (KeyError, OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        print(f"iOS validation failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
