#!/bin/bash
# Prints an xcodebuild destination for the newest available iPhone simulator.
set -euo pipefail
xcrun simctl list devices available -j | python3 -c '
import json, re, sys
data = json.load(sys.stdin)["devices"]
best = None
for runtime, devices in data.items():
    m = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not m:
        continue
    version = (int(m.group(1)), int(m.group(2)))
    for d in devices:
        if d["name"].startswith("iPhone") and (best is None or version > best[0]):
            best = (version, d["udid"], d["name"])
if not best:
    sys.exit("No iPhone simulator found")
print(f"platform=iOS Simulator,id={best[1]}")
'
