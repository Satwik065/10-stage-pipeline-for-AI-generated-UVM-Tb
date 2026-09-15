interface qpsk_dut_if (
input logic clk
);

```
logic       rst;
logic [1:0] symbol_in;
logic [31:0] seed;
logic       valid_in;

logic [1:0] symbol_out;
logic       valid_out;

clocking cb_driver @(negedge clk);
    output rst;
    output symbol_in;
    output seed;
    output valid_in;
endclocking

clocking cb_monitor @(posedge clk);
    input rst;
    input symbol_in;
    input seed;
    input valid_in;
    input symbol_out;
    input valid_out;
endclocking

modport driver (
    clocking cb_driver,
    input clk
);

modport monitor (
    clocking cb_monitor,
    input clk
);
```

endinterface
