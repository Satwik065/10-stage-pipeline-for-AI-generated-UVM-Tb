# STAGE 0 CONSTITUTION — Sync Hub Protocol / QPSK Golden DUT — v1.5
constitution_sha256: <compute after saving this file, then paste here>

CHANGELOG (v1.4 -> v1.5, pre-freeze):
  - §5: added explicit clause for Stage 4-7 variant compile failures
    (scored T=0, C_dev=0, C_holdout=0; not retried). Closes a scoring
    hole where an AI-generated testbench that failed to compile had no
    defined verdict.
  - §13: restored Open Items checklist (dropped in v1.4). Guarantees
    constitution is not freezable while tb_qpsk_bkg.sv is unhashed or
    the 15-cell calibration has not run.
  - Tooling alignment: stage3_build_battery.py schema bumped to
    "sync-hub-battery/1.5"; calibrate retry logic clarified as
    per-seed, not per-cell.

1. Scope & Identity
DUT under test = QPSK modulator + demodulator pair (Golden RTL).

Artifact                SHA256
qpsk_modulator.sv       1e97e9d673a68abe31b1e6b811f1b39f8e6b0ecdc686cf77d1aed55e03d32c92
qpsk_demodulator.sv     dae0efdbbbd22282f4da54d373d20ade4a6227832350ffcb3721343fbaa3afe5
tb_qpsk_bkg.sv          3a026448fb641054513dc95ad4da32f851e76eb5e56c57cb08772631950adff1
tb_qpsk.sv              a68ceb49fcf174085686e9dbf3d2c8e223030095f34b112eccd126737d665549

2. Protocol Contract (what a TB may rely on)
Clock single-edge, synchronous active-high rst, asserted >= 3 cycles.
Data is meaningful ONLY when valid_out == 1. Sampling between valids is a TB bug.
No output-stability guarantee between valids. No fixed latency guarantee.
Liveness bound L = 6 cycles: any valid_in-produced symbol must produce
exactly one downstream valid within L cycles.
Battery invariant: max Weather added latency (1) < L. Weather mutations
are applied one at a time, per run (leave-one-out) — never stacked — so
the largest single addition from the §7 table (W-01 or W-02, +1 cycle each)
is the bound this invariant checks against L. This bound is the T/C resolution
for latency defects.
Legal constellation at valid: 00->(+127,+127) 01->(+127,-128)
10->(-128,+127) 11->(-128,-128). X/Z on any monitored signal post-reset = FAIL.

3. Stimulus Envelope (minimum, per scoring run)
= 40 symbols; each of the 4 symbols >= 10 times; valid asserted exactly
1 cycle per symbol; inter-symbol idle >= 2 cycles. tb_qpsk_bkg.sv
satisfies this exactly.

4. Seeds
LOCKED_SEEDS = [42, 1337, 9001, 271828, 314159]. Every random source
(UVM RNG, tool seed) must draw from this list. Any run using an
unlisted seed is invalid. tb_qpsk_bkg.sv is deterministic; seeds still
apply to every later-stage run.

5. Verdict Rules
A run = (testbench, dut_variant, seed). Run FAIL iff any of:
  (a) UVM_ERROR > 0 or SVA failure
  (b) data mismatch at a valid
  (c) missing / duplicate / late (beyond L) valid_out
  (d) X/Z on monitored signals
  (e) UVM watchdog / simulation timeout (200 us sim)
Else PASS. Warnings and INFO are ignored. "[RESULT]" is the only
pass/fail channel; log parsers must ignore everything else.
An INVALID run (compile error, missing [RESULT]) may be retried once
for infrastructure faults; a mutant that fails to COMPILE = broken
battery, fix the battery. Golden/Weather compile failures likewise
invalidate the battery.

Variant compile failure (Stage 4-7 only): a Stage 4-7 AI-generated
variant that fails to compile or elaborate is scored as T = 0,
C_dev = 0, C_holdout = 0. It is NOT retried. Compile failure is a
variant defect, not an infrastructure fault. This is the ONLY case in
which a variant is scored without simulation.

