> **POST-ERRATA NOTICE (2026-09-15).** Certain numbers in this
> document are superseded by `errata_v1.md`. Specifically: catch
> semantics (v2), Stage 8 scope (9 → 26 survivors), Weather lane
> attribution (0 unique kills), Qwen reclassification (structural
> malformation, not just backtick-drop), and AER numbers. See
> `errata_v1.md` for the corrected claims. This document is preserved
> as the frozen historical record; errata is the source of truth for
> any number cited in the paper.

---

# Stage 5 — Final Results (Way-1 + Way-2)

**Project:** Sync Hub Protocol — Screening LLM-Generated UVM Testbenches
**DUT:** QPSK Modulator + Channel + QPSK Demodulator (Golden RTL v2)
**Constitution:** v2.1 (frozen)
**Protocol:** `STAGE4_5_PROTOCOL.md` (frozen)
**Runner:** `stage5_runner.py` + `stage5_reclassify.py`
**Status:** FROZEN
**Date:** 2026-09-14

---

## 1. Scope

Stage 5 scored 45 AI-generated UVM variants (15 ChatGPT `cg`, 15 Qwen
`qw`, 15 Gemini `gm`) as triads against the 17-cell Stage 4-5 matrix
(11 Golden+Weather cells + 6 DEV Sabotage cells) × 5 LOCKED_SEEDS.

Per protocol §5, the 6 hold-out Sabotage cells
(`S-04, S-06, S-07, S-08, S-10, S-12`) were sealed. The runner asserts
this at startup (`stage5_runner.py` line ~90).

- **Way-1:** 15 same-model triads (matched version indices)
- **Way-2:** leave-one-out swaps from each model's Way-1 baseline
  (baselines selected per §6.2: `C_dev` desc → `T` desc → version-sum asc)

---

## 2. Scoring Correction Applied Retroactively

The original runner classified any `FAIL` as a catch. Reason-aware
semantics require the fail to come from an actual evaluation:
`reason ∈ {result_fail, uvm_error_in_pass}`. A sim that dies at t=0
with `no_result` never evaluated the DUT — it caught nothing.

`stage5_reclassify.py` re-derives T/C_dev from
`stage5_runs.csv` with corrected catch semantics and adds a new
`RUNTIME_CRASH` quadrant for triads whose every run is `no_result`.

**Root cause evidence** (`results/cgv01_diagnostic_FROZEN.log`):

UVM_FATAL @ 0: uvm_test_top.env.agent.seqr@@seq [NULLITM]
attempting to start a null item from sequence
'uvm_test_top.env.agent.seqr.seq'
%Error: tb/uvm/qpsk_seq.sv:26: Null pointer dereferenced


`cg_seq_cg_01.sv` declares `qpsk_seq_item req;` at module scope but
never calls `type_id::create()`. `start_item(req)` passes a null handle
and aborts before any valid_in is driven. Every cell returns
`no_result`. Six triads previously mislabeled `Q3_FRAGILE` are
reclassified `RUNTIME_CRASH`.

---

## 3. Way-1 Results (corrected)

| Triad | Model | T | C_dev | Quadrant |
|---|---|---|---|---|
| cg_v01 | cg | 0.0000 | 0.0000 | RUNTIME_CRASH |
| cg_v02 | cg | 0.0000 | 0.0000 | RUNTIME_CRASH |
| cg_v03 | cg | 0.0000 | 0.0000 | RUNTIME_CRASH |
| **cg_v04** | cg | **1.0000** | **1.0000** | **Q1_SURVIVOR** |
| **cg_v05** | cg | **1.0000** | **1.0000** | **Q1_SURVIVOR** |
| qw_v01 | qw | 0.0000 | 0.0000 | COMPILE_FAIL |
| qw_v02 | qw | 0.0000 | 0.0000 | COMPILE_FAIL |
| qw_v03 | qw | 0.0000 | 0.0000 | COMPILE_FAIL |
| qw_v04 | qw | 0.0000 | 0.0000 | COMPILE_FAIL |
| qw_v05 | qw | 0.0000 | 0.0000 | COMPILE_FAIL |
| gm_v01 | gm | 0.0000 | 0.0000 | RUNTIME_CRASH |
| gm_v02 | gm | 0.0000 | 0.0000 | RUNTIME_CRASH |
| **gm_v03** | gm | **1.0000** | **1.0000** | **Q1_SURVIVOR** |
| gm_v04 | gm | 0.0000 | 1.0000 | Q3_FRAGILE |
| gm_v05 | gm | 0.0000 | 0.0000 | RUNTIME_CRASH |

**Totals:** 3 Q1_SURVIVOR, 1 Q3_FRAGILE, 6 RUNTIME_CRASH, 5 COMPILE_FAIL.

---

## 4. Way-2 Results (corrected)

Baselines selected per §6.2:
- `cg`: baseline `cg_v04` (only Way-1 Q1 with version-sum 12)
- `gm`: baseline `gm_v03` (only Way-1 Q1)
- `qw`: no baseline (all Way-1 COMPILE_FAIL)

