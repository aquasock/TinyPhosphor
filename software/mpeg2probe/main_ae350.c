/* SPDX-License-Identifier: GPL-2.0-or-later
 *
 * The probe as an AE350 program.  Decodes an MPEG-2 elementary stream that
 * is embedded in the image, times the decode against the core cycle counter
 * and the 75 MHz fabric timer, and publishes raw counts.  All division and
 * every derived figure is done by tools/mpeg2probe_report.py on the host, so
 * nothing in the measured window does anything but decode.
 *
 * Result registers (ae350.h): see the publish() calls below.
 */
#include <stdint.h>

#include "ae350.h"
#include "probe.h"

extern const uint8_t input_data[];
extern const uint8_t input_end[];

#include "plugin.h"

struct plugin_api *mpeg2probe_rb(void);

static void put_hex(uint32_t value)
{
	for (int shift = 28; shift >= 0; shift -= 4)
		ae350_putc("0123456789abcdef"[(value >> shift) & 15u]);
}

static void publish64(uint32_t first, uint64_t value)
{
	AE350_REG(AE350_USER(first)) = (uint32_t)value;
	AE350_REG(AE350_USER(first + 1)) = (uint32_t)(value >> 32);
}

int main(void)
{
	static struct probe_result r;
	uint32_t bytes = (uint32_t)(input_end - input_data);
	uint64_t cycles, instructions, ticks;
	uint32_t reads, lat_sum, hits, errors;
	int status;

	rb = mpeg2probe_rb();

	reads   = AE350_REG(AE350_BRIDGE_READS);
	lat_sum = AE350_REG(AE350_BRIDGE_LAT_SUM);
	hits    = AE350_REG(AE350_BRIDGE_HITS);
	errors  = AE350_REG(AE350_BRIDGE_ERRORS);

	cycles       = ae350_cycles();
	instructions = ae350_instructions();
	ticks        = ae350_time();

	status = probe_run(input_data, bytes, &r, NULL);

	ticks        = ae350_time() - ticks;
	instructions = ae350_instructions() - instructions;
	cycles       = ae350_cycles() - cycles;

	reads   = AE350_REG(AE350_BRIDGE_READS)        - reads;
	lat_sum = AE350_REG(AE350_BRIDGE_LAT_SUM)      - lat_sum;
	hits    = AE350_REG(AE350_BRIDGE_HITS)         - hits;
	errors  = AE350_REG(AE350_BRIDGE_ERRORS)       - errors;

	AE350_REG(AE350_USER(0))  = (uint32_t)status;
	publish64(1, cycles);
	publish64(3, instructions);
	AE350_REG(AE350_USER(5))  = r.frames;
	AE350_REG(AE350_USER(6))  = r.crc_first;
	AE350_REG(AE350_USER(7))  = r.crc_last;
	publish64(8, ticks);
	AE350_REG(AE350_USER(10)) = r.i_frames;
	AE350_REG(AE350_USER(11)) = r.p_frames;
	AE350_REG(AE350_USER(12)) = r.b_frames;
	/* Geometry is already proved by the checksums; these three carry the
	 * memory attribution, which is what tells compute from stalls. */
	AE350_REG(AE350_USER(13)) = reads;
	AE350_REG(AE350_USER(14)) = lat_sum;
	AE350_REG(AE350_USER(15)) = hits;

	ae350_puts("mpeg2probe\r\ninput=");
	ae350_put_decimal(bytes);
	ae350_puts(" geometry=");
	ae350_put_decimal(r.width);
	ae350_putc('x');
	ae350_put_decimal(r.height);
	ae350_putc('@');
	ae350_put_decimal(r.stride);
	ae350_puts("\r\nframes=");
	ae350_put_decimal(r.frames);
	ae350_puts(" displayed=");
	ae350_put_decimal(r.displayed);
	ae350_puts(" I=");
	ae350_put_decimal(r.i_frames);
	ae350_puts(" P=");
	ae350_put_decimal(r.p_frames);
	ae350_puts(" B=");
	ae350_put_decimal(r.b_frames);
	ae350_puts(" other=");
	ae350_put_decimal(r.other_frames);
	ae350_puts(" invalid=");
	ae350_put_decimal(r.invalid);
	ae350_puts("\r\ncycles=");
	put_hex((uint32_t)cycles);
	ae350_puts(" instr=");
	put_hex((uint32_t)instructions);
	ae350_puts(" ticks75m=");
	put_hex((uint32_t)ticks);
	ae350_puts("\r\ncrc first=");
	put_hex(r.crc_first);
	ae350_puts(" last=");
	put_hex(r.crc_last);
	ae350_puts("\r\nbridge reads=");
	ae350_put_decimal(reads);
	ae350_puts(" lat_sum=");
	ae350_put_decimal(lat_sum);
	ae350_puts(" hits=");
	ae350_put_decimal(hits);
	ae350_puts(" errors=");
	ae350_put_decimal(errors);
	ae350_puts("\r\n");

	return (uint32_t)status;
}
