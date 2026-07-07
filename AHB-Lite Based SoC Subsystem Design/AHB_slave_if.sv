`timescale 1ns/1ps
// ==============================================================================
// Module Name: AHB_slave_if
// Description: Optimized and safe AHB-Lite Slave Interface.
// ==============================================================================
module AHB_slave_if (
    input  logic        HCLK,
    input  logic        HRESETn,
    input  logic [31:0] HADDR,
    input  logic        HWRITE,
    input  logic [1:0]  HSIZE,
    input  logic [1:0]  HTRANS,
    input  logic [31:0] HWDATA,
    input  logic        HSEL_P,
    input  logic        HREADY,

    // Peripheral Side Signals
    input  logic [31:0] peripheral_rd_data,
    input  logic        peripheral_ready,
    input  logic        peripheral_response,

    // AHB Bus Side Outputs
    output logic [31:0] HRDATA_P, 
    output logic        HREADY_P, 
    output logic        HRESP_P,
    
    // Controls to Peripheral
    output logic        peripheral_we,
    output logic        peripheral_re,
    output logic [31:0] Addr,
    output logic [1:0]  size,
    output logic [31:0] wd_data
);
    // Pipeline registers for Address Phase -> Data Phase transition
    logic [31:0] HADDR_reg;
    logic        HWRITE_reg;
    logic [1:0]  HSIZE_reg;
    logic [1:0]  HTRANS_reg;
    logic        HSEL_P_reg;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            HADDR_reg  <= 32'b0;
            HWRITE_reg <= 1'b0;
            HSIZE_reg  <= 2'b0;
            HTRANS_reg <= 2'b0;
            HSEL_P_reg <= 1'b0;
        end else if (HREADY) begin // Properly gated by HREADY to support bus stalls
            HADDR_reg  <= HADDR;
            HWRITE_reg <= HWRITE;
            HSIZE_reg  <= HSIZE;
            HTRANS_reg <= HTRANS;
            HSEL_P_reg <= HSEL_P;
        end
    end

    // Combinational control signals to peripheral
    assign peripheral_we = HREADY && HSEL_P_reg && HWRITE_reg && (HTRANS_reg == 2'b10 || HTRANS_reg == 2'b11);
    assign peripheral_re = HREADY && HSEL_P_reg && !HWRITE_reg && (HTRANS_reg == 2'b10 || HTRANS_reg == 2'b11);

    // Direct, optimized data and control assignments
    assign Addr    = (HSEL_P_reg && (HTRANS_reg == 2'b10 || HTRANS_reg == 2'b11)) ? HADDR_reg : 32'b0;
    assign size    = HSIZE_reg;
    assign wd_data = HWDATA;

    // Interface Feedback outputs
    assign HRDATA_P = peripheral_rd_data;
    assign HREADY_P = peripheral_ready;
    assign HRESP_P  = peripheral_response;
 
endmodule