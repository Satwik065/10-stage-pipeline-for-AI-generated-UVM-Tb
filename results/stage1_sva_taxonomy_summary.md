# Stage 1 — Contract SVA Per-Assertion Taxonomy

## Fire matrix

| Cell | Fired assertions |
|---|---|
| S-05_mod_valid_gate | P1 (liveness) |
| S-08_demod_valid_dup | P2 (credit) |
| S-10_ch_drop_valid | P1 (liveness) |
| All other 20 cells | (silent) |

## Classification

| ID | Purpose | Strict | Loose | Note |
|---|---|---|---|---|
| P1 | liveness bound | Useful | Useful | fires on S-05 (DEV), S-10 (hold-out) |
| P2 | credit model | Dead   | Useful | fires on S-08 (hold-out) — strict taxonomy ignores hold-out |
| P3 | symbol domain | Dead | Dead | tautology — documented as known-dead control |
| P4 | X/Z check | Dead | Dead | Verilator 2-state-inert — documented |
| P5 | pulse rule | Dead | Dead | gated OFF — back-to-back valid legal on this DUT |

## AER

- Strict (DEV-only useful): 1/5 = **0.20**
- Loose (any Sabotage useful): 2/5 = **0.40**
- Excluding documented-off controls (P3, P4, P5): 2/2 = **1.00**

## Comparison

| Artifact | AER (loose) |
|---|---|
| Human contract SVA (this stage) | **0.40** |
| AI cg_v04 scoreboard (workshop) | 0.14 |
| AI cg_v05 scoreboard (workshop) | 0.06 |
| Human BKG (workshop) | 1.00 |

The human-designed SVA sits between AI-generated scoreboards and the
human BKG. Its low absolute AER reflects three deliberate control
assertions; excluding those, every firing assertion earns its place.
