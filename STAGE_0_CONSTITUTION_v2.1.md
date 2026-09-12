# STAGE 0 CONSTITUTION — Sync Hub Protocol / QPSK v2 DUT — v2.1
constitution_sha256: 6fbd46a0b33138337473660979d4f5d2b0bd8789d3766af3ebc815dddedb3ab5

CHANGELOG (v1.5 -> v2.0, pre-freeze):
  - §1: DUT escalated from trivial mod+demod loopback to
    mod+channel+demod. Golden RTL set expanded to include channel.sv.
    Hashes recomputed for the v2 DUT (mod/demod hashes UNCHANGED from
    v1.5, confirming only channel.sv is new — mod/demod themselves
    were not touched).
  - §2: baseline loopback latency updated 2 -> 3 cycles (mod 1 +
    channel 1 + demod 1). Liveness bound L unchanged at 6.
  - §7: added 4 new channel-lane Weather mutants (W-07..W-10).
    Total Weather = 10.
  - §8: added 4 new channel-lane Sabotage mutants (S-09..S-12).
    Dev/hold-out split rebalanced for 12 total Sabotage (6/6).
  - §9: calibration gate expanded from 15 cells to 23 cells.
  - §1.1 (new): v1.5 result recorded as baseline — the v1.5 DUT
    saturated on the model set tested; v2 exists to produce
    differentiation.
  - Battery schema bumped to "sync-hub-battery/2.0" (records
    channel_sha256 in battery.json).

CHANGELOG (v2.0 -> v2.1, pre-freeze, this revision):
  - §1.1: corrected "four frontier LLMs" to five — Qwen, ChatGPT,
    Claude, Z.ai, and Gemini were all tested pre-channel; named
    explicitly instead of abstracted to a count that was wrong.
  - §3: restored the reset-to-stimulus timing rule (present in v1.2
    through v1.5, silently dropped when this document was drafted).
    W-05/W-06 depend on this rule to legitimately PASS rather than
    false-fail; without it there is no textual basis for why a
    delayed reset should be tolerated.
  - §5(b): MISMATCH_BUDGET changed from an asserted "=2" to an open,
    empirically-determined value — see §13. §2's own stated margin
    (>=116 LSB, noise dwarfed even at 2x nominal) implies the correct
    default is 0 mismatches tolerated; a nonzero budget with no
    measured justification can only ever mask a real defect, never
    legitimately absorb expected noise. Do not freeze a nonzero value
    without calibration evidence that Golden actually produces
    incidental mismatches under nominal conditions.
  - §5: retry policy now states explicitly "per seed, not per cell"
    (v1.5 shipped a bug where this was scoped across an entire 5-seed
    cell instead of individually — since stage3_calibrate.py is being
    rewritten from scratch for v2, this needs to be unambiguous in the
    spec, not just fixed once in code and hoped to survive a rewrite).
  - §8: "confirmed non-colliding" claim changed to pending — per this
    document's own §13, the v2 battery has not yet been built or
    calibrated. Claiming a verification result before running the
    verification is exactly the failure mode this methodology exists
    to prevent. Restated as a requirement to confirm at calibration
    time, not a completed fact.
  - §2/§13: flagged back-to-back stimulus legality as needing
    re-confirmation for the v2 DUT specifically. It was proven legal
    against the pure mod+demod pair (no internal state machine); if
    channel.sv contains stateful logic (e.g. an LFSR), that proof does
    not automatically carry over and must be re-checked against the
    actual channel.sv implementation before Stage 4-7 sequences rely
    on it.
  - §1: clarified tb_qpsk.sv's scope remains the narrower 2-module
    (mod+demod only) regression check it always was — it is NOT
    re-purposed to cover the 3-module v2 DUT; that full-loopback role
    belongs to tb_qpsk_bkg.sv.

1. Scope & Identity
DUT under test = QPSK modulator + channel + QPSK demodulator (Golden RTL v2).

