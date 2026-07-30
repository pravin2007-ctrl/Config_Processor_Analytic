`timescale 1ns/1ps

module register_bank (
    clk,
    rst_n,
    execution_done,
    reg_inputs,
    read_addr,
    read_en,
    read_data,
    read_valid
);

    parameter G_NUM_REGS   = 32; // Number of registers
    parameter G_DATA_WIDTH = 32; // Width of each register
    parameter G_ADDR_WIDTH = 8;  // Width of address bus

    input  wire                                     clk;
    input  wire                                     rst_n;

    // Control
    input  wire                                     execution_done;

    // Data inputs (Flattened vector containing all metrics and counters)
    input  wire [G_NUM_REGS * G_DATA_WIDTH - 1 : 0] reg_inputs;

    // Read Interface
    input  wire [G_ADDR_WIDTH - 1 : 0]              read_addr;
    input  wire                                     read_en;
    
    output reg  [G_DATA_WIDTH - 1 : 0]              read_data;
    output reg                                      read_valid;

    // Internal memory bank
    reg [G_DATA_WIDTH - 1 : 0] internal_regs [0 : G_NUM_REGS - 1];
    reg                        freeze_lock;
    
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_data   <= {G_DATA_WIDTH{1'b0}};
            read_valid  <= 1'b0;
            freeze_lock <= 1'b0;
            for (i = 0; i < G_NUM_REGS; i = i + 1) begin
                internal_regs[i] <= {G_DATA_WIDTH{1'b0}};
            end
        end else begin
            if (execution_done) begin
                freeze_lock <= 1'b1;
            end

            // 1. Capture Data
            // While execution is not done, sample inputs. 
            // Once done, freeze the state persistently for stable readout.
            if (!execution_done && !freeze_lock) begin
                for (i = 0; i < G_NUM_REGS; i = i + 1) begin
                    // Unpack the 1D input bus into the 2D memory array
                    internal_regs[i] <= reg_inputs >> (i * G_DATA_WIDTH);
                end
            end

            // 2. Read Interface
            if (read_en) begin
                if (read_addr < G_NUM_REGS) begin
                    read_data  <= internal_regs[read_addr];
                    read_valid <= 1'b1;
                end else begin
                    read_data  <= {G_DATA_WIDTH{1'b0}}; // Out of bounds read
                    read_valid <= 1'b0;
                end
            end else begin
                read_data  <= {G_DATA_WIDTH{1'b0}};
                read_valid <= 1'b0;
            end
        end
    end

endmodule
