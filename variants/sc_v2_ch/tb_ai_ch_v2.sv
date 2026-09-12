`timescale 1ns/1ps

module tb_qpsk_mod_channel_demod;

    reg clk;
    reg rst;

    reg        valid_in;
    reg [1:0]  bits;

    wire              mod_valid;
    wire signed [7:0] mod_i;
    wire signed [7:0] mod_q;

    reg  [31:0]       channel_seed;
    wire              ch_valid;
    wire signed [7:0] ch_i;
    wire signed [7:0] ch_q;

    wire              demod_valid;
    wire [1:0]        demod_bits;

    integer errors;
    integer symbols_sent;
    integer symbols_checked;

    reg [1:0] expected_q [0:63];
    integer   age_q      [0:63];

    integer q_head;
    integer q_tail;
    integer q_count;

    reg valid_in_d;
    reg done;

    qpsk_modulator u_modulator (
        .clk       (clk),
        .rst       (rst),
        .valid_in  (valid_in),
        .bits      (bits),
        .valid_out (mod_valid),
        .i_out     (mod_i),
        .q_out     (mod_q)
    );

    channel u_channel (
        .clk       (clk),
        .rst       (rst),
        .seed      (channel_seed),
        .valid_in  (mod_valid),
        .i_in      (mod_i),
        .q_in      (mod_q),
        .valid_out (ch_valid),
        .i_out     (ch_i),
        .q_out     (ch_q)
    );

    qpsk_demodulator u_demodulator (
        .clk       (clk),
        .rst       (rst),
        .valid_in  (ch_valid),
        .i_in       (ch_i),
        .q_in       (ch_q),
        .valid_out (demod_valid),
        .bits      (demod_bits)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    function automatic is_xz_2;
        input [1:0] v;
        begin
            is_xz_2 = (^v === 1'bx);
        end
    endfunction

    function automatic is_xz_8;
        input [7:0] v;
        begin
            is_xz_8 = (^v === 1'bx);
        end
    endfunction

    task enqueue_expected;
        input [1:0] expected_bits;
        begin
            if (q_count >= 64) begin
                errors = errors + 1;
            end
            else begin
                expected_q[q_tail] = expected_bits;
                age_q[q_tail]      = 0;

                q_tail = q_tail + 1;
                if (q_tail == 64)
                    q_tail = 0;

                q_count = q_count + 1;
            end
        end
    endtask

    task dequeue_expected;
        input [1:0] actual_bits;
        begin
            if (q_count == 0) begin
                // No outstanding transaction: duplicate/spurious valid.
                errors = errors + 1;
            end
            else begin
                if (actual_bits !== expected_q[q_head])
                    errors = errors + 1;

                symbols_checked = symbols_checked + 1;

                q_head = q_head + 1;
                if (q_head == 64)
                    q_head = 0;

                q_count = q_count - 1;
            end
        end
    endtask

    /*
     * Scoreboard.
     *
     * The channel has a nominal 3-cycle latency.  The scoreboard does
     * not assume that latency; it accepts an in-order result at any
     * time through cycle 6.  A transaction still outstanding after
     * cycle 6 is reported as a missing/late transaction.
     */
    always @(posedge clk) begin : scoreboard
        integer k;
        integer idx;

        if (rst === 1'b1) begin
            valid_in_d <= 1'b0;
        end
        else begin

            /*
             * Check valid signals for X/Z.
             */
            if ((mod_valid !== 1'b0) && (mod_valid !== 1'b1))
                errors = errors + 1;

            if ((ch_valid !== 1'b0) && (ch_valid !== 1'b1))
                errors = errors + 1;

            if ((demod_valid !== 1'b0) && (demod_valid !== 1'b1))
                errors = errors + 1;

            /*
             * Check input transaction.
             */
            if (valid_in === 1'b1) begin
                if (is_xz_2(bits))
                    errors = errors + 1;

                enqueue_expected(bits);
            end

            /*
             * valid_in must be exactly one cycle wide.
             */
            if ((valid_in === 1'b1) && (valid_in_d === 1'b1))
                errors = errors + 1;

            valid_in_d <= valid_in;

            /*
             * Check modulator outputs whenever they are valid.
             */
            if (mod_valid === 1'b1) begin
                if (is_xz_8(mod_i))
                    errors = errors + 1;

                if (is_xz_8(mod_q))
                    errors = errors + 1;

                if ((mod_i !== 8'sd127) &&
                    (mod_i !== -8'sd128))
                    errors = errors + 1;

                if ((mod_q !== 8'sd127) &&
                    (mod_q !== -8'sd128))
                    errors = errors + 1;
            end

            /*
             * Check channel outputs whenever they are valid.
             * The channel is allowed to rotate/noise the constellation,
             * so only X/Z integrity is checked here.
             */
            if (ch_valid === 1'b1) begin
                if (is_xz_8(ch_i))
                    errors = errors + 1;

                if (is_xz_8(ch_q))
                    errors = errors + 1;
            end

            /*
             * Demodulator result.
             *
             * No fixed latency is assumed.  The result is matched to
             * the oldest outstanding expected symbol.
             */
            if (demod_valid === 1'b1) begin
                if (is_xz_2(demod_bits))
                    errors = errors + 1;

                dequeue_expected(demod_bits);
            end

            /*
             * Age outstanding transactions.
             *
             * Age 0 = cycle in which input was accepted.
             * Results through age 6 are allowed.
             * At age > 6 the transaction is considered missing/late.
             *
             * Expired transactions are removed so that the testbench
             * can still complete and report a normal FAIL result rather
             * than waiting for the 200 us watchdog.
             */
            if (q_count > 0) begin
                k = 0;

                while (k < q_count) begin
                    idx = q_head + k;
                    if (idx >= 64)
                        idx = idx - 64;

                    age_q[idx] = age_q[idx] + 1;

                    if (age_q[idx] > 6) begin
                        errors = errors + 1;

                        /*
                         * Only the oldest transaction can be removed
                         * without disturbing in-order matching.
                         */
                        if (k == 0) begin
                            q_head = q_head + 1;
                            if (q_head == 64)
                                q_head = 0;

                            q_count = q_count - 1;
                            k = k - 1;
                        end
                    end

                    k = k + 1;
                end
            end
        end
    end

    /*
     * Stimulus.
     *
     * 40 symbols total:
     *   00 repeated 10 times
     *   01 repeated 10 times
     *   10 repeated 10 times
     *   11 repeated 10 times
     *
     * valid_in is asserted for exactly one cycle, followed by two
     * complete idle cycles.
     */
    initial begin
        rst             = 1'b1;
        valid_in        = 1'b0;
        bits            = 2'b00;
        channel_seed    = 32'h1357_9BDF;

        errors          = 0;
        symbols_sent    = 0;
        symbols_checked = 0;

        q_head          = 0;
        q_tail          = 0;
        q_count         = 0;

        valid_in_d      = 1'b0;
        done            = 1'b0;

        /*
         * Active-high reset for three complete cycles.
         */
        repeat (3) @(posedge clk);

        @(negedge clk);
        rst = 1'b0;

        /*
         * Reset must be observed deasserted for one complete cycle
         * before the first valid_in assertion.
         */
        @(posedge clk);
        @(negedge clk);

        /*
         * 40 symbols, four constellation points, ten each.
         */
        while (symbols_sent < 40) begin

            case (symbols_sent / 10)
                0: bits = 2'b00;
                1: bits = 2'b01;
                2: bits = 2'b10;
                3: bits = 2'b11;
                default: bits = 2'b00;
            endcase

            /*
             * Exactly one cycle of valid_in.
             */
            valid_in = 1'b1;
            @(negedge clk);
            valid_in = 1'b0;

            symbols_sent = symbols_sent + 1;

            /*
             * At least two idle cycles between symbols.
             */
            repeat (2) @(negedge clk);
        end

        /*
         * Wait for all outstanding transactions to either produce a
         * result or be classified as missing/late.
         */
        while (q_count != 0)
            @(posedge clk);

        /*
         * Allow one additional cycle for scoreboard bookkeeping.
         */
        @(posedge clk);

        done = 1'b1;

        if ((errors == 0) && (symbols_checked == 40))
            $display("[RESULT] PASS");
        else
            $display("[RESULT] FAIL errors=%0d", errors);

        $finish;
    end

    /*
     * 200 us watchdog.
     */
    initial begin
        #200000;

        if (!done) begin
            $display("[RESULT] FAIL watchdog");
            $finish;
        end
    end

endmodule