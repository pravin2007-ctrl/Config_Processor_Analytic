module data_mem
(
    input        clk,
    input         rd_en,
    input         wr_en,
    input  [31:0] addr,
    input  [ 2:0] mem_acc_mode,
    input  [31:0] wdata,
    output reg [31:0] rdata
);
    parameter BYTE              = 3'b000;
    parameter HALFWORD          = 3'b001;
    parameter WORD              = 3'b010;
    parameter BYTE_UNSIGNED     = 3'b011;
    parameter HALFWORD_UNSIGNED = 3'b100;

    reg [7:0] data_mem [0:4095];
    wire [6:0] mem_index;

assign mem_index = addr[6:0];

    // Here I'm using big-endian byte ordering in which MSB is stored at lower address and LSB at higher address

    // asynchronous read
    always @(*)
    begin
     if(rd_en)
    begin

        $display("--------------------------------");
        $display("MEMORY READ");
        $display("Time = %0t",$time);
        $display("rd_en = %b",rd_en);
        $display("addr = %h",mem_index);

        case(mem_acc_mode)
            BYTE:
                rdata = $signed (data_mem[mem_index]) ;
            HALFWORD:
                rdata = $signed({data_mem[mem_index], data_mem[mem_index+1]});
            WORD:
                rdata = $signed({data_mem[mem_index], data_mem[mem_index+1], data_mem[mem_index+2], data_mem[mem_index+3]});
            BYTE_UNSIGNED:
                rdata = {24'b0, {data_mem[mem_index]}};
            HALFWORD_UNSIGNED:
                rdata = {16'b0, {data_mem[mem_index]}, {data_mem[mem_index+1]}};
            endcase
            
        end
    end

    //synchronous write
always @(posedge clk)
begin
    if (wr_en)
    begin

        $display("--------------------------------");
        $display("MEMORY WRITE");
        $display("Time  = %0t", $time);
        $display("wr_en = %b", wr_en);
        $display("addr  = %h", mem_index);
        $display("mode  = %b", mem_acc_mode);
        $display("data  = %h", wdata);

        case(mem_acc_mode)

        BYTE:
            data_mem[mem_index] <= wdata[7:0];

        HALFWORD:
        begin
            data_mem[mem_index]   <= wdata[15:8];
            data_mem[mem_index+1] <= wdata[7:0];
        end

        WORD:
        begin
            data_mem[mem_index]   <= wdata[31:24];
            data_mem[mem_index+1] <= wdata[23:16];
            data_mem[mem_index+2] <= wdata[15:8];
            data_mem[mem_index+3] <= wdata[7:0];
        end

        endcase
    end
end
endmodule