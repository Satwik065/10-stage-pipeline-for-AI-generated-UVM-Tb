#!/usr/bin/env python3
"""Ablation B — No Weather Lane."""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT  = ROOT / "results" / "ablations"
OUT.mkdir(parents=True, exist_ok=True)

SOURCES = [
    ("b1_way1", ROOT / "results" / "stage5_scores.csv"),
    ("b2_way1", ROOT / "results" / "b2" / "stage5_scores.csv"),
    ("stage6",  ROOT / "results" / "stage6" / "stage6_scores.csv"),
]

def load(path):
    if not path.exists(): return []
    with open(path, newline="") as f:
        return list(csv.DictReader(f))

def classify(row):
    T = float(row.get("T", 0) or 0)
    C = float(row.get("C_dev", 0) or 0)
    mutation_pass = (C == 1.0)
    full_pass     = (T == 1.0 and C == 1.0)
    false_accept  = mutation_pass and not full_pass
    return dict(mutation_pass=mutation_pass, full_pass=full_pass,
                false_accept=false_accept, T=T, C_dev=C,
                quadrant=row.get("quadrant",""))

def main():
    summary = {}
    out_rows = []
    print(f"{'source':<10} {'triad':<24} {'T':>6} {'C_dev':>7} "
          f"{'quadrant':<16} mut full")
    print("-"*80)
    for source, path in SOURCES:
        rows = load(path)
        if not rows:
            print(f"  [skip] {source} missing {path}")
            continue
        c = dict(total=0, mutation_pass=0, full_pass=0, false_accept=0)
        for r in rows:
            triad = r.get("triad","?")
            res = classify(r)
            c["total"] += 1
            c["mutation_pass"] += int(res["mutation_pass"])
            c["full_pass"] += int(res["full_pass"])
            c["false_accept"] += int(res["false_accept"])
            if res["mutation_pass"] or res["full_pass"]:
                print(f"{source:<10} {triad:<24} {res['T']:>6.4f} "
                      f"{res['C_dev']:>7.4f} {res['quadrant']:<16} "
                      f"{'P' if res['mutation_pass'] else ' ':>3} "
                      f"{'P' if res['full_pass'] else ' ':>4}")
            out_rows.append(dict(source=source, triad=triad, **res))
        summary[source] = c
    print()
    print("="*80)
    print(f"{'source':<10} {'triads':>7} {'mut_only':>10} "
          f"{'full_gate':>10} {'false_accept':>13}")
    print("-"*80)
    for src, c in summary.items():
        print(f"{src:<10} {c['total']:>7} {c['mutation_pass']:>10} "
              f"{c['full_pass']:>10} {c['false_accept']:>13}")
    out = OUT / "ablation_B_no_weather.csv"
    with open(out, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(out_rows[0].keys()))
        w.writeheader(); w.writerows(out_rows)
    print(f"\nWrote {out}")

if __name__ == "__main__":
    main()
