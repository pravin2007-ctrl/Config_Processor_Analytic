module reg_file 
(
    input         clk,
    input         rf_en,
    input  [ 4:0] rs1,
    input  [ 4:0] rs2,
    input  [ 4:0] rd,
    input  [31:0] wdata,
    output reg [31:0] rdata1,
    output reg [31:0] rdata2
);

    reg [31:0] reg_mem [0:31];

    // asynchronous read
    always @(*) 
    begin
        rdata1 = reg_mem[rs1];
        rdata2 = reg_mem[rs2];
    end

    // synchronus write
    always @(negedge clk) 
    begin
        if(rf_en)
        begin
            if (rd != 5'b00000)
            begin
                reg_mem[rd] <= wdata;
            end
        end
    end

endmodule