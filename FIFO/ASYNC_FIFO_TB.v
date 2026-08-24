`timescale 1ns/1ps

module ASYNC_FIFO_TB;

    // =========================================================
    // Assignment Parameters
    // =========================================================
    parameter DATA_WIDTH = 8;

    // 9 bytes are written.
    // FIFO depth must be >= 9 entries.
    // Since asynchronous FIFO depth is 2^ADDR_WIDTH:
    // 2^3 = 8  < 9
    // 2^4 = 16 >= 9
    parameter ADDR_WIDTH = 4;
    parameter FIFO_DEPTH = (1 << ADDR_WIDTH);
    parameter TEST_BYTES = 9;

    // =========================================================
    // DUT Signals
    // =========================================================
    reg                  W_CLK;
    reg                  W_RST;
    reg                  W_INC;
    reg [DATA_WIDTH-1:0] WR_DATA;
    wire                 FULL;

    reg                  R_CLK;
    reg                  R_RST;
    reg                  R_INC;
    wire [DATA_WIDTH-1:0] RD_DATA;
    wire                 EMPTY;

    integer write_count;
    integer read_count;
    integer errors;
    reg [DATA_WIDTH-1:0] expected_data;

    // =========================================================
    // Device Under Test
    // =========================================================
    ASYNC_FIFO #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) DUT (
        .W_CLK   (W_CLK),
        .W_RST   (W_RST),
        .W_INC   (W_INC),
        .WR_DATA (WR_DATA),
        .R_CLK   (R_CLK),
        .R_RST   (R_RST),
        .R_INC   (R_INC),
        .RD_DATA (RD_DATA),
        .FULL    (FULL),
        .EMPTY   (EMPTY)
    );

    // =========================================================
    // WRITE CLOCK: 100 MHz -> 10 ns period
    // =========================================================
    initial begin
        W_CLK = 1'b0;
        forever #5 W_CLK = ~W_CLK;
    end

    // =========================================================
    // READ CLOCK: 40 MHz -> 25 ns period
    // =========================================================
    initial begin
        R_CLK = 1'b0;
        forever #12.5 R_CLK = ~R_CLK;
    end

    // =========================================================
    // WRITE BLOCK
    // Writes exactly 9 bytes at 100 MHz.
    // =========================================================
    initial begin : WRITE_BLOCK

        W_INC  = 1'b0;
        WR_DATA = 8'h00;

        // Wait for reset release.
        @(posedge W_CLK);
        while (!W_RST)
            @(posedge W_CLK);

        $display("--------------------------------------------------");
        $display("WRITE BLOCK STARTED");
        $display("Write frequency : 100 MHz");
        $display("Bytes to write  : %0d", TEST_BYTES);
        $display("FIFO depth      : %0d", FIFO_DEPTH);
        $display("--------------------------------------------------");

        for (write_count = 0; write_count < TEST_BYTES; write_count = write_count + 1) begin

            @(negedge W_CLK);

            if (FULL) begin
                $display("[%0t] ERROR: FIFO FULL while trying to write byte %0d",
                         $time, write_count);
                errors = errors + 1;
                W_INC = 1'b0;
            end
            else begin
                WR_DATA = 8'hA0 + write_count;
                W_INC   = 1'b1;

                $display("[%0t] WRITE: byte[%0d] = 0x%02h",
                         $time, write_count, WR_DATA);
            end

            @(posedge W_CLK);
            W_INC = 1'b0;
        end

        $display("[%0t] WRITE BLOCK FINISHED", $time);
    end

    // =========================================================
    // READ BLOCK
    // Reads exactly 9 bytes at 40 MHz.
    // =========================================================
    initial begin : READ_BLOCK

        R_INC = 1'b0;

        // Wait for reset release.
        @(posedge R_CLK);
        while (!R_RST)
            @(posedge R_CLK);

        $display("--------------------------------------------------");
        $display("READ BLOCK STARTED");
        $display("Read frequency  : 40 MHz");
        $display("Bytes to read   : %0d", TEST_BYTES);
        $display("--------------------------------------------------");

        for (read_count = 0; read_count < TEST_BYTES; read_count = read_count + 1) begin

            // Wait until FIFO contains valid data.
            @(negedge R_CLK);
            while (EMPTY) begin
                R_INC = 1'b0;
                @(negedge R_CLK);
            end

            // Enable one read operation.
            R_INC = 1'b1;

            // At this rising edge, RD_DATA corresponds to the
            // current read address before the pointer advances.
            @(posedge R_CLK);
            expected_data = 8'hA0 + read_count;

            if (RD_DATA !== expected_data) begin
                $display("[%0t] ERROR: READ byte[%0d] = 0x%02h, expected 0x%02h",
                         $time, read_count, RD_DATA, expected_data);
                errors = errors + 1;
            end
            else begin
                $display("[%0t] READ : byte[%0d] = 0x%02h  --> PASS",
                         $time, read_count, RD_DATA);
            end

            R_INC = 1'b0;
        end

        $display("[%0t] READ BLOCK FINISHED", $time);
    end

    // =========================================================
    // RESET + FINAL CHECK
    // =========================================================
    initial begin : CONTROL_BLOCK

        errors = 0;
        write_count = 0;
        read_count = 0;

        W_RST = 1'b0;
        R_RST = 1'b0;

        $display("");
        $display("==================================================");
        $display("        ASYNCHRONOUS FIFO TESTBENCH");
        $display("==================================================");
        $display("Required write frequency : 100 MHz");
        $display("Required read frequency  : 40 MHz");
        $display("Required written bytes   : 9");
        $display("Calculated FIFO depth    : 16 entries");
        $display("==================================================");

        // Hold both asynchronous resets active.
        #50;

        W_RST = 1'b1;
        R_RST = 1'b1;

        $display("[%0t] RESET RELEASED", $time);

        // Allow the read block to finish all 9 reads.
        #500;

        if (!EMPTY) begin
            $display("[%0t] ERROR: FIFO is not EMPTY after all reads.", $time);
            errors = errors + 1;
        end
        else begin
            $display("[%0t] FINAL CHECK: FIFO EMPTY --> PASS", $time);
        end

        $display("");
        $display("==================================================");
        if (errors == 0)
            $display("                 TEST PASSED");
        else
            $display("                 TEST FAILED (%0d errors)", errors);
        $display("==================================================");

        #20;
        $finish;
    end

    // =========================================================
    // Waveform Dump
    // =========================================================
    initial begin
        $dumpfile("async_fifo.vcd");
        $dumpvars(0, ASYNC_FIFO_TB);
    end

endmodule
