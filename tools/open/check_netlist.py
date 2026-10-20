#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Check that the open-flow netlist kept the primitives the player needs.

`read_slang -v` makes cell-library modules visible but does not instantiate
them; a missing `--blackboxed-module` drops the instance silently.  This check
fails the build if a required primitive count is absent, rather than letting a
plausible-looking but clockless netlist reach place and route.

    tools/open/check_netlist.py <netlist.json> <top-module>
"""

import json
import sys
from collections import Counter

PROFILES = {
    # Player image: five PLLs, four serialisers, four TMDS outputs and the
    # menu renderer's block RAM.
    "player": {
        "PLL": 5,
        "OSER10": 4,
        "ELVDS_OBUF": 4,
        "DPB": 1,
    },
    # Stand-alone AE350 smoke: the AE350 hard block and its PLL.  No HDMI.
    "ae350": {
        "PLL": 1,
        "AE350_SOC": 1,
    },
}


def main(path: str, top: str, profile: str = "player") -> int:
    with open(path) as fh:
        doc = json.load(fh)

    module = doc.get("modules", {}).get(top)
    if module is None:
        # synth_gowin should keep the top's name, but fall back to the only
        # module if it renamed it.
        modules = doc.get("modules", {})
        if len(modules) != 1:
            print(f"top module {top!r} not found; modules: {sorted(modules)}",
                  file=sys.stderr)
            return 2
        module = next(iter(modules.values()))

    required = PROFILES.get(profile)
    if required is None:
        print(f"unknown netlist profile {profile!r}; known: {sorted(PROFILES)}",
              file=sys.stderr)
        return 2

    counts = Counter(cell.get("type") for cell in module.get("cells", {}).values())
    print(f"{top}: {len(module.get('cells', {}))} cells")
    for name in ("PLL", "AE350_SOC", "OSER10", "ELVDS_OBUF", "DPB", "DPX9B",
                 "SDPX9B", "RAM16SDP4", "ALU"):
        if counts.get(name):
            print(f"  {name:<10} {counts[name]}")

    missing = []
    for name, want in required.items():
        if counts.get(name, 0) < want:
            missing.append(f"{name}: {counts.get(name, 0)} < {want}")
    if missing:
        print("missing required primitives:", file=sys.stderr)
        for line in missing:
            print(f"  {line}", file=sys.stderr)
        print("a library instance was probably dropped by read_slang; check "
              "the --blackboxed-module list", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    if len(sys.argv) not in (3, 4):
        raise SystemExit(
            "usage: check_netlist.py <netlist.json> <top-module> [profile]"
        )
    profile = sys.argv[3] if len(sys.argv) == 4 else "player"
    sys.exit(main(sys.argv[1], sys.argv[2], profile))
