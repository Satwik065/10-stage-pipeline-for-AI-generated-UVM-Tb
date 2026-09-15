Appendix — Sync Hub Protocol Verification Pipeline (v2.1)
Experiment Log: Stage 0 (Constitution), Stage 3 (Battery), Stage 4 (Variant Scoring)
DUT: QPSK Modulator + Channel + QPSK Demodulator (Golden RTL v2)
Status: Stages 0, 3, and 4 complete and frozen. Stage 4 produced model differentiation.
Pipeline context: This appendix covers Stages 0, 3, and 4 of the 10-stage Sync Hub Protocol pipeline (Constitution → Contract Lock → Mechanical Derivation → Battery & Calibration → Variant Generation → Scoring → Assembly/Integration → Coverage → Hold-out Generalization → Golden Sanity → Handoff). See main text for the full pipeline and its ablation design (A: full pipeline, B: no-Weather, C: no-Contract-Lock, D: naive-AI baseline, E: cross-model).

1. Golden RTL (v2)
A hand-written, hand-verified QPSK modulator + channel + demodulator pipeline serves as ground truth for every downstream mutation and scoring experiment.

Design summary
Modulator: 2-bit symbol → registered signed 8-bit I/Q constellation, 1-cycle latency.

00 → I=+127, Q=+127 · 01 → I=+127, Q=-128 · 10 → I=-128, Q=+127 · 11 → I=-128, Q=-128

Channel: registered, 1-cycle latency, applies fixed rotation (~3.6°) and ±3 LSB pseudo-random noise from a 32-bit LFSR. LFSR seed tied to LOCKED_SEEDS via +CHSEED. LFSR advances unconditionally every cycle (not gated by valid_in), so back-to-back stimulus legality carries over from v1.5. Saturating 8-bit output.

Demodulator: zero-threshold slicer, 1-cycle latency.

bits[1] = (i_in < 0) · bits[0] = (q_in < 0)

Loopback latency (baseline): 3 cycles (1 mod + 1 channel + 1 demod).

Reset: synchronous, active-high, asserted ≥ 3 cycles.

Artifact hashes (SHA256)
Artifact	SHA256
qpsk_modulator.sv	1e97e9d673a68abe31b1e6b811f1b39f8e6b0ecdc686cf77d1aed55e03d32c92
qpsk_demodulator.sv	dae0efdbbbd22282f4da54d373d20ade4a6227832350ffcb3721343fbaa3afe5
channel.sv	c05104057287a22d72bdf37c166cba7626818f6eb03748e5dfe38cc6a122681d
tb_qpsk_bkg.sv	d444484e1967a4e4fc334f58e68a2c6082927ca2aef5d35f7542c145b8316f7b
tb_qpsk.sv (Stage 9 only)	a68ceb49fcf174085686e9dbf3d2c8e223030095f34b112eccd126737d665549
Note on hashes: qpsk_modulator.sv and qpsk_demodulator.sv hashes are identical to v1.5 — this is intentional and confirms only channel.sv was added; neither existing module was modified. tb_qpsk.sv remains the narrower 2-module (mod+demod only) Stage 9 regression check; it is not re-scoped to cover the 3-module v2 DUT.

2. Stage 0 — Constitution v2.1 (frozen)
text
constitution_sha256: <computed and recorded externally in CONSTITUTION_v2.1_HASH.txt>
2.1 Locked parameters
Parameter	Value
DUT	QPSK modulator + channel + demodulator
Liveness bound L	6 cycles
Battery invariant	Baseline (3) + Max Weather (1) = 4 ≤ L (6)
LOCKED_SEEDS	[42, 1337, 9001, 271828, 314159]
Stimulus envelope (BKG)	40 symbols, ≥10 of each, 1-cycle valid, ≥2-cycle idle
Verdict channel	[RESULT] PASS / [RESULT] FAIL errors=N / [RESULT] FAIL watchdog
Simulation watchdog	200 µs sim-time
Wall-clock ceiling	120 s (infrastructure-only, never a verdict)
MISMATCH_BUDGET	0 (empirically justified — see §3.5)
Survivor gate	T = 1.0 exactly AND C_dev = 1.0 exactly, no partial credit
2.2 Protocol contract
Data meaningful only when valid_out == 1; no output-stability or fixed-latency guarantee between valids.

