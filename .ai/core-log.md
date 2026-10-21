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

## 2 COMMIT Unreleased 2026-10-20T12:13:02-07:00

#### Coming From:

Unreleased c2adfd2

#### Purpose:

Update `.ai/core-reference.md` for TinyPhosphor's open-flow build while preserving the inherited Tang-Phosphor records.

#### Outcome:

The reference is now titled for TinyPhosphor and states that entries headed `Tang-Phosphor use` are inherited implementation context, with new decisions labelled `TinyPhosphor use`. A new `Open FPGA Flow and Toolchain` section records the `read_slang` front end and its `-U SYNTHESIS -D GW_IDE` requirement, the `-v` plus `--blackboxed-module` primitive rule and the `specify`-block shim, the PLL string-parameter restoration needed before `gowin_pack`, the fork's GW5AST-138C device database and its non-redistributable provenance, the measured clock rules from TinyNES, Tiny89 and TinyTang (right-edge PLL sites, `SPINE17` avoidance, the `SPINE26 <= CBRIDGEOUT_BOTTOM2` pixel bridge, `GB10` for the AE350 bus and the dedicated `AE350_CORE_CLK_PLLR0` hop), the placement and block-RAM gates (8 to 16 seeds, single-clock 9-bit video RAM), the HDMI clock-lane and thermal rule, and the scratch player-core synthesis baseline at Tang-Phosphor `c261fcb`. The revision-C record gained the open-flow `--device` and `-d` invocation, and the GowinSynthesis record gained the note that `syn_srlstyle` does not exist in this build, so synchronizers must be checked in the routed netlist. No hardware was built or deployed; this was a documentation-only cycle. The required core-syntax audit re-read `.ai/core.md` and `.ai/core-syntax.md`, inspected the complete `.ai/` diff, confirmed `.ai/core.md` was unchanged, and validated this entry as number 2 of 100 with exactly six sections and allowed Status values.

#### Next Steps:

Import the Tang-Phosphor player sources at a pinned commit and add the open-flow build scripts described by the new reference section, then create the player-only top without AE350 or DDR3 and run the first synthesis and seed sweep. The two read_slang findings and the stale `build.tcl` file list remain the first import tasks, and no board result exists yet.

#### Files Modified:

None.

#### Status:

- Build: N/A
- Deployment: N/A
- User Test: N/A

---

## 3 COMMIT Unreleased 2026-10-20T13:07:02-07:00

#### Coming From:

Unreleased 875f5fc

#### Purpose:

Build and qualify TinyPhosphor's first player-only image with the open FPGA flow, without the AE350 or DDR3 subsystem.

#### Outcome:

TinyPhosphor imported Tang-Phosphor's player RTL at `c261fcb` into `src/` and added `src/ae350/ae350_stub.sv` plus `src/tiny_phosphor_player_top.sv`, so the player elaborates without the AE350 or the vendor DDR3 IP; `cpu_mode` resets to zero, leaving the FPGA player on the stream path. The open-flow scripts under `tools/open/` synthesise with `read_slang` and `synth_gowin`, restore PLL string parameters, place and route with the GW5AST-138C nextpnr fork, gate timing, hold, block RAM and clock topology, and pack with Apicula; no GowinSynthesis is invoked. Three RTL corrections were required: `src/hdmi/hdmi.sv` and `src/hdmi/packet_picker.sv` no longer mix blocking and non-blocking assignments in `always_ff`, and the HDMI clock chain now generates 371.25 MHz on the PLL's `CLKOUT1`, divides it by five in a `CLKDIV` placed at `RIGHTSIDE[4]`, and serialises the TMDS clock lane through a fourth `OSER10`; `src/tang_phosphor_top.sv` and `src/phosphor_video.sv` drive the differential clock lane from that serialised output. The I2S2 audio PLL's dynamic select nets are tied to the 48 kHz recipe because this nextpnr/Apicula model cannot place them, so audio is fixed-rate and best-effort. One seed, seed 1, passed every gate: `clk_pixel` 99.404 MHz against 74.25, `clk12` 136.295 MHz, zero hold violations, 169 two-clock-capable block RAMs all single-clock, five PLLs, four OSER10s, and both HDMI clocks on dedicated routes. The packed artifacts are `build/open/seed-1/tiny_phosphor.fs`, 39,397,861 bytes with SHA-256 `c5d9d56d30e989656828daea2785a7c9cbdbd3cb24974b6926ec8b2076a9bc72`, and `build/open/seed-1/tiny_phosphor.bin`, 4,920,812 bytes with SHA-256 `1521246f990425dde92f667c38448f858a2e06112d8424066a455897a2bc51ed`. The `.bin` was put at `/root/cores/console138k/tinyphosphor.bin` with TinyTang's `tinytang_put.py`, loaded with `tangload`, and the core accepted the `/tang.ini` socket declaration at `0xc0 = 0x0710`; `fpga` reported core 80 answering on UART1. The user watched the HDMI output and reported PASS for the 96x64 address-encoded menu frame at 1280x720. The 8-seed sweep was not run because seed 1 passed every gate; the real AE350, DDR3, runtime audio-rate switching, and the 4-bit DPB review remain out of scope. The required core-syntax audit re-read `.ai/core.md` and `.ai/core-syntax.md`, inspected the complete `.ai/` diff, confirmed `.ai/core.md` was unchanged, and validated this entry as number 3 of 100 with exactly six sections and allowed Status values.

