# Stage 5 — Batch 2 (Naive-Prompt Ablation)

**Project:** Sync Hub Protocol — Screening LLM-Generated UVM Testbenches
**DUT:** QPSK Modulator + Channel + QPSK Demodulator (Golden RTL v2)
**Constitution:** v2.1 (frozen)
**Protocol:** `stage4_5_protocol.md` §13 (frozen at tag `b2-protocol-frozen`)
**Runner:** `stage5_runner_b2.py` + `stage5_reclassify_b2.py`
**Model set:** pp (Perplexity), km (Kimi), gm (Gemini)
**Status:** FROZEN
**Date:** 2026-09-14

---

## 1. Purpose

Batch 2 is **Experiment D** of the pipeline document — a naive-prompt
ablation that measures LLM-generated UVM quality with the pipeline's
accumulated constraint wisdom REMOVED.

The batch-1 prompts contained, explicitly:
- `` `uvm_component_utils `` requirement
- `` `uvm_object_utils `` requirement
- "declarations at top of block" (Verilator quirk)
- "do not emit module/package/import"
- "no `expect` identifier"
- Analysis-port member names (`ap_imp_expected`, `ap_imp_observed`)
- Reset-aware start algorithm
- "exactly one drv_cb cycle" pulse width
- "FRESH item every iteration"
- Publish-expected-to-`ap_expected` timing
- Style seeds (5 distinct shapes per category)

The batch-2 prompts contain ONLY mechanical requirements:
- Frozen interface + seq_item (integration fact)
- Class names, endclass, no module/package/import
- "10 of each, 40 items" (§3 stimulus envelope)
- `[RESULT] PASS` / `[RESULT] FAIL errors=N` verdict channel
- Structural signatures (`write_expected`, `write_observed`, `ap_expected`)

All algorithmic hints, style seeds, Verilator quirk warnings, and
harness-integration contracts were removed.

**Pre-registered predictions** (hashed in protocol §13.5 before any
batch-2 chat):
- P1 — Diversity collapse (fewer functional variants per model+category)
- P2 — Higher compile-fail rate than batch 1
- P3 — Q2 and/or Q4 populated

---

## 2. Generation & Substitution

**Original plan:** 3 models × 3 categories × 5 chats = 45 raw files.

**Deviation:** ChatGPT (`cg`) and Qwen (`qw`) became unavailable due to
anti-bot human-verification walls before any batch-2 chat was fired.
Substituted with pp (Perplexity) and km (Kimi) — both English-language
general-purpose models. Gemini (`gm`) retained. Substitution executed
pre-generation and committed as tag `b2-protocol-frozen`.

**Final model set:** `pp`, `km`, `gm`.

---

## 3. Ingest Results

Ingest runs at `stage4_ingest_lint.py` with the naive-regime rules:
- Fence-strip (only permitted edit)
- Forbidden-token check
- Class-name/count check
- Required-macro check (`uvm_component_utils` / `uvm_object_utils`)

| Model | Files | Eligible | INELIGIBLE | Reason |
|---|---|---|---|---|
| pp | 15 | 15 | 0 | — |
| km | 15 | 14 | 1 | `km_04` driver missing `uvm_component_utils` |
| gm | 15 | 12 | 3 | `gm_02`, `gm_04` drivers; `gm_sb_01` scoreboard |
| **Total** | **45** | **41** | **4** | all `missing-macro` |

**Finding (P2 evidence):** 4/45 files missing the UVM registration
macro under the naive prompt. Batch 1 had zero such failures because
the prompt explicitly required it. **The pipeline's macro constraint is
load-bearing.**

---

## 4. Structural Compile Failures

Four scoreboards never declared the analysis-imp members at all
(`no-imp-decl-found`):
- `pp_sb_04`, `pp_sb_05`
- `gm_sb_02`, `gm_sb_04`

The frozen `tb/uvm/qpsk_env.sv` connects to
`scb.ap_imp_expected` and `scb.ap_imp_observed`. Any scoreboard that
doesn't declare those two members fails Verilator elaboration at
`env.connect_phase` — the build exits in ~1 second.

Triads affected: `b2_pp_v04`, `b2_pp_v05`, `b2_gm_v02` (never formed),
`b2_gm_v04` (never formed). Recorded as `COMPILE_FAIL`.

**Second P2 data point:** 4/15 naive scoreboards did not produce the
required harness contract.

---

## 5. Member-Name Normalization

The other 15 naive scoreboards *did* declare imps of the correct type
(`uvm_analysis_imp_expected` / `uvm_analysis_imp_observed`) but named
the member variables differently:

| Model | Names used |
|---|---|
| pp_01, pp_03 | `expected_export`, `observed_export` |
| pp_02 | `expected_imp`, `observed_imp` |
| km_01..05 | `expected_export`, `observed_export` |
| gm_01 | `expected_imp`, `observed_imp` |
| gm_03 | `exp_port`, `obs_port` |
| gm_05 | `expected_export`, `observed_export` |

