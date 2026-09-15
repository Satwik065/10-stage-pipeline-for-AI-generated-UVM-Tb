# Errata v1 — Post-Audit Corrections

**Status:** FROZEN
**Date:** 2026-09-15
**Supersedes:** Specific claims in `stage5_final.md`, `stage5_b2.md`,
`ablation_B.md`, `ablation_C.md`, `experiment_flowchart.md`, and
`stage8.md`.
**Does NOT modify:** any frozen result CSV, any git tag, any Stage 1-10
artifact. Frozen data is preserved; this document corrects how it is
interpreted.

---

## Summary of Corrections

| # | Issue | Old claim | Corrected |
|---|---|---|---|
| 1 | Catch semantics v2 | `C_dev = caught/6` where a FAIL on Sabotage counts | `Catch = FAIL mutant ∧ PASS Golden ∧ PASS Weather` |
| 2 | Stage 8 scope | "9 Q1 survivors generalize" | "26 Q1 survivors generalize" (Stage 8b) |
| 3 | Qwen reclassification | "5/5 backtick-drop" | "5/5 structurally malformed" (backtick + orphaned blocks) |
| 4 | Weather lane attribution | "tolerance lane kills 9% (constrained) / 100% (naive)" | "0 unique kills by the Weather lane across all 74 triads" |
| 5 | SVA in UVM harness | "contract SVA enforced in the pipeline" | "SVA validated standalone (115 cells); not bound into the UVM harness" |
| 6 | Batch 2 confound | "constraints are load-bearing" | "constraints + model substitution are confounded" |
| 7 | Interaction test sample | "0/6 interaction failure = component portability" | "6 cherry-picked cross-model pairs; architectural result, not a rate" |
| 8 | AER comparison | Workshop AER 0.06–0.14 vs BKG 1.0 | New: UVM scoreboards AER 0.44 (strict) / 0.64 (loose) |
| 9 | Per-assertion taxonomy | Previously unmeasured for SVA and UVM | New: SVA AER 0.20 (strict) / 0.40 (loose) |

Each correction is detailed below.

---

## Correction 1 — Catch semantics v2

**Old rule:** `C_dev = caught / 6` where a "catch" was any FAIL on a
Sabotage cell.

**Problem:** A degenerate scoreboard that fires `[RESULT] FAIL` on
every cell — including Golden — was counted as "catching" every
Sabotage bug. `C_dev = 1.0` was reachable without any real detection.

**New rule:**
Catch(triad, bug) = FAIL on ≥3/5 seeds of the bug cell ∧ PASS on ≥ 3/5 seeds of golden∧ PASS on ≥3/5 seeds of every Weather cell


A triad that fails Golden cannot claim a catch anywhere.

**Effect:** Recomputes every headline number. Script:
`recompute_all.py`. Output: `results/recompute/b1_scores_v2.csv`,
`b2_scores_v2.csv`, `s6_scores_v2.csv`.

**Corrected totals:**

| Source | v1 Q1 | v2 Q1 |
|---|---|---|
| Batch 1 (34 triads) | 20 | 20 |
| Batch 2 (26 triads) | 0 | 0 |
| Stage 6 (6 triads) | 6 | 6 |

The Q1 count is unchanged; what changed is *which* triads sit in Q3
vs. a new `FAILS_GOLDEN` label. Specifically, `gm_v04` and
`gm_w2_sb04` are reclassified from `Q3_FRAGILE` to `FAILS_GOLDEN`.

---

## Correction 2 — Stage 8 scope

**Old claim:** "9 Q1 survivors achieve C_holdout = 1.0, gap = 0."

**Problem:** The pipeline had 26 Q1 survivors (3 batch-1 Way-1, 17
batch-1 Way-2, 6 Stage-6 assemblies). Only 9 were tested. Way-2 Q1
triads were treated as derivatives of tested baselines — an
undocumented scoping assumption.

**Corrected claim:** Stage 8b (`stage8b_all_q1.py`) extends the
hold-out evaluation to all 26 Q1 survivors. Result: **26/26 achieve
C_holdout = 1.0, gap = 0.0**.

**Frozen artifact:** `results/stage8b/stage8b_scores.csv`, tag
`stage8b-frozen`.

**Scope caveat:** All 6 sealed hold-out cells exercise data-corruption
or count-corruption faults — the same class as the DEV Sabotage set.
Every Q1 survivor uses a bit-comparison scoreboard. Bit-comparison
catches any data corruption. **The uniformity is mechanistically
expected, not a discovery.** What this proves: no DEV-mutant leakage
in the harness. What this does NOT prove: generalization to fault
classes not represented in the battery (e.g., purely temporal faults).

---

## Correction 3 — Qwen reclassification

**Old claim:** "Qwen 5/5 COMPILE_FAIL — missing backticks on UVM
macros."

