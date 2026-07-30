// In RISC-V XLEN denotes the bits of CPU. XLEN=32 

module pc 
(
    input         clk,
    input         rst,
    input         en,
    input  [31:0] pc_in,
    output reg [31:0] pc_out
);

    always @(posedge clk)
    begin
        if( rst )
        begin
            pc_out <= 0;
        end
        else if ( en )
        begin
            pc_out <= pc_in;
        end
    end

endmodule
