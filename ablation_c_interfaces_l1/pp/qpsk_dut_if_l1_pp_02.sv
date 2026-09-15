interface qpsk_dut_if (
  input logic clk,
  input logic rst_n
);

  logic [1:0] symbol_in;
  logic       valid_in;
  logic [31:0] channel_seed;

  logic [1:0] symbol_out;
  logic       valid_out;

  clocking cb_driver @(negedge clk);
    default input #1step output #1step;
    output symbol_in;
    output valid_in;
    output channel_seed;
  endclocking

  clocking cb_monitor @(posedge clk);
    default input #1step output #1step;
    input symbol_out;
    input valid_out;
  endclocking

  modport driver (
    clocking cb_driver,
    input clk,
    input rst_n
  );

  modport monitor (
    clocking cb_monitor,
    input clk,
    input rst_n
  );

endinterface