# TinyPhosphor

An audio player and stereo XY visualiser for the Sipeed Tang Console 138K.

Rockbox's codecs run on the AE350 hard core, the FPGA draws the picture and
drives I2S audio, and the whole bitstream is built with the open FPGA flow —
Yosys, a GW5AST-138C-capable nextpnr-himbaechel and Apicula's `gowin_pack`.
GowinSynthesis is not in the build path.

The target is the revision-C `GW5AST-LV138PG484AC1/I0`.

## What it does

- Plays eleven codec families from the SD card through Rockbox's decoders:
  WAV, FLAC, MP3 and MP2, Ogg Vorbis, Opus, AAC, ALAC, WavPack, WMA, AC-3 and
  TTA. A track ends by itself and the player takes the next one; files of any
  size play, streamed through a 4 MiB cache rather than held whole.
- Sends audio out of the Pmod I2S2 socket on PMOD1 and out of HDMI, both at
  48 kHz. The onboard MAX98357A on J5 is left in shutdown by design.
- Draws a stereo XY oscilloscope on a 1280x720 HDMI picture, with persistence,
  a bloom, channel swap, dots-only and single-channel views.
- Loads over USB and is driven from the desktop: see
  [TinyTang](https://github.com/aquasock/TinyTang), which carries the firmware,
  the Phosphor app window and the `phosphor` shell command.

## On the card

The core image and the AE350 program are two separate files:

| Path | Purpose |
| --- | --- |
| `/root/cores/console138k/tinyphosphor.bin` | the FPGA image |
| `/root/ae350/resident.tpi` | the resident Rockbox player and its codecs |
| `/root/media/music/` | tracks |
| `/tang.ini` | which PMOD modules are seated |

`/tang.ini` must declare the Pmod I2S2 on the socket it is actually in, for
example `pmod0 = none` and `pmod1 = i2s2`; `tangload` then sends the declaring
word and the core drives those pins. A missing file leaves both sockets
released, which is the safe state.

## Building

The scripts default to the local toolchain and can be overridden:

- `OSS_CAD_SUITE` — oss-cad-suite, default `$HOME/oss-cad-suite`. Use the suite
  the scripts default to: an older Yosys (0.69+152) leaves `$buf` cells this
  design cannot place, and `tools/open/check_netlist.py` now refuses such a
  netlist rather than letting it reach place and route.
- `NEXTPNR_HIMBAECHEL` — the fork's nextpnr, default
  `$HOME/tools/nextpnr-mathieufro/nextpnr-himbaechel`.
- `APICULA_FORK` — the Apicula fork, default `../apicula-mathieufro`.
- `PYDEPS` — Python dependencies, default `$HOME/tools/pydeps`.
- `RISCV_CROSS` — the RISC-V toolchain prefix for the AE350 firmware, default
  `$HOME/tools/xpack-riscv-none-elf-gcc-15.2.0-1/bin/riscv-none-elf-`.

The fork's GW5AST-138C device database is generated from Gowin EDA 1.9.11.03
and is not redistributable, so Gowin EDA is still needed to produce it; nothing
in the build invokes GowinSynthesis.

```sh
# One seed: boot ROM, synthesis, place and route, gates, pack.
SEED=1 tools/open/ae350_player.sh build/ae350_player

# The normal hardware build is a seed sweep, because placement decides whether
# the AE350 bus clock gets a legal route. It is blocked unless approved.
SWEEP_APPROVED=1 SEEDS="1 2 3 4 5 6 7 8" SWEEP_JOBS=8 \
    tools/open/ae350_player_sweep.sh build/ae350_player
```

The sweep packs the best passing seed and writes `results.tsv`, `winner` and
`.bin`/`.fs` pairs. Expect most seeds to fail: one or two in eight normally
pass, and a large logic change can move that to none at all. `docs/open-flow-build.md`
describes the flow, and `docs/ae350-smoke.md` the stand-alone AE350 smoke image.

### Gates

A build is not qualified until the gates pass:

- `clk_pixel` at 74.25 MHz and `bus_clk` at 75 MHz, no hold violations.
- The `AE350_CORE_CLK_PLLR0` dedicated hop present, and no GB20 branch on the
  bus clock — cores that reach a sink through GB20 kill the A25 bus.
- Six PLLs, four `OSER10` serialisers, 205 two-clock-capable block RAMs.

After loading, two registers are the hardware gate before any audio test:

```sh
phosphor peek 0xf8   # 0x0012c000: I2S2 MCLK measured over a 100 ms window
phosphor peek 0xfc   # 0x0000001f: both PLLs locked, ready, zero retries
```

`0xfc` bits 15:8 count audio-PLL reset retries; a rising count means the
re-try path is doing the work, and a saturated one means the PLL never locked.

## Register ABI 1.14

`0x04` reports the ABI. The registers that matter day to day:

- `0x2c` — HDMI audio cadence: frames per second in 15:0, frames carrying a
  sample in 31:16. Both read 48000 during playback.
- `0xac` — 16-bit scope control: 0 enable, 2:1 persistence (0 133 ms, 1 267 ms,
  2 533 ms, 3 67 ms), 3 instant, 4 bloom, 6 channel swap, 7 dots only,
  9:8 channels (XY, X only, Y only). Bits 5 and 11:10 are reserved.
- `0xb0`, `0xb4`, `0xb8` — scope dropped samples, status and sweeps. Status
  carries the active settings in 31:16 and the sample FIFO level in 15:8.
- `0xf8`, `0xfc` — the audio clocks described above.

## Repository layout

- `src/` — the FPGA design: AE350 subsystem, SDRAM, HDMI, audio, UI, scope.
- `firmware/` — the AE350 boot ROM and the resident player's start-up code.
- `software/rbhost/` — Rockbox as a host: the codecs, the file server, the
  on-demand player.
- `third_party/` — Rockbox at a pinned commit, with the project's patches.
- `tools/open/` — the build, gates, packing and sweep scripts.
- `docs/` — the open-flow build and the AE350 smoke image.

## Limits

- Audio is fixed at 48 kHz: Rockbox resamples 44.1 kHz sources, so pitch is
  correct but no file is played at its native rate. The I2S2 PLL's dynamic
  selects are not routable in the open flow, and a two-PLL alternative is
  documented but not built.
- The onboard speaker stays in shutdown. It is loud and harsh at full scale,
  and a level control has not been scheduled.
- Scope colour is reserved in the ABI but not implemented: the palette that
  would carry it moved the bus clock onto GB20 on every seed tried.

## Licensing

GPL-3.0-only; see `LICENSE`. Rockbox, Apicula and the imported Tang-Phosphor
sources keep their own licences and provenance, all recorded in
`THIRD_PARTY.md`. Nothing from CERN's colibri is copied; it is a design
reference only.

`.ai/` holds the project's own records: directives, the running engineering
log, and a reference library of the standards and measured behaviour behind
these numbers.
