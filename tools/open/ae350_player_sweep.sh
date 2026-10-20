#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Sweep the AE350 player design across placement seeds.
#
#   SWEEP_APPROVED=1 tools/open/ae350_player_sweep.sh
#   SWEEP_APPROVED=1 SWEEP_JOBS=4 SEEDS="1 2 3 4" tools/open/ae350_player_sweep.sh
#
# The netlist is synthesised once (or reused when present); each seed gets its
# own place-and-route directory.  Every seed is gated with the player and AE350
# checks, including the GB10/GB20 bus-clock rule.  The best passing seed is
# packed; nothing is deployed.
set -euo pipefail

if [[ "${SWEEP_APPROVED:-0}" != "1" ]]; then
    cat >&2 <<'EOF'
AE350 player sweep blocked.  Set SWEEP_APPROVED=1 when the sweep is intended.
EOF
    exit 2
fi

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
out=${1:-$root/build/ae350_player}
seeds=${SEEDS:-"1 2 3 4 5 6 7 8"}
jobs=${SWEEP_JOBS:-4}
top=tiny_phosphor_ae350_player_top
netlist=${NETLIST:-$out/synth/$top.json}
suite=${OSS_CAD_SUITE:-$HOME/oss-cad-suite}
apycula=${APICULA_FORK:-$(dirname "$root")/apicula-mathieufro}
pydeps=${PYDEPS:-$HOME/tools/pydeps}
py=${PY:-$suite/py3bin/python3}
artifact=tiny_phosphor_ae350_player

[[ -f "$netlist" ]] || { echo "missing netlist: $netlist" >&2; exit 2; }

export TOP="$top"
export CST="$root/src/boards/console138k_ae350_player.cst"
export SDC="$root/src/boards/console138k_ae350_player.sdc"
export FREQ=75
export NPNR_GOWIN_CLK_FIRST=bus_clk

mkdir -p "$out/sweep"
netlist_sha=$(sha256sum "$netlist" | cut -d' ' -f1)
echo "netlist $netlist_sha"
echo "seeds: $seeds  jobs: $jobs"

run_seed() {
    local seed=$1
    local dir=$out/sweep/seed-$seed
    mkdir -p "$dir"
    if "$root/tools/open/pnr.sh" "$netlist" "$dir" "$seed" \
        > "$dir/pnr.out" 2>&1; then
        if "$py" "$root/tools/open/ae350_player_gates.py" \
            "$dir/$TOP-routed.json" "$dir/timing.json" "$dir/nextpnr.log" \
            > "$dir/gates.out" 2>&1; then
            echo pass > "$dir/status"
        else
            echo fail > "$dir/status"
        fi
    else
        echo fail > "$dir/status"
    fi
}
export -f run_seed
export root out netlist top py

printf '%s\n' $seeds | xargs -P "$jobs" -I{} bash -c 'run_seed "$@"' _ {}

"$py" - "$out/sweep" $seeds <<'PY'
import json
import pathlib
import sys

base = pathlib.Path(sys.argv[1])
rows = []
for seed in sys.argv[2:]:
    d = base / f"seed-{seed}"
    status = (d / "status").read_text().strip() if (d / "status").exists() else "missing"
    bus = pixel = 0.0
    gb20 = "?"
    try:
        t = json.loads((d / "timing.json").read_text())["fmax"]
        for key, value in t.items():
            if key == "bus_clk" or key.endswith(".bus_clk"):
                bus = float(value["achieved"])
        pixel = min(float(v["achieved"]) for v in t.values()
                    if abs(float(v["constraint"]) - 74.25) < 0.05)
    except (OSError, KeyError, ValueError):
        pass
    try:
        gates = (d / "gates.out").read_text()
        gb20 = "yes" if "GB20 branch present=True" in gates else "no"
    except OSError:
        pass
    rows.append((seed, status, bus, pixel, gb20))

print("seed\tstatus\tbus_mhz\tpixel_mhz\tgb20")
for row in rows:
    print(f"{row[0]}\t{row[1]}\t{row[2]:.2f}\t{row[3]:.2f}\t{row[4]}")
(base / "results.tsv").write_text(
    "seed\tstatus\tbus_mhz\tpixel_mhz\tgb20\n" +
    "".join(f"{r[0]}\t{r[1]}\t{r[2]:.2f}\t{r[3]:.2f}\t{r[4]}\n" for r in rows))

passing = [r for r in rows if r[1] == "pass"]
if not passing:
    raise SystemExit(1)
# Best margin on the two constrained clocks, then seed order.
passing.sort(key=lambda r: (-min(r[2] / 75.0, r[3] / 74.25), int(r[0])))
print(f"winner\t{passing[0][0]}")
(base / "winner").write_text(str(passing[0][0]) + "\n")
PY
winner=$(cat "$out/sweep/winner")
echo "packing seed $winner"
TOP="$top" GATES="$root/tools/open/ae350_player_gates.py" \
    ARTIFACT="$artifact" "$root/tools/open/pack.sh" "$out/sweep/seed-$winner"
