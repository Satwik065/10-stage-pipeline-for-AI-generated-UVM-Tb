#!/usr/bin/env python3
"""Stage 3 calibration gate (Constitution v2.0 §9).
Compiles tb + {golden|mutant} sources per cell, runs 5 LOCKED_SEEDS,
parses ONLY the [RESULT] line, prints the 19-cell matrix (1 golden +
10 Weather + 12 Sabotage), exits non-zero on ANY mismatch.
v2.0: channel.sv treated as a first-class DUT component (not harness).
Every cell compiles: tb + golden(mod,dem,ch) with the mutated file
swapped in for its golden counterpart."""
import argparse, csv, json, subprocess, sys, hashlib
from pathlib import Path

SEEDS = [42, 1337, 9001, 271828, 314159]
WALLCLOCK_S = 120
COMPILE_TIMEOUT_S = 120

def sha256_file(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def run_seed(sim, seed):
    try:
        r = subprocess.run(["vvp", str(sim),
                            f"+SVSEED={seed}", f"+CHSEED={seed}"],
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
        if v == "INVALID_TIMEOUT":
            v = run_seed(sim, seed)
        verdicts.append(v)
    scored = [v for v in verdicts if v in ("PASS", "FAIL")]
    ok = (len(scored) == len(SEEDS)
          and all(v == expected for v in scored)
          and all(v not in ("NO_RESULT", "INVALID_TIMEOUT") for v in verdicts))
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
    ap.add_argument("--tb", default="variants/sc_v5_ch/tb_ai_ch_v5.sv")
    ap.add_argument("--workdir", default="./cal_work")
    a = ap.parse_args()
    rtl, mdir = Path(a.rtl_dir), Path(a.mutants_dir)
    MOD, DEM, CH = "qpsk_modulator.sv", "qpsk_demodulator.sv", "channel.sv"
    battery = json.loads((mdir / "battery.json").read_text())

    # §12 provenance: verify golden hashes
    for f, h in battery["golden"].items():
        if sha256_file(rtl / f) != h:
            sys.exit(f"[FATAL] {f} drifted — battery rebuild + constitution bump required")
    for m in battery["mutants"]:
        man = json.loads((mdir / m["id"] / "manifest.json").read_text())
        if sha256_file(rtl / man["target_file"]) != man["golden_source_sha256"]:
            sys.exit(f"[FATAL] {m['id']} manifest golden hash mismatch")

    golden_files = [rtl / MOD, rtl / DEM, rtl / CH]
    work = Path(a.workdir)
    rows, all_ok = [], True

    # Build cells
    cells = [("golden", "golden", "PASS", golden_files)]
    for m in battery["mutants"]:
        # Swap golden target for mutant version
        srcs = [s for s in golden_files if s.name != m["target_file"]]
        srcs.append(mdir / m["id"] / m["target_file"])
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