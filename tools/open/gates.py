#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Gate a routed TinyPhosphor player seed before it is packed.

    tools/open/gates.py <routed.json> <timing.json> <nextpnr.log>

The gates are the ones the sibling projects paid for on this board:

  * setup on the pixel clock, plus the USB clock when nextpnr reports it;
  * no hold violation on the pixel clock;
  * every two-clock-capable block RAM rejected, because it reads back wrong;
  * five PLLs and four OSER10s present;
  * the pixel clock and the serial clock on the dedicated clock network, with
    no SPINE17 route.

nextpnr has no I/O or IOLOGIC timing model on this device, so the 371.25 MHz
serial clock and the board/reference clocks may have no Fmax entry.  They are
reported as unmeasured, not failed; the serial clock is covered by its route.
"""

import json
import re
import sys
from collections import Counter

REQUIRED_CLOCKS = {
    "clk_pixel": 74.25,
    "clk12": 12.0,
}
OPTIONAL_CLOCKS = {
    "clk50": 50.0,
    "clk27": 27.0,
    "clk_pixel_x5": 371.25,
    "clk_i2s2_ref": 24.0,
    "clk_i2s2_mclk": 12.288,
}
BRAM_TYPES = {"DP", "SDP", "DPB", "DPX9B", "SDPX9B", "SDPB"}
PIXEL_CLOCK_NAMES = ("audio_player.clk", "clk_pixel", "pixel_div")


def load_json(path):
    with open(path) as fh:
        return json.load(fh)


def top_module(doc):
    modules = doc.get("modules", {})
    if "top" in modules:
        return modules["top"]
    if len(modules) == 1:
        return next(iter(modules.values()))
    return max(modules.values(), key=lambda m: len(m.get("cells", {})))


def fmax_entries(timing):
    return timing.get("fmax", {})


def by_name(entries, name):
    if name in entries:
        return entries[name]
    for key, value in entries.items():
        if key.endswith("." + name) or key.endswith("/" + name):
            return value
    return None


def by_constraint(entries, mhz, tolerance=0.1):
    hits = []
    for value in entries.values():
        try:
            constraint = float(value.get("constraint", -1))
        except (TypeError, ValueError):
            continue
        if abs(constraint - mhz) <= tolerance:
            hits.append(value)
    return max(hits, key=lambda v: float(v.get("achieved", 0))) if hits else None


def net_for_pin(module, cell_name, pin):
    cell = module.get("cells", {}).get(cell_name)
    if not cell:
        return None, None
    bits = cell.get("connections", {}).get(pin)
    if not bits:
        return None, None
    bit = bits[0]
    for name, net in module.get("netnames", {}).items():
        if bit in net.get("bits", []):
            return name, net
    return None, None


def route_of(net):
    return net.get("attributes", {}).get("ROUTING", "") if net else ""


def main(routed_path, timing_path, log_path):
    routed = load_json(routed_path)
    timing = load_json(timing_path)
    log = open(log_path, errors="replace").read()
    module = top_module(routed)
    cells = module.get("cells", {})
    entries = fmax_entries(timing)
    failures = []
    notes = []

    print("== timing ==")
    for name, wanted in REQUIRED_CLOCKS.items():
        entry = by_name(entries, name) or by_constraint(entries, wanted)
        if not entry:
            failures.append(f"{name}: no timing entry at {wanted} MHz")
            continue
        achieved = float(entry.get("achieved", 0))
        constraint = float(entry.get("constraint", 0))
        print(f"  {name:<14} constraint {constraint:8.3f}  achieved {achieved:8.3f}")
        if achieved + 1e-6 < wanted:
            failures.append(f"{name}: achieved {achieved:.3f} < {wanted:.3f} MHz")
    for name, wanted in OPTIONAL_CLOCKS.items():
        entry = by_name(entries, name) or by_constraint(entries, wanted, 0.2)
        if not entry:
            notes.append(f"{name}: not timed by nextpnr (reported unmeasured)")
            continue
        achieved = float(entry.get("achieved", 0))
        print(f"  {name:<14} constraint {float(entry.get('constraint', 0)):8.3f}"
              f"  achieved {achieved:8.3f}  (optional)")
        if achieved + 1e-6 < wanted:
            notes.append(f"{name}: {achieved:.3f} < {wanted:.3f} MHz")

    print("== hold ==")
    hold_counts = Counter(
        m.group(1)
        for m in re.finditer(r"Hold/min time violation for clock 'posedge ([^']+)'", log)
    )
    pixel_holds = 0
    for clock, count in sorted(hold_counts.items()):
        is_pixel = any(token in clock for token in PIXEL_CLOCK_NAMES)
        print(f"  {clock}: {count}" + ("  (pixel)" if is_pixel else "  (other)"))
        if is_pixel:
            pixel_holds += count
    if pixel_holds:
        failures.append(f"{pixel_holds} hold violations on the pixel clock")
    elif not hold_counts:
        print("  none")

    print("== block RAM ==")
    two_clock = []
    bram_count = 0
    for name, cell in cells.items():
        if cell.get("type") not in BRAM_TYPES:
            continue
        conn = cell.get("connections", {})
        clka, clkb = conn.get("CLKA"), conn.get("CLKB")
        if clka is None or clkb is None:
            continue
        bram_count += 1
        if clka != clkb:
            two_clock.append(name)
    print(f"  {bram_count} two-clock-capable block RAMs checked")
    if two_clock:
        for name in two_clock[:8]:
            print(f"  two clocks: {name}")
        failures.append(f"{len(two_clock)} block RAMs have CLKA != CLKB")

    print("== primitives ==")
    counts = Counter(cell.get("type") for cell in cells.values())
    for name, want in (("PLL", 5), ("OSER10", 4)):
        got = counts.get(name, 0)
        print(f"  {name:<12} {got} (need {want})")
        if got < want:
            failures.append(f"{name}: {got} < {want}")

    print("== PLL placement ==")
    for name, cell in cells.items():
        if cell.get("type") != "PLL":
            continue
        bel = cell.get("attributes", {}).get("NEXTPNR_BEL", "?")
        print(f"  {name:<34} {bel}")

    print("== clock routes ==")
    for label, cell_name, pin, max_hops in (
        ("clk_pixel", "core.pixel_div", "CLKOUT", 50000),
        ("clk_pixel_x5", "core.clock_hdmi.PLL_inst", "CLKOUT1", 200),
    ):
        net_name, net = net_for_pin(module, cell_name, pin)
        if not net:
            failures.append(f"{label}: no routed net from {cell_name}/{pin}")
            continue
        route = route_of(net)
        hops = len(route.split(";")) // 3
        dedicated = any(token in route for token in ("HCLK", "CBRIDGEOUT", "SPINE"))
        print(f"  {label}: net {net_name}, {hops} hops, dedicated={dedicated}")
        if not dedicated:
            failures.append(f"{label}: not on a clock-network route")
        if hops > max_hops:
            failures.append(f"{label}: {hops} hops exceeds {max_hops}")
        if "SPINE17" in route:
            failures.append(f"{label}: routes through SPINE17")

    if notes:
        print("== notes ==")
        for note in notes:
            print(f"  {note}")

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
            "usage: gates.py <routed.json> <timing.json> <nextpnr.log>"
        )
    sys.exit(main(*sys.argv[1:]))