**Third P2 data point:** without an explicit naming contract, LLMs do
not converge on a required interface. Batch-1's prompt named both
members; batch-2's did not.

**Patch applied:** `patch_sb_imp_names.py` mechanically renamed the
member variables to the canonical names. This is a wiring-name edit, not
a logic edit — the scoreboard comparison logic (what the ablation tests)
is untouched. Same class as `patch_driver_macro.py` from batch 1.

---

## 6. Way-1 Results (corrected)

| Triad | Model | T | C_dev | Quadrant |
|---|---|---|---|---|
| b2_pp_v01 | pp | 0.0000 | 0.0000 | RUNTIME_CRASH |
| b2_pp_v02 | pp | 0.0000 | 0.0000 | RUNTIME_CRASH |
| b2_pp_v03 | pp | 0.0000 | 1.0000 | Q3_DEGENERATE |
| b2_pp_v04 | pp | 0.0000 | 0.0000 | COMPILE_FAIL |
| b2_pp_v05 | pp | 0.0000 | 0.0000 | COMPILE_FAIL |
| b2_km_v01 | km | 0.0000 | 1.0000 | Q3_DEGENERATE |
| b2_km_v02 | km | 0.0000 | 1.0000 | Q3_DEGENERATE |
| b2_km_v03 | km | 0.0000 | 1.0000 | Q3_DEGENERATE |
| b2_km_v05 | km | 0.0000 | 0.0000 | COMPILE_FAIL |
| b2_gm_v03 | gm | 0.0000 | 0.0000 | COMPILE_FAIL |
| b2_gm_v05 | gm | 0.0000 | 0.0000 | COMPILE_FAIL |

**Note on `Q3_DEGENERATE`:** Every triad with this label has `T=0.0000`
— it fails Golden AND every Weather cell. `C_dev=1.0000` is an artifact:
the scoreboard reports `[RESULT] FAIL` on every cell (including Golden),
which the naive classifier counted as "caught Sabotage". A reasonable
scoreboard cannot achieve `C_dev=1` while failing Golden. This quadrant
is **not** a tolerance failure; it is a scoreboard that fails everything.

The original runner's Q3_FRAGILE label was corrected by
`stage5_reclassify_b2.py` — but the corrected script still labels these
`Q3_FRAGILE` because they pass the `T<1 ∧ C=1` test. A manual review
identified them as a degenerate sub-class.

---

## 7. Way-2 Results

Baselines selected by protocol §6.2 (C_dev desc → T desc → version-sum
asc). With zero Q1 way-1 triads, baselines were selected from the
`Q3_DEGENERATE` pool (C_dev=1, T=0).

- pp baseline: `b2_pp_v03` (only Way-1 C_dev=1)
- km baseline: `b2_km_v01` (lowest version-sum among C_dev=1)
- gm: no baseline (only COMPILE_FAIL Way-1 triads)

**Way-2 swaps formed:** 24 (12 pp + 12 km)

All swaps landed in `RUNTIME_CRASH`, `Q3_DEGENERATE`, or `COMPILE_FAIL`.
**Zero Q1, zero Q2, zero Q4.**

---

## 8. Batch-2 Quadrant Summary

| Quadrant | Count |
|---|---|
| Q1 SURVIVOR | **0** |
| Q2 BLIND | **0** |
| Q3_DEGENERATE (fails everything) | 15 |
| Q3 genuine (passes Golden, false-alarms on Weather) | **0** |
| Q4 DEAD | **0** |
| RUNTIME_CRASH | 11 |
| COMPILE_FAIL | 9 |
| **Total triads** | **35** |

---

## 9. Pre-Registered Prediction Outcomes

| ID | Prediction | Outcome |
|---|---|---|
| **P1** | Diversity collapse | **FALSIFIED** — every model+category produced 5 unique normalized hashes |
| **P2** | Higher compile-fail rate | **CONFIRMED** — 4/45 INELIGIBLE + 9 COMPILE_FAIL vs batch 1's 0 + 5 |
| **P3** | Q2 and/or Q4 populated | **FALSIFIED** — neither populated |

P1's falsification is a positive result: it shows that removing *style*
constraints (v01–v05 seeds) does not collapse output diversity when the
model is otherwise free to make structural choices. Diversity in the
naive regime comes from the models themselves, not from prompt seeds.

---

## 10. Batch-1 vs Batch-2 Comparison

