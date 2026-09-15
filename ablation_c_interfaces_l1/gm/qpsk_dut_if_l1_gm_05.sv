interface qpsk_dut_if(input logic clk, input logic rst_n);
logic [1:0]  symbol_in;
logic        valid_in;
logic [31:0] seed;
logic [1:0]  demod_out;
logic        valid_out;

clocking driver_cb @(negedge clk);
default input #1ns output #1ns;
output symbol_in;
output valid_in;
output seed;
endclocking

clocking monitor_cb @(posedge clk);
default input #1ns output #0ns;
input symbol_in;
input valid_in;
input seed;
input demod_out;
input valid_out;
endclocking

modport driver(clocking driver_cb, input clk, input rst_n);
modport monitor(clocking monitor_cb, input clk, input rst_n);
endinterface