#### Next Steps:

Qualify the player stream path and audio next: send a WAV or FLAC through TinyTang, check the HDMI audio cadence against the fixed 48 kHz I2S2 clock, and decide whether runtime rate switching is required before restoring the dynamic I2S PLL selects. The real AE350 and DDR3 subsystem remains deferred; if it is revived, replace Gowin's DDR3 IP with the dock's J9 SDRAM or keep decoding on the BL616. An 8-seed sweep is only warranted if a future netlist change or an HDMI fault makes seed 1's placement inadequate.

#### Files Modified:

- .gitignore
- LICENSE
- THIRD_PARTY.md
- docs/open-flow-build.md
- src/ae350/ae350_stub.sv
- src/assets/font.vh
- src/audio/audio_output_policy.sv
- src/audio/i2s_clock_control.sv
- src/audio/i2s_clock_probe.sv
- src/audio/i2s_playback.sv
- src/audio/i2s_tx.sv
- src/audio/pcm_sample_fifo.sv
- src/audio/pcm_sink.sv
- src/audio_test_source.sv
- src/boards/console138k_merged.cst
- src/boards/console138k_merged.sdc
- src/boards/console138k_player.cst
- src/boards/console138k_player.sdc
- src/debug/debug_regs.sv
- src/debug/ui_debug_regs.sv
- src/hdmi/audio_clock_regeneration_packet.sv
- src/hdmi/audio_info_frame.sv
- src/hdmi/audio_sample_packet.sv
- src/hdmi/auxiliary_video_information_info_frame.sv
- src/hdmi/hdmi.sv
- src/hdmi/packet_assembler.sv
- src/hdmi/packet_picker.sv
- src/hdmi/serializer.sv
- src/hdmi/source_product_description_info_frame.sv
- src/hdmi/tmds_channel.sv
- src/input/keylink_rx.sv
- src/iosys/gowin_dpb_menu.v
- src/iosys/iosys_bl616.v
- src/iosys/textdisp.v
- src/iosys/textdisp_wide.sv
- src/iosys/uart_fixed.v
- src/oled/oled_panel.sv
- src/oled/oled_spi.sv
- src/phosphor_video.sv
- src/pll/pll_12.v
- src/pll/pll_27.v
- src/pll/pll_74.v
- src/pll/pll_i2s2_audio.v
- src/pll/pll_i2s2_ref.v
- src/pmod/pmod_enc.sv
- src/pmod/pmod_i2s2_tone.sv
- src/pmod/pmod_io_buf.sv
- src/pmod/pmod_oledrgb.sv
- src/pmod/pmod_slot.sv
- src/pmod/pmod_vga.sv
- src/pmod_mirror_core.sv
- src/stream/stream_debug_sink.sv
- src/tang_phosphor_top.sv
- src/tiny_phosphor_player_top.sv
- src/ui/phosphor_album_ui.sv
- src/ui/phosphor_time_digits.sv
- src/ui/phosphor_ui_control.sv
- src/ui/ui_checksum.sv
- src/ui/ui_frame_bank.sv
- src/ui/ui_frame_store.sv
- src/ui/ui_menu_renderer.sv
- src/ui/ui_scanout.sv
- src/ui/ui_swap.sv
- src/usb_hid_host.v
- src/usb_hid_host_rom.hex
- src/video/ui_desk_layer.sv
- src/video/ui_hdmi_backend.sv
- src/video/ui_hdmi_scan.sv
- src/video/ui_vga_backend.sv
- src/visualizers/scope_phosphor_ram.sv
- src/visualizers/scope_reconstruct.sv
- src/visualizers/scope_xy.sv
- tools/open/build.sh
- tools/open/check_netlist.py
- tools/open/fs_to_bin.py
- tools/open/gates.py
- tools/open/pack.sh
- tools/open/pll_strings.py
- tools/open/pnr.sh
- tools/open/sources.f
- tools/open/sweep.sh
- tools/open/synth.sh

