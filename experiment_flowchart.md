# Sync Hub Protocol — Experiment Flowchart

**Project:** Screening LLM-Generated UVM Testbenches
**DUT:** QPSK Modulator + Channel + QPSK Demodulator (Golden RTL v2)
**Date:** 2026-09-15

This file is the human-readable map of every artifact, decision point,
and result in the pipeline. Every stage has a git tag. Every result is
hash-anchored. Every ablation is recorded.

---

## 1. The 10-stage pipeline (main flow)

```
┌───────────────────────────────┐
│ STAGE 0: CONSTITUTION         │
│ 23-cell battery defined       │
│ 10 Weather + 12 Sabotage      │
│ 5 LOCKED_SEEDS                │
│ tag: (commit)                 │
└───────────────┬───────────────┘
                │
                ▼
┌───────────────────────────────┐
│ STAGE 1: CONTRACT LOCK        │
│ AI-generated interface +      │
│ seq_item + SVA. AST-checked   │
│ against real RTL ports.       │
│ tag: stage1-frozen            │
└───────────────┬───────────────┘
                │
                ▼
┌───────────────────────────────┐
│ STAGE 2: MECHANICAL SCAFFOLD  │
│ pkg / monitor / agent /       │
│ env / test / tb_top           │
│ Zero AI. Pure templates.      │
│ tag: stage2-frozen            │
└───────────────┬───────────────┘
                │
                ▼
┌───────────────────────────────┐
│ STAGE 3: BATTERY              │
│ 22 mutants built + calibrated │
│ BKG verified 23/23 cells      │
│ tag: (commit)                 │
└───────────────┬───────────────┘
                │
                ▼
┌───────────────────────────────┐
│ STAGE 4: VARIANT GENERATION   │
│ 3 models (cg, qw, gm) ×       │
│ 5 drv + 5 seq + 5 sb          │
│ = 45 raw files                │
│ tag: stage4-pool              │
└───────────────┬───────────────┘
                │
                ▼
┌───────────────────────────────┐
│ STAGE 5: SCORING              │
│ Way-1: 15 triads              │
│ Way-2: leave-one-out swaps    │
│ 17 active cells × 5 seeds     │
│ → T / C_dev / quadrant        │
│ tag: stage5-frozen            │
│ Result: 3 Q1 survivors        │
└───────────────┬───────────────┘
                │
                ▼
┌───────────────────────────────┐
│ STAGE 6: ASSEMBLY             │
│ Cross-model Q1 swaps          │
│ 6 assemblies                  │
│ tag: stage6-frozen            │
│ Result: 0/6 interaction fail  │
└───────────────┬───────────────┘
                │
                ▼
┌───────────────────────────────┐
│ STAGE 7: COVERAGE             │
│ N/A — deferred to companion   │
│ DUT. Documented.              │
└───────────────┬───────────────┘
                │
                ▼
┌───────────────────────────────┐
│ STAGE 8: HOLD-OUT             │
│ 9 Q1 survivors vs 6 sealed    │
│ Sabotage cells                │
│ tag: stage8-frozen            │
│ Result: C_holdout = 1.0       │
└───────────────┬───────────────┘
                │
                ▼
┌───────────────────────────────┐
│ STAGE 9: GOLDEN SANITY        │
│ 9/9 survivors pass 5/5 seeds  │
│ tag: stage9-frozen            │
└───────────────┬───────────────┘
                │
                ▼
┌───────────────────────────────┐
│ STAGE 10: HANDOFF             │
│ deliverables/ package         │
│ tag: stage10-frozen           │
└───────────────────────────────┘
```

---

## 2. The 5 ablations (compare against the main flow)

