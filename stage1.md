# Stage 1 — Contract Lock

**Project:** Sync Hub Protocol — Screening LLM-Generated UVM Testbenches
**DUT:** QPSK Modulator + Channel + QPSK Demodulator (Golden RTL v2)
**Constitution:** v2.1 (frozen), sha256 `6fbd46a0b33138337473660979d4f5d2b0bd8789d3766af3ebc815dddedb3ab5`
**Status:** FROZEN
**Date:** 2026-09-13

---

## 1. Purpose

Stage 1 locks the DUT boundary contract before any AI generation happens
downstream. The contract consists of three artifacts:

| Artifact | Role |
|---|---|
| `contract/interface.sv` | TB-side boundary alias for the 3-module loopback |
| `contract/qpsk_seq_item.sv` | UVM sequence item (stimulus domain) |
| `contract/qpsk_sva.sv` | Protocol-level assertions (P1-P5) |

Per Constitution §1 + Stage 1 spec: contract must (a) match the actual
RTL ports/registers via AST check, (b) survive the testing battery
without false-firing on good behaviour, and (c) never be regenerated
for this DUT once locked.

---

## 2. Artifact Hashes (frozen)

| Artifact | SHA256 |
|---|---|
| `interface.sv` | `4b9c382628c0769710916567b3b633ccac3f19086cf2b2f26f6ed1c3a5455034` |
| `qpsk_seq_item.sv` | `cb70c30085a5f81c1697652f225c69cc8c6ebd040c2bc97872c30a25f9a2babd` |
| `qpsk_sva.sv` | `8ae6211b7feb759b5fa088fb560b9cfc5831c1530aedda99d19108eb3124559c` |
| `contract_manifest.json` | `c67f521533f39814fc745bc35afbbe429f241f915d6ed5e101f0e391f7a3d984` |


---

## 3. Checker Verdict

`stage1_ast_check.py` v2.1-c, run with `--accept-degraded`.

| # | Check | Status |
|---|---|---|
| 1 | `golden:pin_v2.1_s1` | PASS |
| 2 | `golden:qpsk_modulator:ports` | PASS |
| 3 | `golden:qpsk_modulator:ast` | PASS |
| 4 | `golden:qpsk_demodulator:ports` | PASS |
| 5 | `golden:qpsk_demodulator:ast` | PASS |
| 6 | `golden:channel:ports` | PASS |
| 7 | `golden:channel:ast` | PASS |
| 8 | `iface:rename_map_widths` | PASS |
| 9 | `iface:clocking_modports` | PASS |
| 10 | `item:fields` | PASS |
| 11 | `item:structure` | PASS |
| 12 | `sva:ports` | PASS |
| 13 | `sva:assert_ids` | PASS |
| 14 | `sva:constructs` | PASS |
| 15 | `sva:p5_default_off` | PASS |
| 16 | `item:compile_gate` | DEGRADED (accepted) |

**Verdict: PASS.**

`item:compile_gate` is DEGRADED because UVM sources were not available
locally at lock time. The `contract:compile_gate` row (Verilator lint of
`interface.sv` + `qpsk_sva.sv`) is not emitted in degraded mode; it was
run manually and recorded in `contract/compile_gate_manual.txt`.

---

## 4. Contract Assertions

| ID | Type | Class (Stage 5 expected) |
|---|---|---|
| P1 `a_liveness_valid_out` | procedural shift-register liveness bound L=6 | Useful |
| P2 `a_credit_valid_out` | credit-counter: no valid_out without outstanding grant | Useful |
| P3 `a_symbol_domain` | tautological (2-bit vector) | Dead (control) |
| P4 `a_no_xz_outputs` | X/Z check, post-reset window | Verilator 2-state inert |
| P5 `a_valid_in_single_cycle` | 1-cycle pulse rule, gated OFF (back-to-back LEGAL on v2) | OFF |

Data-path mismatch checking is deliberately absent from the contract SVA
— that belongs to the scoreboard / BKG, per §5(b) MISMATCH_BUDGET=0.
Duplicating it in SVA would double-attribute Stage 5 failures.

---

## 5. False-Fire Proof (Stage 1 "new twist")

The contract itself was run through the tolerance lane to prove it does
not false-fire on legal behaviour:

