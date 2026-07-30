`timescale 1ns/1ps

module analytics_top (
    probe_clk,
    probe_rst_n,
    ctrl_en,
    cnt_clear,
    mode_select,
    priv_filter,
    context_filter,
    context_filter_en,
    probe_instruction_commit,
    probe_opcode,
    probe_stall,
    probe_flush,
    probe_raw_hazard,
    probe_load_hazard,
    probe_control_hazard,
    probe_mem_read,
    probe_mem_write,
    probe_if_valid,
    probe_if_stall,
    probe_id_valid,
    probe_id_stall,
    probe_id_bubble,
    probe_ex_valid,
    probe_ex_stall,
    probe_mem_valid,
    probe_mem_stall,
    probe_wb_valid,
    probe_wb_stall,
    probe_fwd_opp,
    probe_fwd_success,
    probe_execution_done,
    probe_priv_mode,
    probe_context_id,
    read_addr,
    read_en,
    read_data,
    read_valid
);

    parameter G_OPCODE_WIDTH  = 32;
    parameter G_ISSUE_WIDTH   = 1;
    parameter G_PRIV_WIDTH    = 2;
    parameter G_CONTEXT_WIDTH = 8;
    parameter G_COUNTER_WIDTH = 32;
    parameter G_ADDR_WIDTH    = 8;

    // Clocks and Resets
    input  wire                         probe_clk;
    input  wire                         probe_rst_n;

    // Gating and Mode Control
    input  wire                         ctrl_en;
    input  wire                         cnt_clear;
    input  wire                         mode_select;
    input  wire [2:0]                   priv_filter;
    input  wire [G_CONTEXT_WIDTH-1:0]   context_filter;
    input  wire                         context_filter_en;

    // CPU Probes
    input  wire [G_ISSUE_WIDTH-1:0]     probe_instruction_commit;
    input  wire [G_OPCODE_WIDTH-1:0]    probe_opcode;
    input  wire                         probe_stall;
    input  wire                         probe_flush;
    input  wire                         probe_raw_hazard;
    input  wire                         probe_load_hazard;
    input  wire                         probe_control_hazard;
    input  wire                         probe_mem_read;
    input  wire                         probe_mem_write;
    input  wire                         probe_if_valid;
    input  wire                         probe_if_stall;
    input  wire                         probe_id_valid;
    input  wire                         probe_id_stall;
    input  wire                         probe_id_bubble;
    input  wire                         probe_ex_valid;
    input  wire                         probe_ex_stall;
    input  wire                         probe_mem_valid;
    input  wire                         probe_mem_stall;
    input  wire                         probe_wb_valid;
    input  wire                         probe_wb_stall;
    input  wire                         probe_fwd_opp;
    input  wire                         probe_fwd_success;
    input  wire                         probe_execution_done;
    input  wire [G_PRIV_WIDTH-1:0]      probe_priv_mode;
    input  wire [G_CONTEXT_WIDTH-1:0]   probe_context_id;

    // Read Interface (from APB/UART wrapper)
    input  wire [G_ADDR_WIDTH-1:0]      read_addr;
    input  wire                         read_en;
    output wire [G_COUNTER_WIDTH-1:0]   read_data;
    output wire                         read_valid;

    // =========================================================================
    // Internal Wires
    // =========================================================================
    
    // Mode Controller -> Counters
    wire en_arch_counters;
    wire en_microarch_counters;

    // Event Collector -> Event Counters
    wire [G_ISSUE_WIDTH-1:0]    ev_inst_retired;
    wire                        ev_branch_retired;
    wire                        ev_load_retired;
    wire                        ev_store_retired;
    wire                        ev_raw_hazard_cycle;
    wire                        ev_ldu_hazard_cycle;
    wire                        ev_ctrl_hazard_cycle;
    wire                        ev_stall_cycle;
    wire                        ev_bubble_cycle;
    wire                        ev_flush_event;
    wire                        ev_fwd_opp;
    wire                        ev_fwd_success;
    wire                        ev_if_active_cycle;
    wire                        ev_id_active_cycle;
    wire                        ev_ex_active_cycle;
    wire                        ev_mem_active_cycle;
    wire                        ev_wb_active_cycle;
    wire                        ev_execution_done;

    // Event Counters -> Analytics Engine & Register Bank
    wire [G_COUNTER_WIDTH-1:0]  cycle_cnt;
    wire [G_COUNTER_WIDTH-1:0]  inst_ret_cnt;
    wire [G_COUNTER_WIDTH-1:0]  branch_cnt;
    wire [G_COUNTER_WIDTH-1:0]  load_cnt;
    wire [G_COUNTER_WIDTH-1:0]  store_cnt;
    wire [G_COUNTER_WIDTH-1:0]  raw_haz_cnt;
    wire [G_COUNTER_WIDTH-1:0]  ldu_haz_cnt;
    wire [G_COUNTER_WIDTH-1:0]  ctrl_haz_cnt;
    wire [G_COUNTER_WIDTH-1:0]  stall_cnt;
    wire [G_COUNTER_WIDTH-1:0]  bubble_cnt;
    wire [G_COUNTER_WIDTH-1:0]  flush_cnt;
    wire [G_COUNTER_WIDTH-1:0]  fwd_opp_cnt;
    wire [G_COUNTER_WIDTH-1:0]  fwd_succ_cnt;
    wire [G_COUNTER_WIDTH-1:0]  if_active_cnt;
    wire [G_COUNTER_WIDTH-1:0]  id_active_cnt;
    wire [G_COUNTER_WIDTH-1:0]  ex_active_cnt;
    wire [G_COUNTER_WIDTH-1:0]  mem_active_cnt;
    wire [G_COUNTER_WIDTH-1:0]  wb_active_cnt;

    // Analytics Engine -> Register Bank
    wire [G_COUNTER_WIDTH-1:0]  metric_ipc;
    wire [G_COUNTER_WIDTH-1:0]  metric_cpi;
    wire [G_COUNTER_WIDTH-1:0]  metric_pipe_eff;
    wire [G_COUNTER_WIDTH-1:0]  metric_util_if;
    wire [G_COUNTER_WIDTH-1:0]  metric_util_id;
    wire [G_COUNTER_WIDTH-1:0]  metric_util_ex;
    wire [G_COUNTER_WIDTH-1:0]  metric_util_mem;
    wire [G_COUNTER_WIDTH-1:0]  metric_util_wb;
    wire [G_COUNTER_WIDTH-1:0]  metric_fwd_eff;
    wire [G_COUNTER_WIDTH-1:0]  metric_haz_raw_dist;
    wire [G_COUNTER_WIDTH-1:0]  metric_haz_ldu_dist;
    wire [G_COUNTER_WIDTH-1:0]  metric_haz_ctrl_dist;
    wire [G_COUNTER_WIDTH-1:0]  metric_mem_ratio;

    // Power Gating logic: gate microarchitectural events if en_microarch_counters is disabled
    wire gated_ev_raw_hazard_cycle  = ev_raw_hazard_cycle  & en_microarch_counters;
    wire gated_ev_ldu_hazard_cycle  = ev_ldu_hazard_cycle  & en_microarch_counters;
    wire gated_ev_ctrl_hazard_cycle = ev_ctrl_hazard_cycle & en_microarch_counters;
    wire gated_ev_stall_cycle       = ev_stall_cycle       & en_microarch_counters;
    wire gated_ev_bubble_cycle      = ev_bubble_cycle      & en_microarch_counters;
    wire gated_ev_flush_event       = ev_flush_event       & en_microarch_counters;
    wire gated_ev_fwd_opp           = ev_fwd_opp           & en_microarch_counters;
    wire gated_ev_fwd_success       = ev_fwd_success       & en_microarch_counters;
    wire gated_ev_if_active_cycle   = ev_if_active_cycle   & en_microarch_counters;
    wire gated_ev_id_active_cycle   = ev_id_active_cycle   & en_microarch_counters;
    wire gated_ev_ex_active_cycle   = ev_ex_active_cycle   & en_microarch_counters;
    wire gated_ev_mem_active_cycle  = ev_mem_active_cycle  & en_microarch_counters;
    wire gated_ev_wb_active_cycle   = ev_wb_active_cycle   & en_microarch_counters;

    // =========================================================================
    // Instantiations
    // =========================================================================

    mode_controller u_mode_ctrl (
        .clk(probe_clk),
        .rst_n(probe_rst_n),
        .mode_select(mode_select),
        .en_arch_counters(en_arch_counters),
        .en_microarch_counters(en_microarch_counters)
    );

    event_collector #(
        G_OPCODE_WIDTH,
        G_ISSUE_WIDTH,
        G_PRIV_WIDTH,
        G_CONTEXT_WIDTH
    ) u_event_collector (
        .probe_clk(probe_clk),
        .probe_rst_n(probe_rst_n),
        .ctrl_en(ctrl_en),
        .priv_filter(priv_filter),
        .context_filter(context_filter),
        .context_filter_en(context_filter_en),
        .probe_instruction_commit(probe_instruction_commit),
        .probe_opcode(probe_opcode),
        .probe_stall(probe_stall),
        .probe_flush(probe_flush),
        .probe_raw_hazard(probe_raw_hazard),
        .probe_load_hazard(probe_load_hazard),
        .probe_control_hazard(probe_control_hazard),
        .probe_mem_read(probe_mem_read),
        .probe_mem_write(probe_mem_write),
        .probe_if_valid(probe_if_valid),
        .probe_if_stall(probe_if_stall),
        .probe_id_valid(probe_id_valid),
        .probe_id_stall(probe_id_stall),
        .probe_id_bubble(probe_id_bubble),
        .probe_ex_valid(probe_ex_valid),
        .probe_ex_stall(probe_ex_stall),
        .probe_mem_valid(probe_mem_valid),
        .probe_mem_stall(probe_mem_stall),
        .probe_wb_valid(probe_wb_valid),
        .probe_wb_stall(probe_wb_stall),
        .probe_fwd_opp(probe_fwd_opp),
        .probe_fwd_success(probe_fwd_success),
        .probe_execution_done(probe_execution_done),
        .probe_priv_mode(probe_priv_mode),
        .probe_context_id(probe_context_id),
        
        .ev_inst_retired(ev_inst_retired),
        .ev_branch_retired(ev_branch_retired),
        .ev_load_retired(ev_load_retired),
        .ev_store_retired(ev_store_retired),
        .ev_raw_hazard_cycle(ev_raw_hazard_cycle),
        .ev_ldu_hazard_cycle(ev_ldu_hazard_cycle),
        .ev_ctrl_hazard_cycle(ev_ctrl_hazard_cycle),
        .ev_stall_cycle(ev_stall_cycle),
        .ev_bubble_cycle(ev_bubble_cycle),
        .ev_flush_event(ev_flush_event),
        .ev_fwd_opp(ev_fwd_opp),
        .ev_fwd_success(ev_fwd_success),
        .ev_if_active_cycle(ev_if_active_cycle),
        .ev_id_active_cycle(ev_id_active_cycle),
        .ev_ex_active_cycle(ev_ex_active_cycle),
        .ev_mem_active_cycle(ev_mem_active_cycle),
        .ev_wb_active_cycle(ev_wb_active_cycle),
        .ev_execution_done(ev_execution_done)
    );

    event_counter #(
        G_COUNTER_WIDTH,
        G_ISSUE_WIDTH
    ) u_event_counter (
        .probe_clk(probe_clk),
        .probe_rst_n(probe_rst_n),
        
        // Use arch counters for base mode, and microarch for the rest.
        // For simplicity, we bind cnt_en to en_arch_counters (which is always 1 when active)
        // A more advanced synthesis target might split the clock enables.
        .cnt_en(en_arch_counters),
        .cnt_clear(cnt_clear),
        .saturate_en(1'b1),
        
        .ev_inst_retired(ev_inst_retired),
        .ev_branch_retired(ev_branch_retired),
        .ev_load_retired(ev_load_retired),
        .ev_store_retired(ev_store_retired),
        .ev_raw_hazard_cycle(gated_ev_raw_hazard_cycle),
        .ev_ldu_hazard_cycle(gated_ev_ldu_hazard_cycle),
        .ev_ctrl_hazard_cycle(gated_ev_ctrl_hazard_cycle),
        .ev_stall_cycle(gated_ev_stall_cycle),
        .ev_bubble_cycle(gated_ev_bubble_cycle),
        .ev_flush_event(gated_ev_flush_event),
        .ev_fwd_opp(gated_ev_fwd_opp),
        .ev_fwd_success(gated_ev_fwd_success),
        .ev_if_active_cycle(gated_ev_if_active_cycle),
        .ev_id_active_cycle(gated_ev_id_active_cycle),
        .ev_ex_active_cycle(gated_ev_ex_active_cycle),
        .ev_mem_active_cycle(gated_ev_mem_active_cycle),
        .ev_wb_active_cycle(gated_ev_wb_active_cycle),
        
        .cycle_cnt(cycle_cnt),
        .inst_ret_cnt(inst_ret_cnt),
        .branch_cnt(branch_cnt),
        .load_cnt(load_cnt),
        .store_cnt(store_cnt),
        .raw_haz_cnt(raw_haz_cnt),
        .ldu_haz_cnt(ldu_haz_cnt),
        .ctrl_haz_cnt(ctrl_haz_cnt),
        .stall_cnt(stall_cnt),
        .bubble_cnt(bubble_cnt),
        .flush_cnt(flush_cnt),
        .fwd_opp_cnt(fwd_opp_cnt),
        .fwd_succ_cnt(fwd_succ_cnt),
        .if_active_cnt(if_active_cnt),
        .id_active_cnt(id_active_cnt),
        .ex_active_cnt(ex_active_cnt),
        .mem_active_cnt(mem_active_cnt),
        .wb_active_cnt(wb_active_cnt)
    );

    analytics_engine #(
        G_COUNTER_WIDTH,
        G_COUNTER_WIDTH,
        G_ISSUE_WIDTH
    ) u_analytics_engine (
        .clk(probe_clk),
        .rst_n(probe_rst_n),
        .cycle_cnt(cycle_cnt),
        .inst_ret_cnt(inst_ret_cnt),
        .branch_cnt(branch_cnt),
        .load_cnt(load_cnt),
        .store_cnt(store_cnt),
        .fwd_cnt(fwd_succ_cnt), // Mapping success to the engine's definition
        .raw_haz_cnt(raw_haz_cnt),
        .load_haz_cnt(ldu_haz_cnt),
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

    // =========================================================================
    // Packing the Register Bank Bus
    // 32 words of G_COUNTER_WIDTH
    // =========================================================================
    wire [32 * G_COUNTER_WIDTH - 1 : 0] reg_inputs;

    assign reg_inputs = {
        // [31] Spare
        {G_COUNTER_WIDTH{1'b0}}, 
        
        // [30:18] Metrics
        metric_mem_ratio,
        metric_haz_ctrl_dist,
        metric_haz_ldu_dist,
        metric_haz_raw_dist,
        metric_fwd_eff,
        metric_util_wb,
        metric_util_mem,
        metric_util_ex,
        metric_util_id,
        metric_util_if,
        metric_pipe_eff,
        metric_cpi,
        metric_ipc,

        // [17:0] Raw Counters
        wb_active_cnt,
        mem_active_cnt,
        ex_active_cnt,
        id_active_cnt,
        if_active_cnt,
        fwd_succ_cnt,
        fwd_opp_cnt,
        flush_cnt,
        bubble_cnt,
        stall_cnt,
        ctrl_haz_cnt,
        ldu_haz_cnt,
        raw_haz_cnt,
        store_cnt,
        load_cnt,
        branch_cnt,
        inst_ret_cnt,
        cycle_cnt
    };

    register_bank #(
        32,
        G_COUNTER_WIDTH,
        G_ADDR_WIDTH
    ) u_register_bank (
        .clk(probe_clk),
        .rst_n(probe_rst_n),
        .execution_done(ev_execution_done),
        .reg_inputs(reg_inputs),
        .read_addr(read_addr),
        .read_en(read_en),
        .read_data(read_data),
        .read_valid(read_valid)
    );

endmodule
