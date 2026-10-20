#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Restore PLL string parameters that read_slang leaves as bit vectors.

`read_slang` keeps a Verilog string parameter as a bit vector, so a PLL's
`FCLKIN = "50"` or `CLKOUT0_EN = "TRUE"` reaches `gowin_pack` as ASCII bits and
the packer rejects it.  Convert only PLL-family cells: a whole-netlist rule
would corrupt LUT `INIT` values that happen to decode as printable text.

    tools/open/pll_strings.py <netlist.json>
"""

import json
import sys

PLL_TYPES = {"PLL", "PLLA", "rPLL", "PLLVR"}


def main(path: str) -> int:
    with open(path) as fh:
        doc = json.load(fh)

    converted = []
    for module in doc.get("modules", {}).values():
        for cell_name, cell in module.get("cells", {}).items():
            if cell.get("type") not in PLL_TYPES:
                continue
            params = cell.get("parameters") or {}
            for key, value in list(params.items()):
                if (
                    not isinstance(value, str)
                    or len(value) < 8
                    or len(value) % 8
                    or set(value) - set("01")
                ):
                    continue
                text = "".join(
                    chr(int(value[i : i + 8], 2)) for i in range(0, len(value), 8)
                )
                if all(0x20 <= ord(ch) <= 0x7E for ch in text):
                    params[key] = text
                    converted.append(f"{cell_name}.{key} = {text!r}")

    if converted:
        with open(path, "w") as fh:
            json.dump(doc, fh)
        print(f"PLL string parameters restored ({len(converted)}): "
              + ", ".join(converted))
    else:
        print("PLL string parameters restored: none")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: pll_strings.py <netlist.json>")
    sys.exit(main(sys.argv[1]))
