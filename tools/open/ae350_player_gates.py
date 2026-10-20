#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Run both the player and AE350 gates on one routed AE350-player seed."""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import ae350_gates  # noqa: E402
import gates        # noqa: E402


def main():
    if len(sys.argv) != 4:
        raise SystemExit(
            "usage: ae350_player_gates.py <routed.json> <timing.json> <log>"
        )
    player_rc = gates.main(*sys.argv[1:])
    ae350_rc = ae350_gates.main(*sys.argv[1:])
    return player_rc or ae350_rc


if __name__ == "__main__":
    sys.exit(main())
