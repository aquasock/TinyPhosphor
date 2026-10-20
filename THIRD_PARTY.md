# Third-party components

## Tang-Phosphor player RTL (vendored)

TinyPhosphor's `src/` is vendored from Tang-Phosphor's player RTL at:

- Project: https://github.com/aquasock/Tang-Phosphor
- Commit: `c261fcb03538fa980d2ef296d9e910842cbcbc3e`
- License: GNU General Public License v3.0; the text is in `LICENSE`.
- Imported: the 60 files listed by `build-merged.tcl` under `src/` that are not under `src/ae350/`, plus `src/assets/font.vh`, `src/usb_hid_host_rom.hex`, `src/boards/console138k_merged.cst` and `src/boards/console138k_merged.sdc`. The AE350 subsystem, `software/`, `third_party/rockbox`, build outputs and generated vendor IP are not imported.
- Local additions: `src/ae350/ae350_stub.sv`, `src/tiny_phosphor_player_top.sv`, `src/boards/console138k_player.cst`, `src/boards/console138k_player.sdc`, and the open-flow build scripts under `tools/open/`.
- Local modifications: `src/hdmi/hdmi.sv` and `src/hdmi/packet_picker.sv` are corrected for `read_slang`'s blocking and non-blocking assignment rules; `src/hdmi/serializer.sv` serialises the TMDS clock lane through a fourth `OSER10`, following TinyNES's measured HDMI fix, and `src/tang_phosphor_top.sv` plus `src/phosphor_video.sv` drive the differential clock lane from that serialised output rather than from `clk_pixel`. These are the only RTL changes from the vendored commit.

TinyPhosphor is a derivative of Tang-Phosphor and carries GPL-3.0. The sections below are Tang-Phosphor's provenance records for the imported files and remain applicable.

## TinyNES and TinyTang open-flow tooling

The build scripts under `tools/open/` are adapted from TinyTang's
`tools/desktop_open/` and TinyNES/Tiny89's measured build gates:

- Project: https://github.com/aquasock/TinyTang
- Project: https://github.com/aquasock/TinyNES
- Project: https://github.com/aquasock/Tiny89
- License: MIT for the TinyNES and TinyTang tooling; Tiny89's build-gate
  pattern is used as a reference.

`tools/open/fs_to_bin.py` is copied from TinyNES `tools/fs_to_bin.py`, which
is itself TinyTang `tools/desktop_open/fs_to_bin.py` at `d68bc18`, under the
MIT License.  The remaining scripts are rewritten for TinyPhosphor's paths and
checks but keep the same flow and gate rules.

## TinyNES AE350 platform and boot ROM

The stand-alone AE350 + 32 MiB SDRAM smoke imports TinyNES's platform at
commit `50cd89e28ba4f503287b9085538390d945c1c124`:

- `src/ae350_platform/ahb_boot_rom.sv`, `ahb_ram.sv`, `ahb_sdram.sv` and
  `exts_uart.sv`
- `firmware/boot/`, `firmware/common/` and `firmware/include/tinynes.h`
- the J9 SDRAM/UART pin mapping, the AE350 PLL and reset recipe, and the
  `AE350_SOC` hard-block connections

License: MIT.  The AE350 itself is a hard block in the GW5AST-138C, not
imported source.  Local changes: `src/ae350_smoke/tiny_phosphor_ae350_sdram_top.sv`
is a stripped version of TinyNES's `fpga/ae350_soc/ae350_soc.sv` with the NES
video, Wii pads and I2S removed; the boot banner strings say TinyPhosphor,
while the loader protocol strings remain `TinyNES LOAD`/`RUN` so TinyNES's
host loader still works.

## MiSTer-Phosphor design reference

Tang-Phosphor's bounded audio profile, album-screen presentation and stereo
XY O-Scope use the project's MiSTer implementation as a behavioral and visual
reference:

