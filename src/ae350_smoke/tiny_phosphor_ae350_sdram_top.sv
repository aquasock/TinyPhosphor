// SPDX-License-Identifier: MIT
//
// TinyPhosphor AE350 + 32 MiB SDRAM smoke top.
//
// This is the first AE350 image in TinyPhosphor's open-flow tree.  It keeps
// TinyNES's proven platform: the AE350 hard block, a 32 KiB block-RAM boot
// ROM, a 64 KiB block-RAM data/stack window at 0x60000000, the dock's 32 MiB
// J9 SDRAM at 0x40000000, and the EXTS UART at 0xe8000000.  The boot ROM
// checks the fabric registers, the block RAM and the SDRAM, then prints:
//
//   TinyPhosphor AE350 boot ROM
//   TinyPhosphor AE350 C OK UNC=<cycles> CAC=<cycles>
//   TinyPhosphor SDRAM OK 32M
//   TinyNES LOAD
//
// The last line is TinyNES's load protocol on purpose: its host loader keeps
// working, and a later TinyPhosphor cycle can replace it with the Tang-Control
// stream loader.  There is no player, HDMI, PMOD or DDR3 in this image.
//
// Reference: TinyNES commit 50cd89e, fpga/ae350_soc/ae350_soc.sv and its
// memory modules.  The AE350 PLL, memory decode and hard-block connections are
// kept in substance; the NES video, pads, I2S and DDR3 are not present.