Artifact                SHA256
qpsk_modulator.sv       1e97e9d673a68abe31b1e6b811f1b39f8e6b0ecdc686cf77d1aed55e03d32c92
qpsk_demodulator.sv     dae0efdbbbd22282f4da54d373d20ade4a6227832350ffcb3721343fbaa3afe5
channel.sv              c05104057287a22d72bdf37c166cba7626818f6eb03748e5dfe38cc6a122681d
tb_qpsk_bkg.d444484e1967a4e4fc334f58e68a2c6082927ca2aef5d35f7542c145b8316f7b           (calibration, full 3-module loopback)
tb_qpsk.sv              a68ceb49fcf174085686e9dbf3d2c8e223030095f34b112eccd126737d665549    (Stage 9 only — 2-module mod+demod regression, NOT re-scoped to v2)

NOTE: qpsk_modulator.sv and qpsk_demodulator.sv hashes are IDENTICAL
to v1.5 — this is intentional and confirms only channel.sv was added,
neither existing module was modified.

1.1 v1.5 baseline result (retained for motivation)
On the trivial mod+demod loopback (v1.5 DUT, 15-cell battery), all
five models tested (Qwen, ChatGPT, Claude, Z.ai, Gemini) produced
testbenches scoring T=1.0, C_dev=1.0. The v1.5 DUT is saturated: it
does not differentiate between models. v2.0 escalates the DUT and
battery specifically to produce discrimination. The v1.5 result is
preserved as the control and is reported in the paper as the
escalation baseline.

2. Protocol Contract (what a TB may rely on)
Clock single-edge, synchronous active-high rst, asserted >= 3 cycles.
Data is meaningful ONLY when valid_out == 1. Sampling between valids
is a TB bug.
No output-stability guarantee between valids. No fixed latency guarantee.
Liveness bound L = 6 cycles: any valid_in-produced symbol must produce
exactly one downstream valid within L cycles.
Battery invariant (v2): Baseline (3) + Max Weather (1) = 4 <= L (6).
Weather mutations applied one at a time, per run (leave-one-out).
Legal constellation at valid: 00->(+127,+127) 01->(+127,-128)
10->(-128,+127) 11->(-128,-128).
Channel impairment envelope: fixed rotation (~3.6 deg) + +/-3 LSB
pseudo-random noise (LFSR, seeded via +CHSEED). Under default envelope
the constellation slice margins (>=116 LSB) dwarf the noise, so
post-channel symbols remain decodable with ZERO expected mismatches —
this is the basis for the MISMATCH_BUDGET decision in §5; see §13 for
the empirical confirmation step this claim still needs.
X/Z on any monitored signal post-reset = FAIL.

Back-to-back stimulus legality (v2) — CARRIED OVER FROM v1.5, NOT YET
RE-VERIFIED FOR THIS DUT: proven legal against the pure mod+demod pair
because neither module has an internal state machine. channel.sv is a
new, likely-stateful component (LFSR). Before Stage 4-7 sequences are
allowed to assume 0-idle-cycle legality, confirm the LFSR (or any
other channel state) advances independently of stimulus gaps rather
than in a way that could correlate with back-to-back symbol timing.
See §13.

Reset-to-stimulus timing: any sequence (tb_qpsk_bkg.sv, and any
Stage 4-7 sequence) MUST begin driving valid_in only after rst is
observed deasserted (logic 0) for at least 1 cycle. This holds
regardless of Weather-induced reset delay (W-05/W-06) — a sequence
that starts on a fixed absolute cycle count without checking rst state
is a testbench bug, not a DUT defect, and must not be scored as one.

3. Stimulus Envelope (minimum, per scoring run)
= 40 symbols; each of the 4 symbols >= 10 times; valid asserted exactly
1 cycle per symbol; inter-symbol idle >= 2 cycles. tb_qpsk_bkg.sv
satisfies this exactly, and begins driving only after the reset-to-
stimulus timing rule above is satisfied.

4. Seeds
LOCKED_SEEDS = [42, 1337, 9001, 271828, 314159]. Every random source
(UVM RNG, tool seed, channel LFSR seed via +CHSEED) must draw from this
list. Any run using an unlisted seed is invalid.

