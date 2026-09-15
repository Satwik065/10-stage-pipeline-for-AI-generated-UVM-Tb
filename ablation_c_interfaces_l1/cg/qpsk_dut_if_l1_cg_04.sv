interface qpsk_dut_if (
input logic clk,
input logic rst
);

```
logic [1:0]  symbol_in;
logic        valid_in;
logic [31:0] channel_seed;

logic [1:0]  symbol_out;
logic        valid_out;

clocking cb_driver @(negedge clk);
    output symbol_in;
    output valid_in;
    output channel_seed;
endclocking

clocking cb_monitor @(posedge clk);
    input symbol_out;
    input valid_out;
endclocking

modport driver (
    clocking cb_driver,
    input rst
);

modport monitor (
    clocking cb_monitor,
    input rst
);
```

endinterface
