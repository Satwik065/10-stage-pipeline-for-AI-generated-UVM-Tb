#!/usr/bin/env python3
"""Catch semantics v2 recompute.

Reads frozen CSVs only. Applies:
  Catch(triad, bug) = FAIL >=3/5 seeds on bug
                    AND PASS >=3/5 seeds on Golden
                    AND PASS >=3/5 seeds on every Weather cell
Writes:
  results/recompute/b1_scores_v2.csv
  results/recompute/b2_scores_v2.csv
  results/recompute/s6_scores_v2.csv
  results/recompute/summary_v2.txt
"""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT  = ROOT / "results" / "recompute"
OUT.mkdir(parents=True, exist_ok=True)

SEEDS = ["42","1337","9001","271828","314159"]
DEV_BUGS = ["S-01_const_sym10_i","S-02_const_sym01_q",
            "S-03_slice_invert_i","S-05_mod_valid_gate",
            "S-09_ch_q_inversion","S-11_ch_noise_overload"]
WEATHER = ["W-01_mod_latency_plus1","W-02_demod_latency_plus1",
           "W-03_mod_idle_zero","W-04_demod_idle_zero",
           "W-05_mod_reset_late","W-06_demod_reset_late",
           "W-07_ch_noise_doubled","W-08_ch_rotation_doubled",
           "W-09_ch_latency_plus1","W-10_ch_idle_zero"]
NON_DEV = ["golden"] + WEATHER

def load(path):
    with open(path, newline="") as f:
        return list(csv.DictReader(f))

def dominant_pass(runs_by_key, triad, cell):
    """Return True if triad passed >=3/5 seeds on this cell."""
    passes = sum(1 for s in SEEDS
                 if runs_by_key.get((triad, cell, s), {}).get("verdict") == "PASS")
    return passes >= 3

def dominant_fail_genuine(runs_by_key, triad, cell):
    """FAIL >=3/5 seeds AND reason is genuine (not no_result)."""
    genuine = 0
    for s in SEEDS:
        r = runs_by_key.get((triad, cell, s), {})
        if r.get("verdict") == "FAIL" and r.get("reason") in \
           ("result_fail", "uvm_error_in_pass"):
            genuine += 1
    return genuine >= 3

def gate_triad(runs_by_key, triad, cells_for_T=None):
    """Apply v2 semantics. Returns dict with T, C_dev, quadrant."""
    # Golden gate
    if not dominant_pass(runs_by_key, triad, "golden"):
        return dict(T=0.0, C_dev=0.0, quadrant="FAILS_GOLDEN")

    # Weather gate — full weather pass required for T=1.0
    weather_fails = 0
    for w in WEATHER:
        if not dominant_pass(runs_by_key, triad, w):
            weather_fails += 1
    T = 1.0 - weather_fails / len(WEATHER)

    # Catch under v2 — only if T==1.0
    if T != 1.0:
        C = 0.0
    else:
        caught = 0
        for bug in DEV_BUGS:
            if dominant_fail_genuine(runs_by_key, triad, bug):
                caught += 1
        C = caught / 6.0

    # Quadrant
    if T == 1.0 and C == 1.0: q = "Q1_SURVIVOR"
    elif T == 1.0 and C < 1.0: q = "Q2_BLIND"
    elif T < 1.0 and C == 1.0: q = "Q3_FRAGILE"
    elif T == 0.0 and C == 0.0 and weather_fails == len(WEATHER):
        q = "FAILS_EVERYTHING"
    else: q = "Q4_DEAD"
    return dict(T=T, C_dev=C, quadrant=q)

def process(runs_csv, scores_csv, out_csv, label, key_name="triad"):
    runs = load(runs_csv)
    by_key = {}
    for r in runs:
        by_key[(r[key_name], r["cell"], r["seed"])] = r
    triads = sorted({r[key_name] for r in runs})
    out_rows = []
    for t in triads:
        g = gate_triad(by_key, t)
        # Preserve way/model metadata from original scores if present
        model = ""
        try:
            with open(scores_csv, newline="") as f:
                for row in csv.DictReader(f):
                    if row.get(key_name) == t:
                        model = row.get("model", "")
                        break
        except FileNotFoundError:
            pass
        out_rows.append(dict(triad=t, model=model, **g))
    with open(out_csv, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["triad","model","T","C_dev","quadrant"])
        w.writeheader(); w.writerows(out_rows)
    print(f"\n=== {label} ===")
    print(f"{'triad':<24} {'model':<5} {'T':>6} {'C_dev':>7} {'quadrant':<16}")
    for r in out_rows:
        print(f"{r['triad']:<24} {r['model']:<5} {r['T']:>6.3f} "
              f"{r['C_dev']:>7.3f} {r['quadrant']:<16}")
    return out_rows

def main():
    b1 = process(ROOT/"results"/"stage5_runs.csv",
                 ROOT/"results"/"stage5_scores.csv",
                 OUT/"b1_scores_v2.csv", "BATCH 1 v2")
    b2 = process(ROOT/"results"/"b2"/"stage5_runs.csv",
                 ROOT/"results"/"b2"/"stage5_scores.csv",
                 OUT/"b2_scores_v2.csv", "BATCH 2 v2")
    s6 = process(ROOT/"results"/"stage6"/"stage6_runs.csv",
                 ROOT/"results"/"stage6"/"stage6_scores.csv",
                 OUT/"s6_scores_v2.csv", "STAGE 6 v2", key_name="assembly")

    # Summary
    summary = OUT/"summary_v2.txt"
    with open(summary, "w") as f:
        for label, rows in [("BATCH 1", b1), ("BATCH 2", b2), ("STAGE 6", s6)]:
            q1 = sum(1 for r in rows if r["quadrant"] == "Q1_SURVIVOR")
            f.write(f"{label}: {q1}/{len(rows)} Q1 survivors\n")
    print(f"\nSummary written to {summary}")
    print(open(summary).read())

if __name__ == "__main__":
    main()
