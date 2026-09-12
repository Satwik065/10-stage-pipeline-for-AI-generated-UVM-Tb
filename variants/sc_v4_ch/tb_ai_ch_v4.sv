`timescale 1ns / 1ps
//======================================================================
// Self-checking testbench :
//   qpsk_modulator -> channel (rotation + noise) -> qpsk_demodulator
//======================================================================
module tb_qpsk_loopback;

  localparam [31:0] CHAN_SEED = 32'hDEAD_BEEF;
  localparam integer LATE_LIMIT_CYCLES = 6;   // baseline latency is 3 cycles

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

  wire              chan_valid_out;
  wire signed [7:0] chan_i_out;
  wire signed [7:0] chan_q_out;

  wire              demod_valid_in;
  wire signed [7:0] demod_i_in;
  wire signed [7:0] demod_q_in;
  wire              demod_valid_out;
  wire [1:0]        demod_bits;

  // ------------------------------------------------------------------
  // DUTs : modulator -> channel -> demodulator (loopback)
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

  channel u_chan (
    .clk       (clk),
    .rst       (rst),
    .seed      (CHAN_SEED),
    .valid_in  (mod_valid_out),
    .i_in      (mod_i_out),
    .q_in      (mod_q_out),
    .valid_out (chan_valid_out),
    .i_out     (chan_i_out),
    .q_out     (chan_q_out)
  );

  assign demod_valid_in = chan_valid_out;
  assign demod_i_in     = chan_i_out;
  assign demod_q_in     = chan_q_out;

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
  reg  [1:0] exp_bits_q [0:63];   // expected demod bits
  reg  [1:0] exp_pat_q  [0:63];   // expected constellation pattern
  integer    issue_q    [0:63];   // issue time per symbol

  integer head, tail;             // demod expected queue
  integer mhead, mtail;           // channel/mod expected queue
  integer err_chan, err_demod, total;
  reg     result_printed;
  reg     demod_valid_prev;

  integer i;
  reg [1:0] pat;
  reg signed [7:0] ci, cq;
  integer di, dq, d0, d1, d2, d3, dexp;

  // ------------------------------------------------------------------
  // Modulator output monitor : X/Z only (values impaired downstream)
  // ------------------------------------------------------------------
  always @(posedge clk) begin
    if (rst === 1'b0) begin
      if (mod_valid_out === 1'b1) begin
        if ((^mod_i_out) === 1'bx || (^mod_q_out) === 1'bx) begin
          err_chan = err_chan + 1;
          $display("[ERROR] time=%0t: X/Z on modulator i/q (i=%h q=%h)",
                   $time, mod_i_out, mod_q_out);
        end
      end
    end
  end

  // ------------------------------------------------------------------
  // Channel output monitor : X/Z, unexpected valid, constellation sanity
  // (rotation ~3.6 deg + +/-3 LSB noise tolerated via nearest-neighbor
  //  check : received point must be closest to its own ideal point)
  // ------------------------------------------------------------------
  always @(posedge clk) begin
    if (rst === 1'b0) begin
      if (chan_valid_out !== 1'b0 && chan_valid_out !== 1'b1) begin
        err_chan = err_chan + 1;
        $display("[ERROR] time=%0t: X/Z on channel valid_out", $time);
      end else if (chan_valid_out === 1'b1) begin
        if ((^chan_i_out) === 1'bx || (^chan_q_out) === 1'bx) begin
          err_chan = err_chan + 1;
          $display("[ERROR] time=%0t: X/Z on channel i/q (i=%h q=%h)",
                   $time, chan_i_out, chan_q_out);
        end else if (mhead < mtail) begin
          ci  = chan_i_out;
          cq  = chan_q_out;
          d0  = (ci-127)*(ci-127) + (cq-127)*(cq-127);  // 2'b00
          d1  = (ci-127)*(ci-127) + (cq+128)*(cq+128);  // 2'b01
          d2  = (ci+128)*(ci+128) + (cq-127)*(cq-127);  // 2'b10
          d3  = (ci+128)*(ci+128) + (cq+128)*(cq+128);  // 2'b11
          case (exp_pat_q[mhead])
            2'b00:   dexp = d0;
            2'b01:   dexp = d1;
            2'b10:   dexp = d2;
            default: dexp = d3;
          endcase
          if (dexp > d0 || dexp > d1 || dexp > d2 || dexp > d3) begin
            err_chan = err_chan + 1;
            $display("[ERROR] time=%0t: channel output closer to wrong point (i=%0d q=%0d exp=%b)",
                     $time, ci, cq, exp_pat_q[mhead]);
          end
          mhead = mhead + 1;
        end else begin
          err_chan = err_chan + 1;
          $display("[ERROR] time=%0t: unexpected channel valid_out (queue empty)", $time);
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
      demod_valid_prev <= (demod_valid_out === 1'b1);

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
          if ((($time - issue_q[head]) / 10) > LATE_LIMIT_CYCLES) begin
            err_demod = err_demod + 1;
            $display("[ERROR] time=%0t: late valid (latency=%0d cycles > %0d)",
                     $time, ($time - issue_q[head]) / 10, LATE_LIMIT_CYCLES);
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
    err_chan         = 0;
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
      exp_pat_q[tail]  = pat;
      issue_q[tail]    = $time;
      tail             = tail + 1;

      // (4) at least 2 idle cycles before next symbol
      @(posedge clk);
      mod_valid_in <= 1'b0;
      repeat (2) @(posedge clk);
    end

    // drain pipeline (baseline latency 3 cycles + margin)
    repeat (60) @(posedge clk);
    @(negedge clk);

    // (9) missing-valid check
    total = err_chan + err_demod;
    if (mhead != mtail) begin
      $display("[ERROR] missing channel valid_out for %0d symbol(s)", mtail - mhead);
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