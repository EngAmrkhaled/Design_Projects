module FIFO_MEM_CNTRL #(parameter DATA_WIDTH = 8, parameter FIFO_DEPTH = 6, parameter ADDR_WIDTH = 3) (
    input wire W_CLK, input wire W_CLKEN,
    input wire [DATA_WIDTH-1:0] WR_DATA,
    input wire [ADDR_WIDTH-1:0] W_ADDR,
    input wire [ADDR_WIDTH-1:0] R_ADDR,
    output wire [DATA_WIDTH-1:0] RD_DATA
);
    reg [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];

    always @(posedge W_CLK)
        if (W_CLKEN)
            mem[W_ADDR] <= WR_DATA;

    assign RD_DATA = mem[R_ADDR];
endmodule
