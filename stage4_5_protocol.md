# STAGE4_5_PROTOCOL — Sync Hub Protocol / QPSK v2 DUT

protocol_sha256: <FILL — sha256sum of this file after every other field is set, then freeze>

Post-freeze edits invalidate Stages 4-5. Same rule as Constitution §11.

---

## 0. Scope & Freeze Rule

Governs Stage 4 (AI variant generation) and Stage 5 (triad scoring) ONLY.
Stages 6-10 keep their definitions from Constitution v2.1.

This document MUST be frozen (hashed) before the first Stage 4 generation
chat. Any rule change after results are seen invalidates the affected
stage. No rule on this page may be edited after the first Stage-5 number
exists (§10).

---

## 1. References (per Constitution §12 chain)

- CONSTITUTION v2.1
  sha256 `6fbd46a0b33138337473660979d4f5d2b0bd8789d3766af3ebc815dddedb3ab5`
  (FROZEN)
- Stage 1 contract manifest: `contract/contract_manifest.json`
  - `interface.sv`      `4b9c382628c0769710916567b3b633ccac3f19086cf2b2f26f6ed1c3a5455034`
  - `qpsk_seq_item.sv`  `cb70c30085a5f81c1697652f225c69cc8c6ebd040c2bc97872c30a25f9a2babd`
  - `qpsk_sva.sv`       `8ae6211b7feb759b5fa088fb560b9cfc5831c1530aedda99d19108eb3124559c`
- UVM harness certification: `results/uvm_bkg_sweep.txt`
  - 23 cells × 5 seeds = 115/115 correct verdicts, post-Fix#1 and post-Fix#2.
  - **Fix#1**: `uvm_analysis_imp_decl` macros moved into `tb/uvm/qpsk_pkg.sv`
    before the includes, so `qpsk_scoreboard` sees them at parse time.
  - **Fix#2**: `tb/uvm/qpsk_tb_top.sv` routes `ch_seed` at t=0 via
    `uvm_config_db#(bit[31:0])::set(...)` before `run_test()`, so the driver's
    `build_phase` fetch is guaranteed to succeed on first evaluation.
  - **Fix#3** (prompt-level, pre-generation): the token `expect` is
    FORBIDDEN in model output — `expect` is a SystemVerilog keyword. §4.1
    enforces this at ingestion.

- `bkg_signature` — per-cell BKG error counts from the certified sweep
  (deterministic fingerprint reference for Stage 5 blame attribution):

  | cell | BKG errors |
  |---|---|
  | `golden` | 0 |
  | `W-01` … `W-10` | 0 |
  | `S-01` | 10 |
  | `S-02` | 10 |
  | `S-03` | 40 |
  | `S-05` | 31 |
  | `S-09` | 40 |
  | `S-11` | 31 |
  | `S-04, S-06, S-07, S-08, S-10, S-12` | **SEALED until Stage 8** |

  A Stage-4/5 triad whose per-cell error count on a DEV Sabotage cell
  diverges from this fingerprint is flagged for review.

---

## 2. Naming & Manifest

File naming: `qpsk_(drv|seq|sb)_(cg|qw|gm)_(0[1-5]).sv`

- categories: `drv`, `seq`, `sb`
- models: `cg` (ChatGPT), `qw` (Qwen), `gm` (Gemini)
- versions: `01`–`05`, zero-padded
- version index = GENERATION INDEX, never a quality rank

Layout:
uvm_variants/
├── cg/ qpsk_drv_cg_01.sv … qpsk_drv_cg_05.sv
│ qpsk_seq_cg_01.sv … qpsk_seq_cg_05.sv
│ qpsk_sb_cg_01.sv … qpsk_sb_cg_05.sv
├── qw/ (same 15)
└── gm/ (same 15)

text

