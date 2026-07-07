`timescale 1ns/1ps

module AHB_lite_system_tb;

    // Parameters
    parameter CLK_PERIOD    = 10;
    parameter REG_WIDTH     = 8;
    parameter REG_DEPTH     = 32;
    parameter GPIO_WIDTH    = 8;
    parameter COUNTER_WIDTH = 32;

    // Signals declaration
    logic                       HCLK;
    logic                       HRESETn;
    logic  [31:0]               PADDR;
    logic                       PWRITE;
    logic  [1:0]                PSIZE;
    logic                       PVALID; 
    logic  [2:0]                PBURST;
    logic  [31:0]               PWDATA;
    
    logic  [GPIO_WIDTH-1:0]     GPIO_in_portA;      
    logic  [GPIO_WIDTH-1:0]     GPIO_in_portB;      
    logic  [GPIO_WIDTH-1:0]     GPIO_in_portC;      
    logic  [GPIO_WIDTH-1:0]     GPIO_in_portD;      
    
    logic                       Register_File_En;
    logic                       GPIO_En;
    logic                       Timer_En;

    logic                       PREADY;
    logic                       PRESP;
    logic  [31:0]               PRDATA;
    
    logic [GPIO_WIDTH-1:0]      GPIO_out_portA;     
    logic [GPIO_WIDTH-1:0]      GPIO_out_portB;     
    logic [GPIO_WIDTH-1:0]      GPIO_out_portC;     
    logic [GPIO_WIDTH-1:0]      GPIO_out_portD;

    // Performance tracking variables
    int correct_count = 0;
    int error_count   = 0;

    // --------------------------------------------------------------------------
    // Device Under Test (DUT) Instance
    // --------------------------------------------------------------------------
    AHB_lite_system #(
        .REG_WIDTH(REG_WIDTH),
        .REG_DEPTH(REG_DEPTH),
        .GPIO_WIDTH(GPIO_WIDTH),
        .COUNTER_WIDTH(COUNTER_WIDTH)
    ) dut (
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .PADDR(PADDR),
        .PWRITE(PWRITE),
        .PSIZE(PSIZE),
        .PVALID(PVALID), 
        .PBURST(PBURST),
        .PWDATA(PWDATA),
        .GPIO_in_portA(GPIO_in_portA),
        .GPIO_in_portB(GPIO_in_portB),
        .GPIO_in_portC(GPIO_in_portC),
        .GPIO_in_portD(GPIO_in_portD),
        .Register_File_En(Register_File_En),
        .GPIO_En(GPIO_En),
        .Timer_En(Timer_En),
        .PREADY(PREADY),
        .PRESP(PRESP),
        .PRDATA(PRDATA),
        .GPIO_out_portA(GPIO_out_portA),
        .GPIO_out_portB(GPIO_out_portB),
        .GPIO_out_portC(GPIO_out_portC),
        .GPIO_out_portD(GPIO_out_portD)
    );

    // Clock Generation
    always #(CLK_PERIOD/2) HCLK = ~HCLK;

    // --------------------------------------------------------------------------
    // Stimulus Generation
    // --------------------------------------------------------------------------
    initial begin
        // Initialize signals to default states
        HCLK             = 0;
        HRESETn          = 0;
        PADDR            = 0;
        PWRITE           = 0;
        PSIZE            = 2'b10;  // Default to Word size (4 Bytes)
        PVALID           = 0;      // Starts at IDLE state
        PBURST           = 3'b000; // SINGLE transfer type
        GPIO_in_portA    = 8'hA1;
        GPIO_in_portB    = 8'hB2;
        GPIO_in_portC    = 8'hC3;
        GPIO_in_portD    = 8'hD4;
        Register_File_En = 0;
        GPIO_En          = 0;
        Timer_En         = 0;

        // Reset Sequence
        #(CLK_PERIOD * 2);
        HRESETn = 1;
        #(CLK_PERIOD);

        $display("==================================================");
        $display("Starting AHB-Lite System Verification with PVALID");
        $display("==================================================");

        // ======================================================================
        // --- TEST 1: Write and Read from Register File ---
        // ======================================================================
        Register_File_En = 1;
        
        // --- 1.A) Write Operation (Address Phase) ---
        @(posedge HCLK);
        PADDR  = 32'h2000_0004; 
        PWRITE = 1;
        PWDATA = 32'hDEADBEEF;
        PVALID = 1;            
        PBURST = 3'b000;

        // Wait until Master accepts and drives the Address Phase on the bus
        @(posedge HCLK);
        while (!PREADY) @(posedge HCLK); 
        
        // Clear transaction controls (End of Address Phase request)
        PVALID = 0;            
        PWRITE = 0;

        // --- 1.B) Wait for Write Data Phase to Complete ---
        @(posedge HCLK);
        while (!PREADY) @(posedge HCLK);

        #(CLK_PERIOD * 2);

        // --- 1.C) Read Operation (Address Phase) ---
        @(posedge HCLK);
        PADDR  = 32'h2000_0004; 
        PWRITE = 0;
        PVALID = 1;            

        // Wait for Master to latch the read command
        @(posedge HCLK);
        while (!PREADY) @(posedge HCLK);
        PVALID = 0; // Clear read request
        
        // --- 1.D) Read Data Phase ---
        @(posedge HCLK);
        while (!PREADY) @(posedge HCLK);
        
        #1; 
        check_read(32'hDEADBEEF, 1'b1, 1'b0);
        Register_File_En = 0;


        // ======================================================================
        // --- TEST 2: Read from GPIO Input Port ---
        // ======================================================================
        GPIO_En = 1;
        
        // --- 2.A) Read Operation (Address Phase) ---
        @(posedge HCLK);
        PADDR  = 32'h0000_0000; // Port A input address
        PWRITE = 0;
        PVALID = 1;

        // Wait for Master to latch the GPIO address phase
        @(posedge HCLK);
        while (!PREADY) @(posedge HCLK);
        PVALID = 0;

        // --- 2.B) Read Data Phase ---
        @(posedge HCLK);
        while (!PREADY) @(posedge HCLK);

        #1; 
        check_read(32'h0000_00A1, 1'b1, 1'b0);
        GPIO_En = 0;

        #(CLK_PERIOD * 2);

        // ======================================================================
        // --- TEST 3: Advanced Burst Verification (INCR4 on Register File) ---
        // ======================================================================
        $display("--------------------------------------------------");
        $display("Starting TEST 3: 4-Beat Incrementing Burst (INCR4)");
        $display("--------------------------------------------------");
        Register_File_En = 1;

        // --- 3.A) INCR4 Burst Write Operation ---
        @(posedge HCLK);
        PADDR  = 32'h2000_0000; // Starting at address 0
        PWRITE = 1;
        PBURST = 3'b011;        // INCR4 encoding
        PVALID = 1;
        PWDATA = 32'h1111_1111; // Data for Beat 1

        // Beat 1 Address Phase / Data Phase entry
        @(posedge HCLK); while (!PREADY) @(posedge HCLK);
        
        // Beat 2
        PWDATA = 32'h2222_2222; // Data for Beat 2
        @(posedge HCLK); while (!PREADY) @(posedge HCLK);

        // Beat 3
        PWDATA = 32'h3030_3030; // Data for Beat 3
        @(posedge HCLK); while (!PREADY) @(posedge HCLK);

        // Beat 4
        PWDATA = 32'h4444_4444; // Data for Beat 4
        @(posedge HCLK); while (!PREADY) @(posedge HCLK);

        // End of Address phases, clear controls
        PVALID = 0;
        PWRITE = 0;

        // Wait for final Beat 4 Data phase to complete
        @(posedge HCLK); while (!PREADY) @(posedge HCLK);
        $display("[%0t] INCR4 Burst Write Finished successfully.", $time);

        #(CLK_PERIOD * 3);

        // --- 3.B) INCR4 Burst Read Operation & Verification (Aligned Timing) ---
        @(posedge HCLK);
        PADDR  = 32'h2000_0000; // Read from start of burst
        PWRITE = 0;
        PBURST = 3'b011;        // INCR4
        PVALID = 1;

        // Cycle R1: Master drives Beat 1 Address Phase (NONSEQ)
        @(posedge HCLK); while (!PREADY) @(posedge HCLK);
        
        // Cycle R2: Master drives Beat 2 Address (SEQ) / Slave processes Beat 1 Data Phase
        @(posedge HCLK); while (!PREADY) @(posedge HCLK);
        #1; check_read(32'h1111_1111, 1'b1, 1'b0); // Verify Beat 1 Data
        
        // Cycle R3: Master drives Beat 3 Address (SEQ) / Slave processes Beat 2 Data Phase
        @(posedge HCLK); while (!PREADY) @(posedge HCLK);
        #1; check_read(32'h2222_2222, 1'b1, 1'b0); // Verify Beat 2 Data

        // Cycle R4: Master drives Beat 4 Address (SEQ) / Slave processes Beat 3 Data Phase
        PVALID = 0; // End of Burst Read request
        @(posedge HCLK); while (!PREADY) @(posedge HCLK);
        #1; check_read(32'h3030_3030, 1'b1, 1'b0); // Verify Beat 3 Data

        // Cycle R5: Master returns to IDLE / Slave processes Beat 4 Data Phase
        @(posedge HCLK); while (!PREADY) @(posedge HCLK);
        #1; check_read(32'h4444_4444, 1'b1, 1'b0); // Verify Beat 4 Data
        
        Register_File_En = 0;
        #(CLK_PERIOD * 2);

        // ======================================================================
        // --- TEST 4: Timer Peripheral Access Verification ---
        // ======================================================================
        $display("--------------------------------------------------");
        $display("Starting TEST 4: Timer Peripheral Configuration");
        $display("--------------------------------------------------");
        Timer_En = 1;

        // --- 4.A) Write to Timer Reload Register ---
        @(posedge HCLK);
        PADDR  = 32'h1000_0008; 
        PWRITE = 1;
        PVALID = 1;
        PBURST = 3'b000;
        PWDATA = 32'h0000_00FF; 

        @(posedge HCLK); while (!PREADY) @(posedge HCLK);
        PVALID = 0;
        PWRITE = 0;
        @(posedge HCLK); while (!PREADY) @(posedge HCLK); 

        #(CLK_PERIOD * 2);

        // --- 4.B) Read Back Timer Reload Register to Verify ---
        @(posedge HCLK);
        PADDR  = 32'h1000_0008;
        PWRITE = 0;
        PVALID = 1;

        @(posedge HCLK); while (!PREADY) @(posedge HCLK);
        PVALID = 0;
        @(posedge HCLK); while (!PREADY) @(posedge HCLK);
        
        #1;
        check_read(32'h0000_00FF, 1'b1, 1'b0);
        Timer_En = 0;


        // ======================================================================
        // Final Performance Report
        // ======================================================================
        #(CLK_PERIOD * 5);
        $display("==================================================");
        $display("Verification Finished!");
        $display("Correct Transactions: %0d", correct_count);
        $display("Error Transactions:   %0d", error_count);
        $display("==================================================");
        $finish;
    end

    // --------------------------------------------------------------------------
    // Verification Tasks
    // --------------------------------------------------------------------------
    
    task check_write(
        input logic [31:0] DATA_expected,
        input logic        PREADY_expected,
        input logic        PRESP_expected
    );
        begin
            if (PWDATA == DATA_expected && PREADY == PREADY_expected && PRESP == PRESP_expected) begin
                $display("[%0t] Write PASS: DATA=%h", $time, PWDATA);
                correct_count++;
            end else begin
                $display("[%0t] Write FAIL: DATA=%h (exp=%h)", $time, PWDATA, DATA_expected);
                $display("  PREADY: %0d (expected %0d)", PREADY, PREADY_expected);
                $display("  PRESP : %0d (expected %0d)", PRESP, PRESP_expected);
                error_count++;
            end
        end
    endtask

    task check_read(
    input logic [31:0] DATA_expected,
    input logic        PREADY_expected,
    input logic        PRESP_expected
);
begin
    if (PRDATA == DATA_expected &&
        PREADY == PREADY_expected &&
        PRESP == PRESP_expected)
    begin
        $display("[%0t] Read PASS: DATA=%h", $time, PRDATA);
        correct_count++;
    end
    else
    begin
        $display("[%0t] Read FAIL: DATA=%h (exp=%h)", $time, PRDATA, DATA_expected);
        $display("  PREADY: %0d (expected %0d)", PREADY, PREADY_expected);
        $display("  PRESP : %0d (expected %0d)", PRESP, PRESP_expected);
        error_count++;
    end
end
endtask

endmodule

/*`timescale 1ns/1ps

