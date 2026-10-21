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

## 12 COMMIT Unreleased 2026-10-20T19:24:10-07:00

#### Coming From:

Unreleased e5a3295

#### Purpose:

Qualify full-track completion for the codecs and corpus files that entry 11 did not play to their end.

#### Outcome:

On the qualified seed 6 image `/root/cores/console138k/tinyphosphor_e8_known.bin` with entry 11's one-track resident player at `/root/ae350/resident.tpi` and `/tang.ini` declaring the Pmod I2S2 on PMOD1, blocking `phosphor play` runs of `test.ogg`, `test.m4a`, `test.wv`, `test.ac3`, `test.tta` and `test.mp2` from `/root/media/music` each returned by itself between 13.6 and 14.1 seconds with playback complete, zero underruns and player result `0x600d0000`. Vorbis, ALAC, WavPack and TTA produced 480,002 samples at 48000 Hz, AC-3 produced 481,491 and MP2 479,714, and `0x4020` read `0x00010001` after every track. With entry 11's WAV, FLAC, MP3, AAC, Opus and WMA runs, all eleven Rockbox codecs and all twelve corpus files have now played to their end and stopped on the deployed player. The user reported PASS: every track ended cleanly on both the Pmod I2S2 and the MAX98357A speaker. No source change was required. The required core-syntax audit re-read `.ai/core.md` and `.ai/core-syntax.md`, inspected the complete `.ai/` diff, confirmed `.ai/core.md` was unchanged, and validated this entry as number 12 of 100 with exactly six sections and allowed Status values.

#### Next Steps:

Continue with HDMI player UI and visualizer integration. On the next FPGA build cycle, resolve the boot ROM reproducibility gap recorded in entry 10 by qualifying the `HEAD` boot ROM on hardware or recovering the source of the qualified ROM.

#### Files Modified:

None.

#### Status:

- Build: N/A
- Deployment: N/A
- User Test: PASS

---

## 13 COMMIT Unreleased 2026-10-20T19:37:33-07:00

#### Coming From:

Unreleased 241a9ff

#### Purpose:

Survey the HDMI player UI and visualizer state and qualify the XY scope on hardware as the first step of the TinyTang desk-layer UI direction.

#### Outcome:

The survey found that the HDMI picture is the 96x64 frame store scaled by 11, filled only by `src/ui/ui_menu_renderer.sv` slice 1's address-encoded pattern, replaced by `src/visualizers/scope_xy.sv` when bit 0 of `0xac` is set, and covered by TinyTang's 80x45 desk layer when its overlay is on; `src/phosphor_video.sv` and `src/ui/phosphor_album_ui.sv` are in the source list but not instantiated, the `src/ui/phosphor_ui_control.sv` text, playlist, length, visibility and artwork registers feed nothing, album art was never implemented, and TinyTang never writes `0xac`. The user chose option A, a player UI in TinyTang's existing TinyDesk Phosphor app over the FPGA picture, rather than a native FPGA now-playing screen. On the qualified seed 6 image reloaded after a power cycle, with `/tang.ini` declaring the Pmod I2S2 on PMOD1, `phosphor poke 0xac 1` enabled the scope with `0xb4` reporting enabled and initialised, and `scope-circle-48000.wav`, `scope-lissajous-48000.wav` and `scope-diagonal-48000.wav` each played 192,000 samples at 48000 Hz with zero underruns, ended by themselves, and left the dropped-sample counter `0xb0` at zero; the user reported a perfect circle, a correct Lissajous figure and a correct diagonal, then PASS for `Special D. - Come with me.mp3` on the scope. A limitation was found: the resident player holds the whole file in its 4 MiB `INPUT_LIMIT` region at `0x41800000` and never starts a track larger than that, so `Crazy.mp3` at 7,460,996 bytes, most of `/root/media/music`, and the 49 MB 44.1 kHz `1 Function.flac` from N-Spheres cannot play. No source change was made. The required core-syntax audit re-read `.ai/core.md` and `.ai/core-syntax.md`, inspected the complete `.ai/` diff, confirmed `.ai/core.md` was unchanged, and validated this entry as number 13 of 100 with exactly six sections and allowed Status values.

