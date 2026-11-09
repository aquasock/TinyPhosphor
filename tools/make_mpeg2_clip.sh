#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Make an MPEG-2 Main Profile at Main Level elementary stream for the decode
# probe.  MP@ML is DVD's profile: 720x480 4:2:0, one of the eight H.262 frame
# rates, and a closed GOP with B pictures.
#
#   tools/make_mpeg2_clip.sh [out.m2v] [bitrate] [seconds] [source]
#
# Defaults: build/mpeg2probe/clip.m2v, 4M, 5 s, the lavfi testsrc2 pattern.
# testsrc2 rather than testsrc because it carries real motion, colour and
# detail, so the encoder produces a realistic spread of I, P and B macroblock
# types instead of mostly-skipped blocks.  A static clip would understate the
# decode cost.
#
# The GOP is the DVD shape -- 15 pictures, 2 B pictures -- so the measured
# stream has the reference-picture traffic a disc has.
#
# ffmpeg's output is not guaranteed byte-identical across versions; the
# parameters are pinned, the bytes are not.  Record the ffmpeg version with
# any measurement taken from a clip this script made.
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
out="${1:-$root/build/mpeg2probe/clip.m2v}"
bitrate="${2:-4M}"
seconds="${3:-5}"
source="${4:-testsrc2=size=720x480:rate=30000/1001:duration=$seconds}"

command -v ffmpeg >/dev/null || { echo "ffmpeg not found" >&2; exit 1; }
mkdir -p "$(dirname "$out")"

ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i "$source" \
    -c:v mpeg2video \
    -profile:v main -level:v main \
    -pix_fmt yuv420p \
    -b:v "$bitrate" -maxrate "$bitrate" -bufsize "$bitrate" \
    -g 15 -bf 2 \
    -f mpeg2video "$out"

ffprobe -hide_banner -loglevel error \
    -select_streams v:0 \
    -show_entries stream=codec_name,profile,width,height,r_frame_rate,nb_frames,bit_rate \
    -of default=noprint_wrappers=1 "$out"

printf 'clip=%s\n' "$out"
printf 'bytes=%s\n' "$(stat -c %s "$out")"
printf 'ffmpeg=%s\n' "$(ffmpeg -version | head -1 | cut -d' ' -f1-3)"
printf 'sha256=%s\n' "$(sha256sum "$out" | cut -d' ' -f1)"