#### Status:

- Build: PASS
- Deployment: PASS
- User Test: PASS

---

## 4 COMMIT Unreleased 2026-10-20T13:21:06-07:00

#### Coming From:

Unreleased 92c0c0c

#### Purpose:

Bring up the AE350 and its 32 MiB J9 SDRAM in the open flow as a stand-alone smoke image before integrating them with the player.

#### Outcome:

TinyPhosphor imported TinyNES's AE350 platform at `50cd89e28ba4f503287b9085538390d945c1c124`: `src/ae350_platform/ahb_boot_rom.sv`, `ahb_ram.sv`, `ahb_sdram.sv` and `exts_uart.sv`, plus `firmware/boot`, `firmware/common` and `firmware/include/tinynes.h` for the boot ROM. `src/ae350_smoke/tiny_phosphor_ae350_sdram_top.sv` is a stripped version of TinyNES's `ae350_soc.sv` with the NES video, Wii pads, I2S and DDR3 removed; it keeps the AE350 hard block, the `PLL_R[0]` 750/75 MHz clock recipe, the 32 KiB boot ROM, the 64 KiB block RAM at `0x60000000`, the 32 MiB J9 SDRAM at `0x40000000` and the EXTS UART. The boot banner strings now say TinyPhosphor while the loader protocol strings remain `TinyNES LOAD` and `TinyNES RUN`, so TinyNES's host loader still works. `tools/open/ae350_smoke.sh`, `ae350_gates.py` and `ae350_sources.f` add the smoke profile, and `synth.sh`, `pnr.sh`, `pack.sh` and `check_netlist.py` gained source-list, top, constraint, frequency, gate, artifact and netlist-profile overrides so the player and AE350 builds share one flow. The boot ROM builds to 2,666 bytes of text in a 32 KiB image; seed 1 passed every gate with `bus_clk` at 123.472 MHz against 75, the `AE350_CORE_CLK_PLLR0` dedicated hop present, `bus_clk` routed first, no hold violations, and the AE350 hard block and PLL present. The packed artifacts are `build/ae350_smoke/seed-1/tiny_phosphor_ae350_smoke.fs`, 37,743,845 bytes with SHA-256 `bc76120b28ed836fda93be4fe7aea3317ee06d323b6fdf281834b6c8b04ad57e`, and `tiny_phosphor_ae350_smoke.bin`, 4,714,476 bytes with SHA-256 `131a07120eb091a82408fb0588ada7fb5446ea41c16d000cb02357fb8fe98da9`. The `.bin` was put on the card as `/root/cores/console138k/tinyphosphor_ae350_smoke.bin`, loaded with `tangload`, and the EXTS UART captured through TinyTang's `fpgapipe` repeated `TinyPhosphor AE350 C OK UNC=0491d440 CAC=001f6bc2`, `TinyPhosphor SDRAM OK 32M` and `TinyNES LOAD`. The image has no player or display, so there was no user-visible test; the UART output is the smoke evidence. No program has been loaded through the loader yet, the boot ROM still speaks TinyNES's protocol, and the player integration, PLL re-plan and Rockbox software remain. The required core-syntax audit re-read `.ai/core.md` and `.ai/core-syntax.md`, inspected the complete `.ai/` diff, confirmed `.ai/core.md` was unchanged, and validated this entry as number 4 of 100 with exactly six sections and allowed Status values.

#### Next Steps:

Integrate the AE350 and 32 MiB SDRAM into the player top next: replace `src/ae350/ae350_stub.sv` with an AE350+SDRAM subsystem that keeps Tang-Phosphor's stream, debug and play interfaces, add the SDRAM pins to the AE350 player wrapper, and re-plan the PLLs because the AE350 must own `PLL_R[0]` while the HDMI chain keeps `PLL_R[1]` and `PLL_R[3]`; the remaining I2S2 audio and USB clocks need either the free `PLL_R[2]` site or an AE350 PLL spare output, and the left-edge I2S pair is still suspect. Load a program through the TinyNES UART loader before Rockbox, and keep to one seed until timing fails.

