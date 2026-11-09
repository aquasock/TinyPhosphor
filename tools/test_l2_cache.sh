#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Run the second-level cache testbench at both geometries.
#
#   tools/test_l2_cache.sh
#
# 16 lines exercises aliasing in a short run; 2048 lines is the shipped 64 KiB
# and is tested with the same checks.  The testbench compares every read
# against a model memory rather than only counting hits, because a cache that
# returns the wrong word quickly passes a hit-rate test -- which is exactly
# how the two faults it found first hid.
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
suite="${OSS_CAD_SUITE:-$HOME/oss-cad-suite}"
out="$root/build/l2"
mkdir -p "$out"

run() {
    local lines=$1 tag=$2 name=$3
    echo "== $name"
    "$suite/bin/iverilog" -g2012 -Ptb_l2.LINES="$lines" \
        -o "$out/$tag" "$root/sim/tb_l2_cache.sv" "$root/src/ae350/ae350_l2_cache.sv"
    "$suite/bin/vvp" "$out/$tag" | tail -8
}

run 16   tb_l2 "16 lines (aliasing)"
run 2048 tb_l2_2048 "2048 lines (shipped 64 KiB)"