`uvm_variants/variants_manifest.json` schema (per file):
filename string e.g. "qpsk_drv_cg_03.sv"
model enum "cg" | "qw" | "gm"
category enum "drv" | "seq" | "sb"
version int 1..5
style_seed_id string "S1".."S5"
base_prompt_sha256 hex
style_line_sha256 hex
chat_date string ISO-8601
re_asks int 0 or 1
raw_output_sha256 hex
ingested_file_sha256 hex
dedup_class string "unique" | "duplicate_of:<v>" | "ineligible:<reason>"
triads list triad ids this file participates in
compile_status enum "ok" | "fail" | "not_attempted"
notes string

text

Prompt files live in `prompts/`:

- `prompts/drv_base.txt`
- `prompts/seq_base.txt`
- `prompts/sb_base.txt`
- `prompts/style_drv_v01.txt` … `style_drv_v05.txt`
- `prompts/style_seq_v01.txt` … `style_seq_v05.txt`
- `prompts/style_sb_v01.txt`  … `style_sb_v05.txt`

`sha256` of every prompt file recorded at generation time. Base prompts
are IDENTICAL across all three models (fairness rule).

---

## 3. Control Group (already collected, retained)

`control/qpsk_drv_cg_unseeded_v1..v5.sv` — 5 ChatGPT chats, no style seed.

Finding: 5 raw outputs → 2 normalized classes (A: v1/v3/v4, B: v2/v5) → 1
functional class. Reported in the paper as the unseeded-diversity control.
Not scored; not in the manifest's scored pool.

---

## 4. Generation Protocol

3 models (ChatGPT, Qwen, Gemini — all free tier, no temperature control).

- **15 chats per model**: 5 drv + 5 seq + 5 sb.
- ONE file per chat. Fresh chat per file (same-chat regeneration produces
  correlated outputs).
- Each chat receives: base prompt + ONE style requirement, verbatim from
  the frozen prompt files.
- All three models receive IDENTICAL prompt text.
- **Re-ask policy**: at most ONE re-ask per chat, and ONLY for formatting
  violations (missing/extra fences, markdown leakage). Count in `re_asks`.
  No re-ask for content quality.
- **Save EVERY raw output**, including failures. No regeneration because
  an output "looks same-y" or "looks bad". Style seeds are the diversity
  mechanism; outcome-based re-rolling is **prohibited**
  (selection-on-outcome bias).

### 4.1 Ingestion lint (deterministic, pre-compile)

