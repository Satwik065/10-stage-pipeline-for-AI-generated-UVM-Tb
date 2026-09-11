#!/usr/bin/env python3
"""Stage 3 calibration gate (Constitution v1.5 §9).
Compiles tb_qpsk_bkg.sv against Golden + all 14 mutants, runs 5 LOCKED_SEEDS
per cell, parses ONLY the [RESULT] line, prints the 15-cell matrix, exits
non-zero on ANY mismatch. Golden must PASS, W-01..W-06 must PASS,
S-01..S-08 must FAIL — all seeds, no exceptions. Wall-clock (120 s) is an
infrastructure net only: timeout => INVALID, retried exactly once (§5)."""
import argparse, csv, json, subprocess, sys, hashlib
from pathlib import Path

SEEDS = [42, 1337, 9001, 271828, 314159]   # Constitution §4 — do not edit
WALLCLOCK_S = 120                          # §5 infra net, never a verdict
COMPILE_TIMEOUT_S = 120

def sha256_file(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def run_seed(sim, seed):
    """Returns 'PASS' | 'FAIL' | 'NO_RESULT' | 'INVALID_TIMEOUT'."""
    try:
        r = subprocess.run(["vvp", str(sim), f"+SVSEED={seed}"],
                           capture_output=True, text=True, timeout=WALLCLOCK_S)
    except subprocess.TimeoutExpired:
        return "INVALID_TIMEOUT"
    results = [l.strip() for l in r.stdout.splitlines() if l.startswith("[RESULT]")]
    if not results:
        return "NO_RESULT"
    return "PASS" if results[-1] == "[RESULT] PASS" else "FAIL"

def compile_cell(tb, srcs, workdir):
    workdir.mkdir(parents=True, exist_ok=True)
    sim = workdir / "sim.vvp"
    cmd = ["iverilog", "-g2012", "-o", str(sim), tb] + [str(s) for s in srcs]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True,
                           timeout=COMPILE_TIMEOUT_S)
    except subprocess.TimeoutExpired:
        return None, "COMPILE_TIMEOUT"
    if r.returncode != 0:
        return None, "COMPILE_ERROR:\n" + r.stderr.strip()[-800:]
    return sim, None

def evaluate_cell(cell_id, lane, expected, tb, srcs, workdir, rows):
    sim, err = compile_cell(tb, srcs, workdir)
    if sim is None:
        print(f"{cell_id:<32} {lane:<9} exp={expected:<5} COMPILE/ELAB FAILURE "
              f"(§5: attributed, never retried) -> GATE FAIL\n{err}")
        rows.append(dict(cell=cell_id, lane=lane, expected=expected,
                         actual="COMPILE_ERROR", ok="False"))
        return False
    verdicts = []
    for seed in SEEDS:
        v = run_seed(sim, seed)
        if v == "INVALID_TIMEOUT":     # §5: retry exactly once, PER SEED
            v = run_seed(sim, seed)
        verdicts.append(v)
    scored = [v for v in verdicts if v in ("PASS", "FAIL")]
    ok = (len(scored) == len(SEEDS)
          and all(v == expected for v in scored)
          and all(v != "NO_RESULT" and v != "INVALID_TIMEOUT" for v in verdicts))
    np = scored.count("PASS"); nf = scored.count("FAIL")
    detail = " ".join("P" if v == "PASS" else "F" if v == "FAIL" else v[0] + "?"
                      for v in verdicts)
    print(f"{cell_id:<32} {lane:<9} exp={expected:<5} act={detail:<12} "
          f"({np}P/{nf}F) {'OK' if ok else 'GATE FAIL'}")
    rows.append(dict(cell=cell_id, lane=lane, expected=expected,
                     actual=detail, ok=str(ok)))
    return ok

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rtl-dir", default="./rtl")
    ap.add_argument("--mutants-dir", default="./mutants")
    ap.add_argument("--tb", default="tb/tb_qpsk_bkg.sv")
    ap.add_argument("--workdir", default="./cal_work")
    a = ap.parse_args()
    rtl, mdir = Path(a.rtl_dir), Path(a.mutants_dir)
    MOD, DEM = "qpsk_modulator.sv", "qpsk_demodulator.sv"
    battery = json.loads((mdir / "battery.json").read_text())

    # §12 provenance: battery must have been built from these exact golden files
    for f, h in battery["golden"].items():
        if sha256_file(rtl / f) != h:
            sys.exit(f"[FATAL] {f} no longer matches battery.json golden hash — "
                     f"Golden RTL drifted; battery rebuild + constitution v2 required")
    for m in battery["mutants"]:
        man = json.loads((mdir / m["id"] / "manifest.json").read_text())
        if sha256_file(rtl / man["target_file"]) != man["golden_source_sha256"]:
            sys.exit(f"[FATAL] {m['id']} manifest golden hash mismatch — rebuild battery")

    work = Path(a.workdir)
    rows, all_ok = [], True
    cells = [("golden", "golden", "PASS", [rtl / MOD, rtl / DEM])]
    for m in battery["mutants"]:
        other = DEM if m["target_file"] == MOD else MOD
        srcs = [rtl / other, mdir / m["id"] / m["target_file"]]
        cells.append((m["id"], m["lane"], m["expected_verdict"], srcs))

    for cell_id, lane, expected, srcs in cells:
        all_ok &= evaluate_cell(cell_id, lane, expected, a.tb, srcs,
                                work / cell_id, rows)

    with open(mdir / "calibration.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["cell", "lane", "expected", "actual", "ok"])
        w.writeheader(); w.writerows(rows)

    print(f"\nCELLS: {sum(1 for r in rows if r['ok']=='True')}/{len(rows)} matched")
    print("CALIBRATION: PASS — battery certified, proceed to Stage 4"
          if all_ok else
          "CALIBRATION: FAIL — the battery is broken. Fix the battery, never the BKG (§9).")
    sys.exit(0 if all_ok else 1)

if __name__ == "__main__":
    main()