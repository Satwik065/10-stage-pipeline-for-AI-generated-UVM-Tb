# Stage 10 — Human Handoff

**Status:** DELIVERED
**Date:** 2026-09-14

## Deliverable

`deliverables/` — a UVM 1.2 testbench verified to
T=1.0, C_dev=1.0, C_holdout=1.0, gap=0.0 across all 23 battery
cells × 5 seeds.

## Contents

    deliverables/
    ├── HANDOFF.md                  engineer-facing write-up
    ├── stage7_notes.md             coverage N/A disclosure
    ├── winning_testbench/          verified TB (13 files)
    │   ├── qpsk_driver.sv          (ChatGPT cg_v04)
    │   ├── qpsk_seq.sv             (ChatGPT cg_v04)
    │   ├── qpsk_scoreboard.sv      (ChatGPT cg_v04)
    │   ├── qpsk_pkg.sv             (Stage 2 mechanical)
    │   ├── qpsk_monitor.sv         (Stage 2 mechanical)
    │   ├── qpsk_agent.sv           (Stage 2 mechanical)
    │   ├── qpsk_env.sv             (Stage 2 mechanical)
    │   ├── qpsk_base_test.sv       (Stage 2 mechanical)
    │   ├── qpsk_tb_top.sv          (Stage 2 mechanical)
    │   ├── dut_cells.sv            (23-cell merged DUT)
    │   ├── interface.sv            (Stage 1 contract)
    │   ├── qpsk_seq_item.sv        (Stage 1 contract)
    │   └── build_uvm.sh
    └── reports/                    (8 files)
        ├── stage5_b1_scores.csv
        ├── stage5_b2_scores.csv
        ├── stage6_scores.csv
        ├── stage8_scores.csv
        ├── stage5_b1_runs.csv
        ├── stage8_runs.csv
        ├── variants_manifest_b1.json
        ├── variants_manifest_b2.json
        └── provenance_summary.txt

## What the engineer gets

- A testbench that runs on Verilator 5.053 + UVM 1.2
- A merged DUT netlist with 23 selectable cells
- Full metric history, hash-anchored at every pipeline stage
- No need to re-debug AI hallucinations — the pipeline screened them

## What the engineer does NOT get

- Register Abstraction Layer (v2 DUT has no registers)
- Coverage instrumentation (Stage 7 N/A)
- Formal verification harness (out of scope)

## Change Control

Frozen upon commit. All Stage 1-9 artifacts referenced by hash.
