module inst_mem
(
    input [31:0] addr,
    output reg [31:0] data
);

    reg [31:0] mem [0:1023];

    integer i;

    initial
    begin
        // Initialize every location with NOP
        for(i = 0; i < 100; i = i + 1)
            mem[i] = 32'h00000013;
    end

    always @(*)
    begin
        data = mem[addr[31:2]];
    end

endmodule