// SPDX-License-Identifier: GPL-3.0-only
//
// TinyPhosphor player-only top for the open FPGA flow.
//
// `tang_phosphor_player` is the player peripheral.  This wrapper exposes only
// the board pins a player-only image uses and holds the CPU interface idle;
// `cpu_mode` resets to zero, so the FPGA player owns the stream path.
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

    tang_phosphor_player core (
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
        .tmds_d_n   (tmds_d_n),

        // Player-only image: no CPU behind the transport.
        .clk_pixel         (),
        .debug_valid       (),
        .debug_write       (),
        .debug_address     (),
        .debug_wdata       (),
        .cpu_debug_valid   (),
        .ae350_debug_rdata (32'd0),
        .cpu_stream_start  (),
        .cpu_stream_end    (),
        .cpu_stream_cancel (),
        .cpu_stream_data   (),
        .cpu_stream_valid  (),
        .cpu_stream_ready  (1'b0),
        .cpu_play_start    (1'b0),
        .cpu_play_end      (1'b0),
        .cpu_play_cancel   (1'b0),
        .cpu_play_data     (8'd0),
        .cpu_play_valid    (1'b0),
        .cpu_play_id       (16'd0),
        .cpu_play_rate     (32'd0),
        .cpu_play_ready    ()
    );

endmodule
