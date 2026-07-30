module processor_top(

    input         clk,
    input         rst,
    input         timer_interrupt,

    //======================================================
// PC Signals
//======================================================
output [31:0] pc_out_IF,
output reg [31:0] pc_out_DE,
output reg [31:0] pc_out_MW,
output [31:0] new_pc,

//======================================================
// Instruction Signals
//======================================================
output [31:0] inst_IF,
output reg [31:0] inst_DE,
output reg [31:0] inst_MW,

//======================================================
// Register Address Signals
//======================================================
output reg [4:0]  waddr,

output [4:0]  rs1_DE,
output reg [4:0]  rs1_MW,

output [4:0]  rs2_DE,
output reg [4:0]  rs2_MW,

output [4:0]  rd_DE,
output reg [4:0] rd_MW,

//======================================================
// Decoded Instruction Fields
//======================================================
output [6:0]  opcode,
output [2:0]  funct3,
output [6:0]  funct7,

//======================================================
// Register File Data
//======================================================
output [31:0] rdata1_DE,
output reg [31:0] rdata1_MW,

output [31:0] rdata2_DE,
output reg [31:0] rdata2_MW,

//======================================================
// ALU Operand Signals
//======================================================
output [31:0] opr_a,
output [31:0] opr_b,

output reg [31:0] opr_res_IF,
output [31:0] opr_res_DE,
output reg [31:0] opr_res_MW,

//======================================================
// Immediate
//======================================================
output [31:0] imm_val_DE,
output reg [31:0] imm_val_MW,

//======================================================
// Writeback Signals
//======================================================
output reg [31:0] wdata_DE,
output [31:0] wdata_MW,

//======================================================
// Memory Signals
//======================================================
output [31:0] rdata,

//======================================================
// Branch Signals
//======================================================
output        br_taken,
output   reg     br_take_IF,
output        br_take_DE,

//======================================================
// ALU Control
//======================================================
output [3:0] aluop,

//======================================================
// Register File Control
//======================================================
output        rf_en_DE,
output reg    rf_en_MW,

//======================================================
// ALU Select
//======================================================
output        sel_a,
output        sel_b,

//======================================================
// Memory Control
//======================================================
output        rd_en_DE,
output reg    rd_en_MW,

output        wr_en_DE,
output reg    wr_en_MW,

output [1:0] wb_sel_DE,
output reg [1:0] wb_sel_MW,

output [2:0] mem_acc_mode_DE,
output reg [2:0] mem_acc_mode_MW,

//======================================================
// Branch Type
//======================================================
output [2:0] br_type,

//======================================================
// CSR Control
//======================================================
output        csr_rd_DE,
output reg    csr_rd_MW,

output        csr_wr_DE,
output reg    csr_wr_MW,

output        is_mret_DE,
output reg    is_mret_MW,

//======================================================
// CSR Signals
//======================================================
output [31:0] csr_rdata,

//======================================================
// EPC Signals
//======================================================
output reg [31:0] epc_IF,
output [31:0] epc_MW,

output     reg   epc_taken_IF,
output        epc_taken_MW,

output [31:0] epc_pc,

//======================================================
// Forwarding Signals
//======================================================
output reg [31:0] forward_opr_a,
output reg [31:0] forward_opr_b,

output        forward_a,
output        forward_b,

//======================================================
// Hazard Signals
//======================================================
output        stall_IF,
output        flush_DE

);
    // wires
