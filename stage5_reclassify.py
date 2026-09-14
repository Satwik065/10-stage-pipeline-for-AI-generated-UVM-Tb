#!/usr/bin/env python3
"""Reclassify Stage-5 scores with reason-aware catch semantics.
Reads results/stage5_runs.csv + results/stage5_scores.csv; writes
results/stage5_scores_CORRECTED.csv. Does not touch any frozen artifact."""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent
RES  = ROOT / "results"

DEV_BUGS = {"S-01_const_sym10_i", "S-02_const_sym01_q",
            "S-03_slice_invert_i", "S-05_mod_valid_gate",
            "S-09_ch_q_inversion", "S-11_ch_noise_overload"}
NON_DEV = ["golden",
    "W-01_mod_latency_plus1","W-02_demod_latency_plus1",
    "W-03_mod_idle_zero","W-04_demod_idle_zero",
    "W-05_mod_reset_late","W-06_demod_reset_late",
    "W-07_ch_noise_doubled","W-08_ch_rotation_doubled",
    "W-09_ch_latency_plus1","W-10_ch_idle_zero"]
SEEDS = ["42","1337","9001","271828","314159"]
GENUINE_CATCH = {"result_fail", "uvm_error_in_pass"}

# Load per-run data
runs = {}
with open(RES / "stage5_runs.csv") as f:
    for row in csv.DictReader(f):
        runs[(row["triad"], row["cell"], row["seed"])] = row

# Load prior scores (to preserve COMPILE_FAIL rows and way/model tags)
prior = {}
with open(RES / "stage5_scores.csv") as f:
    for row in csv.DictReader(f):
        prior[row["triad"]] = row

triads = sorted(prior.keys())
with open(RES / "stage5_scores_CORRECTED.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["triad","way","model","T","C_dev","quadrant"])
    for t in triads:
        p = prior[t]
        if p["quadrant"] == "COMPILE_FAIL":
            w.writerow([t, p["way"], p["model"], "0.0000","0.0000","COMPILE_FAIL"])
            continue
        cells = [(k, runs[k]) for k in runs if k[0] == t]
        if not cells:
            w.writerow([t, p["way"], p["model"], "0.0000","0.0000","NO_RUNS"])
            continue
        all_reasons = {r["reason"] for _, r in cells if r["verdict"] == "FAIL"}
        ff = sum(1 for k, r in cells
                 if k[1] in NON_DEV and r["verdict"] == "FAIL")
        T = 1.0 - ff / 55.0
        caught = 0
        for bug in DEV_BUGS:
            n = sum(1 for s in SEEDS
                    if runs[(t, bug, s)]["verdict"] == "FAIL"
                    and runs[(t, bug, s)]["reason"] in GENUINE_CATCH)
            if n >= 3:
                caught += 1
        C_dev = caught / 6.0
        if all_reasons == {"no_result"}:
            q = "RUNTIME_CRASH"
        elif T == 1.0 and C_dev == 1.0:
            q = "Q1_SURVIVOR"
        elif T == 1.0 and C_dev < 1.0:
            q = "Q2_BLIND"
        elif T < 1.0 and C_dev == 1.0:
            q = "Q3_FRAGILE"
        else:
            q = "Q4_DEAD"
        w.writerow([t, p["way"], p["model"], f"{T:.4f}", f"{C_dev:.4f}", q])
print("Wrote results/stage5_scores_CORRECTED.csv")