```
┌─────────────────────────────────────────────────────────────────────┐
│ ABLATION A — Full pipeline (main result)                             │
├─────────────────────────────────────────────────────────────────────┤
│ All constraints applied.                                             │
│ Result: 3 of 15 Way-1 triads survive. 0/6 interaction failure.       │
│ 9/9 hold-out survivors. Gap = 0.                                     │
│ tag: stage5-frozen                                                    │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ ABLATION B — No Weather lane                                          │
├─────────────────────────────────────────────────────────────────────┤
│ Score with mutation-only gate instead of full gate.                  │
│ Batch 1: 22 pass mutation-only, 20 pass full → 2 killed by T (9%)    │
│ Batch 2: 14 pass mutation-only, 0 pass full → 14 killed by T (100%)  │
│ Stage 6: 6 pass both, 0 killed                                       │
│ Insight: T lane kills 9% under constrained, 100% under naive.        │
│ tag: ablation-b-frozen                                                │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ ABLATION C — No Contract Lock                                         │
├─────────────────────────────────────────────────────────────────────┤
│ 3 specification levels, 15 files each, 3 models                      │
│ L0 (no spec): 15/15 fail                                              │
│ L1 (semantic only): 15/15 fail — but on names only                   │
│   (widths: 105/105 correct)                                          │
│ L2 (frozen contract): 0 fail                                         │
│ Insight: The contract's job is NAME CONVERGENCE, not protocol        │
│ understanding. AI already knows what QPSK needs.                     │
│ tag: ablation-c-frozen                                                │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ ABLATION D — Naive AI (= Batch 2)                                     │
├─────────────────────────────────────────────────────────────────────┤
│ Strip all prompt constraints. 3 models (pp, km, gm) × 15 chats.      │
│ Result: 0 Q1 out of 35 triads. Every compile-clean triad crashed.    │
│ tag: stage5-b2-frozen                                                 │
│ Insight: The pipeline's constraints are load-bearing.                │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ ABLATION E — Multi-model                                              │
├─────────────────────────────────────────────────────────────────────┤
│ Batch 1: cg, qw, gm (Qwen 5/5 compile-fail)                          │
│ Batch 2: pp, km, gm (zero Q1 across all models)                     │
│ Stage 6: cross-model cg↔gm swaps (0/6 interaction failure)           │
│ Insight: T/C profile is model-dependent. Survivors compose across    │
│ models. Qwen is systematically incompatible.                         │
│ tags: stage5-frozen, stage5-b2-frozen, stage6-frozen                  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 3. The per-model breakdown

**BATCH 1 (constrained prompt)**

| Model | Result |
|---|---|
| ChatGPT (cg) | 2/5 Q1 survivors (v04, v05); 3/5 RUNTIME_CRASH |
| Qwen (qw) | 0/5 — 5/5 COMPILE_FAIL (backtick-drop + truncation) |
| Gemini (gm) | 1/5 Q1 survivor (v03); 1/5 Q3_FRAGILE (v04); 3/5 RUNTIME_CRASH |

**BATCH 2 (naive prompt)**

| Model | Result |
|---|---|
| Perplexity (pp) | 3/5 Q3_DEGENERATE, 2/5 COMPILE_FAIL, 0 Q1 |
| Kimi (km) | 3/5 Q3_DEGENERATE, 1/5 RUNTIME_CRASH, 1/5 COMPILE_FAIL, 0 Q1 |
| Gemini (gm) | 2/5 COMPILE_FAIL, 0 Q1 |

**STAGE 6 (cross-model)**

| Pairing | Result |
|---|---|
| cg↔gm | 6/6 Q1 assemblies |

---

## 4. The failure taxonomy

| Outcome | Batch 1 (constrained) | Batch 2 (naive) |
|---|---|---|
| Q1 SURVIVOR | 3 | 0 |
| Q3_FRAGILE | 1 (gm_v04) | — |
| Q3_DEGENERATE | — | 15 |
| RUNTIME_CRASH | 6 | 11 |
| COMPILE_FAIL | 5 | 9 |
| **Total** | **15 (Way-1)** | **35** |

---

## 5. The three headline numbers

**Survivor rate**
- Constrained prompt: 3 / 15 Way-1 triads = 20%
- Naive prompt: 0 / 11 Way-1 triads = 0%

**Tolerance lane value**
- Constrained: kills 9% of mutation-only accepts
- Naive: kills 100% of mutation-only accepts

**Generalization**
- 9/9 Q1 survivors achieve C_holdout = 1.0
- Generalization gap = 0.0

---

## 6. Tags (frozen checkpoint chain)

| Tag | Meaning |
|---|---|
| stage1-frozen | Contract lock |
| stage2-frozen | UVM scaffolding |
| stage5-frozen | Batch-1 scoring |
| stage5-b2-frozen | Batch-2 scoring |
| stage5-b2-writeup | Batch-2 writeup |
| stage6-frozen | Cross-model assembly |
| stage8-frozen | Hold-out generalization |
| stage9-frozen | Golden sanity |
| stage10-frozen | Handoff package |
| uvm-bkg-certified | UVM BKG certified 115/115 |
| b2-protocol-frozen | Batch-2 pre-registration |
| ablation-b-frozen | No Weather lane |
| ablation-c-frozen | No Contract Lock |

14 tags. Every claim in the paper traces to at least one tag.

---

## 7. Repository layout

```
qpsk_p/
├── rtl/                          Golden RTL (frozen, hash-pinned)
├── contract/                     Stage 1 locked artifacts
├── tb/uvm/                       UVM scaffolding + 23-cell wrapper
├── mutants/                      22 battery mutants (10 W + 12 S)
├── uvm_variants/                 Batch-1 AI output (45 files + BKG)
├── uvm_variants_b2/              Batch-2 AI output (45 files)
├── stage4/ingested/               Batch-1 fence-stripped + linted
├── stage4/ingested_b2/            Batch-2 fence-stripped + linted
├── ablation_c_interfaces/         L0 interfaces (15 files)
├── ablation_c_interfaces_l1/      L1 interfaces (15 files)
├── deliverables/                  Stage 10 handoff package
│   ├── HANDOFF.md
│   ├── winning_testbench/
│   └── reports/
├── results/                       Scores, runs, attributions
│   ├── stage5_scores.csv          (batch-1 way-1 + way-2)
│   ├── way2_attribution.csv
│   ├── stage6/stage6_scores.csv
│   ├── stage8/stage8_scores.csv
│   ├── b2/stage5_scores.csv       (batch-2)
│   └── ablations/
│       ├── ablation_B_no_weather.csv
│       ├── ablation_C_contract_lock.csv
│       └── ablation_C_L1.csv
├── prompts/prompts_b2/            Frozen naive prompts + hashes
├── stage4_5_protocol.md           Frozen pre-registration
├── stage5_final.md                Batch-1 writeup
├── stage5_b2.md                   Batch-2 writeup
├── stage6.md                      Assembly writeup
├── stage8.md                      Hold-out writeup
├── stage9.md                      Golden sanity
├── stage10.md                     Handoff
├── ablation_B.md
├── ablation_C.md
├── experiment_flowchart.md        (this file)
├── build_uvm.sh                   Verilator build script
└── .git/                          14 tags
```

---

## 8. How to reproduce everything

```bash
# 1. Setup
export UVM_DIR=/path/to/uvm-1.2
./build_uvm.sh

# 2. Verify BKG certifies the battery
python3 stage5_runner.py          # batch 1
./run_batch2.sh                   # batch 2

# 3. Reclassify
python3 stage5_reclassify.py      # batch 1
python3 stage5_reclassify_b2.py   # batch 2

# 4. Cross-model assembly
python3 stage6_assembler.py

# 5. Hold-out generalization
python3 stage8_holdout.py

# 6. Ablations
python3 ablation_b_no_weather.py
python3 ablation_c_check.py       # L0
python3 ablation_c_check_l1.py    # L1
```

---

## 9. What each ablation proves (one-liners)

| Ablation | Question | Answer |
|---|---|---|
| A | Does the full pipeline produce a working testbench? | Yes — 3 survivors, 0 interaction failure, 0 gap |
| B | Does the Weather lane matter? | Yes — kills 100% of naive false-accepts |
| C | Does the Contract Lock matter? | Yes — kills 100% of interface name divergences |
| D | Do the prompt constraints matter? | Yes — 0 vs 3 survivors |
| E | Does the result depend on one model? | No — 2 models produced Q1, cross-model composes |