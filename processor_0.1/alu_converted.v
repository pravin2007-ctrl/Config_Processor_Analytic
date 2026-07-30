module alu 
(
    input  [ 3:0] aluop,
    input  [31:0] opr_a,
    input  [31:0] opr_b,
    output reg [31:0] opr_res
);
    
    always @(*)
    begin
        case(aluop)
            4'b0000: opr_res = opr_a            +  opr_b;
            4'b0001: opr_res = opr_a            -  opr_b;
            4'b0010: opr_res = opr_a            << opr_b[4:0];
            4'b0011: opr_res = $signed(opr_a) < $signed(opr_b);
            4'b0100: opr_res = $unsigned(opr_a) <  $unsigned(opr_b);
            4'b0101: opr_res = opr_a            ^  opr_b;
            4'b0110: opr_res = opr_a            >> opr_b[4:0];
            4'b0111: opr_res = $signed(opr_a) >>> opr_b[4:0];
            4'b1000: opr_res = opr_a            | opr_b;
            4'b1001: opr_res = opr_a            & opr_b;
            4'b1010: opr_res = opr_b; // pass opr_b
            default: opr_res = 32'd0;

        endcase
    end

endmodule