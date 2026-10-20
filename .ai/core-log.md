## 1 COMMIT Unreleased 2026-10-20T12:08:19-07:00

#### Coming From:

Unreleased 94d31cd

#### Purpose:

Record TinyPhosphor's decision to build the Tang Console 138K player and visualizer with an open FPGA toolchain instead of GowinSynthesis.

#### Outcome:

TinyPhosphor moves its FPGA build to the open toolchain: Yosys, a GW5AST-138C-capable nextpnr-himbaechel and Apicula's `gowin_pack`, with no GowinSynthesis in the build path. Gowin EDA 1.9.11.03 remains required only to generate the non-redistributable GW5AST-138C device database, and the target stays the revision-C `GW5AST-LV138PG484AC1/I0` recorded in `.ai/core-reference.md`. The first target is the player and visualizer core without the AE350 and DDR3 subsystem, because the merged image depends on Gowin's generated DDR3 IP; a later AE350 path would use the dock's J9 SDRAM as TinyNES and TinyCreature do, or keep decoding on TinyTang's BL616. The decision rests on a scratch open-flow synthesis of Tang-Phosphor's player sources at `c261fcb`: `read_slang` elaborated the tree unchanged, and after stubbing `ae350_subsystem` and correcting two mixed blocking and non-blocking assignments, `synth_gowin -family gw5a` produced about 9,200 LUTs, 3,200 ALUs, 5,900 flip-flops, 34 DPB, 7 DPX9B/SDPX9B and 5 PLLs, with every inferred block RAM on one clock, so area is not the risk and placement and clock routing are. The port will carry the measured open-flow rules from TinyNES and Tiny89: right-edge PLL sites, the `SPINE26 <= CBRIDGEOUT_BOTTOM2` pixel-clock bridge, single-clock 9-bit video block RAM, and a seed sweep that gates hold, clock topology and the AE350 dedicated PLL hop before packing. Tang-Phosphor is GPL-3.0, so importing its RTL makes TinyPhosphor GPL-3.0 and the provenance belongs in `THIRD_PARTY.md`. The inherited Tang-Phosphor active log, entries 67 through 84, was archived as `core-log_2026-10-20T120819-0700.tar.gz` so this active log begins at entry 1. The required core-syntax audit re-read `.ai/core.md` and `.ai/core-syntax.md`, inspected the complete `.ai/` diff, confirmed `.ai/core.md` was unchanged, and validated this entry as number 1 of 100 with exactly six sections and allowed Status values.

#### Next Steps:

Import the Tang-Phosphor player sources at a pinned commit, add the open-flow build scripts adapted from TinyTang's `tools/desktop_open/` recipe (`read_slang` with `-U SYNTHESIS -D GW_IDE`, cell-library blackboxing, the fork nextpnr and Apicula, and PLL string-parameter restoration), create a player-only top without AE350 or DDR3, and run the first synthesis and seed sweep against the TinyNES/Tiny89 gates before any hardware load. The two read_slang findings and the stale `build.tcl` file list are part of that import; no board result exists yet.

#### Files Modified:

None.

#### Status:

- Build: N/A
- Deployment: N/A
- User Test: N/A

---
