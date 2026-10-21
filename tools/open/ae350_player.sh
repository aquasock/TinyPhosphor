#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Build the TinyPhosphor player + AE350 + 32 MiB SDRAM image.
#
#   tools/open/ae350_player.sh [out-dir]
#   SEED=2 tools/open/ae350_player.sh
#
# One seed at a time.  The AE350 owns PLL_R[0]; the HDMI chain and audio
# PLLs are placed by src/boards/console138k_ae350_player.cst.  The image has
# the player's HDMI menu and the AE350 boot ROM with its stream loader.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
out=${1:-$root/build/ae350_player}
seed=${SEED:-1}
top=tiny_phosphor_ae350_player_top

echo "AE350 boot ROM"
make -C "$root/firmware/ae350" \
    CROSS="${RISCV_CROSS:-$HOME/tools/xpack-riscv-none-elf-gcc-15.2.0-1/bin/riscv-none-elf-}"
[[ -f "$root/build/ae350/boot/ae350_boot.hex" ]] || {
    echo "missing ae350_boot.hex" >&2; exit 1;
}
# The ROM is baked into the bitstream, so record which one this build used:
# a stale hex once shipped in a qualified image that HEAD did not reproduce.
mkdir -p "$out"
sha256sum "$root/build/ae350/boot/ae350_boot.hex" | tee "$out/boot_rom.sha256"

export TOP="$top"
export SOURCES="$root/tools/open/ae350_player_sources.f"
export CST="$root/src/boards/console138k_ae350_player.cst"
export SDC="$root/src/boards/console138k_ae350_player.sdc"
export FREQ=75
export NETLIST_PROFILE=ae350_player
export NPNR_GOWIN_CLK_FIRST=bus_clk
export GATES="$root/tools/open/ae350_player_gates.py"
export ARTIFACT=tiny_phosphor_ae350_player

mkdir -p "$out"
"$root/tools/open/synth.sh" "$out/synth"
"$root/tools/open/pnr.sh" "$out/synth/$top.json" "$out/seed-$seed" "$seed"
"$root/tools/open/pack.sh" "$out/seed-$seed"