#### Files Modified:

- THIRD_PARTY.md
- docs/ae350-smoke.md
- firmware/boot/Makefile
- firmware/boot/crt0.S
- firmware/boot/link.ld
- firmware/boot/load.c
- firmware/boot/load.h
- firmware/boot/main.c
- firmware/common/memtest.c
- firmware/common/memtest.h
- firmware/common/uart.c
- firmware/common/uart.h
- firmware/include/tinynes.h
- src/ae350_platform/ahb_boot_rom.sv
- src/ae350_platform/ahb_ram.sv
- src/ae350_platform/ahb_sdram.sv
- src/ae350_platform/exts_uart.sv
- src/ae350_smoke/tiny_phosphor_ae350_sdram_top.sv
- src/boards/console138k_ae350_sdram.cst
- src/boards/console138k_ae350_sdram.sdc
- tools/open/ae350_gates.py
- tools/open/ae350_smoke.sh
- tools/open/ae350_sources.f
- tools/open/check_netlist.py
- tools/open/pack.sh
- tools/open/pnr.sh
- tools/open/synth.sh

#### Status:

- Build: PASS
- Deployment: PASS
- User Test: N/A

---

## 5 COMMIT Unreleased 2026-10-20T14:54:17-0700

#### Coming From:

Unreleased 66eb0af

#### Purpose:

Move the AE350 and its 32 MiB SDRAM to the top-level base of the player image so the A25 bus clock follows the TinyNES/Tiny89/TinyCreature layout instead of sharing GB20.

#### Outcome:

TinyPhosphor replaced the embedded AE350 subsystem with `src/tiny_phosphor_ae350_player_top.sv`, an AE350-centric top that owns the `PLL_R[0]` 750/75 MHz clock, the A25 macro, the boot ROM, the 64 KiB block RAM, the 32 MiB J9 SDRAM, the EXTS register block, the stream loader, the play-stream FIFO and the transport debug view; the top-level bus net is named `bus_clk`, and `src/tang_phosphor_top.sv` became the `tang_phosphor_player` peripheral clocked by `clk_pixel`, with the player-only wrapper holding the CPU interface idle. The first AE350-centric synthesis exposed a real reset bug: `logic mem_resetn = por_n && ae350_pll_lock` was a declaration initializer, not a continuous assignment, so `ahb_ram` and `ahb_sdram` stayed in reset forever and the AE350 never left reset; changing it to `assign mem_resetn = por_n && ae350_pll_lock` restored the memory logic and grew the routed netlist from 25,760 to 31,805 cells. An eight-seed sweep with `NPNR_GOWIN_CLK_FIRST=bus_clk` produced one passing placement, seed 5, with `bus_clk` at 156.470 MHz against 75 MHz, `clk_pixel` at 91.558 MHz against 74.25 MHz, no hold violations, the `AE350_CORE_CLK_PLLR0` hop present and no GB20 branch; the other seven seeds failed the GB20 gate. Seed 5's `.bin` with SHA-256 `9578a45ab6671d949dc4b91687bb542348507727e71263be93f15a64a91779c7` was loaded with `tangload`; `fpga` reported core 80 answering, `0x43e0` read `0x0000001b` (POR done, AE350 PLL locked, SDRAM ready, CPU running), `0x43e4` read `0x00002730`, the log ring at `0x4100` decoded to `ae350 boot\n`, and the player ABI 1.10 HDMI frame counter advanced from `0x000009e6` to `0x00000cbe` while the user watched. The user confirmed the TinyPhosphor HDMI menu and reported PASS. The required core-syntax audit re-read `.ai/core.md` and `.ai/core-syntax.md`, inspected the complete `.ai/` diff, confirmed `.ai/core.md` was unchanged, and validated this entry as number 5 of 100 with exactly six sections and allowed Status values.

#### Next Steps:

