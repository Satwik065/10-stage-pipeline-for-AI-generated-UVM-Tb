# Stage 9 — Golden Sanity Re-check

**Status:** FROZEN
**Date:** 2026-09-14

## Result

Every Q1 survivor passes Golden RTL on all 5 LOCKED_SEEDS. Because
Golden was already executed in Stage 5 (Way-1) and Stage 6
(cross-model assemblies), Stage 9 aggregates from those records
rather than re-running.

| Triad | Origin | Golden PASS |
|---|---|---|
| q1_cg_v04 | Stage 5 Way-1 | 5/5 |
| q1_cg_v05 | Stage 5 Way-1 | 5/5 |
| q1_gm_v03 | Stage 5 Way-1 | 5/5 |
| q1_X1_cg_drvGm | Stage 6 | 5/5 |
| q1_X2_cg_seqGm | Stage 6 | 5/5 |
| q1_X3_cg_sbGm  | Stage 6 | 5/5 |
| q1_X4_gm_drvCg | Stage 6 | 5/5 |
| q1_X5_gm_seqCg | Stage 6 | 5/5 |
| q1_X6_gm_sbCg  | Stage 6 | 5/5 |

**No false-fails on unmodified Golden RTL across 45 runs**
(9 triads × 5 seeds).

## Evidence

Stage 5 Way-1 golden passes:
grep ",golden," results/stage5_runs.csv | grep PASS | wc -l


Stage 6 golden passes:

grep ",golden," results/stage6/stage6_runs.csv | grep PASS | wc -l


Per-triad verification:

for t in cg_v04 cg_v05 gm_v03; do
printf "%-10s " "{t},.,golden,.,PASS," results/stage5_runs.csv
done

for t in X1_cg_drvGm X2_cg_seqGm X3_cg_sbGm X4_gm_drvCg X5_gm_seqCg X6_gm_sbCg; do
printf "%-16s " "{t},.,golden,.,PASS," results/stage6/stage6_runs.csv
done




Expected: all 9 lines end in `5`.

## Interpretation

No Q1 survivor false-fails on unmodified Golden RTL. This is the
final precondition check before handoff (Stage 10). Combined with
Stage 8's C_holdout = 1.0 across all 9 survivors, the pipeline's
deliverable is confirmed: a testbench that passes Golden, tolerates
Weather, catches DEV Sabotage, and generalizes to hold-out Sabotage.

## Change Control

Frozen upon commit.