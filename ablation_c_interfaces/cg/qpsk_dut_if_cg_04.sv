interface qpsk_dut_if (
input logic clk,
input logic rst
);

```
logic [31:0] seed;

logic        valid_in;
logic [1:0]  bits_in;

logic        valid_out;
logic [1:0]  bits_out;

clocking cb_driver @(negedge clk);
    output valid_in;
    output bits_in;
    output seed;
endclocking

clocking cb_monitor @(posedge clk);
    input rst;
    input valid_in;
    input bits_in;
    input seed;
    input valid_out;
    input bits_out;
endclocking

modport driver (
    clocking cb_driver,
    input rst
);

modport monitor (
    clocking cb_monitor
);
```

endinterface
