# Stage 8 — Hold-out Generalization

**Status:** FROZEN
**Date:** 2026-09-14

## Result

All 9 Q1 survivors (3 from Way-1: `cg_v04`, `cg_v05`, `gm_v03`;
6 from Stage 6 cross-model assemblies) were run against the 6 sealed
Sabotage cells for the first time, 5 seeds each.

| Triad | Origin | C_holdout | Gap |
|---|---|---|---|
| q1_cg_v04 | way1 | 1.0000 | 0.0000 |
| q1_cg_v05 | way1 | 1.0000 | 0.0000 |
| q1_gm_v03 | way1 | 1.0000 | 0.0000 |
| q1_X1_cg_drvGm | stage6 | 1.0000 | 0.0000 |
| q1_X2_cg_seqGm | stage6 | 1.0000 | 0.0000 |
| q1_X3_cg_sbGm  | stage6 | 1.0000 | 0.0000 |
| q1_X4_gm_drvCg | stage6 | 1.0000 | 0.0000 |
| q1_X5_gm_seqCg | stage6 | 1.0000 | 0.0000 |
| q1_X6_gm_sbCg  | stage6 | 1.0000 | 0.0000 |

**Generalization gap (C_dev − C_holdout) = 0.0000 for all survivors.**

## Interpretation

No overfit. Survivors were not tuned to the 6 DEV mutants; the same
scoreboard logic that catches the DEV Sabotage cells also catches the
hold-out Sabotage cells. The pipeline's survivor gate selects for
general-purpose testbenches.

## Limitation (declared pre-submission)

The hold-out set covers the same fault classes as the DEV set (bit
corruption, count corruption). A fault class not represented in DEV
(e.g., a purely temporal fault that preserves both data and count)
would test survivors more aggressively. Extension to the companion DUT.

## Reproducibility

```bash
python3 stage8_holdout.py 2>&1 | tee results/stage8/stage8_runlog.txt
column -t -s, results/stage8/stage8_scores.csv