#### Next Steps:

Make the resident player stream its input through a bounded window in `software/rbhost/host/platform_ae350.c` so tracks of any size play, keeping the backward seeks some codecs make, and qualify it on files above 4 MiB including `Crazy.mp3` and `1 Function.flac`. Then qualify TinyTang's TinyDesk Phosphor app against TinyPhosphor end to end, including auto-advance, and have the scope enabled during playback. The boot ROM reproducibility gap and the speaker headroom test remain for the next FPGA build cycle.

#### Files Modified:

None.

#### Status:

- Build: N/A
- Deployment: N/A
- User Test: PASS

---

## 14 COMMIT Unreleased 2026-10-20T20:12:31-07:00

#### Coming From:

Unreleased d3f4fec

#### Purpose:

Let the resident AE350 player stream tracks of any size instead of refusing any file larger than its 4 MiB input region.

#### Outcome:

`software/rbhost/host/platform_ae350.c` now treats the 4 MiB input region at `0x41800000` as a direct-mapped cache of 64 slots of 64 KiB, chunk c in slot c % 64: `_read` copies through the cache a chunk at a time and fetches a missing chunk on demand, the background prefetch keeps the 48 chunks from the latest read resident, the 16 chunks behind them stay for short seeks back, a read outside the window such as an MP4 index is fetched on demand, chunk 0 stays at `INPUT_BASE` for the format probe, and `wait_for_track()` accepts any 32-bit size; the `BENCH_STREAM=1` image keeps its contiguous buffer. TinyTang's `fpga_file_stream` already switches the link to 5 Mbaud for each answer, as Tang-PSX does, because TinyPhosphor reports the baud-switch capability. The resident image rebuilt with `make bench-ondemand BENCH_NAME=tinyphosphor` to 844,932 payload bytes, crc32 `7c007b8b`, `.tpi` SHA-256 `cb77d0d309e143e7457614573749dea86fd4c31acd9a58cca6abd02db0afbeca`, and replaced `/root/ae350/resident.tpi`, with entry 11's image kept as `/root/ae350/resident.tpi.bak-e11`; the FPGA stayed on the qualified seed 6 image. All twelve corpus files played to their end with the same sample counts as entries 11 and 12 and zero underruns. `Crazy.mp3`, 7,460,996 bytes and 433.76 seconds at 44.1 kHz, returned by itself after 438.1 seconds with 20,821,384 samples at 48000 Hz against 20,820,637 expected, zero underruns and result `0x600d0000`; an earlier run stopped at 420 seconds by a too-short test limit recorded 194,025 link requests with no timeouts or errors. N-Spheres `1 Function.flac` at 44.1 kHz, 49,082,237 bytes and 7:23, was put on the card as `/root/media/music/function.flac` in 32 seconds and played with the XY scope enabled; the user reported PASS for the audio and the scope, and the log was committed at the user's request while the track was still playing, so its completion line is not recorded here. The MAX98357A speaker was disconnected from J5 for the long runs because its level is too loud for a full song, and the user judged the large files on the Pmod I2S2. The required core-syntax audit re-read `.ai/core.md` and `.ai/core-syntax.md`, inspected the complete `.ai/` diff, confirmed `.ai/core.md` was unchanged, and validated this entry as number 14 of 100 with exactly six sections and allowed Status values.

#### Next Steps:

Qualify TinyTang's TinyDesk Phosphor app against TinyPhosphor end to end, including browse, play, pause, stop, next and auto-advance, and have the XY scope enabled during playback. On the next FPGA build cycle, resolve the boot ROM reproducibility gap from entry 10 and add a speaker-only attenuation or volume register for the MAX98357A, whose level is too loud for full songs.

#### Files Modified:

- software/rbhost/host/platform_ae350.c

