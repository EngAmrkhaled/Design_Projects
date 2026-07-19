`timescale 1ns / 1ps

module weighted_ma_filter #(parameter DATA_WIDTH = 16)(
    input  logic clk,
    input  logic rst_n,
    input  logic valid_in,
    input  logic signed [DATA_WIDTH-1:0] x_in, 
    output logic valid_out,
    output logic signed [DATA_WIDTH-1:0] y_out 
);

    // -------------------------------------------------------------------------
    // Coefficients: h0 = 1, h1 = 0.5, h2 = 0.25, h3 = 0.125
    // We replace expensive multipliers with Arithmetic Right Shifts (>>>)
    // -------------------------------------------------------------------------
    logic signed [DATA_WIDTH-1:0] w0, w1, w2, w3;

    assign w0 = x_in;                 // x_in * 1
    assign w1 = x_in >>> 1;           // x_in * 0.5
    assign w2 = x_in >>> 2;           // x_in * 0.25
    assign w3 = x_in >>> 3;           // x_in * 0.125

    // -------------------------------------------------------------------------
    // Transposed Form FIR Filter Implementation
    // -------------------------------------------------------------------------
    logic signed [DATA_WIDTH-1:0] reg1, reg2, reg3, reg_out;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg3      <= '0;
            reg2      <= '0;
            reg1      <= '0;
            reg_out   <= '0;
            valid_out <= 1'b0;
        end else if (valid_in) begin
            reg3      <= w3;
            reg2      <= w2 + reg3;
            reg1      <= w1 + reg2;
            reg_out   <= w0 + reg1;
            valid_out <= 1'b1;
        end else begin
            // Hold values but indicate invalid data if input stops
            valid_out <= 1'b0; 
        end
    end

    // Output assignment
    assign y_out = reg_out;

endmodule