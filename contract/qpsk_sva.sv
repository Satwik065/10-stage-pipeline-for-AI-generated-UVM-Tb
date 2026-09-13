`timescale 1ns/1ps
//----------------------------------------------------------------------
// qpsk_sva — Stage 1 contract artifact: protocol-level assertions
// (Constitution v2.1). Bound at the loopback TB boundary; spans the full
// 3-module chain (baseline latency 3: mod + channel + demod).
//
//   P1  liveness      : valid_in @t => valid_out in [t+1, t+6] (§2 L=6;
//                       worst legal Weather = 3+1 = 4 <= 6).
//                       PATCH v2.1-a: implemented as a procedural
//                       shift-register (see below) instead of
//                       `##[1:LIVENESS_L]`, because Verilator rejects
//                       ranged cycle delay. Semantics identical: a grant
//                       that survives to bit index LIVENESS_L (i.e. has
//                       not been consumed within L cycles) is a violation.
//   P2  credit check  : no valid_out without an outstanding valid_in.
//                       Exact for in-order 1:1 registered pipelines.
//                       Saturation [0,7] >= in-flight bound (L=6, §2).
//                       Catches the S-08 class (duplicate/extra valids).
//   P3  symbol domain : tautological (2-bit vector) — retained as the
//                       Stage 5 known-Dead control case
//   P4  X/Z outputs   : post-reset window (§5(d)); INERT under Verilator
//                       (2-state), functional on 4-state sims — the
//                       known 2-state-only control case
//   P5  1-cycle pulse : OFF by default. v2.1 §2/§13 record back-to-back
//                       valid_in as LEGAL (execution-confirmed for the
//                       v2 DUT incl. channel LFSR). Enabling this would
//                       manufacture §10-Harmful fires. Flip only in a
//                       constitution revision.
// No data-path assertions here by design: mismatch scoring is §5(b)
// scoreboard/BKG territory (MISMATCH_BUDGET=0); duplicating it in SVA
// would double-attribute Stage 5 failures.
// Every message is uniquely prefixed [SVA][P#] for §8-style blame
// attribution in Stage 5 per-assertion scoring.
//----------------------------------------------------------------------
module qpsk_sva #(
    parameter bit ENFORCE_VALID_PULSE = 1'b0
)(
    input logic       clk,
    input logic       rst,
    input logic       valid_in,
    input logic       valid_out,
    input logic [1:0] bits_in,    // observed; not used by P1-P5
    input logic [1:0] bits_out
);

    localparam int unsigned LIVENESS_L = 6;   // v2.1 §2

    //====================================================================
    // P1 — liveness bound (procedural; Verilator-compatible).
    //
    // PATCH v2.1-a: replaced `valid_in |-> ##[1:LIVENESS_L] valid_out`
    // with a shift-register deadline tracker.
    //
    // Model:
    //   pending_sr[i] == 1  <=>  a grant arrived (i+1) cycles ago and
    //                            has not yet been consumed by valid_out.
    //   Each posedge: shift left, insert valid_in at bit 0.
    //   If valid_out fires, clear the lowest set bit (in-order 1:1
    //   pipeline: valid_out always consumes the OLDEST outstanding grant).
    //   If a grant survives to bit index LIVENESS_L, the deadline
    //   (valid_in @ t => valid_out by t+L) has been missed -> violation.
    //
    // Bit-count proof: grant inserted at posedge a lives at bit (k-1) at
    // start of cycle a+k. At start of cycle a+L+1 (L+1 cycles after
    // arrival) it lives at bit L. The consequent is evaluated at the
    // posedge, i.e. it sees the state at the start of that cycle. So
    // firing on bit LIVENESS_L is exactly "no valid_out through cycle
    // a+L" — the intended L-bound, no off-by-one.
    //====================================================================
    localparam int SR_W = LIVENESS_L + 1;   // positions 0..L; L is violation
    logic [SR_W-1:0] pending_sr;

    always_ff @(posedge clk) begin
        if (rst) begin
            pending_sr <= '0;
        end else begin
            logic [SR_W-1:0] shifted;
            shifted = {pending_sr[SR_W-2:0], valid_in};
                        if (valid_out) begin
                // PATCH v2.1-e: clear the OLDEST outstanding grant. Bit index
                // is age: higher index = arrived earlier. In-order 1:1
                // pipeline consumes oldest-first, so clear the HIGHEST set
                // bit, not the lowest. The v2.1-d version cleared the lowest
                // set bit and lost the oldest grant whenever valid_in and
                // valid_out coincided (W-01/W-02/W-09), leaving a phantom
                // grant to age into bit LIVENESS_L and false-fire P1.
                for (int i = SR_W - 1; i >= 0; i--) begin
                    if (shifted[i]) begin
                        shifted[i] = 1'b0;
                        break;
                    end
                end
            end
            pending_sr <= shifted;
        end
    end

    a_liveness_valid_out: assert property (@(posedge clk) disable iff (rst)
        !pending_sr[SR_W-1])
        else $error("[SVA][P1] liveness: no valid_out within %0d cycles of valid_in (t=%0t)",
                    LIVENESS_L, $time);

    //--------------------------------------------------------------------
    // P2 — credit model. credits(t) = symbols granted in cycles < t that
    // have not yet produced valid_out. For an in-order 1:1 registered
    // pipeline, the symbol emerging this cycle is always among them, so
    // valid_out |-> credits != 0 is exact. The cap MUST exceed max
    // in-flight: §2 bounds it by L=6, so [0,7] never clips a legal value.
    // HISTORY: the v1 artifact capped at 2 < pipeline depth 3 — any
    // finite back-to-back burst lost a credit during drain and
    // false-fired on Golden. The BKG's >=2-idle envelope (credits <= 1)
    // could never expose it; v2.1's confirmed back-to-back legality made
    // it live. Net grant-consume single-step update; consume-then-grant
    // ordering is NOT equivalent at the clamp and must not be "simplified".
    //--------------------------------------------------------------------
    logic [2:0]        credits;
    logic signed [4:0] delta;

    always_ff @(posedge clk) begin
        if (rst) begin
            credits <= 3'd0;
        end else begin
            delta   = $signed({2'b00, credits})
                    + (valid_in  ? 5'sd1 : 5'sd0)
                    - (valid_out ? 5'sd1 : 5'sd0);
            credits <= (delta < 5'sd0) ? 3'd0 :
                       (delta > 5'sd7) ? 3'd7 : delta[2:0];
        end
    end

    a_credit_valid_out: assert property (@(posedge clk) disable iff (rst)
        valid_out |-> (credits != 3'd0))
        else $error("[SVA][P2] valid_out with no outstanding valid_in (credits exhausted) (t=%0t)", $time);

    //--------------------------------------------------------------------
    // P3 — symbol domain. Tautological for a 2-bit vector (every encoding
    // is a legal symbol). Kept per contract; expect Dead classification.
    //--------------------------------------------------------------------
    a_symbol_domain: assert property (@(posedge clk) disable iff (rst)
        valid_out |-> (bits_out inside {2'b00, 2'b01, 2'b10, 2'b11}))
        else $error("[SVA][P3] illegal symbol %b at valid_out (t=%0t)", bits_out, $time);

    //--------------------------------------------------------------------
    // P4 — no X/Z on outputs, sampled >= 1 cycle past reset deassertion
    // (§5(d) post-reset window; rst_q registered). 2-state simulators:
    // inert by construction ($isunknown is constant-false on Verilator).
    //--------------------------------------------------------------------
    logic rst_q;

    always_ff @(posedge clk) rst_q <= rst;

    a_no_xz_outputs: assert property (@(posedge clk) disable iff (rst)
        !rst_q |-> (!$isunknown(valid_out) && !$isunknown(bits_out)))
        else $error("[SVA][P4] X/Z on outputs (t=%0t)", $time);

    //--------------------------------------------------------------------
    // P5 — pulse rule, generate-gated OFF by default (see header).
    //--------------------------------------------------------------------
    if (ENFORCE_VALID_PULSE) begin : g_valid_pulse
        a_valid_in_single_cycle: assert property (@(posedge clk) disable iff (rst)
            valid_in |=> !valid_in)
            else $error("[SVA][P5] valid_in held >1 consecutive cycle (t=%0t)", $time);
    end

endmodule : qpsk_sva
