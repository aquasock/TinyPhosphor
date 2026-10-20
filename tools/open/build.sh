#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Build one TinyPhosphor player-only seed end to end: synthesis, place and
# route, gates, pack, and the .bin conversion.
#
#   tools/open/build.sh [out-dir]
#   SEED=3 tools/open/build.sh build/open
#
# This script deliberately builds ONE seed.  The seed sweep is a separate
# command, tools/open/sweep.sh, and it refuses to run without an explicit
# SWEEP_APPROVED=1.  That keeps a review from accidentally launching eight
# placements.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
out=${1:-$root/build/open}
seed=${SEED:-1}
top=tiny_phosphor_player_top
family=GW5AST-138C
suite=${OSS_CAD_SUITE:-$HOME/oss-cad-suite}
apycula=${APICULA_FORK:-$(dirname "$root")/apicula-mathieufro}
pydeps=${PYDEPS:-$HOME/tools/pydeps}
py=${PY:-$suite/py3bin/python3}

if [[ -n "${SEEDS:-}" || "${SWEEP:-0}" == "1" ]]; then
    cat >&2 <<'EOF'
build.sh builds one seed.  The seed sweep is tools/open/sweep.sh, and it
requires SWEEP_APPROVED=1.  Refusing to start a sweep from here.
EOF
    exit 2
fi

mkdir -p "$out"
"$root/tools/open/synth.sh" "$out/synth"
"$root/tools/open/pnr.sh" "$out/synth/$top.json" "$out/seed-$seed" "$seed"
"$py" "$root/tools/open/gates.py" \
    "$out/seed-$seed/$top-routed.json" \
    "$out/seed-$seed/timing.json" \
    "$out/seed-$seed/nextpnr.log"

echo "packing seed $seed"
# shellcheck disable=SC1090
source "$suite/environment"
export PYTHONHOME="$suite"
export PYTHONPATH="$apycula:$pydeps:${PYTHONPATH:-}"
"$py" -W ignore -m apycula.gowin_pack \
    -d "$family" \
    -o "$out/seed-$seed/tiny_phosphor.fs" \
    "$out/seed-$seed/$top-routed.json" \
    > "$out/seed-$seed/pack.log" 2>&1 || {
        tail -40 "$out/seed-$seed/pack.log" >&2
        exit 1
    }
"$py" "$root/tools/open/fs_to_bin.py" \
    "$out/seed-$seed/tiny_phosphor.fs" \
    -o "$out/seed-$seed/tiny_phosphor.bin" >/dev/null

sha=$(sha256sum "$out/seed-$seed/tiny_phosphor.fs" | cut -d' ' -f1)
cp "$out/seed-$seed/tiny_phosphor.fs" "$out/seed-$seed/tiny_phosphor.${sha:0:12}.fs"
cp "$out/seed-$seed/tiny_phosphor.bin" "$out/seed-$seed/tiny_phosphor.${sha:0:12}.bin"
sha256sum "$out/seed-$seed/tiny_phosphor.fs" "$out/seed-$seed/tiny_phosphor.bin"
echo "ready (one-wire .fs): $out/seed-$seed/tiny_phosphor.fs"
echo "ready (tangload .bin): $out/seed-$seed/tiny_phosphor.bin"