Bring up the onboard MAX98357A mono speaker on J5 next by adding top-level `i2s_bclk`, `i2s_lrck`, `i2s_dout` and `pa_en` ports, constraining them to the schematic's Y17, AB17, AA16 and Y14 balls, tapping the existing I2S transmitter, and verifying the amplifier enable and channel-select polarity; then load and play a WAV through the AE350. Keep seed 5 as the pinned placement until the GB20 sensitivity is removed, because seven of eight seeds still fail that gate.

#### Files Modified:

- firmware/ae350/Makefile
- firmware/ae350/boot/boot.c
- firmware/ae350/boot/boot.ld
- firmware/ae350/boot/start.S
- firmware/ae350/include/ae350.h
- firmware/ae350/include/ae350_request.h
- firmware/ae350/lib/crt0.S
- firmware/ae350/lib/program.ld
- src/ae350/ae350_boot_rom.sv
- src/ae350/ae350_exts_regs.sv
- src/ae350/ae350_play_stream.sv
- src/ae350/ae350_pll.v
- src/ae350/ae350_sdram_subsystem.sv
- src/ae350/ae350_soc.sv
- src/ae350/ae350_stream_loader.sv
- src/ae350/ae350_stub.sv
- src/ae350/async_fifo.sv
- src/ae350/async_fifo_rst.sv
- src/ae350/debug_read_cdc.sv
- src/boards/console138k_ae350_player.cst
- src/boards/console138k_ae350_player.sdc
- src/tang_phosphor_top.sv
- src/tiny_phosphor_ae350_player_top.sv
- src/tiny_phosphor_player_top.sv
- tools/open/ae350_gates.py
- tools/open/ae350_player.sh
- tools/open/ae350_player_gates.py
- tools/open/ae350_player_sources.f
- tools/open/ae350_player_sweep.sh
- tools/open/check_netlist.py
- tools/open/gates.py
- tools/open/sources.f

#### Status:

- Build: PASS
- Deployment: PASS
- User Test: PASS

---

## 6 COMMIT Unreleased 2026-10-20T15:57:50-0700

#### Coming From:

Unreleased 4bf0c7b

#### Purpose:

Integrate Rockbox's codec library and resident player into the AE350-centric TinyPhosphor image, and qualify 48 kHz playback on the Pmod I2S2.

#### Outcome:

TinyPhosphor imported Rockbox at `e45936397ee3677c910c9a0c6473184e9755040c` as `third_party/rockbox`, copied Tang-Phosphor's `software/rbhost` and its WMA patch, and built eleven RV32 codecs: `wav`, `flac`, `mpa`, `vorbis`, `opus`, `aac`, `alac`, `wavpack`, `wma`, `a52` and `tta`. The host and codec build required `-march=rv32imafdc_zifencei` and the newer libc's `libc_a-setjmp.o` name. The resident on-demand player image is 844,524 payload bytes; its memory map was moved into the 32 MiB SDRAM: host image and codec at `0x40000000`/`0x41000000`, heap through `0x41800000`, input at `0x41800000`, and a 4 MiB output ring at `0x41c00000`. The first loader attempts returned `BAD_HEADER` because `cpu_stream_data` had never been assigned in `tang_phosphor_player`; after `assign cpu_stream_data = cpu_mode ? stream_data : 8'd0`, the boot ROM accepted the image and the resident player logged `resident`. The first playback then produced heavy choppiness: the I2S2 MCLK probe read `0x00249f00` instead of `0x0012c000`, because the audio PLL's dynamic M/D selects were driving it to about 24 MHz. Setting `DYN_MDIV_SEL` and `DYN_ODIV0_SEL` false and tying the rate-control request to 48 kHz made the MCLK read exactly `0x0012c000`. An eight-seed sweep with four parallel jobs produced two passing placements, seed 6 and seed 8; seed 6 is the winner with `bus_clk` 151.814 MHz, `clk_pixel` 99.741 MHz, the AE350 hop present and no GB20 branch. Seed 6 played `scope-vertical-48000.wav` at 48 kHz with 659,836 samples, zero underruns and a full 2048-sample PCM FIFO, and the user heard the tone with no choppiness. The speaker path was also wired to the MAX98357A pins Y17/AB17/AA16/Y14, but it is not separately qualified. The cycle limitation is that 44.1 kHz files are forced through the 48 kHz PLL until runtime rate switching or resampling is restored. The required core-syntax audit re-read `.ai/core.md` and `.ai/core-syntax.md`, inspected the complete `.ai/` diff, confirmed `.ai/core.md` was unchanged, and validated this entry as number 6 of 100 with exactly six sections and allowed Status values.

