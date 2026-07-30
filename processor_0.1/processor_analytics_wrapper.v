module processor_analytics_wrapper(

    input clk,
    input rst,
    input timer_interrupt,

    input  [7:0]  read_addr,
    input         read_en,

    output [31:0] read_data,
    output        read_valid

);

//======================================================
// Processor Signals
//======================================================

// PC Signals
wire [31:0] pc_out_IF;
wire [31:0] pc_out_DE;
wire [31:0] pc_out_MW;
wire [31:0] new_pc;

// Instruction Signals
wire [31:0] inst_IF;
wire [31:0] inst_DE;
wire [31:0] inst_MW;

// Register Address Signals
wire [4:0] waddr;
wire [4:0] rs1_DE;
wire [4:0] rs1_MW;
wire [4:0] rs2_DE;
wire [4:0] rs2_MW;
wire [4:0] rd_DE;
wire [4:0] rd_MW;

// Decoded Instruction Fields
wire [6:0] opcode;
wire [2:0] funct3;
wire [6:0] funct7;

// Register File Data
wire [31:0] rdata1_DE;
wire [31:0] rdata1_MW;
wire [31:0] rdata2_DE;
wire [31:0] rdata2_MW;

// ALU Operand Signals
wire [31:0] opr_a;
wire [31:0] opr_b;

wire [31:0] opr_res_IF;
wire [31:0] opr_res_DE;
wire [31:0] opr_res_MW;

// Immediate
wire [31:0] imm_val_DE;
wire [31:0] imm_val_MW;

// Writeback
wire [31:0] wdata_DE;
wire [31:0] wdata_MW;

// Memory
wire [31:0] rdata;

// Branch
wire br_taken;
wire br_take_IF;
wire br_take_DE;

// ALU Control
wire [3:0] aluop;

// Register File Control
wire rf_en_DE;
wire rf_en_MW;

// ALU Select
wire sel_a;
wire sel_b;

// Memory Control
wire rd_en_DE;
wire rd_en_MW;

wire wr_en_DE;
wire wr_en_MW;

wire [1:0] wb_sel_DE;
wire [1:0] wb_sel_MW;

wire [2:0] mem_acc_mode_DE;
wire [2:0] mem_acc_mode_MW;

// Branch Type
wire [2:0] br_type;

// CSR Control
wire csr_rd_DE;
wire csr_rd_MW;

wire csr_wr_DE;
wire csr_wr_MW;

wire is_mret_DE;
wire is_mret_MW;

// CSR
wire [31:0] csr_rdata;

// EPC
wire [31:0] epc_IF;
wire [31:0] epc_MW;

wire epc_taken_IF;
wire epc_taken_MW;

wire [31:0] epc_pc;

// Forwarding
wire [31:0] forward_opr_a;
wire [31:0] forward_opr_b;

wire forward_a;
wire forward_b;

// Hazard
wire stall_IF;
wire flush_DE;

//======================================================
// Analytics IP Control Signals
//======================================================

wire        ctrl_en;
wire        cnt_clear;
wire        mode_select;

wire [2:0] priv_filter;
wire [7:0] context_filter;
wire       context_filter_en;

//======================================================
// Analytics Probe Signals
//======================================================

wire        probe_instruction_commit;
wire [31:0] probe_opcode;

wire        probe_stall;
wire        probe_flush;

wire        probe_raw_hazard;
wire        probe_load_hazard;
wire        probe_control_hazard;

wire        probe_mem_read;
wire        probe_mem_write;

wire        probe_if_valid;
wire        probe_if_stall;

wire        probe_id_valid;
wire        probe_id_stall;
wire        probe_id_bubble;

wire        probe_ex_valid;
wire        probe_ex_stall;

wire        probe_mem_valid;
wire        probe_mem_stall;

wire        probe_wb_valid;
wire        probe_wb_stall;

wire        probe_fwd_opp;
wire        probe_fwd_success;

