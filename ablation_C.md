# Ablation C — No Contract Lock

**Status:** FROZEN
**Date:** 2026-09-15

## Purpose

Quantifies Stage 1's value. Three levels of specification were tested
against the same 3 models × 5 chats (15 files per level):

| Level | Specification |
|---|---|
| **L0** | "write an interface for a QPSK TB" — no signal detail |
| **L1** | Full semantic description (function, width, direction, clocking, modports); signal names explicitly left to the model |
| **L2** | The frozen Stage 1 contract verbatim — the interface that every downstream artifact is built against |

L2 is not a chat; it is the frozen artifact.

## Results

| Level | Files | Pass | Fail |
|---|---|---|---|
| L0 | 15 | 0 | 15 |
| L1 | 15 | 0 | 15 (all fail on naming only) |
| L2 | — | — | 0 (AST-locked) |

### L1 breakdown — widths correct, names divergent

| Metric | Value |
|---|---|
| Signal widths correct | **105 / 105** (7 slots × 15 files) |
| Signal set present | 15 / 15 files |
| Signal **names** matching contract | **0 / 105** |
| Renames per file (avg) | 3.7 |
| Missing signals | 1 (gm_05, alias-checker gap) |

### The specific renames

| Contract name | AI-invented aliases | Count |
|---|---|---|
| `bits_in` | `symbol_in` | 15/15 |
| `bits_out` | `symbol_out`, `demod_out` | 15/15 |
| `ch_seed` | `channel_seed`, `seed` | 15/15 |
| `rst` | `rst`, `rst_n`, `reset` | 15/15 (all present) |
| `valid_in` | `valid_in`, `symbol_valid_in` | 15/15 |

**Zero files used the contract's chosen names for `bits_in`, `bits_out`,
or `ch_seed`.**

## Findings

### 1. LLMs understand the QPSK protocol

Under L1, every file correctly declared:
- 2-bit symbols (in and out)
- 32-bit channel seed
- 1-bit valid signals
- Correct direction per modport
- Clocking blocks on the right edge

There were zero width errors and zero missing signals. Protocol
understanding is not the failure mode.

### 2. LLMs do not converge on identifier names

Across 15 independent chats, every file chose different names for the
same 7 signals. No two files produced the same naming convention. The
naming is a free variable that each chat independently samples.

### 3. The contract's job is naming convergence, not protocol understanding

Without L2, every downstream AI generation requires the engineer to
manually map model-invented names to the harness's expected names.
This is a mechanical `sed` per file, per chat, per model — the exact
class of work that a frozen contract eliminates.

### 4. The L0 → L1 → L2 curve

| Transition | What improves |
|---|---|
| L0 → L1 | Signal set, widths, structure all become correct |
| L1 → L2 | Identifier names become correct |

The frozen contract is solving **only the naming problem**. The
protocol is already understood.

## Practical impact

Under a naive LLM-driven UVM workflow (no contract lock), every
interface file requires manual review + rename before integration.
With the frozen contract + AST check, that work is eliminated — but
the AST check is doing different work than one might assume: it is
not detecting "AI invented a QPSK signal," it is detecting "AI chose
a different name than the harness expects."

## Reproducibility

```bash
python3 ablation_c_check.py       # L0 → results/ablations/ablation_C_contract_lock.csv
python3 ablation_c_check_l1.py    # L1 → results/ablations/ablation_C_L1.csv
Change control
freeze upon commit