| Swap id | Model | Category | Swap v | Quadrant |
|---|---|---|---|---|
| cg_w2_drv01 | cg | drv | 01 | Q1_SURVIVOR |
| cg_w2_drv02 | cg | drv | 02 | Q1_SURVIVOR |
| cg_w2_drv03 | cg | drv | 03 | Q1_SURVIVOR |
| cg_w2_drv05 | cg | drv | 05 | Q1_SURVIVOR |
| cg_w2_seq01 | cg | seq | 01 | RUNTIME_CRASH |
| cg_w2_seq02 | cg | seq | 02 | RUNTIME_CRASH |
| cg_w2_seq03 | cg | seq | 03 | RUNTIME_CRASH |
| cg_w2_seq05 | cg | seq | 05 | Q1_SURVIVOR |
| cg_w2_sb01 | cg | sb | 01 | Q1_SURVIVOR |
| cg_w2_sb02 | cg | sb | 02 | Q1_SURVIVOR |
| cg_w2_sb03 | cg | sb | 03 | Q1_SURVIVOR |
| cg_w2_sb05 | cg | sb | 05 | Q1_SURVIVOR |
| gm_w2_drv01 | gm | drv | 01 | Q1_SURVIVOR |
| gm_w2_drv02 | gm | drv | 02 | Q1_SURVIVOR |
| gm_w2_drv04 | gm | drv | 04 | Q1_SURVIVOR |
| gm_w2_drv05 | gm | drv | 05 | Q1_SURVIVOR |
| gm_w2_seq01 | gm | seq | 01 | RUNTIME_CRASH |
| gm_w2_seq02 | gm | seq | 02 | RUNTIME_CRASH |
| gm_w2_seq04 | gm | seq | 04 | Q1_SURVIVOR |
| gm_w2_seq05 | gm | seq | 05 | RUNTIME_CRASH |
| gm_w2_sb01 | gm | sb | 01 | Q1_SURVIVOR |
| gm_w2_sb02 | gm | sb | 02 | Q1_SURVIVOR |
| gm_w2_sb04 | gm | sb | 04 | Q3_FRAGILE |
| gm_w2_sb05 | gm | sb | 05 | Q1_SURVIVOR |

**Way-2 totals:** 17 Q1_SURVIVOR, 1 Q3_FRAGILE, 6 RUNTIME_CRASH.

### Component attribution

| Category | Swaps | Preserved Q1 | Broke to Q3 | RUNTIME_CRASH |
|---|---|---|---|---|
| drv | 8 | 8 | 0 | 0 |
| seq | 8 | 2 | 0 | 6 |
| sb | 8 | 7 | 1 | 0 |

**Finding:** The sequence is the fault-carrier. All 6 sequence swaps
that introduced a non-baseline sequence either crashed (5) or stayed Q1
(1); driver and scoreboard swaps preserve Q1 in 15/16 cases.

---

## 5. Failure Taxonomy — Three Distinct Modes Across Three Models

| Model | Q1 | Q3 | RUNTIME_CRASH | COMPILE_FAIL |
|---|---|---|---|---|
| ChatGPT | 2 / 5 | 0 | 3 / 5 | 0 |
| Qwen | 0 | 0 | 0 | **5 / 5** |
| Gemini | 1 / 5 | 1 / 5 | 3 / 5 | 0 |

### Mode A — Qwen: COMPILE_FAIL (5/5)

Repair-loop-free raw output from Qwen failed elaboration on all 15
variants. Failure classes (from `stage5_work/qw_v0*/build.log`):

