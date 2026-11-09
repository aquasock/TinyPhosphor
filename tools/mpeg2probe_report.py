#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Turn a completed mpeg2probe run into the numbers that decide the question.

The AE350 program publishes raw counts only; this does the arithmetic, so
nothing in the measured window multiplies or divides.  Feed it the result
registers, either from a `phosphor` run line or from explicit words.

  tools/mpeg2probe_report.py --frames 150 --cycles 4371324817 \
      --instructions 974414256 --ticks 437183956 --width 720 --height 480

It prints cycles per pixel, instructions per pixel, IPC, decode-only frames
per second, and the same run decomposed into a compute term and a
memory-stall term.  The decomposition uses three independently established
constants and no fitted parameters:

  570 cycles   a D-cache miss to SDRAM-dock memory, no overlap (AE350-009)
  0.95 IPC     this core on a dependent chain with no loads (AE350-007)
  33 lines     cache lines a macroblock's motion compensation touches: 17 for
               the 16x16 luma block (one per row, rows a stride apart) and 8
               each for the two 8x8 chroma planes

Each macroblock fetch is a fresh line because a frame is far larger than the
32 KiB D-cache, so a miss per touch is the model, not an assumption about
hit rate.
"""
import argparse
import sys

CORE_HZ = 750e6
MISS_CYCLES = 570.0
COMPUTE_IPC = 0.95
LINES_PER_MB = 33.0


def main():
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--frames", type=int, required=True)
    ap.add_argument("--cycles", type=lambda s: int(s, 0), required=True)
    ap.add_argument("--instructions", type=lambda s: int(s, 0), required=True)
    ap.add_argument("--ticks", type=lambda s: int(s, 0),
                    help="75 MHz fabric timer, to cross-check the core clock")
    ap.add_argument("--width", type=int, required=True)
    ap.add_argument("--height", type=int, required=True)
    ap.add_argument("--fps-budget", type=float, default=30000 / 1001,
                    help="target frame rate (default 29.97 for NTSC DVD)")
    args = ap.parse_args()

    w, h, n = args.width, args.height, args.frames
    px = w * h
    total = px * n
    cpp = args.cycles / total
    ipp = args.instructions / total
    ipc = args.instructions / args.cycles
    seconds = args.cycles / CORE_HZ
    per_frame_ms = seconds / n * 1e3
    fps = n / seconds
    budget_ms = 1e3 / args.fps_budget

    print(f"geometry            {w}x{h}  {px} px/frame, {n} frames")
    print(f"cycles              {args.cycles:,}")
    print(f"instructions        {args.instructions:,}")
    if args.ticks:
        tsec = args.ticks / 75e6
        print(f"ticks @75MHz        {args.ticks:,}  ({tsec:.4f} s)")
        print(f"implied core clock  {args.cycles / tsec / 1e6:.1f} MHz")
    print()
    print(f"cycles per pixel    {cpp:.2f}")
    print(f"instr per pixel     {ipp:.2f}")
    print(f"IPC                 {ipc:.3f}")
    print()
    print(f"decode-only         {per_frame_ms:.2f} ms/frame   {fps:.2f} fps")
    print(f"budget @{args.fps_budget:.2f} fps  {budget_ms:.2f} ms/frame   "
          f"{per_frame_ms / budget_ms:.2f}x over")
    print()

    mbs = (w // 16) * (h // 16)
    compute = args.instructions / COMPUTE_IPC
    stalls = mbs * n * LINES_PER_MB * MISS_CYCLES
    model = compute + stalls
    print(f"macroblock/frame    {mbs}")
    print(f"compute term        {compute:>16,.0f}  ({compute / args.cycles * 100:4.1f}% of measured)")
    print(f"stall term          {stalls:>16,.0f}  ({stalls / args.cycles * 100:4.1f}% of measured)")
    print(f"model total         {model:>16,.0f}  ({(model - args.cycles) / args.cycles * 100:+.1f}% vs measured)")
    print()
    print("decode-only if the memory term dropped to an L2 hit (240 cycles):")
    for label, miss in (("no L2, 570 cycles", 570.0),
                        ("L2 hit, 240 cycles", 240.0)):
        tot = compute + mbs * n * LINES_PER_MB * miss
        print(f"  {label:20s} {tot / CORE_HZ / n * 1e3:6.2f} ms/frame  "
              f"{n / (tot / CORE_HZ):6.1f} fps")
    return 0


if __name__ == "__main__":
    sys.exit(main())
