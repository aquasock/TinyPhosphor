# TinyPhosphor open-flow build

The first TinyPhosphor image is the vendored Tang-Phosphor player without the
AE350 and DDR3 subsystem.  It is built with Yosys, the GW5AST-138C nextpnr
fork, and Apicula's `gowin_pack`; Gowin EDA is not in the build path.  The
first image's acceptance gate is HDMI video: the 96x64 address-encoded menu
frame scaled to 1280x720.  Audio is present but best-effort.

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

```sh
tools/open/build.sh
# or
SEED=3 tools/open/build.sh build/open
```

This runs synthesis, one place-and-route, the gates, packing, and `.bin`
conversion.  It refuses to start a sweep.

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

`tools/open/gates.py` checks:

- `clk_pixel` at 74.25 MHz and `clk_pixel_x5` at 371.25 MHz, plus 50, 27 and
  12 MHz on the board, pixel and USB clocks;
- zero hold violations, which nextpnr reports only in its log;
- every two-clock-capable block RAM has `CLKA == CLKB` (two-clock block RAM
  reads back wrong on this chip in the open flow);
- five PLLs and four OSER10s are present;
- no `clk_pixel` or `clk_pixel_x5` route through `SPINE17`.

The I2S2 clocks are reported but not gating: the first image's audio is
best-effort, and the I2S2 PLLs are on the left edge.

## Artifacts

Under `build/open/seed-<n>/`:

- `tiny_phosphor.fs` — one-wire SRAM load with `openFPGALoader`.
- `tiny_phosphor.bin` — the same bits packed eight to a byte, for TinyTang's
  `tangload` from `/root/cores/console138k/`.
- `tiny_phosphor.<sha12>.fs` and `.bin` — content-addressed copies.
- `timing.json`, `nextpnr.log`, `gates.out` — the evidence for the gate.

## Known limitations of the first image

- `src/ae350/ae350_stub.sv` replaces the AE350 subsystem.  The image does not
  run Rockbox, MP3, or any AE350 program.  `cpu_mode` resets to zero, so the
  FPGA player owns the stream path.
- The DDR3 ports are not exposed by `tiny_phosphor_player_top`; the merged
  DDR3 image is a later problem.
- The I2S2 PLLs are on the left edge.  If the left clock plane misbehaves,
  HDMI video can still pass; audio needs its own cycle.
- The display store currently infers 4-bit DPBs.  They are single-clock, which
  avoids the open-flow two-clock failure, but the 9-bit mode rule is not yet
  enforced on them.  A corrupted menu pattern points here first.
- No hardware result exists for this image until the board test is recorded in
  `.ai/core-log.md`.

## Provenance

`src/` is vendored from Tang-Phosphor at
`c261fcb03538fa980d2ef296d9e910842cbcbc3e`.  The build scripts are adapted from
TinyTang's `tools/desktop_open/`, with the MIT notice retained in
`THIRD_PARTY.md`.  `tools/open/fs_to_bin.py` is TinyNES's copy of TinyTang's
converter, also MIT.
