`timescale 1ns/1ps

module analytics_engine (
    clk,
    rst_n,
    cycle_cnt,
    inst_ret_cnt,
    branch_cnt,
    load_cnt,
    store_cnt,
    fwd_cnt,
    raw_haz_cnt,
    load_haz_cnt,
    ctrl_haz_cnt,
    flush_cnt,
    bubble_cnt,
    if_active_cnt,
    id_active_cnt,
    ex_active_cnt,
    mem_active_cnt,
    wb_active_cnt,
    metric_ipc,
    metric_cpi,
    metric_pipe_eff,
    metric_util_if,
    metric_util_id,
    metric_util_ex,
    metric_util_mem,
    metric_util_wb,
    metric_fwd_eff,
    metric_haz_raw_dist,
    metric_haz_ldu_dist,
    metric_haz_ctrl_dist,
    metric_mem_ratio
);

    parameter G_COUNTER_WIDTH = 32;
    parameter G_METRIC_WIDTH  = 32;
    parameter G_ISSUE_WIDTH   = 1;   // Maximum instructions issued per cycle

    input  wire                       clk;
    input  wire                       rst_n;

    // Input Counters from Event Counter Module
    input  wire [G_COUNTER_WIDTH-1:0] cycle_cnt;
    input  wire [G_COUNTER_WIDTH-1:0] inst_ret_cnt;
    input  wire [G_COUNTER_WIDTH-1:0] branch_cnt;
    input  wire [G_COUNTER_WIDTH-1:0] load_cnt;
    input  wire [G_COUNTER_WIDTH-1:0] store_cnt;
    input  wire [G_COUNTER_WIDTH-1:0] fwd_cnt;
    input  wire [G_COUNTER_WIDTH-1:0] raw_haz_cnt;
    input  wire [G_COUNTER_WIDTH-1:0] load_haz_cnt;
    input  wire [G_COUNTER_WIDTH-1:0] ctrl_haz_cnt;
    input  wire [G_COUNTER_WIDTH-1:0] flush_cnt;
    input  wire [G_COUNTER_WIDTH-1:0] bubble_cnt;
    input  wire [G_COUNTER_WIDTH-1:0] if_active_cnt;
    input  wire [G_COUNTER_WIDTH-1:0] id_active_cnt;
    input  wire [G_COUNTER_WIDTH-1:0] ex_active_cnt;
    input  wire [G_COUNTER_WIDTH-1:0] mem_active_cnt;
    input  wire [G_COUNTER_WIDTH-1:0] wb_active_cnt;

    // Calculated Metrics (Scaled by 100 for precision, e.g., 1.25 -> 125)
    output reg  [G_METRIC_WIDTH-1:0]  metric_ipc;
    output reg  [G_METRIC_WIDTH-1:0]  metric_cpi;
    output reg  [G_METRIC_WIDTH-1:0]  metric_pipe_eff;
    
    // Pipeline Utilization %
    output reg  [G_METRIC_WIDTH-1:0]  metric_util_if;
    output reg  [G_METRIC_WIDTH-1:0]  metric_util_id;
    output reg  [G_METRIC_WIDTH-1:0]  metric_util_ex;
    output reg  [G_METRIC_WIDTH-1:0]  metric_util_mem;
    output reg  [G_METRIC_WIDTH-1:0]  metric_util_wb;

    // Efficiencies and Distributions %
    output reg  [G_METRIC_WIDTH-1:0]  metric_fwd_eff;
    output reg  [G_METRIC_WIDTH-1:0]  metric_haz_raw_dist;
    output reg  [G_METRIC_WIDTH-1:0]  metric_haz_ldu_dist;
    output reg  [G_METRIC_WIDTH-1:0]  metric_haz_ctrl_dist;
    output reg  [G_METRIC_WIDTH-1:0]  metric_mem_ratio;

    // Intermediate calculations with safe width expansion to prevent overflow (scaled by 100)
    // We add 8 bits of extra headroom to accommodate multiplying by 100
    wire [G_COUNTER_WIDTH-1:0] total_hazards = raw_haz_cnt + load_haz_cnt + ctrl_haz_cnt;
    wire [G_COUNTER_WIDTH-1:0] fwd_opportunities = fwd_cnt + raw_haz_cnt;
    wire [G_COUNTER_WIDTH-1:0] total_mem_ops = load_cnt + store_cnt;
    wire [G_COUNTER_WIDTH + 7 : 0] max_inst_possible = {8'b0, cycle_cnt} * G_ISSUE_WIDTH;

    wire [G_COUNTER_WIDTH + 7 : 0] ipc_scaled      = {8'b0, inst_ret_cnt} * 100;
    wire [G_COUNTER_WIDTH + 7 : 0] cpi_scaled      = {8'b0, cycle_cnt} * 100;
    wire [G_COUNTER_WIDTH + 7 : 0] pipe_eff_scaled = {8'b0, inst_ret_cnt} * 100;
    
    wire [G_COUNTER_WIDTH + 7 : 0] util_if_scaled  = {8'b0, if_active_cnt} * 100;
    wire [G_COUNTER_WIDTH + 7 : 0] util_id_scaled  = {8'b0, id_active_cnt} * 100;
    wire [G_COUNTER_WIDTH + 7 : 0] util_ex_scaled  = {8'b0, ex_active_cnt} * 100;
    wire [G_COUNTER_WIDTH + 7 : 0] util_mem_scaled = {8'b0, mem_active_cnt} * 100;
    wire [G_COUNTER_WIDTH + 7 : 0] util_wb_scaled  = {8'b0, wb_active_cnt} * 100;
    
    wire [G_COUNTER_WIDTH + 7 : 0] fwd_eff_scaled  = {8'b0, fwd_cnt} * 100;
    wire [G_COUNTER_WIDTH + 7 : 0] raw_dist_scaled = {8'b0, raw_haz_cnt} * 100;
    wire [G_COUNTER_WIDTH + 7 : 0] ldu_dist_scaled = {8'b0, load_haz_cnt} * 100;
    wire [G_COUNTER_WIDTH + 7 : 0] ctrl_dist_scaled= {8'b0, ctrl_haz_cnt} * 100;
    wire [G_COUNTER_WIDTH + 7 : 0] mem_ratio_scaled= {8'b0, total_mem_ops} * 100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            metric_ipc           <= {G_METRIC_WIDTH{1'b0}};
            metric_cpi           <= {G_METRIC_WIDTH{1'b0}};
            metric_pipe_eff      <= {G_METRIC_WIDTH{1'b0}};
            metric_util_if       <= {G_METRIC_WIDTH{1'b0}};
            metric_util_id       <= {G_METRIC_WIDTH{1'b0}};
            metric_util_ex       <= {G_METRIC_WIDTH{1'b0}};
            metric_util_mem      <= {G_METRIC_WIDTH{1'b0}};
            metric_util_wb       <= {G_METRIC_WIDTH{1'b0}};
            metric_fwd_eff       <= {G_METRIC_WIDTH{1'b0}};
            metric_haz_raw_dist  <= {G_METRIC_WIDTH{1'b0}};
            metric_haz_ldu_dist  <= {G_METRIC_WIDTH{1'b0}};
            metric_haz_ctrl_dist <= {G_METRIC_WIDTH{1'b0}};
            metric_mem_ratio     <= {G_METRIC_WIDTH{1'b0}};
        end else begin
            // 1. IPC = (Inst * 100) / Cycles
            if (cycle_cnt != 0) begin
                metric_ipc <= ipc_scaled / {8'b0, cycle_cnt};
            end else begin
                metric_ipc <= 0;
            end

            // 2. CPI = (Cycles * 100) / Inst
            if (inst_ret_cnt != 0) begin
                metric_cpi <= cpi_scaled / {8'b0, inst_ret_cnt};
            end else begin
                metric_cpi <= 0;
            end

            // 3. Pipeline Efficiency = (Inst * 100) / (Cycles * Issue_Width)
            if (max_inst_possible != 0) begin
                metric_pipe_eff <= pipe_eff_scaled / max_inst_possible;
            end else begin
                metric_pipe_eff <= 0;
            end

            // 4. Pipeline Utilization = (Stage_Active * 100) / Cycles
            if (cycle_cnt != 0) begin
                metric_util_if  <= util_if_scaled / {8'b0, cycle_cnt};
                metric_util_id  <= util_id_scaled / {8'b0, cycle_cnt};
                metric_util_ex  <= util_ex_scaled / {8'b0, cycle_cnt};
                metric_util_mem <= util_mem_scaled / {8'b0, cycle_cnt};
                metric_util_wb  <= util_wb_scaled / {8'b0, cycle_cnt};
            end else begin
                metric_util_if  <= 0;
                metric_util_id  <= 0;
                metric_util_ex  <= 0;
                metric_util_mem <= 0;
                metric_util_wb  <= 0;
            end

            // 5. Forward Efficiency = (Fwd * 100) / (Fwd + RAW_Stalls)
            if (fwd_opportunities != 0) begin
                metric_fwd_eff <= fwd_eff_scaled / {8'b0, fwd_opportunities};
            end else begin
                metric_fwd_eff <= 0;
            end

            // 6. Hazard Distribution = (Specific_Hazard * 100) / Total_Hazards
            if (total_hazards != 0) begin
                metric_haz_raw_dist  <= raw_dist_scaled / {8'b0, total_hazards};
                metric_haz_ldu_dist  <= ldu_dist_scaled / {8'b0, total_hazards};
                metric_haz_ctrl_dist <= ctrl_dist_scaled / {8'b0, total_hazards};
            end else begin
                metric_haz_raw_dist  <= 0;
                metric_haz_ldu_dist  <= 0;
                metric_haz_ctrl_dist <= 0;
            end

            // 7. Memory Ratio = ((Loads + Stores) * 100) / Inst_Ret
            if (inst_ret_cnt != 0) begin
                metric_mem_ratio <= mem_ratio_scaled / {8'b0, inst_ret_cnt};
            end else begin
                metric_mem_ratio <= 0;
            end
        end
    end

endmodule
