// SPDX-License-Identifier: GPL-3.0-only
//
// A second-level cache between the AE350's RAM port and the SDRAM engine.
//
// Why it exists.  The AE350's L1 D-cache is 32 KiB with no hardware prefetch
// (AE350-008) and a miss costs hundreds of core cycles with no overlap
// between misses (AE350-009).  mpeg2probe measured the MPEG-2 decode at IPC
// 0.223 -- 84.3 cycles per pixel against 18.8 instructions -- and decomposed
// that into 23.5 percent compute and 87.1 percent non-overlapping misses.  So
// the decode is stall bound, and a cache that cuts the miss cost is worth more
// than any instruction-level work (core-log entry 25).
//
// Why it is not the single-line buffer that ahb_sdram already has.  That
// buffer holds exactly one 32-byte line.  Motion compensation alternates
// between the block being built and the block being predicted from, which is
// two lines at minimum and 16 for a luma macroblock, so one line is thrashed
// on every access.  The reuse that matters is between neighbouring
// macroblocks in a row: a 32-byte line holds 32 luma samples, which is a whole
// row of two macroblocks, so the second macroblock of a pair re-reads the same
// 16 lines the first one just read.  That is a working set of tens of lines,
// which this cache holds and the line buffer cannot.
//
// Design.
//
//   * Direct-mapped, LINES lines of 32 bytes.  The default 2048 lines is
//     64 KiB: 30 block RAMs, against 212 already used of 340 on this part.
//   * Write-through, and a write invalidates the matching line rather than
//     merging into it.  SDRAM is therefore always authoritative, no line can
//     hold stale data, and there is no byte-enable merge to get wrong.  A
//     write costs one compare-free invalidate plus the SDRAM write it would
//     have done anyway; the cost is that a write followed by a read of the
//     same line re-fetches it, which for a decoder writing frames in raster
//     order is the common case and still cheap.
//   * Read-allocate: a miss fetches all four doublewords of the line.  This
//     was designed on the belief that ahb_sdram's line buffer would serve
//     three of the four cheaply, making a fill one row activation.  The
//     measurement says otherwise -- a miss costs about 53 bus cycles, four
//     times a baseline access -- so the four requests each carry their own
//     cost and the fill is not amortised.  Filling through a single burst
//     read is the fix, and it belongs inside ahb_sdram where the burst logic
//     already lives.
//   * One clock, deliberately.  Every array is written and read on bus_clk:
//     a two-clock block RAM reads back wrong in this open flow, and that is a
//     build gate rather than a caution.
//   * Tags start invalid by walking the index space after reset, not by
//     relying on a bitstream initialisation.  The CPU is held in reset until
//     the SDRAM is ready anyway, and LINES cycles is 27 us.
//
// MEASURED RESULT, 2026-11-09: this cache is a 33.8 percent pessimization of
// the MPEG-2 decode and is therefore off by default in the player top.
//
//   baseline (no cache)   4,371,786,929 cycles   25.73 fps
//   with this cache       5,851,293,437 cycles   19.23 fps
//   hit rate 75.3 percent (21,553,813 hits, 7,052,046 misses, 28,605,860
//   lookups), decoded output bit-identical
//
// It is not a correctness fault: the testbench and the decode checksums agree.
// It is the wrong place for a cache.  ahb_sdram already keeps one 32-byte line
// and serves the line's other three doublewords from it, so a baseline access
// averages about 11.7 bus cycles and only a few percent of accesses reach the
// SDRAM at all.  Most of what this cache counts as a hit was already nearly
// free, while each of its hits costs about five bus cycles of its own and each
// of its misses issues four separate downstream requests instead of one.
//
// The lesson worth keeping: the reuse to exploit is the ~16 lines a pair of
// macroblocks touches along a row, and the place to hold it is inside
// ahb_sdram's existing line buffer, where a hit already costs one or two
// cycles and a fill is a single burst.  Widening that buffer to N lines is a
// smaller change than this module and does not tax the common case.
//
// Coherence.  There is one writer, the CPU, and it reaches this cache through
// ahb_ram.  The only other memory client is the display, whose video reads go
// straight to ahb_sdram and bypass this cache entirely -- and that is safe in
// the direction that matters, because the CPU writes go through to SDRAM, so
// what the display reads is never stale.  If a fabric master that writes
// memory is ever added, it must invalidate by address here.
//
// Statistics.  The four counters are readable through the AE350 register
// block, at the addresses the RAM-bridge counters occupy in the DDR3 image
// (0xa0, 0xa8, 0xb0 and 0xa4).  This image has no RAM bridge, so those
// registers are otherwise tied to zero; see ae350_sdram_subsystem.sv.

