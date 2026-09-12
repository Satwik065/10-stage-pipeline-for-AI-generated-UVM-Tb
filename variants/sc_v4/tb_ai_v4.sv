`timescale 1ns / 1ps
//======================================================================
// Self-checking testbench : QPSK modulator -> demodulator loopback
//======================================================================
module tb_qpsk_loopback;

  // ------------------------------------------------------------------
  // Signals
  // ------------------------------------------------------------------
  reg               clk;
  reg               rst;

  reg               mod_valid_in;
  reg  [1:0]        mod_bits;
  wire              mod_valid_out;
  wire signed [7:0] mod_i_out;
  wire signed [7:0] mod_q_out;

  wire              demod_valid_in;
  wire signed [7:0] demod_i_in;
  wire signed [7:0] demod_q_in;
  wire              demod_valid_out;
  wire [1:0]        demod_bits;

  // ------------------------------------------------------------------
  // DUTs
  // ------------------------------------------------------------------
  qpsk_modulator u_mod (
    .clk       (clk),
    .rst       (rst),
    .valid_in  (mod_valid_in),
    .bits      (mod_bits),
    .valid_out (mod_valid_out),
    .i_out     (mod_i_out),
    .q_out     (mod_q_out)
  );

  // loopback: modulator feeds demodulator directly
  assign demod_valid_in = mod_valid_out;
  assign demod_i_in     = mod_i_out;
  assign demod_q_in     = mod_q_out;

  qpsk_demodulator u_demod (
    .clk       (clk),
    .rst       (rst),
    .valid_in  (demod_valid_in),
    .i_in      (demod_i_in),
    .q_in      (demod_q_in),
    .valid_out (demod_valid_out),
    .bits      (demod_bits)
  );

  // ------------------------------------------------------------------
  // Clock : 10 ns period
  // ------------------------------------------------------------------
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // ------------------------------------------------------------------
  // Checker state : in-order expected queues (latency agnostic)
  // ------------------------------------------------------------------
  reg  [1:0]        exp_bits_q [0:63];   // expected demod bits
  integer           issue_q    [0:63];   // issue time per symbol
  reg  signed [7:0] exp_i_q    [0:63];   // expected mod constellation
  reg  signed [7:0] exp_qv_q   [0:63];

  integer head, tail;                  // demod expected queue
  integer mhead, mtail;                // mod expected queue
  integer err_mod, err_demod, total;
  reg     result_printed;
  reg     demod_valid_prev;

  integer i;
  reg [1:0] pat;
  reg signed [7:0] ci, cq;

  // ------------------------------------------------------------------
  // Modulator output monitor : X/Z, constellation, extra valid
  // ------------------------------------------------------------------
  always @(posedge clk) begin
    if (rst === 1'b0) begin
      if (mod_valid_out !== 1'b0 && mod_valid_out !== 1'b1) begin
        err_mod = err_mod + 1;
        $display("[ERROR] time=%0t: X/Z on modulator valid_out", $time);
      end else if (mod_valid_out === 1'b1) begin
        if ((^mod_i_out) === 1'bx || (^mod_q_out) === 1'bx) begin
          err_mod = err_mod + 1;
          $display("[ERROR] time=%0t: X/Z on modulator i/q (i=%h q=%h)",
                   $time, mod_i_out, mod_q_out);
        end
        if (mhead < mtail) begin
          if (mod_i_out !== exp_i_q[mhead] || mod_q_out !== exp_qv_q[mhead]) begin
            err_mod = err_mod + 1;
            $display("[ERROR] time=%0t: constellation mismatch exp i=%0d q=%0d got i=%0d q=%0d",
                     $time, exp_i_q[mhead], exp_qv_q[mhead], mod_i_out, mod_q_out);
          end
          mhead = mhead + 1;
        end else begin
          err_mod = err_mod + 1;
          $display("[ERROR] time=%0t: unexpected modulator valid_out (queue empty)", $time);
        end
      end
    end
  end

  // ------------------------------------------------------------------
  // Demodulator output monitor : mismatch, X/Z, dup valid, late valid
  // ------------------------------------------------------------------
  always @(posedge clk) begin
    if (rst === 1'b0) begin
      if (demod_valid_out !== 1'b0 && demod_valid_out !== 1'b1) begin
        err_demod = err_demod + 1;
        $display("[ERROR] time=%0t: X/Z on demodulator valid_out", $time);
      end
      if (demod_valid_out === 1'b1 && demod_valid_prev === 1'b1) begin
        err_demod = err_demod + 1;
        $display("[ERROR] time=%0t: duplicate demodulator valid_out", $time);
      end
      demod_valid_prev <= demod_valid_out;

      if (demod_valid_out === 1'b1) begin
        if ((^demod_bits) === 1'bx) begin
          err_demod = err_demod + 1;
          $display("[ERROR] time=%0t: X/Z on demodulator bits (%b)", $time, demod_bits);
        end
        if (head < tail) begin
          if (demod_bits !== exp_bits_q[head]) begin
            err_demod = err_demod + 1;
            $display("[ERROR] time=%0t: data mismatch exp=%b got=%b",
                     $time, exp_bits_q[head], demod_bits);
          end
          if ((($time - issue_q[head]) / 10) > 6) begin
            err_demod = err_demod + 1;
            $display("[ERROR] time=%0t: late valid (latency=%0d cycles > 6)",
                     $time, ($time - issue_q[head]) / 10);
          end
          head = head + 1;
        end else begin
          err_demod = err_demod + 1;
          $display("[ERROR] time=%0t: unexpected demodulator valid_out (queue empty)", $time);
        end
      end
    end else begin
      demod_valid_prev <= 1'b0;
    end
  end

  // ------------------------------------------------------------------
  // Stimulus
  // ------------------------------------------------------------------
  initial begin : stimulus
    rst              = 1'b1;
    mod_valid_in     = 1'b0;
    mod_bits         = 2'b00;
    head             = 0;
    tail             = 0;
    mhead            = 0;
    mtail            = 0;
    err_mod          = 0;
    err_demod        = 0;
    total            = 0;
    result_printed   = 1'b0;
    demod_valid_prev = 1'b0;

    // (1) reset asserted for at least 3 cycles
    repeat (5) @(negedge clk);
    rst <= 1'b0;

    // (5) rst observed deasserted for >= 1 full cycle before first valid_in
    @(posedge clk);
    @(posedge clk);

    // (2) 40 symbols : gray-coded pattern order, each pattern exactly 10x
    for (i = 0; i < 40; i = i + 1) begin
      pat = i % 4;
      pat = pat ^ (pat >> 1);            // 00,01,11,10 repeating
      case (pat)
        2'b00:   begin ci =  8'sd127;  cq =  8'sd127;  end
        2'b01:   begin ci =  8'sd127;  cq = -8'sd128;  end
        2'b10:   begin ci = -8'sd128;  cq =  8'sd127;  end
        default: begin ci = -8'sd128;  cq = -8'sd128;  end
      endcase

      // (3) valid_in high for EXACTLY one cycle
      @(posedge clk);
      mod_bits     <= pat;
      mod_valid_in <= 1'b1;

      // (8) push expected data, record issue time (no latency assumption)
      exp_bits_q[tail] = pat;
      issue_q[tail]    = $time;
      tail             = tail + 1;
      exp_i_q[mtail]   = ci;
      exp_qv_q[mtail]  = cq;
      mtail            = mtail + 1;

      // (4) at least 2 idle cycles before next symbol
      @(posedge clk);
      mod_valid_in <= 1'b0;
      repeat (2) @(posedge clk);
    end

    // drain pipeline
    repeat (60) @(posedge clk);
    @(negedge clk);

    // (9) missing-valid check
    total = err_mod + err_demod;
    if (mhead != mtail) begin
      $display("[ERROR] missing modulator valid_out for %0d symbol(s)", mtail - mhead);
      total = total + (mtail - mhead);
    end
    if (head != tail) begin
      $display("[ERROR] missing demodulator valid_out for %0d symbol(s)", tail - head);
      total = total + (tail - head);
    end

    // (10) final verdict, printed exactly once
    result_printed = 1'b1;
    if (total == 0) $display("[RESULT] PASS");
    else            $display("[RESULT] FAIL errors=%0d", total);

    #100;
    $finish;                             // (11)
  end

  // ------------------------------------------------------------------
  // (12) 200 us watchdog
  // ------------------------------------------------------------------
  initial begin : watchdog
    #200_000;
    if (!result_printed) begin
      result_printed = 1'b1;
      $display("[RESULT] FAIL watchdog");
    end
    $finish;
  end

  // ------------------------------------------------------------------
  // Waveforms (optional)
  // ------------------------------------------------------------------
  initial begin
    $dumpfile("tb_qpsk_loopback.vcd");
    $dumpvars(0, tb_qpsk_loopback);
  end

endmodule