`timescale 1ns/1ps

module tb_qpsk_loopback;

    parameter NUM_SYMBOLS = 40;
    parameter QDEPTH      = 64;
    parameter MAX_LATENCY = 6;

    reg  clk;
    reg  rst;
    reg  valid_in;
    reg  [1:0] bits;

    wire             mod_valid_out;
    wire signed [7:0] i_out, q_out;

    wire        demod_valid_out;
    wire [1:0]  demod_bits;

    integer cycle_count;
    integer error_count;
    integer i;
    reg     test_done;

    reg [1:0] pattern_seq [0:NUM_SYMBOLS-1];

    reg [1:0] exp_bits [0:QDEPTH-1];
    integer   exp_time [0:QDEPTH-1];
    integer   q_head, q_tail, q_count;

    // ------------------------------------------------------------------
    // DUT instances (loopback: modulator output feeds demodulator input)
    // ------------------------------------------------------------------
    qpsk_modulator u_mod (
        .clk       (clk),
        .rst       (rst),
        .valid_in  (valid_in),
        .bits      (bits),
        .valid_out (mod_valid_out),
        .i_out     (i_out),
        .q_out     (q_out)
    );

    qpsk_demodulator u_demod (
        .clk       (clk),
        .rst       (rst),
        .valid_in  (mod_valid_out),
        .i_in      (i_out),
        .q_in      (q_out),
        .valid_out (demod_valid_out),
        .bits      (demod_bits)
    );

    // ------------------------------------------------------------------
    // Clock: 10ns period
    // ------------------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ------------------------------------------------------------------
    // Cycle counter
    // ------------------------------------------------------------------
    initial cycle_count = 0;
    always @(posedge clk) cycle_count <= cycle_count + 1;

    // ------------------------------------------------------------------
    // Modulator output sanity check (X/Z on the loopback signal path)
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst && mod_valid_out) begin
            if ((^i_out === 1'bx) || (^q_out === 1'bx)) begin
                $display("[ERROR] t=%0t X/Z on modulator output i_out=%b q_out=%b",
                          $time, i_out, q_out);
                error_count = error_count + 1;
            end
        end
    end

    // ------------------------------------------------------------------
    // Expected-symbol queue: push on valid_in, pop/check on demod valid_out
    // Combined in one always block to avoid same-edge push/pop races.
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        // push
        if (!rst && valid_in) begin
            exp_bits[q_tail] = bits;
            exp_time[q_tail] = cycle_count;
            q_tail           = (q_tail + 1) % QDEPTH;
            q_count          = q_count + 1;
        end

        // pop / check
        if (!rst && demod_valid_out) begin
            if (^demod_bits === 1'bx) begin
                $display("[ERROR] t=%0t X/Z on demodulator output bits=%b",
                          $time, demod_bits);
                error_count = error_count + 1;
            end
            else if (q_count == 0) begin
                $display("[ERROR] t=%0t duplicate/unexpected valid_out, bits=%b",
                          $time, demod_bits);
                error_count = error_count + 1;
            end
            else begin
                if (demod_bits !== exp_bits[q_head]) begin
                    $display("[ERROR] t=%0t data mismatch: expected=%b got=%b",
                              $time, exp_bits[q_head], demod_bits);
                    error_count = error_count + 1;
                end
                if ((cycle_count - exp_time[q_head]) > MAX_LATENCY) begin
                    $display("[ERROR] t=%0t late valid: latency=%0d cycles (max=%0d)",
                              $time, (cycle_count - exp_time[q_head]), MAX_LATENCY);
                    error_count = error_count + 1;
                end
                q_head  = (q_head + 1) % QDEPTH;
                q_count = q_count - 1;
            end
        end
    end

    // ------------------------------------------------------------------
    // Stimulus task: valid_in high for EXACTLY 1 cycle, then >=2 idle cycles
    // ------------------------------------------------------------------
    task drive_symbol(input [1:0] pattern);
    begin
        @(negedge clk);
        valid_in <= 1'b1;
        bits     <= pattern;
        @(negedge clk);
        valid_in <= 1'b0;
        bits     <= 2'b00;
        @(negedge clk);
        @(negedge clk);
    end
    endtask

    // ------------------------------------------------------------------
    // Build 40-symbol sequence: 10 of each pattern, then shuffle
    // ------------------------------------------------------------------
    task build_patterns;
        integer idx, r;
        reg [1:0] tmp;
    begin
        idx = 0;
        for (i = 0; i < 10; i = i + 1) begin
            pattern_seq[idx] = 2'b00; idx = idx + 1;
            pattern_seq[idx] = 2'b01; idx = idx + 1;
            pattern_seq[idx] = 2'b10; idx = idx + 1;
            pattern_seq[idx] = 2'b11; idx = idx + 1;
        end
        for (i = NUM_SYMBOLS - 1; i > 0; i = i - 1) begin
            r = $random % (i + 1);
            if (r < 0) r = -r;
            tmp             = pattern_seq[i];
            pattern_seq[i]  = pattern_seq[r];
            pattern_seq[r]  = tmp;
        end
    end
    endtask

    // ------------------------------------------------------------------
    // 200us watchdog
    // ------------------------------------------------------------------
    initial begin
        #200_000;
        if (!test_done) begin
            $display("[RESULT] FAIL watchdog");
            $finish;
        end
    end

    // ------------------------------------------------------------------
    // Main test sequence
    // ------------------------------------------------------------------
    initial begin
        rst         = 1'b1;
        valid_in    = 1'b0;
        bits        = 2'b00;
        error_count = 0;
        q_head      = 0;
        q_tail      = 0;
        q_count     = 0;
        test_done   = 1'b0;

        build_patterns;

        // hold reset for at least 3 cycles
        repeat (4) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        // start driving only after rst observed deasserted for >=1 cycle
        @(posedge clk);
        @(posedge clk);

        for (i = 0; i < NUM_SYMBOLS; i = i + 1) begin
            drive_symbol(pattern_seq[i]);
        end

        // allow pipeline to flush
        repeat (20) @(posedge clk);

        // any symbols still outstanding -> missing valid
        while (q_count > 0) begin
            $display("[ERROR] missing valid: expected bits=%b pushed at cycle=%0d never arrived",
                      exp_bits[q_head], exp_time[q_head]);
            error_count = error_count + 1;
            q_head      = (q_head + 1) % QDEPTH;
            q_count     = q_count - 1;
        end

        test_done = 1'b1;

        if (error_count == 0)
            $display("[RESULT] PASS");
        else
            $display("[RESULT] FAIL errors=%0d", error_count);

        $finish;
    end

endmodule