#### Status:

- Build: PASS
- Deployment: PASS
- User Test: PASS

---
## 15 COMMIT Unreleased 2026-10-20T22:32:34-07:00

#### Coming From:

Unreleased 8060b8d

#### Purpose:

Qualify TinyTang's TinyDesk Phosphor app as TinyPhosphor's player interface, with the XY scope enabled during playback.

#### Outcome:

No source changed in this cycle. The qualified seed 6 image `/root/cores/console138k/tinyphosphor_e8_known.bin` was loaded with `tangload`, which declared `0xc0 = 0x0500` from `/tang.ini`. The MCLK probe read `0x0012c000`, the AE350 state read `0x1b`, and the scope was enabled from the shell with `phosphor poke 0xac 1` because the app has no scope control; entry 14's streaming `/root/ae350/resident.tpi` was the player. The first attempt ended when the user power-cycled the board to disconnect the forgotten MAX98357A speaker; the core was reloaded and the prep repeated. With the speaker disconnected, the user browsed `/root/media/music` in the Phosphor window and exercised Play, Pause and Resume, Stop, Prev, Next, auto-advance on a short track, and a track ending with auto-advance off, then played `function.flac`; the user reported PASS on the Pmod I2S2 and HDMI with the scope drawing. Afterwards the scope reported 0 dropped samples and 43,928 sweeps, and the last track reported 0 underruns. The core's cumulative underrun register `0x6c`, which clears only with the core, read 5,597. Shell tests with the counter read between phases showed that it grows only when a track starts after a stop, by 1,768 to 2,843 sample periods (37 to 59 ms), and stays still during playback, pause, resume, back-to-back completed tracks and idle. TinyTang's `drain()` in `phosphor_player.cpp` unpauses the sink to flush it, and after a stop the empty sink counts every period of the flush as an underrun, before the new track's baseline is taken and before its first sample, so no audio is lost and per-track reports stay correct. The window's no-core hint still names `/root/cores/console138k/phosphortang.bin`. The required core-syntax audit re-read `.ai/core.md` and `.ai/core-syntax.md`, inspected the complete `.ai/` diff, confirmed `.ai/core.md` was unchanged, and validated this entry as number 15 of 100 with exactly six sections and allowed Status values.

#### Next Steps:

In TinyTang, consider a scope toggle in the Phosphor window, a no-core hint naming the TinyPhosphor image, and a `drain()` that skips the unpause when the sink is already empty, so `0x6c` stops counting the flush after a stop. On the next FPGA build cycle, resolve the boot ROM reproducibility gap from entry 10, add a speaker-only attenuation or volume register for the MAX98357A, and add the MAX98357A to `.ai/core-reference.md`. Album art remains unimplemented.

#### Files Modified:

None.

#### Status:

- Build: N/A
- Deployment: PASS
- User Test: PASS

---
## 16 COMMIT Unreleased 2026-10-20T23:34:06-07:00

#### Coming From:

Unreleased 9f58024

#### Purpose:

Rebuild the FPGA image to close the boot ROM reproducibility gap, give the MAX98357A speaker a level control and add an HDMI audio cadence counter, then qualify it on hardware.

#### Outcome:

The cycle did not produce a qualified image, because the I2S2 audio PLL stopped locking in the rebuilt images, and it ends here as an agent handoff at the user's request with the user test not run. The boot ROM gap from entry 10 is closed on the source side: `tools/open/ae350_player.sh` now writes the boot hex's SHA-256 to `<out>/boot_rom.sha256`, a fresh build of `firmware/ae350` into an empty directory reproduced `735130b92d342e5cfcf60120a957054710c0529f0aa343f89ac0590f7a42799f` exactly, and the entry 8 rebuild that carries this `HEAD` ROM (`build/ae350_entry8/seed-6`, `.bin` SHA-256 `76acfada…`) loaded on hardware with the AE350 at `0x1b` and the audio PLL locked (`0xf8 = 0x0012c000`, `0xfc = 0x1f`). Only `0x43e0` was read on it, so the `HEAD` ROM is shown to boot but has not yet started a player and played a track. The new `src/audio/hdmi_audio_cadence.sv` counts the audio frames handed to the HDMI packetizer per second of the 74.25 MHz pixel clock, all frames in bits 15:0 and frames carrying a sample in bits 31:16, read at `0x2c`, and the register ABI is 1.11. A speaker data line mixed to mono and shifted down in 6 dB steps by a register at `0xbc` was built: seed 6 failed the GB20 gate, a sweep of seeds 1 to 5 and 7 to 9 passed only seed 1 (`bus_clk` 151.0 MHz), and that image (`.bin` SHA-256 `99f91a6c…`) booted the AE350 but its audio PLL never locked, with `0xfc = 0x2d` and an MCLK near 9.74 MHz (`0xf8 = 0x000ee0xx`). Diagnostic seed 6 images that ignore the AE350 gates split the change: the HDMI counter alone locked, while the speaker line alone and the full netlist did not. At the user's direction the speaker was then disabled instead, with the line removed and PA_EN held low so the amplifier stays in shutdown while BCLK, LRCLK and DIN carry the Pmod lane as before, but that netlist's seed 1 passed every gate (`bus_clk` 163.4 MHz, no GB20 branch, `.bin` SHA-256 `4912041653a8c6efa899786776235d2b470d763c4ac909a24daa74cd1ff02070`) and its audio PLL also failed to lock, both on load and after a power cycle. Lock therefore depends on the image rather than on the speaker logic, and the PLL cells' parameters and attributes, input routes, reset driver and output tiles were compared and found identical between locking and failing images; the evidence and the leading start-up race hypothesis are recorded in `.ai/core-reference.md` under "I2S2 audio PLL lock depends on the image (open)", beside the new MAX98357A entry. The committed source is the speaker-off and counter design whose seed 1 build fails to lock, differing from that build only by a source comment, so it must not be deployed as is. The card holds that image as `/root/cores/console138k/tinyphosphor_e16.bin`, with diagnostic images `diag_e16_s6.bin`, `diag_e8_rebuild.bin`, `diag_vA.bin` and `diag_vB.bin` beside it; the qualified image remains `/root/cores/console138k/tinyphosphor_e8_known.bin`, and the board was left running the failing image. The HDMI cadence was never measured because no failing image has an audio clock. The required core-syntax audit re-read `.ai/core.md` and `.ai/core-syntax.md`, inspected the complete `.ai/` diff, confirmed `.ai/core.md` was unchanged, and validated this entry as number 16 of 100 with exactly six sections and allowed Status values.

#### Next Steps:

Make the I2S2 audio PLL lock reliable before any other FPGA change: in `src/audio/i2s_clock_control.sv`, hold the audio PLL in reset until the reference PLL reports lock, re-pulse the reset if lock does not arrive within about 20 ms, and expose a retry count in the spare bits of `0xfc`; this change is proposed and awaits user approval. Rebuild seed 1, sweeping seeds if it fails the gates, and gate the image on `0xf8 = 0x0012c000` and `0xfc = 0x1f` after `tangload`; if it still fails to lock, the race hypothesis is wrong and the next step needs user approval. Then read `0x2c` during playback, expecting 48000 in each half, play a few corpus clips through the resident player to complete the `HEAD` boot ROM's qualification, and have the user test the Pmod I2S2 and HDMI audio and the Phosphor app before tagging v0.1.0. The speaker stays disabled; a level control can return once the lock is reliable.

#### Files Modified:

- src/audio/hdmi_audio_cadence.sv
- src/debug/debug_regs.sv
- src/tang_phosphor_top.sv
- tools/open/ae350_player.sh
- tools/open/ae350_player_sources.f
- tools/open/sources.f

#### Status:

- Build: PASS
- Deployment: PASS
- User Test: NOT RUN

---

## 17 COMMIT Unreleased 2026-10-21T05:27:53-07:00

