interface qpsk_dut_if (input logic clk, input logic rst_n);
logic        valid_in;
logic [1:0]  symbol_in;
logic [31:0] seed;
logic        valid_out;
logic [1:0]  symbol_out;

clocking drv_cb @(negedge clk);
default input #1ns output #1ns;
output valid_in;
output symbol_in;
output seed;
endclocking

clocking mon_cb @(posedge clk);
default input #1ns output #1ns;
input valid_in;
input symbol_in;
input seed;
input valid_out;
input symbol_out;
endclocking

modport driver (clocking drv_cb, input clk, input rst_n);
modport monitor (clocking mon_cb, input clk, input rst_n);
endinterface