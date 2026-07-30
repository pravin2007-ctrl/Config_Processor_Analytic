`timescale 1ns/1ps

module tb_analytics_engine;

    // Parameters
    parameter G_COUNTER_WIDTH = 32;
    parameter G_METRIC_WIDTH  = 32;
    parameter G_ISSUE_WIDTH   = 1;

    // Inputs
    reg clk;
    reg rst_n;
    reg [G_COUNTER_WIDTH-1:0] cycle_cnt;
    reg [G_COUNTER_WIDTH-1:0] inst_ret_cnt;
    reg [G_COUNTER_WIDTH-1:0] branch_cnt;
    reg [G_COUNTER_WIDTH-1:0] load_cnt;
    reg [G_COUNTER_WIDTH-1:0] store_cnt;
    reg [G_COUNTER_WIDTH-1:0] fwd_cnt;
    reg [G_COUNTER_WIDTH-1:0] raw_haz_cnt;
    reg [G_COUNTER_WIDTH-1:0] load_haz_cnt;
    reg [G_COUNTER_WIDTH-1:0] ctrl_haz_cnt;
    reg [G_COUNTER_WIDTH-1:0] flush_cnt;
    reg [G_COUNTER_WIDTH-1:0] bubble_cnt;
    reg [G_COUNTER_WIDTH-1:0] if_active_cnt;
    reg [G_COUNTER_WIDTH-1:0] id_active_cnt;
    reg [G_COUNTER_WIDTH-1:0] ex_active_cnt;
    reg [G_COUNTER_WIDTH-1:0] mem_active_cnt;
    reg [G_COUNTER_WIDTH-1:0] wb_active_cnt;

    // Outputs
    wire [G_METRIC_WIDTH-1:0] metric_ipc;
    wire [G_METRIC_WIDTH-1:0] metric_cpi;
    wire [G_METRIC_WIDTH-1:0] metric_pipe_eff;
    wire [G_METRIC_WIDTH-1:0] metric_util_if;
    wire [G_METRIC_WIDTH-1:0] metric_util_id;
    wire [G_METRIC_WIDTH-1:0] metric_util_ex;
    wire [G_METRIC_WIDTH-1:0] metric_util_mem;
    wire [G_METRIC_WIDTH-1:0] metric_util_wb;
    wire [G_METRIC_WIDTH-1:0] metric_fwd_eff;
    wire [G_METRIC_WIDTH-1:0] metric_haz_raw_dist;
    wire [G_METRIC_WIDTH-1:0] metric_haz_ldu_dist;
    wire [G_METRIC_WIDTH-1:0] metric_haz_ctrl_dist;
    wire [G_METRIC_WIDTH-1:0] metric_mem_ratio;

    // Instantiate the Unit Under Test (UUT)
    analytics_engine #(
        G_COUNTER_WIDTH,
        G_METRIC_WIDTH,
        G_ISSUE_WIDTH
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .cycle_cnt(cycle_cnt),
        .inst_ret_cnt(inst_ret_cnt),
        .branch_cnt(branch_cnt),
        .load_cnt(load_cnt),
        .store_cnt(store_cnt),
        .fwd_cnt(fwd_cnt),
        .raw_haz_cnt(raw_haz_cnt),
        .load_haz_cnt(load_haz_cnt),
        .ctrl_haz_cnt(ctrl_haz_cnt),
        .flush_cnt(flush_cnt),
        .bubble_cnt(bubble_cnt),
        .if_active_cnt(if_active_cnt),
        .id_active_cnt(id_active_cnt),
        .ex_active_cnt(ex_active_cnt),
        .mem_active_cnt(mem_active_cnt),
        .wb_active_cnt(wb_active_cnt),
        .metric_ipc(metric_ipc),
        .metric_cpi(metric_cpi),
        .metric_pipe_eff(metric_pipe_eff),
        .metric_util_if(metric_util_if),
        .metric_util_id(metric_util_id),
        .metric_util_ex(metric_util_ex),
        .metric_util_mem(metric_util_mem),
        .metric_util_wb(metric_util_wb),
        .metric_fwd_eff(metric_fwd_eff),
        .metric_haz_raw_dist(metric_haz_raw_dist),
        .metric_haz_ldu_dist(metric_haz_ldu_dist),
        .metric_haz_ctrl_dist(metric_haz_ctrl_dist),
        .metric_mem_ratio(metric_mem_ratio)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        // Initialize Inputs
        clk = 0;
        rst_n = 0;
        
        cycle_cnt = 0;
        inst_ret_cnt = 0;
        branch_cnt = 0;
        load_cnt = 0;
        store_cnt = 0;
        fwd_cnt = 0;
        raw_haz_cnt = 0;
        load_haz_cnt = 0;
        ctrl_haz_cnt = 0;
        flush_cnt = 0;
        bubble_cnt = 0;
        if_active_cnt = 0;
        id_active_cnt = 0;
        ex_active_cnt = 0;
        mem_active_cnt = 0;
        wb_active_cnt = 0;

        // Reset
        #20 rst_n = 1;

        // Test Scenario 1: Typical Workload
        // Set counters to simulate a block of execution
        @(posedge clk);
        cycle_cnt = 1000;
        inst_ret_cnt = 850;
        branch_cnt = 100;
        load_cnt = 200;
        store_cnt = 50;
        fwd_cnt = 150;
        raw_haz_cnt = 50;
        load_haz_cnt = 20;
        ctrl_haz_cnt = 30; // Total hazards = 100
        flush_cnt = 30;
        bubble_cnt = 80;
        if_active_cnt = 950;
        id_active_cnt = 900;
        ex_active_cnt = 850;
        mem_active_cnt = 250; // Load/Store + extra stall cycles
        wb_active_cnt = 850;

        // Wait for calculation to register
        @(posedge clk);
        @(posedge clk);

        // Verify Results
        // IPC = (850 * 100) / 1000 = 85
        if (metric_ipc !== 85) $display("FAIL: IPC is %0d, expected 85", metric_ipc);
        else $display("PASS: IPC = %0d", metric_ipc);

        // CPI = (1000 * 100) / 850 = 117
        if (metric_cpi !== 117) $display("FAIL: CPI is %0d, expected 117", metric_cpi);
        else $display("PASS: CPI = %0d", metric_cpi);

        // Pipe Eff = (850 * 100) / (1000 * 1) = 85
        if (metric_pipe_eff !== 85) $display("FAIL: Pipe Eff is %0d, expected 85", metric_pipe_eff);
        else $display("PASS: Pipe Eff = %0d", metric_pipe_eff);

        // FWD Eff = (150 * 100) / (150 + 50) = 15000 / 200 = 75
        if (metric_fwd_eff !== 75) $display("FAIL: Fwd Eff is %0d, expected 75", metric_fwd_eff);
        else $display("PASS: Fwd Eff = %0d", metric_fwd_eff);

        // Hazard RAW Dist = (50 * 100) / 100 = 50
        if (metric_haz_raw_dist !== 50) $display("FAIL: RAW Dist is %0d, expected 50", metric_haz_raw_dist);
        else $display("PASS: RAW Dist = %0d", metric_haz_raw_dist);

        // Mem Ratio = ((200 + 50) * 100) / 850 = 25000 / 850 = 29
        if (metric_mem_ratio !== 29) $display("FAIL: Mem Ratio is %0d, expected 29", metric_mem_ratio);
        else $display("PASS: Mem Ratio = %0d", metric_mem_ratio);

        $display("Verification Complete.");
        $finish;
    end
endmodule
