module DF_SYNC #(parameter WIDTH = 5) (input wire CLK, input wire RST_N, input wire [WIDTH-1:0] DATA_IN, output wire [WIDTH-1:0] DATA_OUT);
    wire [WIDTH-1:0] sync_ff1;
    FF #(.WIDTH(WIDTH)) sync_stage1 (.clk(CLK), .rst_n(RST_N), .d(DATA_IN), .q(sync_ff1));
    FF #(.WIDTH(WIDTH)) sync_stage2 (.clk(CLK), .rst_n(RST_N), .d(sync_ff1), .q(DATA_OUT));
endmodule
