# Stage 6 — Cross-Model Assembly (Interaction Test)

**Status:** FROZEN
**Date:** 2026-09-14

## 1. Purpose

Stage 5's Way-2 (leave-one-out) tested components *within* a model.
Stage 6 tests them *across* models. A driver that passes Q1 with its
own model's sequence might fail when paired with another model's
sequence. This is the "interaction failure rate" that doesn't exist
in the literature.

## 2. Assemblies Tested

Holds 2 components at their own model's Q1 baseline, swaps 1 component
to the other model's Q1 baseline.

| ID | drv | seq | sb | Cross slot |
|---|---|---|---|---|
| X1_cg_drvGm | gm_03 | cg_04 | cg_04 | driver |
| X2_cg_seqGm | cg_04 | gm_03 | cg_04 | sequence |
| X3_cg_sbGm  | cg_04 | cg_04 | gm_03 | scoreboard |
| X4_gm_drvCg | cg_04 | gm_03 | gm_03 | driver |
| X5_gm_seqCg | gm_03 | cg_04 | gm_03 | sequence |
| X6_gm_sbCg  | gm_03 | gm_03 | cg_04 | scoreboard |

Baselines: cg_v04 (ChatGPT), gm_v03 (Gemini). Qwen contributed no Q1
components in Stage 5.

## 3. Results

| Assembly | Cross | T | C_dev | Quadrant |
|---|---|---|---|---|
| X1_cg_drvGm | drv | 1.0000 | 1.0000 | Q1_SURVIVOR |
| X2_cg_seqGm | seq | 1.0000 | 1.0000 | Q1_SURVIVOR |
| X3_cg_sbGm  | sb  | 1.0000 | 1.0000 | Q1_SURVIVOR |
| X4_gm_drvCg | drv | 1.0000 | 1.0000 | Q1_SURVIVOR |
| X5_gm_seqCg | seq | 1.0000 | 1.0000 | Q1_SURVIVOR |
| X6_gm_sbCg  | sb  | 1.0000 | 1.0000 | Q1_SURVIVOR |

**Interaction failure rate: 0/6.**
**Q1 survivors: 6/6.**

## 4. Interpretation

Every cross-model assembly survived. There is no measurable
interaction failure when individual components pass the Q1 gate.

**Prediction failure (recorded):** based on Way-2 attribution, we
predicted X2 and X5 (sequence swaps) would fail. They did not. The
prediction confused *sequence fragility* (Way-2 showed fragile
sequences break Q1) with *sequence cross-model incompatibility*
(Stage 6 shows robust sequences transfer). These are distinct
properties.

## 5. Finding

**Component quality is a property of the component, not of the LLM
ecosystem it was generated in.** A Q1-passing driver, sequence, or
scoreboard from ChatGPT composes with Gemini's Q1 components without
degradation. LOO attribution from Stage 5 Way-2 generalizes across
model boundaries.

Paired with batch 2 (§ stage5_b2.md), this completes the pipeline's
core argument: the pipeline's constraints produce components that
(a) survive the gate (batch 1) and (b) generalize across ecosystems
(Stage 6), while (c) removing those constraints produces zero
survivors (batch 2).

## 6. Reproducibility

```bash
python3 stage6_assembler.py 2>&1 | tee results/stage6/stage6_runlog.txt
column -t -s, results/stage6/stage6_scores.csv