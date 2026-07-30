`timescale 1ns/1ps

module tb_analytics_top;

    // =========================================================================
    // Parameters
    // =========================================================================
    parameter G_OPCODE_WIDTH  = 32;
    parameter G_ISSUE_WIDTH   = 1;
    parameter G_PRIV_WIDTH    = 2;
    parameter G_CONTEXT_WIDTH = 8;
    parameter G_COUNTER_WIDTH = 32;
    parameter G_ADDR_WIDTH    = 8;

    // =========================================================================
    // Signals
    // =========================================================================
    reg                         probe_clk;
    reg                         probe_rst_n;
    reg                         ctrl_en;
    reg                         cnt_clear;
    reg                         mode_select;
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

    reg [G_ADDR_WIDTH-1:0]      read_addr;
    reg                         read_en;
    wire [G_COUNTER_WIDTH-1:0]  read_data;
    wire                        read_valid;

    // Track Coverage
    integer tests_passed = 0;
    integer tests_failed = 0;

    // =========================================================================
    // UUT Instantiation
    // =========================================================================
    analytics_top #(
        G_OPCODE_WIDTH,
        G_ISSUE_WIDTH,
        G_PRIV_WIDTH,
        G_CONTEXT_WIDTH,
        G_COUNTER_WIDTH,
        G_ADDR_WIDTH
    ) uut (
        .probe_clk(probe_clk),
        .probe_rst_n(probe_rst_n),
        .ctrl_en(ctrl_en),
        .cnt_clear(cnt_clear),
        .mode_select(mode_select),
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
        .read_addr(read_addr),
        .read_en(read_en),
        .read_data(read_data),
        .read_valid(read_valid)
    );

    // =========================================================================
    // Clock Generation
    // =========================================================================
    always #5 probe_clk = ~probe_clk;

    // =========================================================================
    // Tasks
    // =========================================================================

    task reset_probes;
    begin
        probe_instruction_commit = 0;
        probe_opcode = 32'h0;
        probe_stall = 0;
        probe_flush = 0;
        probe_raw_hazard = 0;
        probe_load_hazard = 0;
        probe_control_hazard = 0;
        probe_mem_read = 0;
        probe_mem_write = 0;
        probe_if_valid = 0;
        probe_if_stall = 0;
        probe_id_valid = 0;
        probe_id_stall = 0;
        probe_id_bubble = 0;
        probe_ex_valid = 0;
        probe_ex_stall = 0;
        probe_mem_valid = 0;
        probe_mem_stall = 0;
        probe_wb_valid = 0;
        probe_wb_stall = 0;
        probe_fwd_opp = 0;
        probe_fwd_success = 0;
        probe_execution_done = 0;
    end
    endtask

    task run_normal_program;
        input [31:0] cycles;
        integer i;
        begin
            for (i = 0; i < cycles; i = i + 1) begin
                reset_probes;
                probe_instruction_commit = 1;
                probe_opcode = 32'h00000033; // ALU op
                probe_if_valid = 1;
                probe_id_valid = 1;
                probe_ex_valid = 1;
                probe_wb_valid = 1;
                @(posedge probe_clk);
            end
            reset_probes;
        end
    endtask

    task run_memory_intensive;
        input [31:0] cycles;
        integer i;
        begin
            for (i = 0; i < cycles; i = i + 1) begin
                reset_probes;
                probe_instruction_commit = 1;
                probe_opcode = 32'h00000003; // Load op
                probe_if_valid = 1;
                probe_id_valid = 1;
                probe_ex_valid = 1;
                probe_mem_valid = 1;
                probe_wb_valid = 1;
                probe_mem_read = 1;
                @(posedge probe_clk);
            end
            reset_probes;
        end
    endtask

    task run_branch_intensive;
        input [31:0] cycles;
        integer i;
        begin
            for (i = 0; i < cycles; i = i + 1) begin
                reset_probes;
                probe_instruction_commit = 1;
                probe_opcode = 32'h00000063; // Branch op
                probe_if_valid = 1;
                probe_id_valid = 1;
                probe_ex_valid = 1;
                @(posedge probe_clk);
            end
            reset_probes;
        end
    endtask

    task run_raw_hazard;
        input [31:0] cycles;
        integer i;
        begin
            for (i = 0; i < cycles; i = i + 1) begin
                reset_probes;
                probe_stall = 1;
                probe_raw_hazard = 1;
                probe_if_valid = 1;
                probe_if_stall = 1;
                probe_id_valid = 1;
                probe_id_stall = 1;
                probe_ex_valid = 0; // Bubble
                @(posedge probe_clk);
            end
            reset_probes;
        end
    endtask

    task run_fwd_enabled;
        input [31:0] cycles;
        integer i;
        begin
            for (i = 0; i < cycles; i = i + 1) begin
                reset_probes;
                probe_instruction_commit = 1;
                probe_opcode = 32'h00000033; // ALU op
                probe_fwd_opp = 1;
                probe_fwd_success = 1;
                probe_if_valid = 1;
                probe_id_valid = 1;
                probe_ex_valid = 1;
                probe_wb_valid = 1;
                @(posedge probe_clk);
            end
            reset_probes;
        end
    endtask

    task run_fwd_disabled;
        input [31:0] cycles;
        integer i;
        begin
            for (i = 0; i < cycles; i = i + 1) begin
                reset_probes;
                probe_fwd_opp = 1;
                probe_fwd_success = 0;
                probe_raw_hazard = 1;
                probe_stall = 1;
                @(posedge probe_clk);
            end
            reset_probes;
        end
    endtask

    task run_pipeline_flush;
    begin
        reset_probes;
        probe_flush = 1;
        @(posedge probe_clk);
        reset_probes;
    end
    endtask

    task run_load_hazard;
        input [31:0] cycles;
        integer i;
        begin
            for (i = 0; i < cycles; i = i + 1) begin
                reset_probes;
                probe_stall = 1;
                probe_load_hazard = 1;
                probe_if_valid = 1;
                probe_if_stall = 1;
                probe_id_valid = 1;
                probe_id_stall = 1;
                probe_ex_valid = 0; // Bubble
                @(posedge probe_clk);
            end
            reset_probes;
        end
    endtask

    task run_control_hazard;
        input [31:0] cycles;
        integer i;
        begin
            for (i = 0; i < cycles; i = i + 1) begin
                reset_probes;
                probe_stall = 1;
                probe_control_hazard = 1;
                probe_if_valid = 1;
                probe_if_stall = 1;
                probe_id_valid = 1;
                probe_id_stall = 1;
                probe_ex_valid = 0; // Bubble
                @(posedge probe_clk);
            end
            reset_probes;
        end
    endtask

    // -------------------------------------------------------------------
    // Realistic mixed workload, sized to look like a real program run
    // (thousands of instructions) instead of an isolated single-feature
    // burst. Each "block" below is 12 driven cycles representing a
    // plausible instruction mix: mostly ALU ops, with a load, a store,
    // a taken branch, and one instance each of a RAW hazard, a
    // load-use hazard, and a control-hazard flush -- plus two
    // forwarding attempts that succeed and one that misses (stalls).
    //
    // Per block, exactly:
    //   9 instructions retire  (3 hazard/bubble cycles do NOT retire)
    //   1 branch, 1 load, 1 store
    //   1 RAW hazard, 1 load-use hazard, 1 control hazard, 1 flush
    //   3 stall cycles, 3 bubble cycles
    //   3 forwarding opportunities (2 hits, 1 miss)
    //   9 IF/ID/EX-active cycles, 2 MEM-active cycles, 8 WB-active cycles
    //
    // Because every quantity above scales linearly with the block
    // count, the expected value of every raw counter after N blocks is
    // just N times the per-block number -- which is what lets us
    // verify_register() against nearly every raw-counter address below,
    // not just eyeball the dump.
    // -------------------------------------------------------------------
    task run_mixed_workload;
        input [31:0] num_blocks;
        integer i;
        begin
            for (i = 0; i < num_blocks; i = i + 1) begin
                // 1. ALU op
                reset_probes;
                probe_instruction_commit = 1;
                probe_opcode = 32'h00000033;
                probe_if_valid = 1; probe_id_valid = 1; probe_ex_valid = 1; probe_wb_valid = 1;
                @(posedge probe_clk);

                // 2. ALU op
                reset_probes;
                probe_instruction_commit = 1;
                probe_opcode = 32'h00000033;
                probe_if_valid = 1; probe_id_valid = 1; probe_ex_valid = 1; probe_wb_valid = 1;
                @(posedge probe_clk);

                // 3. ALU op, forwarded operand (hit)
                reset_probes;
                probe_instruction_commit = 1;
                probe_opcode = 32'h00000033;
                probe_if_valid = 1; probe_id_valid = 1; probe_ex_valid = 1; probe_wb_valid = 1;
                probe_fwd_opp = 1; probe_fwd_success = 1;
                @(posedge probe_clk);

                // 4. Load
                reset_probes;
                probe_instruction_commit = 1;
                probe_opcode = 32'h00000003;
                probe_if_valid = 1; probe_id_valid = 1; probe_ex_valid = 1; probe_mem_valid = 1; probe_wb_valid = 1;
                probe_mem_read = 1;
                @(posedge probe_clk);

                // 5. Load-use hazard on the very next instruction -> stall + bubble
                reset_probes;
                probe_stall = 1;
                probe_load_hazard = 1;
                probe_if_valid = 1; probe_if_stall = 1;
                probe_id_valid = 1; probe_id_stall = 1; probe_id_bubble = 1;
                probe_ex_valid = 0; // Bubble
                @(posedge probe_clk);

                // 6. Store
                reset_probes;
                probe_instruction_commit = 1;
                probe_opcode = 32'h00000023;
                probe_if_valid = 1; probe_id_valid = 1; probe_ex_valid = 1; probe_mem_valid = 1; probe_wb_valid = 1;
                probe_mem_write = 1;
                @(posedge probe_clk);

                // 7. RAW hazard, forwarding attempted but missed -> stall + bubble
                reset_probes;
                probe_stall = 1;
                probe_raw_hazard = 1;
                probe_fwd_opp = 1; probe_fwd_success = 0;
                probe_if_valid = 1; probe_if_stall = 1;
                probe_id_valid = 1; probe_id_stall = 1; probe_id_bubble = 1;
                probe_ex_valid = 0; // Bubble
                @(posedge probe_clk);

                // 8. Branch, taken
                reset_probes;
                probe_instruction_commit = 1;
                probe_opcode = 32'h00000063;
                probe_if_valid = 1; probe_id_valid = 1; probe_ex_valid = 1;
                @(posedge probe_clk);

                // 9. Control hazard from the mispredicted branch -> flush + bubble
                reset_probes;
                probe_stall = 1;
                probe_control_hazard = 1;
                probe_flush = 1;
                probe_if_valid = 1; probe_if_stall = 1;
                probe_id_valid = 1; probe_id_stall = 1; probe_id_bubble = 1;
                probe_ex_valid = 0; // Bubble
                @(posedge probe_clk);

                // 10. ALU op, forwarded operand (hit) -- steady state resumes
                reset_probes;
                probe_instruction_commit = 1;
                probe_opcode = 32'h00000033;
                probe_if_valid = 1; probe_id_valid = 1; probe_ex_valid = 1; probe_wb_valid = 1;
                probe_fwd_opp = 1; probe_fwd_success = 1;
                @(posedge probe_clk);

                // 11. ALU op
                reset_probes;
                probe_instruction_commit = 1;
                probe_opcode = 32'h00000033;
                probe_if_valid = 1; probe_id_valid = 1; probe_ex_valid = 1; probe_wb_valid = 1;
                @(posedge probe_clk);

                // 12. ALU op
                reset_probes;
                probe_instruction_commit = 1;
                probe_opcode = 32'h00000033;
                probe_if_valid = 1; probe_id_valid = 1; probe_ex_valid = 1; probe_wb_valid = 1;
                @(posedge probe_clk);
            end
            reset_probes;
        end
    endtask

    task verify_register;
        input [G_ADDR_WIDTH-1:0] addr;
        input [G_COUNTER_WIDTH-1:0] expected_val;
        input [80*8:1] test_name;
        begin
            @(posedge probe_clk);
            read_addr = addr;
            read_en = 1;
            @(posedge probe_clk);
            // Let the register_bank's non-blocking "read_data <= ..." update settle
            // before we sample it -- checking in the same delta-cycle as the clock
            // edge that produces it reads the *old* (pre-read) value every time.
            #1;
            read_en = 0;
            if (read_data !== expected_val) begin
                $display("[FAIL] %s - Expected: %0d, Got: %0d", test_name, expected_val, read_data);
                tests_failed = tests_failed + 1;
            end else begin
                $display("[PASS] %s", test_name);
                tests_passed = tests_passed + 1;
            end
        end
    endtask

    // Reads back all 32 register_bank locations (18 raw counters + 13
    // derived metrics + 1 spare) and prints them to the console as a
    // single labelled snapshot. Non-destructive -- safe to call as many
    // times as we like inside a scenario, and safe to call after
    // verify_register since it just re-reads the same bank.
    //
    // Metrics are stored scaled x100 (see analytics_engine.v), so this
    // task also prints the "human" X.YY form next to the raw code.
    task dump_all_registers;
        input [80*8:1] scenario_name;
        reg [31:0] reg_val [0:31];
        integer idx;
        begin
            for (idx = 0; idx < 32; idx = idx + 1) begin
                @(posedge probe_clk);
                read_addr = idx[G_ADDR_WIDTH-1:0];
                read_en   = 1;
                @(posedge probe_clk);
                #1; // let register_bank's registered read_data settle
                reg_val[idx] = read_data;
            end
            read_en = 0;

            $display("");
            $display("-------------------------------------------------------------");
            $display("REGISTER SNAPSHOT : %0s", scenario_name);
            $display("-------------------------------------------------------------");
            $display(" -- Raw Event Counters (addr 0x00 - 0x11) --");
            $display("  [0x00] cycle_cnt              = %0d", reg_val[0]);
            $display("  [0x01] inst_ret_cnt           = %0d", reg_val[1]);
            $display("  [0x02] branch_cnt             = %0d", reg_val[2]);
            $display("  [0x03] load_cnt               = %0d", reg_val[3]);
            $display("  [0x04] store_cnt              = %0d", reg_val[4]);
            $display("  [0x05] raw_haz_cnt            = %0d", reg_val[5]);
            $display("  [0x06] ldu_haz_cnt            = %0d", reg_val[6]);
            $display("  [0x07] ctrl_haz_cnt           = %0d", reg_val[7]);
            $display("  [0x08] stall_cnt              = %0d", reg_val[8]);
            $display("  [0x09] bubble_cnt             = %0d", reg_val[9]);
            $display("  [0x0A] flush_cnt              = %0d", reg_val[10]);
            $display("  [0x0B] fwd_opp_cnt            = %0d", reg_val[11]);
            $display("  [0x0C] fwd_succ_cnt           = %0d", reg_val[12]);
            $display("  [0x0D] if_active_cnt          = %0d", reg_val[13]);
            $display("  [0x0E] id_active_cnt          = %0d", reg_val[14]);
            $display("  [0x0F] ex_active_cnt          = %0d", reg_val[15]);
            $display("  [0x10] mem_active_cnt         = %0d", reg_val[16]);
            $display("  [0x11] wb_active_cnt          = %0d", reg_val[17]);
            $display(" -- Derived Metrics, scaled x100 (addr 0x12 - 0x1E) --");
            $display("  [0x12] metric_ipc             = %0d  (%0d.%02d IPC)",
                        reg_val[18], reg_val[18] / 100, reg_val[18] % 100);
            $display("  [0x13] metric_cpi             = %0d  (%0d.%02d CPI)",
                        reg_val[19], reg_val[19] / 100, reg_val[19] % 100);
            $display("  [0x14] metric_pipe_eff        = %0d  (%0d%%)", reg_val[20], reg_val[20]);
            $display("  [0x15] metric_util_if         = %0d  (%0d%%)", reg_val[21], reg_val[21]);
            $display("  [0x16] metric_util_id         = %0d  (%0d%%)", reg_val[22], reg_val[22]);
            $display("  [0x17] metric_util_ex         = %0d  (%0d%%)", reg_val[23], reg_val[23]);
            $display("  [0x18] metric_util_mem        = %0d  (%0d%%)", reg_val[24], reg_val[24]);
            $display("  [0x19] metric_util_wb         = %0d  (%0d%%)", reg_val[25], reg_val[25]);
            $display("  [0x1A] metric_fwd_eff         = %0d  (%0d%%)", reg_val[26], reg_val[26]);
            $display("  [0x1B] metric_haz_raw_dist    = %0d  (%0d%%)", reg_val[27], reg_val[27]);
            $display("  [0x1C] metric_haz_ldu_dist    = %0d  (%0d%%)", reg_val[28], reg_val[28]);
            $display("  [0x1D] metric_haz_ctrl_dist   = %0d  (%0d%%)", reg_val[29], reg_val[29]);
            $display("  [0x1E] metric_mem_ratio       = %0d  (%0d%%)", reg_val[30], reg_val[30]);
            $display("  [0x1F] (spare)                = %0d", reg_val[31]);
            $display("-------------------------------------------------------------");
        end
    endtask

    // =========================================================================
    // Test Sequence
    // =========================================================================
    initial begin
        $display("=================================================");
        $display("Starting Analytics IP Verification Suite");
        $display("=================================================");
        
        probe_clk = 0;
        probe_rst_n = 0;
        ctrl_en = 0;
        cnt_clear = 0;
        mode_select = 1; // Microarch mode to enable all counters
        priv_filter = 3'b111; // Accept all
        context_filter_en = 0;
        probe_priv_mode = 0;
        probe_context_id = 0;
        read_addr = 0;
        read_en = 0;

        reset_probes;

        // Release Reset for Scenario 1
        #20 probe_rst_n = 1;
        ctrl_en = 1;
        @(posedge probe_clk);

        // -----------------------------------------------------------
        // Scenario 1: Normal Program (10 cycles)
        // -----------------------------------------------------------
        $display("Injecting Scenario 1: Normal Program");
        reset_probes;
        cnt_clear = 1;
        @(posedge probe_clk);
        cnt_clear = 0;
        
        run_normal_program(10);
        
        // Wait pipeline flush (2 cycles for collector)
        reset_probes;
        @(posedge probe_clk);
        @(posedge probe_clk);
        @(posedge probe_clk);
        probe_execution_done = 1;
        @(posedge probe_clk);
        probe_execution_done = 0;
        
        // IPC is scaled by 100. 10 inst / 13 cycles = 76
        verify_register(8'h12, 76, "Normal Program: IPC = 76");
        dump_all_registers("Scenario 1 - Normal Program");

        // -----------------------------------------------------------
        // Scenario 2: Memory Intensive (10 cycles)
        // -----------------------------------------------------------
        $display("Injecting Scenario 2: Memory Intensive");
        reset_probes;
        probe_rst_n = 0;
        @(posedge probe_clk);
        probe_rst_n = 1;
        ctrl_en = 1;
        @(posedge probe_clk);
        
        run_memory_intensive(10);
        
        reset_probes;
        @(posedge probe_clk);
        @(posedge probe_clk);
        @(posedge probe_clk);
        probe_execution_done = 1;
        @(posedge probe_clk);
        probe_execution_done = 0;
        
        // Memory ratio should be 100% (100 scaled). Addr 0x1E is metric_mem_ratio
        verify_register(8'h1E, 100, "Memory Intensive: Mem Ratio = 100");
        dump_all_registers("Scenario 2 - Memory Intensive");

        // -----------------------------------------------------------
        // Scenario 3: RAW Hazard (10 cycles stall)
        // -----------------------------------------------------------
        $display("Injecting Scenario 3: RAW Hazard");
        reset_probes;
        probe_rst_n = 0;
        @(posedge probe_clk);
        probe_rst_n = 1;
        ctrl_en = 1;
        @(posedge probe_clk);
        
        run_raw_hazard(10);
        
        reset_probes;
        @(posedge probe_clk);
        @(posedge probe_clk);
        @(posedge probe_clk);
        probe_execution_done = 1;
        @(posedge probe_clk);
        probe_execution_done = 0;
        
        // Addr 0x1B is haz_raw_dist (10 raw hazards / 10 total hazards) = 100%
        verify_register(8'h1B, 100, "RAW Hazard: RAW Dist = 100");
        dump_all_registers("Scenario 3 - RAW Hazard");

        // -----------------------------------------------------------
        // Scenario 4: Load Hazard (10 cycles Load Use stall)
        // -----------------------------------------------------------
        $display("Injecting Scenario 4: Load Hazard");
        reset_probes;
        probe_rst_n = 0;
        @(posedge probe_clk);
        probe_rst_n = 1;
        ctrl_en = 1;
        @(posedge probe_clk);
        
        run_load_hazard(10);
        
        reset_probes;
        @(posedge probe_clk);
        @(posedge probe_clk);
        @(posedge probe_clk);
        probe_execution_done = 1;
        @(posedge probe_clk);
        probe_execution_done = 0;
        
        // Addr 0x1C is haz_ldu_dist (10 load hazards / 10 total hazards) = 100%
        verify_register(8'h1C, 100, "Load Hazard: Load Use Dist = 100");
        dump_all_registers("Scenario 4 - Load Hazard");

        // -----------------------------------------------------------
        // Scenario 5: Control Hazard (10 cycles Branch stall)
        // -----------------------------------------------------------
        $display("Injecting Scenario 5: Control Hazard");
        reset_probes;
        probe_rst_n = 0;
        @(posedge probe_clk);
        probe_rst_n = 1;
        ctrl_en = 1;
        @(posedge probe_clk);
        
        run_control_hazard(10);
        
        reset_probes;
        @(posedge probe_clk);
        @(posedge probe_clk);
        @(posedge probe_clk);
        probe_execution_done = 1;
        @(posedge probe_clk);
        probe_execution_done = 0;
        
        // Addr 0x1D is haz_ctrl_dist (10 ctrl hazards / 10 total hazards) = 100%
        verify_register(8'h1D, 100, "Control Hazard: Control Dist = 100");
        dump_all_registers("Scenario 5 - Control Hazard");

        // -----------------------------------------------------------
        // Scenario 6: Forwarding Enabled (10 cycles FWD success)
        // -----------------------------------------------------------
        $display("Injecting Scenario 6: Forwarding Enabled");
        reset_probes;
        probe_rst_n = 0;
        @(posedge probe_clk);
        probe_rst_n = 1;
        ctrl_en = 1;
        @(posedge probe_clk);
        
        run_fwd_enabled(10);
        
        reset_probes;
        @(posedge probe_clk);
        @(posedge probe_clk);
        @(posedge probe_clk);
        probe_execution_done = 1;
        @(posedge probe_clk);
        probe_execution_done = 0;
        
        // Addr 0x1A is metric_fwd_eff. 10 FWDs / 10 Opportunities = 100%
        verify_register(8'h1A, 100, "FWD Enabled: FWD Eff = 100");
        dump_all_registers("Scenario 6 - Forwarding Enabled");

        // -----------------------------------------------------------
        // Scenario 7: Forwarding Disabled (10 cycles RAW stall, fwd failed)
        // -----------------------------------------------------------
        $display("Injecting Scenario 7: Forwarding Disabled");
        reset_probes;
        probe_rst_n = 0;
        @(posedge probe_clk);
        probe_rst_n = 1;
        ctrl_en = 1;
        @(posedge probe_clk);
        
        run_fwd_disabled(10);
        
        reset_probes;
        @(posedge probe_clk);
        @(posedge probe_clk);
        @(posedge probe_clk);
        probe_execution_done = 1;
        @(posedge probe_clk);
        probe_execution_done = 0;
        
        // Addr 0x1A is metric_fwd_eff. 0 FWDs / 10 Opportunities = 0%
        verify_register(8'h1A, 0, "FWD Disabled: FWD Eff = 0");
        dump_all_registers("Scenario 7 - Forwarding Disabled");

        // -----------------------------------------------------------
        // Scenario 8: Pipeline Flush
        // -----------------------------------------------------------
        $display("Injecting Scenario 8: Pipeline Flush");
        reset_probes;
        probe_rst_n = 0;
        @(posedge probe_clk);
        probe_rst_n = 1;
        ctrl_en = 1;
        @(posedge probe_clk);
        
        run_pipeline_flush;
        
        reset_probes;
        @(posedge probe_clk);
        @(posedge probe_clk);
        @(posedge probe_clk);
        probe_execution_done = 1;
        @(posedge probe_clk);
        probe_execution_done = 0;
        
        // Addr 0x0A is flush_cnt. Should be 1.
        verify_register(8'h0A, 1, "Pipeline Flush: Flush Count = 1");
        dump_all_registers("Scenario 8 - Pipeline Flush");

        // -----------------------------------------------------------
        // Scenario 9: Execution Complete (Registers freeze check)
        // -----------------------------------------------------------
        $display("Injecting Scenario 9: Execution Complete Freeze");
        reset_probes;
        probe_rst_n = 0;
        @(posedge probe_clk);
        probe_rst_n = 1;
        ctrl_en = 1;
        @(posedge probe_clk);
        
        run_normal_program(5);
        
        reset_probes;
        @(posedge probe_clk);
        @(posedge probe_clk);
        @(posedge probe_clk);
        probe_execution_done = 1;
        @(posedge probe_clk);
        probe_execution_done = 0;
        
        // Wait for register bank to freeze
        @(posedge probe_clk);
        @(posedge probe_clk);
        @(posedge probe_clk);
        
        // Now, run more instructions. These should NOT be counted if frozen!
        run_normal_program(10);
        
        // Addr 8'h01 is inst_ret_cnt. It should be 5, not 15!
        verify_register(8'h01, 5, "Execution Complete: Frozen Instruction Count = 5");
        dump_all_registers("Scenario 9 - Execution Complete / Frozen Snapshot");

        // -----------------------------------------------------------
        // Scenario 10: Large Mixed Workload (~10,000 instructions)
        //
        // The previous scenarios each isolate one feature at a time,
        // so most registers read back as 0 in any single snapshot.
        // This scenario drives a long, realistic instruction mix --
        // ALU ops, loads, stores, a taken branch, a RAW hazard, a
        // load-use hazard, and a control-hazard flush, repeated back
        // to back -- so nearly all 32 registers come back non-zero
        // and mutually consistent, the way a real program run would
        // look.
        //
        // 1112 blocks x 9 retiring instructions/block = 10,008
        // instructions retired, over 1112 x 12 = 13,344 driven cycles.
        // -----------------------------------------------------------
        $display("Injecting Scenario 10: Large Mixed Workload (~10,000 instructions)");
        reset_probes;
        probe_rst_n = 0;
        @(posedge probe_clk);
        probe_rst_n = 1;
        ctrl_en = 1;
        cnt_clear = 1;
        @(posedge probe_clk);
        cnt_clear = 0;
        @(posedge probe_clk);

        run_mixed_workload(1112);

        reset_probes;
        @(posedge probe_clk);
        @(posedge probe_clk);
        @(posedge probe_clk);
        probe_execution_done = 1;
        @(posedge probe_clk);
        probe_execution_done = 0;

        // Every one of these is an exact linear function of the 1112
        // blocks driven above -- see run_mixed_workload's header comment
        // for the per-block breakdown.
        verify_register(8'h01, 10008, "Mixed Workload: inst_ret_cnt = 10008");
        verify_register(8'h02, 1112,  "Mixed Workload: branch_cnt = 1112");
        verify_register(8'h03, 1112,  "Mixed Workload: load_cnt = 1112");
        verify_register(8'h04, 1112,  "Mixed Workload: store_cnt = 1112");
        verify_register(8'h05, 1112,  "Mixed Workload: raw_haz_cnt = 1112");
        verify_register(8'h06, 1112,  "Mixed Workload: ldu_haz_cnt = 1112");
        verify_register(8'h07, 1112,  "Mixed Workload: ctrl_haz_cnt = 1112");
        verify_register(8'h08, 3336,  "Mixed Workload: stall_cnt = 3336");
        verify_register(8'h09, 3336,  "Mixed Workload: bubble_cnt = 3336");
        verify_register(8'h0A, 1112,  "Mixed Workload: flush_cnt = 1112");
        verify_register(8'h0B, 3336,  "Mixed Workload: fwd_opp_cnt = 3336");
        verify_register(8'h0C, 2224,  "Mixed Workload: fwd_succ_cnt = 2224");
        verify_register(8'h0D, 10008, "Mixed Workload: if_active_cnt = 10008");
        verify_register(8'h0E, 10008, "Mixed Workload: id_active_cnt = 10008");
        verify_register(8'h0F, 10008, "Mixed Workload: ex_active_cnt = 10008");
        verify_register(8'h10, 2224,  "Mixed Workload: mem_active_cnt = 2224");
        verify_register(8'h11, 8896,  "Mixed Workload: wb_active_cnt = 8896");
        dump_all_registers("Scenario 10 - Large Mixed Workload (~10,000 instructions)");

        // -----------------------------------------------------------
        // Coverage Report Generation
        // -----------------------------------------------------------
        $display("=================================================");
        $display("FUNCTIONAL COVERAGE REPORT");
        $display("=================================================");
        $display("Total Scenarios Hit : 10");
        $display("Total Tests Passed  : %0d", tests_passed);
        $display("Total Tests Failed  : %0d", tests_failed);
        if (tests_failed == 0)
            $display("VERIFICATION STATUS : PASSED");
        else
            $display("VERIFICATION STATUS : FAILED");
        $display("=================================================");

        $finish;
    end

endmodule