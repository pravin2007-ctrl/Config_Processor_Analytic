// =============================================================================
// Company:        ASIC soft IP
// Engineer:       Senior ASIC Architect
// 
// Create Date:    July 15, 2026
// Design Name:    Configurable Processor Analytics Soft IP
// Module Name:    event_collector
// Project Name:   Configurable Processor Analytics Soft IP
// Target Devices: ASIC / FPGA
// Tool Versions:  Synthesizable Verilog-2001
// Description:    This module registers CPU probe signals for timing isolation,
//                 gates events based on privilege and context filters,
//                 classifies instruction opcodes, and outputs clean strobes.
//
// Dependencies:   None
// =============================================================================

`timescale 1ns / 1ps

module event_collector (
    probe_clk,
    probe_rst_n,
    ctrl_en,
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
    ev_execution_done
);

    parameter G_OPCODE_WIDTH  = 32;
    parameter G_ISSUE_WIDTH   = 1;
    parameter G_PRIV_WIDTH    = 2;
    parameter G_CONTEXT_WIDTH = 8;

    // Clocks and Resets
    input  wire                         probe_clk;
    input  wire                         probe_rst_n;

    // Gating Control Inputs
    input  wire                         ctrl_en;
    input  wire [2:0]                   priv_filter;        // [0]=User, [1]=Supervisor, [2]=Machine
    input  wire [G_CONTEXT_WIDTH-1:0]   context_filter;
    input  wire                         context_filter_en;

    // Probes from Wrapper
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

    // Gated Event Outputs
    output reg  [G_ISSUE_WIDTH-1:0]     ev_inst_retired;
    output reg                          ev_branch_retired;
    output reg                          ev_load_retired;
    output reg                          ev_store_retired;
    output reg                          ev_raw_hazard_cycle;
    output reg                          ev_ldu_hazard_cycle;
    output reg                          ev_ctrl_hazard_cycle;
    output reg                          ev_stall_cycle;
    output reg                          ev_bubble_cycle;
    output reg                          ev_flush_event;
    output reg                          ev_fwd_opp;
    output reg                          ev_fwd_success;
    output reg                          ev_if_active_cycle;
    output reg                          ev_id_active_cycle;
    output reg                          ev_ex_active_cycle;
    output reg                          ev_mem_active_cycle;
    output reg                          ev_wb_active_cycle;
    output reg                          ev_execution_done;

    // =========================================================================
    // 1. Input Registers for Timing Isolation (ASIC pipeline barrier)
    // =========================================================================
    reg [G_ISSUE_WIDTH-1:0]     r_instruction_commit;
    reg [G_OPCODE_WIDTH-1:0]    r_opcode;
    reg                         r_stall;
    reg                         r_flush;
    reg                         r_raw_hazard;
    reg                         r_load_hazard;
    reg                         r_control_hazard;
    reg                         r_mem_read;
    reg                         r_mem_write;
    reg                         r_if_valid;
    reg                         r_if_stall;
    reg                         r_id_valid;
    reg                         r_id_stall;
    reg                         r_id_bubble;
    reg                         r_ex_valid;
    reg                         r_ex_stall;
    reg                         r_mem_valid;
    reg                         r_mem_stall;
    reg                         r_wb_valid;
    reg                         r_wb_stall;
    reg                         r_fwd_opp;
    reg                         r_fwd_success;
    reg                         r_execution_done;
    reg [G_PRIV_WIDTH-1:0]      r_priv_mode;
    reg [G_CONTEXT_WIDTH-1:0]   r_context_id;

    always @(posedge probe_clk or negedge probe_rst_n) begin
        if (!probe_rst_n) begin
            r_instruction_commit <= {G_ISSUE_WIDTH{1'b0}};
            r_opcode             <= {G_OPCODE_WIDTH{1'b0}};
            r_stall              <= 1'b0;
            r_flush              <= 1'b0;
            r_raw_hazard         <= 1'b0;
            r_load_hazard        <= 1'b0;
            r_control_hazard     <= 1'b0;
            r_mem_read           <= 1'b0;
            r_mem_write          <= 1'b0;
            r_if_valid           <= 1'b0;
            r_if_stall           <= 1'b0;
            r_id_valid           <= 1'b0;
            r_id_stall           <= 1'b0;
            r_id_bubble          <= 1'b0;
            r_ex_valid           <= 1'b0;
            r_ex_stall           <= 1'b0;
            r_mem_valid          <= 1'b0;
            r_mem_stall          <= 1'b0;
            r_wb_valid           <= 1'b0;
            r_wb_stall           <= 1'b0;
            r_fwd_opp            <= 1'b0;
            r_fwd_success        <= 1'b0;
            r_execution_done     <= 1'b0;
            r_priv_mode          <= {G_PRIV_WIDTH{1'b0}};
            r_context_id         <= {G_CONTEXT_WIDTH{1'b0}};
        end else begin
            r_instruction_commit <= probe_instruction_commit;
            r_opcode             <= probe_opcode;
            r_stall              <= probe_stall;
            r_flush              <= probe_flush;
            r_raw_hazard         <= probe_raw_hazard;
            r_load_hazard        <= probe_load_hazard;
            r_control_hazard     <= probe_control_hazard;
            r_mem_read           <= probe_mem_read;
            r_mem_write          <= probe_mem_write;
            r_if_valid           <= probe_if_valid;
            r_if_stall           <= probe_if_stall;
            r_id_valid           <= probe_id_valid;
            r_id_stall           <= probe_id_stall;
            r_id_bubble          <= probe_id_bubble;
            r_ex_valid           <= probe_ex_valid;
            r_ex_stall           <= probe_ex_stall;
            r_mem_valid          <= probe_mem_valid;
            r_mem_stall          <= probe_mem_stall;
            r_wb_valid           <= probe_wb_valid;
            r_wb_stall           <= probe_wb_stall;
            r_fwd_opp            <= probe_fwd_opp;
            r_fwd_success        <= probe_fwd_success;
            r_execution_done     <= probe_execution_done;
            r_priv_mode          <= probe_priv_mode;
            r_context_id         <= probe_context_id;
        end
    end

    // =========================================================================
    // 2. Opcode Classifier (Modular RISC-V Decoding)
    // =========================================================================
    wire [6:0] opcode_7b = r_opcode[6:0];
    
    // Check if it is a compressed instruction (16-bit)
    wire is_rvc = (r_opcode[1:0] != 2'b11);
    wire [2:0] rvc_funct3 = r_opcode[15:13];

    // RISC-V 32-bit Opcode Classes:
    // 7'b1100011 -> Branch (BEQ, BNE, BLT, BGE, etc.)
    // 7'b1101111 -> JAL (Jump and Link)
    // 7'b1100111 -> JALR (Jump and Link Register)
    // 7'b0000011 -> Load (LB, LH, LW, LBU, LHU)
    // 7'b0100011 -> Store (SB, SH, SW)
    
    // RISC-V 16-bit RVC Opcode Classes:
    // op = 2'b00:
    //   funct3 == 3'b010 -> C.LW
    //   funct3 == 3'b110 -> C.SW
    // op = 2'b01:
    //   funct3 == 3'b110 -> C.BEQZ
    //   funct3 == 3'b111 -> C.BNEZ
    //   funct3 == 3'b101 -> C.J
    //   funct3 == 3'b001 -> C.JAL (RV32 only)
    // op = 2'b10:
    //   funct3 == 3'b010 -> C.LWSP
    //   funct3 == 3'b110 -> C.SWSP
    //   funct3 == 3'b100 && r_opcode[6:2] == 5'b00000 -> C.JR / C.JALR
    
    wire rvc_branch = is_rvc && (
                          (r_opcode[1:0] == 2'b01 && (rvc_funct3 == 3'b110 || rvc_funct3 == 3'b111 || rvc_funct3 == 3'b101 || rvc_funct3 == 3'b001)) ||
                          (r_opcode[1:0] == 2'b10 && rvc_funct3 == 3'b100 && r_opcode[6:2] == 5'b00000)
                      );
    wire rvc_load   = is_rvc && (
                          (r_opcode[1:0] == 2'b00 && rvc_funct3 == 3'b010) ||
                          (r_opcode[1:0] == 2'b10 && rvc_funct3 == 3'b010)
                      );
    wire rvc_store  = is_rvc && (
                          (r_opcode[1:0] == 2'b00 && rvc_funct3 == 3'b110) ||
                          (r_opcode[1:0] == 2'b10 && rvc_funct3 == 3'b110)
                      );

    wire is_branch = (!is_rvc && ((opcode_7b == 7'b1100011) || (opcode_7b == 7'b1101111) || (opcode_7b == 7'b1100111))) || rvc_branch;
    wire is_load   = (!is_rvc && (opcode_7b == 7'b0000011)) || rvc_load;
    wire is_store  = (!is_rvc && (opcode_7b == 7'b0100011)) || rvc_store;

    // =========================================================================
    // 3. Filter Matching & Gating
    // =========================================================================
    wire priv_match = (r_priv_mode == 2'b00 && priv_filter[0]) || // User mode
                      (r_priv_mode == 2'b01 && priv_filter[1]) || // Supervisor mode
                      (r_priv_mode == 2'b11 && priv_filter[2]);   // Machine mode
                      
    wire context_match = (!context_filter_en) || (r_context_id == context_filter);
    
    wire active = ctrl_en && priv_match && context_match;

    // =========================================================================
    // 4. Output Register Generation (Clean registered output boundary)
    // =========================================================================
    always @(posedge probe_clk or negedge probe_rst_n) begin
        if (!probe_rst_n) begin
            ev_inst_retired      <= {G_ISSUE_WIDTH{1'b0}};
            ev_branch_retired    <= 1'b0;
            ev_load_retired      <= 1'b0;
            ev_store_retired     <= 1'b0;
            ev_raw_hazard_cycle  <= 1'b0;
            ev_ldu_hazard_cycle  <= 1'b0;
            ev_ctrl_hazard_cycle <= 1'b0;
            ev_stall_cycle       <= 1'b0;
            ev_bubble_cycle      <= 1'b0;
            ev_flush_event       <= 1'b0;
            ev_fwd_opp           <= 1'b0;
            ev_fwd_success       <= 1'b0;
            ev_if_active_cycle   <= 1'b0;
            ev_id_active_cycle   <= 1'b0;
            ev_ex_active_cycle   <= 1'b0;
            ev_mem_active_cycle  <= 1'b0;
            ev_wb_active_cycle   <= 1'b0;
            ev_execution_done    <= 1'b0;
        end else begin
            if (active) begin
                ev_inst_retired      <= r_instruction_commit;
                ev_branch_retired    <= (|r_instruction_commit) && is_branch;
                ev_load_retired      <= (|r_instruction_commit) && is_load;
                ev_store_retired     <= (|r_instruction_commit) && is_store;
                ev_raw_hazard_cycle  <= r_raw_hazard;
                ev_ldu_hazard_cycle  <= r_load_hazard;
                ev_ctrl_hazard_cycle <= r_control_hazard;
                ev_stall_cycle       <= r_stall;
                ev_bubble_cycle      <= r_id_bubble;
                ev_flush_event       <= r_flush;
                ev_fwd_opp           <= r_fwd_opp;
                ev_fwd_success       <= r_fwd_success;
                ev_if_active_cycle   <= r_if_valid && !r_if_stall;
                ev_id_active_cycle   <= r_id_valid && !r_id_stall;
                ev_ex_active_cycle   <= r_ex_valid && !r_ex_stall;
                ev_mem_active_cycle  <= r_mem_valid && !r_mem_stall;
                ev_wb_active_cycle   <= r_wb_valid && !r_wb_stall;
                ev_execution_done    <= r_execution_done;
            end else begin
                ev_inst_retired      <= {G_ISSUE_WIDTH{1'b0}};
                ev_branch_retired    <= 1'b0;
                ev_load_retired      <= 1'b0;
                ev_store_retired     <= 1'b0;
                ev_raw_hazard_cycle  <= 1'b0;
                ev_ldu_hazard_cycle  <= 1'b0;
                ev_ctrl_hazard_cycle <= 1'b0;
                ev_stall_cycle       <= 1'b0;
                ev_bubble_cycle      <= 1'b0;
                ev_flush_event       <= 1'b0;
                ev_fwd_opp           <= 1'b0;
                ev_fwd_success       <= 1'b0;
                ev_if_active_cycle   <= 1'b0;
                ev_id_active_cycle   <= 1'b0;
                ev_ex_active_cycle   <= 1'b0;
                ev_mem_active_cycle  <= 1'b0;
                ev_wb_active_cycle   <= 1'b0;
                ev_execution_done    <= 1'b0;
            end
        end
    end

endmodule
