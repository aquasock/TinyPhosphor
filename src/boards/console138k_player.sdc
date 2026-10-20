# SPDX-License-Identifier: GPL-3.0-only
#
# TinyPhosphor player-only clocks, open-flow build.
#
# The PLL outputs are constrained at their primitive pins rather than at
# synthesized net aliases, which change with the front end.  The board
# oscillator is the only external clock; every other clock is derived from it.
#
# This nextpnr fork's SDC reader supports get_ports/get_cells/get_nets/get_pins,
# create_clock and a limited set_false_path only.  It has no set_clock_groups
# and no get_regs, so the domain relationships are left to the RTL's explicit
# synchronizers and FIFOs rather than declared here.  Place-and-route runs with
# --timing-allow-fail and the gates read the resulting per-clock Fmax.
#
# The HDMI chain is the acceptance path: 50 MHz -> 27 MHz -> 371.25 MHz serial
# and 74.25 MHz pixel.  The USB host runs at 12 MHz.  The I2S2 pair is on the
# left edge and is best-effort in the first image.

create_clock -name clk50 -period 20.000 [get_ports {sys_clk}]
create_clock -name clk27 -period 37.037 [get_pins {core.clock_27mhz.PLL_inst/CLKOUT0}]
create_clock -name clk_pixel_x5 -period 2.694 [get_pins {core.clock_hdmi.PLL_inst/CLKOUT1}]
create_clock -name clk_pixel -period 13.468 [get_pins {core.pixel_div/CLKOUT}]
create_clock -name clk12 -period 83.333 [get_pins {core.controller_clock.PLL_inst/CLKOUT0}]
create_clock -name clk_i2s2_ref -period 41.667 [get_pins {core.i2s2_reference_clock.PLL_inst/CLKOUT0}]
create_clock -name clk_i2s2_mclk -period 81.380208 [get_pins {core.i2s2_audio_clock.PLL_inst/CLKOUT0}]