module AHB_lite_system_tb;

    // Parameters
    parameter CLK_PERIOD    = 10;
    parameter REG_WIDTH     = 8;
    parameter REG_DEPTH     = 32;
    parameter GPIO_WIDTH    = 8;
    parameter COUNTER_WIDTH = 32;

    // Signals declaration
    logic                       HCLK;
    logic                       HRESETn;
    logic  [31:0]               PADDR;
    logic                       PWRITE;
    logic  [1:0]                PSIZE;
    logic                       PVALID; 
    logic  [2:0]                PBURST;
    logic  [31:0]               PWDATA;
    
    logic  [GPIO_WIDTH-1:0]     GPIO_in_portA;      
    logic  [GPIO_WIDTH-1:0]     GPIO_in_portB;      
    logic  [GPIO_WIDTH-1:0]     GPIO_in_portC;      
    logic  [GPIO_WIDTH-1:0]     GPIO_in_portD;      
    
    logic                       Register_File_En;
    logic                       GPIO_En;
    logic                       Timer_En;

    logic                       PREADY;
    logic                       PRESP;
    logic  [31:0]               PRDATA;
    
    logic [GPIO_WIDTH-1:0]      GPIO_out_portA;     
    logic [GPIO_WIDTH-1:0]      GPIO_out_portB;     
    logic [GPIO_WIDTH-1:0]      GPIO_out_portC;     
    logic [GPIO_WIDTH-1:0]      GPIO_out_portD;

    // Performance tracking variables
    int correct_count = 0;
    int error_count   = 0;

    // --------------------------------------------------------------------------
    // Device Under Test (DUT) Instance
    // --------------------------------------------------------------------------
    AHB_lite_system #(
        .REG_WIDTH(REG_WIDTH),
        .REG_DEPTH(REG_DEPTH),
        .GPIO_WIDTH(GPIO_WIDTH),
        .COUNTER_WIDTH(COUNTER_WIDTH)
    ) dut (
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .PADDR(PADDR),
        .PWRITE(PWRITE),
        .PSIZE(PSIZE),
        .PVALID(PVALID), 
        .PBURST(PBURST),
        .PWDATA(PWDATA),
        .GPIO_in_portA(GPIO_in_portA),
        .GPIO_in_portB(GPIO_in_portB),
        .GPIO_in_portC(GPIO_in_portC),
        .GPIO_in_portD(GPIO_in_portD),
        .Register_File_En(Register_File_En),
        .GPIO_En(GPIO_En),
        .Timer_En(Timer_En),
        .PREADY(PREADY),
        .PRESP(PRESP),
        .PRDATA(PRDATA),
        .GPIO_out_portA(GPIO_out_portA),
        .GPIO_out_portB(GPIO_out_portB),
        .GPIO_out_portC(GPIO_out_portC),
        .GPIO_out_portD(GPIO_out_portD)
    );

    // Clock Generation
    always #(CLK_PERIOD/2) HCLK = ~HCLK;

    // --------------------------------------------------------------------------
    // Stimulus Generation
    // --------------------------------------------------------------------------
    initial begin
        // Initialize signals to default states
        HCLK             = 0;
        HRESETn          = 0;
        PADDR            = 0;
        PWRITE           = 0;
        PSIZE            = 2'b10;  // Default to Word size (4 Bytes)
        PVALID           = 0;      // Starts at IDLE state
        PBURST           = 3'b000; // SINGLE transfer type
        GPIO_in_portA    = 8'hA1;
        GPIO_in_portB    = 8'hB2;
        GPIO_in_portC    = 8'hC3;
        GPIO_in_portD    = 8'hD4;
        Register_File_En = 0;
        GPIO_En          = 0;
        Timer_En         = 0;

        // Reset Sequence
        #(CLK_PERIOD * 2);
        HRESETn = 1;
        #(CLK_PERIOD);

        $display("==================================================");
        $display("Starting AHB-Lite System Verification with PVALID");
        $display("==================================================");

        // ======================================================================
        // --- TEST 1: Write and Read from Register File ---
        // ======================================================================
        Register_File_En = 1;
        
        // --- 1.A) Write Operation (Address Phase) ---
        @(posedge HCLK);
        // FIX: Corrected base address to match Decoder MSB mapping (32'h2000_0000 instead of 32'h0020_0000)
        PADDR  = 32'h2000_0004; 
        PWRITE = 1;
        PWDATA = 32'hDEADBEEF;
        PVALID = 1;            
        PBURST = 3'b000;

        // Wait until Master accepts and drives the Address Phase on the bus
        @(posedge HCLK);
        while (!PREADY) @(posedge HCLK); 
        
        // Clear transaction controls (End of Address Phase request)
        PVALID = 0;            
        PWRITE = 0;

        // --- 1.B) Wait for Write Data Phase to Complete ---
        @(posedge HCLK);
        while (!PREADY) @(posedge HCLK);

        #(CLK_PERIOD * 2);

        // --- 1.C) Read Operation (Address Phase) ---
        @(posedge HCLK);
        PADDR  = 32'h2000_0004; // Same corrected address for reading
        PWRITE = 0;
        PVALID = 1;             

        // Wait for Master to latch the read command
        @(posedge HCLK);
        while (!PREADY) @(posedge HCLK);
        PVALID = 0; // Clear read request
        
        // --- 1.D) Read Data Phase ---
        // Advance clock to let the Slave complete the Data Phase and drive PRDATA
        @(posedge HCLK);
        while (!PREADY) @(posedge HCLK);
        
        // FIX: Added a #1 delay to avoid simulation race conditions before sampling the bus signals
        #1; 
        check_read(32'hDEADBEEF, 1'b1, 1'b0);
        Register_File_En = 0;


        // ======================================================================
        // --- TEST 2: Read from GPIO Input Port ---
        // ======================================================================
        GPIO_En = 1;
        
        // --- 2.A) Read Operation (Address Phase) ---
        @(posedge HCLK);
        PADDR  = 32'h0000_0000; // Port A input address (Matches GPIO Base)
        PWRITE = 0;
        PVALID = 1;

        // Wait for Master to latch the GPIO address phase
        @(posedge HCLK);
        while (!PREADY) @(posedge HCLK);
        PVALID = 0;

        // --- 2.B) Read Data Phase ---
        // Advance clock to wait for the Slave to process the Data Phase
        @(posedge HCLK);
        while (!PREADY) @(posedge HCLK);

        // FIX: Added a #1 delay for reliable data sampling stability
        #1; 
        check_read(32'h0000_00A1, 1'b1, 1'b0);
        GPIO_En = 0;

        // Final Performance Report
        #(CLK_PERIOD * 5);
        $display("==================================================");
        $display("Verification Finished!");
        $display("Correct Transactions: %0d", correct_count);
        $display("Error Transactions:   %0d", error_count);
        $display("==================================================");
        $finish;
    end

    // --------------------------------------------------------------------------
    // Verification Tasks
    // --------------------------------------------------------------------------
    
    // Task to verify Write Transactions
    task check_write(
        input logic [31:0] DATA_expected,
        input logic        PREADY_expected,
        input logic        PRESP_expected
    );
        begin
            if (PWDATA == DATA_expected && PREADY == PREADY_expected && PRESP == PRESP_expected) begin
                $display("[%0t] Write PASS: DATA=%h", $time, PWDATA);
                correct_count++;
            end else begin
                $display("[%0t] Write FAIL: DATA=%h (exp=%h)", $time, PWDATA, DATA_expected);
                $display("  PREADY: %0d (expected %0d)", PREADY, PREADY_expected);
                $display("  PRESP : %0d (expected %0d)", PRESP, PRESP_expected);
                error_count++;
            end
        end
    endtask

    // Task to verify Read Transactions
    task check_read(
        input logic [31:0] DATA_expected,
        input logic        PREADY_expected,
        input logic        PRESP_expected
    );
        begin
            if (PRDATA == DATA_expected && PREADY == PREADY_expected && PRESP == PRESP_expected) begin
                $display("[%0t] Read PASS: DATA=%h", $time, PRDATA);
                correct_count++;
            end else begin
                $display("[%0t] Read FAIL: DATA=%h (exp=%h)", $time, PRDATA, DATA_expected);
                $display("  PREADY: %0d (expected %0d)", PREADY, PREADY_expected);
                $display("  PRESP : %0d (expected %0d)", PRESP, PRESP_expected);
                error_count++;
            end
        end
    endtask

endmodule*/