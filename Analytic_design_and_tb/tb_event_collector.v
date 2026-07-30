// =============================================================================
// Company:        ASIC soft IP
// Engineer:       Senior ASIC Architect
// 
// Create Date:    July 15, 2026
// Design Name:    Configurable Processor Analytics Soft IP Testbench
// Module Name:    event_collector_tb
// Project Name:   Configurable Processor Analytics Soft IP
// Target Devices: ASIC / FPGA Simulation
// Tool Versions:  Synthesizable Verilog-2001 Testbench
// Description:    Self-checking testbench to verify event_collector module.
//                 Validates pipeline stages, opcodes, hazards, flushes, bubbles,
//                 and privilege level/context filtering.
// =============================================================================

`timescale 1ns / 1ps

module event_collector_tb;

    // Parameters
    parameter G_OPCODE_WIDTH  = 32;
    parameter G_ISSUE_WIDTH   = 1;
    parameter G_PRIV_WIDTH    = 2;
    parameter G_CONTEXT_WIDTH = 8;

    // Inputs to UUT
    reg                         clk;
    reg                         rst_n;
    reg                         ctrl_en;
    reg [2:0]                   priv_filter;
    reg [G_CONTEXT_WIDTH-1:0]   context_filter;
    reg                         context_filter_en;
    reg [G_ISSUE_WIDTH-1:0]     probe_instruction_commit;
    reg [G_OPCODE_WIDTH-1:0]    probe_opcode;
    reg                         probe_stall;
    reg                         probe_flush;
    reg                         probe_raw_hazard;
    reg                         probe_load_hazard;
    reg                         probe_control_hazard;
    reg                         probe_mem_read;
    reg                         probe_mem_write;
    reg                         probe_if_valid;
    reg                         probe_if_stall;
    reg                         probe_id_valid;
    reg                         probe_id_stall;
    reg                         probe_id_bubble;
    reg                         probe_ex_valid;
    reg                         probe_ex_stall;
    reg                         probe_mem_valid;
    reg                         probe_mem_stall;
    reg                         probe_wb_valid;
    reg                         probe_wb_stall;
    reg                         probe_fwd_opp;
    reg                         probe_fwd_success;
    reg                         probe_execution_done;
    reg [G_PRIV_WIDTH-1:0]      probe_priv_mode;
    reg [G_CONTEXT_WIDTH-1:0]   probe_context_id;

    // Outputs from UUT
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

    // UUT Instantiation
    event_collector #(
        G_OPCODE_WIDTH,
        G_ISSUE_WIDTH,
        G_PRIV_WIDTH,
        G_CONTEXT_WIDTH
    ) uut (
        .probe_clk(clk),
        .probe_rst_n(rst_n),
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

    // Clock Generator (100MHz -> 10ns period)
    always #5 clk = ~clk;

    // Test variables
    integer errors = 0;

    // Helper task to clear all probe inputs
    task clear_probes;
        begin
            probe_instruction_commit = {G_ISSUE_WIDTH{1'b0}};
            probe_opcode             = {G_OPCODE_WIDTH{1'b0}};
            probe_stall              = 1'b0;
            probe_flush              = 1'b0;
            probe_raw_hazard         = 1'b0;
            probe_load_hazard        = 1'b0;
            probe_control_hazard     = 1'b0;
            probe_mem_read           = 1'b0;
            probe_mem_write          = 1'b0;
            probe_if_valid           = 1'b0;
            probe_if_stall           = 1'b0;
            probe_id_valid           = 1'b0;
            probe_id_stall           = 1'b0;
            probe_id_bubble          = 1'b0;
            probe_ex_valid           = 1'b0;
            probe_ex_stall           = 1'b0;
            probe_mem_valid          = 1'b0;
            probe_mem_stall          = 1'b0;
            probe_wb_valid           = 1'b0;
            probe_wb_stall           = 1'b0;
            probe_fwd_opp            = 1'b0;
            probe_fwd_success        = 1'b0;
            probe_execution_done     = 1'b0;
            probe_priv_mode          = 2'b11; // Machine mode
            probe_context_id         = 8'h01;
        end
    endtask

    // Simulation Flow
    initial begin
        // Initialize Inputs
        clk = 0;
        rst_n = 0;
        ctrl_en = 0;
        priv_filter = 3'b111; // enable all (User, Supervisor, Machine)
        context_filter = 8'h01;
        context_filter_en = 0; // disable context filter by default
        clear_probes;

        // 1. Reset Phase
        #20 rst_n = 1;
        #10 ctrl_en = 1; // Enable collector tracking
        #10;
        
        $display("=== STARTING EVENT COLLECTOR VERIFICATION ===");

        // =====================================================================
        // Test 1: Instruction Retirement
        // =====================================================================
        $display("[TEST 1] Instruction Commit Pulse");
        probe_instruction_commit = 1'b1;
        probe_opcode = 32'h000002b3; // ADD instruction (non-branch, non-load, non-store)
        #10;
        clear_probes;
        // Wait 1 cycle for registered output (total latency = 2 clocks from input)
        #10;
        if (ev_inst_retired !== 1'b1) begin
            $display("ERROR: Instruction commit event pulse failed. Expected 1, Got %b", ev_inst_retired);
            errors = errors + 1;
        end

        // =====================================================================
        // Test 2: Branch Opcode Retirement
        // =====================================================================
        $display("[TEST 2] Branch Opcode Commit");
        probe_instruction_commit = 1'b1;
        probe_opcode = 32'h000000e3; // RISC-V BEQ instruction (opcode 7'b1100011)
        #10;
        clear_probes;
        #10;
        if (ev_branch_retired !== 1'b1) begin
            $display("ERROR: Branch retirement detection failed. Expected 1, Got %b", ev_branch_retired);
            errors = errors + 1;
        end

        // =====================================================================
        // Test 3: Load Opcode Retirement
        // =====================================================================
        $display("[TEST 3] Load Opcode Commit");
        probe_instruction_commit = 1'b1;
        probe_opcode = 32'h00000003; // RISC-V LW instruction (opcode 7'b0000011)
        #10;
        clear_probes;
        #10;
        if (ev_load_retired !== 1'b1) begin
            $display("ERROR: Load retirement detection failed. Expected 1, Got %b", ev_load_retired);
            errors = errors + 1;
        end

        // =====================================================================
        // Test 4: Store Opcode Retirement
        // =====================================================================
        $display("[TEST 4] Store Opcode Commit");
        probe_instruction_commit = 1'b1;
        probe_opcode = 32'h00000023; // RISC-V SW instruction (opcode 7'b0100011)
        #10;
        clear_probes;
        #10;
        if (ev_store_retired !== 1'b1) begin
            $display("ERROR: Store retirement detection failed. Expected 1, Got %b", ev_store_retired);
            errors = errors + 1;
        end

        // =====================================================================
        // Test 5: Hazards, Stalls and Flushes
        // =====================================================================
        $display("[TEST 5] Hazard and Stall Level Assertions");
        probe_raw_hazard = 1'b1;
        probe_load_hazard = 1'b1;
        probe_control_hazard = 1'b1;
        probe_stall = 1'b1;
        probe_flush = 1'b1;
        #10;
        clear_probes;
        #10;
        if (ev_raw_hazard_cycle !== 1'b1 || ev_ldu_hazard_cycle !== 1'b1 || ev_ctrl_hazard_cycle !== 1'b1 || ev_stall_cycle !== 1'b1 || ev_flush_event !== 1'b1) begin
            $display("ERROR: Hazard, stall, or flush level gating failed.");
            errors = errors + 1;
        end

        // =====================================================================
        // Test 6: Forwarding and Bubble events
        // =====================================================================
        $display("[TEST 6] Forwarding and Bubbles");
        probe_fwd_opp = 1'b1;
        probe_fwd_success = 1'b1;
        probe_id_bubble = 1'b1;
        #10;
        clear_probes;
        #10;
        if (ev_fwd_opp !== 1'b1 || ev_fwd_success !== 1'b1 || ev_bubble_cycle !== 1'b1) begin
            $display("ERROR: Forwarding or Bubble registration failed.");
            errors = errors + 1;
        end

        // =====================================================================
        // Test 7: Pipeline Stage Utilizations
        // =====================================================================
        $display("[TEST 7] Stage Valid Level Assertions");
        probe_if_valid = 1'b1;
        probe_id_valid = 1'b1;
        probe_ex_valid = 1'b1;
        probe_mem_valid = 1'b1;
        probe_wb_valid = 1'b1;
        #10;
        clear_probes;
        #10;
        if (ev_if_active_cycle !== 1'b1 || ev_id_active_cycle !== 1'b1 || ev_ex_active_cycle !== 1'b1 || ev_mem_active_cycle !== 1'b1 || ev_wb_active_cycle !== 1'b1) begin
            $display("ERROR: Pipeline active stage level gating failed.");
            errors = errors + 1;
        end

        // =====================================================================
        // Test 8: Privilege Filtering (Gating check)
        // =====================================================================
        $display("[TEST 8] Privilege Filtering");
        // Only profile User Mode (priv_filter = 3'b001)
        priv_filter = 3'b001; 
        probe_priv_mode = 2'b11; // Machine mode
        probe_instruction_commit = 1'b1; // Trigger commit
        #10;
        clear_probes;
        #10;
        if (ev_inst_retired !== 1'b0) begin
            $display("ERROR: Privilege filtering failed. Expected gated commit 0, Got %b", ev_inst_retired);
            errors = errors + 1;
        end

        // Change mode to User mode (matches filter)
        probe_priv_mode = 2'b00; // User mode
        probe_instruction_commit = 1'b1;
        #10;
        clear_probes;
        #10;
        if (ev_inst_retired !== 1'b1) begin
            $display("ERROR: Gating allowed commit failed. Expected 1, Got %b", ev_inst_retired);
            errors = errors + 1;
        end

        // =====================================================================
        // Test 9: Context ID Filtering
        // =====================================================================
        $display("[TEST 9] Context Filtering");
        priv_filter = 3'b111; // Allow all privileges
        context_filter = 8'hA5;
        context_filter_en = 1'b1; // Enable context gating
        
        probe_context_id = 8'h33; // Mismatch ID
        probe_instruction_commit = 1'b1;
        #10;
        clear_probes;
        #10;
        if (ev_inst_retired !== 1'b0) begin
            $display("ERROR: Context gating failed. Expected gated commit 0, Got %b", ev_inst_retired);
            errors = errors + 1;
        end

        probe_context_id = 8'hA5; // Match ID
        probe_instruction_commit = 1'b1;
        #10;
        clear_probes;
        #10;
        if (ev_inst_retired !== 1'b1) begin
            $display("ERROR: Context matching failed. Expected 1, Got %b", ev_inst_retired);
            errors = errors + 1;
        end

        // =====================================================================
        // Final Verdict
        // =====================================================================
        $display("===============================================");
        if (errors == 0) begin
            $display("  ALL EVENT COLLECTOR TESTS PASSED SUCCESSFULLY!  ");
        end else begin
            $display("  VERIFICATION FAILED WITH %d ERRORS.", errors);
        end
        $display("===============================================");
        $finish;
    end

endmodule
