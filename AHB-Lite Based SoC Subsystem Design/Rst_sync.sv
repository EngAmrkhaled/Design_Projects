// ==============================================================================
// Module Name: Rst_sync
// Description: Asynchronous Reset Synchronizer (2-Stage) to prevent meta-stability.
// ==============================================================================
module Rst_sync (
    input  logic clk,
    input  logic async_rst_n,  // Asynchronous external reset (active low)
    output logic sync_rst_n    // Synchronized reset (active low)
);
    logic Q1;

    always_ff @(posedge clk or negedge async_rst_n) begin
        if (!async_rst_n) begin
            Q1         <= 1'b0;
            sync_rst_n <= 1'b0;
        end else begin
            Q1         <= 1'b1;
            sync_rst_n <= Q1;
        end
    end
endmodule