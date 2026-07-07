// ==============================================================================
// Module Name: AHB_lite_master (Commercial-Grade RTL)
// Description: Industry-standard AHB-Lite Master.
//              - Auto-generates HTRANS based on Burst type.
//              - Uses PVALID instead of passing PTRANS from processor.
//              - Clean control and data path separation.
// ==============================================================================
module AHB_lite_master (
    input  logic        HCLK,
    input  logic        HRESETn,
    
    // Processor Interface (Standard Custom Interface)
    input  logic        PVALID,   // High when Processor requests a transfer
    input  logic [31:0] PADDR,
    input  logic [31:0] PWDATA,
    input  logic        PWRITE,
    input  logic [1:0]  PSIZE,
    input  logic [2:0]  PBURST,
    
    output logic [31:0] PRDATA,
    output logic        PREADY,
    output logic        PRESP,
    
    // AHB-Lite Bus Interface
    output logic [31:0] HADDR,
    output logic [31:0] HWDATA,
    output logic        HWRITE,
    output logic [1:0]  HSIZE,
    output logic [1:0]  HTRANS,
    output logic [2:0]  HBURST,
    
    input  logic        HREADY,
    input  logic        HRESP,
    input  logic [31:0] HRDATA
);

    // Encode FSM states to directly match HTRANS values for optimal synthesis
    typedef enum logic [1:0] {
        ST_IDLE   = 2'b00, 
        ST_BUSY   = 2'b01, 
        ST_NONSEQ = 2'b10, 
        ST_SEQ    = 2'b11
    } state_t;

    state_t state_q, state_d;
    
    logic [4:0]  beat_cnt_q, beat_cnt_d;
    logic [4:0]  burst_length;
    logic [31:0] next_addr;
    logic [31:0] wrap_mask;
    logic [31:0] beat_size;

    // --------------------------------------------------------------------------
    // 1. Burst Decoder & Address Masking (Combinational)
    // --------------------------------------------------------------------------
    assign beat_size = 32'd1 << PSIZE; // 00 -> 1 Byte, 01 -> 2 Bytes, 10 -> 4 Bytes

// -----------------------------------------------------------------------------
// PBURST Encoding:
// 000 : SINGLE  -> Single transfer
// 001 : INCR    -> Incrementing burst of undefined length
// 010 : WRAP4   -> 4-beat wrapping burst
// 011 : INCR4   -> 4-beat incrementing burst
// 100 : WRAP8   -> 8-beat wrapping burst
// 101 : INCR8   -> 8-beat incrementing burst
// 110 : WRAP16  -> 16-beat wrapping burst
// 111 : INCR16  -> 16-beat incrementing burst
// -----------------------------------------------------------------------------
    always_comb begin
        case (PBURST)
            3'b010, 3'b011: burst_length = 5'd4;   // 4-beat burst
            3'b100, 3'b101: burst_length = 5'd8;   // 8-beat burst
            3'b110, 3'b111: burst_length = 5'd16;  // 16-beat burst
            default:        burst_length = 5'd1;   // SINGLE transfer (or undefined)
        endcase
    end

    always_comb begin
        case (PBURST)
            3'b010:  wrap_mask = (4  * beat_size) - 1; // Wrap boundary for WRAP4
            3'b100:  wrap_mask = (8  * beat_size) - 1; // Wrap boundary for WRAP8
            3'b110:  wrap_mask = (16 * beat_size) - 1; // Wrap boundary for WRAP16
            default: wrap_mask = 32'hFFFFFFFF;         // No wrapping for INCR/SINGLE
        endcase
    end

    // --------------------------------------------------------------------------
    // 2. Control Path FSM (Next State Logic)
    // --------------------------------------------------------------------------
    always_comb begin
        state_d    = state_q;
        beat_cnt_d = beat_cnt_q;

        case (state_q)
            ST_IDLE: begin
                if (PVALID) begin
                    state_d    = ST_NONSEQ; // Start a new transaction
                    beat_cnt_d = 5'd1;
                end
            end
            
            ST_NONSEQ, ST_SEQ: begin
                if (HREADY) begin
                    if (beat_cnt_q < burst_length) begin
                        // Continue current burst transaction
                        state_d    = ST_SEQ;
                        beat_cnt_d = beat_cnt_q + 5'd1;
                    end else begin
                        // Burst complete, check for back-to-back request
                        if (PVALID) begin
                            state_d    = ST_NONSEQ; 
                            beat_cnt_d = 5'd1;
                        end else begin
                            state_d    = ST_IDLE;
                        end
                    end
                end
            end
            
            default: state_d = ST_IDLE;
        endcase
    end

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            state_q    <= ST_IDLE;
            beat_cnt_q <= 5'd0;
        end else if (HREADY) begin
            state_q    <= state_d;
            beat_cnt_q <= beat_cnt_d;
        end
    end

    // Direct mapping of state to HTRANS (Glitch-free as it comes from FF)
    assign HTRANS = state_q;

    // --------------------------------------------------------------------------
    // 3. Address & Control Output Logic (Address Phase)
    // --------------------------------------------------------------------------
    always_comb begin
        if (state_q == ST_IDLE) begin
            next_addr = PADDR; // Sample new start address ONLY when IDLE
        end else begin
            // Calculate next address for SEQUENTIAL (SEQ) beats inside the burst
            if (PBURST[0] == 1'b1 || PBURST == 3'b000) begin // INCR or SINGLE
                next_addr = HADDR + beat_size;
            end else begin                                   // WRAP
                next_addr = (HADDR & ~wrap_mask) | ((HADDR + beat_size) & wrap_mask);
            end
        end
    end

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            HADDR  <= 32'b0;
            HWRITE <= 1'b0;
            HSIZE  <= 2'b00;
            HBURST <= 3'b000;
        end else if (HREADY) begin
            if (state_d != ST_IDLE) begin
                HADDR  <= next_addr;
                HWRITE <= PWRITE;
                HSIZE  <= PSIZE;
                HBURST <= PBURST;
            end
        end
    end

    // --------------------------------------------------------------------------
    // 4. Data Path (Data Phase)
    // --------------------------------------------------------------------------
    // Two-stage pipeline registers for PWDATA to align precisely with AHB Data Phase
    logic [31:0] PWDATA_q;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            PWDATA_q <= 32'b0;
            HWDATA   <= 32'b0;
        end else if (HREADY) begin
            PWDATA_q <= PWDATA;    // Stage 1: Capture processor data
            HWDATA   <= PWDATA_q;  // Stage 2: Drive data to bus (delayed by 1 cycle relative to address)
        end
    end

    // --------------------------------------------------------------------------
    // 5. Processor Handshake Signals
    // --------------------------------------------------------------------------
    assign PREADY = HREADY;
    assign PRESP  = HRESP;
    
    // Gate PRDATA (Saves power by preventing toggling during writes or bus stalls)
    assign PRDATA = (HREADY && !HWRITE) ? HRDATA : 32'b0;

endmodule