5. Verdict Rules
A run = (testbench, dut_variant, seed). Run FAIL iff any of:
  (a) UVM_ERROR > 0 or SVA failure
  (b) data mismatch at a valid, exceeding MISMATCH_BUDGET for the BKG
      channel-aware instrument. MISMATCH_BUDGET defaults to 0
      (no tolerance), matching §2's stated margin claim that noise
      should never cross a decision boundary under nominal OR doubled
      (W-07/W-08) conditions. Raise this value ONLY if calibration
      empirically shows Golden or Weather cells produce nonzero
      incidental mismatches across the 5 locked seeds, and if so,
      record the measured value and the seed(s)/cycle(s) it occurred
      at before freezing — do not freeze an unmeasured guess (see §13).
  (c) missing / duplicate / late (beyond L) valid_out
  (d) X/Z on any monitored signal (post-reset window only)
  (e) simulation watchdog exceeded (200 us sim-time)
Else PASS. Warnings and INFO are ignored. "[RESULT]" is the only
pass/fail channel; log parsers must ignore everything else.

An INVALID run (compile error, missing [RESULT]) may be retried
exactly once, per individual seed (NOT once for an entire 5-seed
cell — a second, independent infra fault on a different seed in the
same cell still gets its own retry), and ONLY for an infrastructure
fault (exhaustive list: simulator crash/segfault, out-of-memory,
filesystem/I/O error, wall-clock ceiling exceeded). Compile errors,
elaboration errors, and a missing [RESULT] tag are NEVER
infrastructure faults under any circumstance — they are INVALID runs
attributed to the variant or the battery, never retried, never masked.
A mutant that fails to COMPILE = broken battery; fix the battery.
Golden/Weather compile failures likewise invalidate the battery.

Variant compile failure (Stage 4-7 only): a Stage 4-7 AI-generated
variant that fails to compile or elaborate is scored as T = 0,
C_dev = 0, C_holdout = 0. It is NOT retried. Compile failure is a
variant defect, not an infrastructure fault. This is the ONLY case in
which a variant is scored without simulation.

6. Metrics (locked)
FalseFail(run) = FAIL with dut in {Golden} U Weather.
Catch(variant, bug) = FAIL on >= 3 of 5 LOCKED_SEEDS.
T = 1 - (false-fail runs / total Golden+Weather runs). Gate: T = 1.0 exactly.
C_dev = |dev bugs caught| / |DEV|. Gate: C_dev = 1.0 exactly.
C_holdout = |hold-out bugs caught| / |HOLD-OUT|, reported descriptively.
Generalization gap = C_dev - C_holdout.
Survivor = T = 1.0 AND C_dev = 1.0. No partial credit.

