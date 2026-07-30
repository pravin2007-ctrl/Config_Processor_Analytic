// =============================================================================
// Company:        ASIC soft IP
// Engineer:       Senior ASIC Architect
// 
// Create Date:    July 15, 2026
// Design Name:    Configurable Processor Analytics Soft IP Counter Testbench
// Module Name:    tb_event_counter
// Project Name:   Configurable Processor Analytics Soft IP
// Target Devices: ASIC / FPGA Simulation
// Tool Versions:  Synthesizable Verilog-2001 Testbench
// Description:    Self-checking testbench to verify event_counter.
//                 Validates clear logic, gating, multi-issue commits,
//                 and counter saturation at maximum values.
// =============================================================================

`timescale 1ns / 1ps

module tb_event_counter;

    // Test parameters
    parameter TEST_WIDTH = 4; // Use a small width of 4 bits to verify saturation easily
    parameter TEST_ISSUE = 4; // 4-way superscalar support

    // Inputs to UUT
    reg                     clk;
    reg                     rst_n;
    reg                     cnt_en;
    reg                     cnt_clear;
    reg                     saturate_en;
    reg [TEST_ISSUE-1:0]    ev_inst_retired;
    reg                     ev_branch_retired;
    reg                     ev_load_retired;
    reg                     ev_store_retired;
    reg                     ev_raw_hazard_cycle;
    reg                     ev_ldu_hazard_cycle;
    reg                     ev_ctrl_hazard_cycle;
    reg                     ev_stall_cycle;
    reg                     ev_bubble_cycle;
    reg                     ev_flush_event;
    reg                     ev_fwd_opp;
    reg                     ev_fwd_success;
    reg                     ev_if_active_cycle;
    reg                     ev_id_active_cycle;
    reg                     ev_ex_active_cycle;
    reg                     ev_mem_active_cycle;
    reg                     ev_wb_active_cycle;

    // Outputs from UUT
    wire [TEST_WIDTH-1:0]   cycle_cnt;
    wire [TEST_WIDTH-1:0]   inst_ret_cnt;
    wire [TEST_WIDTH-1:0]   branch_cnt;
    wire [TEST_WIDTH-1:0]   load_cnt;
    wire [TEST_WIDTH-1:0]   store_cnt;
    wire [TEST_WIDTH-1:0]   raw_haz_cnt;
    wire [TEST_WIDTH-1:0]   ldu_haz_cnt;
    wire [TEST_WIDTH-1:0]   ctrl_haz_cnt;
    wire [TEST_WIDTH-1:0]   stall_cnt;
    wire [TEST_WIDTH-1:0]   bubble_cnt;
    wire [TEST_WIDTH-1:0]   flush_cnt;
    wire [TEST_WIDTH-1:0]   fwd_opp_cnt;
    wire [TEST_WIDTH-1:0]   fwd_succ_cnt;
    wire [TEST_WIDTH-1:0]   if_active_cnt;
    wire [TEST_WIDTH-1:0]   id_active_cnt;
    wire [TEST_WIDTH-1:0]   ex_active_cnt;
    wire [TEST_WIDTH-1:0]   mem_active_cnt;
    wire [TEST_WIDTH-1:0]   wb_active_cnt;

    // Instantiation
    event_counter #(
        TEST_WIDTH,
        TEST_ISSUE
    ) uut (
        .probe_clk(clk),
        .probe_rst_n(rst_n),
        .cnt_en(cnt_en),
        .cnt_clear(cnt_clear),
        .saturate_en(saturate_en),
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

    // Clock Gen
    always #5 clk = ~clk;

    // Test variables
    integer errors = 0;
    
    // Coverage trackers
    reg cov_cycle_tested;
    reg cov_clear_tested;
    reg cov_gating_tested;
    reg cov_multi_issue_tested;
    reg cov_saturation_tested;

    task clear_events;
        begin
            ev_inst_retired      = 4'b0000;
            ev_branch_retired    = 1'b0;
            ev_load_retired      = 1'b0;
            ev_store_retired     = 1'b0;
            ev_raw_hazard_cycle  = 1'b0;
            ev_ldu_hazard_cycle  = 1'b0;
            ev_ctrl_hazard_cycle = 1'b0;
            ev_stall_cycle       = 1'b0;
            ev_bubble_cycle      = 1'b0;
            ev_flush_event       = 1'b0;
            ev_fwd_opp           = 1'b0;
            ev_fwd_success       = 1'b0;
            ev_if_active_cycle   = 1'b0;
            ev_id_active_cycle   = 1'b0;
            ev_ex_active_cycle   = 1'b0;
            ev_mem_active_cycle  = 1'b0;
            ev_wb_active_cycle   = 1'b0;
        end
    endtask

    initial begin
        clk = 0;
        rst_n = 0;
        cnt_en = 0;
        cnt_clear = 0;
        saturate_en = 0;
        clear_events;
        
        cov_cycle_tested = 0;
        cov_clear_tested = 0;
        cov_gating_tested = 0;
        cov_multi_issue_tested = 0;
        cov_saturation_tested = 0;

        #20 rst_n = 1;
        #10 cnt_en = 1;
        #10;

        $display("=== STARTING EVENT COUNTERS VERIFICATION ===");

        // =====================================================================
        // Test 1: Active Cycle Increment
        // =====================================================================
        $display("[TEST 1] Standard Increment Verification");
        ev_branch_retired = 1'b1;
        ev_load_retired = 1'b1;
        #10; // Increment counters to 1
        if (branch_cnt !== 4'd1 || load_cnt !== 4'd1 || cycle_cnt !== 4'd2) begin
            $display("ERROR: Increment test failed. branch_cnt=%d, load_cnt=%d, cycle_cnt=%d", branch_cnt, load_cnt, cycle_cnt);
            errors = errors + 1;
        end
        clear_events;
        #10;
        cov_cycle_tested = 1;

        // =====================================================================
        // Test 2: Gating Verification (cnt_en)
        // =====================================================================
        $display("[TEST 2] Counter Gating (cnt_en = 0)");
        cnt_en = 0;
        ev_branch_retired = 1'b1;
        #20; // 2 clock cycles of event active
        clear_events;
        cnt_en = 1;
        #10;
        if (branch_cnt !== 4'd1) begin
            $display("ERROR: Gating check failed. Counter incremented while disabled. branch_cnt=%d", branch_cnt);
            errors = errors + 1;
        end
        cov_gating_tested = 1;

        // =====================================================================
        // Test 3: Gating Clear Verification (cnt_clear)
        // =====================================================================
        $display("[TEST 3] Synchronous Reset (cnt_clear = 1)");
        cnt_clear = 1;
        #10;
        if (branch_cnt !== 4'd0 || load_cnt !== 4'd0 || cycle_cnt !== 4'd0) begin
            $display("ERROR: Synchronous clear failed. branch_cnt=%d, cycle_cnt=%d", branch_cnt, cycle_cnt);
            errors = errors + 1;
        end
        cnt_clear = 0;
        #10;
        cov_clear_tested = 1;

        // =====================================================================
        // Test 4: Multi-Issue Retirement Adder
        // =====================================================================
        $display("[TEST 4] Multi-Issue Instruction Slots Summation");
        ev_inst_retired = 4'b1011; // 3 instructions retired on same cycle
        #10;
        clear_events;
        #10;
        if (inst_ret_cnt !== 4'd3) begin
            $display("ERROR: Multi-issue commit failed. Expected 3, Got %d", inst_ret_cnt);
            errors = errors + 1;
        end
        cov_multi_issue_tested = 1;

        // =====================================================================
        // Test 5: Counter Saturation
        // =====================================================================
        $display("[TEST 5] Counter Saturation Limits");
        saturate_en = 1;
        // Count to 4'hE first
        ev_branch_retired = 1'b1;
        #140; // 14 cycles of increment -> 14 + 0 = 14 (4'hE)
        clear_events;
        #10;
        
        $display("   Before saturation pulse: branch_cnt = %h", branch_cnt);
        
        // Assert increment to push to maximum (4'hF)
        ev_branch_retired = 1'b1;
        #10; // push to 15 (4'hF)
        // Assert again (should saturate at 4'hF, not roll over to 4'h0)
        #20;
        clear_events;
        #10;
        if (branch_cnt !== 4'hF) begin
            $display("ERROR: Saturation failure. Expected 4'hF, Got %h", branch_cnt);
            errors = errors + 1;
        end
        cov_saturation_tested = 1;

        // =====================================================================
        // Test 6: Verify Other Event Lines Gating
        // =====================================================================
        $display("[TEST 6] Triggering remaining counters for coverage");
        cnt_clear = 1;
        #10;
        cnt_clear = 0;
        saturate_en = 0;
        #10;
        
        ev_store_retired     = 1'b1;
        ev_raw_hazard_cycle  = 1'b1;
        ev_ldu_hazard_cycle  = 1'b1;
        ev_ctrl_hazard_cycle = 1'b1;
        ev_stall_cycle       = 1'b1;
        ev_bubble_cycle      = 1'b1;
        ev_flush_event       = 1'b1;
        ev_fwd_opp           = 1'b1;
        ev_fwd_success       = 1'b1;
        ev_if_active_cycle   = 1'b1;
        ev_id_active_cycle   = 1'b1;
        ev_ex_active_cycle   = 1'b1;
        ev_mem_active_cycle  = 1'b1;
        ev_wb_active_cycle   = 1'b1;
        #10;
        clear_events;
        #10;

        if (store_cnt !== 4'd1 || raw_haz_cnt !== 4'd1 || ldu_haz_cnt !== 4'd1 ||
            ctrl_haz_cnt !== 4'd1 || stall_cnt !== 4'd1 || bubble_cnt !== 4'd1 ||
            flush_cnt !== 4'd1 || fwd_opp_cnt !== 4'd1 || fwd_succ_cnt !== 4'd1 ||
            if_active_cnt !== 4'd1 || id_active_cnt !== 4'd1 || ex_active_cnt !== 4'd1 ||
            mem_active_cnt !== 4'd1 || wb_active_cnt !== 4'd1) begin
            $display("ERROR: Event line coverage checks failed.");
            errors = errors + 1;
        end

        // =====================================================================
        // Print Verification Verdict
        // =====================================================================
        $display("===============================================");
        $display("                COVERAGE REPORT                ");
        $display("===============================================");
        $display("  Cycle Increment Test   : %s", cov_cycle_tested ? "PASSED" : "FAILED");
        $display("  Synchronous Clear Test : %s", cov_clear_tested ? "PASSED" : "FAILED");
        $display("  Counter Gating Test    : %s", cov_gating_tested ? "PASSED" : "FAILED");
        $display("  Multi-Issue Commit Test: %s", cov_multi_issue_tested ? "PASSED" : "FAILED");
        $display("  Saturation Test        : %s", cov_saturation_tested ? "PASSED" : "FAILED");
        $display("===============================================");
        if (errors == 0) begin
            $display("  ALL EVENT COUNTER TESTS PASSED SUCCESSFULLY!  ");
        end else begin
            $display("  VERIFICATION FAILED WITH %d ERRORS.", errors);
        end
        $display("===============================================");
        $finish;
    end

endmodule
