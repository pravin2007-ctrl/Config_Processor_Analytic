`timescale 1ns/1ps

module mode_controller (
    input  wire clk,
    input  wire rst_n,
    
    // 0 = Architectural Profiling
    // 1 = Microarchitectural Profiling
    input  wire mode_select,

    // Enable Signals to Counter Groups
    output reg  en_arch_counters,
    output reg  en_microarch_counters
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            en_arch_counters      <= 1'b0;
            en_microarch_counters <= 1'b0;
        end else begin
            case (mode_select)
                1'b0: begin // Architectural Mode
                    en_arch_counters      <= 1'b1;
                    // Disable microarchitectural counters to save dynamic power
                    en_microarch_counters <= 1'b0;
                end
                1'b1: begin // Microarchitectural Mode
                    // Architectural counters are still needed to calculate base IPC and CPI
                    en_arch_counters      <= 1'b1;
                    en_microarch_counters <= 1'b1;
                end
                default: begin
                    en_arch_counters      <= 1'b1;
                    en_microarch_counters <= 1'b1;
                end
            endcase
        end
    end

endmodule