#### Coming From:

Unreleased 8cbd0de

#### Purpose:

Make the I2S2 audio PLL lock reliably in every open-flow image so the Pmod I2S2 and HDMI audio always have a clock.

#### Outcome:

`src/audio/i2s_clock_control.sv` no longer pulses the audio PLL reset on a fixed delay: it holds `pll_reset` asserted until the synchronised reference lock arrives, waits 20 ms (1,485,000 `clk_pixel` cycles) in `LOCK` before re-pulsing and counting a retry, and reloads that window when lock drops from `SETTLE` or `RUN`, so a failing image now reports retries instead of waiting forever. `src/tang_phosphor_top.sv` and `src/debug/debug_regs.sv` expose the saturating 8-bit retry count in bits 15:8 of `0xfc`, leaving bits 5:0 unchanged, and the register ABI moves from 1.11 to 1.12. The cycle's first build used the local `~/tools/oss-cad-suite-20260925` tree (Yosys 0.69+152) and failed place and route on all eight seeds with `no BELs remaining to implement cell type '$buf'`; reverting every source change reproduced the same 19 partial-driver `$buf` cells, so the RTL was not at fault, and rebuilding with the suite the scripts default to (`$HOME/oss-cad-suite`, Yosys 0.69+260) produced a clean netlist of 32,260 cells. `tools/open/check_netlist.py` now fails the build when the top module still holds generic `$` cells other than `$scopeinfo`, naming the toolchain cause, and was verified to pass the real netlist and fail an injected `$buf`. The boot ROM rebuilt to its reproducible hash `735130b9…`, the eight-seed sweep passed seeds 2 and 6 with six seeds failing the GB20 branch rule, and seed 6 won with `bus_clk` 148.544 MHz against 75, `clk_pixel` 101.112 MHz against 74.25, the `AE350_CORE_CLK_PLLR0` hop present, no GB20 branch, six PLLs, four OSER10s, 205 two-clock-capable block RAMs and no hold violations. The packed artifacts are `build/ae350_e17/sweep/seed-6/tiny_phosphor_ae350_player.bin`, 5,063,660 bytes with SHA-256 `19b2c0a80638e8bdb7e6622bf8f837bdb384ec2f32c7ef1c7180bafce6216e68`, and `tiny_phosphor_ae350_player.fs`, 40,542,949 bytes with SHA-256 `e17d6a701f04bde599ab6b982323a8d86f586a67c2b65339879467f6d97ce038`. The `.bin` was put at `/root/cores/console138k/tinyphosphor_e17.bin` over the console with TinyTang's `tinytang_put.py` and loaded with `tangload`, which declared `0xc0 = 0x0500` from `/tang.ini`; core 80 answered, `0x43e0` read `0x0000001b`, `0xf8` read `0x0012c000`, and `0xfc` read `0x0000001f`, so the audio PLL locked on its first pulse with zero retries on a netlist family that had never locked, confirming the start-up race. The HDMI audio cadence was measured for the first time: `0x2c` read `0xbb80bb80` during `function.flac`, 48,000 audio frames per second with all 48,000 carrying a sample. `test.flac` and `test.mp3` each completed with 480,002 samples, zero underruns and result `0x600d0000`, `0x6c` stayed at zero, and `0x4020` read `0x00010001`, which also completes the `HEAD` boot ROM's qualification on hardware and closes the reproducibility gap recorded in entry 10. After the load the picture showed only the 96x64 color pattern because the scope enable at `0xac` bit 0 resets with the core and nothing sets it; `phosphor poke 0xac 1` brought the visualizer up. The user reported PASS for the Pmod I2S2, for HDMI audio, which had never been verified before, and for the picture and the scope. The old toolchain tree was deleted at the user's direction because Tang-Phosphor is retired. `.ai/core-reference.md` gained a record for the `$buf` toolchain gate and its PLL record moved from open to resolved with the hardware evidence. The required core-syntax audit re-read `.ai/core.md` and `.ai/core-syntax.md`, inspected the complete `.ai/` diff, confirmed `.ai/core.md` was unchanged, and validated this entry as number 17 of 100 with exactly six sections and allowed Status values.

