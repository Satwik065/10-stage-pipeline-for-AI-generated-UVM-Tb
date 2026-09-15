# Stage 8b — Hold-out on All Q1 Survivors

**Status:** FROZEN
**Date:** 2026-09-15

## Purpose

Extends Stage 8's hold-out evaluation from 9 selected Q1 survivors to
all 26 (3 batch-1 Way-1 + 17 batch-1 Way-2 + 6 Stage-6 assemblies).
Corrects an undocumented scoping assumption in the original Stage 8.

## Result

All 26 Q1 survivors achieved C_holdout = 1.0 (6/6 sealed Sabotage
cells caught, ≥3/5 seeds each). Generalization gap = 0.0 for every
triad.

## Interpretation

The uniformity is expected and mechanistically explainable: the 6
sealed hold-out cells exercise the same data-corruption mechanism as
the 6 DEV cells (bit flips, count corruption, valid glitches).
Every Q1 survivor uses a bit-comparison scoreboard, which catches
any data corruption regardless of DEV/hold-out provenance.

**What this proves:** No dev-mutant leakage in the harness. Survivors
are general-purpose comparators, not mutant-specific overfits.

**What this does NOT prove:** Generalization to fault classes outside
the DEV distribution (e.g., timing-only faults that preserve both data
and count). Future work on a companion DUT with discriminating Weather
cells and non-data-domain Sabotage mutations.

## Reproduce

```bash
python3 stage8b_all_q1.py 2>&1 | tee results/stage8b/runlog.txt
column -t -s, results/stage8b/stage8b_scores.csv

frozen upon commit
