# SPDX-License-Identifier: MIT
#
# TinyPhosphor AE350 + 32 MiB SDRAM smoke clocks.
#
# The AE350 PLL is at PLL_R[0]; CLKOUT0 is the 75 MHz AHB bus and CLKOUT1 the
# 750 MHz A25 core clock.  nextpnr names the bus clock net bus_clk and the
# gate reads its Fmax from the timing report.  The core clock uses the
# dedicated AE350_CORE_CLK_PLLR0 hop, which the gate checks in the routed
# netlist.  This fork's SDC reader has no set_clock_groups, so only the board
# oscillator is declared here.

create_clock -name sys_clk -period 20.000 [get_ports {sys_clk}]
