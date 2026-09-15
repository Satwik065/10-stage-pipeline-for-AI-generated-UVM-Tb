> **POST-ERRATA NOTICE (2026-09-15).** Certain numbers in this
> document are superseded by `errata_v1.md`. Specifically: catch
> semantics (v2), Stage 8 scope (9 → 26 survivors), Weather lane
> attribution (0 unique kills), Qwen reclassification (structural
> malformation, not just backtick-drop), and AER numbers. See
> `errata_v1.md` for the corrected claims. This document is preserved
> as the frozen historical record; errata is the source of truth for
> any number cited in the paper.

---

# Ablation B — No Weather Lane

**Status:** FROZEN
**Date:** 2026-09-15

## Method

Re-applies the survivor gate with the Tolerance lane removed:

- **Mutation-only gate:** accepts iff `C_dev == 1.0`
- **Full gate:** accepts iff `T == 1.0 AND C_dev == 1.0`

A "false accept" is any triad that passes mutation-only but fails the
full gate — i.e. a triad the tolerance lane killed.

Data sources:
- `results/stage5_scores.csv` (batch 1, way1 + way2)
- `results/b2/stage5_scores.csv` (batch 2, way1 + way2)
- `results/stage6/stage6_scores.csv` (cross-model assemblies)

## Results

| Source | Triads | Mutation-only accepts | Full-gate accepts | Killed by tolerance lane |
|---|---|---|---|---|
| Batch 1 (constrained) | 39 | **22** | 20 | **2** (9%) |
| Batch 2 (naive) | 34 | **14** | 0 | **14** (100%) |
| Stage 6 (cross-model) | 6 | 6 | 6 | 0 (0%) |

## False accepts (killed by tolerance lane)

| Source | Triad | T | C_dev | Quadrant | Kill reason |
|---|---|---|---|---|---|
| batch 1 | `gm_v04` | 0.0000 | 1.0000 | Q3_FRAGILE | Fails Golden (errors=20) and all 10 Weather cells |
| batch 1 | `gm_w2_sb04` | 0.0000 | 1.0000 | Q3_FRAGILE | Same mechanism (bad scoreboard) |
| batch 2 | 14 triads | 0.0000 | 1.0000 | Q3_DEGENERATE | Scoreboard fires `[RESULT] FAIL` on every cell including Golden |

## Finding

**The tolerance lane's discriminating power scales with prompt looseness.**

- Constrained prompt: 2/22 triads killed (9%)
- Naive prompt: 14/14 triads killed (100%)

Under the naive prompt, mutation-only screening would accept 14
triads as "strong testbenches." Every one of them is a degenerate
scoreboard that emits a constant `FAIL` signal — including on the
correct DUT. The tolerance lane removes all of them.

Without the tolerance lane, batch-2 false positives would pass
screening as legitimate results. The pipeline's tolerance gate is not
optional.

## Secondary finding

Batch 1's `gm_v04` (Stage 5) and `gm_w2_sb04` (Stage 5 Way-2) are the
only two constrained-prompt triads killed by the tolerance lane. Both
share the same mechanism: Gemini's scoreboard produces a reproducible
false-alarm signature (Golden errors=20, stable across all 5 seeds).
The tolerance lane correctly identifies these as non-survivors.

## Reproducibility

```bash
python3 ablation_b_no_weather.py

Change control

frozen upon commit
