`timescale 1ns / 1ps

module top_fpga(
    input  wire clk,
    input  wire rst,
    input  wire timer_interrupt,

    input  wire [7:0]  read_addr,
    input  wire        read_en,

    output wire [31:0] read_data,
    output wire        read_valid
);

    //------------------------------------------------------------
    // Temporary Register Bank Read Interface
    //------------------------------------------------------------
  /*  wire [7:0]  read_addr;
    wire        read_en;
    wire [31:0] read_data;
    wire        read_valid;
*/
    // Temporary assignments
  /*  // These will later come from the UART controller.
    assign read_addr = 8'h00;
    assign read_en   = 1'b0;
*/
    //------------------------------------------------------------
    // Processor + Analytics Wrapper
    //------------------------------------------------------------
    processor_analytics_wrapper u_wrapper (

        .clk               (clk),
        .rst               (rst),
        .timer_interrupt   (timer_interrupt),

        .read_addr         (read_addr),
        .read_en           (read_en),
        .read_data         (read_data),
        .read_valid        (read_valid)

    );

endmodule