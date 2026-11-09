# SPDX-License-Identifier: GPL-2.0-or-later
#
# MPEG-2 Main Profile decode probe for the AE350.
#
#   make host  [CLIP=clip.m2v]   native build, prints the reference checksums
#   make ae350 [CLIP=clip.m2v]   AE350 image, build/bench/mpeg2probe.tpi
#
# libmpeg2 is compiled from third_party/rockbox unmodified; shim/ supplies the
# two headers Rockbox would have supplied (plugin.h and config.h) and alloc.c
# the memory contract the decoder expects.
#
# -DHAVE_LCD_COLOR makes mpeg2dec_config.h select three components, so chroma
# is decoded.  A luma-only build would report a decode cost no player could
# use.
#
# The input stream is embedded in the image, so the measurement excludes the
# link.  A 2.5 MB clip at 4 Mbit/s is about five seconds of video.

ROOT      := $(abspath ../..)
HERE      := $(abspath .)
BUILD     ?= $(ROOT)/build/mpeg2probe

RB        := $(ROOT)/third_party/rockbox
LIBMPEG2  := $(RB)/apps/plugins/mpegplayer/libmpeg2

CROSS     ?= riscv64-unknown-elf-
XCC       ?= $(CROSS)gcc
XOBJCOPY  ?= $(CROSS)objcopy

CLIP      ?= $(BUILD)/clip.m2v
NAME      ?= mpeg2probe

# -O2, the level Rockbox builds its faster codecs at.  -Os would be the
# conservative choice and is one flag away.
OPT       := -O2

COMMON    := -std=gnu11 $(OPT) -g -ffunction-sections -fdata-sections \
             -fno-common -fno-builtin -DHAVE_LCD_COLOR \
             -I$(HERE)/shim -I$(HERE) -I$(LIBMPEG2)

# Sources.  motion_comp_c.c is the generic C motion compensation, chosen by
# the same CPU_ selects that pick it on any non-ARM, non-Coldfire target.
LIB_SRC   := $(LIBMPEG2)/decode.c $(LIBMPEG2)/header.c $(LIBMPEG2)/idct.c \
             $(LIBMPEG2)/motion_comp.c $(LIBMPEG2)/motion_comp_c.c \
             $(LIBMPEG2)/slice.c
PROBE_SRC := $(HERE)/alloc.c $(HERE)/probe.c

ARCHFLAGS := -march=rv32imafdc_zicsr_zifencei -mabi=ilp32d

# ---- host reference -------------------------------------------------------

LIB_BASE  := $(basename $(notdir $(LIB_SRC)))
PROBE_BASE:= $(basename $(notdir $(PROBE_SRC)))

HOST_OBJ := $(addprefix $(BUILD)/host/,$(addsuffix .o,$(LIB_BASE) $(PROBE_BASE) main_host))

$(BUILD)/host/%.o: $(HERE)/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(COMMON) -c $< -o $@

$(BUILD)/host/%.o: $(LIBMPEG2)/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(COMMON) -c $< -o $@

$(BUILD)/mpeg2probe-host: $(HOST_OBJ)
	$(CC) -o $@ $^

host: $(BUILD)/mpeg2probe-host
	$(BUILD)/mpeg2probe-host $(CLIP)

# ---- AE350 ----------------------------------------------------------------

# bare/mem.c supplies memset, memcmp and memcpy: newlib is not linked.
AE_OBJ := $(addprefix $(BUILD)/ae/,$(addsuffix .o,$(LIB_BASE) $(PROBE_BASE) main_ae350 crt0 mem))

$(BUILD)/ae/%.o: $(HERE)/%.c
	@mkdir -p $(dir $@)
	$(XCC) $(ARCHFLAGS) $(COMMON) -I$(ROOT)/firmware/ae350/include -c $< -o $@

$(BUILD)/ae/%.o: $(LIBMPEG2)/%.c
	@mkdir -p $(dir $@)
	$(XCC) $(ARCHFLAGS) $(COMMON) -c $< -o $@

$(BUILD)/ae/mem.o: $(HERE)/bare/mem.c
	@mkdir -p $(dir $@)
	$(XCC) $(ARCHFLAGS) $(COMMON) -c $< -o $@

$(BUILD)/ae/crt0.o: $(ROOT)/firmware/ae350/lib/crt0.S
	@mkdir -p $(dir $@)
	$(XCC) $(ARCHFLAGS) -c $< -o $@

# The clip is embedded through .incbin rather than -D so no compiler can
# decide to move or reorder it.
#
# The stamp records which clip the .S was built from.  Without it, pointing
# CLIP at a different file whose timestamp is older than the .S leaves the
# previous clip embedded and the image builds happily with the wrong input --
# which happened once and would have been a wasted hardware run.
$(BUILD)/ae/input.stamp: FORCE
	@mkdir -p $(dir $@)
	@printf '%s\n' "$(abspath $(CLIP))" | cmp -s - $@ || \
		printf '%s\n' "$(abspath $(CLIP))" > $@

$(BUILD)/ae/input.S: $(CLIP) $(BUILD)/ae/input.stamp
	@mkdir -p $(dir $@)
	@printf '%s\n' \
		'	.section .rodata.input, "a"' \
		'	.balign 8' \
		'	.globl input_data' \
		'input_data:' \
		'	.incbin "$(abspath $(CLIP))"' \
		'	.globl input_end' \
		'input_end:' \
		'	.balign 4' > $@

$(BUILD)/ae/input.o: $(BUILD)/ae/input.S
	$(XCC) $(ARCHFLAGS) -c $< -o $@

$(BUILD)/$(NAME).elf: $(AE_OBJ) $(BUILD)/ae/input.o $(ROOT)/firmware/ae350/lib/program.ld
	$(XCC) $(ARCHFLAGS) -nostdlib -nostartfiles \
		-T $(ROOT)/firmware/ae350/lib/program.ld \
		-Wl,--no-relax -Wl,--gc-sections -Wl,-Map,$(@:.elf=.map) \
		-o $@ $(AE_OBJ) $(BUILD)/ae/input.o -lgcc

$(BUILD)/$(NAME).bin: $(BUILD)/$(NAME).elf
	$(XOBJCOPY) -O binary $< $@
	@size=$$(stat -c %s $@); echo "image payload: $$size bytes"; \
	 test $$size -le 33554432 || { echo "over the 32 MiB program window" >&2; exit 1; }

$(BUILD)/$(NAME).tpi: $(BUILD)/$(NAME).bin
	python3 $(ROOT)/tools/ae350_run.py pack $< -o $@
	@echo "built $@"

ae350: $(BUILD)/$(NAME).tpi

clean:
	rm -rf $(BUILD)

FORCE:

.PHONY: host ae350 clean