#### Next Steps:

Make the XY scope come up without a shell poke, either by defaulting `scope_control` bit 0 at reset or by giving TinyTang's Phosphor window a scope toggle, then qualify that on hardware. The speaker stays in shutdown: its level control is no longer blocked on the PLL, but the Pmod I2S2 and HDMI audio are the priority outputs and the amplifier sounds poor off the Tang. Restoring runtime 44.1/48 kHz PLL switching would remove the fixed-48 kHz resampling, and the remaining UI work is album art, which is still unimplemented.

#### Files Modified:

- src/audio/i2s_clock_control.sv
- src/debug/debug_regs.sv
- src/tang_phosphor_top.sv
- tools/open/check_netlist.py

#### Status:

- Build: PASS
- Deployment: PASS
- User Test: PASS

---

## 18 COMMIT Unreleased 2026-10-21T05:49:44-07:00

#### Coming From:

Unreleased 589f495

#### Purpose:

Make the XY scope the picture as soon as the core loads, instead of waiting for a shell `phosphor poke 0xac 1`.

#### Outcome:

`src/debug/debug_regs.sv` now resets `scope_control` to `4'b0001` instead of zero. Bit 0 is the scope enable in `src/visualizers/scope_xy.sv`, and `src/video/ui_hdmi_backend.sv` selects the scope's pixels over the 96x64 colour pattern while it is set, so a fresh `tangload`, which writes no registers, previously left the picture on the colour pattern until a host wrote `0xac`. Trails and glow, bits 2:1 and bit 3, keep their zero defaults and a host can still override the whole word. The netlist is unchanged in size at 32,260 cells, but the constant moved placement enough that the eight-seed sweep passed only seed 4, the other seven failing the GB20 branch rule; seed 4 passed every gate with `clk_pixel` 92.234 MHz against 74.25, `clk12` 99.226 MHz, `bus_clk` 155.79 MHz against 75, no hold violations, no GB20 branch, six PLLs, four OSER10s and 205 two-clock-capable block RAMs. The packed artifacts are `build/ae350_e18/sweep/seed-4/tiny_phosphor_ae350_player.bin`, 5,063,660 bytes with SHA-256 `8e81fc985bc733bc5f3d174d96bd53611b0e26345d50ad10d4a66f367e5747af`, and `tiny_phosphor_ae350_player.fs` with SHA-256 `41db25d32646539a77afdf6c28d172251bce975561b00734a09f607d2050bded`. The `.bin` was put at `/root/cores/console138k/tinyphosphor_e18.bin` with TinyTang's `tinytang_put.py` and loaded with `tangload`, which declared `0xc0 = 0x0500`; core 80 answered, `0xac` read `0x00000001` with no host write, `0xf8` read `0x0012c000` and `0xfc` read `0x0000001f`, so the audio PLL again locked on its first pulse with zero retries. Playing `scope-circle-48000.wav` completed with 192,000 samples, zero underruns and result `0x600d0000`, advanced the sweep counter `0xb8` from 10,267 to 14,057 over the four-second track, and left the dropped-sample counter `0xb0` at zero, which shows the scope drawing from the reset default. The user reported PASS for the scope coming up by itself over the HDMI picture. `.ai/core-reference.md` gained a record stating that the scope enable is a reset default rather than a host step, because `tangload` writes no registers and TinyTang's Phosphor window has no scope control. The required core-syntax audit re-read `.ai/core.md` and `.ai/core-syntax.md`, inspected the complete `.ai/` diff, confirmed `.ai/core.md` was unchanged, and validated this entry as number 18 of 100 with exactly six sections and allowed Status values.

#### Next Steps:

