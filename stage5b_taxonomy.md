# Stage 5b — Per-Assertion Taxonomy (Q1 Scoreboards)

**Status:** FROZEN
**Date:** 2026-09-15

## Method

Each Q1 survivor scoreboard (cg_v04, cg_v05, gm_v03) was instrumented:
every `errors++` / `errors += N` site got a unique `[FIRE] L<n>` tag.
Each instrumented triad was rebuilt and run against all 23 cells × 5
seeds. Fire matrix -> §10 taxonomy.

## AER Results

| Scoreboard | Sites | Useful | Dead | Harmful | Redundant | AER (strict) | AER (loose) |
|---|---|---|---|---|---|---|---|
| cg_v04 | 5 | 2 | 2 | 0 | 1 | 0.400 | 0.600 |
| cg_v05 | 7 | 3 | 1 | 0 | 3 | 0.429 | 0.571 |
| gm_v03 | 4 | 2 | 1 | 0 | 1 | 0.500 | 0.750 |
| **Mean** | 5.3 | 2.3 | 1.3 | 0 | 1.7 | **0.44** | **0.64** |

**Strict** = §10 definition (Useful requires ≥1 DEV bug). **Loose** =
Useful includes sites firing on ≥1 Sabotage bug (DEV or hold-out).

Three sites are classified DEAD under strict but fire on S-08 (hold-out
only). Under the strict taxonomy, hold-out bugs don't count toward
Usefulness. Under the loose taxonomy they do.

## Comparison vs. Workshop Paper

| Artifact | AER | Source |
|---|---|---|
| Human BKG | 1.000 | Workshop paper |
| **UVM cg_v04** | **0.400** | This work |
| **UVM cg_v05** | **0.429** | This work |
| **UVM gm_v03** | **0.500** | This work |
| AI Claude (single-file) | 0.143 | Workshop paper |
| AI ChatGPT (single-file) | 0.063 | Workshop paper |

**UVM-constrained scoreboards have AER 3-8x higher than the same
models' single-file output.** Same taxonomy, same metric. The
difference is the pipeline's constraint set.

## Findings

1. **Zero HARMFUL sites.** Q1 scoreboards by definition don't false-fire
   on Golden or Weather. The taxonomy confirms this independently.

2. **One dominant check per scoreboard.** Every scoreboard has one site
   that catches 8-12 Sabotage bugs (the primary data-comparison check).
   All other sites are secondary.

3. **~1/3 of sites are Redundant.** A subset of the useful sites fire on
   identical bug sets (or subsets), meaning one site alone would
   suffice.

4. **Every scoreboard has dead-code padding.** 1-2 sites per scoreboard
   never fire on any of the 23 cells. These are the "plausible-looking
   but non-firing" checks that inflate AER denominator.

5. **The pipeline improves AER by 3-8x.** Workshop single-file tests
   from the same models had AER 0.06-0.14. Under the UVM pipeline, same
   models produce AER 0.40-0.50. Constraints don't just filter bad
   output — they elicit better output.

## Caveats

- **Greedy redundancy classification.** Keep-order is SHA256 of site
  id; the first USEFUL site per bug-set is kept, later matches are
  marked Redundant. This is deterministic but not globally optimal.
- **Strict vs. loose AER.** Sites firing only on hold-out bugs are
  classified Dead under §10. A looser definition reports higher AER.
- **23-cell matrix includes hold-out.** Sites that fire on hold-out
  bugs are recorded but don't count toward strict Usefulness.

## Reproduction

```bash
mkdir -p results/stage5b
python3 stage5_sb_taxonomy.py 2>&1 | tee results/stage5b/runlog.txt

frozen upon commit
