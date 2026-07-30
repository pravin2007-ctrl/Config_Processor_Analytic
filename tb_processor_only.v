// ============================================================
// tb_processor_complete.v
// Self-contained testbench for the 3-stage pipelined RV32I core
// (processor_top : IF -> DE -> MW)
//
// NOTES ON THIS DUT (learned by probing the RTL with iverilog
// before writing this file -- see comments inline):
//
//   1. Memory is NOT loaded from inst.mem/dm.mem. Instructions and
//      data are written directly into the DUT's internal arrays
//      from this testbench:
//          dut.inst_mem_i.mem[word_index]      <= instruction
//          dut.data_mem_i.data_mem[byte_addr]  <= byte value
//      exactly like the reference testbench built its own `mem[]`
//      array, except here the array lives inside the DUT itself.
//
//   2. reg_file has NO reset. x0 is only "zero" because the RTL
//      skips writes when rd==0 -- the array itself is never
//      cleared. This testbench force-clears reg_mem[0:31] = 0
//      before every test (acting as the missing reset).
//
//   3. data_mem is byte addressed with only 7 bits of the address
//      used (addr[6:0]), so its visible window is bytes 0-127.
//      Storage is BIG-ENDIAN (MSB at the lower address). All test
//      addresses below are kept inside 0-124.
//
//   4. imm_gen has no case for AUIPC's opcode (7'b0010111) -- only
//      LUI's opcode is handled in the U-type branch. This means
//      AUIPC silently reuses whatever imm_val was latched by the
//      previous instruction instead of computing PC+immediate.
//      The AUIPC tests below encode the CORRECT RISC-V expected
//      values, so they are expected to FAIL until that case is
//      added to imm_gen.v. This is flagged again at the test site.
//
//   5. Load immediates (opcode 0000011) are zero-extended in
//      imm_gen instead of sign-extended, so only non-negative load
//      offsets are used in these tests (matches intended ISA
//      behavior for the offsets chosen; a negative-offset load
//      would expose this separately).
//
//   7. ALU BUG: aluop 4'b0011 (SLT) is implemented as a plain
//      unsigned `opr_a < opr_b` instead of a $signed compare, so
//      it behaves identically to SLTU instead of doing a signed
//      less-than. The signed-SLT test below encodes the CORRECT
//      RISC-V expected result and is expected to FAIL until
//      alu.v's SLT case uses $signed(opr_a) < $signed(opr_b).
//
//   6. Verified empirically: PC=0 IS fetched (nothing is skipped
//      after reset); a taken branch/JAL/JALR flushes exactly the
//      one instruction that was already in IF (so the classic
//      "+8 skips the next instruction" pattern applies); a load
//      immediately followed by a dependent instruction is stalled
//      for exactly one cycle and then forwarded correctly.
// ============================================================

