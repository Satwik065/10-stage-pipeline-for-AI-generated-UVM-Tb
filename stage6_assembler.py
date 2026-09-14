#!/usr/bin/env python3
"""Stage 6 — cross-model assembly test.

Holds 2 components at their own model's Q1 baseline, swaps 1 component
to the other model's Q1 baseline. Runs each assembly against the same
17-cell x 5-seed matrix. Reports interaction failure rate.
"""
import csv, json, re, shutil, subprocess, sys
from pathlib import Path

ROOT     = Path(__file__).resolve().parent
TB_UVM   = ROOT / "tb" / "uvm"
INGESTED = ROOT / "stage4" / "ingested" / "variants"
WORK     = ROOT / "stage6_work"
RESULTS  = ROOT / "results" / "stage6"
BINARY   = ROOT / ".uvm_smoke" / "Vqpsk_tb_top"
BUILD    = ROOT / "build_uvm.sh"
BKG_BAK  = WORK / "bkg_backup"

SEEDS = [42, 1337, 9001, 271828, 314159]
CATEGORIES = ["drv", "seq", "sb"]
TARGET_MAP = {"drv": "qpsk_driver.sv", "seq": "qpsk_seq.sv",
              "sb":  "qpsk_scoreboard.sv"}

ACTIVE_CELLS = [
    "golden",
    "W-01_mod_latency_plus1", "W-02_demod_latency_plus1",
    "W-03_mod_idle_zero",     "W-04_demod_idle_zero",
    "W-05_mod_reset_late",    "W-06_demod_reset_late",
    "W-07_ch_noise_doubled",  "W-08_ch_rotation_doubled",
    "W-09_ch_latency_plus1",  "W-10_ch_idle_zero",
    "S-01_const_sym10_i", "S-02_const_sym01_q", "S-03_slice_invert_i",
    "S-05_mod_valid_gate", "S-09_ch_q_inversion", "S-11_ch_noise_overload",
]
DEV_BUGS = {"S-01_const_sym10_i","S-02_const_sym01_q","S-03_slice_invert_i",
            "S-05_mod_valid_gate","S-09_ch_q_inversion","S-11_ch_noise_overload"}
NON_DEV = [c for c in ACTIVE_CELLS if c not in DEV_BUGS]
GENUINE_CATCH = {"result_fail", "uvm_error_in_pass"}

# Baseline components (from Stage 5 Way-2 baselines)
# X1..X3 = swap 1 slot on cg baseline; X4..X6 = swap 1 slot on gm baseline
ASSEMBLIES = [
    # From cg baseline (drv_04, seq_04, sb_04)
    {"id":"X1_cg_drvGm", "drv":("gm",3), "seq":("cg",4), "sb":("cg",4),
     "cross":"drv", "cg_slot":{"drv":("cg",4),"seq":("cg",4),"sb":("cg",4)}},
    {"id":"X2_cg_seqGm", "drv":("cg",4), "seq":("gm",3), "sb":("cg",4),
     "cross":"seq", "cg_slot":{"drv":("cg",4),"seq":("cg",4),"sb":("cg",4)}},
    {"id":"X3_cg_sbGm",  "drv":("cg",4), "seq":("cg",4), "sb":("gm",3),
     "cross":"sb",  "cg_slot":{"drv":("cg",4),"seq":("cg",4),"sb":("cg",4)}},
    # From gm baseline (drv_03, seq_03, sb_03)
    {"id":"X4_gm_drvCg", "drv":("cg",4), "seq":("gm",3), "sb":("gm",3),
     "cross":"drv", "cg_slot":{"drv":("gm",3),"seq":("gm",3),"sb":("gm",3)}},
    {"id":"X5_gm_seqCg", "drv":("gm",3), "seq":("cg",4), "sb":("gm",3),
     "cross":"seq", "cg_slot":{"drv":("gm",3),"seq":("gm",3),"sb":("gm",3)}},
    {"id":"X6_gm_sbCg",  "drv":("gm",3), "seq":("gm",3), "sb":("cg",4),
     "cross":"sb",  "cg_slot":{"drv":("gm",3),"seq":("gm",3),"sb":("gm",3)}},
]

def path_of(m, cat, v):
    return INGESTED / m / f"qpsk_{cat}_{m}_{v:02d}.sv"

def compile_assembly(a):
    logdir = WORK / a["id"]; logdir.mkdir(parents=True, exist_ok=True)
    if BINARY.exists(): BINARY.unlink()
    for cat, fn in TARGET_MAP.items():
        shutil.copy(path_of(a[cat][0], cat, a[cat][1]), TB_UVM / fn)
    try:
        r = subprocess.run([str(BUILD)], capture_output=True, text=True,
                           timeout=1800, cwd=str(ROOT))
    except subprocess.TimeoutExpired:
        (logdir / "build.log").write_text("TIMEOUT")
        return False, "compile_timeout"
    (logdir / "build.log").write_text(r.stdout + "\n" + r.stderr)
    if r.returncode != 0: return False, "compile_error"
    if not BINARY.exists(): return False, "no_binary"
    return True, ""

