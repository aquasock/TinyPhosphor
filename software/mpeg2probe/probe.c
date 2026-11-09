/* SPDX-License-Identifier: GPL-2.0-or-later
 *
 * MPEG-2 Main Profile decode.  libmpeg2 from mpeg2dec 0.4.0b, as carried by
 * Rockbox's mpegplayer plugin, unmodified: this file is only the loop around
 * it.  See THIRD_PARTY.md for provenance and licensing.
 *
 * The loop follows libmpeg2's own example program.  A frame is counted and
 * checksummed when a new display buffer appears at a slice boundary, which is
 * the decoder telling us a picture finished, after any reordering.  The
 * luma plane of the first and last such frames are hashed so the same binary
 * run on another machine can be compared without copying pixels off the
 * board.
 */
#include <stddef.h>
#include <string.h>

#include "probe.h"

#include "mpeg2.h"

struct plugin_api *mpeg2probe_rb(void);

static uint32_t fnv1a(const uint8_t *p, uint32_t n)
{
	uint32_t h = 2166136261u;

	while (n--) {
		h ^= *p++;
		h *= 16777619u;
	}
	return h;
}

int probe_run(const uint8_t *data, uint32_t len, struct probe_result *out,
              struct probe_dump *dump)
{
	const mpeg2_info_t *info;
	mpeg2dec_t *dec;
	uint32_t guard = 0;

	memset(out, 0, sizeof *out);

	mpeg2_alloc_init(NULL, 0);
	dec = mpeg2_init();
	if (!dec)
		return -1;

	info = mpeg2_info(dec);
	mpeg2_buffer(dec, (uint8_t *)data, (uint8_t *)data + len);

	for (;;) {
		mpeg2_state_t state = mpeg2_parse(dec);

		out->parses++;

		switch (state) {
		case STATE_SEQUENCE:
		case STATE_SEQUENCE_REPEATED:
		case STATE_SEQUENCE_MODIFIED:
			out->width = info->sequence->width;
			out->height = info->sequence->height;
			out->stride = mpeg2_stride(dec, 0);
			break;

		/*
		 * Count at the picture header, not at the display buffer.
		 * One picture header arrives per coded picture, which is the
		 * decode work being measured; the display side reorders, and
		 * a buffer-identity test there drops pictures whenever two
		 * consecutive displays land in the same one.
		 */
		case STATE_PICTURE:
		case STATE_PICTURE_2ND:
			if (info->current_picture) {
				switch (info->current_picture->flags &
					PIC_MASK_CODING_TYPE) {
				case PIC_FLAG_CODING_TYPE_I:
					out->i_frames++;
					break;
				case PIC_FLAG_CODING_TYPE_P:
					out->p_frames++;
					break;
				case PIC_FLAG_CODING_TYPE_B:
					out->b_frames++;
					break;
				default:
					out->other_frames++;
					break;
				}
			}
			out->frames++;
			break;

		/*
		 * Checksums come from completed pictures, after reordering.
		 * Every slice state carrying a display buffer is hashed: the
		 * buffer identity is not a frame counter -- with three buffers
		 * in rotation and B pictures, consecutive displays reuse one
		 * roughly a third of the time, so a "changed buffer" test drops
		 * those frames and hashes the wrong one as the last.
		 */
		case STATE_SLICE:
		case STATE_SLICE_1ST:
			if (!info->display_fbuf || !out->stride || !out->height)
				break;
			if (out->displayed == 0) {
				out->luma_bytes = out->stride * out->height;
				out->crc_first = fnv1a(info->display_fbuf->buf[0],
						       out->luma_bytes);
			}
			out->crc_last = fnv1a(info->display_fbuf->buf[0],
					      out->stride * out->height);

			if (dump && dump->bytes >= out->stride * out->height) {
				uint32_t n = out->stride * out->height;

				if (out->displayed == 0 && dump->first)
					memcpy(dump->first,
					       info->display_fbuf->buf[0], n);
				if (dump->last)
					memcpy(dump->last,
					       info->display_fbuf->buf[0], n);
			}
			out->displayed++;
			break;

		case STATE_BUFFER:
		case STATE_END:
		case STATE_INVALID_END:
			goto done;

		case STATE_INVALID:
			out->invalid++;
			break;

		default:
			break;
		}

		/*
		 * A stream that never reaches a start code again would spin
		 * here; the guard is the parser's own count of states, so a
		 * stuck run reports rather than hangs.
		 */
		if (++guard > 40000000u)
			break;
	}

done:
	out->seq_bytes = (uint32_t)mpeg2_getpos(dec);
	mpeg2_close(dec);

	return out->frames ? 0 : -1;
}

void probe_mem(struct probe_mem *m)
{
	if (m) {
		m->used = 0;
		m->total = 0;
	}
}