X/Z checked only in the post-reset window; uses an is_unknown() test so both x and z are caught, not x alone.

Reset-to-stimulus timing rule: any sequence must begin driving valid_in only after rst is observed deasserted for ≥1 cycle, regardless of Weather-induced reset delay (W-05/W-06).

Back-to-back stimulus legality: legal. Confirmed against the actual v2 DUT: the channel's LFSR advances unconditionally every cycle (rtl/channel.sv line 40), so its state is stimulus-independent and does not correlate with back-to-back symbol timing.

Channel impairment envelope: fixed rotation (~3.6°) + ±3 LSB LFSR noise (seed-tied via +CHSEED). Constellation slice margins (≥116 LSB) dwarf the noise even at 2× nominal (W-07/W-08), so zero incidental mismatches are expected — this is the basis for MISMATCH_BUDGET=0.

2.3 Verdict rules — a run FAILS iff any of:
(a) UVM_ERROR > 0 or SVA failure
(b) data mismatch at a valid, exceeding MISMATCH_BUDGET
(c) missing / duplicate / late (beyond L) valid_out
(d) X/Z on any monitored signal, post-reset window only
(e) simulation-time watchdog exceeded (200 µs)

Infrastructure fault (strict, exhaustive list — retried exactly once, per individual seed, NOT per 5-seed cell): simulator crash/segfault, out-of-memory, filesystem/I/O error, or wall-clock ceiling exceeded. Compile errors, elaboration errors, and a missing [RESULT] tag are NEVER infrastructure faults — they are INVALID runs attributed to the variant or the battery, never retried, never masked.

Variant compile-failure policy (Stage 4-7 only): a variant that fails to compile scores T=0, C_dev=0, C_holdout=0 — never retried, never treated as infrastructure failure. This is the only case where a variant is scored without simulation.

2.4 Metrics (locked)
FalseFail(run) = FAIL with dut in {Golden} ∪ Weather.

Catch(variant, bug) = FAIL on ≥3 of 5 LOCKED_SEEDS.

T = 1 - (false-fail runs / total Golden+Weather runs). Gate: T = 1.0.

C_dev = |dev bugs caught| / |DEV|. Gate: C_dev = 1.0.

C_holdout = |hold-out bugs caught| / |HOLD-OUT|, reported descriptively.

Generalization gap = C_dev - C_holdout.

Survivor = T = 1.0 AND C_dev = 1.0. No partial credit.

