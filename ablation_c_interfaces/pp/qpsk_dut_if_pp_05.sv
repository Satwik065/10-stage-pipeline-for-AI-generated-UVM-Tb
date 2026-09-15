interface qpsk_dut_if (
  input logic clk,
  input logic rst_n
);

  logic [1:0]  symbol_in;
  logic        valid_in;

  logic signed [7:0] i_out;
  logic signed [7:0] q_out;

  logic [31:0] channel_seed;

  logic [1:0]  symbol_out;
  logic        valid_out;

  clocking driver_cb @(negedge clk);
    default input #1step output #1step;
    output symbol_in;
    output valid_in;
    output channel_seed;
  endclocking

  clocking monitor_cb @(posedge clk);
    default input #1step output #1step;
    input symbol_in;
    input valid_in;
    input i_out;
    input q_out;
    input channel_seed;
    input symbol_out;
    input valid_out;
  endclocking

  modport driver (
    clocking driver_cb,
    input clk,
    input rst_n
  );

  modport monitor (
    clocking monitor_cb,
    input clk,
    input rst_n
  );

endinterface