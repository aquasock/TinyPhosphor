// SPDX-License-Identifier: GPL-3.0-only
//
// Tang-Phosphor AE350 + DDR3 subsystem, shared by the standalone AE350 image
// (ae350_ddr3_top, transport at 50 MHz) and the merged player image
// (tang_phosphor_top, transport at 74.25 MHz).  Everything here is moved
// unchanged from the former ae350_ddr3_top body except the transport-facing
// clock: the stream and debug interfaces are synchronous to tclk, which may
// be the 50 MHz board clock (standalone) or the 74.25 MHz pixel clock
// (merged).  The AE350/DDR3 logic itself keeps its own clock domains:
//
//   clk        50 MHz board oscillator: power-on reset, both PLLs'
//              reference, and the diagnostic status counters.
//   tclk       transport domain: the stream ingress and the Tang-Control
//              debug view (stream counters, flags, register readback).
//   ui_clk     100 MHz user clock of the Gowin DDR3 controller; only the
//              controller's native port and the far side of the RAM link
//              run here.  Held in reset until calibration.
//   bus_clk    75 MHz AE350 bus clock from PLL_R[0] CLKOUT0; it clocks the
//              AE350 AHB buses, the RAM bridge, and the register block.
//   core_clk   750 MHz A25 core clock from PLL_R[0] CLKOUT1.
//
// The DDR3 controller, its 400 MHz PLL, and the x32 pin mapping follow
// Sipeed's TangMega-138K-example ddr_memory design (Apache-2.0, commit
// 06e7d8b), as proven on this board by Tang-PSX; scripts/gen-ddr3-ip.sh
// regenerates the Gowin IP locally.
//
// Tang-Control debug view (reads of 0x000-0x3bc return the AE350 register
// block, see ae350_exts_regs.sv; the view aliases every 1 KiB and the
// merged top gates it into one 1 KiB window):
//   0x3c0 R  stream sessions, 0x3c4 bytes, 0x3c8 ends, 0x3cc cancels,
//            0x3d0 overflow
//   0x3e0 R  flags: bit 0 power-on reset done, 1 AE350 PLL locked, 2 DDR3
//            PLL locked, 3 DDR3 calibrated, 4 AE350 running
//   0x3e4 R  50 MHz cycles from power-on reset to calibration
//   0x3e8 R  50 MHz uptime
//   0x3f0 W  bit 0: restart the AE350 (R: restarts requested)

