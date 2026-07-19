`timescale 1ns / 1ps

module tb_weighted_ma_filter;

    // Parameters
    parameter DATA_WIDTH = 16;
    
    // Testbench Signals
    logic clk;
    logic rst_n;
    logic valid_in;
    logic signed [DATA_WIDTH-1:0] x_in;
    logic valid_out;
    logic signed [DATA_WIDTH-1:0] y_out;

    // File handles 
    integer fd_in, fd_out, fd_ref, scan_file, scan_ref;
    logic signed [DATA_WIDTH-1:0] expected_y;
    integer error_count = 0;

    weighted_ma_filter #(
        .DATA_WIDTH(DATA_WIDTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .x_in(x_in),
        .valid_out(valid_out),
        .y_out(y_out)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        valid_in = 0;
        x_in = 0;

        fd_in = $fopen("input_stimulus.txt", "r");
        fd_out = $fopen("rtl_output.txt", "w");
        fd_ref = $fopen("reference_output.txt", "r");

        if (fd_in == 0) begin
            $display("WARNING: input_stimulus.txt not found! Applying manual impulse test instead.");
        end
        if (fd_ref == 0) begin
            $display("WARNING: reference_output.txt not found! Automatic comparison will be skipped.");
        end

        // Reset the system
        #20;
        rst_n = 1;
        #10;

        // Read from file and apply to UUT
        if (fd_in != 0) begin
            while (!$feof(fd_in)) begin
                @(posedge clk);
                scan_file = $fscanf(fd_in, "%d\n", x_in);
                valid_in = 1;
            end
            // Clear valid_in when file ends
            @(posedge clk);
            valid_in = 0;
            
        end else begin
            // --- Fallback Manual Test (Impulse Response) ---
            // Expected Output: 1000, 500, 250, 125, 0, 0...
            @(posedge clk);
            valid_in = 1; x_in = 16'd1000;
            @(posedge clk);
            valid_in = 1; x_in = 16'd0;
            @(posedge clk);
            valid_in = 1; x_in = 16'd0;
            @(posedge clk);
            valid_in = 1; x_in = 16'd0;
            @(posedge clk);
            valid_in = 0;
        end

        #100;
        
        if (fd_in != 0)  $fclose(fd_in);
        if (fd_out != 0) $fclose(fd_out);
        if (fd_ref != 0) $fclose(fd_ref);
        
        if (error_count == 0 && fd_ref != 0) begin
            $display("========================================");
            $display("SUCCESS: All outputs match the reference!");
            $display("========================================");
        end else if (fd_ref != 0) begin
            $display("========================================");
            $display("FAILED: Found %d mismatches.", error_count);
            $display("========================================");
        end
        
        $display("Simulation Complete.");
        $finish;
    end

    // Process to write outputs to a file whenever valid_out is high
    always @(posedge clk) begin
        if (valid_out) begin
            if (fd_out != 0) begin
                $fwrite(fd_out, "%d\n", y_out);
            end
            
            // Automatic self-checking against reference file
            if (fd_ref != 0 && !$feof(fd_ref)) begin
                scan_ref = $fscanf(fd_ref, "%d\n", expected_y);
                if (y_out !== expected_y) begin
                    $display("TIME: %0t | ERROR: Expected %d, Got %d", $time, expected_y, y_out);
                    error_count = error_count + 1;
                end else begin
                    $display("TIME: %0t | MATCH: Output %d", $time, y_out);
                end
            end
        end
    end

endmodule