#### Next Steps:

Restore 44.1/48 kHz handling so native-rate files play at the correct pitch: either bring back the PLL's dynamic M/D selects with a verified open-flow encoding, or force the Rockbox DSP to resample to 48 kHz. Then qualify the MAX98357A path on J5, and commit the 44.1 kHz result as its own cycle.

#### Files Modified:

- .gitmodules
- THIRD_PARTY.md
- scripts/apply-rockbox-patches.sh
- software/rbhost/Makefile
- software/rbhost/config/autoconf.h
- software/rbhost/config/endian.h
- software/rbhost/config/file.h
- software/rbhost/config/rbcodecconfig.h
- software/rbhost/config/rbcodecplatform.h
- software/rbhost/host/bench_qemu.c
- software/rbhost/host/bench_qemu_start.S
- software/rbhost/host/codec.ld
- software/rbhost/host/codec_loader.c
- software/rbhost/host/codec_loader.h
- software/rbhost/host/crt0_ae350.S
- software/rbhost/host/crt0_qemu.S
- software/rbhost/host/host.ld
- software/rbhost/host/memory.ld
- software/rbhost/host/platform_ae350.c
- software/rbhost/host/platform_qemu.c
- software/rbhost/host/rbhost.c
- src/boards/console138k_ae350_player.cst
- src/pll/pll_i2s2_audio.v
- src/tang_phosphor_top.sv
- src/tiny_phosphor_ae350_player_top.sv
- src/tiny_phosphor_player_top.sv
- third_party/patches/0001-libwma-frames-per-packet.patch
- third_party/rockbox
- tools/ae350_run.py
- tools/fpga_uart.py

#### Status:

- Build: PASS
- Deployment: PASS
- User Test: PASS

---

## 7 COMMIT Unreleased 2026-10-20T16:00:39-0700

#### Coming From:

Unreleased 745aaae

#### Purpose:

Make 44.1 kHz sources play at the correct pitch through the fixed 48 kHz I2S2 clock by resampling them in the Rockbox DSP.

#### Outcome:

TinyPhosphor's rbhost previously matched 44.1 or 48 kHz to the source; with the I2S2 PLL fixed at 48 kHz that made 44.1 kHz files fast. `software/rbhost/host/rbhost.c` now sets the DSP output frequency to 48 kHz for every source, so Rockbox resamples 44.1 kHz and any other native rate before PCM reaches `pcm_sink`. The on-demand resident image rebuilt to 844,508 payload bytes. On the deployed seed 6 image, `/root/media/music/test.wav` played as `1,753,721 samples at 48000 Hz` with `0 underruns`, a full `0x800` PCM FIFO and `0xf8 = 0x0012c000`; `phosphor status` reported zero underruns throughout, while `0x6c` retained 2,610 startup underruns from the initial buffer fill and did not increase. The user reported PASS for the 44.1 kHz playback. The required core-syntax audit re-read `.ai/core.md` and `.ai/core-syntax.md`, inspected the complete `.ai/` diff, confirmed `.ai/core.md` was unchanged, and validated this entry as number 7 of 100 with exactly six sections and allowed Status values.

#### Next Steps:

Qualify the MAX98357A speaker path on J5, and decide whether to restore native 44.1/48 kHz PLL switching or keep the fixed-48 kHz resampling path. No runtime rate-switching work is required for correct pitch with the current implementation.

#### Files Modified:

- software/rbhost/host/rbhost.c

#### Status:

- Build: PASS
- Deployment: PASS
- User Test: PASS

---

## 8 COMMIT Unreleased 2026-10-20T16:09:39-0700

#### Coming From:

Unreleased e27b4d4

#### Purpose:

Qualify the onboard MAX98357A mono speaker path on J5.

#### Outcome:

The deployed seed 6 image already drove the MAX98357A from the same I2S lane as the Pmod I2S2: `I2S_BCLK` on Y17, `I2S_LRCK` on AB17, `I2S_DOUT` on AA16 and `PA_EN` on Y14, with `PA_EN` held high while the player and I2S clock are ready. The user played `test.wav` and heard the tone from both the Pmod I2S2 and the speaker connected across J5 pins 2 and 4, confirming both the FPGA pin mapping and the amplifier enable path. The earlier `scope-vertical-48000.wav` produced only quiet hiss from the speaker, which is consistent with the amplifier's SD_MODE-high left-channel selection and a fixture whose audible signal was not on the selected channel. No source change was needed for this qualification. The required core-syntax audit re-read `.ai/core.md` and `.ai/core-syntax.md`, inspected the complete `.ai/` diff, confirmed `.ai/core.md` was unchanged, and validated this entry as number 8 of 100 with exactly six sections and allowed Status values.

