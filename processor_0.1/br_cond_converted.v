module br_cond
(
    input  [31:0] rdata1,
    input  [31:0] rdata2,
    input  [2:0]  br_type,

    output reg    br_taken
);

always @(*) begin

    case(br_type)

        3'b000: br_taken = (rdata1 == rdata2);                           // BEQ

        3'b001: br_taken = (rdata1 != rdata2);                           // BNE

        3'b100: br_taken = ($signed(rdata1) < $signed(rdata2));          // BLT

        3'b101: br_taken = ($signed(rdata1) >= $signed(rdata2));         // BGE

        3'b110: br_taken = (rdata1 < rdata2);                            // BLTU

        3'b111: br_taken = (rdata1 >= rdata2);                           // BGEU

        default: br_taken = 1'b0;

    endcase

end

endmodule