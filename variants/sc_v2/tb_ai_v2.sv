`timescale 1ns/1ps

module tb_qpsk_loopback;

    reg         clk;
    reg         rst;
    reg         valid_in;
    reg  [1:0]  bits;
    wire        valid_mod;
    wire signed [7:0] i_out;
    wire signed [7:0] q_out;
    wire        valid_demod;
    wire [1:0]  demod_bits;

    integer errors;
    integer symbols_sent;
    integer symbols_checked;
    integer watchdog_expired;

    reg [1:0] expected_queue [0:63];
    integer   age_queue      [0:63];
    reg       expired_queue  [0:63];

    integer q_head;
    integer q_tail;
    integer q_count;

    qpsk_modulator u_mod (
        .clk       (clk),
        .rst       (rst),
        .valid_in  (valid_in),
        .bits      (bits),
        .valid_out (valid_mod),
        .i_out     (i_out),
        .q_out     (q_out)
    );

    qpsk_demodulator u_demod (
        .clk       (clk),
        .rst       (rst),
        .valid_in  (valid_mod),
        .i_in      (i_out),
        .q_in      (q_out),
        .valid_out (valid_demod),
        .bits      (demod_bits)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    function automatic has_xz_2;
        input [1:0] v;
        begin
            has_xz_2 = ((v[0] !== 1'b0) && (v[0] !== 1'b1)) ||
                       ((v[1] !== 1'b0) && (v[1] !== 1'b1));
        end
    endfunction

    function automatic has_xz_8;
        input [7:0] v;
        integer k;
        begin
            has_xz_8 = 1'b0;
            for (k = 0; k < 8; k = k + 1)
                if ((v[k] !== 1'b0) && (v[k] !== 1'b1))
                    has_xz_8 = 1'b1;
        end
    endfunction

    task enqueue_expected;
        input [1:0] v;
        begin
            if (q_count >= 64) begin
                errors = errors + 1;
            end
            else begin
                expected_queue[q_tail] = v;
                age_queue[q_tail]      = 0;
                expired_queue[q_tail]  = 1'b0;

                q_tail = q_tail + 1;
                if (q_tail == 64)
                    q_tail = 0;

                q_count = q_count + 1;
            end
        end
    endtask

    task consume_expected;
        input [1:0] actual;
        begin
            if (q_count == 0) begin
                errors = errors + 1;
            end
            else begin
                if (expired_queue[q_head]) begin
                    errors = errors + 1;
                end

                if (actual !== expected_queue[q_head]) begin
                    errors = errors + 1;
                end

                symbols_checked = symbols_checked + 1;

                q_head = q_head + 1;
                if (q_head == 64)
                    q_head = 0;

                q_count = q_count - 1;
            end
        end
    endtask

    initial begin
        rst            = 1'b1;
        valid_in       = 1'b0;
        bits           = 2'b00;

        errors         = 0;
        symbols_sent   = 0;
        symbols_checked = 0;
        watchdog_expired = 0;

        q_head = 0;
        q_tail = 0;
        q_count = 0;

        repeat (3) @(posedge clk);

        @(negedge clk);
        rst = 1'b0;

        @(posedge clk);

        /*
         * Start stimulus only after reset has been observed deasserted
         * for at least one complete clock cycle.
         */
        @(negedge clk);

        while (symbols_sent < 40) begin
            case (symbols_sent % 4)
                0: bits = 2'b00;
                1: bits = 2'b01;
                2: bits = 2'b10;
                3: bits = 2'b11;
            endcase

            valid_in = 1'b1;
            @(negedge clk);
            valid_in = 1'b0;

            symbols_sent = symbols_sent + 1;

            /*
             * At least two complete idle cycles between symbols.
             */
            repeat (2) @(negedge clk);
        end

        /*
         * Allow the final expected symbol enough time to emerge.
         * The monitor continues independently.
         */
        repeat (20) @(posedge clk);

        if (q_count != 0) begin
            errors = errors + q_count;
            q_count = 0;
        end

        if (errors == 0 && symbols_checked == 40)
            $display("[RESULT] PASS");
        else
            $display("[RESULT] FAIL errors=%0d", errors);

        $finish;
    end

    /*
     * Expected-symbol queue insertion and DUT output checking.
     */
    always @(posedge clk) begin : monitor
        integer k;
        reg [1:0] actual_bits;

        if (rst === 1'b1) begin
            if (valid_in === 1'b1) begin
                errors = errors + 1;
            end
        end
        else begin
            /*
             * Check all output/control signals for X/Z whenever active.
             */
            if ((valid_mod !== 1'b0) && (valid_mod !== 1'b1))
                errors = errors + 1;

            if ((valid_demod !== 1'b0) && (valid_demod !== 1'b1))
                errors = errors + 1;

            if (valid_mod === 1'b1) begin
                if (has_xz_8(i_out))
                    errors = errors + 1;

                if (has_xz_8(q_out))
                    errors = errors + 1;

                /*
                 * Loopback constellation sanity check.
                 */
                if ((i_out !== 8'sd127) &&
                    (i_out !== -8'sd128))
                    errors = errors + 1;

                if ((q_out !== 8'sd127) &&
                    (q_out !== -8'sd128))
                    errors = errors + 1;
            end

            if (valid_demod === 1'b1) begin
                if (has_xz_2(demod_bits))
                    errors = errors + 1;

                actual_bits = demod_bits;

                if (q_count == 0) begin
                    /*
                     * No expected transaction exists:
                     * duplicate/spurious valid.
                     */
                    errors = errors + 1;
                end
                else begin
                    /*
                     * A valid result arriving after the six-cycle
                     * allowed latency is explicitly a late valid.
                     */
                    if (expired_queue[q_head])
                        errors = errors + 1;

                    if (actual_bits !== expected_queue[q_head])
                        errors = errors + 1;

                    symbols_checked = symbols_checked + 1;

                    q_head = q_head + 1;
                    if (q_head == 64)
                        q_head = 0;

                    q_count = q_count - 1;
                end
            end

            /*
             * Capture every accepted input symbol.
             * valid_in is required to be exactly one cycle wide;
             * stimulus generation guarantees this, while this monitor
             * checks for an illegal consecutive assertion.
             */
            if (valid_in === 1'b1) begin
                if (has_xz_2(bits))
                    errors = errors + 1;

                if (symbols_sent < 40)
                    enqueue_expected(bits);
            end

            /*
             * Age outstanding transactions.
             *
             * age > 6 means the transaction has gone beyond the
             * permitted six-cycle latency without a valid result.
             * Mark it expired but retain it so a subsequent result
             * is classified as "late valid" rather than merely
             * "duplicate valid".
             */
            if (q_count != 0) begin
                for (k = 0; k < 64; k = k + 1) begin
                    if (k < q_count) begin
                        if (!expired_queue[(q_head + k) % 64]) begin
                            if (age_queue[(q_head + k) % 64] > 6) begin
                                expired_queue[(q_head + k) % 64] = 1'b1;
                                errors = errors + 1;
                            end
                        end
                        else begin
                            age_queue[(q_head + k) % 64] =
                                age_queue[(q_head + k) % 64] + 1;
                        end
                    end
                end
            end
        end
    end

    /*
     * 200 us simulation watchdog.
     */
    initial begin
        #200000;
        watchdog_expired = 1;
        $display("[RESULT] FAIL watchdog");
        $finish;
    end

    /*
     * Detect a multi-cycle valid_in pulse.
     */
    reg valid_in_d;

    always @(posedge clk) begin
        if (rst === 1'b1)
            valid_in_d <= 1'b0;
        else begin
            if (valid_in === 1'b1 && valid_in_d === 1'b1)
                errors = errors + 1;

            valid_in_d <= valid_in;
        end
    end

endmodule