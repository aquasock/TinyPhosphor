#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Place and route one TinyPhosphor player-only seed with the fork's
# nextpnr-himbaechel.
#
#   tools/open/pnr.sh <netlist.json> <out-dir> <seed>
#
# The fork is required: oss-cad-suite's nextpnr carries the published
# GW5AST-138C database, which has no PLL site and no clock pips for this part.
# The build stops rather than pretending the published database is enough.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
netlist=${1:-}
out=${2:-}
seed=${3:-1}
suite=${OSS_CAD_SUITE:-$HOME/oss-cad-suite}
apycula=${APICULA_FORK:-$(dirname "$root")/apicula-mathieufro}
pydeps=${PYDEPS:-$HOME/tools/pydeps}
nextpnr=${NEXTPNR_HIMBAECHEL:-$HOME/tools/nextpnr-mathieufro/nextpnr-himbaechel}
device=GW5AST-LV138PG484AC1/I0
top=tiny_phosphor_player_top
cst=$root/src/boards/console138k_player.cst
sdc=$root/src/boards/console138k_player.sdc

[[ -n "$netlist" && -f "$netlist" ]] || {
    echo "usage: pnr.sh <netlist.json> <out-dir> <seed>" >&2; exit 2;
}
[[ -n "$out" ]] || { echo "missing out-dir" >&2; exit 2; }
[[ -f "$suite/environment" ]] || { echo "missing open toolchain: $suite" >&2; exit 2; }
# shellcheck disable=SC1090
source "$suite/environment"
export PYTHONHOME="$suite"
export PYTHONPATH="$apycula:$pydeps:${PYTHONPATH:-}"

case "$nextpnr" in
    */oss-cad-suite/*)
        cat >&2 <<'EOF'
NEXTPNR_HIMBAECHEL points at oss-cad-suite's nextpnr-himbaechel.  That build
carries the published GW5AST-138C database, which has no PLL site and no clock
pips for this device, so it cannot place this core.  Point it at the fork.
EOF
        exit 2
        ;;
esac
[[ -x "$nextpnr" ]] || { echo "missing fork nextpnr: $nextpnr" >&2; exit 2; }
[[ -f "$apycula/apycula/GW5AST-138C.msgpack.xz" ]] || {
    echo "missing Apicula GW5AST-138C database under $apycula/apycula" >&2; exit 2;
}

mkdir -p "$out"
# nextpnr's SDC reader rejects C++-style comments.
sed 's|^\([[:space:]]*\)//|\1#|' "$sdc" > "$out/player.sdc"

echo "nextpnr: $nextpnr"
echo "seed: $seed"
"$nextpnr" \
    --json "$netlist" \
    --write "$out/$top-routed.json" \
    --device "$device" \
    --freq 50 \
    --vopt cst="$cst" \
    --sdc "$out/player.sdc" \
    --report "$out/timing.json" \
    --seed "$seed" \
    --timing-allow-fail \
    ${NEXTPNR_PLACER:+--placer "$NEXTPNR_PLACER"} \
    > "$out/nextpnr.log" 2>&1 || {
        tail -80 "$out/nextpnr.log" >&2
        if grep -q "no BELs remaining to implement cell type 'PLL'" "$out/nextpnr.log"; then
            cat >&2 <<'EOF'

The design is fine; the binary is wrong.  "no BELs remaining to implement cell
type 'PLL'" means the nextpnr binary was built against the published
GW5AST-138C database, not the fork's regenerated one.
EOF
        fi
        exit 1
    }

echo "routed: $out/$top-routed.json"
echo "timing: $out/timing.json"
