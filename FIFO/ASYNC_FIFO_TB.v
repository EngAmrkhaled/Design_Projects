`timescale 1ns/1ps
module ASYNC_FIFO_TB;
    parameter DATA_WIDTH=8;
    parameter FIFO_DEPTH=6;
    parameter ADDR_WIDTH=3;
    parameter TEST_BYTES=9;

    reg W_CLK,W_RST,W_INC;
    reg [DATA_WIDTH-1:0] WR_DATA;
    wire FULL;
    reg R_CLK,R_RST,R_INC;
    wire [DATA_WIDTH-1:0] RD_DATA;
    wire EMPTY;

    integer i,j,errors;
    reg [DATA_WIDTH-1:0] expected;

    ASYNC_FIFO #(.DATA_WIDTH(DATA_WIDTH),.FIFO_DEPTH(FIFO_DEPTH),.ADDR_WIDTH(ADDR_WIDTH)) DUT(
        .W_CLK(W_CLK),.W_RST(W_RST),.W_INC(W_INC),.WR_DATA(WR_DATA),
        .R_CLK(R_CLK),.R_RST(R_RST),.R_INC(R_INC),
        .RD_DATA(RD_DATA),.FULL(FULL),.EMPTY(EMPTY));

    initial begin W_CLK=0; forever #5 W_CLK=~W_CLK; end
    initial begin R_CLK=0; forever #12.5 R_CLK=~R_CLK; end

    // WRITE BLOCK: 100 MHz, 9 bytes
    initial begin : WRITE_BLOCK
        W_INC=0; WR_DATA=0;
        wait(W_RST);
        $display("========== WRITE BLOCK ==========");
        $display("Write clock = 100 MHz, FIFO depth = 6");
        for(i=0;i<TEST_BYTES;i=i+1) begin
            @(negedge W_CLK);
            while(FULL) begin
                $display("[%0t] WRITE WAIT: FULL",$time);
                @(negedge W_CLK);
            end
            WR_DATA=8'hA0+i;
            W_INC=1;
            @(posedge W_CLK);
            $display("[%0t] WRITE byte[%0d] = %02h",$time,i,WR_DATA);
            W_INC=0;
        end
        $display("========== WRITE BLOCK DONE ==========");
    end

    // READ BLOCK: 40 MHz, 9 bytes
    initial begin : READ_BLOCK
        R_INC=0;
        wait(R_RST);
        $display("========== READ BLOCK ==========");
        $display("Read clock = 40 MHz, FIFO depth = 6");
        for(j=0;j<TEST_BYTES;j=j+1) begin
            @(negedge R_CLK);
            while(EMPTY) begin
                $display("[%0t] READ WAIT: EMPTY",$time);
                @(negedge R_CLK);
            end
            expected=8'hA0+j;
            R_INC=1;
            @(posedge R_CLK);
            #1;
            if(RD_DATA !== expected) begin
                $display("[%0t] READ ERROR byte[%0d]: got %02h expected %02h",
                         $time,j,RD_DATA,expected);
                errors=errors+1;
            end else
                $display("[%0t] READ byte[%0d] = %02h -> PASS",$time,j,RD_DATA);
            R_INC=0;
        end
        $display("========== READ BLOCK DONE ==========");
    end

    initial begin
        errors=0;
        W_RST=0; R_RST=0;
        $display("======================================");
        $display("ASYNC FIFO TESTBENCH");
        $display("Write = 100 MHz | Read = 40 MHz");
        $display("Depth = 6 | Bytes = 9");
        $display("======================================");
        #50;
        W_RST=1; R_RST=1;
        $display("[%0t] RESET RELEASED",$time);
        #700;
        if(errors==0 && EMPTY)
            $display("========== TEST PASSED ==========");
        else
            $display("========== TEST FAILED: %0d errors ==========",errors);
        $finish;
    end
endmodule
