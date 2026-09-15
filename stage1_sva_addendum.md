# Stage 1 — Extended SVA False-Fire Proof

**Status:** FROZEN
**Date:** 2026-09-15

## Purpose

Stage 1's original false-fire proof (30 cells) tested the contract SVA
against Golden + 5 Weather mutants across 5 seeds. This addendum
extends the proof to all 23 battery cells × 5 seeds = 115 runs,
closing the gap on W-03, W-04, W-07, W-08, W-10 (untested in Stage 1).

## Method

Standalone harness (`tb/tb_p1_check.sv`) binds `contract/qpsk_sva.sv`
at the loopback boundary. Each battery cell built and run across 5
LOCKED_SEEDS.

## Result

| Cell class | SVA silent? | Fires |
|---|---|---|
| Golden | ✓ | — |
| W-01..W-10 (all 10 Weather) | ✓ | — |
| S-01 (const sym10) | ✓ | — |
| S-02 (const sym01) | ✓ | — |
| S-03 (slice invert I) | ✓ | — |
| S-04 (slice swap IQ) | ✓ | — |
| **S-05 (valid gate)** | ✗ | **P1 liveness** |
| S-06 (demod valid skew) | ✓ | — |
| S-07 (const sym00) | ✓ | — |
| **S-08 (valid dup)** | ✗ | **P2 credit** |
| S-09 (Q inversion) | ✓ | — |
| **S-10 (drop valid)** | ✗ | **P1 liveness** |
| S-11 (noise overload) | ✓ | — |
| S-12 (Q forced 0) | ✓ | — |

**Zero false fires on 55 Golden+Weather runs.**

## Finding

The contract SVA is a **complementary detector**, not a redundant one:

- **Scoreboard** catches data mutations (S-01, S-02, S-03, S-09, S-11, S-12)
- **SVA** catches handshake mutations (S-05, S-08, S-10)
- **Union**: 8/12 Sabotage cells detected by at least one detector

The SVA's P1 (liveness) and P2 (credit) assertions check protocol
invariants that data-comparison scoreboards structurally cannot see.
Conversely, the scoreboard catches data corruptions that leave the
handshake intact. Two independent detectors, zero overlap in false
fires.

## Impact on the pipeline

- Stage 1's SVA claim is strengthened: validated on 115 cells, not 30.
- Q1 survivor verification can be augmented with SVA as a second-
  detector layer (integration is trivial: bind `qpsk_sva` in `tb_top`).
- The frozen Stage 4-8 results are unchanged; the SVA does not fire on
  any cell that Q1 survivors pass (Golden+Weather).

## Reproducibility

```bash
python3 stage1_sva_full_proof.py 2>&1 | tee stage1_sva_full_proof.log

frozen on commit
