# AE350 + 32 MiB SDRAM smoke

This is the first AE350 image in TinyPhosphor's open-flow tree. It is a
stand-alone platform test, not the player: no HDMI, PMOD, DDR3 or Rockbox.

## What it proves

The AE350 hard block boots from the 32 KiB block-RAM boot ROM, uses the 64 KiB
block RAM at `0x60000000` for data and stack, and tests the dock's 32 MiB J9
SDRAM at `0x40000000`. The boot ROM prints over the EXTS UART at 2 Mbaud:

```
TinyPhosphor AE350 boot ROM
TinyPhosphor AE350 C OK UNC=<cycles> CAC=<cycles>
TinyPhosphor SDRAM OK 32M
TinyNES LOAD
```

## Build

```sh
tools/open/ae350_smoke.sh
SEED=2 tools/open/ae350_smoke.sh
```

The script builds `firmware/boot/boot.hex`, synthesises
`tiny_phosphor_ae350_sdram_top` with `read_slang`, places and routes one seed
with `NPNR_GOWIN_CLK_FIRST=bus_clk`, gates the result, and packs it.

## Gates

`tools/open/ae350_gates.py` requires:

- `bus_clk` at 75 MHz;
- the `AE350_CORE_CLK_PLLR0` dedicated core-clock hop;
- nextpnr routed `bus_clk` first, so the A25 bus takes GB10 rather than GB20;
- no hold violations on the AE350 clocks;
- the `AE350_SOC` hard block and its PLL are present.

Seed 1 measured 123.472 MHz on `bus_clk`, with the core hop present, bus routed
first, no hold violations, and the AE350 PLL at `X177Y27`.

## Artifacts

Seed 1:

- `build/ae350_smoke/seed-1/tiny_phosphor_ae350_smoke.fs`
  (37,743,845 bytes, SHA-256
  `bc76120b28ed836fda93be4fe7aea3317ee06d323b6fdf281834b6c8b04ad57e`)
- `build/ae350_smoke/seed-1/tiny_phosphor_ae350_smoke.bin`
  (4,714,476 bytes, SHA-256
  `131a07120eb091a82408fb0588ada7fb5446ea41c16d000cb02357fb8fe98da9`)

The `.bin` was put on the card as
`/root/cores/console138k/tinyphosphor_ae350_smoke.bin` and loaded with
`tangload`. The repeated `C OK` and `SDRAM OK 32M` lines were captured with
TinyTang's `fpgapipe`.

## Limitations

- The image has no player or display, so there is no user-visible test; the
  UART output is the smoke evidence.
- The boot ROM still speaks TinyNES's load protocol; it has not been replaced
  with Tang-Phosphor's stream loader.
- No program has been loaded through the UART yet; the boot ROM has only run
  its own ROM/RAM/SDRAM tests.
- The player integration, PLL re-plan and Rockbox software are the next
  cycles.

## Provenance

The AE350 platform, boot ROM and SDRAM controller are TinyNES's at commit
`50cd89e28ba4f503287b9085538390d945c1c124`, MIT. See `THIRD_PARTY.md`.
