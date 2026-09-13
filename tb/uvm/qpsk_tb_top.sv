`timescale 1ns/1ps
module qpsk_tb_top;
    import uvm_pkg::*;
    import qpsk_pkg::*;
    `include "uvm_macros.svh"

    logic clk = 1'b0;
    logic rst = 1'b1;

    qpsk_dut_if dut_if (.clk(clk), .rst(rst));

    // All 23 cells live inside dut_cells; select at runtime via +CELL=<name>
    dut_cells u_dut (
        .clk      (clk),
        .rst      (rst),
        .ch_seed  (dut_if.ch_seed),
        .valid_in (dut_if.valid_in),
        .bits_in  (dut_if.bits_in),
        .valid_out(dut_if.valid_out),
        .bits_out (dut_if.bits_out)
    );

    always #5 clk = ~clk;

    initial begin
        repeat (5) @(posedge clk);
        rst = 1'b0;
    end

    initial begin
        uvm_config_db#(virtual qpsk_dut_if)::set(null, "*", "vif", dut_if);
        run_test();
    end
endmodule