2.5 Per-assertion taxonomy (locked; used at Stage 5)
Class	Definition
Harmful	fires on ≥1 Golden/Weather run (any seed)
Useful	fires on ≥3/5 seeds of ≥1 DEV bug, never on Golden/Weather
Dead	fires nowhere
Redundant	Useful, but caught-bug set is a subset of the union of kept assertions; keep-order = lexicographic sort of each assertion's own SHA256 (or its fixed prompt-seed) — never file-creation time
2.6 Change log (v1.0 → v2.1)
Version	Change
v1.0 → v1.1	Corrected §2 latency invariant (3 → 1, matching Weather table); removed inapplicable seed-median line from §6.
v1.1 → v1.2	Scoped X/Z checks to post-reset window; flagged back-to-back stimulus and baseline latency as open decisions; added reset-to-stimulus timing rule; demoted wall-clock from verdict to infra-only net; tightened infra-fault list; added Sabotage blame-assignment signature requirement (§8); specified Redundant tie-break source.
v1.2 → v1.3	Resolved both open decisions against actual Golden RTL (back-to-back legal; baseline latency = 2 cycles); filled SHA256 hashes.
v1.3 → v1.4	Replaced hardcoded-latency check with latency-agnostic in-order queue (required for W-01/W-02 to pass); redesigned S-07 after execution showed it was observationally identical to S-04 in loopback; authored and calibrated BKG + battery (15/15).
v1.4 → v1.5	Added variant compile-failure clause (§5); strengthened X/Z detection to catch both x and z; fixed retry-scoping bug in calibration runner (per-seed, not per-cell).
v1.5 → v2.0	DUT escalated — channel inserted between mod and demod. Baseline latency 2 → 3. Added 4 channel-targeted Weather (W-07..W-10) and 4 channel-targeted Sabotage (S-09..S-12) mutants. Dev/hold-out rebalanced to 6/6. Calibration gate expanded 15 → 23 cells. Battery schema bumped to sync-hub-battery/2.0.
v2.0 → v2.1	Corrected v1.5 baseline from "four" to five models (Qwen, ChatGPT, Claude, Z.ai, Gemini). Restored reset-to-stimulus rule (silently dropped in v2.0 draft). MISMATCH_BUDGET changed from asserted =2 to empirically-determined 0. Retry policy stated explicitly per-seed. §8 "confirmed non-colliding" claim downgraded from asserted fact to calibration-time requirement. Flagged back-to-back legality for re-verification against the stateful channel. Clarified tb_qpsk.sv scope (2-module, not re-scoped to v2).
2.7 §13 Open Items — all closed
#	Item	Evidence
1	Hash all 5 files into §1	Done. mod/demod hashes match v1.5.
2	Battery byte-identical (--verify)	[OK] verify: all mutants byte-identical to deterministic rebuild
3	23/23 calibration across 5 seeds	CELLS: 23/23 matched
4	MISMATCH_BUDGET=0 confirmed	grep -c "INFO.*MISMATCH" → 0
5	Back-to-back legality against channel.sv	LFSR unconditional (line 40); state is stimulus-independent.
6	12 Sabotage signatures non-colliding	Cross-checked pairwise by execution (see §3.6). S-12 ⊂ S-09 subset noted and documented.
3. Stage 3 — Battery Construction & Calibration
3.1 stage3_build_battery.py — Deterministic Mutation Factory
Reads the three Golden RTL files (qpsk_modulator.sv, qpsk_demodulator.sv, channel.sv), applies 22 anchored string-substitution transforms (zero LLM involvement). Every anchor must occur exactly once or the build aborts. Idempotent — --verify re-derives every mutant in memory and byte-compares against disk.

Each mutant directory contains the mutated file plus a manifest.json: id, lane, target_file, transform_description, expected_verdict, signature, golden_source_sha256, mutated_file_sha256, builder version. A top-level battery.json records the Golden hashes, channel_sha256, and the mutant list.

3.2 Weather Lane (10 mutants — TB must NOT fail)
ID	Mutation	Max added latency
W-01	mod output staged +1 cycle (aligned)	+1
W-02	demod output staged +1 cycle (aligned)	+1
W-03	mod drives I/Q=0 when !valid_in	0
W-04	demod drives bits=0 when !valid_in	0
W-05	mod reset effective 1 cycle late	0
W-06	demod reset effective 1 cycle late	0
W-07	channel noise amplitude doubled (±6 LSB)	0
W-08	channel rotation angle doubled (~7°)	0
W-09	channel output staged +1 cycle (baseline 3→4)	+1
W-10	channel drives I/Q=0 when !valid_in	0
W-05/W-06 are a deliberate robustness trap for any AI driver that doesn't wait for confirmed rst deassertion before driving.

3.3 Sabotage Lane (12 mutants — TB MUST fail) and locked split
ID	Class	Split	Detection site
S-01	CONST	dev	mismatch on symbol 10
S-02	CONST	dev	mismatch on symbol 01
S-03	SLICE	dev	mismatch all symbols (I polarity)
S-04	SLICE	hold-out	mismatch on symbols 01, 10
S-05	HANDSHAKE	dev	missing valid for symbols 00, 01
S-06	HANDSHAKE	hold-out	mismatch from 2nd symbol on (skew)
S-07	CONST	hold-out	mismatch on symbol 00 (00→10)
S-08	HANDSHAKE	hold-out	duplicate / unexpected valid_out
S-09	CHANNEL	dev	Q inversion — every symbol flips Q-bit
S-10	CHANNEL	hold-out	periodic valid drop (every 4th symbol)
S-11	CHANNEL	dev	noise overload (±200 LSB, unrecoverable)
S-12	CHANNEL	hold-out	Q forced to 0
DEV = {S-01, S-02, S-03, S-05, S-09, S-11} (6 bugs)
HOLD-OUT = {S-04, S-06, S-07, S-08, S-10, S-12} (6 bugs)