#### Next Steps:

No speaker work remains. Continue with the next player or UI milestone; the 48 kHz resampling path and the AE350 resident player remain the current playback baseline.

#### Files Modified:

None.

#### Status:

- Build: N/A
- Deployment: N/A
- User Test: PASS

---

## 9 COMMIT Unreleased 2026-10-20T16:23:34-07:00

#### Coming From:

Unreleased 4ed81af

#### Purpose:

Qualify every Rockbox-supported corpus format through the resident AE350 player with a ten-second playback window.

#### Outcome:

The twelve-file corpus in `/root/media/music` was played through the resident AE350 player on the deployed seed 6 image, with each file allowed ten and a half seconds before `phosphor status` was read and the track stopped. WAV, FLAC, MP2, MP3, Ogg Vorbis, AAC in MP4, ALAC in M4A, WavPack, AC-3, TTA, WMA and Opus all reached the player, produced nonzero sample counts between 328,356 and 353,557 at 48000 Hz, and reported zero underruns; the counts cover roughly seven seconds of audio after the approximately 2.7-second load. The user confirmed all formats pass. Because every track was stopped after the window, this qualifies codec startup, decode and transport on the real card path but not end-of-file completion. No source change was required. The required core-syntax audit re-read `.ai/core.md` and `.ai/core-syntax.md`, inspected the complete `.ai/` diff, confirmed `.ai/core.md` was unchanged, and validated this entry as number 9 of 100 with exactly six sections and allowed Status values.

#### Next Steps:

Validate full-track completion and end-of-file handling on a representative subset before treating the codec path as complete, then continue with HDMI player UI and visualizer integration.

#### Files Modified:

None.

#### Status:

- Build: N/A
- Deployment: N/A
- User Test: PASS

---

## 10 COMMIT Unreleased 2026-10-20T19:07:28-07:00

#### Coming From:

Unreleased 40b1d9c

#### Purpose:

Rebuild and redeploy entry 8's image and restore the Pmod I2S2 output, which had gone silent while the MAX98357A speaker still played.

#### Outcome:

A fresh `SEED=6 tools/open/ae350_player.sh build/ae350_entry8` from `40b1d9c` passed every gate with the same placement and timing as entry 6 (`bus_clk` 151.814 MHz, AE350 hop present, no GB20 branch), but its `.bin` is SHA-256 `76acfadac72800d1ef4723d741da9a1503c2c851ccdeb56bb67e409d43f0964b` against entry 6's `80150f8b14c36de3b3c3d1bd11baaaba8843fcf529629c1faed56e72bc492e9e`: the only netlist difference is the four `boot_rom.rom.0.*` block RAMs, where 81 instruction words between `0x2c` and `0x318` differ, with identical strings and range constants and 20 more bytes of code in the qualified ROM. `firmware/ae350/boot/boot.c` was last written at 15:24, after entry 5's commit, and entry 6's sweep reused a boot hex it never rebuilt, so the qualified image carries a boot ROM that `HEAD` does not reproduce; the `HEAD` rebuild has not been run on hardware. The resident player rebuilt byte-identical to entry 7 (844,508 payload bytes, crc32 `d7ff73ff`). The qualified seed 6 `.bin` was put on the card as `/root/cores/console138k/tinyphosphor_e8_known.bin` and loaded with `tangload`; core 80 answered, `0xf8` read `0x0012c000` and `0x43e0` read `0x0000001b`, and `test.wav` played on the speaker but not the Pmod. The cause was the card's `/tang.ini`, which a previous session had rewritten to declare `pmod0 = i2s2`, while the Pmod I2S2 is seated in PMOD1, the socket beside the HDMI port, where TinyNES also drives it; the speaker has its own pins and was unaffected. The Tang-Phosphor core `phosphortang.bin` was silent on the Pmod under the same declaration, and played on the Pmod once `0xc0` was set to `0x0500`. The old file was saved as `/tang.ini.bak-pmod0-i2s2` and `/tang.ini` now declares `pmod0 = none` and `pmod1 = i2s2`, so `tangload` sends `0xc0 = 0x0500`; after reloading the qualified image, `test.wav` played for 14 seconds with 689,838 samples at 48000 Hz and zero underruns, and the user reported PASS for both the Pmod I2S2 and the speaker. A new regression was observed: `test.wav` no longer ends by itself, running 3,923,977 samples over 1:21 until stopped, where entry 7 recorded 1,753,721 samples for the same file. The required core-syntax audit re-read `.ai/core.md` and `.ai/core-syntax.md`, inspected the complete `.ai/` diff, confirmed `.ai/core.md` was unchanged, and validated this entry as number 10 of 100 with exactly six sections and allowed Status values.

