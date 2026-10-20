#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Gate the routed TinyPhosphor AE350 + 32 MiB SDRAM smoke image.

    tools/open/ae350_gates.py <routed.json> <timing.json> <nextpnr.log>

The gates are TinyNES/Tiny89's measured AE350 rules:

  * the 75 MHz AHB bus closes timing;
  * the A25 core clock takes the dedicated AE350_CORE_CLK_PLLR0 hop;
  * nextpnr routed bus_clk first, so the A25 bus takes GB10 rather than GB20;
  * no hold violations on the AE350 clocks;
  * the AE350 hard block and its PLL are present.

This is a build gate.  The hardware smoke test is the boot banner and
`SDRAM OK 32M` over the UART.
"""

import json
import re
import sys
from collections import Counter

BUS_CLOCKS = ("bus_clk", "core_clk")


def load(path):
    with open(path) as fh:
        return json.load(fh)


def top_module(doc):
    modules = doc.get("modules", {})
    if "top" in modules:
        return modules["top"]
    if len(modules) == 1:
        return next(iter(modules.values()))
    return max(modules.values(), key=lambda m: len(m.get("cells", {})))


def find_net(module, name):
    for net_name, net in module.get("netnames", {}).items():
        if net_name == name or net_name.endswith("." + name):
            return net_name, net
    return None, None


def main(routed_path, timing_path, log_path):
    routed = load(routed_path)
    timing = load(timing_path)
    log = open(log_path, errors="replace").read()
    module = top_module(routed)
    cells = module.get("cells", {})
    failures = []

    print("== timing ==")
    fmax = timing.get("fmax", {})
    bus = fmax.get("bus_clk")
    if not bus:
        failures.append("bus_clk: no timing entry")
    else:
        achieved = float(bus.get("achieved", 0))
        constraint = float(bus.get("constraint", 0))
        print(f"  bus_clk  constraint {constraint:8.3f}  achieved {achieved:8.3f}")
        if achieved + 1e-6 < 75.0:
            failures.append(f"bus_clk: {achieved:.3f} < 75.000 MHz")

    print("== AE350 clock hop ==")
    core_name, core_net = find_net(module, "core_clk")
    if not core_net:
        failures.append("core_clk net not found in the routed design")
    else:
        route = core_net.get("attributes", {}).get("ROUTING", "")
        has_hop = "AE350_CORE_CLK_PLLR0" in route
        print(f"  {core_name}: dedicated hop present={has_hop}")
        if not has_hop:
            failures.append("AE350_CORE_CLK_PLLR0 hop is absent")

    print("== clock-first ==")
    if "routing 'bus_clk' first" in log:
        print("  bus_clk routed first")
    else:
        failures.append("nextpnr did not route bus_clk first")

    print("== hold ==")
    holds = Counter(
        m.group(1)
        for m in re.finditer(r"Hold/min time violation for clock 'posedge ([^']+)'", log)
    )
    if holds:
        for clock, count in sorted(holds.items()):
            print(f"  {clock}: {count}")
        for clock in holds:
            if any(name in clock for name in BUS_CLOCKS):
                failures.append(f"hold violation on {clock}")
    else:
        print("  none")

    print("== primitives ==")
    counts = Counter(cell.get("type") for cell in cells.values())
    for name, want in (("AE350_SOC", 1), ("PLL", 1)):
        got = counts.get(name, 0)
        print(f"  {name:<12} {got} (need {want})")
        if got < want:
            failures.append(f"{name}: {got} < {want}")

    print("== PLL placement ==")
    for name, cell in cells.items():
        if cell.get("type") == "PLL":
            print(f"  {name}: {cell.get('attributes', {}).get('NEXTPNR_BEL', '?')}")

    if failures:
        print("\nGATE FAILED:")
        for failure in failures:
            print(f"  - {failure}")
        return 1
    print("\nGATE PASSED")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit(
            "usage: ae350_gates.py <routed.json> <timing.json> <nextpnr.log>"
        )
    sys.exit(main(*sys.argv[1:]))
