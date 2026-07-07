// ==============================================================================
// Module Name: Timer
// Description: Multi-mode hardware timer/counter.
// ==============================================================================
module Timer #(
    parameter COUNTER_WIDTH = 32
)(
    input                               clk,
    input                               rst_n,
    input                               en,                 
    input       [1:0]                   Addr,               
    input                               we,                 
    input                               re,  
    input       [COUNTER_WIDTH-1:0]     load,                   
    input       [1:0]                   size,

    output logic [COUNTER_WIDTH-1:0]    counter_value,      
    output logic                        done,               
    output logic                        check               
);

    typedef enum logic [2:0] {
        MODE_IDLE = 3'b000, MODE_UP = 3'b001, MODE_DOWN = 3'b010, 
        MODE_FREE_RUN = 3'b011, MODE_PERIODIC = 3'b100, MODE_UP_DOWN = 3'b101
    } mode_t;

    logic [COUNTER_WIDTH-1:0] counter_reg, reload_reg;
    logic finish_flag, dir;
    mode_t mode;

    assign done = 1'b1; // Always ready

    // Sequential Logic: Modes & Counter updates
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter_reg <= '0;
            reload_reg  <= '0;
            mode        <= MODE_IDLE;
            finish_flag <= 1'b0;
            dir         <= 1'b1; // 1 means UP, 0 means DOWN
        end else if (en && we) begin
            case (Addr)
                2'b00: counter_reg <= load;
                2'b01: mode        <= mode_t'(load[2:0]);
                2'b10: reload_reg  <= load;
            endcase
            finish_flag <= 1'b0; // Clear flag on config write
        end else if (en) begin
            case (mode)
                MODE_UP: begin
                    if (counter_reg < reload_reg) counter_reg <= counter_reg + 1;
                    else finish_flag <= 1'b1;
                end
                MODE_DOWN: begin
                    if (counter_reg > 0) counter_reg <= counter_reg - 1;
                    else finish_flag <= 1'b1;
                end
                MODE_PERIODIC: begin
                    if (counter_reg > 0) counter_reg <= counter_reg - 1;
                    else begin
                        counter_reg <= reload_reg; // Auto-reload
                        finish_flag <= 1'b1;
                    end
                end
                MODE_FREE_RUN: counter_reg <= counter_reg + 1; // Overflows naturally
                
                // ===== The Ping-Pong Mode Logic =====
                MODE_UP_DOWN: begin
                    if (dir == 1'b1) begin // Counting UP
                        if (counter_reg < reload_reg) 
                            counter_reg <= counter_reg + 1;
                        else begin
                            dir <= 1'b0; // Switch direction to DOWN
                            counter_reg <= counter_reg - 1;
                        end
                    end else begin         // Counting DOWN
                        if (counter_reg > 0) 
                            counter_reg <= counter_reg - 1;
                        else begin
                            dir <= 1'b1; // Switch direction to UP
                            counter_reg <= counter_reg + 1;
                            finish_flag <= 1'b1;
                        end
                    end
                end
                // ============================================
            endcase
        end
    end

    // Combinational Logic: Register Read
    always_comb begin
        counter_value = '0;
        if (en && re) begin
            case (Addr)
                2'b00: counter_value = counter_reg;
                2'b01: counter_value = {{(COUNTER_WIDTH-3){1'b0}}, mode};
                2'b10: counter_value = reload_reg;
                2'b11: counter_value = {{(COUNTER_WIDTH-1){1'b0}}, finish_flag};
            endcase
        end
    end

    // Error generation (HRESP)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            check <= 1'b0;
        else 
            // Trigger ERROR if trying to write to read-only finish_flag address
            check <= (en && we && Addr == 2'b11);
    end

endmodule