// Synchronous FIFO, parameterized, extra-MSB pointer scheme for full/empty.
// Depth = 2**ADDR_W. Writes when full and reads when empty are ignored.
// Read data is registered (valid the cycle after rd_en).
module sync_fifo #(
    parameter DATA_W = 8,
    parameter ADDR_W = 4
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire              wr_en,
    input  wire [DATA_W-1:0] wr_data,
    input  wire              rd_en,
    output reg  [DATA_W-1:0] rd_data,
    output wire              full,
    output wire              empty
);
    localparam DEPTH = 1 << ADDR_W;

    reg [DATA_W-1:0] mem [0:DEPTH-1];
    reg [ADDR_W:0]   wptr, rptr;   // one extra MSB distinguishes full from empty

    assign empty = (wptr == rptr);
    assign full  = (wptr[ADDR_W] != rptr[ADDR_W]) &&
                   (wptr[ADDR_W-1:0] == rptr[ADDR_W-1:0]);

    wire do_wr = wr_en && !full;
    wire do_rd = rd_en && !empty;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wptr    <= 0;
            rptr    <= 0;
            rd_data <= 0;
        end else begin
            if (do_wr) begin
                mem[wptr[ADDR_W-1:0]] <= wr_data;
                wptr <= wptr + 1;
            end
            if (do_rd) begin
                rd_data <= mem[rptr[ADDR_W-1:0]];
                rptr <= rptr + 1;
            end
        end
    end

`ifndef SYNTHESIS
    // ---------------- Assertions (simulation only) ----------------
    reg [ADDR_W:0] wptr_q, rptr_q;
    reg            full_q, empty_q, wr_en_q, rd_en_q, armed;
    wire [ADDR_W:0] count = wptr - rptr;
    wire [ADDR_W:0] dw = wptr - wptr_q;   // sized so pointer wrap-around is handled
    wire [ADDR_W:0] dr = rptr - rptr_q;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            armed <= 1;
            wptr_q <= 0; rptr_q <= 0; full_q <= 0; empty_q <= 1; wr_en_q <= 0; rd_en_q <= 0;
        end else begin
            // A1: full and empty are never high together
            assert (!(full && empty)) else $error("A1: full && empty");
            // A2: occupancy never exceeds depth
            assert (count <= DEPTH) else $error("A2: count > DEPTH");
            // A3/A4: flags agree with occupancy
            assert (full  == (count == DEPTH)) else $error("A3: full flag wrong");
            assert (empty == (count == 0))     else $error("A4: empty flag wrong");
            // A5: overflow guard - wptr advances only on a valid write (not full)
            if (armed && wptr != wptr_q)
                assert (!full_q && wr_en_q) else $error("A5: wptr moved without valid write");
            // A6: underflow guard - rptr advances only on a valid read (not empty)
            if (armed && rptr != rptr_q)
                assert (!empty_q && rd_en_q) else $error("A6: rptr moved without valid read");
            // A7: pointers move by at most 1 per cycle
            if (armed) begin
                assert (dw <= 1) else $error("A7: wptr jumped");
                assert (dr <= 1) else $error("A7: rptr jumped");
            end
            wptr_q <= wptr; rptr_q <= rptr; full_q <= full; empty_q <= empty;
            wr_en_q <= wr_en; rd_en_q <= rd_en;
        end
    end
`endif
endmodule
