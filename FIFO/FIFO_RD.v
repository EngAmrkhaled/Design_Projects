module FIFO_RD #(parameter ADDR_WIDTH = 4) (input wire R_CLK, input wire R_RST, input wire R_INC, input wire [ADDR_WIDTH:0] W_PTR_SYNC, output wire [ADDR_WIDTH-1:0] R_ADDR, output reg [ADDR_WIDTH:0] R_PTR, output wire EMPTY);
    assign EMPTY = (R_PTR == W_PTR_SYNC);
    assign R_ADDR = R_PTR[ADDR_WIDTH-1:0];
    always @(posedge R_CLK or negedge R_RST) begin
        if (!R_RST) R_PTR <= 0;
        else if (R_INC && !EMPTY) R_PTR <= R_PTR + 1'b1;
    end
endmodule
