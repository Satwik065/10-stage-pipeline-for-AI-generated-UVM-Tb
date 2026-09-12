`timescale 1ns/1ps
//----------------------------------------------------------------------
// tb_qpsk_bkg.sv — Stage 3 calibration Best-Known-Good instrument, v2.
// v1 -> v2 (channel insert):
//   * channel.sv instantiated between u_mod and u_demod. Baseline
//     loopback latency is now 3 cycles (mod 1 + channel 1 + demod 1);
//     the expected-symbol queue + L=6 liveness checker is
//     latency-agnostic, so only this header changes semantically.
//   * MISMATCH no longer fails immediately: mismatch_count increments;
//     end-of-test gate mismatch_count > MISMATCH_BUDGET(2) => FAIL.
//   * X/Z watch extended to channel outputs (post-reset window only).
//   * channel seed: default 32'hDEADBEEF; +CHSEED=<n> optional override.
// Constitution §3 envelope unchanged: 40 symbols (10x each of 00/01/10/11),
// 1-cycle valid pulses, >=2 idle cycles, reset-aware start, negedge-only
// stimulus. §5 verdict channel: exactly one final "[RESULT] ..." line.
//----------------------------------------------------------------------
module tb_qpsk_bkg;

    localparam integer LIVENESS_L       = 6;      // §2 (3 + 1 weather = 4 <= 6)
    localparam integer BASELINE_LATENCY = 3;      // mod + channel + demod (doc)
    localparam integer MISMATCH_BUDGET  = 2;      // v2 end-of-test tolerance
    localparam integer N_ROUNDS         = 10;     // 10 x 4 = 40 symbols
    localparam integer IDLE_CYCLES      = 2;      // §3 minimum
    localparam integer QDEPTH           = 64;
    localparam integer TIMEOUT_NS       = 200000; // §5(e) watchdog

    reg         clk;
    reg         rst;
    reg         valid_in;
    reg  [1:0]  bits_in;
    reg  [31:0] ch_seed;

    wire              mod_valid;
    wire signed [7:0] mod_i;
    wire signed [7:0] mod_q;
    wire              ch_valid;
    wire signed [7:0] ch_i;
    wire signed [7:0] ch_q;
    wire              demod_valid;
    wire  [1:0]       demod_bits;

    qpsk_modulator u_mod (
        .clk(clk), .rst(rst), .valid_in(valid_in), .bits(bits_in),
        .valid_out(mod_valid), .i_out(mod_i), .q_out(mod_q)
    );

    channel u_ch (
        .clk(clk), .rst(rst), .seed(ch_seed),
        .valid_in(mod_valid), .i_in(mod_i), .q_in(mod_q),
        .valid_out(ch_valid), .i_out(ch_i), .q_out(ch_q)
    );

    qpsk_demodulator u_demod (
        .clk(clk), .rst(rst), .valid_in(ch_valid),
        .i_in(ch_i), .q_in(ch_q),
        .valid_out(demod_valid), .bits(demod_bits)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    //---------------- expected queue (in-order, latency-agnostic) -------
    reg  [1:0] q_sym [0:QDEPTH-1];
    integer    q_idx [0:QDEPTH-1];
    integer    q_head, q_tail, q_count;
    integer    pushed, errors, mismatch_count;
    reg        rst_done, finished;

    task push_expected(input [1:0] s);
        begin
            if (q_count == QDEPTH) begin
                errors = errors + 1;
                $display("[ERROR] t=%0t CLASS=OVERFLOW idx=%0d", $time, pushed);
            end else begin
                q_sym[q_tail] = s;
                q_idx[q_tail] = pushed;
                q_tail  = (q_tail + 1) % QDEPTH;
                q_count = q_count + 1;
            end
            pushed = pushed + 1;
        end
    endtask

    //---------------- checker (single posedge writer) -------------------
    reg     prev_dv;
    reg     xz_dv_prev, xz_db_prev;
    reg     xz_mv_prev, xz_mi_prev, xz_mq_prev;
    reg     xz_cv_prev, xz_ci_prev, xz_cq_prev;
    integer stall;

    always @(posedge clk) begin
        if (!rst_done) begin
            prev_dv    <= 1'b0;
            stall      <= 0;
            xz_dv_prev <= 1'b0; xz_db_prev <= 1'b0;
            xz_mv_prev <= 1'b0; xz_mi_prev <= 1'b0; xz_mq_prev <= 1'b0;
            xz_cv_prev <= 1'b0; xz_ci_prev <= 1'b0; xz_cq_prev <= 1'b0;
        end else begin
            // ---- X/Z, post-reset window only, edge-latched --------------
            if (demod_valid === 1'bx) begin
                if (!xz_dv_prev) begin
                    errors = errors + 1;
                    $display("[ERROR] t=%0t CLASS=XZ demod_valid", $time);
                end
                xz_dv_prev <= 1'b1;
            end else xz_dv_prev <= 1'b0;

            if ((^demod_bits) === 1'bx) begin
                if (!xz_db_prev) begin
                    errors = errors + 1;
                    $display("[ERROR] t=%0t CLASS=XZ demod_bits", $time);
                end
                xz_db_prev <= 1'b1;
            end else xz_db_prev <= 1'b0;

            if (mod_valid === 1'bx) begin
                if (!xz_mv_prev) begin
                    errors = errors + 1;
                    $display("[ERROR] t=%0t CLASS=XZ mod_valid", $time);
                end
                xz_mv_prev <= 1'b1;
            end else xz_mv_prev <= 1'b0;

            if ((^mod_i) === 1'bx) begin
                if (!xz_mi_prev) begin
                    errors = errors + 1;
                    $display("[ERROR] t=%0t CLASS=XZ mod_i", $time);
                end
                xz_mi_prev <= 1'b1;
            end else xz_mi_prev <= 1'b0;

            if ((^mod_q) === 1'bx) begin
                if (!xz_mq_prev) begin
                    errors = errors + 1;
                    $display("[ERROR] t=%0t CLASS=XZ mod_q", $time);
                end
                xz_mq_prev <= 1'b1;
            end else xz_mq_prev <= 1'b0;

            if (ch_valid === 1'bx) begin
                if (!xz_cv_prev) begin
                    errors = errors + 1;
                    $display("[ERROR] t=%0t CLASS=XZ ch_valid", $time);
                end
                xz_cv_prev <= 1'b1;
            end else xz_cv_prev <= 1'b0;

            if ((^ch_i) === 1'bx) begin
                if (!xz_ci_prev) begin
                    errors = errors + 1;
                    $display("[ERROR] t=%0t CLASS=XZ ch_i", $time);
                end
                xz_ci_prev <= 1'b1;
            end else xz_ci_prev <= 1'b0;

            if ((^ch_q) === 1'bx) begin
                if (!xz_cq_prev) begin
                    errors = errors + 1;
                    $display("[ERROR] t=%0t CLASS=XZ ch_q", $time);
                end
                xz_cq_prev <= 1'b1;
            end else xz_cq_prev <= 1'b0;

            // ---- valid / data checking ----------------------------------
            if (demod_valid === 1'b1) begin
                if (prev_dv) begin
                    errors = errors + 1;
                    $display("[ERROR] t=%0t CLASS=DUPLICATE idx=-1", $time);
                end else if (q_count == 0) begin
                    errors = errors + 1;
                    $display("[ERROR] t=%0t CLASS=UNEXPECTED_VALID idx=-1", $time);
                end else begin
                    if (demod_bits !== q_sym[q_head]) begin
                        // v2: count, do not fail immediately
                        mismatch_count = mismatch_count + 1;
                        $display("[INFO] t=%0t MISMATCH idx=%0d exp=%b got=%b count=%0d",
                                 $time, q_idx[q_head], q_sym[q_head],
                                 demod_bits, mismatch_count);
                    end
                    q_head  = (q_head + 1) % QDEPTH;
                    q_count = q_count - 1;
                    stall   = 0;
                end
            end else if (q_count > 0) begin
                stall = stall + 1;
                if (stall == LIVENESS_L) begin
                    errors = errors + 1;
                    $display("[ERROR] t=%0t CLASS=LIVENESS pending=%0d no_valid_%0d_cyc",
                             $time, q_count, LIVENESS_L);
                end
            end else begin
                stall = 0;
            end

            prev_dv <= (demod_valid === 1'b1);
        end
    end

    //---------------- stimulus (negedge-driven only) --------------------
    task run_symbol(input [1:0] s);
        begin
            @(negedge clk);
            push_expected(s);
            valid_in = 1'b1;
            bits_in  = s;
            @(negedge clk);
            valid_in = 1'b0;                     // exactly 1-cycle pulse
            repeat (IDLE_CYCLES) @(negedge clk); // >= 2 idle cycles
        end
    endtask

    integer   r, k;
    reg [1:0] pattern [0:3];

    initial begin
        rst      = 1'b1;
        valid_in = 1'b0;
        bits_in  = 2'b00;
        if (!$value$plusargs("CHSEED=%d", ch_seed)) ch_seed = 32'hDEADBEEF;
        errors         = 0;
        mismatch_count = 0;
        pushed         = 0;
        q_head  = 0; q_tail = 0; q_count = 0;
        rst_done = 1'b0; finished = 1'b0;
        prev_dv  = 1'b0; stall = 0;
        pattern[0] = 2'b00; pattern[1] = 2'b01;
        pattern[2] = 2'b10; pattern[3] = 2'b11;

        repeat (3) @(negedge clk);   // rst asserted >= 3 cycles
        rst = 1'b0;
        @(negedge clk);              // rst observed low for one full cycle
        rst_done = 1'b1;             // §2 post-reset window opens
        @(negedge clk);              // settle cycle before first drive

        for (r = 0; r < N_ROUNDS; r = r + 1)
            for (k = 0; k < 4; k = k + 1)
                run_symbol(pattern[k]);

        repeat (LIVENESS_L + 4) @(negedge clk);   // drain
        if (q_count != 0) begin
            errors = errors + 1;
            $display("[ERROR] t=%0t CLASS=MISSING count=%0d", $time, q_count);
        end
        if (mismatch_count > MISMATCH_BUDGET) begin
            errors = errors + 1;
            $display("[ERROR] t=%0t CLASS=MISMATCH_BUDGET count=%0d > %0d",
                     $time, mismatch_count, MISMATCH_BUDGET);
        end

        finished = 1'b1;
        if (errors == 0) $display("[RESULT] PASS");
        else             $display("[RESULT] FAIL errors=%0d", errors);
        $finish;
    end

    //---------------- watchdog (§5e) ------------------------------------
    initial begin
        #(TIMEOUT_NS);
        if (!finished) begin
            $display("[RESULT] FAIL watchdog");
            $finish;
        end
    end

endmodule