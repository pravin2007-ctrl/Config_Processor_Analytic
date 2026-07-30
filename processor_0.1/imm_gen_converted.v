module imm_gen
(
    input  [31:0] inst,
    output reg [31:0] imm_val
);

 always @(*) begin
    imm_val = 32'd0;      // default value

    case(inst[6:0])

        7'b0010011: begin
            case(inst[14:12])
                3'b011: imm_val = {20'b0,inst[31:20]};
                3'b101: imm_val = $signed(inst[24:20]);
                default: imm_val = $signed(inst[31:20]);
            endcase
        end

        7'b0100011:
            imm_val = $signed({inst[31:25],inst[11:7]});

        7'b1100011:
            imm_val = $signed({inst[31],inst[7],inst[30:25],inst[11:8],1'b0});

        7'b0110111:      // LUI
            imm_val = {inst[31:12],12'b0};

        7'b0010111:      // AUIPC
            imm_val = {inst[31:12],12'b0};

        7'b1101111:
            imm_val = $signed({inst[31],inst[19:12],inst[20],inst[30:21],1'b0});

        7'b1100111:
            imm_val = $signed(inst[31:20]);

        7'b0000011:
            imm_val = {20'b0,inst[31:20]};

        default:
            imm_val = 32'd0;
    endcase
end

endmodule
