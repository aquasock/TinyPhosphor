/* SPDX-License-Identifier: GPL-2.0-or-later
 *
 * The same decode on the host, for two things the board cannot give:
 *
 *   1. the reference for the luma checksums, so a hardware run can be proved
 *      to have decoded correctly rather than only quickly;
 *   2. a second measurement of cycles per pixel on a CPU whose IPC and cache
 *      behaviour are known, which is what makes the hardware number
 *      interpretable.
 *
 * Output format matches what tools/mpeg2probe_report.py expects.
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "probe.h"

#include "plugin.h"

struct plugin_api *mpeg2probe_rb(void);

static double seconds(void)
{
	struct timespec ts;

	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
}

int main(int argc, char **argv)
{
	static struct probe_result r;
	FILE *f;
	uint8_t *data;
	long size;
	double t0, dt;
	struct probe_dump dump, *dumpp = NULL;
	uint8_t *first = NULL, *last = NULL;
	int status;

	if (argc < 2 || argc > 4) {
		fprintf(stderr,
			"usage: %s <clip.m2v> [first_y.raw [last_y.raw]]\n"
			"  the optional paths receive the first and last displayed\n"
			"  luma planes, for comparison against a reference decoder;\n"
			"  a dump run is not a timing run\n", argv[0]);
		return 2;
	}
	f = fopen(argv[1], "rb");
	if (!f) {
		perror(argv[1]);
		return 2;
	}
	fseek(f, 0, SEEK_END);
	size = ftell(f);
	fseek(f, 0, SEEK_SET);
	data = malloc((size_t)size);
	if (!data || fread(data, 1, (size_t)size, f) != (size_t)size) {
		fprintf(stderr, "read failed\n");
		return 2;
	}
	fclose(f);

	rb = mpeg2probe_rb();

	if (argc >= 3) {
		first = malloc((size_t)720 * 576);
		last = malloc((size_t)720 * 576);
		dump.first = argc >= 3 ? first : NULL;
		dump.last = argc >= 4 ? last : NULL;
		dump.bytes = 720u * 576u;
		dumpp = &dump;
	}

	t0 = seconds();
	status = probe_run(data, (uint32_t)size, &r, dumpp);
	dt = seconds() - t0;

	printf("file=%s\n", argv[1]);
	printf("input=%ld\n", size);
	printf("geometry=%ux%u@%u\n", r.width, r.height, r.stride);
	printf("frames=%u displayed=%u i=%u p=%u b=%u other=%u invalid=%u status=%d\n",
	       r.frames, r.displayed, r.i_frames, r.p_frames, r.b_frames,
	       r.other_frames, r.invalid, status);
	printf("seconds=%.6f\n", dt);
	printf("crc_first=%08x crc_last=%08x luma_bytes=%u\n",
	       r.crc_first, r.crc_last, r.luma_bytes);

	if (dumpp && first) {
		FILE *o = fopen(argv[2], "wb");
		if (o) {
			fwrite(first, 1, r.luma_bytes, o);
			fclose(o);
			printf("dumped_first=%s bytes=%u\n", argv[2], r.luma_bytes);
		}
	}
	if (dumpp && last && argc >= 4) {
		FILE *o = fopen(argv[3], "wb");
		if (o) {
			fwrite(last, 1, r.luma_bytes, o);
			fclose(o);
			printf("dumped_last=%s bytes=%u\n", argv[3], r.luma_bytes);
		}
	}
	if (dt > 0.0 && r.frames) {
		printf("fps=%.3f cyc_per_pixel=%s\n", r.frames / dt, "host");
	}

	free(first);
	free(last);
	free(data);
	return status ? 1 : 0;
}
