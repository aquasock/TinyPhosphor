/* SPDX-License-Identifier: GPL-2.0-or-later
 *
 * MPEG-2 Main Profile decode probe: how much of a 750 MHz A25 one frame of
 * DVD video costs.
 */
#ifndef MPEG2PROBE_PROBE_H
#define MPEG2PROBE_PROBE_H

#include <stdint.h>

struct probe_result {
	/* Stream shape, from the sequence header. */
	uint32_t width;
	uint32_t height;
	uint32_t stride;

	/* Pictures handed to the display, by coding type. */
	uint32_t frames;         /* picture headers: the decode work done */
	uint32_t displayed;      /* pictures the decoder emitted */
	uint32_t i_frames;
	uint32_t p_frames;
	uint32_t b_frames;
	uint32_t other_frames;

	/* FNV-1a of the first and last displayed luma plane: the
	 * host-versus-hardware correctness check. */
	uint32_t crc_first;
	uint32_t crc_last;
	uint32_t luma_bytes;

	/* Counts that decide whether the run was sound. */
	uint32_t parses;
	uint32_t invalid;      /* STATE_INVALID occurrences */
	uint32_t seq_bytes;    /* input bytes consumed */

	/* Heap high-water mark, to report the decoder's footprint. */
	uint32_t arena_peak;

	/* Scanout emulation: bytes read back out of the decoded frames the way
	 * a display scanout reads them, and a checksum so the reads are not
	 * optimised away.  Equal to the plane sizes when emulation is on. */
	uint32_t scan_bytes;
	uint32_t scan_sum;
};

/*
 * Optional copies of the first and last displayed luma planes, for comparing
 * this decoder's output against a reference decoder.  Pass NULL for a timing
 * run: filling a dump copies a plane per displayed frame, which belongs in a
 * correctness run and not in a measurement.
 */
struct probe_dump {
	uint8_t *first;      /* one luma plane, in when first != NULL */
	uint8_t *last;       /* one luma plane, updated on every display */
	uint32_t bytes;      /* capacity of each, at least stride * height */
};

/*
 * Decode a whole MPEG-2 elementary stream held in memory.  Returns 0 if at
 * least one picture was displayed, -1 otherwise.  No timing: the caller
 * brackets this call so the measured window holds the decode and nothing
 * else.
 */
int probe_run(const uint8_t *data, uint32_t len, struct probe_result *out,
              struct probe_dump *dump);

/*
 * probe_run with the display's share of the memory bus included.
 *
 * A real player does not stop at "decode finished": the display reads the
 * finished frame back out of the same SDRAM, once per refresh, while the
 * decoder is working on the next one.  Setting scanout makes this probe walk
 * each displayed frame's three planes the way a raster scanout would, in
 * order, so the cycle count covers both users of the memory.  It is not a
 * scanout -- nothing is displayed and the reads are a burst per frame rather
 * than a row per line -- but it puts the right number of bytes through the
 * same controller, which is what the timing question needs.
 */
int probe_run_scanout(const uint8_t *data, uint32_t len,
                      struct probe_result *out);

/* Bytes of the decoder arena handed out, for the footprint report. */
struct probe_mem {
	uint32_t used;
	uint32_t total;
};

void probe_mem(struct probe_mem *m);

#endif /* MPEG2PROBE_PROBE_H */
