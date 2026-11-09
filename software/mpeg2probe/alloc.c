/* SPDX-License-Identifier: GPL-2.0-or-later
 *
 * The host services and the two allocators libmpeg2 expects, for a
 * standalone build.
 *
 * libmpeg2 takes its own memory from mpeg2_malloc/mpeg2_bufalloc rather than
 * the C library, because Rockbox's MPEG player hands it one contiguous pool.
 * The contract that matters is not the pool but the reset: mpeg2_mem_reset()
 * is called at every sequence header and must reclaim everything except the
 * dedicated buffers, so mpeg2dec_t and the chunk buffer survive.  A plain
 * bump allocator that reset to zero would wipe the decoder it is decoding
 * into.  This keeps Rockbox's split, with one pointer for the shared area and
 * one marking the end of the dedicated area.
 */
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "plugin.h"
#include "mpeg2.h"

struct plugin_api *rb;

/*
 * The decoder's working set, in SDRAM.  Three 720x480 4:2:0 frame buffers
 * are 1.5 MB, the chunk buffer and the tables are small, and a PAL frame at
 * 720x576 is a little larger, so 8 MiB leaves room to also try 1920x1080
 * without rebuilding.
 */
#define ARENA_BYTES (8u << 20)

static uint8_t arena[ARENA_BYTES];
static size_t arena_used;
static size_t dedicated_end;

/* libmpeg2 zeroes nothing itself; allocations are expected zeroed. */
static void *take(unsigned size)
{
	size_t rounded = (size + 3u) & ~(size_t)3u;

	if (rounded > ARENA_BYTES || arena_used + rounded > ARENA_BYTES)
		return NULL;
	void *p = &arena[arena_used];
	arena_used += rounded;
	memset(p, 0, rounded);
	return p;
}

void *mpeg2_malloc(unsigned size, mpeg2_alloc_t reason)
{
	(void)reason;
	return take(size);
}

void *mpeg2_bufalloc(unsigned size, mpeg2_alloc_t reason)
{
	void *p = mpeg2_malloc(size, reason);

	if (p)
		dedicated_end = arena_used;
	return p;
}

void *mpeg2_get_buf(size_t *size)
{
	if (arena_used + 32u >= ARENA_BYTES)
		return NULL;
	*size = ARENA_BYTES - arena_used;
	return &arena[arena_used];
}

/* Called at every sequence header: drop everything but the dedicated area. */
void mpeg2_mem_reset(void)
{
	arena_used = dedicated_end;
}

void mpeg2_alloc_init(unsigned char *buf, int mallocsize)
{
	(void)buf;
	(void)mallocsize;
	arena_used = 0;
	dedicated_end = 0;
}

/* mpeg2_close() frees through this; the pool is reclaimed by reset instead. */
void mpeg2_free(void *buf)
{
	(void)buf;
}

static struct plugin_api api = {
	.memset = memset,
	.memcmp = memcmp,
	.memcpy = memcpy,
};

struct plugin_api *mpeg2probe_rb(void);

struct plugin_api *mpeg2probe_rb(void)
{
	return &api;
}
