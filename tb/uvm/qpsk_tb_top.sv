`timescale 1ns/1ps
module qpsk_tb_top;
    import uvm_pkg::*;
    import qpsk_pkg::*;
    `include "uvm_macros.svh"

    logic clk = 1'b0;
    logic rst = 1'b1;

    qpsk_dut_if dut_if (.clk(clk), .rst(rst));

    logic              mod_valid;
    logic signed [7:0] mod_i, mod_q;
    logic              ch_valid;
    logic signed [7:0] ch_i, ch_q;

    qpsk_modulator u_mod (
        .clk(clk), .rst(rst),
        .valid_in(dut_if.valid_in), .bits(dut_if.bits_in),
        .valid_out(mod_valid), .i_out(mod_i), .q_out(mod_q));

    channel u_ch (
        .clk(clk), .rst(rst), .seed(dut_if.ch_seed),
        .valid_in(mod_valid), .i_in(mod_i), .q_in(mod_q),
        .valid_out(ch_valid), .i_out(ch_i), .q_out(ch_q));

    qpsk_demodulator u_demod (
        .clk(clk), .rst(rst), .valid_in(ch_valid),
        .i_in(ch_i), .q_in(ch_q),
        .valid_out(dut_if.valid_out), .bits(dut_if.bits_out));

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