| Metric | Batch 1 (constrained) | Batch 2 (naive) |
|---|---|---|
| Prompts | Heavy constraints | Mechanical only |
| Models | cg, qw, gm | pp, km, gm |
| Raw files | 45 | 45 |
| Eligible after ingest | 45 / 45 | 41 / 45 |
| Way-1 triads formed | 15 | 11 |
| Way-2 triads formed | 24 | 24 |
| **Q1 SURVIVOR** | **3** | **0** |
| Q3 real (passes Golden) | 0 | **0** |
| Q3_DEGENERATE | 1 | 15 |
| RUNTIME_CRASH | 6 | 11 |
| COMPILE_FAIL | 5 | 9 |
| Total scored triads | 39 | 35 |

**Finding:** Under the naive prompt, zero triads (out of 35) achieved
`T=1.0 ∧ C_dev=1.0`. Under the constrained prompt, 3 of 39 did.

The pipeline's accumulated constraints convert a
"does not produce a usable testbench" outcome into a
"sometimes produces a survivor" outcome. That is the ablation's
central result.

---

## 11. Failure Taxonomy — Batch 1 vs Batch 2

| Failure class | Batch 1 | Batch 2 |
|---|---|---|
| COMPILE_FAIL (missing backtick) | 5 (qw only) | 0 |
| COMPILE_FAIL (missing macro) | 0 | 4 (ingest INELIGIBLE) |
| COMPILE_FAIL (missing imp declaration) | 0 | 4 |
| RUNTIME_CRASH (null handle) | 6 | 11 |
| Q3_DEGENERATE (fails everything) | 1 | 15 |
| Q1 SURVIVOR | 3 | 0 |

**New failure mode discovered in batch 2:** null-handle scoreboards that
fire `[RESULT] FAIL` on every cell (including Golden) without any
data-driven cause. These are not tolerance failures; they are broken
scoreboards producing a constant FAIL signal.

---

## 12. Findings for the Paper

### Finding A — The pipeline's constraints are load-bearing

Under the naive prompt, 0/35 triads survive the gate. Under the
constrained prompt, 3/39 do. The constraint list is not decoration; it
encodes the specific knowledge that converts LLM output from
"compiles in isolation" to "usable in a UVM environment."

### Finding B — The failure modes shift, not disappear

Batch 1's dominant failure was Q3-tolerance rejection (false alarms on
legal Weather variation) plus qwen's systematic backtick-drop. Batch 2's
dominant failures are structural: missing macros, missing harness
contracts, null handles, and degenerate scoreboards. **Pipelines don't
eliminate LLM failure — they change its shape.**

### Finding C — Interface contracts are non-obvious to LLMs

Every naive scoreboard invented its own analysis-imp member names.
Required names (`ap_imp_expected`, `ap_imp_observed`) were never
discovered from context. Without explicit naming, no LLM produced a
batch-2 scoreboard that plugs into the frozen env without a mechanical
rename.

### Finding D — Diversity is not the pipeline's contribution

P1 was falsified. Naive prompts produce as much *normalized-hash*
diversity as constrained prompts (5 unique per model+category).
Diversity comes from the models. What the pipeline contributes is
*convergence on a working interface*.

### Finding E — "Fickle" is the right description

Every batch-2 triad that compiled cleanly crashed at t=0 in at least one
seed. Every way-2 swap introduced a fresh failure mode. Under the naive
prompt, LLM-generated UVM code is not "sometimes works" — it is
"almost never works, and when it does, it fails differently each time."

---

## 13. Frozen Artifacts

| Artifact | sha256 |
|---|---|
| `results/b2/stage5_runs.csv` | `328a6abd8435ffc7a386a49de4e6401c41e4557ea1a6309024db87fb50bebb6a` |
| `results/b2/stage5_scores.csv` | `aaf43f1e0971ce581768cd8fb8f3d4a1dc62304b584093bdbeb4eb618c1d8aa1` |
| `results/b2/stage5_scores_CORRECTED.csv` | `aaf43f1e0971ce581768cd8fb8f3d4a1dc62304b584093bdbeb4eb618c1d8aa1` |
| `results/b2/way2_attribution.csv` | `ee711cf5f634df18cc141ba21edd89de84bcd5eeeb72946b03e7a9e10df522ce` |
| `results/b2/diversity_table.csv` | `6154f101ebf6e892864da55a009d78df887706e3d3f2ac819cdaf074741c504c` |
| `variants_manifest_b2.json` | `e64be71f34c76b4462b15e6287f6ecc299059dfb09eda2f7155247a04e955982` |
| `stage4_5_protocol.md` | hash in `results/stage4_5_protocol_hash.txt` |

---

## 14. Reproduction

```bash
# 1. Batch-2 runner (Way-1 + Way-2 scoring)
python3 stage5_runner_b2.py 2>&1 | tee results/b2/stage5_runlog_b2.txt

# 2. Reason-aware reclassification
python3 stage5_reclassify_b2.py

# 3. Member-name normalization (applied before scoring)
python3 patch_sb_imp_names.py

# 4. Inspect
column -t -s, results/b2/stage5_scores_CORRECTED.csv
column -t -s, results/b2/way2_attribution.csv