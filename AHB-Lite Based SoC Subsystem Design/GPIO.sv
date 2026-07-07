// ==============================================================================
// Module Name: GPIO
// Description: General Purpose I/O Peripheral.
// ==============================================================================
module GPIO #(
    parameter GPIO_WIDTH = 8  // Width of each GPIO port
)(
    input  logic                                clk,
    input  logic                                rst_n,
    input  logic                                en,                 // Slave select
    input  logic       [2:0]                    Addr,               // Port address
    input  logic       [1:0]                    size,               // Size (unused here)
    input  logic                                we,                 // Write enable
    input  logic                                re,                 // Read enable
    input  logic       [31:0]                   wd_data,            // Write data
    
    input  logic       [GPIO_WIDTH-1:0]         GPIO_in_portA,      // Input Ports
    input  logic       [GPIO_WIDTH-1:0]         GPIO_in_portB,
    input  logic       [GPIO_WIDTH-1:0]         GPIO_in_portC,
    input  logic       [GPIO_WIDTH-1:0]         GPIO_in_portD,
    
    output logic       [31:0]                   rd_data,            // Read data
    
    output logic       [GPIO_WIDTH-1:0]         GPIO_out_portA,     // Output Ports
    output logic       [GPIO_WIDTH-1:0]         GPIO_out_portB,
    output logic       [GPIO_WIDTH-1:0]         GPIO_out_portC,
    output logic       [GPIO_WIDTH-1:0]         GPIO_out_portD,
    
    output logic                                done,               // Slave Ready
    output logic                                check               // Error Response
);

    assign done = 1'b1;  // GPIO is fast, always ready (0 Wait States)
    assign check = 1'b0; // No error generation in GPIO

    // ----------------------------------------------------
    // Write Operation (Sequential) - Drive Output Ports
    // ----------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            GPIO_out_portA <= '0;
            GPIO_out_portB <= '0;
            GPIO_out_portC <= '0;
            GPIO_out_portD <= '0;
        end else if (en && we) begin
            case (Addr)
                3'b100: GPIO_out_portA <= wd_data[GPIO_WIDTH-1:0];
                3'b101: GPIO_out_portB <= wd_data[GPIO_WIDTH-1:0];
                3'b110: GPIO_out_portC <= wd_data[GPIO_WIDTH-1:0];
                3'b111: GPIO_out_portD <= wd_data[GPIO_WIDTH-1:0];
            endcase
        end
    end

    // ----------------------------------------------------
    // Read Operation (Combinational) - Read Input Ports
    // ----------------------------------------------------
    always_comb begin
        rd_data = 32'b0; // Default value to prevent Latches
        if (en && re) begin
            case (Addr)
                3'b000:  rd_data[GPIO_WIDTH-1:0] = GPIO_in_portA;
                3'b001:  rd_data[GPIO_WIDTH-1:0] = GPIO_in_portB;
                3'b010:  rd_data[GPIO_WIDTH-1:0] = GPIO_in_portC;
                3'b011:  rd_data[GPIO_WIDTH-1:0] = GPIO_in_portD;
                default: rd_data = 32'b0; // Invalid Address Read 
            endcase
        end
    end

endmodule