The scope default is qualified; the next visualizer work is trails and glow, which are reachable only by writing `0xac` bits 2:1 and bit 3 and have no control in TinyTang's Phosphor window yet, so a host-side control is the remaining UI gap alongside album art. Restoring runtime 44.1/48 kHz PLL switching would remove the fixed-48 kHz resampling, and the speaker stays in shutdown while the Pmod I2S2 and HDMI audio remain the priority outputs.

#### Files Modified:

- src/debug/debug_regs.sv

#### Status:

- Build: PASS
- Deployment: PASS
- User Test: PASS

---

## 19 COMMIT Unreleased 2026-10-21T10:06:10-07:00

#### Coming From:

Unreleased 2312522

#### Purpose:

Give the XY scope the controls a host could not previously reach -- persistence, bloom, channel swap, dots and single-channel views -- through a wider control word at `0xac`.

#### Outcome:

`src/visualizers/scope_xy.sv` widened `control` and `settings` to sixteen bits and added, at register ABI 1.14: bit 3 instant (no decay; beats bits 2:1), bit 4 bloom, bit 5 freeze, bit 6 channel swap, bit 7 dots only, and 9:8 a channel select of XY, X only or Y only; bits 11:10 were reserved for colour. Bloom was fixed as a colour fringe: the first version added the halo to green, where an already bright green trace saturates and 12 to 25 percent more reads as no change at all, so the halo now goes to red and blue at quarter and half weight, the two channels a green beam is not using. Channel select and swap act on the source samples before the existing axis maps, so a zero channel lands on the map's centre. `status` was repacked -- settings at 31:16, the FIFO level at 15:8 -- because the previous layout put `settings[4]` at bit 24, which `status[31:24]=age_clock` then overwrote, so a bloom write read back as off. `mode_change` was masked to exclude bloom and freeze, since a control change clears the plane and a freeze that cleared it erased the image it was meant to hold. `src/debug/debug_regs.sv`, `src/tang_phosphor_top.sv`, `src/pmod_mirror_core.sv` and `src/video/ui_hdmi_backend.sv` carried the width through, and the ABI moved to 1.14. The cycle needed four netlists: the first with colour passed no seed of forty, its `bus_clk` route growing from 5,033 to 5,627 tokens and entering at `GB20` instead of `GB00`, so the colour multiplexer was removed at the user's direction and rebuilt; that netlist passed seed 2 of eight, and the freeze mask then passed seed 7 of eight. The shipped image is seed 7, `clk_pixel` 100.786 MHz, `bus_clk` 146.480 MHz, `clk12` 111.757 MHz, no hold violations, no GB20 branch, six PLLs, four OSER10s and 205 two-clock-capable block RAMs, packed as `build/ae350_e22/sweep/seed-7/tiny_phosphor_ae350_player.bin`, 5,047,788 bytes with SHA-256 `e946042428ae11e5e1e31c73dd38db9064e6289d67948a7afa7497f429cde4e4`, and installed on the card as both `tinyphosphor.bin` and `tinyphosphor_e22.bin`. The user tested it from the desktop's Phosphor app: persistence, bloom, swap, dots and the channel select all took effect, freeze instead blanked the screen, and the app's freeze and swap captions were clipped; the free function all worked as specified and the freeze control was removed at the user's direction, which needs no further build because nothing writes bit 5. Colour is deferred: the palette multiplexer is what moved the bus clock, so it returns in a cycle that does not also widen the drawing path. `.ai/core-reference.md` records the ABI 1.14 word, the reason bloom is a colour fringe, the status-word overlap and the reserved bits. The required core-syntax audit re-read `.ai/core.md` and `.ai/core-syntax.md`, inspected the complete `.ai/` diff, confirmed `.ai/core.md` was unchanged, and validated this entry as number 19 of 100 with exactly six sections and allowed Status values.

#### Next Steps:

