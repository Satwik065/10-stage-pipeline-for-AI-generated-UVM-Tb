`timescale 1ns/1ps
//----------------------------------------------------------------------
// tb_p1_check.sv — Stage 1 contract false-fire harness (Verilator).
// Instantiates the full 3-module loopback, drives the §3 envelope
// (40 symbols, >=10 of each, 1-cycle valid, >=2 idle), waits for
// confirmed rst deassertion per §2, and reports [RESULT] PASS only if
// exactly 40 valid_outs emerge. Binds qpsk_sva at the loopback boundary.
// Any [SVA][P#] fire in the log = contract defect.
//----------------------------------------------------------------------
module tb_p1_check;
    logic              clk        = 1'b0;
    logic              rst        = 1'b1;
    logic [31:0]       ch_seed    = 32'hDEADBEEF;
    logic              valid_in   = 1'b0;
    logic [1:0]        bits_in    = 2'b00;

    logic              valid_mod_out, valid_ch_out, valid_out;
    logic signed [7:0] i_mod, q_mod, i_ch, q_ch;
    logic [1:0]        bits_out;

    // module-scope statics (Verilator requires these NOT be declared inside initial)
    logic [1:0] sched [0:39];
    int         valid_out_count = 0;
    int         s_i             = 0;

    qpsk_modulator u_mod (
        .clk(clk), .rst(rst), .valid_in(valid_in), .bits(bits_in),
        .valid_out(valid_mod_out), .i_out(i_mod), .q_out(q_mod));

    channel u_ch (
        .clk(clk), .rst(rst), .seed(ch_seed),
        .valid_in(valid_mod_out), .i_in(i_mod), .q_in(q_mod),
        .valid_out(valid_ch_out), .i_out(i_ch), .q_out(q_ch));

    qpsk_demodulator u_demod (
        .clk(clk), .rst(rst), .valid_in(valid_ch_out),
        .i_in(i_ch), .q_in(q_ch),
        .valid_out(valid_out), .bits(bits_out));

    // Contract SVA, bound at the loopback boundary
    qpsk_sva u_sva (
        .clk(clk), .rst(rst),
        .valid_in(valid_in), .valid_out(valid_out),
        .bits_in(bits_in), .bits_out(bits_out));

    always #5 clk = ~clk;

    // schedule: exactly 10 of each symbol, in a fixed deterministic order
    initial begin
        for (int k = 0; k < 10; k++) begin
            sched[4*k+0] = 2'b00;
            sched[4*k+1] = 2'b01;
            sched[4*k+2] = 2'b10;
            sched[4*k+3] = 2'b11;
        end
        if ($value$plusargs("CHSEED=%d", s_i)) ch_seed = s_i[31:0];
    end

    initial begin
        // §2: reset asserted >= 3 cycles (we use 5)
        repeat (5) @(posedge clk);
        rst = 1'b0;
        // §2: drive only after rst observed deasserted for >= 1 cycle
        @(posedge clk);
        @(posedge clk);

        // §3 envelope: 1-cycle valid, then >=2 idle, x40 symbols
        for (int i = 0; i < 40; i++) begin
            @(posedge clk);
            valid_in = 1'b1;
            bits_in  = sched[i];
            @(posedge clk);
            valid_in = 1'b0;
            bits_in  = 2'b00;
            repeat (2) @(posedge clk);   // 2 idle cycles
        end

        // drain: L=6 + slack
        repeat (16) @(posedge clk);

        if (valid_out_count == 40)
            $display("[RESULT] PASS valid_out=%0d", valid_out_count);
        else
            $display("[RESULT] FAIL valid_out=%0d expected=40", valid_out_count);
        $finish;
    end

    always @(posedge clk) if (!rst && valid_out) valid_out_count++;

    initial begin
        #200000;
        $display("[RESULT] FAIL watchdog");
        $finish;
    end
endmodule