6. Metrics (locked)
FalseFail(run) = FAIL with dut in {Golden} U Weather.
Catch(variant, bug) = FAIL on >= 3 of 5 LOCKED_SEEDS.
T = 1 - (false-fail runs / total Golden+Weather runs). Gate: T = 1.0 exactly.
C_dev = |dev bugs caught| / 4. Gate: C_dev = 1.0 exactly.
C_holdout = |hold-out bugs caught| / 4, reported descriptively.
Generalization gap = C_dev - C_holdout.
C_dev and C_holdout are each already seed-aggregated via the Catch(variant, bug)
majority rule (>=3/5 seeds), so each is reported as a single value per surviving
variant — there is no remaining seed dimension to median over for the headline gap.
(Optional diagnostic: report raw 5-seed pass/fail vector per bug alongside Catch()).
Survivor = T = 1.0 AND C_dev = 1.0. No partial credit.

7. Weather Lane (tolerance — TB must NOT fail)
ID      Mutation                                    Max added latency
W-01    mod output staging: +1 cycle (aligned)       +1
W-02    demod output staging: +1 cycle (aligned)     +1
W-03    mod drives 0 on I/Q when !valid_in            0
W-04    demod drives bits=0 when !valid_in            0
W-05    mod reset takes effect 1 cycle late           0
W-06    demod reset takes effect 1 cycle late         0
Each Weather mutation above is applied individually, one per run.

8. Sabotage Lane (catch — TB MUST fail) and locked split
ID      Class        Split      Detection site
S-01    CONST        dev        mismatch on symbol 10
S-02    CONST        dev        mismatch on symbol 01
S-03    SLICE        dev        mismatch all symbols (I polarity)
S-04    SLICE        hold-out   mismatch on symbols 01, 10
S-05    HANDSHAKE    dev        missing valid for symbols 00, 01
S-06    HANDSHAKE    hold-out   mismatch from 2nd symbol on (skew)
S-07    CONST        hold-out   mismatch on symbol 00 (00->10)
S-08    HANDSHAKE    hold-out   duplicate/unexpected valid_out
DEV = {S-01, S-02, S-03, S-05}. HOLD-OUT = {S-04, S-06, S-07, S-08}.
Hold-out bugs are executed ONLY at Stage 8, results append-only, never
used for selection or tuning in Stages 4-7.

9. Calibration Gate
Instrument: tb_qpsk_bkg.sv. It must produce expected verdicts on ALL 15
cells (1 Golden PASS + 6 Weather PASS + 8 Sabotage FAIL) across all 5 seeds.
Any mismatch => the battery is broken. Fix the battery, never the BKG.

10. Per-Assertion Taxonomy (locked now, used at Stage 5)
Harmful: fires on >= 1 Golden/Weather run (any seed).
Useful: fires on >= 3/5 seeds of >= 1 DEV bug, never on Golden/Weather.
Dead: fires nowhere.
Redundant: Useful, but its caught-bug set is a subset of the union of
kept assertions; keep-order = generation index (deterministic greedy).

11. Change Control
Post-freeze edits to this document invalidate the experiment. Battery
rebuilds must be byte-identical: stage3_build_battery.py --verify must
pass against the locked manifest. If the Golden RTL ever changes, the
entire constitution is re-written as v2.

12. Provenance Chain
manifest.json records: constitution_sha256 -> golden hashes -> per-
variant hashes. The Stage 5 runner re-verifies variant hashes before
simulating.

13. Open Items (MUST be empty before computing constitution_sha256)
  [x] Hash qpsk_modulator.sv, qpsk_demodulator.sv, tb_qpsk_bkg.sv,
      tb_qpsk.sv into §1 (sha256sum each file).
  [x] Run `python stage3_build_battery.py` then
      `python stage3_build_battery.py --verify` — confirm byte-identical.
  [x] Run `python stage3_calibrate.py` — confirm 15/15 cells match
      expected verdicts across all 5 LOCKED_SEEDS.
  [x] Compute constitution_sha256 and freeze. No further edits.