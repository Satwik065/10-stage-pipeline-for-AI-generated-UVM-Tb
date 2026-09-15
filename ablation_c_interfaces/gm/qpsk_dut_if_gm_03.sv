interface qpsk_dut_if (input logic clk, input logic rst_n);

// Control and Data Signals
logic [1:0]        symbol_in;
logic              valid_in;
logic [31:0]       channel_seed;

// Intermediate / Observability Signals
logic signed [7:0] mod_i;
logic signed [7:0] mod_q;
logic              mod_valid;

logic signed [7:0] chan_i;
logic signed [7:0] chan_q;
logic              chan_valid;

logic [1:0]        symbol_out;
logic              valid_out;

// Driver Clocking Block (negedge drive)
clocking cb_drv @(negedge clk);
default input #1step output #1ns;
output symbol_in;
output valid_in;
output channel_seed;
endclocking

// Monitor Clocking Block (posedge monitor)
clocking cb_mon @(posedge clk);
default input #1step output #1ns;
input symbol_in;
input valid_in;
input channel_seed;
input mod_i;
input mod_q;
input mod_valid;
input chan_i;
input chan_q;
input chan_valid;
input symbol_out;
input valid_out;
endclocking

// Modports
modport driver_mp (clocking cb_drv, input clk, input rst_n);
modport monitor_mp (clocking cb_mon, input clk, input rst_n);

endinterface