- Project: https://github.com/aquasock/MiSTer-Phosphor
- Reference commit: `183b514ceb98afd373d2bd8d8b9425e1df74bd15`
- License: GNU General Public License v3.0 or later

The Tang implementation is newly written for TangCore's transport, Gowin
memories, clocks, and HDMI path; no MiSTer RTL file is copied into this tree.
The visual reconstruction filter uses the reference's four symmetric
half-band coefficient pairs; the line engine, timestamp persistence, banked
memory scheduling and glow shader are Tang-native implementations. See
[docs/oscope-plan.md](docs/oscope-plan.md) for the referenced RTL files.

## TangCore Monitor Core

The files under `src/iosys/`, the Gowin-generated PLL wrappers under
`src/pll/`, and the initial board-support structure are derived from:

- Project: https://github.com/nand2mario/monitorcore
- Commit: `e4446093a754205f46e7000e6ef1bf37176bda19`
- Author: nand2mario and contributors
- License: GNU General Public License v3.0

The GPL-3.0 text is provided in `LICENSE`.

`src/iosys/iosys_bl616.v` corrects the direction of the `kbd_data` port from
input to output, matching the signal's actual use inside the upstream module.

`src/hdmi/serializer.sv` leaves the Gowin OSER10 runtime reset inactive. FPGA
configuration initializes the serializers, and this avoids driving an
asynchronous reset across the pixel and x5 pixel-clock domains.

## NESTang USB HID host

The following files are taken from nand2mario's NESTang repository at commit
`c2450818e1f0c858e13c5dd16746ee5221a5c760`:

- `src/usb_hid_host.v`
- `src/usb_hid_host_rom.hex`

- Project: https://github.com/nand2mario/nestang
- USB host project: https://github.com/nand2mario/usb_hid_host
- Author: nand2mario, based on work by hi631
- License: GNU General Public License v3.0

The GPL-3.0 text is provided in `LICENSE`.

## TinyTang desktop text layer

The following files come from nestang as modified by TinyTang's nestang patch
series (`third_party/patches/0002-desktop-text-layer.patch` through
`0007-wide-layer-alignment.patch`, applied to the NESTang commit above):

- `src/iosys/textdisp_wide.sv`, added by the TinyTang patches
- `src/assets/font.vh`, unmodified from NESTang commit
  `c2450818e1f0c858e13c5dd16746ee5221a5c760`

- Project: https://github.com/aquasock/TinyTang
- Authors: the TinyTang contributors; nand2mario for `font.vh`
- License: GNU General Public License v3.0 (the TinyTang patch files carry
  GPL-3.0 lines because they modify nestang)

The GPL-3.0 text is provided in `LICENSE`. `src/iosys/iosys_bl616.v` carries
TinyTang's desktop-layer commands 0x13-0x15 and keyboard report response 0x08
in the same form as the TinyTang nestang patches.

## hdl-util HDMI

The files under `src/hdmi/` originated in:

- Project: https://github.com/hdl-util/hdmi
- Author: Sameer Puri and contributors
- License: MIT OR Apache-2.0

Tang-Phosphor uses these files under the MIT option. The required notice is
provided in `third_party/hdl-util-hdmi/LICENSE-MIT`.

## Gowin-generated PLL wrappers

The files under `src/pll/` were generated by Gowin EDA and retain their
original copyright notices.

`src/ae350/ae350_pll.v` is an adapted Gowin PLL wrapper used only by the
standalone AE350 proof-of-life image and retains Gowin's copyright notice.

## Sipeed TangMega-138K-example DDR3 configuration

`src/ddr3/ddr3_ip.tcl` and the checked-in `src/ddr3/ddr3_memory_interface.ipc`
reproduce the DDR3 memory-interface configuration from Sipeed's
TangMega-138K-example design, option by option, for every setting the Gowin
EDA 1.9.11.03 generator supports:

