/* SPDX-License-Identifier: GPL-2.0-or-later
 *
 * Stands in for Rockbox's plugin.h so libmpeg2 compiles outside a Rockbox
 * plugin.  The decoder touches only three host services, all through the
 * `rb` pointer: memset, memcmp and memcpy.
 */
#ifndef MPEG2PROBE_PLUGIN_H
#define MPEG2PROBE_PLUGIN_H

#include <stddef.h>
#include <stdint.h>
#include <string.h>

struct plugin_api {
	void *(*memset)(void *dest, int c, size_t n);
	int (*memcmp)(const void *s1, const void *s2, size_t n);
	void *(*memcpy)(void *dest, const void *src, size_t n);
};

extern struct plugin_api *rb;

/*
 * Rockbox section attributes.  On Rockbox these place objects in fast
 * internal RAM; here they place nothing, which is the honest equivalent -- an
 * AE350 has no IRAM to place into, only its caches.
 */
#define IBSS_ATTR
#define IDATA_ATTR
#define ICONST_ATTR
#define IRAM_ATTR
#define ICODE_ATTR
#define SHAREDBSS_ATTR
#define SHAREDDATA_ATTR

/* Rockbox's macros.h, the two the decoder uses. */
#ifndef ARRAYLEN
#define ARRAYLEN(a) (sizeof (a) / sizeof ((a)[0]))
#endif
#ifndef MIN
#define MIN(a, b) ((a) < (b) ? (a) : (b))
#endif

/* Rockbox's DEBUGF compiles out unless DEBUG is set. */
#define DEBUGF(...) do { } while (0)

#endif /* MPEG2PROBE_PLUGIN_H */
