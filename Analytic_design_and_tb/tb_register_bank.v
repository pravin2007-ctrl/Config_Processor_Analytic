`timescale 1ns/1ps

module tb_register_bank;

    // Parameters
    parameter G_NUM_REGS   = 4;
    parameter G_DATA_WIDTH = 32;
    parameter G_ADDR_WIDTH = 8;

    // Inputs
    reg                                     clk;
    reg                                     rst_n;
    reg                                     execution_done;
    reg [G_NUM_REGS * G_DATA_WIDTH - 1 : 0] reg_inputs;
    reg [G_ADDR_WIDTH - 1 : 0]              read_addr;
    reg                                     read_en;

    // Outputs
    wire [G_DATA_WIDTH - 1 : 0]             read_data;
    wire                                    read_valid;

    // Instantiate UUT
    register_bank #(
        G_NUM_REGS,
        G_DATA_WIDTH,
        G_ADDR_WIDTH
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .execution_done(execution_done),
        .reg_inputs(reg_inputs),
        .read_addr(read_addr),
        .read_en(read_en),
        .read_data(read_data),
        .read_valid(read_valid)
    );

    // Clock gen
    always #5 clk = ~clk;

    initial begin
        // Init
        clk = 0;
        rst_n = 0;
        execution_done = 0;
        reg_inputs = 0;
        read_addr = 0;
        read_en = 0;

        // Reset
        #20 rst_n = 1;
        @(posedge clk);

        // 1. Verify Transparent Sampling (execution_done = 0)
        reg_inputs = {32'hDDDDDDDD, 32'hCCCCCCCC, 32'hBBBBBBBB, 32'hAAAAAAAA}; 
        @(posedge clk);
        @(posedge clk);

        // Read out reg 0
        read_addr = 0;
        read_en = 1;
        @(posedge clk);
        #1; // let register_bank's NBA-scheduled read_data/read_valid update settle
        read_en = 0;
        if (read_data !== 32'hAAAAAAAA || read_valid !== 1) $display("FAIL: Reg0 expected AAAAAAAA, got %h", read_data);
        else $display("PASS: Reg0 = %h", read_data);
        
        // 2. Test Freeze (execution_done = 1)
        @(posedge clk);
        execution_done = 1;
        @(posedge clk);

        // Change inputs, should not affect frozen registers
        reg_inputs = {32'hFFFFFFFF, 32'hEEEEEEEE, 32'h99999999, 32'h88888888}; 
        @(posedge clk);
        @(posedge clk);

        // Read out reg 2
        read_addr = 2;
        read_en = 1;
        @(posedge clk);
        #1; // let register_bank's NBA-scheduled read_data/read_valid update settle
        read_en = 0;
        // Reg 2 should still be CCCCCCCC
        if (read_data !== 32'hCCCCCCCC || read_valid !== 1) $display("FAIL: Reg2 expected CCCCCCCC, got %h", read_data);
        else $display("PASS: Reg2 = %h", read_data);

        // 3. Test out of bounds read
        @(posedge clk);
        read_addr = 10;
        read_en = 1;
        @(posedge clk);
        #1; // let register_bank's NBA-scheduled read_data/read_valid update settle
        read_en = 0;
        if (read_data !== 32'h0 || read_valid !== 0) $display("FAIL: OOB read expected 0 and invalid, got %h, valid=%b", read_data, read_valid);
        else $display("PASS: OOB read handled correctly");

        $display("Verification Complete.");
        $finish;
    end

endmodule
