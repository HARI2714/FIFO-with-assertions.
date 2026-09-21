`timescale 1ns/1ps
// Self-checking testbench: directed tests + random traffic, scoreboard against
// a simple reference model (plain arrays so it also runs in Icarus Verilog).
module tb_sync_fifo;
    parameter DATA_W = 8, ADDR_W = 3;
    localparam DEPTH = 1 << ADDR_W;

    reg clk = 0, rst_n = 0, wr_en = 0, rd_en = 0;
    reg  [DATA_W-1:0] wr_data = 0;
    wire [DATA_W-1:0] rd_data;
    wire full, empty;

    sync_fifo #(.DATA_W(DATA_W), .ADDR_W(ADDR_W)) dut (
        .clk(clk), .rst_n(rst_n), .wr_en(wr_en), .wr_data(wr_data),
        .rd_en(rd_en), .rd_data(rd_data), .full(full), .empty(empty));

    always #5 clk = ~clk;

    // ---------------- reference model ----------------
    reg [DATA_W-1:0] ref_mem [0:DEPTH-1];
    integer m_w, m_r, m_cnt;
    reg [DATA_W-1:0] exp_data;
    reg exp_valid;
    integer errors = 0, checks = 0;
    reg do_wr_m, do_rd_m;

    always @(posedge clk) begin
        if (!rst_n) begin
            m_w = 0; m_r = 0; m_cnt = 0; exp_valid = 0;
        end else begin
            // decisions use pre-edge occupancy, exactly like the DUT flags
            do_wr_m = wr_en && (m_cnt < DEPTH);
            do_rd_m = rd_en && (m_cnt > 0);
            exp_valid = do_rd_m;
            if (do_rd_m) exp_data = ref_mem[m_r % DEPTH];
            if (do_wr_m) ref_mem[m_w % DEPTH] = wr_data;
            if (do_wr_m) m_w = m_w + 1;
            if (do_rd_m) m_r = m_r + 1;
            m_cnt = m_cnt + do_wr_m - do_rd_m;
        end
    end

    // check just after the edge
    always @(posedge clk) begin
        #1;
        if (rst_n) begin
            checks = checks + 1;
            if (exp_valid && rd_data !== exp_data) begin
                errors = errors + 1;
                $display("[%0t] DATA MISMATCH got=%h exp=%h", $time, rd_data, exp_data);
            end
            if (full  !== (m_cnt == DEPTH)) begin errors = errors + 1; $display("[%0t] FULL flag mismatch",  $time); end
            if (empty !== (m_cnt == 0))     begin errors = errors + 1; $display("[%0t] EMPTY flag mismatch", $time); end
        end
    end

    // ---------------- helpers (drive on negedge) ----------------
    task push(input [DATA_W-1:0] d);
        begin @(negedge clk); wr_en = 1; wr_data = d; rd_en = 0; @(negedge clk); wr_en = 0; end
    endtask
    task pop;
        begin @(negedge clk); rd_en = 1; wr_en = 0; @(negedge clk); rd_en = 0; end
    endtask

    integer i;
    initial begin
        $dumpfile("sim/fifo.vcd"); $dumpvars(0, tb_sync_fifo);
        repeat (3) @(negedge clk);
        rst_n = 1;

        // T1: reset state
        @(negedge clk);
        if (!empty || full) begin errors = errors + 1; $display("T1 FAIL: bad reset flags"); end

        // T2: fill to full, then attempt overflow
        for (i = 0; i < DEPTH; i = i + 1) push(8'hA0 + i);
        repeat (2) push(8'hFF);            // overflow attempts, must be ignored
        // T3: drain everything, then attempt underflow
        for (i = 0; i < DEPTH; i = i + 1) pop;
        repeat (2) pop;                     // underflow attempts, must be ignored

        // T4: simultaneous read+write at various occupancies
        push(8'h11); push(8'h22);
        for (i = 0; i < 6; i = i + 1) begin
            @(negedge clk); wr_en = 1; rd_en = 1; wr_data = 8'h30 + i;
        end
        @(negedge clk); wr_en = 0; rd_en = 0;
        for (i = 0; i < DEPTH; i = i + 1) pop;

        // T5: random traffic (biased to hit both full and empty corners)
        for (i = 0; i < 5000; i = i + 1) begin
            @(negedge clk);
            wr_en   = (($random & 3) != 0) ^ (i % 400 > 200);
            rd_en   = (($random & 3) != 0) ^ (i % 400 <= 200);
            wr_data = $random;
        end
        @(negedge clk); wr_en = 0; rd_en = 0;

        // T6: mid-operation reset
        push(8'h5A); push(8'h5B);
        @(negedge clk); rst_n = 0; @(negedge clk); @(negedge clk); rst_n = 1;
        @(negedge clk);
        if (!empty) begin errors = errors + 1; $display("T6 FAIL: not empty after reset"); end

        repeat (3) @(negedge clk);
        $display("--------------------------------------------");
        $display("Cycles checked: %0d  Errors: %0d", checks, errors);
        if (errors == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
        $finish;
    end
endmodule
