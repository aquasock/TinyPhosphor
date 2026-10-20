#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Build the stand-alone TinyPhosphor AE350 + 32 MiB SDRAM smoke image.
#
#   tools/open/ae350_smoke.sh [out-dir]
#   SEED=2 tools/open/ae350_smoke.sh
#
# One seed at a time.  The image boots the AE350 from its block-RAM boot ROM,
# tests the 64 KiB block RAM and the 32 MiB J9 SDRAM, and prints the banner
# over the EXTS UART.  It has no player, HDMI, PMOD or DDR3.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
out=${1:-$root/build/ae350_smoke}
seed=${SEED:-1}
top=tiny_phosphor_ae350_sdram_top

echo "boot ROM"
make -C "$root/firmware/boot"
[[ -f "$root/build/firmware/boot/boot.hex" ]] || {
    echo "missing boot.hex" >&2; exit 1;
}

export TOP="$top"
export SOURCES="$root/tools/open/ae350_sources.f"
export CST="$root/src/boards/console138k_ae350_sdram.cst"
export SDC="$root/src/boards/console138k_ae350_sdram.sdc"
export FREQ=75
export NETLIST_PROFILE=ae350
export NPNR_GOWIN_CLK_FIRST=bus_clk
export GATES="$root/tools/open/ae350_gates.py"
export ARTIFACT=tiny_phosphor_ae350_smoke

mkdir -p "$out"
"$root/tools/open/synth.sh" "$out/synth"
"$root/tools/open/pnr.sh" "$out/synth/$top.json" "$out/seed-$seed" "$seed"
"$root/tools/open/pack.sh" "$out/seed-$seed"
