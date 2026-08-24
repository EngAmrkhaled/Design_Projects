module ASYNC_FIFO #(parameter DATA_WIDTH = 8, parameter ADDR_WIDTH = 4) (
    input wire W_CLK, input wire W_RST, input wire W_INC, input wire [DATA_WIDTH-1:0] WR_DATA,
    input wire R_CLK, input wire R_RST, input wire R_INC, output wire [DATA_WIDTH-1:0] RD_DATA,
    output wire FULL, output wire EMPTY
);
    wire W_CLKEN;
    wire [ADDR_WIDTH-1:0] W_ADDR, R_ADDR;
    wire [ADDR_WIDTH:0] W_PTR_BIN, R_PTR_BIN, W_PTR_GRAY, R_PTR_GRAY;
    wire [ADDR_WIDTH:0] W_PTR_SYNC_GRAY, R_PTR_SYNC_GRAY, W_PTR_SYNC_BIN, R_PTR_SYNC_BIN;

    FIFO_MEM_CNTRL #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) u_mem (
        .W_CLK(W_CLK), .W_CLKEN(W_CLKEN), .WR_DATA(WR_DATA), .W_ADDR(W_ADDR), .R_ADDR(R_ADDR), .RD_DATA(RD_DATA));
    FIFO_WR #(.ADDR_WIDTH(ADDR_WIDTH)) u_wr (
        .W_CLK(W_CLK), .W_RST(W_RST), .W_INC(W_INC), .R_PTR_SYNC(R_PTR_SYNC_BIN), .W_CLKEN(W_CLKEN), .W_ADDR(W_ADDR), .W_PTR(W_PTR_BIN), .FULL(FULL));
    BinarytoGray #(.WIDTH(ADDR_WIDTH+1)) u_w_b2g (.B(W_PTR_BIN), .G(W_PTR_GRAY));
    DF_SYNC #(.WIDTH(ADDR_WIDTH+1)) u_rptr_sync (.CLK(W_CLK), .RST_N(W_RST), .DATA_IN(R_PTR_GRAY), .DATA_OUT(R_PTR_SYNC_GRAY));
    GraytoBinary #(.WIDTH(ADDR_WIDTH+1)) u_r_g2b (.G(R_PTR_SYNC_GRAY), .B(R_PTR_SYNC_BIN));

    FIFO_RD #(.ADDR_WIDTH(ADDR_WIDTH)) u_rd (
        .R_CLK(R_CLK), .R_RST(R_RST), .R_INC(R_INC), .W_PTR_SYNC(W_PTR_SYNC_BIN), .R_ADDR(R_ADDR), .R_PTR(R_PTR_BIN), .EMPTY(EMPTY));
    BinarytoGray #(.WIDTH(ADDR_WIDTH+1)) u_r_b2g (.B(R_PTR_BIN), .G(R_PTR_GRAY));
    DF_SYNC #(.WIDTH(ADDR_WIDTH+1)) u_wptr_sync (.CLK(R_CLK), .RST_N(R_RST), .DATA_IN(W_PTR_GRAY), .DATA_OUT(W_PTR_SYNC_GRAY));
    GraytoBinary #(.WIDTH(ADDR_WIDTH+1)) u_w_g2b (.G(W_PTR_SYNC_GRAY), .B(W_PTR_SYNC_BIN));
endmodule
