interface qpsk_dut_if (
  input logic clk,
  input logic rst_n
);

  logic        valid_in;
  logic [1:0]  symbol_in;

  logic        valid_out;
  logic [1:0]  symbol_out;

  logic [31:0] channel_seed;

  clocking driver_cb @(negedge clk);
    output valid_in;
    output symbol_in;
    output channel_seed;
  endclocking

  clocking monitor_cb @(posedge clk);
    input valid_out;
    input symbol_out;
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