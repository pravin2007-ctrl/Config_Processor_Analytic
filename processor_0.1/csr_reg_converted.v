module csr_reg
(
    input          clk,
    input           rst,
    input   [31: 0] addr,
    input   [31: 0] wdata,   // data from rs1
    input   [31: 0] pc,
    input          trap,    // interrupt or exception
    input           csr_rd,  // control signal for read
    input           csr_wr,  // control signal for write
    input           is_mret, // control signal for MRET inst
    input   [31: 0] inst,
    output reg [31: 0] rdata,
    output reg [31: 0] epc,
    output reg         epc_taken // it's a flag which is fed to the mux right before PC
);
    reg [31: 0] csr_mem [0:5];
    reg         is_device_int_en;
    reg         is_global_int_en;

    // Convenience: current value of the CSR named in inst[31:20],
    // read independently of csr_rd so it's available for RMW writes.
    reg [31:0] csr_old;
    always @(*)
    begin
        case (inst[31:20])
            12'h300: csr_old = csr_mem[0]; // mstatus
            12'h304: csr_old = csr_mem[1]; // mie
            12'h305: csr_old = csr_mem[2]; // mtvec
            12'h341: csr_old = csr_mem[3]; // mepc
            12'h342: csr_old = csr_mem[4]; // mcause
            12'h344: csr_old = csr_mem[5]; // mip
            default: csr_old = 32'b0;
        endcase
    end

    // Compute the value that should actually be written, based on
    // funct3: CSRRW (001/101) = overwrite, CSRRS (010/110) = set bits,
    // CSRRC (011/111) = clear bits.
    reg [31:0] csr_new;
    always @(*)
    begin
        case (inst[13:12]) // low 2 bits of funct3 distinguish W/S/C regardless of imm vs reg form
            2'b01:   csr_new = wdata;              // CSRRW / CSRRWI
            2'b10:   csr_new = csr_old | wdata;    // CSRRS / CSRRSI
            2'b11:   csr_new = csr_old & ~wdata;   // CSRRC / CSRRCI
            default: csr_new = wdata;
        endcase
    end

    always @(*)
    begin
        if (csr_rd)
        begin
            case (inst[31:20])
                12'h300: rdata = csr_mem[0]; // mstatus 
                12'h304: rdata = csr_mem[1]; // mie 
                12'h305: rdata = csr_mem[2]; // mtvec 
                12'h341: rdata = csr_mem[3]; // mepc 
                12'h342: rdata = csr_mem[4]; // mcause 
                12'h344: rdata = csr_mem[5]; // mip 
            endcase
        end
        else
        begin
            rdata = 32'b0; 
        end
    end

    always @(posedge clk)
    begin
        if (rst)
        begin
            csr_mem[0] <= 32'b0;
            csr_mem[1] <= 32'b0;
            csr_mem[2] <= 32'b0;
            csr_mem[3] <= 32'b0;
            csr_mem[4] <= 32'b0;
            csr_mem[5] <= 32'b0;
        end
        else if (csr_wr)
        begin
            case (inst[31:20])
                12'h300: csr_mem[0] <= csr_new; // mstatus
                12'h304: csr_mem[1] <= csr_new; // mie
                12'h305: csr_mem[2] <= csr_new; // mtvec
                12'h341: csr_mem[3] <= csr_new; // mepc
                12'h342: csr_mem[4] <= csr_new; // mcause
                12'h344: csr_mem[5] <= csr_new; // mip
            endcase
        end
        if (trap)
        begin
            csr_mem[4]       <= 32'b0;
            csr_mem[5]       <= csr_mem[5] | 32'd128;
            is_device_int_en = csr_mem[5][7] & csr_mem[1][7];
            is_global_int_en = csr_mem[0][3] & is_device_int_en;
            if (is_global_int_en)
            begin
                csr_mem[3] = pc;
                epc        <= csr_mem[2] + (csr_mem[4] << 2);
                epc_taken  <= 1'b1;
            end
        end
        else if (is_mret)
        begin
            epc_taken <= 1'b1;
            epc       <= csr_mem[3];
        end
        else
        begin
            epc_taken <= 1'b0;
            epc <= pc;
        end
    end
endmodule