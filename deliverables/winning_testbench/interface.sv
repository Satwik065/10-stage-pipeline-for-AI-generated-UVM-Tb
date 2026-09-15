`ifndef QPSK_DUT_IF_SV
`define QPSK_DUT_IF_SV
`timescale 1ns/1ps
//----------------------------------------------------------------------
// qpsk_dut_if — Stage 1 contract artifact (Constitution v2.1).
// TB-boundary view of the v2 3-module DUT chain (mod -> channel -> demod).
// Rename map (locked in the Stage 1 AST checker):
//   bits_in  -> qpsk_modulator.bits
//   bits_out -> qpsk_demodulator.bits
//   ch_seed  -> channel.seed
// Contract facts relied on (v2.1 §2): baseline latency 3, L=6,
// data meaningful only at valid_out, back-to-back stimulus LEGAL
// (§13 execution-confirmed), reset-to-stimulus rule MANDATORY.
// Drive convention: negedge drive (drv_cb), posedge sample (mon_cb).
//----------------------------------------------------------------------
interface qpsk_dut_if (
    input logic clk,
    input logic rst
);

    // ---- DUT-facing members -------------------------------------------
    logic [31:0] ch_seed;     // -> channel.seed (LFSR seed, LOCKED_SEEDS only, §4)
    logic        valid_in;    // -> qpsk_modulator.valid_in
    logic [1:0]  bits_in;     // -> qpsk_modulator.bits {I_bit, Q_bit}
    logic        valid_out;   // <- qpsk_demodulator.valid_out
    logic [1:0]  bits_out;    // <- qpsk_demodulator.bits

    // ---- clocking blocks ----------------------------------------------
    clocking drv_cb @(negedge clk);
        default input #1step output #0;
        output ch_seed, valid_in, bits_in;
        input  valid_out, bits_out;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1step;
        input valid_out, bits_out;
    endclocking

    // ---- modports -------------------------------------------------------
    modport driver (
        output ch_seed, valid_in, bits_in,
        input  clk, rst, valid_out, bits_out,
        clocking drv_cb
    );

    modport monitor (
        input clk, rst, ch_seed, valid_in, bits_in, valid_out, bits_out,
        clocking mon_cb
    );

endinterface : qpsk_dut_if
`endif