wire        probe_execution_done;

wire [1:0] probe_priv_mode;
wire [7:0] probe_context_id;

//======================================================
// Register Read Interface
//======================================================
/*
wire [7:0] read_addr;
wire       read_en;

wire [31:0] read_data;
wire        read_valid;
*/



processor_top cpu (

    .clk(clk),
    .rst(rst),
    .timer_interrupt(timer_interrupt),

    //================ PC =================
    .pc_out_IF(pc_out_IF),
    .pc_out_DE(pc_out_DE),
    .pc_out_MW(pc_out_MW),
    .new_pc(new_pc),

    //============= Instruction ===========
    .inst_IF(inst_IF),
    .inst_DE(inst_DE),
    .inst_MW(inst_MW),

    //========== Register Addresses =======
    .waddr(waddr),
    .rs1_DE(rs1_DE),
    .rs1_MW(rs1_MW),
    .rs2_DE(rs2_DE),
    .rs2_MW(rs2_MW),
    .rd_DE(rd_DE),
    .rd_MW(rd_MW),

    //========== Instruction Decode =======
    .opcode(opcode),
    .funct3(funct3),
    .funct7(funct7),

    //========== Register File ============
    .rdata1_DE(rdata1_DE),
    .rdata1_MW(rdata1_MW),
    .rdata2_DE(rdata2_DE),
    .rdata2_MW(rdata2_MW),

    //============= ALU ===================
    .opr_a(opr_a),
    .opr_b(opr_b),
    .opr_res_IF(opr_res_IF),
    .opr_res_DE(opr_res_DE),
    .opr_res_MW(opr_res_MW),

    //=========== Immediate ===============
    .imm_val_DE(imm_val_DE),
    .imm_val_MW(imm_val_MW),

    //=========== Writeback ===============
    .wdata_DE(wdata_DE),
    .wdata_MW(wdata_MW),

    //=========== Memory ==================
    .rdata(rdata),

    //=========== Branch ==================
    .br_taken(br_taken),
    .br_take_IF(br_take_IF),
    .br_take_DE(br_take_DE),

    //=========== ALU Control =============
    .aluop(aluop),

    //=========== RF Control ==============
    .rf_en_DE(rf_en_DE),
    .rf_en_MW(rf_en_MW),

    //=========== ALU Select ==============
    .sel_a(sel_a),
    .sel_b(sel_b),

    //=========== Memory Control ==========
    .rd_en_DE(rd_en_DE),
    .rd_en_MW(rd_en_MW),
    .wr_en_DE(wr_en_DE),
    .wr_en_MW(wr_en_MW),

    .wb_sel_DE(wb_sel_DE),
    .wb_sel_MW(wb_sel_MW),

    .mem_acc_mode_DE(mem_acc_mode_DE),
    .mem_acc_mode_MW(mem_acc_mode_MW),

    //=========== Branch Type =============
    .br_type(br_type),

    //=========== CSR =====================
    .csr_rd_DE(csr_rd_DE),
    .csr_rd_MW(csr_rd_MW),

    .csr_wr_DE(csr_wr_DE),
    .csr_wr_MW(csr_wr_MW),

    .is_mret_DE(is_mret_DE),
    .is_mret_MW(is_mret_MW),

    .csr_rdata(csr_rdata),

    //=========== EPC =====================
    .epc_IF(epc_IF),
    .epc_MW(epc_MW),
    .epc_taken_IF(epc_taken_IF),
    .epc_taken_MW(epc_taken_MW),
    .epc_pc(epc_pc),

    //========== Forwarding ===============
    .forward_opr_a(forward_opr_a),
    .forward_opr_b(forward_opr_b),
    .forward_a(forward_a),
    .forward_b(forward_b),

    //=========== Hazard ==================
    .stall_IF(stall_IF),
    .flush_DE(flush_DE)

);
    analytics_top u_analytics (

    //====================================================
    // Clock & Reset
    //====================================================
    .probe_clk               (clk),
    .probe_rst_n             (~rst),

    //====================================================
    // Control Inputs
    //====================================================
    .ctrl_en                 (ctrl_en),
    .cnt_clear               (cnt_clear),
    .mode_select             (mode_select),
    .priv_filter             (priv_filter),
    .context_filter          (context_filter),
    .context_filter_en       (context_filter_en),

    //====================================================
    // CPU Probe Signals
    //====================================================
    .probe_instruction_commit(probe_instruction_commit),
    .probe_opcode            (probe_opcode),
    .probe_stall             (probe_stall),
    .probe_flush             (probe_flush),

    .probe_raw_hazard        (probe_raw_hazard),
    .probe_load_hazard       (probe_load_hazard),
    .probe_control_hazard    (probe_control_hazard),

    .probe_mem_read          (probe_mem_read),
    .probe_mem_write         (probe_mem_write),

    .probe_if_valid          (probe_if_valid),
    .probe_if_stall          (probe_if_stall),

    .probe_id_valid          (probe_id_valid),
    .probe_id_stall          (probe_id_stall),
    .probe_id_bubble         (probe_id_bubble),

    .probe_ex_valid          (probe_ex_valid),
    .probe_ex_stall          (probe_ex_stall),

    .probe_mem_valid         (probe_mem_valid),
    .probe_mem_stall         (probe_mem_stall),

    .probe_wb_valid          (probe_wb_valid),
    .probe_wb_stall          (probe_wb_stall),

    .probe_fwd_opp           (probe_fwd_opp),
    .probe_fwd_success       (probe_fwd_success),

    .probe_execution_done    (probe_execution_done),

    .probe_priv_mode         (probe_priv_mode),
    .probe_context_id        (probe_context_id),

    //====================================================
    // Register Read Interface
    //====================================================
    .read_addr               (read_addr),
    .read_en                 (read_en),
    .read_data               (read_data),
    .read_valid              (read_valid)

);

