`timescale 1ns/1ps
//----------------------------------------------------------------------
// tb_qpsk_bkg.sv — Stage 3 calibration Best-Known-Good instrument.
// Constitution v1.5 compliance:
//   §3: 40 symbols (10x each of 00/01/10/11), valid_in high exactly
//       1 cycle/symbol, >=2 idle cycles between symbols, reset-aware
//       start (drives only after rst observed low for >=1 full cycle).
//   §2/§5: latency-agnostic in-order queue compare (no fixed-latency
//       assumption), liveness bound L=6, duplicate/unexpected valid_out
//       detection, X/Z checked only in the post-reset window.
//   §5: verdict channel = exactly one final line:
//       "[RESULT] PASS" | "[RESULT] FAIL errors=N" | "[RESULT] FAIL watchdog"
//----------------------------------------------------------------------
module tb_qpsk_bkg;

    localparam integer LIVENESS_L  = 6;      // Constitution §2
    localparam integer N_ROUNDS    = 10;     // 10 rounds x 4 symbols = 40
    localparam integer IDLE_CYCLES = 2;      // §3 minimum idle
    localparam integer QDEPTH      = 64;
    localparam integer TIMEOUT_NS  = 200000; // §5(e) watchdog, 200 us

    reg        clk;
    reg        rst;
    reg        valid_in;
    reg  [1:0] bits_in;

    wire              mod_valid;
    wire signed [7:0] mod_i;
    wire signed [7:0] mod_q;
    wire              demod_valid;
    wire  [1:0]       demod_bits;

    qpsk_modulator u_mod (
        .clk(clk), .rst(rst), .valid_in(valid_in), .bits(bits_in),
        .valid_out(mod_valid), .i_out(mod_i), .q_out(mod_q)
    );

    qpsk_demodulator u_demod (
        .clk(clk), .rst(rst), .valid_in(mod_valid),
        .i_in(mod_i), .q_in(mod_q),
        .valid_out(demod_valid), .bits(demod_bits)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    //----------------------------------------------------------------
    // Unknown-detection helper: returns 1 if v is not a clean 0 or 1
    // (catches BOTH x and z; the old (v === 1'bx) check missed pure-z).
    //----------------------------------------------------------------
    function automatic bit is_unknown(input logic v);
        is_unknown = (v !== 1'b0) && (v !== 1'b1);
    endfunction

    //---------------- expected queue (in-order, latency-agnostic) -------
    reg  [1:0] q_sym [0:QDEPTH-1];
    integer    q_idx [0:QDEPTH-1];
    integer    q_head, q_tail, q_count;
    integer    pushed, errors;
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
    reg     xz_dv_prev, xz_db_prev, xz_mv_prev, xz_mi_prev, xz_mq_prev;
    integer stall;

    always @(posedge clk) begin
        if (!rst_done) begin
            // §2: no sampling/checking until rst deasserted >= 1 cycle
            prev_dv    <= 1'b0;
            stall      <= 0;
            xz_dv_prev <= 1'b0; xz_db_prev <= 1'b0; xz_mv_prev <= 1'b0;
            xz_mi_prev <= 1'b0; xz_mq_prev <= 1'b0;
        end else begin
            // ---- X/Z checks (now catching x AND z), edge-guarded ----
            if (is_unknown(demod_valid)) begin
                if (!xz_dv_prev) begin
                    errors = errors + 1;
                    $display("[ERROR] t=%0t CLASS=XZ demod_valid", $time);
                end
                xz_dv_prev <= 1'b1;
            end else xz_dv_prev <= 1'b0;

            if (is_unknown(^demod_bits)) begin
                if (!xz_db_prev) begin
                    errors = errors + 1;
                    $display("[ERROR] t=%0t CLASS=XZ demod_bits", $time);
                end
                xz_db_prev <= 1'b1;
            end else xz_db_prev <= 1'b0;

            if (is_unknown(mod_valid)) begin
                if (!xz_mv_prev) begin
                    errors = errors + 1;
                    $display("[ERROR] t=%0t CLASS=XZ mod_valid", $time);
                end
                xz_mv_prev <= 1'b1;
            end else xz_mv_prev <= 1'b0;

            if (is_unknown(^mod_i)) begin
                if (!xz_mi_prev) begin
                    errors = errors + 1;
                    $display("[ERROR] t=%0t CLASS=XZ mod_i", $time);
                end
                xz_mi_prev <= 1'b1;
            end else xz_mi_prev <= 1'b0;

            if (is_unknown(^mod_q)) begin
                if (!xz_mq_prev) begin
                    errors = errors + 1;
                    $display("[ERROR] t=%0t CLASS=XZ mod_q", $time);
                end
                xz_mq_prev <= 1'b1;
            end else xz_mq_prev <= 1'b0;

            // ---- valid/data pipeline check ----
            if (demod_valid === 1'b1) begin
                if (prev_dv) begin
                    errors = errors + 1;
                    $display("[ERROR] t=%0t CLASS=DUPLICATE idx=-1", $time);
                end else if (q_count == 0) begin
                    errors = errors + 1;
                    $display("[ERROR] t=%0t CLASS=UNEXPECTED_VALID idx=-1", $time);
                end else begin
                    if (demod_bits !== q_sym[q_head]) begin
                        errors = errors + 1;
                        $display("[ERROR] t=%0t CLASS=MISMATCH idx=%0d exp=%b got=%b",
                                 $time, q_idx[q_head], q_sym[q_head], demod_bits);
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
            valid_in = 1'b0;                  // exactly 1-cycle pulse
            repeat (IDLE_CYCLES) @(negedge clk);  // >= 2 idle cycles
        end
    endtask

    integer   r, k;
    reg [1:0] pattern [0:3];

    initial begin
        rst      = 1'b1;
        valid_in = 1'b0;
        bits_in  = 2'b00;
        errors   = 0; pushed = 0;
        q_head   = 0; q_tail = 0; q_count = 0;
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