- Project: https://github.com/sipeed/TangMega-138K-example
- Design: `ddr_memory/`, whose `ddr3_memory_interface.ipc` these values follow
- Reference commit: `06e7d8b118d345915ab6f257b7c22226f81575cd`
- License: Apache-2.0

## Gowin-generated DDR3 memory controller

The DDR3 controller itself is not source in this tree. `scripts/gen-ddr3-ip.sh`
runs Gowin EDA's generator over the configuration above and writes the
generated, encrypted RTL to `build/ddr3-ip`, where it is licensed with Gowin
EDA and is never committed - the same arrangement as the PLL wrappers above.
`src/ddr3/` holds only this project's own configuration.

## LiteX Gowin AE350 integration

The primitive wiring and integration approach in
`src/ae350/ae350_soc_smoke.sv` is based on LiteX's Gowin AE350 hard-CPU
wrapper and the LiteX-WR-NIC Tang Mega 138K Pro target:

- LiteX project: https://github.com/enjoy-digital/litex
- LiteX reference commit: `5940a34ca0b4ee0fd9344f717dc7859aed503d9f`
- LiteX-WR-NIC project: https://github.com/enjoy-digital/litex_wr_nic
- LiteX-WR-NIC reference commit: `cd5fde38b6ef4fde5bdbbd37c2452ee853d1dac5`
- Authors: Gwenhael Goavec-Merou, Florent Kermarrec, and contributors
- License: BSD 2-Clause

The required notice is provided in `third_party/litex/LICENSE-BSD-2-Clause`.
Tang-Phosphor does not include the separately licensed White Rabbit gateware
or firmware.

## Rockbox

`third_party/rockbox` is a Git submodule of the Rockbox open-source firmware.
Its codecs, codec support libraries, metadata parsers, DSP, and supporting
firmware and library sources are compiled by `software/rbhost`. One local
modification is carried, recorded here and applied from a patch file:

- Project: https://www.rockbox.org/ (mirror https://github.com/Rockbox/rockbox)
- Reference commit: `e45936397ee3677c910c9a0c6473184e9755040c`
- License: GNU General Public License version 2 or later; bundled codec
  libraries carry their own GPL-compatible licenses in their directories

`software/rbhost/host/rbhost.c` follows Rockbox's
`lib/rbcodec/test/warble.c`, and the headers in `software/rbhost/config` are
derived from `lib/rbcodec/rbcodecconfig-example.h`,
`lib/rbcodec/rbcodecplatform-unix.h`, and `lib/rbcodec/test/file.h`; those
files remain GPL-2.0-or-later. The combined rbhost and codec binaries are
distributed under GPL-3.0 as permitted by the "or later" terms.

### Local modification: libwma frame count

`lib/rbcodec/codecs/libwma/wmadeci.c` is patched. Rockbox's WMA v2 decoder
hardcoded one frame per ASF packet whenever the bit reservoir is not used, so
packets carrying several block-aligned frames (what ffmpeg's `wmav2` muxer
produces) decoded only the first frame and truncated playback to roughly a
quarter of the track. The patch derives the frame count from the packet
payload size and `block_align` and repositions the bit reader at each frame's
`block_align` slot. It affects only the no-bit-reservoir path and is intended
for upstream submission.

The patch is carried as
`third_party/patches/0001-libwma-frames-per-packet.patch`, marked with a
`Tang-Phosphor:` comment in the source, and applied by
`scripts/apply-rockbox-patches.sh`. `software/rbhost`'s Makefile runs that
script before compiling any Rockbox source, because `git submodule update`
reverts the patch; the script is idempotent and re-applies it automatically.

## QEMU (development tooling only)

`tools/build-qemu-cache-model.sh` builds QEMU 10.2.1 (GPL-2.0) and its
`contrib/plugins/cache.c` cache model from the signed release tarball for
local performance estimates. No QEMU code is included in this repository or
in any Tang-Phosphor artifact.
