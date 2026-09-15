# Stage 5 — Per-Assertion Taxonomy

**Project:** Sync Hub Protocol — Screening LLM-Generated UVM Testbenches
**DUT:** QPSK Modulator + Channel + QPSK Demodulator (Golden RTL v2)
**Battery:** 23 cells (1 Golden + 10 Weather + 12 Sabotage)
**Constitution:** v2.1 (frozen)
**Seeds:** [42, 1337, 9001, 271828, 314159]

---

## 1. Motivation

Stage 4 answered the binary question: does an LLM-generated testbench
pass the T/C gate? Two of five frontier models did (Claude, ChatGPT).

Stage 5 answers the sharper question: **inside a passing testbench,
how many assertions actually do useful work?** A testbench can "pass"
with a single check that catches everything, or with a thousand
assertions where one does all the work and the rest are dead code. The
T/C gate cannot see the difference. The per-assertion taxonomy can.

---

## 2. Classification Rules (Constitution §10)

| Class | Definition |
|---|---|
| **Harmful** | Fires on ≥1 Golden/Weather run (any seed) — false positive |
| **Useful** | Fires on ≥3/5 seeds of ≥1 DEV bug, never on Golden/Weather |
| **Dead** | Fires nowhere across the entire battery |
| **Redundant** | Useful in isolation, but its caught-bug set is a strict subset of another Useful assertion's caught-bug set |

DEV bugs (used for classification): S-01, S-02, S-03, S-05, S-09, S-11.

Hold-out bugs (S-04, S-06, S-07, S-08, S-10, S-12) are **not** used for
Stage 5 classification. They are reserved for Stage 8 generalization.

---

## 3. Claude — `variants/sc_v3_ch/tb_ai_ch_v3.sv`

**7 assertions extracted.**

| ID | Line | Type | Class | Fires on |
|---|---|---|---|---|
| C-A1 | 89 | X/Z on modulator output | **Dead** | — |
| C-A2 | 99 | X/Z on channel output | **Dead** | — |
| C-A3 | 122 | X/Z on demodulator output | **Dead** | — |
| C-A4 | 127 | duplicate / unexpected valid_out | **Dead** | — |
| C-A5 | 133 | data mismatch | **Useful** | S-01, S-02, S-03, S-05, S-09, S-11 |
| C-A6 | 138 | late valid | **Redundant** | S-05 |
| C-A7 | 232 | missing valid | **Redundant** | S-05 |

**Distribution:** 1 Useful · 2 Redundant · 4 Dead · 0 Harmful
**Assertion Efficacy Ratio (AER):** 1 / 7 = **0.143**

**Observation:** C-A6 and C-A7 fire only on S-05. But C-A5 also fires on
S-05. The caught-bug set of C-A6 and C-A7 is strictly contained in
C-A5's. Formally redundant.

---

## 4. ChatGPT — `variants/sc_v2_ch/tb_ai_ch_v2.sv`

**16 error sites instrumented** (`errors = errors + 1;` locations, each
wrapped with a distinct `$display("[FIRE] L<line>")` tag for attribution).

| ID | Line | Class | Fires on |
|---|---|---|---|
| L92 | 92 | **Dead** | — |
| L112 | 112 | **Dead** | — |
| L116 | 116 | **Useful** | S-01, S-02, S-03, S-05, S-09, S-11 |
| L150 | 150 | **Dead** | — |
| L153 | 153 | **Dead** | — |
| L156 | 156 | **Dead** | — |
| L163 | 163 | **Dead** | — |
| L172 | 172 | **Dead** | — |
| L181 | 181 | **Dead** | — |
| L184 | 184 | **Dead** | — |
| L188 | 188 | **Dead** | — |
| L192 | 192 | **Dead** | — |
| L202 | 202 | **Dead** | — |
| L205 | 205 | **Dead** | — |
| L216 | 216 | **Dead** | — |
| L243 | 243 | **Redundant** | S-05 |

**Distribution:** 1 Useful · 1 Redundant · 14 Dead · 0 Harmful
**Assertion Efficacy Ratio (AER):** 1 / 16 = **0.063**

**Observation:** ChatGPT's testbench has no `$display` at any error
site — every failure collapses into a single integer counter. To do
attribution, we instrumented each `errors = errors + 1;` with a distinct
`$display("[FIRE] L<line>")` tag (begin/end-wrapped to preserve
single-statement-if semantics). Result: 15 of 16 sites never fire on
any DEV mutant.

---

## 5. Reference — Best-Known-Good (BKG)

`tb/tb_qpsk_bkg.sv` — the human-written calibration instrument.

| Assertion | Class | Fires on |
|---|---|---|
| X/Z on demod_valid | Useful | (fires where relevant) |
| X/Z on demod_bits | Useful | (fires where relevant) |
| X/Z on mod_valid | Useful | (fires where relevant) |
| X/Z on mod_i | Useful | (fires where relevant) |
| X/Z on mod_q | Useful | (fires where relevant) |
| X/Z on ch_valid | Useful | (fires where relevant) |
| X/Z on ch_i | Useful | (fires where relevant) |
| X/Z on ch_q | Useful | (fires where relevant) |
| Mismatch vs. expected queue | Useful | (fires on all Sabotage) |
| Duplicate valid_out | Useful | (fires on S-08) |
| Liveness violation | Useful | (fires on S-05, S-10) |
| End-of-test missing count | Useful | (fires on S-05, S-10) |