def run_one(cell, seed, timeout=120):
    try:
        r = subprocess.run(
            [str(BINARY), "+UVM_TESTNAME=qpsk_base_test",
             f"+CHSEED={seed}", f"+SVSEED={seed}", f"+CELL={cell}"],
            capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return {"verdict":"FAIL","reason":"wallclock_timeout","error_count":0}
    log = r.stdout + r.stderr
    m = re.search(r'\[RESULT\]\s+(PASS|FAIL)(?:\s+errors=(\d+))?', log)
    if not m: return {"verdict":"FAIL","reason":"no_result","error_count":0}
    if m.group(1) == "PASS":
        ue = re.findall(r'UVM_ERROR\s*:\s*(\d+)', log)
        if ue and int(ue[-1]) > 0:
            return {"verdict":"FAIL","reason":"uvm_error_in_pass",
                    "error_count":int(ue[-1])}
        return {"verdict":"PASS","reason":"","error_count":0}
    return {"verdict":"FAIL","reason":"result_fail",
            "error_count":int(m.group(2) or 0)}

def score_assembly(a, runs_w, runs_f):
    v = {}
    for cell in ACTIVE_CELLS:
        for seed in SEEDS:
            r = run_one(cell, seed)
            runs_w.writerow([a["id"], a["cross"], cell, seed,
                             r["verdict"], r["error_count"], r["reason"]])
            v[(cell,seed)] = r
        runs_f.flush()
    ff = sum(1 for (c,s),r in v.items()
             if c in NON_DEV and r["verdict"] == "FAIL")
    T = 1.0 - ff/55.0
    caught = sum(1 for bug in DEV_BUGS
                 if sum(1 for s in SEEDS
                        if v[(bug,s)]["verdict"] == "FAIL"
                        and v[(bug,s)]["reason"] in GENUINE_CATCH) >= 3)
    C = caught/6.0
    if   T==1.0 and C==1.0: q = "Q1_SURVIVOR"
    elif T==1.0 and C<1.0:  q = "Q2_BLIND"
    elif T<1.0 and C==1.0:  q = "Q3_FRAGILE"
    else:                   q = "Q4_DEAD"
    return dict(id=a["id"], cross=a["cross"], T=T, C_dev=C, quadrant=q)

def main():
    RESULTS.mkdir(parents=True, exist_ok=True); WORK.mkdir(parents=True, exist_ok=True)
    runs_f = (RESULTS / "stage6_runs.csv").open("w", newline="")
    runs_w = csv.writer(runs_f)
    runs_w.writerow(["assembly","cross_slot","cell","seed","verdict",
                     "error_count","reason"])
    sc_f = (RESULTS / "stage6_scores.csv").open("w", newline="")
    sc_w = csv.writer(sc_f)
    sc_w.writerow(["assembly","cross_slot","T","C_dev","quadrant"])

    def backup_bkg():
        BKG_BAK.mkdir(parents=True, exist_ok=True)
        for fn in TARGET_MAP.values():
            shutil.copy2(TB_UVM / fn, BKG_BAK / fn)
    backup_bkg()

    results = []
    try:
        for a in ASSEMBLIES:
            print(f"\n=== {a['id']} (cross={a['cross']}) ===")
            ok, why = compile_assembly(a)
            if not ok:
                print(f"  COMPILE_FAIL ({why})")
                sc_w.writerow([a["id"], a["cross"], "0.0000","0.0000","COMPILE_FAIL"])
                sc_f.flush(); continue
            s = score_assembly(a, runs_w, runs_f)
            print(f"  T={s['T']:.3f}  C_dev={s['C_dev']:.3f}  {s['quadrant']}")
            sc_w.writerow([s["id"], s["cross"],
                           f"{s['T']:.4f}", f"{s['C_dev']:.4f}", s["quadrant"]])
            sc_f.flush(); results.append(s)
    finally:
        for fn in TARGET_MAP.values():
            src = BKG_BAK / fn
            if src.exists(): shutil.copy2(src, TB_UVM / fn)
        runs_f.close(); sc_f.close()

    attempted = len(results) + sum(1 for a in ASSEMBLIES
                                    if not any(r["id"]==a["id"] for r in results))
    survived = sum(1 for r in results if r["quadrant"] == "Q1_SURVIVOR")
    failed = len(ASSEMBLIES) - survived
    print(f"\nInteraction failure rate: {failed}/{len(ASSEMBLIES)}")
    print(f"Q1 survivors: {survived}/{len(ASSEMBLIES)}")

if __name__ == "__main__":
    main()