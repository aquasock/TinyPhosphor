#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Place and route several TinyPhosphor player-only seeds from one synthesis,
# gate each, and pack the first seed that passes.
#
#   SWEEP_APPROVED=1 tools/open/sweep.sh [out-dir]
#   SWEEP_APPROVED=1 SEEDS="1 2 3 4" SWEEP_JOBS=4 tools/open/sweep.sh
#
# The approval guard is deliberate.  Placement decides whether the pixel clock
# gets a workable route on this chip, but a sweep is eight place-and-route jobs
# and several gigabytes; it is not something a build script should start by
# accident.  Set SWEEP_APPROVED=1 only when the sweep is intended.
set -euo pipefail

if [[ "${SWEEP_APPROVED:-0}" != "1" ]]; then
    cat >&2 <<'EOF'
Seed sweep blocked.

The sweep is not approved by default.  It runs several placements and packs
the first that passes every gate.  Set SWEEP_APPROVED=1 when you want it:

    SWEEP_APPROVED=1 tools/open/sweep.sh
EOF
    exit 2
fi

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
out=${1:-$root/build/open}
seeds=${SEEDS:-"1 2 3 4 5 6 7 8"}
jobs=${SWEEP_JOBS:-4}
top=tiny_phosphor_player_top
family=GW5AST-138C
suite=${OSS_CAD_SUITE:-$HOME/oss-cad-suite}
apycula=${APICULA_FORK:-$(dirname "$root")/apicula-mathieufro}
pydeps=${PYDEPS:-$HOME/tools/pydeps}
py=${PY:-$suite/py3bin/python3}

mkdir -p "$out"
"$root/tools/open/synth.sh" "$out/synth"

run_seed() {
    local seed=$1
    local dir=$out/seed-$seed
    "$root/tools/open/pnr.sh" "$out/synth/$top.json" "$dir" "$seed" \
        > "$dir/pnr.out" 2>&1 || { echo fail > "$dir/status"; return; }
    if "$py" "$root/tools/open/gates.py" \
        "$dir/$top-routed.json" "$dir/timing.json" "$dir/nextpnr.log" \
        > "$dir/gates.out" 2>&1; then
        echo pass > "$dir/status"
    else
        echo fail > "$dir/status"
    fi
}
export -f run_seed
export root out top

printf '%s\n' $seeds | xargs -P "$jobs" -I{} bash -c 'run_seed "$@"' _ {}

winner=""
for seed in $seeds; do
    status=$(cat "$out/seed-$seed/status" 2>/dev/null || echo missing)
    printf '  seed %-3s %s\n' "$seed" "$status"
    if [[ "$status" == pass && -z "$winner" ]]; then
        winner=$seed
    fi
done

if [[ -z "$winner" ]]; then
    echo "no seed passed every gate; nothing packed" >&2
    exit 1
fi

echo "packing first passing seed: $winner"
# shellcheck disable=SC1090
source "$suite/environment"
export PYTHONHOME="$suite"
export PYTHONPATH="$apycula:$pydeps:${PYTHONPATH:-}"
dir=$out/seed-$winner
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
echo "winner: seed $winner"