#### Next Steps:

Fix end-of-file handling so a track stops by itself and the resident player accepts the next track, then validate full-track completion on a representative subset of the corpus. Separately, decide whether to qualify the `HEAD` boot ROM rebuild on hardware or recover the source of the qualified ROM, so the deployed image is reproducible from git; until then the qualified image is `build/ae350_clk/sweep/seed-6` with SHA-256 `80150f8b14c36de3b3c3d1bd11baaaba8843fcf529629c1faed56e72bc492e9e`.

#### Files Modified:

None.

#### Status:

- Build: PASS
- Deployment: PASS
- User Test: PASS

---

## 11 COMMIT Unreleased 2026-10-20T19:20:37-07:00

#### Coming From:

Unreleased 8127626

#### Purpose:

Make tracks on the resident AE350 player end by themselves instead of repeating until stopped.

#### Outcome:

A register trace of `test.wav` showed the decoder finishing each pass correctly, with `USER(3)` at 480,002 samples, while `USER(1)` tracks begun and `USER(2)` tracks finished kept climbing, `0x4020` stayed at run count 0 and `0x5c` stayed in the playing state: the resident player inherited from Tang-Phosphor never returned and asked for its next track with `QUERY_NEXT`, but TinyTang's file server answers every length-0 request with the size of the file it is serving, so the same track was handed back and played forever, and TinyTang, which counts a track complete only when the program returns and the sink completes, never saw an end. This has probably been present since entry 6; entry 7's 1,753,721 samples were about 3.6 passes of the file, and entry 9's ten-second windows hid it. `software/rbhost/host/platform_ae350.c` now plays one track per load: `resident_main()` takes the track, hands the rest of its PCM to the FPGA player after the decode, publishes the finished track, ends the play stream, drains any outstanding answer and returns `0x600d0000` with the decode status, so the boot ROM counts the run; stops still arrive as TinyTang's AE350 restart. The gapless multi-track queue is no longer used. The resident image rebuilt with `make bench-ondemand BENCH_NAME=tinyphosphor` to 844,772 payload bytes, crc32 `0d4a0a1d`, `.tpi` SHA-256 `3e9517042b4471ed16512f0c458e874191450b0a538f2ababf15819a1ee70210`, and replaced `/root/ae350/resident.tpi` on the card, with entry 7's image kept as `/root/ae350/resident.tpi.bak-e7`; the FPGA stayed on the qualified seed 6 image `/root/cores/console138k/tinyphosphor_e8_known.bin`. Blocking `phosphor play` runs of `test.wav`, then FLAC, MP3, AAC in MP4, Opus, WMA and WAV back to back, each returned by itself with playback complete and zero underruns, with 480,002 samples for WAV, FLAC, MP3 and AAC, 479,688 for Opus with result `0x600d0001` (the known trailing codec status after a complete decode), and 481,491 for WMA; `0x4020` read `0x00010001` after every track. The user reported PASS: every track ended cleanly on both the Pmod I2S2 and the MAX98357A speaker. The required core-syntax audit re-read `.ai/core.md` and `.ai/core-syntax.md`, inspected the complete `.ai/` diff, confirmed `.ai/core.md` was unchanged, and validated this entry as number 11 of 100 with exactly six sections and allowed Status values.

#### Next Steps:

Continue with HDMI player UI and visualizer integration. On the next FPGA build cycle, resolve the boot ROM reproducibility gap recorded in entry 10 by qualifying the `HEAD` boot ROM on hardware or recovering the source of the qualified ROM.

#### Files Modified:

- software/rbhost/host/platform_ae350.c

#### Status:

- Build: PASS
- Deployment: PASS
- User Test: PASS

---
