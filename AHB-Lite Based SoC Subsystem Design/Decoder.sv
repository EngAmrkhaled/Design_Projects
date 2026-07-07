// ==============================================================================
// Module Name: Decoder
// Description: Address decoder to select the active slave based on memory map.
// ==============================================================================
module Decoder #(
    parameter logic [3:0] GPIO_BASE_MSB     = 4'b0000, // 32'h0000_0000 -> 32'h0FFF_FFFF
    parameter logic [3:0] TIMER_BASE_MSB    = 4'b0001, // 32'h1000_0000 -> 32'h1FFF_FFFF
    parameter logic [3:0] REG_FILE_BASE_MSB = 4'b0010  // 32'h2000_0000 -> 32'h2FFF_FFFF
)(
    input  logic [31:0] HADDR,
    output logic        HSEL_G,
    output logic        HSEL_T,
    output logic        HSEL_R
);
    // Dynamic address decoding logic
    assign HSEL_G = (HADDR[31:28] == GPIO_BASE_MSB);
    assign HSEL_T = (HADDR[31:28] == TIMER_BASE_MSB);
    assign HSEL_R = (HADDR[31:28] == REG_FILE_BASE_MSB);

endmodule