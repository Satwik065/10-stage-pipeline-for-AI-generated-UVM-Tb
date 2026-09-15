interface qpsk_dut_if (input logic clk);

  // DUT signals
  logic [1:0] symbol_in;
  logic       valid_in;

  logic signed [7:0] mod_i_out;
  logic signed [7:0] mod_q_out;
  logic              mod_valid_out;

  logic signed [7:0] ch_i_out;
  logic signed [7:0] ch_q_out;
  logic              ch_valid_out;

  logic [1:0] demod_symbol_out;
  logic       demod_valid_out;

  logic       reset_n;

  logic [31:0] channel_seed;

  // Clocking blocks
  clocking drv_cb @(negedge clk);
    output symbol_in;
    output valid_in;
    output reset_n;
    output channel_seed;

    input  mod_i_out;
    input  mod_q_out;
    input  mod_valid_out;

    input  ch_i_out;
    input  ch_q_out;
    input  ch_valid_out;

    input  demod_symbol_out;
    input  demod_valid_out;
  endclocking

  clocking mon_cb @(posedge clk);
    input symbol_in;
    input valid_in;
    input reset_n;
    input channel_seed;

    input mod_i_out;
    input mod_q_out;
    input mod_valid_out;

    input ch_i_out;
    input ch_q_out;
    input ch_valid_out;

    input demod_symbol_out;
    input demod_valid_out;
  endclocking

  // Modports
  modport driver (clocking drv_cb, input clk);
  modport monitor (clocking mon_cb, input clk);

endinterface