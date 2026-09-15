interface qpsk_dut_if (
input logic clk,
input logic rst
);

```
logic       valid_in;
logic [1:0] symbol_in;

logic [31:0] channel_seed;

logic       valid_out;
logic [1:0] symbol_out;

clocking cb_driver @(negedge clk);
    output valid_in;
    output symbol_in;
    output channel_seed;
endclocking

clocking cb_monitor @(posedge clk);
    input valid_out;
    input symbol_out;
endclocking

modport driver (
    clocking cb_driver,
    input clk,
    input rst
);

modport monitor (
    clocking cb_monitor,
    input clk,
    input rst
);
```

endinterface