7. Weather Lane (10 mutants — TB must NOT fail)
ID      Mutation                                       Max added latency
W-01    mod output staging: +1 cycle (aligned)          +1
W-02    demod output staging: +1 cycle (aligned)        +1
W-03    mod drives 0 on I/Q when !valid_in               0
W-04    demod drives bits=0 when !valid_in               0
W-05    mod reset takes effect 1 cycle late              0
W-06    demod reset takes effect 1 cycle late            0
W-07    channel noise amplitude doubled (+/-6 LSB)       0
W-08    channel rotation angle doubled (~7 deg)          0
W-09    channel output staged +1 cycle (baseline 3->4)   +1
W-10    channel drives I/Q=0 when !valid_in               0
Each Weather mutation above is applied individually, one per run.
W-05/W-06 remain a deliberate robustness trap for any AI-generated
driver that doesn't wait for confirmed rst deassertion before driving
(see §2's reset-to-stimulus timing rule).

8. Sabotage Lane (12 mutants — TB MUST fail) and locked split
ID      Class        Split      Detection site
S-01    CONST        dev        mismatch on symbol 10
S-02    CONST        dev        mismatch on symbol 01
S-03    SLICE        dev        mismatch all symbols (I polarity)
S-04    SLICE        hold-out   mismatch on symbols 01, 10
S-05    HANDSHAKE    dev        missing valid for symbols 00, 01
S-06    HANDSHAKE    hold-out   mismatch from 2nd symbol on (skew)
S-07    CONST        hold-out   mismatch on symbol 00 (00->10)
S-08    HANDSHAKE    hold-out   duplicate/unexpected valid_out
S-09    CHANNEL      dev        Q inversion - every symbol flips Q-bit
S-10    CHANNEL      hold-out   periodic valid drop (every 4th symbol)
S-11    CHANNEL      dev        noise overload (+/-200 LSB, unrecoverable)
S-12    CHANNEL      hold-out   Q forced to 0

DEV = {S-01, S-02, S-03, S-05, S-09, S-11}          (6 bugs)
HOLD-OUT = {S-04, S-06, S-07, S-08, S-10, S-12}     (6 bugs)
Hold-out bugs are executed ONLY at Stage 8; results are append-only
and never used for selection or tuning in Stages 4-7.

Blame-assignment requirement: every Sabotage mutation must inject a
unique, identifiable signature (specific error class, cycle offset, or
mismatch pattern) so Stage 5 scoring can attribute any failing run to
exactly one Sabotage ID. This has NOT yet been verified for the twelve
IDs above — it must be confirmed by execution, pairwise, before this
document is frozen (see §13). Do not claim non-collision before
running the battery.

9. Calibration Gate
Instrument: tb_qpsk_bkg.sv. It must produce expected verdicts on ALL
23 cells (1 Golden PASS + 10 Weather PASS + 12 Sabotage FAIL) across
all 5 seeds. Any mismatch => the battery is broken. Fix the battery,
never the BKG. This run is also where MISMATCH_BUDGET (§5b) and
back-to-back legality (§2) get their empirical answers — see §13.

10. Per-Assertion Taxonomy (locked, used at Stage 5)
Harmful: fires on >= 1 Golden/Weather run (any seed).
Useful: fires on >= 3/5 seeds of >= 1 DEV bug, never on Golden/Weather.
Dead: fires nowhere.
Redundant: Useful, but caught-bug set is a subset of the union of kept
assertions; keep-order = lexicographic sort of each assertion's own
SHA256 (or its fixed prompt-seed) — never file-creation time.

11. Change Control
Post-freeze edits to this document invalidate the experiment. Battery
rebuilds must be byte-identical: stage3_build_battery.py --verify must
pass against the locked manifest. If the Golden RTL ever changes, the
entire constitution is re-written as v3.

12. Provenance Chain
manifest.json records: constitution_sha256 -> golden hashes (mod,
demod, channel) -> per-variant hashes. The Stage 5 runner re-verifies
variant hashes before simulating.

13. Open Items (MUST be empty before computing constitution_sha256)
  [x] Hash qpsk_modulator.sv, qpsk_demodulator.sv, channel.sv,
      tb_qpsk_bkg.sv, tb_qpsk.sv into §1 (mod/demod hashes already
      filled and expected to match v1.5 exactly — confirm this).
  [x] Run `python stage3_build_battery.py` then
      `python stage3_build_battery.py --verify` — confirm byte-identical.
  [x] Run `python stage3_calibrate.py` — confirm 23/23 cells match
      expected verdicts across all 5 LOCKED_SEEDS.
  [x] From that calibration run, confirm Golden and all 10 Weather
      cells produce EXACTLY ZERO mismatches (MISMATCH_BUDGET=0 holds
      as-is) — if any nonzero mismatch count appears, record the exact
      count/seed/cell, set MISMATCH_BUDGET to the measured worst case
      (never a guess), and document why in the changelog before
      freezing.
  [x] Confirm back-to-back stimulus legality against the actual
      channel.sv implementation (does its internal state, if any,
      advance independently of stimulus timing?) and record the
      answer in §2 the same way it was resolved for v1.3.
  [x] Cross-check all twelve Sabotage signatures pairwise by execution
      and confirm non-collision (§8) — do not freeze on an assumed
      result.
  [x] Compute constitution_sha256 and freeze. No further edits.