Hold-out bugs are executed only at Stage 8; results are append-only, never used for selection or tuning in Stages 4–7.

3.4 S-07 redesign rationale
The originally tabled S-07 (modulator constellation arms 01/10 transposed) was found by execution to be observationally identical in full loopback to S-04 (demodulator I/Q slice swap) — both produce exactly {01→10, 10→01} with 00/11 clean, violating the blame-assignment requirement. S-07 was rebuilt as "symbol 00's I-arm corrupted to −128," producing a non-colliding signature (only 00→10).

3.5 Calibration Gate — 23/23 PASS
stage3_calibrate.py compiles the BKG against Golden + all 22 mutants, runs each combination across all 5 LOCKED_SEEDS, parses only the [RESULT] line, prints the 23-cell matrix.

Provenance enforcement (before any simulation): re-verifies battery.json's recorded Golden hashes and channel_sha256 against current rtl/*.sv. Aborts on drift.

Retry policy: wall-clock timeout retried exactly once, per individual seed (not per 5-seed cell).

text
golden                           golden    exp=PASS  act=P P P P P    (5P/0F) OK
W-01_mod_latency_plus1           weather   exp=PASS  act=P P P P P    (5P/0F) OK
W-02_demod_latency_plus1         weather   exp=PASS  act=P P P P P    (5P/0F) OK
W-03_mod_idle_zero               weather   exp=PASS  act=P P P P P    (5P/0F) OK
W-04_demod_idle_zero             weather   exp=PASS  act=P P P P P    (5P/0F) OK
W-05_mod_reset_late              weather   exp=PASS  act=P P P P P    (5P/0F) OK
W-06_demod_reset_late            weather   exp=PASS  act=P P P P P    (5P/0F) OK
S-01_const_sym10_i               sabotage  exp=FAIL  act=F F F F F    (0P/5F) OK
S-02_const_sym01_q               sabotage  exp=FAIL  act=F F F F F    (0P/5F) OK
S-03_slice_invert_i              sabotage  exp=FAIL  act=F F F F F    (0P/5F) OK
S-04_slice_swap_iq               sabotage  exp=FAIL  act=F F F F F    (0P/5F) OK
S-05_mod_valid_gate              sabotage  exp=FAIL  act=F F F F F    (0P/5F) OK
S-06_demod_valid_skew            sabotage  exp=FAIL  act=F F F F F    (0P/5F) OK
S-07_const_sym00_i               sabotage  exp=FAIL  act=F F F F F    (0P/5F) OK
S-08_demod_valid_dup             sabotage  exp=FAIL  act=F F F F F    (0P/5F) OK
W-07_ch_noise_doubled            weather   exp=PASS  act=P P P P P    (5P/0F) OK
W-08_ch_rotation_doubled         weather   exp=PASS  act=P P P P P    (5P/0F) OK
W-09_ch_latency_plus1            weather   exp=PASS  act=P P P P P    (5P/0F) OK
W-10_ch_idle_zero                weather   exp=PASS  act=P P P P P    (5P/0F) OK
S-09_ch_q_inversion              sabotage  exp=FAIL  act=F F F F F    (0P/5F) OK
S-10_ch_drop_valid               sabotage  exp=FAIL  act=F F F F F    (0P/5F) OK
S-11_ch_noise_overload           sabotage  exp=FAIL  act=F F F F F    (0P/5F) OK
S-12_ch_q_zero                   sabotage  exp=FAIL  act=F F F F F    (0P/5F) OK

CELLS: 23/23 matched
CALIBRATION: PASS — battery certified, proceed to Stage 4
3.6 Signature non-collision verification
All 12 Sabotage mutants cross-checked pairwise by execution (seed 42, full 40-symbol output). Frequency distributions:

Mutant	Signature (exp→got, count)
S-01	{(10,00)×10}
S-02	{(01,00)×10}
S-03	{(11,01)×10, (10,00)×10, (01,11)×10, (00,10)×10}
S-04	{(10,01)×10, (01,10)×10}
S-05	{(01,11)×5, (00,10)×5} + LIVENESS + MISSING
S-06	{(11,10)×10, (10,01)×10, (01,00)×10, (00,11)×9}
S-07	{(00,10)×10}
S-08	(empty mismatch set — DUPLICATE only)
S-09	{(11,10)×10, (10,11)×10, (01,00)×10, (00,01)×10}
S-10	12 mixed patterns + LIVENESS
S-11	12 mixed patterns
S-12	{(11,10)×10, (01,00)×10}
Result: No two mutants share an identical set. §8 non-collision requirement satisfied.

S-12 ⊂ S-09 subset relation: S-12's signature is a strict subset of S-09's. Attribution relies on complete-pattern matching (full 40-symbol output) rather than individual-pair matching, since the stimulus is fixed and outputs are deterministic. This is documented in §8 of the constitution.

4. Stage 4 — AI Variant Generation and Scoring
4.1 Method
For each of five frontier LLMs (Claude, ChatGPT, Qwen, Z.ai, Gemini), we issued a fixed prompt describing the mod+channel+demod DUT interface, the constellation mapping, the channel impairment, the latency contract, and the [RESULT]-only verdict channel. Each model produced one hand-tuned testbench variant. Each variant was scored against the 23-cell battery across all 5 LOCKED_SEEDS.

Selection was never performed. All five variants were scored unconditionally. Scoring followed §6 metrics with no partial credit.

4.2 Table A — v1.5 baseline (trivial DUT, 15-cell battery)
Model	Golden	Weather (6)	Sabotage (8)	T	C_dev	Verdict
Claude	PASS	PASS ×6	FAIL ×8	1.0	1.0	Keeper
ChatGPT	PASS	PASS ×6	FAIL ×8	1.0	1.0	Keeper
Qwen	PASS	PASS ×6	FAIL ×8	1.0	1.0	Keeper
Z.ai	PASS	PASS ×6	FAIL ×8	1.0	1.0	Keeper
Gemini	PASS	PASS ×6	FAIL ×8	1.0	1.0	Keeper
v1.5 outcome: saturated. All five models produced testbenches that satisfied the survivor gate. Trivial loopback DUT does not differentiate frontier LLMs. This motivated the v2.0 DUT escalation.

4.3 Table B — v2.1 DUT (channel-impaired, 23-cell battery)
Model	Golden	Weather (10)	Sabotage (12)	T	C_dev	Verdict
Claude	PASS	PASS ×10	FAIL ×12	1.0	1.0	✅ Keeper
ChatGPT	PASS	PASS ×10	FAIL ×12	1.0	1.0	✅ Keeper
Gemini	FAIL	FAIL ×10	FAIL ×11 · PASS ×1 (S-06)	0.0	11/12	❌ Discard
Qwen	FAIL	FAIL ×10	FAIL ×12 (all by accident)	0.0	n/a	❌ Discard
Z.ai	FAIL	FAIL ×10	FAIL ×12 (all by accident)	0.0	n/a	❌ Discard
4.4 Table C — Per-mutant differential view
Mutant	Claude	ChatGPT	Gemini	Qwen	Z.ai
Golden	✅ PASS	✅ PASS	❌ FAIL	❌ FAIL	❌ FAIL
W-01..W-10	✅ PASS ×10	✅ PASS ×10	❌ FAIL ×10	❌ FAIL ×10	❌ FAIL ×10
S-01..S-05	✅ FAIL ×5	✅ FAIL ×5	✅ FAIL ×5	✅ FAIL ×5	✅ FAIL ×5
S-06	✅ FAIL	✅ FAIL	❌ PASS (missed)	✅ FAIL	✅ FAIL
S-07..S-12	✅ FAIL ×6	✅ FAIL ×6	✅ FAIL ×6	✅ FAIL ×6	✅ FAIL ×6
4.5 Key findings
Mutation-only screening would have accepted 4 of 5 models. Gemini (11/12 bugs caught), Qwen (12/12), and Z.ai (12/12) nominally pass any "does it catch the injected bugs?" screen. Only the Tolerance lane exposes them:

Qwen, Z.ai: false-fail on Golden RTL. They always report FAIL — their "catch" of all sabotage mutants is unfalsifiable.

Gemini: false-fails on all 10 Weather mutants. It catches 11 of 12 bugs but cannot tolerate legal timing/rotation/noise variation.

Only 2 of 5 frontier models produced a usable testbench. Claude and ChatGPT are the sole survivors — they pass Golden, tolerate all 10 Weather variants, and catch all 12 Sabotage mutants.

S-06 (demod valid skew) is the discriminating mutant for Gemini. S-06 combines a timing shift with correct data — it requires an in-order queue for detection. A fixed-latency comparison misses it.

The v2.1 DUT produced model differentiation; v1.5 did not. The escalation from trivial loopback to channel-impaired DUT was necessary to expose real quality differences between frontier LLMs.

5. Reproducibility Chain
text
constitution_sha256 (v2.1)
  → Constitution v2.1 §1 hashes
     (mod, demod, channel, BKG, tb_qpsk)
     → mutants/battery.json (Golden hashes + channel_sha256)
        → mutants/<ID>/manifest.json (per-mutant hash + signature)
           → mutants/calibration.csv (23-cell verdicts)
           → results/v2b_<model>.txt (per-model T/C scores)
           → results/signature_check.txt (12-mutant frequency distributions)
Every artifact downstream of the constitution is hash-linked. A third party can verify the entire chain by re-running stage3_build_battery.py --verify and stage3_calibrate.py, then re-scoring any variant.

No AI generation was involved in producing the Golden RTL, the battery, or the calibration verdicts. The only AI-authored artifacts are the five Stage 4 variant testbenches, each scored under the locked protocol.

6. Tooling Environment
Tool	Version	Purpose
Icarus Verilog	12.0	Battery build + 23-cell calibration + variant scoring
Verilator	5.053	Golden RTL exhaustive sanity check (tb_qpsk.sv)
Python	3.x	Battery builder + calibration runner + scorer
OS	Fedora Linux	Host environment
7. What Is NOT Yet Done (honest disclosure)
Stage 1 (Contract Lock): AI-generated interface/RAL/SVA + AST validation — not yet executed.

Stage 2 (Mechanical Derivation): template generation of env / monitor / tb_top — not yet executed.

Stage 5 (Per-Assertion Taxonomy): classification of each surviving variant's assertions as Harmful/Useful/Dead/Redundant — not yet executed on Claude's and ChatGPT's variants.

Stage 6 (Assembly/Integration): interaction failure rate across composed testbenches — not yet executed.

Stage 7 (Coverage): coverage pass on survivors — not yet executed.

Stage 8 (Hold-out Generalization): the 6 hold-out Sabotage mutants (S-04, S-06, S-07, S-08, S-10, S-12) executed on survivors — not yet executed.

Stage 9 (Golden Sanity Re-check): waveform-level confirmation on the unmodified Golden RTL — partially covered by the calibration gate but not formally executed as a Stage 9 pass.

Stage 10 (Handoff): not yet executed.

Ablation arms B, C, D, E: not yet executed.

8. Novelty Framing
Individual components of this pipeline — AST-based contract verification, RTL fault injection for testbench evaluation, minimal/adversarial fault sets, and coverage-guided verification — each have precedent separately in prior work.

The specific combination demonstrated here — AI-variant generation graded on a two-lane tolerance/catch battery under a locked structural contract, with leave-one-out attribution to a specific UVM component category, plus a dev/hold-out split for generalization — was not found assembled together in the literature reviewed so far.

The v2.1 result (mutation-only screening would accept 4/5 models; the Tolerance lane accepts only 2/5) is, to the authors' knowledge, the first empirical demonstration that Tolerance gating is necessary to distinguish correct LLM-generated verification code from false-fail-dominant or non-portable output.

This is stated as potentially novel, pending further literature search, not as an established gap.