- **Fence strip**: remove ``` fences and a leading language tag if
  present. This is the ONLY permitted edit to model output.
- **Forbidden tokens** — any hit → INELIGIBLE (recorded; never hand-fixed):
  - line-start ```
  - `^module`
  - `^package`
  - `import uvm_pkg`
  - `` `include "uvm_macros.svh" ``
  - **the identifier `expect`** (reserved SystemVerilog keyword)
  - any `$display` outside the scoreboard `[RESULT]` rule

INELIGIBLE == compile-failure equivalent: `T=0`, `C_dev=0` for any triad
containing it (Constitution §5 variant-compile rule). Not retried.

### 4.2 Dedup ladder (within model+category)

1. **raw hash** — exact bytes
2. **normalized hash** — strip comments and blank lines, collapse whitespace
3. **functional class** — = normalized hash

Duplicates (same normalized hash within a model+category): keep the LOWEST
version index as representative; others marked `duplicate_of` and
**excluded from triad pools**. Cross-model duplicates are allowed and
reported (they are a diversity finding, not an error).

If a model's category pool shrinks below 2 functional variants, swaps for
that category are skipped and shrinkage is reported as a result.

---

## 5. HOLD-OUT FIREWALL (most important rule in this file)

Per Constitution §8, hold-out bugs are executed ONLY at Stage 8.

Therefore ALL Stage 4-5 sweeps use the **17-cell matrix**:
golden
W-01_mod_latency_plus1
W-02_demod_latency_plus1
W-03_mod_idle_zero
W-04_demod_idle_zero
W-05_mod_reset_late
W-06_demod_reset_late
W-07_ch_noise_doubled
W-08_ch_rotation_doubled
W-09_ch_latency_plus1
W-10_ch_idle_zero
S-01_const_sym10_i
S-02_const_sym01_q
S-03_slice_invert_i
S-05_mod_valid_gate
S-09_ch_q_inversion
S-11_ch_noise_overload

text

**SEALED until Stage 8** (physically excluded from Stage 4-5 runner):
`S-04, S-06, S-07, S-08, S-10, S-12`

The runner script must physically exclude the sealed cells and log the
exclusion. Running a sealed cell in Stage 4-5 invalidates Stage 8 for that
triad (its `C_holdout` would be tainted). Way-3 appendix (if run) obeys
the same 17-cell cap.

---

## 6. Triads

### 6.1 Way 1 — same-model triads (selection input)

Per model: `(drv_vN, seq_vN, sb_vN)` for each functional version index N.
Max 5 per model, 15 total. Pool indices come from post-dedup
representatives (§4.2).

### 6.2 Way-2 baseline selection rule (LOCKED before any run)

Per model, rank the Way-1 triads by, in order:

1. **`C_dev` descending** (0–6 DEV bugs caught)
2. **`T` descending** (tiebreak)
3. **lowest sum of version indices** (final deterministic tiebreak)

Inputs: `T` and `C_dev` ONLY. `C_holdout` must NEVER touch this selection
(§8). Selects the Way-2 BASELINE only; does NOT grant survivorship.

### 6.3 Way 2 — leave-one-out swaps

Baseline `B_M` = Way-2 winner per model from §6.2.

For each category `c` in `{drv, seq, sb}`: replace that ONE slot in `B_M`
with each other functional version of the same model+category (up to 4
swaps per category).

Max 12 triads per model, 36 total (fewer if dedup shrank pools).

Way-2 outputs feed:
- component attribution (which category swaps help/hurt)
- Stage 6 assembly

Scored into the same quadrant system as Way 1.

### 6.4 Way 3 — cross-model: CUT from the scored pipeline

Optional observational appendix ONLY. Exactly 3 rotations:
(cg.drv + qw.seq + gm.sb)
(qw.drv + gm.seq + cg.sb)
(gm.drv + cg.seq + qw.sb)

text

17 cells × seed 42 only. Results are reported as appendix observations,
**NEVER** used in T/C tables, selection, or Stage 6+.

Rationale (locked): no downstream consumer; capped to prevent compute creep.

---

## 7. Execution

ONE compiled binary per triad via the merged-DUT wrapper (all 17 DUT
variants inside, `+CELL=` runtime select). **51 binaries total**
(15 Way-1 + 36 Way-2), compiled in parallel.

- **Compile gate**: triad compile failure → `T=0`, `C_dev=0` recorded, NOT
  retried (Constitution §5). No source-level fixes to AI files, ever.
- **Run matrix per triad**: 17 cells × 5 LOCKED_SEEDS = **85 runs**.
  FULL matrix for every triad (official measurement; no early exit).
- **Sim invocation**:
  `./.uvm_smoke/Vqpsk_tb_top +UVM_TESTNAME=qpsk_base_test +CHSEED=<s> +SVSEED=<s> +CELL=<cell>`
- **Budget**: 51 × 85 = **4,335 sims** + 51 compiles.

**Verdict per run**:
- `FAIL` iff `[RESULT]` line contains `FAIL`, OR any `UVM_ERROR` report in
  the log, OR `[RESULT]` missing without an infrastructure fault.
- `PASS` iff `[RESULT] PASS` AND zero `UVM_ERROR` reports.
- `INVALID` iff infra fault (crash/OOM/IO/wall-clock) → retry ONCE, per
  seed (Constitution §5). Missing `[RESULT]` with no infra fault = `FAIL`
  (variant defect).

Also log per run: `error_count`, `first_mismatch_index`, cell fingerprint
(compare against `bkg_signature` for Stage-5 blame attribution).

---

## 8. Scoring (Constitution v2.1 §6 — restated for these runs)

- `Catch(triad, bug) = FAIL on ≥ 3 of 5 LOCKED_SEEDS`
- `FalseFail(run) = FAIL with cell in {golden} ∪ {W-01..W-10}`
- `T(triad)        = 1 - falseFail_runs / 55` (11 cells × 5 seeds)
- `C_dev(triad)    = caught / 6` (DEV = S-01, S-02, S-03, S-05, S-09, S-11)

**Quadrants** (threshold = §6 gates themselves):

| Quadrant | Condition | Action |
|---|---|---|
| Q1 SURVIVOR | `T = 1.0` and `C_dev = 1.0` | keep; feeds Stage 6 |
| Q2 BLIND    | `T = 1.0` and `C_dev < 1.0` | false-alarm-free but deaf |
| Q3 FRAGILE  | `T < 1.0` and `C_dev = 1.0` | catches but cries wolf |
| Q4 DEAD     | `T < 1.0` and `C_dev < 1.0` | discard |

Survivor gate has NO partial credit.

- **Per-assertion taxonomy** (§10): N/A for this DUT generation — Stage 4
  triads contain no AI-authored SVA. Recorded as N/A, not silently skipped.
- `C_holdout` is NOT computed in Stage 5. Stage 8 computes it, append-only.

---

## 9. Outputs

- `results/stage5_runs.csv` — `(triad, cell, seed, verdict, error_count, fingerprint)`
- `results/stage5_scores.csv` — `(triad, way, model, T, C_dev, quadrant)`
- `results/diversity_table.csv` — per model: raw → normalized → functional counts
- `results/way2_attribution.csv` — per-category swap deltas vs baseline
- `uvm_variants/variants_manifest.json` — §2 fields, incl. compile failures + re_asks
- **Stage 6 handoff**: Q1 survivor list + Way-2 per-category best components.

---

## 10. Anti-Vibes Clauses

- No rule on this page may be edited after the first Stage-5 number exists.
- A rule discovered to be broken mid-run (e.g. a sealed cell executed) is
  reported, not patched quietly; affected results are invalidated per §5.
- Every re-ask, retry, duplicate, and ineligibility is DATA and gets
  reported.
- Selection-on-outcome is prohibited: style seeds, not post-hoc re-rolling,
  produce diversity.

---

## 11. Pre-Freeze Checklist

All boxes must be `[x]` before hashing this document.

- [ ] Prompt files saved + hashed (15 base + 15 style blocks; base text
      identical across the three models)
- [ ] 17-cell runner excludes sealed cells (verified by reading the script)
- [ ] Merged-DUT wrapper regenerated for **17** cells and spot-checked vs
      the battery calibration
- [ ] `results/uvm_bkg_sweep.txt` (post-Fix#1/#2) archived as
      `bkg_signature` reference
- [ ] `uvm_variants/variants_manifest.json` schema present (empty is fine)
- [ ] `prompts/` directory populated with all 6 base + 15 style files
- [ ] This file hashed and frozen (`protocol_sha256` filled at top)


---

## 13. BATCH 2 — NAIVE-PROMPT ABLATION (pre-registered)

**Purpose.** Ablation D of the pipeline doc. Measures testbench quality
with the pipeline's accumulated constraint wisdom REMOVED. Batch-1
results are FINAL; batch-2 is never merged into batch-1 tables —
reported side-by-side only.

**Frozen before first batch-2 chat.** The three prompts below are the
complete prompt text sent to each model. Their sha256 hashes are
recorded in `prompts/prompts_b2/hashes.txt`.

6ae3aa96746f6667907b6dfbb30572169bc52b63f2b09cd88ea7d87850fba946 drv_naive.txt
70faf4ee543fa09ffddc7041f08beeb2002453859a20ea4e4a361f04f224ec2e sb_naive.txt
9a3a57ff428de948cb2029914abe91fbdb8658308b59ef94cc9bc8ce0ff4684e seq_naive.txt


### 13.1 Regime

Prompts contain ONLY:
- Frozen contract artifacts (interface + seq_item) — mechanical
- Class names, endclass, no module/package/import constraints — compile contract
- "10 of each, 40 items" — §3 stimulus envelope
- `[RESULT] PASS` / `[RESULT] FAIL errors=N` verdict channel — scoring contract
- Structural signatures (`write_expected`, `write_observed`, `ap_expected`)

Prompts contain NO:
- Style seeds
- Verilator quirk warnings (declaration-at-top, backtick reminders, `expect` keyword)
- Algorithmic hints ("observed equals driven", "checks in order", "in drive order")
- Reset-handling algorithm
- `uvm_component_utils` / `uvm_object_utils` reminders

### 13.2 Generation

3 models × 3 categories × 5 chats = 45 raw files
Deviation note: cg (ChatGPT) and qw (Qwen) became unavailable due to
anti-bot verification walls before any batch-2 chat was fired.
Substituted with pp (Perplexity) and km (Kimi) — both English-language
general-purpose models. Substitution executed pre-generation.
Paths:

uvm_variants_b2/{cg,qw,gm}/qpsk_(drv|seq|sb)<m><NN>.sv


### 13.3 Repair loop ("compile-fix only")

Per file: max 3 repair rounds.

Trigger = ingest INELIGIBLE (violation list) OR compile error
(verbatim `build.log`).

**Human is a courier.** Paste violation/error into the same chat, copy
AI's reply, save as `<name>_fix1.sv`. Never edit a character.

Intermediates `*_fixN.sv` are ignored by the ingest regex.
Final version takes the canonical filename. `fix_count` recorded in
`variants_manifest_b2.json`.

Still failing after 3 rounds → recorded INELIGIBLE, scored T=0 / C=0.

### 13.4 Scoring

Identical semantics to batch 1 (Constitution v2.1 §6):
17 active cells × 5 LOCKED_SEEDS, T / C_dev / quadrant.
Sealed cells (S-04, S-06, S-07, S-08, S-10, S-12) remain sealed.

Runner: `stage5_runner_b2.py`. Outputs under `results/b2/`.

### 13.5 Pre-registered predictions (falsifiable)

- **P1 — Diversity collapse.** Batch-2 normalized-hash diversity within
  each model+category will be lower than batch 1, matching the
  unseeded-control precedent (§3 of this protocol).
- **P2 — Higher compile-fail rate.** Without Verilator-quirk warnings,
  more batch-2 triads fail compilation than batch 1.
- **P3 — Q2 and/or Q4 populated.** Without the scoreboard prompt's
  algorithmic hint, at least one batch-2 triad scores Q2_BLIND
  (T=1, C_dev<1) or Q4_DEAD (T<1, C_dev<1).

If a prediction fails, it is reported as a failed prediction, not
silently amended.

### 13.6 Paths

uvm_variants_b2/ raw AI output
stage4/ingested_b2/variants/ fence-stripped + linted
variants_manifest_b2.json separate manifest
results/b2/ ingest log, diversity, scores
results/b2/stage5_runs.csv
results/b2/stage5_scores.csv
results/b2/way2_attribution.csv
stage5_work_b2/ per-triad build/run logs


Batch-1 artifacts are NEVER touched by batch-2 code paths.

### 13.7 Downstream

Batch-2 Q1 triads join the Stage-8 hold-out evaluation list alongside
batch-1 Q1 survivors (§12.2). Sealed cells remain unseen by any batch-2
run. If Stage-8 evaluation is executed before batch-2 completes, batch-2
Q1 triads are evaluated in a separate, append-only Stage-8b pass.

### 13.8 Change control

No rule in §13 may be edited after the first batch-2 chat is opened.
Append-only.
