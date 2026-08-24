module FIFO_WR #(parameter ADDR_WIDTH = 4) (input wire W_CLK, input wire W_RST, input wire W_INC, input wire [ADDR_WIDTH:0] R_PTR_SYNC, output wire W_CLKEN, output wire [ADDR_WIDTH-1:0] W_ADDR, output reg [ADDR_WIDTH:0] W_PTR, output wire FULL);
    assign W_CLKEN = W_INC & ~FULL;
    assign W_ADDR = W_PTR[ADDR_WIDTH-1:0];
    assign FULL = (W_PTR[ADDR_WIDTH] != R_PTR_SYNC[ADDR_WIDTH]) && (W_PTR[ADDR_WIDTH-1:0] == R_PTR_SYNC[ADDR_WIDTH-1:0]);
    always @(posedge W_CLK or negedge W_RST) begin
        if (!W_RST) W_PTR <= 0;
        else if (W_CLKEN) W_PTR <= W_PTR + 1'b1;
    end
endmodule
