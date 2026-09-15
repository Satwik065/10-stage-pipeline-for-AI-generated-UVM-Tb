interface qpsk_dut_if (
  input logic clk,
  input logic rst_n
);

  // Driver stimuli
  logic [1:0] symbol_in;
  logic       symbol_valid_in;

  // DUT response
  logic [1:0] symbol_out;
  logic       symbol_valid_out;

  // Channel configuration
  logic [31:0] channel_seed;

  // Clocking block for driver (falling edge)
  clocking drv_cb @(negedge clk);
    output symbol_in;
    output symbol_valid_in;
    output channel_seed;
    input  symbol_out;
    input  symbol_valid_out;
  endclocking

  // Clocking block for monitor (rising edge)
  clocking mon_cb @(posedge clk);
    input symbol_in;
    input symbol_valid_in;
    input channel_seed;
    input symbol_out;
    input symbol_valid_out;
  endclocking

  // Modports
  modport driver (clocking drv_cb, input clk, input rst_n);
  modport monitor (clocking mon_cb, input clk, input rst_n);

endinterface