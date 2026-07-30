// =============================================================================
// Company:        ASIC soft IP
// Engineer:       Senior ASIC Architect
// 
// Create Date:    July 15, 2026
// Design Name:    Configurable Processor Analytics Soft IP
// Module Name:    event_counter
// Project Name:   Configurable Processor Analytics Soft IP
// Target Devices: ASIC / FPGA
// Tool Versions:  Synthesizable Verilog-2001
// Description:    Accumulator bank containing 18 parameterized counters.
//                 Supports saturation (no roll-over) and multi-issue retire logic.
//
// Dependencies:   None
// =============================================================================

`timescale 1ns / 1ps

module event_counter (
    probe_clk,
    probe_rst_n,
    cnt_en,
    cnt_clear,
    saturate_en,
    ev_inst_retired,
    ev_branch_retired,
    ev_load_retired,
    ev_store_retired,
    ev_raw_hazard_cycle,
    ev_ldu_hazard_cycle,
    ev_ctrl_hazard_cycle,
    ev_stall_cycle,
    ev_bubble_cycle,
    ev_flush_event,
    ev_fwd_opp,
    ev_fwd_success,
    ev_if_active_cycle,
    ev_id_active_cycle,
    ev_ex_active_cycle,
    ev_mem_active_cycle,
    ev_wb_active_cycle,
    cycle_cnt,
    inst_ret_cnt,
    branch_cnt,
    load_cnt,
    store_cnt,
    raw_haz_cnt,
    ldu_haz_cnt,
    ctrl_haz_cnt,
    stall_cnt,
    bubble_cnt,
    flush_cnt,
    fwd_opp_cnt,
    fwd_succ_cnt,
    if_active_cnt,
    id_active_cnt,
    ex_active_cnt,
    mem_active_cnt,
    wb_active_cnt
);

    parameter G_COUNTER_WIDTH = 48;
    parameter G_ISSUE_WIDTH   = 1;

    // Clocks & Resets
    input  wire                         probe_clk;
    input  wire                         probe_rst_n;

    // Gating Control
    input  wire                         cnt_en;
    input  wire                         cnt_clear;
    input  wire                         saturate_en;

    // Events from Event Collector
    input  wire [G_ISSUE_WIDTH-1:0]     ev_inst_retired;
    input  wire                         ev_branch_retired;
    input  wire                         ev_load_retired;
    input  wire                         ev_store_retired;
    input  wire                         ev_raw_hazard_cycle;
    input  wire                         ev_ldu_hazard_cycle;
    input  wire                         ev_ctrl_hazard_cycle;
    input  wire                         ev_stall_cycle;
    input  wire                         ev_bubble_cycle;
    input  wire                         ev_flush_event;
    input  wire                         ev_fwd_opp;
    input  wire                         ev_fwd_success;
    input  wire                         ev_if_active_cycle;
    input  wire                         ev_id_active_cycle;
    input  wire                         ev_ex_active_cycle;
    input  wire                         ev_mem_active_cycle;
    input  wire                         ev_wb_active_cycle;

    // Outputs to shadow bank / engine
    output reg  [G_COUNTER_WIDTH-1:0]   cycle_cnt;
    output reg  [G_COUNTER_WIDTH-1:0]   inst_ret_cnt;
    output reg  [G_COUNTER_WIDTH-1:0]   branch_cnt;
    output reg  [G_COUNTER_WIDTH-1:0]   load_cnt;
    output reg  [G_COUNTER_WIDTH-1:0]   store_cnt;
    output reg  [G_COUNTER_WIDTH-1:0]   raw_haz_cnt;
    output reg  [G_COUNTER_WIDTH-1:0]   ldu_haz_cnt;
    output reg  [G_COUNTER_WIDTH-1:0]   ctrl_haz_cnt;
    output reg  [G_COUNTER_WIDTH-1:0]   stall_cnt;
    output reg  [G_COUNTER_WIDTH-1:0]   bubble_cnt;
    output reg  [G_COUNTER_WIDTH-1:0]   flush_cnt;
    output reg  [G_COUNTER_WIDTH-1:0]   fwd_opp_cnt;
    output reg  [G_COUNTER_WIDTH-1:0]   fwd_succ_cnt;
    output reg  [G_COUNTER_WIDTH-1:0]   if_active_cnt;
    output reg  [G_COUNTER_WIDTH-1:0]   id_active_cnt;
    output reg  [G_COUNTER_WIDTH-1:0]   ex_active_cnt;
    output reg  [G_COUNTER_WIDTH-1:0]   mem_active_cnt;
    output reg  [G_COUNTER_WIDTH-1:0]   wb_active_cnt;

    // Constant definition for maximum counter value
    wire [G_COUNTER_WIDTH-1:0] max_count = {G_COUNTER_WIDTH{1'b1}};

    // =========================================================================
    // 1. Multi-Issue Instruction Retirement Accumulation
    // =========================================================================
    reg [G_ISSUE_WIDTH:0] retired_sum;
    integer i;
    always @(ev_inst_retired) begin
        retired_sum = 0;
        for (i = 0; i < G_ISSUE_WIDTH; i = i + 1) begin
            if (ev_inst_retired[i]) begin
                retired_sum = retired_sum + 1;
            end
        end
    end

    // Helper macro/function for simple counter increment logic with saturation
    // To maintain compliance with standard Verilog-2001 synthesizability,
    // we implement independent always blocks for clean register mapping.

    // 1. Cycle Counter
    always @(posedge probe_clk or negedge probe_rst_n) begin
        if (!probe_rst_n) begin
            cycle_cnt <= {G_COUNTER_WIDTH{1'b0}};
        end else if (cnt_clear) begin
            cycle_cnt <= {G_COUNTER_WIDTH{1'b0}};
        end else if (cnt_en) begin
            if (saturate_en && (cycle_cnt == max_count)) begin
                cycle_cnt <= max_count;
            end else begin
                cycle_cnt <= cycle_cnt + 1'b1;
            end
        end
    end

    // 2. Retired Instructions Counter
    always @(posedge probe_clk or negedge probe_rst_n) begin
        if (!probe_rst_n) begin
            inst_ret_cnt <= {G_COUNTER_WIDTH{1'b0}};
        end else if (cnt_clear) begin
            inst_ret_cnt <= {G_COUNTER_WIDTH{1'b0}};
        end else if (cnt_en && (|ev_inst_retired)) begin
            if (saturate_en && (inst_ret_cnt >= max_count - retired_sum)) begin
                inst_ret_cnt <= max_count;
            end else begin
                inst_ret_cnt <= inst_ret_cnt + retired_sum;
            end
        end
    end

    // Helper macro for single-bit event counters
    `define DEFINE_COUNTER(signal, register) \
    always @(posedge probe_clk or negedge probe_rst_n) begin \
        if (!probe_rst_n) begin \
            register <= {G_COUNTER_WIDTH{1'b0}}; \
        end else if (cnt_clear) begin \
            register <= {G_COUNTER_WIDTH{1'b0}}; \
        end else if (cnt_en && signal) begin \
            if (saturate_en && (register == max_count)) begin \
                register <= max_count; \
            end else begin \
                register <= register + 1'b1; \
            end \
        end \
    end

    // Instantiating standard counters using macro
    `DEFINE_COUNTER(ev_branch_retired,    branch_cnt)
    `DEFINE_COUNTER(ev_load_retired,      load_cnt)
    `DEFINE_COUNTER(ev_store_retired,     store_cnt)
    `DEFINE_COUNTER(ev_raw_hazard_cycle,  raw_haz_cnt)
    `DEFINE_COUNTER(ev_ldu_hazard_cycle,  ldu_haz_cnt)
    `DEFINE_COUNTER(ev_ctrl_hazard_cycle, ctrl_haz_cnt)
    `DEFINE_COUNTER(ev_stall_cycle,       stall_cnt)
    `DEFINE_COUNTER(ev_bubble_cycle,      bubble_cnt)
    `DEFINE_COUNTER(ev_flush_event,       flush_cnt)
    `DEFINE_COUNTER(ev_fwd_opp,           fwd_opp_cnt)
    `DEFINE_COUNTER(ev_fwd_success,       fwd_succ_cnt)
    `DEFINE_COUNTER(ev_if_active_cycle,   if_active_cnt)
    `DEFINE_COUNTER(ev_id_active_cycle,   id_active_cnt)
    `DEFINE_COUNTER(ev_ex_active_cycle,   ex_active_cnt)
    `DEFINE_COUNTER(ev_mem_active_cycle,  mem_active_cnt)
    `DEFINE_COUNTER(ev_wb_active_cycle,   wb_active_cnt)

    // Clean up macro definition
    `undef DEFINE_COUNTER

endmodule