/*
    // pc_out
 // wire [31:0] pc_out_IF;
    reg [31:0] pc_out_DE;
    reg [31:0] pc_out_MW;

    wire [31:0] new_pc;

    // inst
 //   wire [31:0] inst_IF;
    reg [31:0] inst_DE;
    reg [31:0] inst_MW;

    reg [ 4:0] waddr;

    // rs1
 //   wire [ 4:0] rs1_DE;
    reg [ 4:0] rs1_MW;

    // rs2
 //   wire [ 4:0] rs2_DE;
    reg [ 4:0] rs2_MW;

    // rd
 //   wire [ 4:0] rd_DE;
 //   reg [ 4:0] rd_MW;

    wire [ 6:0] opcode;
    wire [ 2:0] funct3;
    wire [ 6:0] funct7;

    // rdata1
    wire [31:0] rdata1_DE;
    reg [31:0] rdata1_MW;

    // rdata2
    wire [31:0] rdata2_DE;
    reg [31:0] rdata2_MW;

    wire [31:0] opr_a;
    wire [31:0] opr_b;

    // opr_res
    reg [31:0] opr_res_IF;
    wire [31:0] opr_res_DE;
    reg [31:0] opr_res_MW;

    // imm_val
 //   wire [31:0] imm_val_DE;
    reg [31:0] imm_val_MW;

    // wdata
    reg [31:0] wdata_DE;
    wire [31:0] wdata_MW;

    wire [31:0] rdata;
    wire        br_taken;
    wire [3 :0] aluop;

    // rf_en
 //   wire        rf_en_DE;
 //   reg        rf_en_MW;

    wire        sel_a;
    wire        sel_b;

    // rd_en
  //  wire        rd_en_DE;
    reg        rd_en_MW;

    // wr_en
 //   wire        wr_en_DE;
    reg        wr_en_MW;

    // wb_sel
   // wire [ 1:0] wb_sel_DE;
    reg [ 1:0] wb_sel_MW;

    // mem_acc_mode
    wire [ 2:0] mem_acc_mode_DE;
    reg [ 2:0] mem_acc_mode_MW;

    wire [ 2:0] br_type;

    // br_take
    reg        br_take_IF;
    wire        br_take_DE;

    // csr_rd
 //   wire       csr_rd_DE;
    reg        csr_rd_MW;
    
    // csr_wr
 //   wire        csr_wr_DE;
    reg        csr_wr_MW;

    // is_mret
 //   wire      is_mret_DE;
    reg        is_mret_MW;

    wire [31:0] csr_rdata;

    // epc
    reg [31:0] epc_IF;
    wire [31:0] epc_MW;

    // epc_taken
    reg        epc_taken_IF;
    wire        epc_taken_MW;

    wire [31:0] epc_pc;
    reg [31:0] forward_opr_a;
    reg [31:0] forward_opr_b;
 //   wire        forward_a;
//    wire        forward_b;
 //   wire        stall_IF;
 //   wire        flush_DE;
*/
    // --------------------- Instruction Fetch (IF) ---------------------

    // PC MUX
    mux_2x1 mux_2x1_pc
    (
        // inputs
        .in_0        ( pc_out_IF + 32'd4 ),
        .in_1        ( opr_res_DE        ),
        .select_line ( br_take_DE        ),

        // outputs
        .out         ( new_pc            )
    );

    mux_2x1 mux_2x1_epc
    (
        // inputs
        .in_0        ( new_pc       ),
        .in_1        ( epc_IF       ),
        .select_line ( epc_taken_IF ),

        // outputs
        .out         ( epc_pc       ) 
    );

    // program counter
    pc pc_i
    (
        // inputs
        .clk   ( clk            ),
        .rst   ( rst            ),
        .en    ( ~stall_IF      ),
        .pc_in ( epc_pc         ),

        //outputs
        .pc_out( pc_out_IF      )
    );

    // instruction memory
    inst_mem inst_mem_i
    (
        // inputs
        .addr  ( pc_out_IF      ),

        // outputs
        .data  ( inst_IF        )
    );

    // ---------------------------------------------------------------

    // IF <-> DE Buffer
    always @( posedge clk ) 
    begin
        if ( rst )
        begin
            pc_out_DE <= 0;
            inst_DE   <= 0;
        end
        else if ( flush_DE )
        begin
            inst_DE   <= 32'h00000013;
            pc_out_DE <= 0;
        end
        else
        begin
            pc_out_DE <= pc_out_IF; // PC 
            inst_DE   <= inst_IF;   // instruction 
        end
    end

    // --------------------- Decode-Execute (DE) ---------------------

    // instruction decoder
    inst_dec inst_dec_i
    (
        // inputs
        .inst  ( inst_DE        ),

        // outputs
        .rs1   ( rs1_DE         ),
        .rs2   ( rs2_DE         ),
        .rd    ( rd_DE          ),
        .opcode( opcode         ),
        .funct3( funct3         ),
        .funct7( funct7         )
    );

    // register file
    reg_file reg_file_i
    (
        // inputs
        .clk   ( clk            ),
        .rf_en ( rf_en_MW       ),
        .rs1   ( rs1_DE         ),
        .rs2   ( rs2_DE         ),
        .rd    ( waddr          ),
        .wdata ( wdata_DE       ),

        // outputs
        .rdata1( rdata1_DE      ),
        .rdata2( rdata2_DE      )
    );

    // controller
    controller controller_i
    (
        // inputs
        .opcode         ( opcode          ),
        .funct3         ( funct3          ),
        .funct7         ( funct7          ),
        .br_taken       ( br_taken        ),

        // outputs
        .aluop          ( aluop           ),
        .rf_en          ( rf_en_DE        ),
        .sel_a          ( sel_a           ),
        .sel_b          ( sel_b           ),
        .rd_en          ( rd_en_DE        ),
        .wr_en          ( wr_en_DE        ),
        .wb_sel         ( wb_sel_DE       ),
        .mem_acc_mode   ( mem_acc_mode_DE ),
        .br_type        ( br_type         ),
        .br_take        ( br_take_DE      ),
        .csr_rd         ( csr_rd_DE       ),
        .csr_wr         ( csr_wr_DE       ),
        .is_mret        ( is_mret_DE      )
    );

    // immediate generator
    imm_gen imm_gen_i
    (
        // inputs
        .inst   ( inst_DE       ),

        // outputs
        .imm_val( imm_val_DE    )
    );

    // forward_a
    always @(*)
    begin
        if (forward_a)
        begin
            if (rf_en_MW)
            begin
                forward_opr_a = opr_res_MW;
            end
            else
            begin
                forward_opr_a = 0;
            end
        end
        else
        begin
            forward_opr_a = rdata1_DE;
        end
    end

    // forward_b
    always @(*)
    begin
        if (forward_b)
        begin
            if (rf_en_MW)
            begin
                forward_opr_b = opr_res_MW;
            end
            else
            begin
                forward_opr_b = 0;
            end
        end
        else
        begin
            forward_opr_b = rdata2_DE;
        end
    end

    // ALU opr_a MUX
    mux_2x1 mux_2x1_alu_opr_a
    (
        // inputs
        .in_0           ( pc_out_DE     ),
        .in_1           ( forward_opr_a ),
        .select_line    ( sel_a         ),

        // outputs
        .out            ( opr_a         )
    );

    // ALU opr_b MUX
    mux_2x1 mux_2x1_alu_opr_b
    (
        // inputs
        .in_0           ( forward_opr_b ),
        .in_1           ( imm_val_DE    ),
        .select_line    ( sel_b         ),

        // outputs
        .out            ( opr_b         )
    );

    // ALU
    alu alu_i
    (
        // inputs
        .aluop   ( aluop          ),
        .opr_a   ( opr_a          ),
        .opr_b   ( opr_b          ),

        // outputs
        .opr_res ( opr_res_DE     )
    );

    // br_cond
    br_cond br_cond_i
    (
        // inputs
       .rdata1(forward_opr_a),
.rdata2(forward_opr_b),
        .br_type  ( br_type   ),

        // outputs
        .br_taken ( br_taken  )
    );

    // ---------------------------------------------------------------
  /*  
    // Feedback to IF stage
 always @(posedge clk)
begin
    if (rst)
    begin
        br_take_IF <= 1'b0;
        opr_res_IF <= 32'd0;
    end
    else
    begin
        br_take_IF <= br_take_DE;
        opr_res_IF <= opr_res_DE;
    end
end
*/
    // DE <-> MEM-WB Buffer
    always @ ( posedge clk )
    begin
        if ( rst )
        begin
            pc_out_MW       <= 0;
            inst_MW         <= 0;
            opr_res_MW      <= 0;
            rdata1_MW       <= 0;
            rdata2_MW       <= 0;
            imm_val_MW      <= 0;
            rs1_MW          <= 0;
            rs2_MW          <= 0;
            rd_MW           <= 0;

            // control signals
            rf_en_MW        <= 0;
            rd_en_MW        <= 0;
            wr_en_MW        <= 0;
            mem_acc_mode_MW <= 0;
            csr_rd_MW       <= 0;
            csr_wr_MW       <= 0;
            is_mret_MW      <= 0;
            wb_sel_MW       <= 0;
        end
        else
        begin
            pc_out_MW       <= pc_out_DE;
            inst_MW         <= inst_DE;
            opr_res_MW      <= opr_res_DE;
            rdata1_MW       <= rdata1_DE;
            rdata2_MW       <= rdata2_DE;
            imm_val_MW      <= imm_val_DE;
            rs1_MW          <= rs1_DE;
            rs2_MW          <= rs2_DE;
            rd_MW           <= rd_DE;

            // control signals
            rf_en_MW        <= rf_en_DE;
            rd_en_MW        <= rd_en_DE;
            wr_en_MW        <= wr_en_DE;
            mem_acc_mode_MW <= mem_acc_mode_DE;
            csr_rd_MW       <= csr_rd_DE;
            csr_wr_MW       <= csr_wr_DE;
            is_mret_MW      <= is_mret_DE;
            wb_sel_MW       <= wb_sel_DE;
        end
    end

    // ----------------------- Memory-Writeback ----------------------

    // data memory
    data_mem data_mem_i
    (
        // inputs
        .clk            ( clk             ),
        .rd_en          ( rd_en_MW        ),
        .wr_en          ( wr_en_MW        ),
        .addr           ( opr_res_MW      ),
        .mem_acc_mode   ( mem_acc_mode_MW ),
        .wdata          ( rdata2_MW       ),

        // outputs
        .rdata          ( rdata           )
    );

    // csr 
    csr_reg csr_reg_i
    (
        // inputs
        .clk       ( clk             ),
        .rst       ( rst             ),
        .addr      ( imm_val_MW      ),
        .wdata     ( rdata1_MW       ),
        .pc        ( pc_out_MW       ),
        .trap      ( timer_interrupt ),
        .csr_rd    ( csr_rd_MW       ),
        .csr_wr    ( csr_wr_MW       ),
        .is_mret   ( is_mret_MW      ),
        .inst      ( inst_MW         ),

        // outputs
        .rdata     ( csr_rdata       ),
        .epc       ( epc_MW          ),
        .epc_taken ( epc_taken_MW    )
    );

    // Writeback MUX
    mux_4x1 wb_mux
    (
        // inputs
        .in_0           ( pc_out_MW + 32'd4 ),
        .in_1           ( opr_res_MW        ),
        .in_2           ( rdata             ),
        .in_3           ( csr_rdata         ),
        .select_line    ( wb_sel_MW         ),

        // outputs
        .out            ( wdata_MW          )
    );

    // ---------------------------------------------------------------

    // Feedback to IF stage
   always @(posedge clk)
begin
    if (rst)
    begin
        epc_IF       <= 32'd0;
        epc_taken_IF <= 1'b0;
    end
    else
    begin
        epc_IF       <= epc_MW;
        epc_taken_IF <= epc_taken_MW;
    end
end

    // Feedback to DE stage
    always @(*)
    begin
        waddr        = inst_MW[11:7];
        wdata_DE     = wdata_MW;
    end

    // ---------------------------------------------------------------

    // ------------------------- Hazard Unit -------------------------
    hazard_unit hazard_unit_i
    (
        // FORWARDING
        // inputs
        .rs1_DE    ( rs1_DE     ),
        .rs2_DE    ( rs2_DE     ),
        .rd_MW     ( rd_MW      ),
        .rf_en_MW  ( rf_en_MW   ),
        // outputs
        .forward_a ( forward_a  ),
        .forward_b ( forward_b  ),

        // STALLING & FLUSHING
        // inputs
        .inst_IF   ( inst_IF    ),
        .rd_DE     ( rd_DE      ),
        .wb_sel_DE ( wb_sel_DE  ),
        .br_taken  ( br_take_DE ),
        // outputs
        .stall_IF  ( stall_IF   ),
        .flush_DE  ( flush_DE   )
    );
    
endmodule