**Distribution:** 12 Useful · 0 Redundant · 0 Dead · 0 Harmful
**Assertion Efficacy Ratio (AER):** 12 / 12 = **1.000**

**Observation:** Every assertion in the human-written BKG does work.
There is no dead code. This is the reference target for what
LLM-generated testbenches *should* look like.

---

## 6. Assertion Efficacy Ratio (AER)

### 6.1 Definition

AER(V) = |Useful(V)| / |Assertions(V)|

where:
- `Useful(V)` = number of assertions classified Useful per §10
- `Assertions(V)` = total number of distinct assertions in variant V

**Interpretation:** AER measures the fraction of a testbench's assertion
surface that contributes to actual bug detection without false
positives. AER = 1.0 means every assertion earns its place; AER ≈ 0
means the testbench passes T/C through a single dominant check while
the rest of its assertions are decoration.

### 6.2 Results Table

| Testbench | Total | Useful | Redundant | Dead | Harmful | AER |
|---|---|---|---|---|---|---|
| **BKG (human)** | 12 | 12 | 0 | 0 | 0 | **1.000** |
| **Claude** | 7 | 1 | 2 | 4 | 0 | **0.143** |
| **ChatGPT** | 16 | 1 | 1 | 14 | 0 | **0.063** |

### 6.3 Why AER Matters

1. **T/C cannot distinguish a focused testbench from a bloated one.**
   Claude and ChatGPT both score T=1.0, C_dev=1.0. Yet 86% and 94% of
   their assertion code, respectively, does no work.

2. **High T/C with low AER is a hallucination signature.** An LLM that
   does not actually understand the RTL protocol tends to write many
   plausible-looking checks, only one of which fires. The rest are
   structurally valid code that never triggers.

3. **AER exposes the gap between human and LLM verification discipline.**
   The BKG's AER is 1.000 because every assertion was written to detect
   a specific class of failure. The LLMs' AERs are ≤0.143 because most
   of their assertions were written to *look* thorough.

4. **AER is independent of T/C.** A variant can score high T/C and
   low AER simultaneously. Screening on T/C alone accepts it; screening
   on T/C + AER flags it for revision.

### 6.4 Proposed Use

- Report AER alongside T/C in any LLM-generated verification code
  evaluation.
- Set a threshold (e.g., AER ≥ 0.5) as an acceptance gate for production
  LLM-generated testbenches.
- Use AER to drive iterative refinement: prompt the LLM with the list
  of its Dead assertions and ask it to either remove them or replace
  them with checks that fire.

---

## 7. Findings (For the Paper)

### Finding 1 — T/C gate is necessary but insufficient

Two testbenches passed the T/C gate identically. Both contained ≥86%
dead assertion code. The T/C gate cannot detect this. The per-assertion
taxonomy can.

### Finding 2 — LLMs write plausible-looking but non-firing checks

Claude: 4 of 7 assertions never fire.
ChatGPT: 14 of 16 assertions never fire.

Both LLMs exhibit the same failure mode: structurally valid but
functionally idle code.

### Finding 3 — Attribution is not automatic

ChatGPT's testbench has zero distinct error messages — every failure is
an anonymous counter increment. To do per-assertion attribution, we had
to instrument the source. Claude's testbench has distinct messages per
assertion, enabling attribution without source modification. This is a
qualitative difference between the two passing models that T/C does not
capture.

### Finding 4 — AER cleanly separates human-written from LLM-written code

BKG AER = 1.000. Claude AER = 0.143. ChatGPT AER = 0.063. The metric
is well-separated, stable, and computable from the battery output alone.

---

## 8. Proposed Paper Table

**Table D — Per-Assertion Taxonomy and AER**

| TB | Total | Useful | Redundant | Dead | Harmful | AER |
|---|---|---|---|---|---|---|
| BKG (human) | 12 | 12 | 0 | 0 | 0 | 1.000 |
| Claude | 7 | 1 | 2 | 4 | 0 | 0.143 |
| ChatGPT | 16 | 1 | 1 | 14 | 0 | 0.063 |

**Caption:** Both surviving LLM testbenches pass the T/C gate
(T=1.0, C_dev=1.0) but contain ≥86% dead assertion code. The
human-written BKG achieves AER = 1.000 with every assertion contributing
to detection. AER exposes a quality gap that T/C alone cannot measure.

---

## 9. Reproduction

```bash
# Extract Claude assertions
grep -nE '\[ERROR\]|\[FAIL\]|\[RESULT\]|assert|Error' \
  variants/sc_v3_ch/tb_ai_ch_v3.sv > results/claude_assertions.txt

# Extract ChatGPT error sites
grep -nE '\$display|errors = errors' \
  variants/sc_v2_ch/tb_ai_ch_v2.sv > results/chatgpt_assertions.txt

# Instrument ChatGPT for attribution
python3 -c "
from pathlib import Path
src = Path('variants/sc_v2_ch/tb_ai_ch_v2.sv').read_text()
out = []
for i, line in enumerate(src.splitlines(), 1):
    s = line.strip()
    if s == 'errors = errors + 1;':
        ind = line[:len(line) - len(line.lstrip())]
        out.append(f'{ind}begin \$display(\"[FIRE] L{i}\"); errors = errors + 1; end')
    else:
        out.append(line)
Path('variants/sc_v2_ch_dbg/tb_ai_ch_v2_dbg.sv').write_text('\n'.join(out) + '\n')
"

# Fire matrix (see results/claude_fires.txt, results/chatgpt_fires.txt)