module FIFO_WR #(parameter ADDR_WIDTH = 3, parameter FIFO_DEPTH = 6) (
    input wire W_CLK, input wire W_RST, input wire W_INC,
    input wire [ADDR_WIDTH:0] R_PTR_SYNC,
    output wire W_CLKEN, output wire [ADDR_WIDTH-1:0] W_ADDR,
    output reg [ADDR_WIDTH:0] W_PTR, output wire FULL
);
    assign W_CLKEN = W_INC & ~FULL;
    // Pointer index 0..5 maps to memory addresses 0..5.
    // Pointer index 6..11 is the second FIFO cycle.
    assign W_ADDR = (W_PTR[ADDR_WIDTH:0] < FIFO_DEPTH) ? W_PTR[ADDR_WIDTH-1:0] :
                    (W_PTR[ADDR_WIDTH:0] - FIFO_DEPTH);
    // Full means the write pointer is exactly 6 positions ahead of read pointer.
    assign FULL = (W_PTR == ((R_PTR_SYNC + FIFO_DEPTH) % (2*FIFO_DEPTH)));
    always @(posedge W_CLK or negedge W_RST) begin
        if (!W_RST) W_PTR <= 0;
        else if (W_CLKEN) begin
            if (W_PTR == (2*FIFO_DEPTH-1)) W_PTR <= 0;
            else W_PTR <= W_PTR + 1'b1;
        end
    end
endmodule
