#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Synthesise the TinyPhosphor player-only core with the open flow.
#
#   tools/open/synth.sh [out-dir]
#
# The source list is tools/open/sources.f.  The open-flow front end is
# read_slang, not read_verilog: the vendored SystemVerilog uses unpacked-array
# ports that Yosys's classic front end rejects.  The Gowin cell libraries are
# passed with -v and every primitive the design instantiates is named again
# with --blackboxed-module; without that, the primitive is dropped silently.
#
# No GowinSynthesis is invoked.  Gowin EDA is needed only to regenerate the
# GW5AST-138C device database used by nextpnr and Apicula.
set -euo pipefail
# comm(1) and sort(1) need byte order, not the locale's collation.
export LC_ALL=C

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
out=${1:-$root/build/open/synth}
suite=${OSS_CAD_SUITE:-$HOME/oss-cad-suite}
top=${TOP:-tiny_phosphor_player_top}
family=${FAMILY:-gw5a}
src_list=${SOURCES:-$root/tools/open/sources.f}

[[ -f "$src_list" ]] || { echo "missing source list: $src_list" >&2; exit 2; }
[[ -f "$suite/environment" ]] || { echo "missing open toolchain: $suite" >&2; exit 2; }
# shellcheck disable=SC1090
source "$suite/environment"

# oss-cad-suite's environment script unsets PYTHONHOME.  Yosys and nextpnr's
# embedded Python need it back.
export PYTHONHOME="$suite"

datdir=$(yosys-config --datdir 2>/dev/null || true)
[[ -n "${datdir:-}" && -d "$datdir/gowin" ]] || \
    datdir=$(cd "$(dirname "$(command -v yosys)")/../share/yosys" 2>/dev/null && pwd)
[[ -n "${datdir:-}" && -d "$datdir/gowin" ]] || {
    echo "cannot find yosys's Gowin cell library under $datdir/gowin" >&2
    exit 2
}

mkdir -p "$out/shim"
shim=$out/shim

# slang rejects the specify blocks in cells_sim.v; timing checks are
# meaningless at synthesis time anyway.
awk '/^[[:space:]]*specify[[:space:]]*$/ { skip=1 }
     !skip { print }
     /^[[:space:]]*endspecify[[:space:]]*$/ { skip=0 }' \
    "$datdir/gowin/cells_sim.v" > "$shim/cells_sim_nospecify.v"
cp "$datdir/gowin/cells_xtra_gw5a.v" "$shim/cells_xtra_gw5a.v"

# Derive the blackbox list from the cell libraries and the design sources.
# The list is a superset: blackboxing a module the design never instantiates
# is a no-op, while under-collecting silently drops a primitive.
libmods=$(grep -hoE '^[[:space:]]*module [A-Za-z_][A-Za-z0-9_]*' "$shim"/cells_*.v \
          | awk '{print $2}' | sort -u)
dnames=$(grep -rhoE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*' "$root/src" \
              --include=*.v --include=*.sv 2>/dev/null \
         | sed 's/^[[:space:]]*//' | sort -u)
bb=$(comm -12 <(echo "$libmods") <(echo "$dnames")) || true
[[ -n "$bb" ]] || { echo "no cell-library module begins a line in the design" >&2; exit 1; }
bbflags=$(echo "$bb" | sed 's/^/--blackboxed-module /' | paste -sd' ')

echo "yosys: $(command -v yosys) ($(yosys --version 2>/dev/null | head -1))"
echo "Gowin cell library: $datdir/gowin"
echo "blackboxing $(echo "$bb" | wc -l) of $(echo "$libmods" | wc -l) library modules"

mapfile -t sources < "$src_list"
{
    printf '%s\n' "read_slang --std 1800-2017 -U SYNTHESIS -D GW_IDE \\"
    printf '%s\n' "    --allow-use-before-declare --allow-lib-module-redef \\"
    printf '%s\n' "    $bbflags \\"
    printf '%s\n' "    -v $shim/cells_sim_nospecify.v \\"
    printf '%s\n' "    -v $shim/cells_xtra_gw5a.v \\"
    printf '%s\n' "    -I $root/src -I $root/src/hdmi -I $root/src/pll \\"
    printf '%s\n' "    -I $root/src/ui -I $root/src/audio -I $root/src/iosys \\"
    printf '%s\n' "    -I $root/src/assets \\"
    for f in "${sources[@]}"; do
        printf '    %q \\\n' "$root/$f"
    done
    printf '\n'
    printf 'synth_gowin -top %s -family %s\n' "$top" "$family"
    printf 'write_json %s/%s.json\n' "$out" "$top"
    printf 'stat\n'
} > "$out/synth.ys"

cd "$root"
echo "synthesising $top from ${#sources[@]} sources into $out/$top.json"
yosys -Q -T -l "$out/synth.log" -s "$out/synth.ys"

python3 "$root/tools/open/pll_strings.py" "$out/$top.json"
python3 "$root/tools/open/check_netlist.py" "$out/$top.json" "$top" "${NETLIST_PROFILE:-player}"

echo "netlist: $out/$top.json"
