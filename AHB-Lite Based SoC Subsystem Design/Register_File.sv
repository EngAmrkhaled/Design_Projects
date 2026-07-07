// ==============================================================================
// Module Name: Register_File
// Description: Flexible memory slave supporting variable AHB HSIZE accesses.
// ==============================================================================
`timescale 1ns/1ps

module Register_File #(
    parameter REG_WIDTH = 8,
    parameter REG_DEPTH = 32
)(
    input  logic                        clk,
    input  logic                        rst_n,
    input  logic                        en,
    input  logic [$clog2(REG_DEPTH)-1:0] Addr, 
    input  logic [1:0]                  size,
    input  logic                        we,
    input  logic                        re,
    input  logic [31:0]                 wd_data,
    
    output logic [31:0]                 rd_data,
    output logic                        done,
    output logic                        check
);

    logic [REG_WIDTH-1:0] Reg_file [REG_DEPTH-1:0];
    
    logic halfword_ov, word_ov, addr_error;
    
    logic [$clog2(REG_DEPTH)-1:0] addr_p1, addr_p2, addr_p3;
    assign addr_p1 = Addr + 1;
    assign addr_p2 = Addr + 2;
    assign addr_p3 = Addr + 3;

    assign halfword_ov = (size == 2'b01) && (Addr >= REG_DEPTH-1);
    assign word_ov     = (size == 2'b10) && (Addr >= REG_DEPTH-3);
    assign addr_error  = (we | re) & (halfword_ov | word_ov);

    assign done = 1'b1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) check <= 1'b0;
        else        check <= (en && addr_error); // ERROR if unaligned access at boundary
    end

    // WRITE
    always_ff @(posedge clk) begin
        if (en && we && !addr_error) begin
            case (size)
                2'b00: Reg_file[Addr] <= wd_data[7:0];
                2'b01: begin
                    Reg_file[Addr]   <= wd_data[7:0];
                    Reg_file[addr_p1] <= wd_data[15:8];
                end
                2'b10: begin
                    Reg_file[Addr]   <= wd_data[7:0]; 
                    Reg_file[addr_p1] <= wd_data[15:8]; 
                    Reg_file[addr_p2] <= wd_data[23:16];
                    Reg_file[addr_p3] <= wd_data[31:24];
                end
            endcase
        end
    end

    // READ
    always_comb begin
        rd_data = 32'b0;
        if (en && re && !addr_error) begin
            case (size)
                2'b00: rd_data = {24'h0, Reg_file[Addr]};
                2'b01: rd_data = {16'h0, Reg_file[addr_p1], Reg_file[Addr]};
                2'b10: rd_data = {Reg_file[addr_p3], Reg_file[addr_p2], Reg_file[addr_p1], Reg_file[Addr]};
            endcase
        end
    end

endmodule