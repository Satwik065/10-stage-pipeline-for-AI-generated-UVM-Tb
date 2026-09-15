interface qpsk_dut_if (
input logic clk,
input logic rst
);

```
logic [1:0]  symbol_in;
logic        valid_in;

logic [31:0] seed;

logic [1:0]  symbol_out;
logic        valid_out;

clocking driver_cb @(negedge clk);
    output symbol_in;
    output valid_in;
    output seed;
endclocking

clocking monitor_cb @(posedge clk);
    input rst;
    input symbol_in;
    input valid_in;
    input seed;
    input symbol_out;
    input valid_out;
endclocking

modport driver (
    input  clk,
    input  rst,
    clocking driver_cb
);

modport monitor (
    input  clk,
    input  rst,
    clocking monitor_cb
);
```

endinterface
