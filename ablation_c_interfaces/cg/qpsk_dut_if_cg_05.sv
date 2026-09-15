interface qpsk_dut_if (
input logic clk,
input logic rst
);

```
logic        valid_in;
logic [1:0]  bits_in;

logic [31:0] seed;

logic        valid_out;
logic [1:0]  bits_out;

clocking cb_drv @(negedge clk);
    output valid_in;
    output bits_in;
    output seed;
endclocking

clocking cb_mon @(posedge clk);
    input valid_out;
    input bits_out;
endclocking

modport driver (
    clocking cb_drv,
    input clk,
    input rst
);

modport monitor (
    clocking cb_mon,
    input clk,
    input rst
);
```

endinterface