`timescale 1ns/1ps

module tb_processor_only;

    reg clk, rst, timer_interrupt;
    integer i;
    integer pass_count, fail_count;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------
    processor_top dut (
        .clk             (clk),
        .rst             (rst),
        .timer_interrupt (timer_interrupt),

        .pc_out_IF(), .pc_out_DE(), .pc_out_MW(), .new_pc(),
        .inst_IF(), .inst_DE(), .inst_MW(),
        .waddr(), .rs1_DE(), .rs1_MW(), .rs2_DE(), .rs2_MW(), .rd_DE(), .rd_MW(),
        .opcode(), .funct3(), .funct7(),
        .rdata1_DE(), .rdata1_MW(), .rdata2_DE(), .rdata2_MW(),
        .opr_a(), .opr_b(), .opr_res_IF(), .opr_res_DE(), .opr_res_MW(),
        .imm_val_DE(), .imm_val_MW(),
        .wdata_DE(), .wdata_MW(),
        .rdata(),
        .br_taken(), .br_take_IF(), .br_take_DE(),
        .aluop(),
        .rf_en_DE(), .rf_en_MW(),
        .sel_a(), .sel_b(),
        .rd_en_DE(), .rd_en_MW(),
        .wr_en_DE(), .wr_en_MW(),
        .wb_sel_DE(), .wb_sel_MW(),
        .mem_acc_mode_DE(), .mem_acc_mode_MW(),
        .br_type(),
        .csr_rd_DE(), .csr_rd_MW(),
        .csr_wr_DE(), .csr_wr_MW(),
        .is_mret_DE(), .is_mret_MW(),
        .csr_rdata(),
        .epc_IF(), .epc_MW(),
        .epc_taken_IF(), .epc_taken_MW(),
        .epc_pc(),
        .forward_opr_a(), .forward_opr_b(),
        .forward_a(), .forward_b(),
        .stall_IF(), .flush_DE()
    );

    // ------------------------------------------------------------
    // Clock
    // ------------------------------------------------------------
    always #5 clk = ~clk;

    // ------------------------------------------------------------
    // Reset / memory-init task
    //   - clears register file (no reset exists in the RTL itself)
    //   - clears instruction memory to NOP
    //   - clears data memory to 0
    //   - pulses rst
    // ------------------------------------------------------------
    task reset_dut;
        begin
            rst = 1;
            timer_interrupt = 0;
            for (i = 0; i < 32; i = i + 1)
                dut.reg_file_i.reg_mem[i] = 32'd0;
            for (i = 0; i < 200; i = i + 1)
                dut.inst_mem_i.mem[i] = 32'h00000013; // NOP (addi x0,x0,0)
            for (i = 0; i < 140; i = i + 1)
                dut.data_mem_i.data_mem[i] = 8'h00;
            #20;
            rst = 0;
        end
    endtask

    task run;
        input integer cycles;
        begin
            repeat (cycles) @(posedge clk);
        end
    endtask

    // ------------------------------------------------------------
    // Register read (x0 hard-checked to 0 regardless)
    // ------------------------------------------------------------
    function [31:0] read_reg;
        input [4:0] rn;
        begin
            if (rn == 5'd0)
                read_reg = 32'd0;
            else
                read_reg = dut.reg_file_i.reg_mem[rn];
        end
    endfunction

    // Reconstruct a big-endian 32-bit word from data_mem bytes
    function [31:0] read_word_mem;
        input [31:0] addr;
        reg [6:0] a;
        begin
            a = addr[6:0];
            read_word_mem = { dut.data_mem_i.data_mem[a],
                               dut.data_mem_i.data_mem[a+1],
                               dut.data_mem_i.data_mem[a+2],
                               dut.data_mem_i.data_mem[a+3] };
        end
    endfunction

    // ------------------------------------------------------------
    // Check tasks
    // ------------------------------------------------------------
    task check_reg;
        input [4:0]   reg_num;
        input [31:0]  expected;
        input [127:0] test_name;
        reg [31:0] got;
        begin
            #1;
            got = read_reg(reg_num);
            if (got === expected) begin
                $display("  PASS: %-42s | x%0d = 0x%08h", test_name, reg_num, got);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: %-42s | x%0d = 0x%08h | expected 0x%08h", test_name, reg_num, got, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_mem_word;
        input [31:0]  addr;
        input [31:0]  expected;
        input [127:0] test_name;
        reg [31:0] got;
        begin
            #1;
            got = read_word_mem(addr);
            if (got === expected) begin
                $display("  PASS: %-42s | mem[0x%0h] = 0x%08h", test_name, addr, got);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: %-42s | mem[0x%0h] = 0x%08h | expected 0x%08h", test_name, addr, got, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_cond;
        input        cond;
        input [127:0] test_name;
        begin
            if (cond) begin
                $display("  PASS: %-42s", test_name);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: %-42s", test_name);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ------------------------------------------------------------
    // Watchdog + waveform
    // ------------------------------------------------------------
    initial begin
        #200000;
        $display("TIMEOUT - simulation hung");
        $finish;
    end

    initial begin
        $dumpfile("waves_processor_complete.vcd");
        $dumpvars(0, tb_processor_only);
    end

    // ============================================================
    // MAIN TEST SEQUENCE
    // ============================================================
    initial begin
        clk = 0;
        pass_count = 0;
        fail_count = 0;

        $display("========================================================");
        $display("  RV32I 3-STAGE PIPELINE TESTBENCH  (processor_top)");
        $display("========================================================");

        // ════════════════════════════════════════════════════════
        // SECTION 1 : R-TYPE
        // ════════════════════════════════════════════════════════
        $display("\n--- SECTION 1 : R-TYPE ---");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00500093; // addi x1,x0,5
        dut.inst_mem_i.mem[1] = 32'h00300113; // addi x2,x0,3
        dut.inst_mem_i.mem[2] = 32'h002081B3; // add  x3,x1,x2
        run(20);
        check_reg(3, 32'd8, "ADD x3=x1+x2 (5+3=8)");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00A00093; // addi x1,x0,10
        dut.inst_mem_i.mem[1] = 32'h00300113; // addi x2,x0,3
        dut.inst_mem_i.mem[2] = 32'h402081B3; // sub  x3,x1,x2
        run(20);
        check_reg(3, 32'd7, "SUB x3=x1-x2 (10-3=7)");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h0FF00093; // addi x1,x0,0xFF
        dut.inst_mem_i.mem[1] = 32'h00F00113; // addi x2,x0,0x0F
        dut.inst_mem_i.mem[2] = 32'h0020F1B3; // and  x3,x1,x2
        run(20);
        check_reg(3, 32'h0F, "AND x3=x1&x2 (FF&0F=0F)");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h0F000093; // addi x1,x0,0xF0
        dut.inst_mem_i.mem[1] = 32'h00F00113; // addi x2,x0,0x0F
        dut.inst_mem_i.mem[2] = 32'h0020E1B3; // or   x3,x1,x2
        run(20);
        check_reg(3, 32'hFF, "OR x3=x1|x2 (F0|0F=FF)");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h0FF00093; // addi x1,x0,0xFF
        dut.inst_mem_i.mem[1] = 32'h00F00113; // addi x2,x0,0x0F
        dut.inst_mem_i.mem[2] = 32'h0020C1B3; // xor  x3,x1,x2
        run(20);
        check_reg(3, 32'hF0, "XOR x3=x1^x2 (FF^0F=F0)");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00100093; // addi x1,x0,1
        dut.inst_mem_i.mem[1] = 32'h00400113; // addi x2,x0,4
        dut.inst_mem_i.mem[2] = 32'h002091B3; // sll  x3,x1,x2
        run(20);
        check_reg(3, 32'd16, "SLL x3=1<<4=16");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h01000093; // addi x1,x0,16
        dut.inst_mem_i.mem[1] = 32'h00200113; // addi x2,x0,2
        dut.inst_mem_i.mem[2] = 32'h0020D1B3; // srl  x3,x1,x2
        run(20);
        check_reg(3, 32'd4, "SRL x3=16>>2=4");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'hFF000093; // addi x1,x0,-16
        dut.inst_mem_i.mem[1] = 32'h00200113; // addi x2,x0,2
        dut.inst_mem_i.mem[2] = 32'h4020D1B3; // sra  x3,x1,x2
        run(20);
        check_reg(3, 32'hFFFFFFFC, "SRA x3=-16>>>2=-4");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'hFFF00093; // addi x1,x0,-1
        dut.inst_mem_i.mem[1] = 32'h00100113; // addi x2,x0,1
        dut.inst_mem_i.mem[2] = 32'h0020A1B3; // slt  x3,x1,x2
        run(20);
        check_reg(3, 32'd1, "SLT signed (-1<1)=1 [KNOWN BUG: alu.v SLT is unsigned]");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00500093; // addi x1,x0,5
        dut.inst_mem_i.mem[1] = 32'h00300113; // addi x2,x0,3
        dut.inst_mem_i.mem[2] = 32'h0020A1B3; // slt  x3,x1,x2
        run(20);
        check_reg(3, 32'd0, "SLT signed (5<3)=0");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00100093; // addi x1,x0,1
        dut.inst_mem_i.mem[1] = 32'hFFF00113; // addi x2,x0,-1 (=0xFFFFFFFF)
        dut.inst_mem_i.mem[2] = 32'h0020B1B3; // sltu x3,x1,x2
        run(20);
        check_reg(3, 32'd1, "SLTU (1<0xFFFFFFFF)=1");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'hFFF00093; // addi x1,x0,-1
        dut.inst_mem_i.mem[1] = 32'h00100113; // addi x2,x0,1
        dut.inst_mem_i.mem[2] = 32'h0020B1B3; // sltu x3,x1,x2
        run(20);
        check_reg(3, 32'd0, "SLTU (0xFFFFFFFF<1)=0");

        // corners
        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00500093; // addi x1,x0,5
        dut.inst_mem_i.mem[1] = 32'h00300113; // addi x2,x0,3
        dut.inst_mem_i.mem[2] = 32'h00208033; // add  x0,x1,x2 (dest x0)
        run(20);
        check_reg(0, 32'd0, "R-Corner: x0 destination stays 0");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h000001B3; // add x3,x0,x0
        run(20);
        check_reg(3, 32'd0, "R-Corner: x0 source gives 0");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h800000B7; // lui x1,0x80000
        dut.inst_mem_i.mem[1] = 32'hFFF08093; // addi x1,x1,-1 -> 0x7FFFFFFF
        dut.inst_mem_i.mem[2] = 32'h00100113; // addi x2,x0,1
        dut.inst_mem_i.mem[3] = 32'h002081B3; // add  x3,x1,x2
        run(20);
        check_reg(3, 32'h80000000, "R-Corner: ADD overflow wraps");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00500093; // addi x1,x0,5
        dut.inst_mem_i.mem[1] = 32'h00700113; // addi x2,x0,7
        dut.inst_mem_i.mem[2] = 32'h402081B3; // sub  x3,x1,x2
        run(20);
        check_reg(3, 32'hFFFFFFFE, "R-Corner: SUB (5-7)=-2");

        // ════════════════════════════════════════════════════════
        // SECTION 2 : I-TYPE
        // ════════════════════════════════════════════════════════
        $display("\n--- SECTION 2 : I-TYPE ---");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00500093; // addi x1,x0,5
        dut.inst_mem_i.mem[1] = 32'h00308113; // addi x2,x1,3
        run(20);
        check_reg(2, 32'd8, "ADDI x2=5+3=8");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00500093; // addi x1,x0,5
        dut.inst_mem_i.mem[1] = 32'h0060A113; // slti x2,x1,6
        run(20);
        check_reg(2, 32'd1, "SLTI (5<6)=1");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00100093; // addi x1,x0,1
        dut.inst_mem_i.mem[1] = 32'h0020B113; // sltiu x2,x1,2
        run(20);
        check_reg(2, 32'd1, "SLTIU (1<2)=1");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h0FF00093; // addi x1,x0,0xFF
        dut.inst_mem_i.mem[1] = 32'h00F0C113; // xori x2,x1,0xF
        run(20);
        check_reg(2, 32'hF0, "XORI x2=FF^F=F0");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h0F000093; // addi x1,x0,0xF0
        dut.inst_mem_i.mem[1] = 32'h00F0E113; // ori  x2,x1,0xF
        run(20);
        check_reg(2, 32'hFF, "ORI x2=F0|F=FF");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h0FF00093; // addi x1,x0,0xFF
        dut.inst_mem_i.mem[1] = 32'h00F0F113; // andi x2,x1,0xF
        run(20);
        check_reg(2, 32'h0F, "ANDI x2=FF&F=0F");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00100093; // addi x1,x0,1
        dut.inst_mem_i.mem[1] = 32'h00409113; // slli x2,x1,4
        run(20);
        check_reg(2, 32'd16, "SLLI 1<<4=16");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h01000093; // addi x1,x0,16
        dut.inst_mem_i.mem[1] = 32'h0020D113; // srli x2,x1,2
        run(20);
        check_reg(2, 32'd4, "SRLI 16>>2=4");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'hFF000093; // addi x1,x0,-16
        dut.inst_mem_i.mem[1] = 32'h4020D113; // srai x2,x1,2
        run(20);
        check_reg(2, 32'hFFFFFFFC, "SRAI -16>>>2=-4");

        // corners
        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00300013; // addi x0,x0,3
        run(20);
        check_reg(0, 32'd0, "I-Corner: x0 stays 0");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00500093; // addi x1,x0,5
        dut.inst_mem_i.mem[1] = 32'hFFE08113; // addi x2,x1,-2
        run(20);
        check_reg(2, 32'd3, "I-Corner: ADDI negative imm 5+(-2)=3");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h7FF00113; // addi x2,x0,2047
        run(20);
        check_reg(2, 32'd2047, "I-Corner: ADDI max +2047");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h80000113; // addi x2,x0,-2048
        run(20);
        check_reg(2, 32'hFFFFF800, "I-Corner: ADDI min -2048");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00100093; // addi x1,x0,1
        dut.inst_mem_i.mem[1] = 32'h01F09113; // slli x2,x1,31
        run(20);
        check_reg(2, 32'h80000000, "I-Corner: SLLI 1<<31");

        // ════════════════════════════════════════════════════════
        // SECTION 3 : U-TYPE
        // ════════════════════════════════════════════════════════
        $display("\n--- SECTION 3 : U-TYPE ---");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h123450B7; // lui x1,0x12345
        run(20);
        check_reg(1, 32'h12345000, "LUI x1=0x12345000");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h000000B7; // lui x1,0
        run(20);
        check_reg(1, 32'h00000000, "LUI zero imm");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h12345037; // lui x0,0x12345
        run(20);
        check_reg(0, 32'h00000000, "LUI x0 unchanged");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'hFFFFF0B7; // lui x1,0xFFFFF
        run(20);
        check_reg(1, 32'hFFFFF000, "LUI max imm");

        // AUIPC -- expected (correct ISA) results.
        // KNOWN RTL BUG: imm_gen.v has no case for opcode 7'b0010111
        // (AUIPC), so imm_val keeps whatever the previous
        // instruction latched instead of the U-type immediate.
        // These two are expected to FAIL until that is fixed.
        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00001117; // auipc x2,0x1  (PC=0)
        run(20);
        check_reg(2, 32'h00001000, "AUIPC x2=PC+0x1000 [KNOWN BUG: imm_gen missing AUIPC case]");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00000013; // nop
        dut.inst_mem_i.mem[1] = 32'h00002197; // auipc x3,0x2 (PC=4)
        run(20);
        check_reg(3, 32'h00002004, "AUIPC x3=PC+0x2000 [KNOWN BUG: imm_gen missing AUIPC case]");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h111110B7; // lui x1,0x11111
        dut.inst_mem_i.mem[1] = 32'h222220B7; // lui x1,0x22222
        dut.inst_mem_i.mem[2] = 32'h333330B7; // lui x1,0x33333
        run(20);
        check_reg(1, 32'h33333000, "LUI repeated overwrite");

        // ════════════════════════════════════════════════════════
        // SECTION 4 : J-TYPE
        // ════════════════════════════════════════════════════════
        $display("\n--- SECTION 4 : J-TYPE ---");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h008000EF; // jal x1,+8
        dut.inst_mem_i.mem[1] = 32'h0FF00113; // addi x2,x0,0xFF (skipped)
        run(20);
        check_reg(2, 32'd0, "JAL fwd: skipped insn x2=0");
        check_reg(1, 32'd4, "JAL link=PC+4");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h0080006F; // jal x0,+8
        dut.inst_mem_i.mem[1] = 32'h0FF00093; // addi x1,x0,0xFF (skipped)
        dut.inst_mem_i.mem[2] = 32'h0AB00113; // addi x2,x0,0xAB (target)
        run(20);
        check_reg(0, 32'd0, "JAL x0: x0 stays zero");
        check_reg(1, 32'd0, "JAL x0: skipped insn x1=0");
        check_reg(2, 32'hAB, "JAL x0: target executes x2=0xAB");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00108093; // addi x1,x1,1
        dut.inst_mem_i.mem[1] = 32'hFFDFF06F; // jal x0,-4  (loop)
        run(40);
        check_cond(read_reg(1) >= 32'd3, "JAL backward loop: x1 kept incrementing");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h014000EF; // jal x1,+20
        dut.inst_mem_i.mem[5] = 32'h0CD00193; // addi x3,x0,0xCD (target)
        run(30);
        check_reg(1, 32'd4, "JAL +20: link=4");
        check_reg(3, 32'hCD, "JAL +20: target x3=0xCD");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h01000093; // addi x1,x0,16
        dut.inst_mem_i.mem[1] = 32'h00008167; // jalr x2,x1,0
        dut.inst_mem_i.mem[2] = 32'h06300293; // addi x5,x0,99 (skipped)
        dut.inst_mem_i.mem[4] = 32'h0BE00213; // addi x4,x0,0xBE (target PC=16)
        run(30);
        check_reg(2, 32'd8, "JALR imm=0: link=8");
        check_reg(5, 32'd0, "JALR imm=0: skipped insn x5=0");
        check_reg(4, 32'hBE, "JALR imm=0: target x4=0xBE");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h01400093; // addi x1,x0,20
        dut.inst_mem_i.mem[1] = 32'hFFC08167; // jalr x2,x1,-4
        dut.inst_mem_i.mem[4] = 32'h0DD00213; // addi x4,x0,0xDD (target PC=16)
        run(30);
        check_reg(2, 32'd8, "JALR neg imm: link=8");
        check_reg(4, 32'hDD, "JALR neg imm: target x4=0xDD");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h01000193; // addi x3,x0,16
        dut.inst_mem_i.mem[1] = 32'h000181E7; // jalr x3,x3,0  (rd==rs1)
        dut.inst_mem_i.mem[4] = 32'h0F100293; // addi x5,x0,0xF1 (target PC=16)
        run(30);
        check_reg(3, 32'd8,  "JALR rd==rs1: x3=link(PC+4)");
        check_reg(5, 32'hF1, "JALR rd==rs1: target executes");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00C000EF; // jal x1,+12   (call)
        dut.inst_mem_i.mem[1] = 32'h0BB00193; // addi x3,x0,0xBB (after return)
        dut.inst_mem_i.mem[3] = 32'h0AA00113; // addi x2,x0,0xAA (callee)
        dut.inst_mem_i.mem[4] = 32'h00008067; // jalr x0,x1,0    (return)
        run(30);
        check_reg(2, 32'hAA, "Call/Ret: callee executed x2=0xAA");
        check_reg(3, 32'hBB, "Call/Ret: post-return x3=0xBB");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h004000EF; // jal x1,+4
        dut.inst_mem_i.mem[1] = 32'h004000EF; // jal x1,+4 (WAW same rd)
        run(20);
        check_reg(1, 32'd8, "WAW two JALs: second link wins x1=8");

        // ════════════════════════════════════════════════════════
        // SECTION 5 : B-TYPE
        // ════════════════════════════════════════════════════════
        $display("\n--- SECTION 5 : B-TYPE ---");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00A00093; // addi x1,x0,10
        dut.inst_mem_i.mem[1] = 32'h00A00113; // addi x2,x0,10
        dut.inst_mem_i.mem[2] = 32'h00208463; // beq x1,x2,+8
        dut.inst_mem_i.mem[3] = 32'h00100193; // addi x3,x0,1 (skipped)
        run(20);
        check_reg(3, 32'd0, "BEQ taken: x3 stays 0");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00A00093; // addi x1,x0,10
        dut.inst_mem_i.mem[1] = 32'h01400113; // addi x2,x0,20
        dut.inst_mem_i.mem[2] = 32'h00208463; // beq x1,x2,+8
        dut.inst_mem_i.mem[3] = 32'h00100193; // addi x3,x0,1
        run(20);
        check_reg(3, 32'd1, "BEQ not taken: x3=1");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00A00093; // addi x1,x0,10
        dut.inst_mem_i.mem[1] = 32'h01400113; // addi x2,x0,20
        dut.inst_mem_i.mem[2] = 32'h00209463; // bne x1,x2,+8
        dut.inst_mem_i.mem[3] = 32'h00100193; // addi x3,x0,1 (skipped)
        run(20);
        check_reg(3, 32'd0, "BNE taken: x3 stays 0");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00A00093; // addi x1,x0,10
        dut.inst_mem_i.mem[1] = 32'h00A00113; // addi x2,x0,10
        dut.inst_mem_i.mem[2] = 32'h00209463; // bne x1,x2,+8
        dut.inst_mem_i.mem[3] = 32'h00100193; // addi x3,x0,1
        run(20);
        check_reg(3, 32'd1, "BNE not taken: x3=1");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00500093; // addi x1,x0,5
        dut.inst_mem_i.mem[1] = 32'h00A00113; // addi x2,x0,10
        dut.inst_mem_i.mem[2] = 32'h0020C463; // blt x1,x2,+8
        dut.inst_mem_i.mem[3] = 32'h00100193; // addi x3,x0,1 (skipped)
        run(20);
        check_reg(3, 32'd0, "BLT taken (5<10): x3=0");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h01400093; // addi x1,x0,20
        dut.inst_mem_i.mem[1] = 32'h00A00113; // addi x2,x0,10
        dut.inst_mem_i.mem[2] = 32'h0020C463; // blt x1,x2,+8
        dut.inst_mem_i.mem[3] = 32'h00100193; // addi x3,x0,1
        run(20);
        check_reg(3, 32'd1, "BLT not taken (20>10): x3=1");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h01400093; // addi x1,x0,20
        dut.inst_mem_i.mem[1] = 32'h00A00113; // addi x2,x0,10
        dut.inst_mem_i.mem[2] = 32'h0020D463; // bge x1,x2,+8
        dut.inst_mem_i.mem[3] = 32'h00100193; // addi x3,x0,1 (skipped)
        run(20);
        check_reg(3, 32'd0, "BGE taken (20>=10): x3=0");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'hFF600093; // addi x1,x0,-10
        dut.inst_mem_i.mem[1] = 32'hFFB00113; // addi x2,x0,-5
        dut.inst_mem_i.mem[2] = 32'h0020D463; // bge x1,x2,+8
        dut.inst_mem_i.mem[3] = 32'h00100193; // addi x3,x0,1
        run(20);
        check_reg(3, 32'd1, "BGE not taken (-10>=-5 false): x3=1");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00100093; // addi x1,x0,1
        dut.inst_mem_i.mem[1] = 32'hFFF00113; // addi x2,x0,-1(=0xFFFFFFFF)
        dut.inst_mem_i.mem[2] = 32'h0020E463; // bltu x1,x2,+8
        dut.inst_mem_i.mem[3] = 32'h00100193; // addi x3,x0,1 (skipped)
        run(20);
        check_reg(3, 32'd0, "BLTU taken: x3=0");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'hFFF00093; // addi x1,x0,-1
        dut.inst_mem_i.mem[1] = 32'h00100113; // addi x2,x0,1
        dut.inst_mem_i.mem[2] = 32'h0020F463; // bgeu x1,x2,+8
        dut.inst_mem_i.mem[3] = 32'h00100193; // addi x3,x0,1 (skipped)
        run(20);
        check_reg(3, 32'd0, "BGEU taken: x3=0");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00000463; // beq x0,x0,+8 (always taken)
        dut.inst_mem_i.mem[1] = 32'h00100193; // addi x3,x0,1 (skipped)
        run(20);
        check_reg(3, 32'd0, "B-Corner: BEQ x0,x0 always taken");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00700093; // addi x1,x0,7
        dut.inst_mem_i.mem[1] = 32'h00700113; // addi x2,x0,7
        dut.inst_mem_i.mem[2] = 32'h0020D463; // bge x1,x2,+8 (equal -> taken)
        dut.inst_mem_i.mem[3] = 32'h00100193; // addi x3,x0,1 (skipped)
        run(20);
        check_reg(3, 32'd0, "B-Corner: BGE equal values taken");

        // ════════════════════════════════════════════════════════
        // SECTION 6 : S-TYPE
        // ════════════════════════════════════════════════════════
        $display("\n--- SECTION 6 : S-TYPE ---");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00F00093; // addi x1,x0,15
        dut.inst_mem_i.mem[1] = 32'h00102023; // sw x1,0(x0)
        run(20);
        check_mem_word(0, 32'd15, "SW x1->mem[0]");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00A00093; // addi x1,x0,10
        dut.inst_mem_i.mem[1] = 32'h00102223; // sw x1,4(x0)
        run(20);
        check_mem_word(4, 32'd10, "SW offset+4 -> mem[4]");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00500093; // addi x1,x0,5
        dut.inst_mem_i.mem[1] = 32'h00102023; // sw x1,0(x0)
        dut.inst_mem_i.mem[2] = 32'h00A00093; // addi x1,x0,10
        dut.inst_mem_i.mem[3] = 32'h00102023; // sw x1,0(x0)
        run(30);
        check_mem_word(0, 32'd10, "SW overwrite -> mem[0]=10");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00000093; // addi x1,x0,0
        dut.inst_mem_i.mem[1] = 32'h00102023; // sw x1,0(x0)
        run(20);
        check_mem_word(0, 32'd0, "SW store zero");

        reset_dut;
        dut.data_mem_i.data_mem[16]=8'h22; dut.data_mem_i.data_mem[17]=8'h33;
        dut.data_mem_i.data_mem[18]=8'h44; dut.data_mem_i.data_mem[19]=8'h55;
        dut.inst_mem_i.mem[0] = 32'h01000113; // addi x2,x0,16
        dut.inst_mem_i.mem[1] = 32'h01100093; // addi x1,x0,0x11
        dut.inst_mem_i.mem[2] = 32'h00110123; // sb x1,2(x2) -> writes byte at addr 18
        run(20);
        check_mem_word(16, 32'h22331155, "SB byte write at offset+2");

        reset_dut;
        dut.data_mem_i.data_mem[64]=8'hAA; dut.data_mem_i.data_mem[65]=8'hBB;
        dut.data_mem_i.data_mem[66]=8'hCC; dut.data_mem_i.data_mem[67]=8'hDD;
        dut.inst_mem_i.mem[0] = 32'h04000113; // addi x2,x0,64
        dut.inst_mem_i.mem[1] = 32'h12200093; // addi x1,x0,0x122
        dut.inst_mem_i.mem[2] = 32'h00111023; // sh x1,0(x2) -> overwrites the two low-address bytes
        run(20);
        check_mem_word(64, 32'h0122CCDD, "SH halfword store");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h01100093; // addi x1,x0,0x11
        dut.inst_mem_i.mem[1] = 32'h00100023; // sb x1,0(x0)
        dut.inst_mem_i.mem[2] = 32'h001000A3; // sb x1,1(x0)
        dut.inst_mem_i.mem[3] = 32'h00100123; // sb x1,2(x0)
        dut.inst_mem_i.mem[4] = 32'h001001A3; // sb x1,3(x0)
        run(30);
        check_mem_word(0, 32'h11111111, "SB all 4 bytes = 0x11");

        reset_dut;
        dut.data_mem_i.data_mem[0]=8'hAA; dut.data_mem_i.data_mem[1]=8'hBB;
        dut.data_mem_i.data_mem[2]=8'hCC; dut.data_mem_i.data_mem[3]=8'hDD;
        dut.inst_mem_i.mem[0] = 32'h00002023; // sw x0,0(x0)
        run(20);
        check_mem_word(0, 32'h00000000, "SW x0 zeros mem");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h01000093; // addi x1,x0,16
        dut.inst_mem_i.mem[1] = 32'h00500113; // addi x2,x0,5
        dut.inst_mem_i.mem[2] = 32'h0020A023; // sw x2,0(x1)
        run(20);
        check_mem_word(16, 32'd5, "SW using base register address");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00500093; // addi x1,x0,5
        dut.inst_mem_i.mem[1] = 32'h06102023; // sw x1,96(x0)
        run(20);
        check_mem_word(96, 32'd5, "SW large offset (96)");

        // ════════════════════════════════════════════════════════
        // SECTION 7 : LOAD
        // ════════════════════════════════════════════════════════
        $display("\n--- SECTION 7 : LOAD ---");

        reset_dut;
        // word 0x1234F580 at byte address 32 (big-endian: MSB first)
        dut.data_mem_i.data_mem[32]=8'h12; dut.data_mem_i.data_mem[33]=8'h34;
        dut.data_mem_i.data_mem[34]=8'hF5; dut.data_mem_i.data_mem[35]=8'h80;
        dut.inst_mem_i.mem[0] = 32'h02000513; // addi x10,x0,32
        dut.inst_mem_i.mem[1] = 32'h00050083; // lb  x1,0(x10)
        dut.inst_mem_i.mem[2] = 32'h00350103; // lb  x2,3(x10)
        dut.inst_mem_i.mem[3] = 32'h00054183; // lbu x3,0(x10)
        dut.inst_mem_i.mem[4] = 32'h00354203; // lbu x4,3(x10)
        dut.inst_mem_i.mem[5] = 32'h00251283; // lh  x5,2(x10)
        dut.inst_mem_i.mem[6] = 32'h00255303; // lhu x6,2(x10)
        dut.inst_mem_i.mem[7] = 32'h00052383; // lw  x7,0(x10)
        run(30);
        check_reg(1, 32'h00000012, "LB byte0 (0x12, positive)");
        check_reg(2, 32'hFFFFFF80, "LB byte3 (0x80 sign-extended)");
        check_reg(3, 32'h00000012, "LBU byte0 (0x12 zero-extended)");
        check_reg(4, 32'h00000080, "LBU byte3 (0x80 zero-extended)");
        check_reg(5, 32'hFFFFF580, "LH bytes[2:3]=0xF580 sign-extended");
        check_reg(6, 32'h0000F580, "LHU bytes[2:3]=0xF580 zero-extended");
        check_reg(7, 32'h1234F580, "LW full word");

        reset_dut;
        dut.data_mem_i.data_mem[16] = 8'h55;
        dut.inst_mem_i.mem[0] = 32'h01000513; // addi x10,x0,16
        dut.inst_mem_i.mem[1] = 32'h00050083; // lb x1,0(x10)
        run(20);
        check_reg(1, 32'h00000055, "Load-Corner: LB positive (no sign-ext)");

        reset_dut;
        dut.data_mem_i.data_mem[32]=8'hDE; dut.data_mem_i.data_mem[33]=8'hAD;
        dut.data_mem_i.data_mem[34]=8'hBE; dut.data_mem_i.data_mem[35]=8'hEF;
        dut.inst_mem_i.mem[0] = 32'h02000513; // addi x10,x0,32
        dut.inst_mem_i.mem[1] = 32'h00052503; // lw x10,0(x10)
        run(20);
        check_reg(10, 32'hDEADBEEF, "Load-Corner: LW via computed base");

        reset_dut;
        dut.data_mem_i.data_mem[16] = 8'h00;
        dut.inst_mem_i.mem[0] = 32'h01000513; // addi x10,x0,16
        dut.inst_mem_i.mem[1] = 32'h00054083; // lbu x1,0(x10)
        run(20);
        check_reg(1, 32'h00000000, "Load-Corner: LBU zero byte");

        reset_dut;
        dut.data_mem_i.data_mem[16]=8'h80; dut.data_mem_i.data_mem[17]=8'h00;
        dut.inst_mem_i.mem[0] = 32'h01000513; // addi x10,x0,16
        dut.inst_mem_i.mem[1] = 32'h00051083; // lh  x1,0(x10)
        dut.inst_mem_i.mem[2] = 32'h00055103; // lhu x2,0(x10)
        run(20);
        check_reg(1, 32'hFFFF8000, "Load-Corner: LH 0x8000 sign-extends");
        check_reg(2, 32'h00008000, "Load-Corner: LHU 0x8000 zero-extends");

        reset_dut;
        dut.data_mem_i.data_mem[8] = 32'h00000000;
        dut.inst_mem_i.mem[0] = 32'h00800513; // addi x10,x0,8
        dut.inst_mem_i.mem[1] = 32'h00052383; // lw x7,0(x10)
        run(20);
        check_reg(7, 32'h00000000, "Load-Corner: LW zero word");

        // ════════════════════════════════════════════════════════
        // SECTION 8 : PIPELINE / HAZARD BEHAVIOR
        // ════════════════════════════════════════════════════════
        $display("\n--- SECTION 8 : PIPELINE HAZARDS (forwarding / stall) ---");

        // back-to-back RAW: result of instr N used immediately by N+1
        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00500093; // addi x1,x0,5
        dut.inst_mem_i.mem[1] = 32'h00108133; // add  x2,x1,x1   (needs x1 forwarded)
        run(20);
        check_reg(2, 32'd10, "Forwarding: back-to-back RAW (x2=x1+x1=10)");

        // three-deep RAW chain
        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00100093; // addi x1,x0,1
        dut.inst_mem_i.mem[1] = 32'h00108113; // addi x2,x1,1   -> 2 (forward from MW)
        dut.inst_mem_i.mem[2] = 32'h00110193; // addi x3,x2,1   -> 3 (forward from MW)
        run(20);
        check_reg(3, 32'd3, "Forwarding: 3-deep RAW dependency chain");

        // load-use hazard: dependent instruction right after a load
        reset_dut;
        dut.data_mem_i.data_mem[0]=8'h00; dut.data_mem_i.data_mem[1]=8'h00;
        dut.data_mem_i.data_mem[2]=8'h00; dut.data_mem_i.data_mem[3]=8'h07;
        dut.inst_mem_i.mem[0] = 32'h00002103; // lw  x2,0(x0)  -> 7
        dut.inst_mem_i.mem[1] = 32'h002101B3; // add x3,x2,x2  (immediately depends on load)
        run(25);
        check_reg(2, 32'd7,  "Load-use hazard: x2 loaded = 7");
        check_reg(3, 32'd14, "Load-use hazard: stall+forward gives x3=14");

        // forwarding on rs2 operand (store data path) after a load
        reset_dut;
        dut.data_mem_i.data_mem[0]=8'h00; dut.data_mem_i.data_mem[1]=8'h00;
        dut.data_mem_i.data_mem[2]=8'h00; dut.data_mem_i.data_mem[3]=8'h09;
        dut.inst_mem_i.mem[0] = 32'h00002103; // lw x2,0(x0) -> 9
        dut.inst_mem_i.mem[1] = 32'h04202823; // sw x2,80(x0) (store depends on loaded value)
        run(25);
        check_mem_word(80, 32'd9, "Load-use hazard: store of loaded value");

        // x0 never triggers false forwarding (writes to x0 are ignored downstream)
        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00500033; // add x0,x0,x5  (garbage op, writes x0)
        dut.inst_mem_i.mem[1] = 32'h00700093; // addi x1,x0,7  (rs1=x0, must read true 0 not forwarded garbage)
        run(20);
        check_reg(1, 32'd7, "Hazard: writes to x0 don't corrupt later reads of x0");

        // ════════════════════════════════════════════════════════
        // SECTION 9 : CSR (bonus)
        // ════════════════════════════════════════════════════════
        $display("\n--- SECTION 9 : CSR ---");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h12300093; // addi x1,x0,0x123
        dut.inst_mem_i.mem[1] = 32'h30509173; // csrrw x2,mtvec,x1
        dut.inst_mem_i.mem[2] = 32'h30502273; // csrrs x4,mtvec,x0 (readback)
        run(20);
        check_reg(4, 32'h123, "CSR: write mtvec then read back = 0x123");

        // ════════════════════════════════════════════════════════
        // SECTION 10 : EXTRA R-TYPE EDGE CASES
        // ════════════════════════════════════════════════════════
        $display("\n--- SECTION 10 : EXTRA R-TYPE EDGE CASES ---");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h05500093; // addi x1,x0,0x55
        dut.inst_mem_i.mem[1] = 32'h00000113; // addi x2,x0,0
        dut.inst_mem_i.mem[2] = 32'h002091B3; // sll x3,x1,x2 (shift by 0)
        run(20);
        check_reg(3, 32'h55, "SLL shift-by-0 leaves value unchanged");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00100093; // addi x1,x0,1
        dut.inst_mem_i.mem[1] = 32'h01F00113; // addi x2,x0,31
        dut.inst_mem_i.mem[2] = 32'h002091B3; // sll x3,x1,x2 (1<<31)
        dut.inst_mem_i.mem[3] = 32'h0021D233; // srl x4,x3,x2 ((1<<31)>>31)
        run(20);
        check_reg(3, 32'h80000000, "SLL shift-by-31 -> MSB set");
        check_reg(4, 32'd1, "SRL shift-by-31 recovers 1");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'hFFF00093; // addi x1,x0,-1 (0xFFFFFFFF)
        dut.inst_mem_i.mem[1] = 32'h00000113; // addi x2,x0,0
        dut.inst_mem_i.mem[2] = 32'h0020F1B3; // and x3,x1,x2
        dut.inst_mem_i.mem[3] = 32'h0020E233; // or  x4,x1,x2
        dut.inst_mem_i.mem[4] = 32'h0020C2B3; // xor x5,x1,x2
        run(20);
        check_reg(3, 32'd0, "AND with zero => 0");
        check_reg(4, 32'hFFFFFFFF, "OR with zero => unchanged");
        check_reg(5, 32'hFFFFFFFF, "XOR with zero => unchanged");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h04000093; // addi x1,x0,64
        dut.inst_mem_i.mem[1] = 32'h00300113; // addi x2,x0,3
        dut.inst_mem_i.mem[2] = 32'h4020D1B3; // sra x3,x1,x2 (positive >>> arithmetic)
        run(20);
        check_reg(3, 32'd8, "SRA on positive number = logical shift result (64>>>3=8)");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00900093; // addi x1,x0,9
        dut.inst_mem_i.mem[1] = 32'h00900113; // addi x2,x0,9
        dut.inst_mem_i.mem[2] = 32'h0020B1B3; // sltu x3,x1,x2 (equal -> 0)
        run(20);
        check_reg(3, 32'd0, "SLTU equal values => 0");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00200093; // addi x1,x0,2
        dut.inst_mem_i.mem[1] = 32'h00300113; // addi x2,x0,3
        dut.inst_mem_i.mem[2] = 32'h002081B3; // add x3,x1,x2 (=5)
        dut.inst_mem_i.mem[3] = 32'h401181B3; // sub x3,x3,x1 (=3) WAW on x3
        run(20);
        check_reg(3, 32'd3, "WAW R-type: last write to x3 wins (5-2=3)");

        // ════════════════════════════════════════════════════════
        // SECTION 11 : EXTRA I-TYPE EDGE CASES
        // ════════════════════════════════════════════════════════
        $display("\n--- SECTION 11 : EXTRA I-TYPE EDGE CASES ---");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'hFFB00093; // addi x1,x0,-5
        dut.inst_mem_i.mem[1] = 32'hFFE0A113; // slti x2,x1,-2 (-5<-2)=1
        run(20);
        check_reg(2, 32'd1, "SLTI negative operands (-5<-2)=1");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00500093; // addi x1,x0,5
        dut.inst_mem_i.mem[1] = 32'h0030A113; // slti x2,x1,3 (5<3)=0
        run(20);
        check_reg(2, 32'd0, "SLTI (5<3)=0");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00000093; // addi x1,x0,0
        dut.inst_mem_i.mem[1] = 32'hFFF0C113; // xori x2,x1,-1 (0^0xFFFFFFFF)
        run(20);
        check_reg(2, 32'hFFFFFFFF, "XORI with -1 immediate inverts all bits");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h1FF00093; // addi x1,x0,0x1FF
        dut.inst_mem_i.mem[1] = 32'hFF00F113; // andi x2,x1,-16 (mask low 4 bits)
        run(20);
        check_reg(2, 32'h1F0, "ANDI with -16 clears low 4 bits (0x1FF & 0xFFFFFFF0)");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00000093; // addi x1,x0,0
        dut.inst_mem_i.mem[1] = 32'hFFF0E113; // ori x2,x1,-1
        run(20);
        check_reg(2, 32'hFFFFFFFF, "ORI with -1 sets all bits");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'hFFF00093; // addi x1,x0,-1
        dut.inst_mem_i.mem[1] = 32'h01F0D113; // srli x2,x1,31
        run(20);
        check_reg(2, 32'd1, "SRLI 0xFFFFFFFF>>31 = 1 (logical)");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'hFFF00093; // addi x1,x0,-1
        dut.inst_mem_i.mem[1] = 32'h41F0D113; // srai x2,x1,31
        run(20);
        check_reg(2, 32'hFFFFFFFF, "SRAI -1>>>31 stays all 1s (sign extended)");

        // ════════════════════════════════════════════════════════
        // SECTION 12 : EXTRA B-TYPE EDGE CASES
        // ════════════════════════════════════════════════════════
        $display("\n--- SECTION 12 : EXTRA B-TYPE EDGE CASES ---");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'hFF600093; // addi x1,x0,-10
        dut.inst_mem_i.mem[1] = 32'hFFB00113; // addi x2,x0,-5
        dut.inst_mem_i.mem[2] = 32'h0020C463; // blt x1,x2,+8 (-10<-5 taken)
        dut.inst_mem_i.mem[3] = 32'h00100193; // addi x3,x0,1 (skipped)
        run(20);
        check_reg(3, 32'd0, "BLT signed negative operands taken");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'hFF600093; // addi x1,x0,-10 (large unsigned)
        dut.inst_mem_i.mem[1] = 32'hFFB00113; // addi x2,x0,-5 (large unsigned)
        dut.inst_mem_i.mem[2] = 32'h0020E463; // bltu x1,x2,+8 (0xFFFFFFF6 < 0xFFFFFFFB) taken
        dut.inst_mem_i.mem[3] = 32'h00100193; // addi x3,x0,1 (skipped)
        run(20);
        check_reg(3, 32'd0, "BLTU unsigned comparison of negative-looking values taken");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00700093; // addi x1,x0,7
        dut.inst_mem_i.mem[1] = 32'h00700113; // addi x2,x0,7
        dut.inst_mem_i.mem[2] = 32'h0020F463; // bgeu x1,x2,+8 (equal -> taken)
        dut.inst_mem_i.mem[3] = 32'h00100193; // addi x3,x0,1 (skipped)
        run(20);
        check_reg(3, 32'd0, "BGEU equal values taken");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00400093; // addi x1,x0,4
        dut.inst_mem_i.mem[1] = 32'h00400113; // addi x2,x0,4
        dut.inst_mem_i.mem[2] = 32'h00209463; // bne x1,x2,+8 (equal -> not taken)
        dut.inst_mem_i.mem[3] = 32'h00100193; // addi x3,x0,1
        run(20);
        check_reg(3, 32'd1, "BNE equal values not taken");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00300093; // addi x1,x0,3
        dut.inst_mem_i.mem[1] = 32'hFFF08093; // addi x1,x1,-1 (decrement)
        dut.inst_mem_i.mem[2] = 32'hFE009EE3; // bne x1,x0,-4 (loop until zero)
        run(40);
        check_reg(1, 32'd0, "Backward BNE loop counts down to 0");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00100093; // addi x1,x0,1
        dut.inst_mem_i.mem[1] = 32'h00100113; // addi x2,x0,1
        dut.inst_mem_i.mem[2] = 32'h00208463; // beq x1,x2,+8 (taken)
        dut.inst_mem_i.mem[3] = 32'h0AA00193; // addi x3,x0,0xAA (skipped)
        dut.inst_mem_i.mem[4] = 32'h00500213; // addi x4,x0,5
        dut.inst_mem_i.mem[5] = 32'h00500293; // addi x5,x0,5
        dut.inst_mem_i.mem[6] = 32'h00520463; // beq x4,x5,+8 (taken)
        dut.inst_mem_i.mem[7] = 32'h0BB00313; // addi x6,x0,0xBB (skipped)
        run(30);
        check_reg(3, 32'd0, "First branch: skipped insn x3 stays 0");
        check_reg(6, 32'd0, "Second branch: skipped insn x6 stays 0");

        // ════════════════════════════════════════════════════════
        // SECTION 13 : EXTRA STORE/LOAD EDGE CASES
        // ════════════════════════════════════════════════════════
        $display("\n--- SECTION 13 : EXTRA STORE/LOAD EDGE CASES ---");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'hFFF00093; // addi x1,x0,-1
        dut.inst_mem_i.mem[1] = 32'h02102423; // sw x1,40(x0)
        dut.inst_mem_i.mem[2] = 32'h02802103; // lw x2,40(x0)
        dut.inst_mem_i.mem[3] = 32'h02800183; // lb x3,40(x0) (MSB byte, big-endian)
        dut.inst_mem_i.mem[4] = 32'h02804203; // lbu x4,40(x0)
        run(25);
        check_mem_word(40, 32'hFFFFFFFF, "SW of -1 stores all FF bytes");
        check_reg(2, 32'hFFFFFFFF, "LW reads back -1");
        check_reg(3, 32'hFFFFFFFF, "LB of 0xFF sign-extends to -1");
        check_reg(4, 32'h000000FF, "LBU of 0xFF zero-extends");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h000010B7; // lui x1,0x1 (x1=0x1000; 0x1234 doesn't fit ADDI's 12-bit imm)
        dut.inst_mem_i.mem[1] = 32'h23408093; // addi x1,x1,0x234 (x1=0x1234)
        dut.inst_mem_i.mem[2] = 32'h02101623; // sh x1,44(x0)
        dut.inst_mem_i.mem[3] = 32'h02C01103; // lh x2,44(x0)
        dut.inst_mem_i.mem[4] = 32'h02C05183; // lhu x3,44(x0)
        run(25);
        check_reg(2, 32'h1234, "LH readback of stored halfword");
        check_reg(3, 32'h1234, "LHU readback of stored halfword");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h0AA00093; // addi x1,x0,0xAA
        dut.inst_mem_i.mem[1] = 32'h0BB00113; // addi x2,x0,0xBB
        dut.inst_mem_i.mem[2] = 32'h0CC00193; // addi x3,x0,0xCC
        dut.inst_mem_i.mem[3] = 32'h0DD00213; // addi x4,x0,0xDD
        dut.inst_mem_i.mem[4] = 32'h02100823; // sb x1,48(x0)
        dut.inst_mem_i.mem[5] = 32'h022008A3; // sb x2,49(x0)
        dut.inst_mem_i.mem[6] = 32'h02300923; // sb x3,50(x0)
        dut.inst_mem_i.mem[7] = 32'h024009A3; // sb x4,51(x0)
        run(35);
        check_mem_word(48, 32'hAABBCCDD, "Byte-by-byte word assembly via 4x SB");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h03C00513; // addi x10,x0,60
        dut.inst_mem_i.mem[1] = 32'h07700093; // addi x1,x0,0x77
        dut.inst_mem_i.mem[2] = 32'h00152023; // sw x1,0(x10)
        dut.inst_mem_i.mem[3] = 32'h00052103; // lw x2,0(x10)
        dut.inst_mem_i.mem[4] = 32'h00252223; // sw x2,4(x10) store the loaded value elsewhere
        run(30);
        check_mem_word(64, 32'h77, "Load-then-store round trip preserves value at new address");

        reset_dut;
        dut.data_mem_i.data_mem[24]=8'hDE; dut.data_mem_i.data_mem[25]=8'hAD;
        dut.data_mem_i.data_mem[26]=8'hBE; dut.data_mem_i.data_mem[27]=8'hEF;
        dut.inst_mem_i.mem[0] = 32'h01400513; // addi x10,x0,20
        dut.inst_mem_i.mem[1] = 32'h00452583; // lw x11,4(x10) -> addr 24
        run(20);
        check_reg(11, 32'hDEADBEEF, "LW with base+offset addressing (base=20,off=4 -> addr24)");

        // ════════════════════════════════════════════════════════
        // SECTION 14 : EXTRA J-TYPE EDGE CASES
        // ════════════════════════════════════════════════════════
        $display("\n--- SECTION 14 : EXTRA J-TYPE EDGE CASES ---");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h0080006F; // jal x0,+8 (plain goto)
        dut.inst_mem_i.mem[1] = 32'h0EE00093; // addi x1,x0,0xEE (skipped)
        dut.inst_mem_i.mem[2] = 32'h01100113; // addi x2,x0,0x11 (target)
        run(20);
        check_reg(1, 32'd0, "JAL x0 goto: skipped insn x1=0");
        check_reg(2, 32'h11, "JAL x0 goto: target executed");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00C000EF; // jal x1,+12 (call subroutine at PC=12)
        dut.inst_mem_i.mem[1] = 32'h04400213; // addi x4,x0,0x44 (executes after return)
        dut.inst_mem_i.mem[2] = 32'h0640006F; // jal x0,+100 (jump past subroutine to end, avoids fallthrough)
        dut.inst_mem_i.mem[3] = 32'h00000013; // nop (padding)
        dut.inst_mem_i.mem[4] = 32'h05500293; // addi x5,x0,0x55 (subroutine body)
        dut.inst_mem_i.mem[5] = 32'h00008067; // jalr x0,x1,0 (return to PC=4)
        run(30);
        check_reg(5, 32'h55, "Subroutine body executed");
        check_reg(4, 32'h44, "Post-return instruction executed");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h01800093; // addi x1,x0,24
        dut.inst_mem_i.mem[1] = 32'hFF808167; // jalr x2,x1,-8 (target PC=16)
        dut.inst_mem_i.mem[2] = 32'h00100293; // addi x5,x0,1 (skipped)
        dut.inst_mem_i.mem[4] = 32'h00200313; // addi x6,x0,2 (target PC=16)
        run(30);
        check_reg(2, 32'd8, "JALR neg-offset link = PC+4 = 8");
        check_reg(5, 32'd0, "JALR neg-offset: skipped insn stays 0");
        check_reg(6, 32'd2, "JALR neg-offset: target executes");

        // ════════════════════════════════════════════════════════
        // SECTION 15 : EXTRA PIPELINE HAZARD CASES
        // ════════════════════════════════════════════════════════
        $display("\n--- SECTION 15 : EXTRA PIPELINE HAZARD CASES ---");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00500093; // addi x1,x0,5
        dut.inst_mem_i.mem[1] = 32'h00500113; // addi x2,x0,5
        dut.inst_mem_i.mem[2] = 32'h000081B3; // add x3,x1,x0 (=5, forwarded immediately below)
        dut.inst_mem_i.mem[3] = 32'h00218463; // beq x3,x2,+8 (needs forwarded x3)
        dut.inst_mem_i.mem[4] = 32'h00100213; // addi x4,x0,1 (skipped if branch taken)
        run(20);
        check_reg(4, 32'd0, "Forwarded ALU result correctly used as branch operand");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00000513; // addi x10,x0,0
        dut.inst_mem_i.mem[1] = 32'h04852103; // lw x2,72(x10)
        dut.inst_mem_i.mem[2] = 32'h00010463; // beq x2,x0,+8 (branch depends on loaded value)
        dut.inst_mem_i.mem[3] = 32'h00100193; // addi x3,x0,1 (skipped since mem[72]=0)
        run(25);
        check_reg(3, 32'd0, "Load-use hazard resolved correctly feeding a branch");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00100093; // addi x1,x0,1
        dut.inst_mem_i.mem[1] = 32'h06102223; // sw x1,100(x0)
        dut.inst_mem_i.mem[2] = 32'h00200093; // addi x1,x0,2
        dut.inst_mem_i.mem[3] = 32'h06102223; // sw x1,100(x0) (overwrite)
        dut.inst_mem_i.mem[4] = 32'h00300093; // addi x1,x0,3
        dut.inst_mem_i.mem[5] = 32'h06102223; // sw x1,100(x0) (overwrite again)
        run(30);
        check_mem_word(100, 32'd3, "Repeated stores to same address: last one wins");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h00100093; // addi x1,x0,1
        dut.inst_mem_i.mem[1] = 32'h00108093; // addi x1,x1,1
        dut.inst_mem_i.mem[2] = 32'h00108093; // addi x1,x1,1
        dut.inst_mem_i.mem[3] = 32'h00108093; // addi x1,x1,1
        dut.inst_mem_i.mem[4] = 32'h00108093; // addi x1,x1,1
        run(25);
        check_reg(1, 32'd5, "5-deep RAW chain via repeated ADDI forwarding");

        // ════════════════════════════════════════════════════════
        // SECTION 16 : EXTRA CSR CASES
        // ════════════════════════════════════════════════════════
        $display("\n--- SECTION 16 : EXTRA CSR CASES ---");
        // KNOWN BUG (discovered via these tests): CSRRS/CSRRC write rs1
        // straight into the CSR (same as CSRRW) instead of computing
        // read-modify-write with OR/AND-NOT of rs1 as a bitmask. The read
        // side (old value returned in rd) is correct; only the write-back
        // is wrong. These tests encode the CORRECT RISC-V expected values,
        // so they are expected to FAIL until csr_reg.v (or the CSR write
        // mux) is fixed to do (old | rs1) for CSRRS and (old & ~rs1) for
        // CSRRC instead of a plain overwrite.

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h0F000093; // addi x1,x0,0xF0
        dut.inst_mem_i.mem[1] = 32'h30509073; // csrrw x0,mtvec,x1 (write 0xF0, discard old value)
        dut.inst_mem_i.mem[2] = 32'h00F00113; // addi x2,x0,0x0F
        dut.inst_mem_i.mem[3] = 32'h305121F3; // csrrs x3,mtvec,x2 (read old=0xF0, set bits 0x0F)
        dut.inst_mem_i.mem[4] = 32'h30502273; // csrrs x4,mtvec,x0 (readback, should be 0xFF)
        run(20);
        check_reg(3, 32'hF0, "CSRRS returns pre-modification value 0xF0");
        check_reg(4, 32'hFF, "CSRRS with mask ORs in bits => 0xFF [KNOWN BUG: CSRRS overwrites instead of OR-ing]");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h0FF00093; // addi x1,x0,0xFF
        dut.inst_mem_i.mem[1] = 32'h30509073; // csrrw x0,mtvec,x1 (write 0xFF)
        dut.inst_mem_i.mem[2] = 32'h00F00113; // addi x2,x0,0x0F
        dut.inst_mem_i.mem[3] = 32'h305132F3; // csrrc x5,mtvec,x2 (read old=0xFF, clear bits 0x0F)
        dut.inst_mem_i.mem[4] = 32'h30502373; // csrrs x6,mtvec,x0 (readback, should be 0xF0)
        run(20);
        check_reg(5, 32'hFF, "CSRRC returns pre-modification value 0xFF");
        check_reg(6, 32'hF0, "CSRRC clears masked bits => 0xF0 [KNOWN BUG: CSRRC overwrites instead of AND-NOT]");

        reset_dut;
        dut.inst_mem_i.mem[0] = 32'h07700093; // addi x1,x0,0x77
        dut.inst_mem_i.mem[1] = 32'h30509073; // csrrw x0,mtvec,x1 (write 0x77)
        dut.inst_mem_i.mem[2] = 32'h305023F3; // csrrs x7,mtvec,x0 (pure read, rs1=x0 => no modify)
        dut.inst_mem_i.mem[3] = 32'h30502473; // csrrs x8,mtvec,x0 (read again, should be unchanged)
        run(20);
        check_reg(7, 32'h77, "CSRRS pure-read returns current value");
        check_reg(8, 32'h77, "CSR value unmodified after read-only CSRRS [KNOWN BUG: rs1=x0 still overwrites CSR to 0]");

        // ════════════════════════════════════════════════════════
        // FINAL RESULTS
        // ════════════════════════════════════════════════════════
        $display("\n==========================================");
        $display("  FINAL RESULTS");
        $display("==========================================");
        $display("  PASS  : %0d", pass_count);
        $display("  FAIL  : %0d", fail_count);
        $display("  TOTAL : %0d", pass_count + fail_count);
        if (fail_count == 0)
            $display("    ALL TESTS PASSED");
        else
            $display("    SOME TESTS FAILED (see KNOWN BUG notes at top of file / in test names)");
        $display("==========================================");

        $finish;
    end

endmodule
