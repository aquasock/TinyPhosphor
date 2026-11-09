/* SPDX-License-Identifier: GPL-2.0-or-later
 *
 * memset, memcmp and memcpy for the bare-metal AE350 build.  Newlib is not
 * linked, and libmpeg2 reaches these three through the plugin_api shim.
 *
 * Word-at-a-time with byte tails: the AE350 has no vector unit, and the
 * decoder's hot paths do their own per-pixel loads and stores, so these are
 * on the cold side and simplicity is worth more than the last few percent.
 */
#include <stddef.h>
#include <stdint.h>

void *memset(void *dest, int c, size_t n)
{
	uint8_t *d = dest;
	uint8_t byte = (uint8_t)c;
	uint64_t word;
	size_t i;

	/* Broadcast the byte to a 64-bit word. */
	word = byte;
	word |= word << 8;
	word |= word << 16;
	word |= word << 32;

	while (n && ((uintptr_t)d & 7u)) {
		*d++ = byte;
		n--;
	}
	for (i = 0; i + 8 <= n; i += 8)
		((volatile uint64_t *)d)[i / 8] = word;
	d += i;
	n -= i;
	while (n--) {
		*d++ = byte;
	}
	return dest;
}

void *memcpy(void *dest, const void *src, size_t n)
{
	uint8_t *d = dest;
	const uint8_t *s = src;
	size_t i;

	while (n && (((uintptr_t)d | (uintptr_t)s) & 7u)) {
		*d++ = *s++;
		n--;
	}
	for (i = 0; i + 8 <= n; i += 8)
		((volatile uint64_t *)d)[i / 8] = ((const volatile uint64_t *)s)[i / 8];
	d += i;
	s += i;
	n -= i;
	while (n--) {
		*d++ = *s++;
	}
	return dest;
}

int memcmp(const void *a, const void *b, size_t n)
{
	const uint8_t *p = a;
	const uint8_t *q = b;

	while (n--) {
		if (*p != *q)
			return (int)*p - (int)*q;
		p++;
		q++;
	}
	return 0;
}
