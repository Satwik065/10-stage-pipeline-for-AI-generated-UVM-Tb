interface qpsk_dut_if (
  input logic clk,
  input logic rst_n
);

  logic        valid_in;
  logic [1:0]  symbol_in;
  logic [31:0] channel_seed;

  logic        valid_out;
  logic [1:0]  symbol_out;

  clocking driver_cb @(negedge clk);
    default input #1step output #1step;
    output valid_in;
    output symbol_in;
    output channel_seed;
  endclocking

  clocking monitor_cb @(posedge clk);
    default input #1step output #1step;
    input valid_out;
    input symbol_out;
  endclocking

  modport driver (
    input  clk,
    input  rst_n,
    clocking driver_cb
  );

  modport monitor (
    input  clk,
    input  rst_n,
    clocking monitor_cb
  );

endinterface