- **4/5 driver files**: missing backtick before UVM macros.
  `uvm_fatal(...)` instead of `` `uvm_fatal(...) ``. The frozen prompt
  displayed the backtick verbatim; Qwen dropped it.
- **1/5 driver files**: structurally truncated output. Missing
  `endclass` / stray `endtask` / `endfunction`.
- **1/5 scoreboard files**: same missing-backtick defect on `uvm_error`.

**Classification:** systematic toolchain-portability failure, not
stochastic. The Qwen variants produced valid ingest-eligible text
(0 forbidden-token hits) but failed to compile. Reported, not retried,
per protocol §7.

### Mode B — ChatGPT & Gemini: RUNTIME_CRASH (6/15)

Two independent models produced the same failure: sequence files
declare `qpsk_seq_item req;` but never call `type_id::create("req")`.
`start_item(req)` passes null → `UVM_FATAL [NULLITM]` at t=0 → sim dies
before driving any stimulus. Every cell returns `no_result`.

This is a **runtime integration defect**, not a tolerance failure. It
only manifests when the sequence is actually executed, which the
ingest lint (fence-strip + forbidden tokens + class-name check) cannot
detect statically. The variant is technically compile-clean.

### Mode C — Gemini `gm_v04` / `gm_w2_sb04`: Q3_FRAGILE (1–2/15)

The only **genuine tolerance rejection** in Stage 5. `gm_v04` runs to
completion, prints `[RESULT] FAIL errors=N` on every cell, but the
error counts are reproducible and cell-dependent:

| Cell | gm_v04 errors (all 5 seeds) |
|---|---|
| Golden | 20 |
| W-01..W-10 | 20 each |
| S-01 | 10 |
| S-02 | 30 |
| S-03 | 20 |
| S-05 | 41 |
| S-09 | 40 |
| S-11 | 26–33 (spread) |

Golden erroring at 20 is a false alarm (Golden is correct). S-01
erroring at *fewer* than Golden is the tell: the triad isn't catching
bugs, it's generating a constant background of false signals that
happens to fire on every cell. C_dev = 1.0 is coincidental.

**Classification:** the tolerance gate's single legitimate kill in
Stage 5. Mutation-only screening would have accepted `gm_v04` because
it "catches" all DEV bugs (by firing on everything).

---

## 6. Q2 (Robust but Deaf) Is Empty — Behavioral, Not Structural

Zero triads scored Q2 (T=1.0, C_dev<1.0).

**Q2 is reachable on this DUT.** A scoreboard that counts
`valid_out` pulses without inspecting `bits_out` would:
- PASS Golden (40 valids) and all 10 Weather cells (latency shifts
  don't change pulse count) → T = 1.0
- PASS S-01, S-02, S-03, S-09, S-11, S-12 (all preserve count at 40)
- FAIL S-05 (count drops to 20) → C_dev = 1/6

That triad would be Q2_BLIND. The DUT does not prevent it.

**Why Q2 stayed empty:** the scoreboard prompt explicitly states
"Slice margins (≥116 LSB) dwarf the noise, so for a CORRECT DUT:
input symbol == output symbol." Every model that produced a compiling
scoreboard wrote a positional bit-comparison checker. None wrote a
weaker proxy.

**Consequence:** under a spec that hands the model the DUT's
transparency assumption, LLMs over-check rather than under-check. The
naive concern that "LLMs write permissive checkers" is not what
happened. **Batch-2 ablation (§13, in progress) tests this directly**
by removing the algorithmic hint from the scoreboard prompt.

---

## 7. Q3 vs. RUNTIME_CRASH — Why the Distinction Matters

The original classifier merged the two, producing "7 Q3_FRAGILE" and
overstating the tolerance-lane's productivity. The corrected count is
**1 Q3_FRAGILE** (`gm_v04`).

The other six previously-labelled-Q3 triads are all t=0 crashes. Their
`C_dev = 1.0` in the original classifier was an artifact of counting
`FAIL+no_result` as a Sabotage catch. That is a scoring bug, not a
result.

The paper's tolerance-gate claim becomes: **mutation-only screening
accepts 7 of 15 Way-1 triads; the tolerance lane rejects 4 of them**
(1 Q3_FRAGILE, 3 RUNTIME_CRASH). RUNTIME_CRASH is not a tolerance
failure — it's a pre-stimulus defect. The tolerance lane's *unique*
kill is `gm_v04`. Reported as a single strong exemplar, not a rate.

---

## 8. Frozen Artifact Hashes
6401a136bfd04006752038c393a2f28bde435bdd0c7af1a92d5e860c74fccae4 results/stage5_runs.csv
070e7464de199292862ee018084e29598f5901415c90cfa439e94784bb60c34f results/stage5_scores.csv
070e7464de199292862ee018084e29598f5901415c90cfa439e94784bb60c34f results/stage5_scores_FROZEN.csv
adf0411171946834af9fa1836fde71b82a08f36ffd232396926dffe0c4d8884b results/way2_attribution.csv
1fd359d3e8e322a545c34b3ddefc17ef3c8d26fe4a54ee7aa75fb2247c21845e results/diversity_table.csv
e7dcf8cae2bc51cc115e0a730c9cc71183744cf106c587b6e1a0ef83140de496 results/stage4_ingest.csv
8eaf77262b3735b5cf39c5a98cc745adfdf6368b724ccafb27fbe33cd17bf8cd results/cgv01_diagnostic_FROZEN.log
ad14ae28feae97a6c14e0c881889a67d6146adef0095a05907ca5e4fbb7ba476 variants_manifest.json


Auxiliary artifacts referenced in this document:

- `stage5_runner.py`, `stage5_reclassify.py`, `stage4_ingest_lint.py`,
  `patch_driver_macro.py`
- `stage5_work/{triad}/build.log` — per-triad compile logs
- `stage5_work/qw_v0*/build.log` — Qwen COMPILE_FAIL root causes
- `stage5_work/bkg_backup/` — BKG driver/seq/scoreboard backups

---

## 9. Reproduction

```bash
# 1. Ingest + dedup + manifest (idempotent)
python3 stage4_ingest_lint.py

# 2. Fix driver registration-macro omissions (6 files)
python3 patch_driver_macro.py

# 3. Way-1 + Way-2 scoring
python3 stage5_runner.py

# 4. Reason-aware reclassification
python3 stage5_reclassify.py

# 5. View the frozen table
column -t -s, results/stage5_scores.csv