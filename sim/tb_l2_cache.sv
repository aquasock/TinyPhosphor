// SPDX-License-Identifier: GPL-3.0-only
//
// Testbench for ae350_l2_cache.
//
// It models both sides as their real counterparts behave: the requester holds
// req until it sees ack and drops it the cycle after (ahb_ram's behaviour),
// and the memory accepts a request only while ack is low and answers after a
// few cycles (ahb_sdram's behaviour).  Every read is compared against the
// memory contents, which is the only check that matters: a cache that returns
// the wrong word quickly is worse than no cache.
//
// The memory is small and malicious in the way that matters for a
// direct-mapped cache: addresses that alias the same line are exercised on
// purpose, and a write to a line that is currently cached must be visible to
// the read that follows it.

`timescale 1ns / 1ps

module tb_l2 #(
    // 16 for a fast aliasing test; 2048 (64 KiB) is the shipped size, and
    // -Ptb_l2.LINES=2048 tests that geometry with the same checks.
    parameter integer LINES = 16
);
    localparam integer IDXBITS = $clog2(LINES);
    localparam integer MEMW   = 24;                  // byte address width
    localparam integer MEMB   = 1 << 14;             // 16 KiB of modelled memory

    reg clk = 0;
    reg resetn = 0;

    reg         up_req = 0;
    reg         up_write = 0;
    reg  [24:3] up_addr = 0;
    reg  [7:0]  up_lanes = 0;
    reg  [63:0] up_wdata = 0;
    wire        up_ack;
    wire [63:0] up_rdata;

    wire        dn_req;
    wire        dn_write;
    wire [24:3] dn_addr;
    wire [7:0]  dn_lanes;
    wire [63:0] dn_wdata;
    reg         dn_ack = 0;
    reg  [63:0] dn_rdata = 0;

    wire [31:0] stat_lookups, stat_hits, stat_misses, stat_writes;

    ae350_l2_cache #(.LINES(LINES)) dut (
        .clk(clk), .resetn(resetn),
        .up_req(up_req), .up_write(up_write), .up_addr(up_addr),
        .up_lanes(up_lanes), .up_wdata(up_wdata),
        .up_ack(up_ack), .up_rdata(up_rdata),
        .dn_req(dn_req), .dn_write(dn_write), .dn_addr(dn_addr),
        .dn_lanes(dn_lanes), .dn_wdata(dn_wdata),
        .dn_ack(dn_ack), .dn_rdata(dn_rdata),
        .stat_lookups(stat_lookups), .stat_hits(stat_hits),
        .stat_misses(stat_misses), .stat_writes(stat_writes)
    );

    always #5 clk = ~clk;

    // ---- modelled memory -------------------------------------------------
    reg [7:0] mem [0:MEMB-1];
    integer latency = 3;
    integer error_count = 0;

    // A request is accepted only while ack is low; ack is a single cycle.
    reg        dn_busy = 0;
    integer    dn_countdown = 0;
    reg [24:3] dn_hold_addr;
    reg        dn_hold_write;
    reg [7:0]  dn_hold_lanes;
    reg [63:0] dn_hold_wdata;

    integer i;
    initial begin
        // The high address bits must reach the data, or two lines 256 bytes
        // apart look identical and a fill address that is wrong by one line
        // compares equal.  That is how the line_base truncation hid here.
        for (i = 0; i < MEMB; i = i + 1)
            mem[i] = ((i * 37) + ((i >> 8) * 13) + 11) & 8'hff;
    end

    function [63:0] mem_read(input [24:3] a);
        integer base;
        begin
            base = {a, 3'b000};
            mem_read = {mem[base+7], mem[base+6], mem[base+5], mem[base+4],
                        mem[base+3], mem[base+2], mem[base+1], mem[base+0]};
        end
    endfunction

    always @(posedge clk) begin
        dn_ack <= 1'b0;
        if (!resetn) begin
            dn_busy <= 1'b0;
            dn_countdown <= 0;
        end else if (dn_req && !dn_busy && !dn_ack) begin
            dn_busy        <= 1'b1;
            dn_countdown   <= latency;
            dn_hold_addr   <= dn_addr;
            dn_hold_write  <= dn_write;
            dn_hold_lanes  <= dn_lanes;
            dn_hold_wdata  <= dn_wdata;
        end else if (dn_busy) begin
            if (dn_countdown == 0) begin
                dn_busy <= 1'b0;
                dn_ack  <= 1'b1;
                if (dn_hold_write) begin
                    if (dn_hold_lanes[0]) mem[{dn_hold_addr, 3'b000} + 0] <= dn_hold_wdata[7:0];
                    if (dn_hold_lanes[1]) mem[{dn_hold_addr, 3'b000} + 1] <= dn_hold_wdata[15:8];
                    if (dn_hold_lanes[2]) mem[{dn_hold_addr, 3'b000} + 2] <= dn_hold_wdata[23:16];
                    if (dn_hold_lanes[3]) mem[{dn_hold_addr, 3'b000} + 3] <= dn_hold_wdata[31:24];
                    if (dn_hold_lanes[4]) mem[{dn_hold_addr, 3'b000} + 4] <= dn_hold_wdata[39:32];
                    if (dn_hold_lanes[5]) mem[{dn_hold_addr, 3'b000} + 5] <= dn_hold_wdata[47:40];
                    if (dn_hold_lanes[6]) mem[{dn_hold_addr, 3'b000} + 6] <= dn_hold_wdata[55:48];
                    if (dn_hold_lanes[7]) mem[{dn_hold_addr, 3'b000} + 7] <= dn_hold_wdata[63:56];
                end else begin
                    dn_rdata <= mem_read(dn_hold_addr);
                end
            end else begin
                dn_countdown <= dn_countdown - 1;
            end
        end
    end

    // ---- requester -------------------------------------------------------
    // Exactly ahb_ram's shape: assert, hold until ack, drop the cycle after.
    task automatic do_read(input [24:3] a, output [63:0] got);
        reg hits_before;
        begin
            hits_before = stat_hits;
            up_write = 1'b0;
            up_addr  = a;
            up_lanes = 8'hff;
            up_wdata = 64'd0;
            up_req   = 1'b1;
            @(posedge clk);
            while (!up_ack) @(posedge clk);
            got = up_rdata;
            trace_op(a, 1'b0, stat_hits != hits_before);
            @(posedge clk);       // the cycle the ack is seen
            up_req = 1'b0;
            @(posedge clk);       // release
        end
    endtask

    task automatic do_write(input [24:3] a, input [63:0] d);
        begin
            up_write = 1'b1;
            up_addr  = a;
            up_lanes = 8'hff;
            up_wdata = d;
            up_req   = 1'b1;
            @(posedge clk);
            while (!up_ack) @(posedge clk);
            trace_op(a, 1'b1, 1'b0);
            @(posedge clk);
            up_req = 1'b0;
            @(posedge clk);
        end
    endtask

    task automatic expect_word(input [24:3] a, input [63:0] got);
        reg [63:0] want;
        begin
            want = mem_read(a);
            if (got !== want) begin
                error_count = error_count + 1;
                $display("MISMATCH at %h: got %h want %h (lookups %0d hits %0d misses %0d writes %0d)",
                         {a, 3'b000}, got, want, stat_lookups, stat_hits,
                         stat_misses, stat_writes);
                $display("   line base %h index %0d word %0d, tag in dut %h",
                         {dut.line_base(a), 3'b000}, dut.line_index(a),
                         dut.word_of(a), dut.tags[dut.line_index(a)]);
                dump_trace({a, 3'b000});
            end
        end
    endtask

    // ---- trace of recent operations, for a mismatch report -----------------
    reg [23:0] tr_addr [0:15];
    reg        tr_write[0:15];
    reg        tr_hit  [0:15];
    integer    tr_ptr = 0;

    task automatic trace_op(input [24:3] a, input wr, input hit);
        begin
            tr_addr[tr_ptr]  = {a, 3'b000};
            tr_write[tr_ptr] = wr;
            tr_hit[tr_ptr]   = hit;
            tr_ptr = (tr_ptr + 1) & 15;
        end
    endtask

    task automatic dump_trace(input [23:0] around);
        integer k, j;
        begin
            $display("   last ops (index %0d):", (around >> 5) & (LINES - 1));
            for (k = 0; k < 16; k = k + 1) begin
                j = (tr_ptr + k) & 15;
                $display("     %s %h hit=%b idx=%0d tag=%h", tr_write[j] ? "W" : "R",
                         tr_addr[j], tr_hit[j],
                         (tr_addr[j] >> 5) & (LINES-1), tr_addr[j][24:5+IDXBITS]);
            end
        end
    endtask

    // ---- tests -----------------------------------------------------------
    reg [63:0] w, r;
    integer n;
    integer seed = 12345;
    integer base;
    reg [24:3] addr;

    initial begin
        repeat (3) @(posedge clk);
        resetn = 1'b1;

        // The flush walk takes LINES cycles; wait it out.
        repeat (LINES + 8) @(posedge clk);

        $display("-- single read is a miss");
        addr = 24'h000100 >> 3;
        do_read(addr, r);
        expect_word(addr, r);
        if (stat_misses !== 1) begin
            $display("expected 1 miss, got %0d", stat_misses);
            error_count = error_count + 1;
        end
        if (stat_hits !== 0) begin
            $display("expected 0 hits, got %0d", stat_hits);
            error_count = error_count + 1;
        end

        $display("-- the other doublewords of that line are hits");
        // n from 1: doubleword 0 was the read above.
        for (n = 1; n < 4; n = n + 1) begin
            addr = (24'h000100 + n * 8) >> 3;
            do_read(addr, r);
            expect_word(addr, r);
        end
        if (stat_misses !== 1 || stat_hits !== 3) begin
            $display("expected 1 miss 3 hits, got %0d/%0d", stat_misses, stat_hits);
            error_count = error_count + 1;
        end

        $display("-- a write is visible to the read that follows it");
        addr = 24'h000108 >> 3;
        do_write(addr, 64'hdead_beef_0123_4567);
        if (stat_writes !== 1) begin
            $display("expected 1 write, got %0d", stat_writes);
            error_count = error_count + 1;
        end
        do_read(addr, r);
        expect_word(addr, r);          // memory was updated, cache refilled
        if (r !== 64'hdead_beef_0123_4567) begin
            $display("write-through failed: read %h", r);
            error_count = error_count + 1;
        end

        $display("-- aliasing: two addresses one line apart in the index");
        // LINES=16 -> index is addr[8:5]; addresses 512 bytes apart collide
        addr = 24'h000200 >> 3;
        do_read(addr, r);
        expect_word(addr, r);
        addr = 24'h000400 >> 3;        // same index, different tag
        do_read(addr, r);
        expect_word(addr, r);
        addr = 24'h000200 >> 3;        // back: must not have survived
        do_read(addr, r);
        expect_word(addr, r);

        $display("-- random traffic against the memory model");
        for (n = 0; n < 2000; n = n + 1) begin
            base = ($random(seed) & 32'h7fff);       // inside the model
            base = base & ~7;
            addr = base[24:0] >> 3;
            if ($random(seed) & 1) begin
                w = {$random(seed), $random(seed)};
                do_write(addr, w);
            end else begin
                do_read(addr, r);
                expect_word(addr, r);
            end
        end

        // The pattern the decoder actually presents: a working set of 16
        // lines, each re-read once per pass, which is what two neighbouring
        // macroblocks do along a row.  After the first pass this must be
        // almost all hits -- that is the whole reason for the cache.
        $display("-- row-scan working set of 16 lines");
        begin : workset
            integer pass, row, before_h, before_m;
            reg [24:3] ws;
            before_h = stat_hits;
            before_m = stat_misses;
            for (pass = 0; pass < 8; pass = pass + 1)
                for (row = 0; row < 16; row = row + 1) begin
                    ws = (24'h008000 + row * 32) >> 3;
                    do_read(ws, r);
                    expect_word(ws, r);
                end
            $display("   %0d hits, %0d misses over 8 passes of 16 lines",
                     stat_hits - before_h, stat_misses - before_m);
            if (stat_hits - before_h < 100) begin
                $display("   a 16-line working set should have hit almost every time");
                error_count = error_count + 1;
            end
        end

        $display("lookups=%0d hits=%0d misses=%0d writes=%0d",
                 stat_lookups, stat_hits, stat_misses, stat_writes);
        if (stat_lookups != stat_hits + stat_misses) begin
            $display("hit and miss counts do not add to the lookups");
            error_count = error_count + 1;
        end
        if (stat_hits == 0) begin
            $display("the cache never hit: it is not caching");
            error_count = error_count + 1;
        end

        if (error_count == 0)
            $display("PASS");
        else
            $display("FAIL with %0d errors", error_count);
        $finish;
    end

    // Per-transaction trace of the decision, for hunting a wrong hit.
`ifdef L2_TRACE
    always @(posedge clk) if (resetn) begin
        if (dut.state == 2)
            $display("LOOKUP %h idx=%0d rd_tag=%h want=%h",
                     {dut.req_addr, 3'b000}, dut.read_index, dut.rd_tag,
                     dut.line_tag(dut.req_addr));
        $display("CY %0t st=%0d req=%b wr=%b ackd=%b dnreq=%b dnaddr=%h",
                 $time, dut.state, up_req, up_write, dut.acked, dn_req,
                 {dn_addr, 3'b000});
    end
`endif

    initial begin
        #10_000_000;
        $display("TIMEOUT");
        $finish;
    end

    initial begin
        $dumpfile("build/l2/tb_l2.vcd");
        $dumpvars(0, tb_l2);
    end
endmodule