- **Harness:** `tb/tb_p1_check.sv` (Verilator binary sim)
- **Cells:** Golden + W-01, W-02, W-05, W-06, W-09
- **Seeds:** 42, 1337, 9001, 271828, 314159 (all 5 LOCKED_SEEDS)
- **Result:** 30/30 PASS, **0 assertion fires** (P1, P2, P3, P4)

Verilator is the only toolchain used for this proof. Icarus Verilog 12.0
has no concurrent-assertion engine (`sorry: concurrent_assertion_item
not supported`) and cannot evaluate `qpsk_sva.sv`.

---

## 6. Bugs Caught During Stage 1

These are findings the gate itself produced. They document that Stage 1
is not ceremonial — the checker and the contract both had defects that
would have propagated downstream if not caught here.

### 6.1 `stage1_ast_check.py` v2.1-a — comment stripping

RTL port lines with trailing `//` comments
(e.g. `input wire [1:0] bits, // {I_bit,Q_bit}` in `qpsk_modulator.sv`)
silently dropped three ports (`bits`, `i_out`, `q_out`) from the
extracted port map. Caught by `golden:qpsk_modulator:ports` on first run.
Fix: added `_strip_sv_comments()` before regex matching.

### 6.2 v2.1-b — Verilator flag conflict and JSON filename

`--lint-only --json-only` is a Verilator 5.053 mutually-exclusive-flag
error. Removed `--lint-only`; `--json-only` alone performs lint-level
parse + elaboration. Second layer: Verilator 5.053 emits
`V<top>.tree.json` (dot), not the `*__tree.json` (double underscore) the
checker globbed. Fix: glob → `*.tree.json`.

### 6.3 v2.1-c — AST schema mismatch

`ast_collect` assumed top-level `{'nodes': [...]}` with `'children'` keys.
Verilator 5.053 emits a raw top-level dict with `type/name/addr/loc/...`
and children under arbitrary `*sp` keys (`modulesp`, `miscsp`, `stmtsp`,
`varsp`, ...). Fix: walk every dict/list value generically.

### 6.4 v2.1-d — unsatisfiable compile-gate AST check

`contract:compile_gate` compared module names (`"channel"`,
`"qpsk_modulator"`) against the set of `VAR`-node names. Module names are
`MODULE`-type, not `VAR`-type, and none of those modules is instantiated
in the compile (`--top-module qpsk_sva`; interface + SVA only). The check
was unsatisfiable by construction. Fix: verify contract boundary signals
+ P1/P2 internals (`pending_sr`, `credits`) appear in the elaborated AST.

### 6.5 `qpsk_sva.sv` P1 — ranged cycle delay

`valid_in |-> ##[1:LIVENESS_L] valid_out` uses a ranged cycle delay that
Verilator does not support. Replaced with a procedural shift-register
liveness tracker (`pending_sr`).

### 6.6 `qpsk_sva.sv` P1 — queue discipline bug

The shift-register cleared the **lowest** set bit on `valid_out`. Bit
index = age, so the oldest outstanding grant sits at the **highest**
index. On a cycle where `valid_in && valid_out` coincide (which happens
on W-01, W-02, W-09 but not on Golden), the loop discarded the newest
grant instead of the oldest, leaving a phantom grant to age into bit
`LIVENESS_L` and false-fire P1. Caught by the false-fire proof, 15/30
failures (three latency-shifting mutants × 5 seeds).

Fix: reverse loop direction — clear highest set bit, not lowest.

This is the exact class of failure Stage 1's "new twist" was designed
to surface: the gate had to pass the same battery it applies to
everything downstream.

---

## 7. Reproduction

```bash
# AST + interface + structure checks
python3 stage1_ast_check.py \
  --rtl-dir ./rtl --contract-dir ./contract \
  --gen-model claude --gen-temp 0.0 --gen-runs 3 \
  --accept-degraded \
  --manifest ./contract/contract_manifest.json

# False-fire proof (30 cells/seeds)
./run_p1_check.sh

# Manual Verilator elaboration of interface + SVA
verilator --json-only -Wno-fatal --timing \
  --Mdir ./.ast_work/contract \
  --top-module qpsk_sva \
  ./contract/interface.sv ./contract/qpsk_sva.sv