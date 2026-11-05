// -----------------------------------------------------------------------------
// Module: sync_fifo
// Description: Parameterized synchronous FIFO with asynchronous active-low reset.
// Semantics:
//   * Write is accepted when wr_en && !full.
//   * Read is accepted when rd_en && !empty.
//   * A simultaneous accepted read and write leaves occupancy unchanged.
//   * If empty, simultaneous rd_en and wr_en accepts the write only.
//   * If full, simultaneous rd_en and wr_en accepts the read only; the write
//     is not accepted because full is evaluated from pre-edge state.
//   * dout is registered and updates only on an accepted read.
// -----------------------------------------------------------------------------
module sync_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 16,
    parameter int ADDR_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH),
    parameter int COUNT_WIDTH = $clog2(DEPTH + 1)
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  wr_en,
    input  logic                  rd_en,
    input  logic [DATA_WIDTH-1:0] din,
    output logic [DATA_WIDTH-1:0] dout,
    output logic                  full,
    output logic                  empty,
    output logic [COUNT_WIDTH-1:0] count
);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [ADDR_WIDTH-1:0] wr_ptr;
    logic [ADDR_WIDTH-1:0] rd_ptr;

    logic do_write;
    logic do_read;

    function automatic logic [ADDR_WIDTH-1:0] next_ptr(
        input logic [ADDR_WIDTH-1:0] ptr
    );
        if (ptr == ADDR_WIDTH'(DEPTH-1))
            next_ptr = '0;
        else
            next_ptr = ptr + 1'b1;
    endfunction

    assign empty = (count == '0);
    assign full  = (count == COUNT_WIDTH'(DEPTH));

    // Acceptance is based on flags before the active clock edge.
    assign do_write = wr_en && !full;
    assign do_read  = rd_en && !empty;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count  <= '0;
            dout   <= '0;
        end else begin
            if (do_write) begin
                mem[wr_ptr] <= din;
                wr_ptr      <= next_ptr(wr_ptr);
            end

            if (do_read) begin
                dout   <= mem[rd_ptr];
                rd_ptr <= next_ptr(rd_ptr);
            end

            case ({do_write, do_read})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end

    initial begin
        if (DATA_WIDTH < 1)
            $error("DATA_WIDTH must be >= 1");
        if (DEPTH < 1)
            $error("DEPTH must be >= 1");
    end

endmodule