module ae350_l2_cache #(
    // 2048 lines of 32 bytes is 64 KiB.
    parameter integer LINES = 2048
) (
    input  wire        clk,
    input  wire        resetn,

    // Upstream: the request port ahb_ram drives (its sd_* outputs).
    input  wire        up_req,
    input  wire        up_write,
    input  wire [24:3] up_addr,
    input  wire [7:0]  up_lanes,
    input  wire [63:0] up_wdata,
    output reg         up_ack,
    output reg  [63:0] up_rdata,

    // Downstream: the SDRAM engine, unchanged contract.
    output reg         dn_req,
    output reg         dn_write,
    output reg  [24:3] dn_addr,
    output reg  [7:0]  dn_lanes,
    output reg  [63:0] dn_wdata,
    input  wire        dn_ack,
    input  wire  [63:0] dn_rdata,

    output reg  [31:0] stat_lookups,
    output reg  [31:0] stat_hits,
    output reg  [31:0] stat_misses,
    output reg  [31:0] stat_writes
);
    // The port is declared [24:3], so the bit labels are already the byte
    // address's: a[i] is byte address bit i.  The 20-bit line address is
    // byte [24:5]; its low INDEX_BITS select the line and the rest are the
    // tag.  The testbench compares every read against memory rather than
    // only counting hits, because getting this wrong returns wrong data
    // quickly and looks like success in a hit-rate counter.
    localparam integer INDEX_BITS = $clog2(LINES);   // 11 for 2048
    localparam integer TAG_BITS   = 20 - INDEX_BITS; // 9

    function automatic [INDEX_BITS-1:0] line_index(input [24:3] a);
        line_index = a[5 +: INDEX_BITS];
    endfunction

    function automatic [TAG_BITS-1:0] line_tag(input [24:3] a);
        line_tag = a[5 + INDEX_BITS +: TAG_BITS];
    endfunction

    // Which doubleword of the 32-byte line an address names: byte [4:3].
    function automatic [1:0] word_of(input [24:3] a);
        word_of = a[4:3];
    endfunction

    // The line's first doubleword, in the port's address units.  The result
    // is 22 bits wide, so the low two bits are cleared: three zero bits would
    // be 23 and silently truncate the top of the address, which shifts every
    // fill up by one line and is exactly the kind of fault a hit-rate counter
    // cannot see.
    function automatic [24:3] line_base(input [24:3] a);
        line_base = {a[24:5], 2'b00};
    endfunction

    // ------------------------------------------------------------------
    // The arrays.  Four doubleword banks rather than one 256-bit array, so
    // that a fill writes one 64-bit word at a time with no byte-enable
    // merging, and a lookup reads all four in parallel.
    // ------------------------------------------------------------------
    reg [63:0] bank0 [0:LINES-1];
    reg [63:0] bank1 [0:LINES-1];
    reg [63:0] bank2 [0:LINES-1];
    reg [63:0] bank3 [0:LINES-1];

    reg [TAG_BITS:0] tags [0:LINES-1];   // {valid, tag}

    // The array address is the request's own index, not a register of it.
    // With a registered address the read would not be valid until two cycles
    // after the request was accepted, and the tag comparison would be made
    // against the previous request's line -- which reports a hit whenever two
    // lines that share an index happen to share a tag value, and serves the
    // wrong line's data.  The testbench catches that because it compares every
    // read against memory.
    wire [INDEX_BITS-1:0] read_index = line_index(up_addr);

    reg [63:0] rd_bank0, rd_bank1, rd_bank2, rd_bank3;
    reg [TAG_BITS:0] rd_tag;
    reg [63:0] hit_data;

    // Registered outputs: one clock of latency, which is what a block RAM
    // gives and what keeps the arrays single-clock.
    always_ff @(posedge clk) begin
        rd_bank0 <= bank0[read_index];
        rd_bank1 <= bank1[read_index];
        rd_bank2 <= bank2[read_index];
        rd_bank3 <= bank3[read_index];
        rd_tag   <= tags[read_index];
    end

    // ------------------------------------------------------------------
    // Request state.
    // ------------------------------------------------------------------
    reg [24:3] req_addr;
    reg [7:0]  req_lanes;
    reg [63:0] req_wdata;
    reg [1:0]  word;          // the doubleword the requester asked for
    reg        acked;         // the requester has been acknowledged

    // The line being filled, and its metadata.
    reg [63:0] fill_data;
    reg [1:0]  fill_beat;

    reg [63:0] line_words [0:3];

    localparam [3:0] S_FLUSH     = 4'd0,  // invalidate every tag after reset
                     S_IDLE      = 4'd1,  // wait for a request
                     S_LOOKUP    = 4'd2,  // tag and data coming back
                     S_HIT       = 4'd3,  // acknowledge from the cache
                     S_WRITE     = 4'd4,  // pass a write to SDRAM
                     S_FILL_CMD  = 4'd5,  // request one doubleword of the line
                     S_FILL_WAIT = 4'd6,  // wait for that doubleword
                     S_SERVE     = 4'd7,  // acknowledge after a fill
                     S_DRAIN     = 4'd8;  // let the requester release req

    (* fsm_encoding = "one_hot" *)
    reg [3:0] state = S_FLUSH;

    reg [INDEX_BITS-1:0] flush_index;

    always_ff @(posedge clk) begin
        if (!resetn) begin
            state        <= S_FLUSH;
            flush_index  <= '0;
            up_ack       <= 1'b0;
            up_rdata     <= 64'd0;
            dn_req       <= 1'b0;
            dn_write     <= 1'b0;
            dn_addr      <= 22'd0;
            dn_lanes     <= 8'd0;
            dn_wdata     <= 64'd0;
            req_addr     <= 22'd0;
            req_lanes    <= 8'd0;
            req_wdata    <= 64'd0;
            word         <= 2'd0;
            acked        <= 1'b0;
            fill_beat    <= 2'd0;
            fill_data    <= 64'd0;
            stat_lookups <= 32'd0;
            stat_hits    <= 32'd0;
            stat_misses  <= 32'd0;
            stat_writes  <= 32'd0;
            for (int i = 0; i < 4; i++)
                line_words[i] <= 64'd0;
        end else begin
            up_ack <= 1'b0;

            // The downstream request is released the cycle after the ack it
            // was answered with, matching what ahb_ram does to ahb_sdram.
            if (dn_req && dn_ack)
                dn_req <= 1'b0;

            case (state)
            // ----------------------------------------------------------
            S_FLUSH: begin
                tags[flush_index] <= '0;
                if (flush_index == LINES - 1)
                    state <= S_IDLE;
                flush_index <= flush_index + 1'b1;
            end

            // ----------------------------------------------------------
            S_IDLE: begin
                // A request answered a cycle ago is still asserted: the
                // requester drops it in the cycle after it sees the ack.
                if (up_req && !acked) begin
                    req_addr  <= up_addr;
                    req_lanes <= up_lanes;
                    req_wdata <= up_wdata;
                    word      <= word_of(up_addr);
                    if (up_write) begin
                        // Invalidate by index without comparing: clearing a
                        // line that was not there costs nothing, and it keeps
                        // the write path free of a lookup.
                        tags[line_index(up_addr)]     <= '0;
                        stat_writes                   <= stat_writes + 1'b1;
                        dn_req                        <= 1'b1;
                        dn_write                      <= 1'b1;
                        dn_addr                       <= up_addr;
                        dn_lanes                      <= up_lanes;
                        dn_wdata                      <= up_wdata;
                        state                         <= S_WRITE;
                    end else begin
                        stat_lookups <= stat_lookups + 1'b1;
                        state        <= S_LOOKUP;
                    end
                end
            end

            // ----------------------------------------------------------
            S_LOOKUP: begin
                if (rd_tag[TAG_BITS] && rd_tag[TAG_BITS-1:0] == line_tag(req_addr)) begin
                    stat_hits <= stat_hits + 1'b1;
                    case (word)
                    2'd0:    hit_data <= rd_bank0;
                    2'd1:    hit_data <= rd_bank1;
                    2'd2:    hit_data <= rd_bank2;
                    default: hit_data <= rd_bank3;
                    endcase
                    state     <= S_HIT;
                end else begin
                    stat_misses <= stat_misses + 1'b1;
                    fill_beat   <= 2'd0;
                    state       <= S_FILL_CMD;
                end
            end

            // ----------------------------------------------------------
            S_HIT: begin
                up_ack   <= 1'b1;
                acked    <= 1'b1;
                up_rdata <= hit_data;
                state    <= S_DRAIN;
            end

            // ----------------------------------------------------------
            S_WRITE: begin
                if (dn_ack) begin
                    up_ack <= 1'b1;
                    acked  <= 1'b1;
                    state  <= S_DRAIN;
                end
            end

            // ----------------------------------------------------------
            // Fetch the whole line, one doubleword at a time.  A requested
            // doubleword already on its way is not re-requested.
            // dn_req is released in the cycle after an ack, so it is low by
            // the time this state is reached with the next beat.
            S_FILL_CMD: begin
                if (!dn_req) begin
                    dn_req   <= 1'b1;
                    dn_write <= 1'b0;
                    dn_addr  <= line_base(req_addr) + {20'd0, fill_beat};
                    dn_lanes <= 8'hff;
                    state    <= S_FILL_WAIT;
                end
            end

            // ----------------------------------------------------------
            S_FILL_WAIT: begin
                if (dn_ack) begin
                    // Record the word twice: into the line store, and into a
                    // register per position so the serve path never has to
                    // read back a bank it wrote in the same cycle.
                    case (fill_beat)
                    2'd0: begin
                        line_words[0] <= dn_rdata;
                        bank0[line_index(req_addr)] <= dn_rdata;
                    end
                    2'd1: begin
                        line_words[1] <= dn_rdata;
                        bank1[line_index(req_addr)] <= dn_rdata;
                    end
                    2'd2: begin
                        line_words[2] <= dn_rdata;
                        bank2[line_index(req_addr)] <= dn_rdata;
                    end
                    default: begin
                        line_words[3] <= dn_rdata;
                        bank3[line_index(req_addr)] <= dn_rdata;
                    end
                    endcase
                    if (fill_beat == 2'd3) begin
                        tags[line_index(req_addr)] <= {1'b1, line_tag(req_addr)};
                        state <= S_SERVE;
                    end else begin
                        fill_beat <= fill_beat + 1'b1;
                        state     <= S_FILL_CMD;
                    end
                end
            end

            // ----------------------------------------------------------
            S_SERVE: begin
                up_ack <= 1'b1;
                acked  <= 1'b1;
                case (word)
                2'd0:    up_rdata <= line_words[0];
                2'd1:    up_rdata <= line_words[1];
                2'd2:    up_rdata <= line_words[2];
                default: up_rdata <= line_words[3];
                endcase
                state <= S_DRAIN;
            end

            // ----------------------------------------------------------
            // Stay here until the requester has let go of its request, so a
            // still-high req is not mistaken for a second one.
            S_DRAIN: begin
                if (!up_req) begin
                    acked <= 1'b0;
                    state <= S_IDLE;
                end
            end

            default: state <= S_FLUSH;
            endcase
        end
    end

endmodule
