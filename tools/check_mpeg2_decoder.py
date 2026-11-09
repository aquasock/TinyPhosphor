#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Check libmpeg2's decoded luma against ffmpeg's reference decode.

The two are independent implementations of H.262, so their IDCT rounding
differs by a least significant bit here and there.  A byte-exact comparison is
therefore the wrong test, and a hash comparison is useless -- one differing
sample changes the hash of 345,600 bytes.  What is meaningful is the maximum
absolute difference: two correct decoders agree to within one, and a decoder
with a real defect does not.

  tools/check_mpeg2_decoder.py <clip.m2v> <first_y.raw> <last_y.raw> \
      --last-index N

The raw planes come from the host build, which reports the display count:

  build/mpeg2probe/mpeg2probe-host <clip.m2v> first_y.raw last_y.raw

libmpeg2 displays in order and does not skip, so display k is reference frame
k; --last-index is that count minus one.  ffmpeg must be installed: it is the
only reference decoder here that is not our own code.
"""
import argparse
import subprocess
import sys

TOLERANCE = 2


def y_plane(raw, frame_bytes, width, height, index):
    base = index * frame_bytes
    return raw[base:base + width * height]


def compare(label, got, want):
    if len(got) != len(want):
        raise SystemExit(f"{label}: {len(got)} bytes, reference has {len(want)}")
    diffs = [abs(a - b) for a, b in zip(got, want)]
    peak = max(diffs) if diffs else 0
    differing = sum(1 for d in diffs if d)
    return peak, sum(diffs) / len(diffs), differing


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("clip")
    ap.add_argument("first_y")
    ap.add_argument("last_y")
    ap.add_argument("--last-index", type=int, required=True,
                    help="reference frame index the last dump corresponds to")
    args = ap.parse_args()

    probe = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0",
         "-show_entries", "stream=width,height",
         "-of", "default=noprint_wrappers=1", args.clip],
        check=True, capture_output=True, text=True)
    fields = dict(line.split("=", 1) for line in probe.stdout.split())
    width, height = int(fields["width"]), int(fields["height"])

    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", args.clip, "-pix_fmt", "yuv420p",
         "-f", "rawvideo", "-"],
        check=True, capture_output=True).stdout

    frame_bytes = width * height * 3 // 2
    nframes = len(raw) // frame_bytes
    if nframes == 0:
        raise SystemExit("ffmpeg produced no frames")
    if not 0 <= args.last_index < nframes:
        raise SystemExit(f"--last-index must be 0..{nframes - 1}")

    ok = True
    cases = [("first", args.first_y, 0), ("last", args.last_y, args.last_index)]
    for label, path, index in cases:
        with open(path, "rb") as f:
            got = f.read()
        want = y_plane(raw, frame_bytes, width, height, index)
        peak, mean, differing = compare(label, got, want)
        passed = peak <= TOLERANCE
        ok = ok and passed
        print(f"{label:5s} vs ffmpeg[{index}]: max_abs_diff={peak} "
              f"mean_abs_diff={mean:.5f} differing={differing}/{width * height} "
              f"{'PASS' if passed else 'FAIL'}")

    print(f"geometry={width}x{height} ffmpeg_frames={nframes} "
          f"tolerance={TOLERANCE}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
