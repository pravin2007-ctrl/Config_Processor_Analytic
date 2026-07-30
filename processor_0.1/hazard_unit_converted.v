module hazard_unit
(
    // Forwarding
    input  [ 4:0] rs1_DE,
    input   [ 4:0] rs2_DE,
    input   [ 4:0] rd_MW,
    input          rf_en_MW,
    output reg        forward_a,
    output reg        forward_b,

    // Stalling and Flusing 
    input   [31:0] inst_IF,
    input   [ 4:0] rd_DE,
    input   [ 1:0] wb_sel_DE,
    input          br_taken,
    output reg        stall_IF, // to PC register
    output reg        flush_DE // Flush DE stage
);
    reg stall_lw;

    // Operand A
// Operand A
always @(*)
begin
    // Default value
    forward_a = 1'b0;

    if (rf_en_MW)
    begin
        if ((rs1_DE == rd_MW) && (rs1_DE != 5'd0))
        begin
            forward_a = 1'b1;
        end
    end
end
    
    // Operand B
// Operand B
always @(*)
begin
    // Default value
    forward_b = 1'b0;

    if (rf_en_MW)
    begin
        if ((rs2_DE == rd_MW) && (rs2_DE != 5'd0))
        begin
            forward_b = 1'b1;
        end
    end
end

    // Stalling
    always @(*)
    begin
        if (wb_sel_DE == 2'b10)
        begin
            if ((rd_DE != 5'd0) &&
    ((inst_IF[19:15] == rd_DE) ||
     (inst_IF[24:20] == rd_DE)))
            begin
                stall_lw = 1'b1;
            end
            else
            begin
                stall_lw = 1'b0;
            end
        end
        else
        begin
            stall_lw = 1'b0;
        end
        stall_IF = stall_lw;
        flush_DE = stall_lw || br_taken;
    end

endmodule

