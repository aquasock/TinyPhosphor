# TinyPhosphor open-flow build

This document covers the open FPGA flow itself and the player-only bring-up
profile it was first proven on. The **shipped** configuration is the AE350
player, which adds the AE350 hard core, its 32 MiB SDRAM, the stream loader
and Rockbox: build it with `tools/open/ae350_player.sh` and sweep it with
`tools/open/ae350_player_sweep.sh`, as the README describes. The player-only
profile below (`tools/open/build.sh`) remains useful as the smallest design
that exercises HDMI, the scope and the I2S2 pair without the CPU, and as a
diagnostic when the AE350 build will not place.

Everything here uses Yosys, the GW5AST-138C nextpnr fork and Apicula's
`gowin_pack`; Gowin EDA is not in the build path.

The player-only profile's acceptance gate was HDMI video: the 96x64
address-encoded menu frame scaled to 1280x720. Audio was best-effort there;
the AE350 image is where audio is qualified.

## Toolchain

The scripts default to the local installation and can be overridden by
environment variables:

- `OSS_CAD_SUITE` — oss-cad-suite, default `$HOME/oss-cad-suite`.
- `NEXTPNR_HIMBAECHEL` — the fork's nextpnr, default
  `$HOME/tools/nextpnr-mathieufro/nextpnr-himbaechel`.
- `APICULA_FORK` — the Apicula fork, default `../apicula-mathieufro`.
- `PYDEPS` — Python dependencies, default `$HOME/tools/pydeps`.

The fork's GW5AST-138C database is generated from Gowin EDA 1.9.11.03's device
files and is not redistributable.  The published oss-cad-suite database has no
PLL site and no clock pips for this part and cannot place this core.

## Build one seed

Player-only profile:

```sh
tools/open/build.sh
# or
SEED=3 tools/open/build.sh build/open
```

Shipped AE350 player, which also builds the boot ROM and writes the ROM's
SHA-256 beside the artifacts:

```sh
SEED=1 tools/open/ae350_player.sh build/ae350_player
```

Each runs synthesis, one place-and-route, the gates, packing, and `.bin`
conversion, and refuses to start a sweep.

## Seed sweep

Placement decides whether the pixel clock gets a workable route on this chip,
so the normal hardware build is a seed sweep.  It is deliberately blocked
unless explicitly approved:

```sh
SWEEP_APPROVED=1 tools/open/sweep.sh
SWEEP_APPROVED=1 SEEDS="1 2 3 4 5 6 7 8" SWEEP_JOBS=4 tools/open/sweep.sh
```

The sweep synthesises once, places and routes each seed in its own directory,
gates every result, and packs the first seed that passes.  A timing-clean seed
that routes `clk_pixel` through `SPINE17` is refused.

## Gates

`tools/open/gates.py` checks the player-only profile and
`tools/open/ae350_gates.py` and `tools/open/ae350_player_gates.py` the AE350
images. Between them:

- `clk_pixel` at 74.25 MHz and `clk_pixel_x5` at 371.25 MHz, plus 50, 27 and
  12 MHz on the board, pixel and USB clocks, and `bus_clk` at 75 MHz in the
  AE350 images;
- zero hold violations, which nextpnr reports only in its log;
- every two-clock-capable block RAM has `CLKA == CLKB` (two-clock block RAM
  reads back wrong on this chip in the open flow);
- five PLLs and four OSER10s in the player-only profile, six PLLs and the
  AE350 hard block in the AE350 images;
- no `clk_pixel` or `clk_pixel_x5` route through `SPINE17`, and in the AE350
  images the `AE350_CORE_CLK_PLLR0` dedicated hop present with no GB20 branch
  on `bus_clk` — a bus clock that reaches a sink through GB20 kills the A25;
- `tools/open/check_netlist.py` refuses a netlist that still carries generic
  `$` cells, which is what a mismatched Yosys front end produces.

## Artifacts

Under `build/open/seed-<n>/`:

- `tiny_phosphor.fs` — one-wire SRAM load with `openFPGALoader`.
- `tiny_phosphor.bin` — the same bits packed eight to a byte, for TinyTang's
  `tangload` from `/root/cores/console138k/`.
- `tiny_phosphor.<sha12>.fs` and `.bin` — content-addressed copies.
- `timing.json`, `nextpnr.log`, `gates.out` — the evidence for the gate.

## Limits of the player-only profile

These apply to `tools/open/build.sh` and its output, not to the shipped AE350
player, which carries its own gates and was qualified on hardware.

- `src/ae350/ae350_stub.sv` replaces the AE350 subsystem, so the image does
  not run Rockbox, MP3, or any AE350 program.  `cpu_mode` resets to zero, so
  the FPGA player owns the stream path.
- The DDR3 ports are not exposed by `tiny_phosphor_player_top`; the merged
  DDR3 image is a later problem.
- The I2S2 PLLs are on the left edge.  If the left clock plane misbehaves,
  HDMI video can still pass; audio needs its own cycle.
- The display store currently infers 4-bit DPBs.  They are single-clock, which
  avoids the open-flow two-clock failure, but the 9-bit mode rule is not yet
  enforced on them.  A corrupted menu pattern points here first.
- No hardware result exists for this profile beyond its first HDMI acceptance;
  the qualified images are the AE350 player's, recorded in `.ai/core-log.md`.

## Provenance

`src/` is vendored from Tang-Phosphor at
`c261fcb03538fa980d2ef296d9e910842cbcbc3e`.  The build scripts are adapted from
TinyTang's `tools/desktop_open/`, with the MIT notice retained in
`THIRD_PARTY.md`.  `tools/open/fs_to_bin.py` is TinyNES's copy of TinyTang's
converter, also MIT.
