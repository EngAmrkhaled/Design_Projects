// ==============================================================================
// Module Name: AHB_lite_system
// Description: Top-Level SoC System integrating Master, Decoder, Mux, and Slaves.
// Updated to use PVALID instead of PTRANS to match commercial Master design.
// ==============================================================================
module AHB_lite_system #(
    parameter REG_WIDTH = 8,
    parameter REG_DEPTH = 32,
    parameter GPIO_WIDTH = 8,
    parameter COUNTER_WIDTH = 32
)(
    input  logic                     HCLK,
    input  logic                     HRESETn,
    // Processor Signals
    input  logic [31:0]              PADDR,
    input  logic                     PWRITE,
    input  logic [1:0]               PSIZE,
    input  logic                     PVALID,   
    input  logic [2:0]               PBURST,
    input  logic [31:0]              PWDATA,
    // Subsystem I/O Ports
    input  logic [GPIO_WIDTH-1:0]    GPIO_in_portA,      
    input  logic [GPIO_WIDTH-1:0]    GPIO_in_portB,      
    input  logic [GPIO_WIDTH-1:0]    GPIO_in_portC,      
    input  logic [GPIO_WIDTH-1:0]    GPIO_in_portD,      
    input  logic                     Register_File_En,
    input  logic                     GPIO_En,
    input  logic                     Timer_En,

    output logic                     PREADY,
    output logic                     PRESP,
    output logic [31:0]              PRDATA,
    output logic [GPIO_WIDTH-1:0]    GPIO_out_portA,     
    output logic [GPIO_WIDTH-1:0]    GPIO_out_portB,     
    output logic [GPIO_WIDTH-1:0]    GPIO_out_portC,     
    output logic [GPIO_WIDTH-1:0]    GPIO_out_portD    
);

    // Synchronized Reset wire
    logic rst_n;

    // Internal AHB Bus Signals
    logic [31:0] HADDR;
    logic [31:0] HWDATA;
    logic        HWRITE;
    logic [1:0]  HSIZE;
    logic [1:0]  HTRANS;
    logic [2:0]  HBURST;
    logic        HREADY;
    logic        HRESP;
    logic [31:0] HRDATA;

    // Decoder Select Lines
    logic        HSEL_G;
    logic        HSEL_T;
    logic        HSEL_R;

    // Slave Outputs to Multiplexer
    logic [31:0] HRDATA_G, HRDATA_T, HRDATA_R;
    logic        HREADY_G, HREADY_T, HREADY_R;
    logic        HRESP_G, HRESP_T, HRESP_R;

    // Peripheral Internal Control Wires
    logic        gpio_we, gpio_re;
    logic [31:0] Addr_G;
    logic [1:0]  size_G;
    logic [31:0] wd_data_G;
    logic [31:0] gpio_rd_data;

    logic        timer_we, timer_re;
    logic [31:0] Addr_T;
    logic [1:0]  size_T;
    logic [31:0] wd_data_T;
    logic [31:0] timer_rd_data;
    logic        timer_ready;
    logic        timer_response;

    logic        reg_we, reg_re;
    logic [31:0] Addr_R;
    logic [1:0]  size_R;
    logic [31:0] wd_data_R;
    logic [31:0] reg_rd_data;
    logic        reg_ready;
    logic        reg_response;

    // --------------------------------------------------------------------------
    // Reset Synchronizer Instance
    // --------------------------------------------------------------------------
    Rst_sync rst_sync_inst (
        .clk(HCLK),
        .async_rst_n(HRESETn),
        .sync_rst_n(rst_n)
    );

    // --------------------------------------------------------------------------
    // AHB-Lite Master Instance
    // --------------------------------------------------------------------------
    AHB_lite_master master_inst (
        .HCLK(HCLK),
        .HRESETn(rst_n),
        .PVALID(PVALID),   
        .PADDR(PADDR),
        .PWDATA(PWDATA),
        .PWRITE(PWRITE),
        .PSIZE(PSIZE),
        .PBURST(PBURST),
        .PRDATA(PRDATA),
        .PREADY(PREADY),
        .PRESP(PRESP),
        .HADDR(HADDR),
        .HWDATA(HWDATA),
        .HWRITE(HWRITE),
        .HSIZE(HSIZE),
        .HTRANS(HTRANS),
        .HBURST(HBURST),
        .HREADY(HREADY),
        .HRESP(HRESP),
        .HRDATA(HRDATA)
    );

    // --------------------------------------------------------------------------
    // Address Decoder Instance
    // --------------------------------------------------------------------------
    Decoder decoder_inst (
        .HADDR(HADDR),
        .HSEL_G(HSEL_G),
        .HSEL_T(HSEL_T),
        .HSEL_R(HSEL_R)
    );

    // --------------------------------------------------------------------------
    // GPIO Slave Subsystem
    // --------------------------------------------------------------------------
    AHB_slave_if AHB_GPIO_Interface_block (
        .HCLK(HCLK), .HRESETn(rst_n), .HADDR(HADDR), .HWRITE(HWRITE), .HSIZE(HSIZE),
        .HTRANS(HTRANS), .HWDATA(HWDATA), .HSEL_P(HSEL_G), .HREADY(HREADY),
        .peripheral_rd_data(gpio_rd_data), .peripheral_ready(1'b1), .peripheral_response(1'b0),
        .HRDATA_P(HRDATA_G), .HREADY_P(HREADY_G), .HRESP_P(HRESP_G),
        .peripheral_we(gpio_we), .peripheral_re(gpio_re), .Addr(Addr_G), .size(size_G), .wd_data(wd_data_G)
    );

    GPIO #(.GPIO_WIDTH(GPIO_WIDTH)) GPIO_slave (
        .clk(HCLK), .rst_n(rst_n), .en(GPIO_En), .Addr(Addr_G[2:0]), .size(size_G),
        .we(gpio_we), .re(gpio_re), .wd_data(wd_data_G),
        .GPIO_in_portA(GPIO_in_portA), .GPIO_in_portB(GPIO_in_portB),
        .GPIO_in_portC(GPIO_in_portC), .GPIO_in_portD(GPIO_in_portD),
        .rd_data(gpio_rd_data),
        .GPIO_out_portA(GPIO_out_portA), .GPIO_out_portB(GPIO_out_portB),
        .GPIO_out_portC(GPIO_out_portC), .GPIO_out_portD(GPIO_out_portD)
    );

    // --------------------------------------------------------------------------
    // Timer Slave Subsystem
    // --------------------------------------------------------------------------
    AHB_slave_if AHB_Timer_Interface_block (
        .HCLK(HCLK), .HRESETn(rst_n), .HADDR(HADDR), .HWRITE(HWRITE), .HSIZE(HSIZE),
        .HTRANS(HTRANS), .HWDATA(HWDATA), .HSEL_P(HSEL_T), .HREADY(HREADY),
        .peripheral_rd_data(timer_rd_data), .peripheral_ready(timer_ready),
        .peripheral_response(timer_response), .HRDATA_P(HRDATA_T),
        .HREADY_P(HREADY_T), .HRESP_P(HRESP_T), .peripheral_we(timer_we),
        .peripheral_re(timer_re), .Addr(Addr_T), .size(size_T), .wd_data(wd_data_T)      
    );

    Timer #(.COUNTER_WIDTH(COUNTER_WIDTH)) Timer_slave (
        .clk(HCLK), .rst_n(rst_n), .en(Timer_En), .Addr(Addr_T[1:0]), .size(size_T),
        .we(timer_we), .re(timer_re), .load(wd_data_T[COUNTER_WIDTH-1:0]),
        .counter_value(timer_rd_data[COUNTER_WIDTH-1:0]), .done(timer_ready), .check(timer_response)
    );

    // --------------------------------------------------------------------------
    // Register File Slave Subsystem
    // --------------------------------------------------------------------------
    AHB_slave_if AHB_Register_File_Interface_block (
        .HCLK(HCLK), .HRESETn(rst_n), .HADDR(HADDR), .HWRITE(HWRITE), .HSIZE(HSIZE),
        .HTRANS(HTRANS), .HWDATA(HWDATA), .HSEL_P(HSEL_R), .HREADY(HREADY),
        .peripheral_rd_data(reg_rd_data), .peripheral_ready(reg_ready),
        .peripheral_response(reg_response), .HRDATA_P(HRDATA_R),
        .HREADY_P(HREADY_R), .HRESP_P(HRESP_R), .peripheral_we(reg_we),
        .peripheral_re(reg_re), .Addr(Addr_R), .size(size_R), .wd_data(wd_data_R)      
    );

    Register_File #(.REG_WIDTH(REG_WIDTH), .REG_DEPTH(REG_DEPTH)) Register_File_slave (
        .clk(HCLK), .rst_n(rst_n), .en(Register_File_En), .Addr(Addr_R[$clog2(REG_DEPTH)-1:0]), .size(size_R),
        .we(reg_we), .re(reg_re), .wd_data(wd_data_R), .rd_data(reg_rd_data), .done(reg_ready), .check(reg_response)
    );

    // --------------------------------------------------------------------------
    // AHB Multiplexer Instance
    // --------------------------------------------------------------------------
    Mux AHB_Multiplexer_block (
        .clk(HCLK),
        .rst_n(rst_n),
        .HSEL_G(HSEL_G),
        .HSEL_T(HSEL_T),
        .HSEL_R(HSEL_R),
        .HRDATA_G(HRDATA_G),
        .HRDATA_T(HRDATA_T),
        .HRDATA_R(HRDATA_R),
        .HREADY_G(HREADY_G),
        .HREADY_T(HREADY_T),
        .HREADY_R(HREADY_R),
        .HRESP_G(HRESP_G),
        .HRESP_T(HRESP_T),
        .HRESP_R(HRESP_R),
        .HRDATA(HRDATA),
        .HREADY(HREADY),
        .HRESP(HRESP)
    );

endmodule