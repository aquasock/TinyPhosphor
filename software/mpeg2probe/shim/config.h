/* SPDX-License-Identifier: GPL-2.0-or-later
 *
 * Stands in for the config.h Rockbox's tools/configure generates.  libmpeg2
 * includes it only for the CPU_ architecture selects; none of them is set
 * here, so the decoder takes its portable C IDCT and motion compensation.
 * That is the point of the probe: it measures the generic paths, which are
 * the ones this board would actually run.
 */
#ifndef MPEG2PROBE_CONFIG_H
#define MPEG2PROBE_CONFIG_H

/* No CPU_COLDFIRE, no CPU_ARM_CLASSIC, no ARM_ARCH: generic C everywhere. */

#endif /* MPEG2PROBE_CONFIG_H */
