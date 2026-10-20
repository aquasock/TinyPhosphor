#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Gate and pack one already-routed TinyPhosphor seed.
#
#   tools/open/pack.sh <seed-dir>
#
# The gate runs again here so a hand-packed seed cannot skip it.  The output is
# tiny_phosphor.fs for openFPGALoader and tiny_phosphor.bin for tangload, plus
# content-addressed copies.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
dir=${1:-}
top=tiny_phosphor_player_top
family=GW5AST-138C
suite=${OSS_CAD_SUITE:-$HOME/oss-cad-suite}
apycula=${APICULA_FORK:-$(dirname "$root")/apicula-mathieufro}
pydeps=${PYDEPS:-$HOME/tools/pydeps}
py=${PY:-$suite/py3bin/python3}

[[ -n "$dir" && -d "$dir" ]] || { echo "usage: pack.sh <seed-dir>" >&2; exit 2; }
[[ -f "$dir/$top-routed.json" ]] || { echo "missing $dir/$top-routed.json" >&2; exit 2; }
[[ -f "$dir/timing.json" && -f "$dir/nextpnr.log" ]] || {
    echo "missing timing.json or nextpnr.log in $dir" >&2; exit 2;
}

"$py" "$root/tools/open/gates.py" \
    "$dir/$top-routed.json" "$dir/timing.json" "$dir/nextpnr.log" \
    | tee "$dir/gates.out"

# shellcheck disable=SC1090
source "$suite/environment"
export PYTHONHOME="$suite"
export PYTHONPATH="$apycula:$pydeps:${PYTHONPATH:-}"

"$py" -W ignore -m apycula.gowin_pack \
    -d "$family" \
    -o "$dir/tiny_phosphor.fs" \
    "$dir/$top-routed.json" > "$dir/pack.log" 2>&1 || {
        tail -40 "$dir/pack.log" >&2
        exit 1
    }
"$py" "$root/tools/open/fs_to_bin.py" \
    "$dir/tiny_phosphor.fs" -o "$dir/tiny_phosphor.bin" >/dev/null

sha=$(sha256sum "$dir/tiny_phosphor.fs" | cut -d' ' -f1)
cp "$dir/tiny_phosphor.fs" "$dir/tiny_phosphor.${sha:0:12}.fs"
cp "$dir/tiny_phosphor.bin" "$dir/tiny_phosphor.${sha:0:12}.bin"
sha256sum "$dir/tiny_phosphor.fs" "$dir/tiny_phosphor.bin"
echo "ready (one-wire .fs): $dir/tiny_phosphor.fs"
echo "ready (tangload .bin): $dir/tiny_phosphor.bin"