module tiny_phosphor_ae350_sdram_top #(
    parameter INIT_FILE = "build/firmware/boot/boot.hex",
    parameter integer UART_DIV2 = 75,              // 2 * 75 MHz / 2 Mbaud
    parameter integer SDRAM_INIT_CYCLES = 15000    // 200 us at 75 MHz
) (
    input  wire        sys_clk,
    output wire        uart_tx,
    input  wire        uart_rx,

    output wire        sdram_clk,
    output wire        sdram_cs_n,
    output wire        sdram_ras_n,
    output wire        sdram_cas_n,
    output wire        sdram_we_n,
    output wire [1:0]  sdram_ba,
    output wire [12:0] sdram_a,
    output wire [1:0]  sdram_dqm,
    inout  wire [15:0] sdram_dq
);

    wire pll_locked;
    wire bus_clk;
    wire core_clk;

    // The AE350's dedicated clock input is PLL_R[0] CLKOUT1.
    // 50 MHz * 15 = 750 MHz VCO; CLKOUT0 / 10 = 75 MHz AHB bus;
    // CLKOUT1 / 1 = 750 MHz core.
    PLL #(
        .FCLKIN("50"),
        .IDIV_SEL(1),
        .FBDIV_SEL(1),
        .MDIV_SEL(15),
        .ODIV0_SEL(10),
        .ODIV1_SEL(1),
        .CLKOUT0_EN("TRUE"),
        .CLKOUT1_EN("TRUE")
    ) cpu_pll (
        .CLKIN(sys_clk),
        .CLKFB(1'b0),
        .RESET(1'b0),
        .PLLPWD(1'b0),
        .RESET_I(1'b0),
        .RESET_O(1'b0),
        .FBDSEL(6'b0),
        .IDSEL(6'b0),
        .MDSEL(7'b0),
        .MDSEL_FRAC(3'b0),
        .ODSEL0(7'b0),
        .ODSEL0_FRAC(3'b0),
        .ODSEL1(7'b0),
        .ODSEL2(7'b0),
        .ODSEL3(7'b0),
        .ODSEL4(7'b0),
        .ODSEL5(7'b0),
        .ODSEL6(7'b0),
        .DT0(4'b0),
        .DT1(4'b0),
        .DT2(4'b0),
        .DT3(4'b0),
        .ICPSEL(6'b0),
        .LPFRES(3'b0),
        .LPFCAP(2'b0),
        .PSSEL(3'b0),
        .PSDIR(1'b0),
        .PSPULSE(1'b0),
        .ENCLK0(1'b1),
        .ENCLK1(1'b1),
        .ENCLK2(1'b0),
        .ENCLK3(1'b0),
        .ENCLK4(1'b0),
        .ENCLK5(1'b0),
        .ENCLK6(1'b0),
        .SSCPOL(1'b0),
        .SSCON(1'b0),
        .SSCMDSEL(7'b0),
        .SSCMDSEL_FRAC(3'b0),
        .LOCK(pll_locked),
        .CLKOUT0(bus_clk),
        .CLKOUT1(core_clk),
        .CLKOUT2(),
        .CLKOUT3(),
        .CLKOUT4(),
        .CLKOUT5(),
        .CLKOUT6(),
        .CLKFBOUT()
    );

    reg [7:0] reset_count = 8'd0;
    reg resetn = 1'b0;
    always @(posedge bus_clk or negedge pll_locked) begin
        if (!pll_locked) begin
            reset_count <= 8'd0;
            resetn <= 1'b0;
        end else if (!resetn) begin
            reset_count <= reset_count + 1'b1;
            if (&reset_count)
                resetn <= 1'b1;
        end
    end

    wire [31:0] rom_addr;
    wire [1:0]  rom_trans;
    wire [31:0] rom_rdata;
    wire        rom_ready;

    wire [31:0] ram_addr;
    wire [1:0]  ram_trans;
    wire        ram_write;
    wire [2:0]  ram_size;
    wire [63:0] ram_wdata;
    wire [63:0] ram_rdata;
    wire        ram_ready;
    wire        ram_resp;
    wire        ram_stray;
    wire [2:0]  ram_burst;
    wire [3:0]  ram_prot;

    wire        sd_req;
    wire        sd_write;
    wire [24:3] sd_addr;
    wire [7:0]  sd_lanes;
    wire [63:0] sd_wdata;
    wire        sd_ack;
    wire [63:0] sd_rdata;

    wire [31:0] exts_addr;
    wire [31:0] exts_wdata;
    wire        exts_sel;
    wire [1:0]  exts_trans;
    wire        exts_write;
    wire [31:0] exts_rdata;
    wire [2:0]  exts_size;
    wire        exts_ready;
    wire        exts_resp;

    ahb_boot_rom #(.INIT_FILE(INIT_FILE)) boot_rom (
        .clk    (bus_clk),
        .resetn (resetn),
        .haddr  (rom_addr),
        .htrans (rom_trans),
        .hrdata (rom_rdata),
        .hready (rom_ready)
    );

    ahb_ram ram (
        .clk      (bus_clk),
        .resetn   (resetn),
        .haddr    (ram_addr),
        .htrans   (ram_trans),
        .hwrite   (ram_write),
        .hsize    (ram_size),
        .hprot0   (ram_prot[0]),
        .hwdata   (ram_wdata),
        .hrdata   (ram_rdata),
        .hready   (ram_ready),
        .hresp    (ram_resp),
        .stray    (ram_stray),
        .sd_req   (sd_req),
        .sd_write (sd_write),
        .sd_addr  (sd_addr),
        .sd_lanes (sd_lanes),
        .sd_wdata (sd_wdata),
        .sd_ack   (sd_ack),
        .sd_rdata (sd_rdata)
    );

    ahb_sdram #(.INIT_CYCLES(SDRAM_INIT_CYCLES)) sdram (
        .clk         (bus_clk),
        .resetn      (resetn),
        .req         (sd_req),
        .write       (sd_write),
        .addr        (sd_addr),
        .lanes       (sd_lanes),
        .wdata       (sd_wdata),
        .ack         (sd_ack),
        .rdata       (sd_rdata),
        .ready       (),
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

    // The EXTS UART is the only EXTS slave in this image.  The link-mode and
    // text-layer ports are tied idle; a later cycle can connect TinyTang's
    // desk layer or the Tang-Control stream loader.
    wire        fb_ready;
    wire        cpu_owns;
    wire        link;
    wire        rx_link_valid;
    wire [7:0]  rx_link_data;
    wire        txt_valid;
    wire [7:0]  txt_data;
    wire        ln_ready;
    wire        link_flush;
    wire [31:0] link_status;

    exts_uart #(.UART_DIV2(UART_DIV2)) regs (
        .clk            (bus_clk),
        .resetn         (resetn),
        .haddr          (exts_addr),
        .htrans         (exts_trans),
        .hsel           (exts_sel),
        .hwrite         (exts_write),
        .hwdata         (exts_wdata),
        .hready_in      (exts_ready),
        .hrdata         (exts_rdata),
        .hready         (exts_ready),
        .hresp          (exts_resp),
        .fb_valid       (1'b0),
        .fb_data        (8'd0),
        .fb_ready       (fb_ready),
        .cpu_owns       (cpu_owns),
        .link           (link),
        .rx_link_valid  (rx_link_valid),
        .rx_link_data   (rx_link_data),
        .txt_valid      (txt_valid),
        .txt_data       (txt_data),
        .txt_ready      (1'b1),
        .ln_valid       (1'b0),
        .ln_data        (8'd0),
        .ln_ready       (ln_ready),
        .link_idle      (1'b1),
        .link_flush     (link_flush),
        .link_status    (32'd0),
        .tx             (uart_tx),
        .rx             (uart_rx)
    );

    AE350_SOC cpu (
        .POR_N        (1'b1),
        .HW_RSTN      (resetn),
        .CORE_CLK     (core_clk),
        .DDR_CLK      (bus_clk),
        .AHB_CLK      (bus_clk),
        .APB_CLK      (bus_clk),
        .DBG_TCK      (1'b1),
        .RTC_CLK      (bus_clk),
        .CORE_CE      (1'b1),
        .AXI_CE       (1'b1),
        .DDR_CE       (1'b1),
        .AHB_CE       (1'b1),
        .APB_CE       (8'b00000001),
        .APB2AHB_CE   (1'b1),
        .GP_INT       (16'b0),
        .DMA_REQ      (8'b0),
        .WAKEUP_IN    (1'b0),
        .SCAN_TEST    (1'b0),
        .SCAN_EN      (1'b0),
        .SCAN_IN      (20'hfffff),
        .TEST_CLK     (1'b0),
        .TEST_MODE    (1'b0),
        .TEST_RSTN    (1'b1),
        .INTEG_TCK    (1'b1),
        .INTEG_TDI    (1'b1),
        .INTEG_TMS    (1'b1),
        .INTEG_TRST   (1'b0),
        .PGEN_CHAIN_I (1'b1),
        .EMA          (3'b011),
        .EMAW         (2'b01),
        .EMAS         (1'b0),
        .RET1N        (1'b1),
        .RET2N        (1'b1),
        .ROM_HADDR    (rom_addr),
        .ROM_HTRANS   (rom_trans),
        .ROM_HRDATA   (rom_rdata),
        .ROM_HREADY   (rom_ready),
        .ROM_HRESP    (1'b0),
        .APB_PRDATA   (32'b0),
        .APB_PREADY   (1'b1),
        .APB_PSLVERR  (1'b0),
        .EXTS_HADDR   (exts_addr),
        .EXTS_HSEL    (exts_sel),
        .EXTS_HTRANS  (exts_trans),
        .EXTS_HWRITE  (exts_write),
        .EXTS_HSIZE   (exts_size),
        .EXTS_HWDATA  (exts_wdata),
        .EXTS_HRDATA  (exts_rdata),
        .EXTS_HREADYIN(exts_ready),
        .EXTS_HRESP   (exts_resp),
        .EXTM_HADDR   (32'b0),
        .EXTM_HBURST  (3'b0),
        .EXTM_HPROT   (4'b0),
        .EXTM_HREADY  (1'b1),
        .EXTM_HSEL    (1'b0),
        .EXTM_HSIZE   (3'b0),
        .EXTM_HTRANS  (2'b0),
        .EXTM_HWDATA  (64'b0),
        .EXTM_HWRITE  (1'b0),
        .DDR_HADDR    (ram_addr),
        .DDR_HTRANS   (ram_trans),
        .DDR_HWRITE   (ram_write),
        .DDR_HSIZE    (ram_size),
        .DDR_HBURST   (ram_burst),
        .DDR_HPROT    (ram_prot),
        .DDR_HWDATA   (ram_wdata),
        .DDR_HRDATA   (ram_rdata),
        .DDR_HREADY   (ram_ready),
        .DDR_HRESP    (ram_resp),
        .TMS_IN       (1'b1),
        .TRST_IN      (1'b1),
        .TDI_IN       (1'b1),
        .SPI2_HOLDN_IN(1'b1),
        .SPI2_WPN_IN  (1'b1),
        .SPI2_CLK_IN  (1'b1),
        .SPI2_CSN_IN  (1'b1),
        .SPI2_MISO_IN (1'b1),
        .SPI2_MOSI_IN (1'b1),
        .I2C_SCL_IN   (1'b1),
        .I2C_SDA_IN   (1'b1),
        .UART1_RXD    (1'b1),
        .UART1_CTSN   (1'b1),
        .UART1_DSRN   (1'b1),
        .UART1_DCDN   (1'b1),
        .UART1_RIN    (1'b1),
        .UART2_RXD    (1'b1),
        .UART2_CTSN   (1'b1),
        .UART2_DSRN   (1'b1),
        .UART2_DCDN   (1'b1),
        .UART2_RIN    (1'b1),
        .GPIO_IN      (32'b0)
    );

endmodule
