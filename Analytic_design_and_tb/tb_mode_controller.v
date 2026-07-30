`timescale 1ns/1ps

module tb_mode_controller;

    reg clk;
    reg rst_n;
    reg mode_select;

    wire en_arch_counters;
    wire en_microarch_counters;

    mode_controller uut (
        .clk(clk),
        .rst_n(rst_n),
        .mode_select(mode_select),
        .en_arch_counters(en_arch_counters),
        .en_microarch_counters(en_microarch_counters)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        mode_select = 0;

        #20 rst_n = 1;
        @(posedge clk);

        // Test Mode 0
        mode_select = 0;
        @(posedge clk);
        @(posedge clk);
        if (en_arch_counters !== 1 || en_microarch_counters !== 0)
            $display("FAIL: Mode 0 output mismatch. arch=%b, microarch=%b", en_arch_counters, en_microarch_counters);
        else
            $display("PASS: Mode 0 correctly enables only architectural counters.");

        // Test Mode 1
        mode_select = 1;
        @(posedge clk);
        @(posedge clk);
        if (en_arch_counters !== 1 || en_microarch_counters !== 1)
            $display("FAIL: Mode 1 output mismatch. arch=%b, microarch=%b", en_arch_counters, en_microarch_counters);
        else
            $display("PASS: Mode 1 correctly enables all counters.");

        $display("Verification Complete.");
        $finish;
    end

endmodule
