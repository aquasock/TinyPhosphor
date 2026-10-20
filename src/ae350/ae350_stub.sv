// SPDX-License-Identifier: GPL-3.0-only
//
// Open-flow bring-up stub for the AE350 subsystem.
//
// TinyPhosphor's first open-flow image is the FPGA player without the AE350
// and DDR3 subsystem: the merged image depends on Gowin's generated DDR3 IP,
// which the open flow does not provide.  This module keeps the real
// `ae350_subsystem` port list so `tang_phosphor_top` elaborates unchanged, and
// ties every output to a safe idle value.  `cpu_mode` resets to zero in
// `debug_regs`, so the top selects the FPGA player's stream path and never
// waits on these outputs.
//
// This is a build shim, not an AE350 implementation.  Do not describe an image
// built with it as carrying the AE350.  A later cycle either replaces this
// file with the real subsystem or keeps decoding on TinyTang's BL616.

module ae350_subsystem (
    input  logic        clk,
    input  logic        tclk,

    // SDRAM pins are declared by the shared player top.  The stub has no
    // SDRAM controller, so they are tied off.
    output logic        sdram_clk,
    output logic        sdram_cs_n,
    output logic        sdram_ras_n,
    output logic        sdram_cas_n,
    output logic        sdram_we_n,
    output logic [1:0]  sdram_ba,
    output logic [12:0] sdram_a,
    output logic [1:0]  sdram_dqm,
    inout  wire  [15:0] sdram_dq,

    output logic [14:0] ddr_addr,
    output logic [2:0]  ddr_bank,
    output logic        ddr_cs,
    output logic        ddr_ras,
    output logic        ddr_cas,
    output logic        ddr_we,
    output logic        ddr_ck,
    output logic        ddr_ck_n,
    output logic        ddr_cke,
    output logic        ddr_odt,
    output logic        ddr_reset_n,
    output logic [3:0]  ddr_dm,
    inout  wire  [31:0] ddr_dq,
    inout  wire  [3:0]  ddr_dqs,
    inout  wire  [3:0]  ddr_dqs_n,

    input  logic        stream_start,
    input  logic        stream_end,
    input  logic        stream_cancel,
    input  logic [7:0]  stream_data,
    input  logic        stream_valid,
    output logic        stream_ready,

    output logic        play_start,
    output logic        play_end,
    output logic        play_cancel,
    output logic [7:0]  play_data,
    output logic        play_valid,
    input  logic        play_ready,
    output logic [15:0] play_id,
    output logic [31:0] play_rate,

    input  logic        debug_valid,
    input  logic        debug_write,
    input  logic [31:0] debug_address,
    input  logic [31:0] debug_wdata,
    output logic [31:0] debug_rdata,

    input  logic        jtag_trst,
    input  logic        jtag_tck,
    input  logic        jtag_tms,
    input  logic        jtag_tdi,
    output logic        jtag_tdo,
    output logic        jtag_tdo_oe
);

    assign sdram_clk   = 1'b0;
    assign sdram_cs_n  = 1'b0;
    assign sdram_ras_n = 1'b0;
    assign sdram_cas_n = 1'b0;
    assign sdram_we_n  = 1'b0;
    assign sdram_ba    = 2'd0;
    assign sdram_a     = 13'd0;
    assign sdram_dqm   = 2'd0;
    assign sdram_dq    = 'z;

    assign ddr_addr    = 15'd0;
    assign ddr_bank    = 3'd0;
    assign ddr_cs      = 1'b0;
    assign ddr_ras     = 1'b0;
    assign ddr_cas     = 1'b0;
    assign ddr_we      = 1'b0;
    assign ddr_ck      = 1'b0;
    assign ddr_ck_n    = 1'b0;
    assign ddr_cke     = 1'b0;
    assign ddr_odt     = 1'b0;
    assign ddr_reset_n = 1'b0;
    assign ddr_dm      = 4'd0;
    assign ddr_dq      = 'z;
    assign ddr_dqs     = 'z;
    assign ddr_dqs_n   = 'z;

    assign stream_ready = 1'b0;

    assign play_start  = 1'b0;
    assign play_end    = 1'b0;
    assign play_cancel = 1'b0;
    assign play_data   = 8'd0;
    assign play_valid  = 1'b0;
    assign play_id     = 16'd0;
    assign play_rate   = 32'd0;

    assign debug_rdata = 32'd0;

    assign jtag_tdo    = 1'b0;
    assign jtag_tdo_oe = 1'b0;

endmodule