//======================================================
// Analytics Control Assignments
//======================================================

assign ctrl_en             = 1'b1;
assign cnt_clear           = 1'b0;
assign mode_select         = 1'b1;
assign priv_filter         = 3'b000;
assign context_filter      = 8'h00;
assign context_filter_en   = 1'b0;

//======================================================
// Processor -> Analytics IP Assignments
//======================================================

assign probe_instruction_commit =
    rf_en_MW &&
    (inst_MW != 32'h00000013);
assign probe_opcode             = inst_MW;

assign probe_stall              = stall_IF;
assign probe_flush              = flush_DE;

assign probe_raw_hazard         = forward_a | forward_b;
assign probe_load_hazard        = stall_IF;
assign probe_control_hazard     = flush_DE;

assign probe_mem_read           = rd_en_MW;
assign probe_mem_write          = wr_en_MW;

assign probe_if_valid           = ~stall_IF;
assign probe_if_stall           = stall_IF;

assign probe_id_valid           = ~flush_DE;
assign probe_id_stall           = stall_IF;
assign probe_id_bubble          = flush_DE;

assign probe_ex_valid           = 1'b1;
assign probe_ex_stall           = 1'b0;

assign probe_mem_valid          = rd_en_MW | wr_en_MW;
assign probe_mem_stall          = 1'b0;

assign probe_wb_valid           = rf_en_MW;
assign probe_wb_stall           = 1'b0;

assign probe_fwd_opp            = forward_a | forward_b;
assign probe_fwd_success        = forward_a | forward_b;

assign probe_execution_done = (inst_MW == 32'h00000013);
assign probe_priv_mode          = 2'b11;
assign probe_context_id         = 8'h00;
/*
assign read_addr                = 8'h00;
assign read_en                  = 1'b0;
*/
//assign debug_pc = pc_out_IF;

endmodule