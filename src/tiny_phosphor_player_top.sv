// SPDX-License-Identifier: GPL-3.0-only
//
// TinyPhosphor player-only top for the open FPGA flow.
//
// `tang_phosphor_top` still names the AE350/DDR3 subsystem, so this wrapper
// keeps the real top unchanged and exposes only the board pins a player-only
// image uses.  The DDR ports are deliberately left unconnected here; the
// open-flow source list supplies `src/ae350/ae350_stub.sv` in place of the
// real subsystem, and `cpu_mode` resets to zero, so the FPGA player owns the
// stream path.
//
// The first image is an HDMI bring-up: it shows the 96x64 address-encoded
// menu frame at 1280x720.  It is not an AE350 image and does not play files
// through the AE350.

module tiny_phosphor_player_top (
    input        sys_clk,

    inout        [7:0] pmod0_io,
    inout        [7:0] pmod1_io,

    input        UART_RXD,
    output       UART_TXD,

    inout        usb1_dp,
    inout        usb1_dn,
    inout        usb2_dp,
    inout        usb2_dn,

    output       tmds_clk_p,
    output       tmds_clk_n,
    output [2:0] tmds_d_p,
    output [2:0] tmds_d_n
);

    tang_phosphor_top #(
        .AE350_JTAG_PMOD0 (1'b0)
    ) core (
        .sys_clk    (sys_clk),
        .pmod0_io   (pmod0_io),
        .pmod1_io   (pmod1_io),
        .UART_RXD   (UART_RXD),
        .UART_TXD   (UART_TXD),
        .usb1_dp    (usb1_dp),
        .usb1_dn    (usb1_dn),
        .usb2_dp    (usb2_dp),
        .usb2_dn    (usb2_dn),
        .tmds_clk_p (tmds_clk_p),
        .tmds_clk_n (tmds_clk_n),
        .tmds_d_p   (tmds_d_p),
        .tmds_d_n   (tmds_d_n)
        // DDR3 ports intentionally omitted: the AE350 stub drives them and
        // this image does not bring the memory controller up.
    );

endmodule