Colour returns as its own cycle with a palette that does not widen the drawing path, since the four-way multiplexer is what pushed `bus_clk` onto GB20 across forty seeds; bit 5 remains reserved and the freeze gate in `scope_xy.sv` is unreachable, so it should be stripped with that build. The single-channel views and dots mode are qualified by the app test but not separately exercised as three checks. The older items stand: runtime 44.1/48 kHz PLL switching would remove the fixed-48 kHz resampling, album art is unimplemented, and the speaker stays in shutdown.

#### Files Modified:

- src/debug/debug_regs.sv
- src/pmod_mirror_core.sv
- src/tang_phosphor_top.sv
- src/video/ui_hdmi_backend.sv
- src/visualizers/scope_xy.sv

#### Status:

- Build: PASS
- Deployment: PASS
- User Test: PASS

---

## 20 COMMIT Unreleased 2026-10-21T10:27:51-07:00

#### Coming From:

Unreleased 6a89a6b

#### Purpose:

Replace the one-line README with documentation of what the project is, how it builds and what it still cannot do.

#### Outcome:

`README.md` was written from the state the log records rather than from the earlier bring-up notes. It states the target, the eleven Rockbox codec families, the 4 MiB streaming cache, the Pmod I2S2 and HDMI audio paths at 48 kHz, the disabled MAX98357A, the XY scope with its persistence, bloom, swap, dots and single-channel controls, and it points at TinyTang for the firmware, the app and the `phosphor` command. It documents the card layout -- the core image, `/root/ae350/resident.tpi` and `/tang.ini` with the socket declaration that has to match where the Pmod is seated -- and the build, including the `OSS_CAD_SUITE` default with the reason it matters (Yosys 0.69+152 leaves `$buf` cells this design cannot place), the one-seed and sweep commands with `SWEEP_APPROVED`, the gate list with the AE350 dedicated hop and the GB20 rule, and the two registers that gate a load, `0xf8` at `0x0012c000` and `0xfc` at `0x0000001f` with the retry count in bits 15:8. It records register ABI 1.14 including the 16-bit scope word at `0xac` and the reserved bits 5 and 11:10, describes the repository layout, and lists the limits: fixed 48 kHz with Rockbox resampling, the speaker in shutdown, and scope colour built twice and dropped because the palette moved the bus clock onto GB20. `docs/open-flow-build.md` was reframed: it presented the first player-only image as the product, so its introduction now says it covers the flow and the player-only profile while the shipped configuration is the AE350 player, its build section gives both commands, its gate list covers the AE350 gate scripts and `check_netlist.py`, and its limitations are scoped to the profile rather than to the project. `docs/ae350-smoke.md` was checked and remains accurate. The cycle also settled the sample-rate question without a build: the library on the card is 44.1 and 48 kHz throughout the Various folder -- 86 at 44.1, 12 with a second stream at 44.1, 4 at 48 and one at 22.05, `Cyriak - No More Memory.mp3` -- so native-rate clocking would change nothing audible and leave the odd file resampling anyway; a drive-wide scan was stopped at the user's request and no other folder was surveyed. No build, deployment or hardware test applied to this documentation-only cycle. The required core-syntax audit re-read `.ai/core.md` and `.ai/core-syntax.md`, inspected the complete `.ai/` diff, confirmed `.ai/core.md` was unchanged, and validated this entry as number 20 of 100 with exactly six sections and allowed Status values.

#### Next Steps:

The sample-rate change is deliberately not scheduled: the library is 44.1 and 48 throughout what was surveyed, so a second audio PLL would buy headroom and tidiness rather than any audible improvement, and the one 22.05 kHz file would still resample. Scope colour is the open feature, and the honest route is a palette applied outside the scope's timing path rather than another mux inside it. The placement rule that turns six ALUs into a GB20 failure on every seed is the largest engineering debt and would pay for itself across every future cycle. Album art remains unimplemented, the speaker stays in shutdown, and runtime rate switching waits on either that investigation or a decision that it is not wanted.

#### Files Modified:

- README.md
- docs/open-flow-build.md

#### Status:

- Build: N/A
- Deployment: N/A
- User Test: N/A

---
