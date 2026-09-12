`timescale 1ns/1ps

module tb_qpsk_loopback;

  reg clk;
  reg rst;
  reg valid_in;
  reg [1:0] bits_in;

  wire valid_out_mod;
  wire signed [7:0] i_out;
  wire signed [7:0] q_out;

  wire valid_out_chan;
  wire signed [7:0] i_out_chan;
  wire signed [7:0] q_out_chan;

  wire valid_out_demod;
  wire [1:0] bits_out;

  // Instantiate modulator
  qpsk_modulator u_mod (
    .clk(clk),
    .rst(rst),
    .valid_in(valid_in),
    .bits(bits_in),
    .valid_out(valid_out_mod),
    .i_out(i_out),
    .q_out(q_out)
  );

  // Instantiate channel impairment module
  channel u_channel (
    .clk(clk),
    .rst(rst),
    .seed(32'h12345678),
    .valid_in(valid_out_mod),
    .i_in(i_out),
    .q_in(q_out),
    .valid_out(valid_out_chan),
    .i_out(i_out_chan),
    .q_out(q_out_chan)
  );

  // Instantiate demodulator
  qpsk_demodulator u_demod (
    .clk(clk),
    .rst(rst),
    .valid_in(valid_out_chan),
    .i_in(i_out_chan),
    .q_in(q_out_chan),
    .valid_out(valid_out_demod),
    .bits(bits_out)
  );

  // Clock generation: 10ns period
  initial clk = 0;
  always #5 clk = ~clk;

  // Watchdog timer: 200 us = 200,000 ns
  initial begin
    #200000;
    $display("[RESULT] FAIL watchdog");
    $finish;
  end

  // Expected symbol queue structures
  reg [1:0] exp_bits_queue [0:127];
  time      exp_time_queue [0:127];
  integer   queue_head = 0;
  integer   queue_tail = 0;

  integer   error_count = 0;
  integer   symbols_sent = 0;
  integer   symbols_received = 0;

  // Temporary variables for checking
  reg [1:0] expected_b;
  time      sent_t;
  time      latency_ns;

  // X/Z Monitoring and Demodulation Checking
  always @(posedge clk) begin
    if (!rst) begin
      // Check for X/Z on modulator outputs
      if ($isunknown(valid_out_mod) || $isunknown(i_out) || $isunknown(q_out)) begin
        $display("ERROR: X/Z detected on modulator outputs at time %0t", $time);
        error_count = error_count + 1;
      end

      // Check for X/Z on channel outputs
      if ($isunknown(valid_out_chan) || $isunknown(i_out_chan) || $isunknown(q_out_chan)) begin
        $display("ERROR: X/Z detected on channel outputs at time %0t", $time);
        error_count = error_count + 1;
      end

      // Check for X/Z on demodulator outputs
      if ($isunknown(valid_out_demod) || $isunknown(bits_out)) begin
        $display("ERROR: X/Z detected on demodulator outputs at time %0t", $time);
        error_count = error_count + 1;
      end

      // Check Demodulator Valid Out
      if (valid_out_demod === 1'b1) begin
        symbols_received = symbols_received + 1;
        if (queue_head == queue_tail) begin
          $display("ERROR: Duplicate/Unexpected valid_out_demod received at time %0t (no pending symbols)", $time);
          error_count = error_count + 1;
        end else begin
          // Pop expected symbol
          expected_b = exp_bits_queue[queue_head];
          sent_t = exp_time_queue[queue_head];
          queue_head = queue_head + 1;

          // Check latency with baseline 3 cycles (tolerance up to 10 cycles = 100 ns)
          latency_ns = $time - sent_t;
          if (latency_ns > 100) begin
            $display("ERROR: Late valid received! Latency = %0d ns (> 10 cycles) at time %0t", latency_ns, $time);
            error_count = error_count + 1;
          end

          // Check data match
          if (bits_out !== expected_b) begin
            $display("ERROR: Data mismatch! Expected: %b, Got: %b at time %0t", expected_b, bits_out, $time);
            error_count = error_count + 1;
          end
        end
      end
    end
  end

  // Stimulus generation
  reg [1:0] symbol_list [0:39];
  integer idx, i;

  initial begin
    // Initialize signals
    valid_in = 0;
    bits_in = 2'b00;

    // Reset assertion: active-high for at least 3 cycles
    rst = 1;
    repeat(4) @(posedge clk);
    rst = 0;

    // Wait at least 1 cycle after reset deassertion as required
    @(posedge clk);
    @(posedge clk);

    // Prepare 40 symbols: 10 of each (00, 01, 10, 11)
    for (i = 0; i < 10; i = i + 1) begin
      symbol_list[i*4 + 0] = 2'b00;
      symbol_list[i*4 + 1] = 2'b01;
      symbol_list[i*4 + 2] = 2'b10;
      symbol_list[i*4 + 3] = 2'b11;
    end

    // Drive 40 symbols
    for (idx = 0; idx < 40; idx = idx + 1) begin
      bits_in = symbol_list[idx];
      valid_in = 1'b1;
      
      // Push to expected queue
      exp_bits_queue[queue_tail] = symbol_list[idx];
      exp_time_queue[queue_tail] = $time;
      queue_tail = queue_tail + 1;
      symbols_sent = symbols_sent + 1;

      @(posedge clk);
      valid_in = 1'b0;

      // Wait at least 2 idle cycles between symbols
      repeat(2) @(posedge clk);
    end

    // Wait for pipeline to drain
    repeat(50) @(posedge clk);

    // Check for missing valids
    if (queue_head != queue_tail) begin
      $display("ERROR: Missing valid(s)! %0d symbols remaining in queue.", (queue_tail - queue_head));
      error_count = error_count + (queue_tail - queue_head);
    end

    // Final result reporting
    if (error_count == 0) begin
      $display("[RESULT] PASS");
    end else begin
      $display("[RESULT] FAIL errors=%0d", error_count);
    end

    $finish;
  end

endmodule