module ae350_subsystem (
    input  logic        clk,
    input  logic        tclk,

    // DDR3 pins are declared by the shared player top.  This SDRAM variant
    // does not drive them; they are tied off below.
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

    // 32 MiB J9 SDRAM, on the same memory port the AE350 calls DDR_H.
    output logic        sdram_clk,
    output logic        sdram_cs_n,
    output logic        sdram_ras_n,
    output logic        sdram_cas_n,
    output logic        sdram_we_n,
    output logic [1:0]  sdram_ba,
    output logic [12:0] sdram_a,
    output logic [1:0]  sdram_dqm,
    inout  wire  [15:0] sdram_dq,

    // Tang-Control stream (tclk domain).
    input  logic        stream_start,
    input  logic        stream_end,
    input  logic        stream_cancel,
    input  logic [7:0]  stream_data,
    input  logic        stream_valid,
    output logic        stream_ready,

    // Play stream from the AE350 to the player (tclk domain); see
    // ae350_play_stream.sv and registers 0x090-0x098 in ae350_exts_regs.sv.
    output logic        play_start,
    output logic        play_end,
    output logic        play_cancel,
    output logic [7:0]  play_data,
    output logic        play_valid,
    input  logic        play_ready,
    output logic [15:0] play_id,
    output logic [31:0] play_rate,

    // Tang-Control debug (tclk domain).
    input  logic        debug_valid,
    input  logic        debug_write,
    input  logic [31:0] debug_address,
    input  logic [31:0] debug_wdata,
    output logic [31:0] debug_rdata,

    // The A25's debug JTAG, straight to the macro (ae350_soc); tie TCK, TMS
    // and TRST high and TDI low when it is not brought out.
    input  logic        jtag_trst,
    input  logic        jtag_tck,
    input  logic        jtag_tms,
    input  logic        jtag_tdi,
    output logic        jtag_tdo,
    output logic        jtag_tdo_oe
);

    // The DDR3 pins are inert in this image.
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

    // ------------------------------------------------------------------
    // Board-clock power-on reset (about 1.3 ms).
    // ------------------------------------------------------------------
    logic [15:0] por_count = '1;
    logic        por_n = 1'b0;

    always_ff @(posedge clk) begin
        if (por_count != 0)
            por_count <= por_count - 16'd1;
        por_n <= por_count == 0;
    end

    // ------------------------------------------------------------------
    // AE350 core clock, bus clock, and reset.
    //
    // The A25 runs on core_clk (750 MHz from PLL_R[0] CLKOUT1); every AE350
    // fabric bus runs on bus_clk (75 MHz from the same PLL's CLKOUT0).  The
    // slower bus clock gives the macro's AHB output-to-input round trip
    // (about 4 ns output plus 5 ns setup) enough of the 13.3 ns period for
    // the bridge and register handshakes that failed at 100 MHz.
    // ------------------------------------------------------------------
    logic core_clk;
    logic bus_clk;
    logic ae350_pll_lock;

    ae350_pll cpu_pll (
        .lock    (ae350_pll_lock),
        .cpu_clk (core_clk),
        .bus_clk (bus_clk),
        .clkin   (clk)
    );

    // Host restart request, written through the debug view in the transport
    // domain and synchronized into the AE350 bus domain.
    logic [15:0] restart_count;
    logic [31:0] restarts;
    wire         restart = restart_count != 0;

    // The debug write that requests a restart is decoded into a register so
    // the transport's debug address does not share a combinational path with
    // the 16-bit restart counter on tclk.
    logic restart_req;
    always_ff @(posedge tclk)
        restart_req <= debug_valid && debug_write &&
                       debug_address[9:0] == 10'h3f0 && debug_wdata[0];

    // The bus domain comes out of reset only once the AE350 PLL is locked
    // and the SDRAM controller has finished its 200 us initialization.
    // sdram_ready is already in bus_clk, so it is used directly; the PLL lock
    // is synchronized into bus_clk with two stages.
    logic       sdram_ready;
    logic [1:0] ae350_lock_bus /* synthesis syn_srlstyle = "registers" */;
    logic [1:0] restart_bus    /* synthesis syn_srlstyle = "registers" */;
    logic [7:0] cpu_reset_count = 8'hff;
    logic       cpu_resetn = 1'b0;

    always_ff @(posedge bus_clk) begin
        ae350_lock_bus <= {ae350_lock_bus[0], ae350_pll_lock};
        restart_bus    <= {restart_bus[0], restart};
        if (!sdram_ready || !ae350_lock_bus[1] || restart_bus[1]) begin
            cpu_reset_count <= 8'hff;
            cpu_resetn      <= 1'b0;
        end else if (cpu_reset_count != 0) begin
            cpu_reset_count <= cpu_reset_count - 8'd1;
        end else begin
            cpu_resetn <= 1'b1;
        end
    end

    // ------------------------------------------------------------------
    // AE350 and its fabric ports.
    // ------------------------------------------------------------------
    logic [31:0] rom_haddr, rom_hrdata;
    logic [1:0]  rom_htrans;
    logic        rom_hready;

    logic [31:0] exts_haddr, exts_hwdata, exts_hrdata;
    logic        exts_hsel, exts_hwrite, exts_hready;
    logic [1:0]  exts_htrans;
    logic [2:0]  exts_hsize;

    logic [31:0] ram_haddr;
    logic [1:0]  ram_htrans;
    logic        ram_hwrite, ram_hready, ram_hresp;
    logic [2:0]  ram_hsize, ram_hburst;
    logic [63:0] ram_hwdata, ram_hrdata;

    (* keep *) AE350_SOC soc (
        .POR_N(1'b1),
        .HW_RSTN(cpu_resetn),
        .CORE_CLK(core_clk),
        .DDR_CLK(bus_clk),
        .AHB_CLK(bus_clk),
        .APB_CLK(bus_clk),
        .DBG_TCK(jtag_tck),
        .RTC_CLK(bus_clk),
        .CORE_CE(1'b1),
        .AXI_CE(1'b1),
        .DDR_CE(1'b1),
        .AHB_CE(1'b1),
        .APB_CE(8'b00000001),
        .APB2AHB_CE(1'b1),
        .PRESETN(),
        .HRESETN(),
        .DDR_RSTN(),

        .GP_INT(16'b0),
        .DMA_REQ(8'b0),
        .DMA_ACK(),
        .CORE0_WFI_MODE(),
        .WAKEUP_IN(1'b0),
        .RTC_WAKEUP(),
        .SCAN_TEST(1'b0),
        .SCAN_EN(1'b0),
        .SCAN_IN(20'hfffff),
        .SCAN_OUT(),
        .TEST_CLK(1'b0),
        .TEST_MODE(1'b0),
        .TEST_RSTN(1'b1),

        .INTEG_TCK(1'b1),
        .INTEG_TDI(1'b1),
        .INTEG_TMS(1'b1),
        .INTEG_TRST(1'b0),
        .INTEG_TDO(),

        .PGEN_CHAIN_I(1'b1),
        .PRDYN_CHAIN_O(),
        .EMA(3'b011),
        .EMAW(2'b01),
        .EMAS(1'b0),
        .RET1N(1'b1),
        .RET2N(1'b1),

        .ROM_HADDR(rom_haddr),
        .ROM_HRDATA(rom_hrdata),
        .ROM_HREADY(rom_hready),
        .ROM_HRESP(1'b0),
        .ROM_HTRANS(rom_htrans),
        .ROM_HWRITE(),

        .APB_PADDR(),
        .APB_PENABLE(),
        .APB_PRDATA(32'b0),
        .APB_PREADY(1'b1),
        .APB_PSEL(),
        .APB_PWDATA(),
        .APB_PWRITE(),
        .APB_PSLVERR(1'b0),
        .APB_PPROT(),
        .APB_PSTRB(),

        .EXTS_HRDATA(exts_hrdata),
        .EXTS_HREADYIN(exts_hready),
        .EXTS_HRESP(1'b0),
        .EXTS_HADDR(exts_haddr),
        .EXTS_HBURST(),
        .EXTS_HPROT(),
        .EXTS_HSEL(exts_hsel),
        .EXTS_HSIZE(exts_hsize),
        .EXTS_HTRANS(exts_htrans),
        .EXTS_HWDATA(exts_hwdata),
        .EXTS_HWRITE(exts_hwrite),

        .EXTM_HADDR(32'b0),
        .EXTM_HBURST(3'b0),
        .EXTM_HPROT(4'b0),
        .EXTM_HRDATA(),
        .EXTM_HREADY(1'b1),
        .EXTM_HREADYOUT(),
        .EXTM_HRESP(),
        .EXTM_HSEL(1'b0),
        .EXTM_HSIZE(3'b0),
        .EXTM_HTRANS(2'b0),
        .EXTM_HWDATA(64'b0),
        .EXTM_HWRITE(1'b0),

        .DDR_HADDR(ram_haddr),
        .DDR_HBURST(ram_hburst),
        .DDR_HPROT(),
        .DDR_HRDATA(ram_hrdata),
        .DDR_HREADY(ram_hready),
        .DDR_HRESP(ram_hresp),
        .DDR_HSIZE(ram_hsize),
        .DDR_HTRANS(ram_htrans),
        .DDR_HWDATA(ram_hwdata),
        .DDR_HWRITE(ram_hwrite),

        .TMS_IN(jtag_tms),
        .TRST_IN(jtag_trst),
        .TDI_IN(jtag_tdi),
        .TDO_OUT(jtag_tdo),
        .TDO_OE(jtag_tdo_oe),

        .SPI2_HOLDN_IN(1'b0),
        .SPI2_WPN_IN(1'b0),
        .SPI2_CLK_IN(1'b0),
        .SPI2_CSN_IN(1'b0),
        .SPI2_MISO_IN(1'b0),
        .SPI2_MOSI_IN(1'b0),
        .SPI2_HOLDN_OUT(),
        .SPI2_HOLDN_OE(),
        .SPI2_WPN_OUT(),
        .SPI2_WPN_OE(),
        .SPI2_CLK_OUT(),
        .SPI2_CLK_OE(),
        .SPI2_CSN_OUT(),
        .SPI2_CSN_OE(),
        .SPI2_MISO_OUT(),
        .SPI2_MISO_OE(),
        .SPI2_MOSI_OUT(),
        .SPI2_MOSI_OE(),

        .I2C_SCL_IN(1'b0),
        .I2C_SDA_IN(1'b0),
        .I2C_SCL(),
        .I2C_SDA(),

        .UART1_TXD(),
        .UART1_RTSN(),
        .UART1_RXD(1'b0),
        .UART1_CTSN(1'b0),
        .UART1_DSRN(1'b0),
        .UART1_DCDN(1'b0),
        .UART1_RIN(1'b0),
        .UART1_DTRN(),
        .UART1_OUT1N(),
        .UART1_OUT2N(),
        .UART2_TXD(),
        .UART2_RTSN(),
        .UART2_RXD(1'b0),
        .UART2_CTSN(1'b1),
        .UART2_DCDN(1'b1),
        .UART2_DSRN(1'b1),
        .UART2_RIN(1'b1),
        .UART2_DTRN(),
        .UART2_OUT1N(),
        .UART2_OUT2N(),

        .CH0_PWM(),
        .CH0_PWMOE(),
        .CH1_PWM(),
        .CH1_PWMOE(),
        .CH2_PWM(),
        .CH2_PWMOE(),
        .CH3_PWM(),
        .CH3_PWMOE(),
        .GPIO_IN(32'b0),
        .GPIO_OE(),
        .GPIO_OUT()
    );

    ae350_boot_rom #(.INIT_FILE("build/ae350/boot/ae350_boot.hex")) boot_rom (
        .clk    (bus_clk),
        .rst    (!cpu_resetn),
        .haddr  (rom_haddr),
        .htrans (rom_htrans),
        .hrdata (rom_hrdata),
        .hready (rom_hready)
    );

    // Memory-side diagnostics are zero: this image has no RAM bridge.
    logic [31:0] bridge_reads = 0, bridge_writes = 0, bridge_latency_sum = 0;
    logic [31:0] bridge_latency_max = 0, bridge_buffer_hits = 0, bridge_errors = 0;
    logic [31:0] bridge_trace_addr [16];
    logic [15:0] bridge_trace_info [16];
    logic [7:0]  bridge_trace_status = 0;
    logic [31:0] bridge_first_error = 0, bridge_state = 0;

    always_comb begin
        for (int i = 0; i < 16; i++) begin
            bridge_trace_addr[i] = 32'd0;
            bridge_trace_info[i] = 16'd0;
        end
    end

    // 32 MiB J9 SDRAM on the AE350 RAM (DDR_H) port.  ahb_ram decodes the
    // 64 KiB block RAM at 0x60000000 and the SDRAM at 0x40000000; ahb_sdram
    // owns the J9 pins and its 200 us initialization.  The CPU is held in
    // reset until sdram_ready, so the boot ROM's block-RAM stack is available
    // immediately and program loads into SDRAM cannot race initialization.
    logic        sd_req, sd_write;
    logic [24:3] sd_addr;
    logic [7:0]  sd_lanes;
    logic [63:0] sd_wdata, sd_rdata;
    logic        sd_ack;
    logic        mem_resetn = por_n && ae350_pll_lock;

    ahb_ram ram (
        .clk      (bus_clk),
        .resetn   (mem_resetn),
        .haddr    (ram_haddr),
        .htrans   (ram_htrans),
        .hwrite   (ram_hwrite),
        .hsize    (ram_hsize),
        .hprot0   (1'b0),
        .hwdata   (ram_hwdata),
        .hrdata   (ram_hrdata),
        .hready   (ram_hready),
        .hresp    (ram_hresp),
        .stray    (),
        .sd_req   (sd_req),
        .sd_write (sd_write),
        .sd_addr  (sd_addr),
        .sd_lanes (sd_lanes),
        .sd_wdata (sd_wdata),
        .sd_ack   (sd_ack),
        .sd_rdata (sd_rdata)
    );

    ahb_sdram sdram (
        .clk         (bus_clk),
        .resetn      (mem_resetn),
        .req         (sd_req),
        .write       (sd_write),
        .addr        (sd_addr),
        .lanes       (sd_lanes),
        .wdata       (sd_wdata),
        .ack         (sd_ack),
        .rdata       (sd_rdata),
        .ready       (sdram_ready),
        .vstart      (1'b0),
        .vaddr       (17'd0),
        .vvalid      (),
        .vindex      (),
        .vdata       (),
        .vdone       (),
        .sdram_clk   (sdram_clk),
        .sdram_cs_n  (sdram_cs_n),
        .sdram_ras_n (sdram_ras_n),
        .sdram_cas_n (sdram_cas_n),
        .sdram_we_n  (sdram_we_n),
        .sdram_ba    (sdram_ba),
        .sdram_a     (sdram_a),
        .sdram_dqm   (sdram_dqm),
        .sdram_dq    (sdram_dq)
    );

    // ------------------------------------------------------------------
    // Program loading through the Tang-Control stream (tclk ingress).
    // ------------------------------------------------------------------
    logic [31:0] stream_sessions, stream_bytes, stream_ends, stream_cancels;
    logic        stream_overflow;
    logic        entry_valid, entry_pop;
    logic [1:0]  entry_tag;
    logic [31:0] entry_data;

    // por_sync_tclk is the synchronized power-on reset for the loader's
    // stream side (same domain as its sclk).  Declared before the loader
    // instantiation and driven by an assign so Gowin does not drop it as an
    // implicit-declaration redeclaration.
    wire por_sync_tclk;

    ae350_stream_loader loader (
        .sclk        (tclk),
        .srst        (!por_sync_tclk),
        .start       (stream_start),
        .stop        (stream_end),
        .cancel      (stream_cancel),
        .data        (stream_data),
        .valid       (stream_valid),
        .ready       (stream_ready),
        .sessions    (stream_sessions),
        .bytes       (stream_bytes),
        .ends        (stream_ends),
        .cancels     (stream_cancels),
        .overflow    (stream_overflow),
        .cclk        (bus_clk),
        .entry_valid (entry_valid),
        .entry_tag   (entry_tag),
        .entry_data  (entry_data),
        .entry_pop   (entry_pop)
    );

    logic [1:0] stream_overflow_bus /* synthesis syn_srlstyle = "registers" */;
    always_ff @(posedge bus_clk)
        stream_overflow_bus <= {stream_overflow_bus[0], stream_overflow};

    logic [7:0]  regs_dbg_addr;
    logic [31:0] regs_dbg_rdata;

    logic        play_w_valid, play_w_ready;
    logic [1:0]  play_w_kind, play_w_count;
    logic [31:0] play_w_data;

    ae350_exts_regs regs (
        .clk                (bus_clk),
        .rst                (!cpu_resetn),
        .haddr              (exts_haddr),
        .hsel               (exts_hsel),
        .htrans             (exts_htrans),
        .hwrite             (exts_hwrite),
        .hsize              (exts_hsize),
        .hwdata             (exts_hwdata),
        .hrdata             (exts_hrdata),
        .hready             (exts_hready),
        .entry_valid        (entry_valid),
        .entry_tag          (entry_tag),
        .entry_data         (entry_data),
        .entry_pop          (entry_pop),
        .stream_overflow    (stream_overflow_bus[1]),
        .play_valid         (play_w_valid),
        .play_kind          (play_w_kind),
        .play_count         (play_w_count),
        .play_data          (play_w_data),
        .play_ready         (play_w_ready),
        .bridge_reads       (bridge_reads),
        .bridge_writes      (bridge_writes),
        .bridge_latency_sum (bridge_latency_sum),
        .bridge_latency_max (bridge_latency_max),
        .bridge_buffer_hits (bridge_buffer_hits),
        .bridge_errors      (bridge_errors),
        .bridge_trace_addr  (bridge_trace_addr),
        .bridge_trace_info  (bridge_trace_info),
        .bridge_trace_status(bridge_trace_status),
        .bridge_first_error (bridge_first_error),
        .bridge_state       (bridge_state),
        .dbg_addr           (regs_dbg_addr),
        .dbg_rdata          (regs_dbg_rdata)
    );

    // ------------------------------------------------------------------
    // Transport-domain status and debug view.
    //
    // The register readback crosses bus_clk -> tclk through debug_read_cdc.
    // The single-bit status flags cross into tclk with two-stage
    // synchronizers; the diagnostic counters stay in the 50 MHz clk domain
    // so their rate is identical in the standalone and merged images, and
    // are synchronized for display only (a read may tear by one count).
    // ------------------------------------------------------------------
    logic [31:0] regs_rdata;

    // Read word address, registered so the transport's address register
    // reaches this block's read multiplexer through no shared decode logic.
    logic [7:0] read_word;
    always_ff @(posedge tclk)
        read_word <= debug_address[9:2];

    debug_read_cdc #(
        .ADDR_BITS      (8),
        .TARGET_LATENCY (3)
    ) regs_read (
        .dclk   (tclk),
        .daddr  (read_word),
        .drdata (regs_rdata),
        .tclk   (bus_clk),
        .taddr  (regs_dbg_addr),
        .trdata (regs_dbg_rdata)
    );

    logic [1:0]  ae350_lock_sync /* synthesis syn_srlstyle = "registers" */;
    logic [1:0]  ddr_lock_sync   /* synthesis syn_srlstyle = "registers" */;
    logic [1:0]  calib_sync      /* synthesis syn_srlstyle = "registers" */;
    logic [1:0]  running_sync    /* synthesis syn_srlstyle = "registers" */;
    logic [1:0]  por_sync        /* synthesis syn_srlstyle = "registers" */;
    logic [1:0]  calib_done_clk  /* synthesis syn_srlstyle = "registers" */;
    logic [31:0] calib_time;
    logic [31:0] calib_time_meta /* synthesis syn_srlstyle = "registers" */;
    logic [31:0] calib_time_sync /* synthesis syn_srlstyle = "registers" */;
    logic [31:0] uptime;
    logic [31:0] uptime_meta     /* synthesis syn_srlstyle = "registers" */;
    logic [31:0] uptime_sync     /* synthesis syn_srlstyle = "registers" */;

    always_ff @(posedge clk) begin
        calib_done_clk <= {calib_done_clk[0], sdram_ready};
        uptime         <= uptime + 32'd1;
        if (!calib_done_clk[1])
            calib_time <= calib_time + 32'd1;

        if (!por_n) begin
            uptime     <= '0;
            calib_time <= '0;
        end
    end

    always_ff @(posedge tclk) begin
        ae350_lock_sync <= {ae350_lock_sync[0], ae350_pll_lock};
        ddr_lock_sync   <= {ddr_lock_sync[0], 1'b0};
        calib_sync      <= {calib_sync[0], sdram_ready};
        running_sync    <= {running_sync[0], cpu_resetn};
        por_sync        <= {por_sync[0], por_n};
        calib_time_meta <= calib_time;
        calib_time_sync <= calib_time_meta;
        uptime_meta     <= uptime;
        uptime_sync     <= uptime_meta;

        if (restart_count != 0)
            restart_count <= restart_count - 16'd1;
        if (restart_req) begin
            restart_count <= '1;
            restarts      <= restarts + 32'd1;
        end

        if (!por_sync[1]) begin
            restart_count <= '0;
            restarts      <= '0;
        end
    end

    // por_sync_tclk is the synchronized power-on reset for the loader's
    // stream side (same domain as its sclk).
    assign por_sync_tclk = por_sync[1];

    ae350_play_stream play_stream (
        .wclk      (bus_clk),
        .wvalid    (play_w_valid),
        .wkind     (play_w_kind),
        .wcount    (play_w_count),
        .wdata     (play_w_data),
        .wready    (play_w_ready),
        .clk       (tclk),
        .rst       (!por_sync_tclk),
        .start     (play_start),
        .stop      (play_end),
        .cancel    (play_cancel),
        .data      (play_data),
        .valid     (play_valid),
        .ready     (play_ready),
        .stream_id (play_id),
        .rate      (play_rate)
    );

    wire [31:0] flags = {27'b0, running_sync[1], calib_sync[1], ddr_lock_sync[1],
                         ae350_lock_sync[1], por_sync[1]};

    // Registered, like read_word: iosys_bl616 samples debug_rdata six UART
    // bytes after it sets debug_address, so the two cycles are invisible to
    // Tang-Control.
    always_ff @(posedge tclk) begin
        unique case (read_word)
            8'hf0:   debug_rdata <= stream_sessions;
            8'hf1:   debug_rdata <= stream_bytes;
            8'hf2:   debug_rdata <= stream_ends;
            8'hf3:   debug_rdata <= stream_cancels;
            8'hf4:   debug_rdata <= {31'b0, stream_overflow};
            8'hf8:   debug_rdata <= flags;
            8'hf9:   debug_rdata <= calib_time_sync;
            8'hfa:   debug_rdata <= uptime_sync;
            8'hfc:   debug_rdata <= restarts;
            default: debug_rdata <= regs_rdata;
        endcase
    end

endmodule