**Evidence from `stage5_work/qw_v01/build.log`:**
%Error: qpsk_driver.sv:17: unexpected end
%Error: qpsk_driver.sv:40: unexpected endtask
%Error: qpsk_seq.sv:2: unexpected endfunction
%Error: qpsk_seq.sv:6: unexpected endfunction
%Error: qpsk_seq.sv:10: unexpected IDENTIFIER, expecting "'{"
%Error: qpsk_seq.sv:24: unexpected endtask
%Error: qpsk_scoreboard.sv:2: unexpected endfunction


Qwen's output is structurally malformed — orphaned `end`/`endtask`/
`endfunction` tokens, invalid array declarations, and missing
backticks (5/5 drivers have `` `uvm_component_utils `` correct but
`uvm_fatal` without backtick).

**Corrected classification:** Qwen's failure is *structural*, not a
single missing character. The "backtick-drop" description understates
the issue. Suggestive of tooling truncation, chat rendering issues, or
Qwen's known output-integrity problems on long structured outputs.

**Reproducibility:** raw and ingested files both show backtick
presence/absence identically — the ingest pipeline did NOT strip
anything. This is the model's real output.

**Paper impact:** Qwen's row in any "model comparison" table should
read "systematically malformed output" not "missing backticks."

---

## Correction 4 — Weather lane attribution

**Old claim (Ablation B):** "The tolerance lane kills 9% of mutation-
only accepts (constrained) and 100% (naive). Without it, the naive
regime produces 14 false-positive survivors."

**Problem:** Recomputing under v2 catch semantics shows the tolerance
lane kills **0** triads uniquely. Every triad previously attributed to
"tolerance failure" was in fact failing **Golden**, not Weather.

**Corrected table:**

| Gate | Batch-1 kills | Batch-2 kills |
|---|---|---|
| Ingest lint | 5 (qw) | 4 |
| Compilation | 0 | 4 |
| Golden sanity | 2 | 14 |
| **Weather-only** | **0** | **0** |

Across all 74 triads, the Weather lane was never the deciding
rejection. Every post-compile, post-crash rejection was a Golden
failure.

**Reframed finding:**

> The pipeline's screening power is concentrated in four gates: ingest
> lint, compilation, Golden sanity, and reason-aware catch semantics.
> The Weather lane is validated infrastructure but contributed zero
> unique rejections on this DUT.

**What this means for the paper:** The tolerance lane's value
proposition is *unexercised by this DUT*, not *demonstrated*. On
DUT-2, Weather cells should exercise temporal/ordering faults that a
bit-comparison scoreboard cannot see, so the lane has real
discriminating work.

---

## Correction 5 — SVA in UVM harness

**Old framing:** Stage 1's contract SVA is "enforced" or "a checkpoint"
in the pipeline.

**Actual state:**
- `qpsk_sva.sv` is NOT included in `qpsk_pkg.sv`
- `qpsk_sva.sv` is NOT instantiated in `qpsk_tb_top.sv`
- All Stage 4-8 scoring ran via the scoreboard's `[RESULT]` channel

The SVA was:
- AST-locked at Stage 1
- False-fire-verified on 30 cells at Stage 1
- Extended to 115 cells via `stage1_sva_full_proof.py` (Stage 1 addendum)
- Per-assertion taxonomy computed via `sva_taxonomy.py`

But never bound into the UVM harness that scored Stage 4-8.

**Corrected disclosure:**

> Stage 1's contract SVA was AST-locked and validated on 115 battery
> cells. It is not bound into the Stage 4-8 UVM harness; those stages
> score via the scoreboard. The SVA is available as an independent
> protocol checker and is complementary to the scoreboard's functional
> checking (see SVA per-assertion taxonomy in
> `results/stage1_sva_taxonomy_summary.md`).

**Complementary-detector finding:** SVA fires on 3 Sabotage cells
(S-05, S-08, S-10 — handshake faults). Scoreboard fires on 8 Sabotage
cells (data faults). Union: 9/12 Sabotage cells caught by at least one
detector. Independent evidence streams.

---

## Correction 6 — Batch-2 confound

**Old claim:** "The constraints are load-bearing (0/35 naive survivors
vs. 3/15 constrained)."

**Problem:** Batch 2 changed two things simultaneously:
1. Prompt constraints (heavy → naive)
2. Model set (cg/qw/gm → pp/km/gm)

Only Gemini participated in both batches, and with n=5 triads:
- Constrained gm: 1/5 Q1
- Naive gm: 0/5 Q1
- Fisher's exact p ≈ 1.0 (not significant at n=5)

The observed 0/35 result conflates "constraints matter" with "pp/km
are weaker models than cg."

**Corrected claim:**

> Under a naive-prompt regime across three models (pp, km, gm), zero of
> 35 triads survived the Q1 gate. This is consistent with — but not
> cleanly separated from — a model-identity effect. Only Gemini
> participated in both prompt regimes; its n=5 result (1/5 constrained
> vs. 0/5 naive) is not statistically significant.

**DUT-2 fix:** Same model set in both prompt arms, n ≥ 10 chats per
cell.

---

## Correction 7 — Interaction test sample

**Old claim:** "Cross-model assembly shows 0/6 interaction failure —
components are portable across LLM ecosystems."

**Problem:** The 6 assemblies swapped components only between the two
tested baselines (cg_v04 and gm_v03). They were:
- 6 out of a possible 15×15×15 = 3,375 combinations
- The two "best" triads from the two Q1-producing models

This is a cherry-picked sample, not a rate. And 0/6 is a lower bound,
not a measured probability.

**Corrected claim:**

> Cross-model assembly was tested on 6 pairs derived from the two Q1-
> producing model baselines (cg_v04, gm_v03). All 6 preserved Q1
> status. This is an architectural result — the pipeline's frozen
> interface, analysis-port wiring, and seq_item contract are designed
> to make composition checkable — not an empirical interaction failure
> rate.

---

## Correction 8 — AER comparison

**Old framing:** Workshop paper reported AI single-file testbench AER
0.063–0.143 vs. human BKG 1.000. This paper implies the UVM pipeline
preserves or improves that.

**New measurement:** `stage5_sb_taxonomy.py` computed per-assertion
taxonomy for the 3 UVM Q1 scoreboards:

| Scoreboard | Sites | Useful | AER (strict) | AER (loose) |
|---|---|---|---|---|
| cg_v04 | 5 | 2 | 0.400 | 0.600 |
| cg_v05 | 7 | 3 | 0.429 | 0.571 |
| gm_v03 | 4 | 2 | 0.500 | 0.750 |
| Mean | 5.3 | 2.3 | **0.443** | **0.640** |

**Comparison:**

| Artifact | AER |
|---|---|
| Human BKG (workshop) | 1.000 |
| UVM Q1 scoreboards (this work, loose) | **0.640** |
| UVM Q1 scoreboards (this work, strict) | 0.443 |
| AI Claude single-file (workshop) | 0.143 |
| AI ChatGPT single-file (workshop) | 0.063 |

**Finding:** UVM-pipeline scoreboards have AER 3–10× higher than the
same models' single-file output under the workshop pipeline.
Constraints on structure elicit dramatically cleaner assertion code.

**Caveat:** strict AER excludes sites that only fire on hold-out bugs
(S-08). Loose AER includes them. Both are reported.

---

## Correction 9 — SVA per-assertion taxonomy (new)

**Previously unmeasured.** Now computed via `sva_taxonomy.py`:

| ID | Purpose | Fires on | Strict class | Loose class |
|---|---|---|---|---|
| P1 | liveness | S-05, S-10 | USEFUL | USEFUL |
| P2 | credit | S-08 | DEAD | USEFUL |
| P3 | symbol domain | — | KNOWN-DEAD | KNOWN-DEAD |
| P4 | X/Z check | — | KNOWN-DEAD | KNOWN-DEAD |
| P5 | pulse rule | — | KNOWN-DEAD | KNOWN-DEAD |
| | | | **AER = 0.20** | **AER = 0.40** |

The 3 "dead" assertions were documented in `qpsk_sva.sv`'s own header
as known-dead controls at authorship time (P3 tautology, P4 Verilator
2-state-inert, P5 gated off). Excluding the documented controls,
AER = 2/2 = **1.00**.

**Comparison with AI scoreboards:** Human-designed SVA (AER 0.40
loose) sits between AI-generated scoreboards (0.44–0.75) and the
human BKG (1.00). The absolute AER is depressed by the deliberate
controls.

---

## Language Softening Notes

Not a correction — a per-document find/replace pass applied on top of
this errata:

| Old | New |
|---|---|
| "20% survivor rate" | "3 of 15 Way-1" (drop % for n<20) |
| "kills 100% of naive accepts" | "kills 100% of mutation-only accepts, all via Golden sanity" |
| "proves generalization" | "confirms absence of dev-mutant leakage" |
| "component quality is property of component" | "no interaction failures observed across 6 assemblies" |
| "0/6 interaction failure rate" | "6/6 assemblies preserved Q1" |
| "interaction failure rate = 0" | "no interaction failure observed (6/6 preserved)" |

---

## Deferred to DUT-2

These are limitations of this experiment, not corrections. Named for
transparency:

1. Same model set in both prompt arms
2. API generation with pinned model versions and temperature
3. Weather cells that discriminate (temporal/ordering faults)
4. Sabotage classes beyond data-corruption (register side-effects,
   protocol-order bugs)
5. Per-constraint ablation (which specific constraint reduces crash
   rate most)
6. Effort/cost accounting (engineer-hours vs. pipeline-hours)
7. Coverage instrumentation (Stage 7 N/A)
8. RAL (v2 DUT has no registers)

---

## Frozen Artifact Chain

Every correction above is derived from frozen artifacts. The chain is
intact:
Constitution v2.1
→ Stage 1 contract + SVA addendum
→ Stage 3 battery
→ Stage 4 variant pool
→ Stage 5 scoring (v1 semantics)
→ Stage 5 recompute v2 (results/recompute/)
→ Stage 5b per-assertion taxonomy
→ Stage 6 assembly
→ Stage 8 + Stage 8b hold-out
→ Errata v1 (this document)


## Change Control

This errata is frozen upon commit. Future errata must be append-only
and hash-chained.