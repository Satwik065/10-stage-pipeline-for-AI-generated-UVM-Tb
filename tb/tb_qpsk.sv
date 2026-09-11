`timescale 1ns/1ps
//------------------------------------------------------------
// tb_qpsk.sv
// Exhaustive loopback: all 4 symbols mod -> demod -> compare.
// Total pipeline latency = 2 cycles (1 mod + 1 demod).
// Stimulus driven on negedge; checks on negedge after latency.
// Prints "PASS" or "FAIL".
//------------------------------------------------------------
module tb_qpsk;

    // Clock / reset
    reg clk;
    reg rst;

    // Stimulus
    reg        valid_in;
    reg  [1:0] bits_in;

    // Modulator outputs
    wire              mod_valid;
    wire signed [7:0] mod_i;
    wire signed [7:0] mod_q;

    // Demodulator outputs
    wire       demod_valid;
    wire [1:0] bits_out;

    integer   errors;
    integer   k;
    reg [1:0] pattern [0:3];

    //--------------------------------------------------------
    // DUTs (loopback)
    //--------------------------------------------------------
    qpsk_modulator u_mod (
        .clk       (clk),
        .rst       (rst),
        .valid_in  (valid_in),
        .bits      (bits_in),
        .valid_out (mod_valid),
        .i_out     (mod_i),
        .q_out     (mod_q)
    );

    qpsk_demodulator u_demod (
        .clk       (clk),
        .rst       (rst),
        .valid_in  (mod_valid),
        .i_in      (mod_i),
        .q_in      (mod_q),
        .valid_out (demod_valid),
        .bits      (bits_out)
    );

    //--------------------------------------------------------
    // Clock: 10 ns period
    //--------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    //--------------------------------------------------------
    // Drive one symbol (valid_in high exactly 1 cycle),
    // wait out the 2-cycle pipeline, then check.
    //--------------------------------------------------------
    task run_symbol(input [1:0] sym);
        begin
            @(negedge clk);
            valid_in = 1'b1;
            bits_in  = sym;

            @(negedge clk);
            valid_in = 1'b0;

            @(negedge clk);  // mod (1 cyc) + demod (1 cyc) latency

            if (demod_valid !== 1'b1) begin
                $display("[FAIL] symbol %b: demod valid_out not asserted", sym);
                errors = errors + 1;
            end else if (bits_out !== sym) begin
                $display("[FAIL] symbol %b: decoded %b (I=%0d Q=%0d)",
                         sym, bits_out, mod_i, mod_q);
                errors = errors + 1;
            end else begin
                $display("[ OK ] symbol %b -> I=%0d Q=%0d -> decoded %b",
                         sym, mod_i, mod_q, bits_out);
            end
        end
    endtask

    //--------------------------------------------------------
    // Main sequence
    //--------------------------------------------------------
    initial begin
        rst      = 1'b1;
        valid_in = 1'b0;
        bits_in  = 2'b00;
        errors   = 0;

        pattern[0] = 2'b00;
        pattern[1] = 2'b01;
        pattern[2] = 2'b10;
        pattern[3] = 2'b11;

        $dumpfile("tb_qpsk.vcd");
        $dumpvars(0, tb_qpsk);

        repeat (3) @(negedge clk);
        rst = 1'b0;

        for (k = 0; k < 4; k = k + 1)
            run_symbol(pattern[k]);

        if (errors == 0)
            $display("PASS: all 4 QPSK loopback symbols decoded correctly");
        else
            $display("FAIL: %0d QPSK loopback error(s) detected", errors);

        $finish;
    end

endmodule