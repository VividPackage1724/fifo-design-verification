`timescale 1ns/1ps

module fifo_tb;
    localparam int DATA_WIDTH = 8;
    localparam int DEPTH = 16;
    localparam int COUNT_WIDTH = $clog2(DEPTH + 1);

    logic clk = 0;
    logic rst_n = 0;
    logic wr_en = 0;
    logic rd_en = 0;
    logic [DATA_WIDTH-1:0] din = '0;
    logic [DATA_WIDTH-1:0] dout;
    logic full, empty;
    logic [COUNT_WIDTH-1:0] count;

    logic [DATA_WIDTH-1:0] model[$];
    logic [DATA_WIDTH-1:0] expected;
    int unsigned checks = 0;
    int unsigned accepted_writes = 0;
    int unsigned accepted_reads = 0;

    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (.*);

    always #5 clk = ~clk;

    task automatic check_status;
        if (count !== COUNT_WIDTH'(model.size()))
            $fatal(1, "COUNT mismatch: DUT=%0d MODEL=%0d", count, model.size());
        if (empty !== (model.size() == 0))
            $fatal(1, "EMPTY mismatch: DUT=%b MODEL_SIZE=%0d", empty, model.size());
        if (full !== (model.size() == DEPTH))
            $fatal(1, "FULL mismatch: DUT=%b MODEL_SIZE=%0d", full, model.size());
        checks++;
    endtask

    task automatic cycle(input bit write_req, input bit read_req,
                         input logic [DATA_WIDTH-1:0] write_data);
        bit accept_write, accept_read;
        bit had_expected_read;
        logic [DATA_WIDTH-1:0] read_value;

        @(negedge clk);
        wr_en = write_req;
        rd_en = read_req;
        din = write_data;

        // Acceptance is determined from pre-edge queue occupancy.
        accept_write = write_req && (model.size() < DEPTH);
        accept_read  = read_req && (model.size() > 0);
        had_expected_read = accept_read;
        if (accept_read)
            read_value = model.pop_front();

        if (accept_write)
            model.push_back(write_data);

        @(posedge clk);
        #1;

        if (had_expected_read) begin
            if (dout !== read_value)
                $fatal(1, "DATA mismatch: DUT=%h EXPECTED=%h", dout, read_value);
            accepted_reads++;
        end
        if (accept_write)
            accepted_writes++;

        check_status();
    endtask

    initial begin
        $display("[TEST] Starting synchronous FIFO test");

        repeat (2) @(posedge clk);
        #1;
        if (count !== '0 || !empty || full)
            $fatal(1, "Reset state incorrect");
        checks++;

        @(negedge clk);
        rst_n = 1;
        cycle(1, 0, 8'hA5);
        cycle(0, 1, 8'h00);
        if (dout !== 8'hA5)
            $fatal(1, "Single write/read failed");

        // Fill exactly to capacity, then attempt a blocked write.
        for (int i = 0; i < DEPTH; i++)
            cycle(1, 0, DATA_WIDTH'(i + 1));
        if (!full) $fatal(1, "FIFO did not assert full");
        cycle(1, 0, 8'hEE);
        if (count != DEPTH) $fatal(1, "Overflow attempt changed occupancy");

        // Drain completely, then attempt an underflow read.
        for (int i = 0; i < DEPTH; i++)
            cycle(0, 1, '0);
        if (!empty) $fatal(1, "FIFO did not assert empty");
        cycle(0, 1, '0);
        if (count != 0) $fatal(1, "Underflow attempt changed occupancy");

        // Exercise simultaneous read/write while partially occupied.
        cycle(1, 0, 8'h31);
        cycle(1, 0, 8'h42);
        cycle(1, 1, 8'h53);
        if (dout !== 8'h31) $fatal(1, "Simultaneous operation read mismatch");
        cycle(0, 1, '0);
        if (dout !== 8'h42) $fatal(1, "FIFO ordering mismatch");
        cycle(0, 1, '0);
        if (dout !== 8'h53) $fatal(1, "FIFO ordering mismatch");

        // Force multiple pointer wraps with deterministic traffic.
        for (int i = 0; i < (DEPTH * 4); i++) begin
            cycle(1, 0, DATA_WIDTH'(i));
            cycle(0, 1, '0);
        end

        // Deterministic pseudo-random stress (no simulator-specific RNG seed).
        for (int i = 0; i < 500; i++) begin
            bit w, r;
            logic [DATA_WIDTH-1:0] d;
            w = ((i * 17 + 3) % 7) < 4;
            r = ((i * 11 + 1) % 5) < 3;
            d = DATA_WIDTH'((i * 37 + 13) ^ (i >> 1));
            cycle(w, r, d);
        end

        // Final drain ensures all queued words are checked.
        while (model.size() > 0)
            cycle(0, 1, '0);

        @(negedge clk);
        wr_en = 0;
        rd_en = 0;
        #1;
        check_status();

        $display("[PASS] FIFO verification completed");
        $display("[SUMMARY] checks=%0d accepted_writes=%0d accepted_reads=%0d",
                 checks, accepted_writes, accepted_reads);
        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "Global testbench timeout");
    end
endmodule
