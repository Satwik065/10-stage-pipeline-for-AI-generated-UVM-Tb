#!/usr/bin/env python3
"""Stage 8 — hold-out generalization.

Runs Q1 survivors against the 6 SEALED Sabotage cells for the first time.
Reports C_holdout per triad and the generalization gap (C_dev - C_holdout).
C_dev was already 1.0 for all Q1 triads by construction (§6 gate).
"""
import csv, re, shutil, subprocess, sys
from pathlib import Path

ROOT     = Path(__file__).resolve().parent
TB_UVM   = ROOT / "tb" / "uvm"
INGESTED = ROOT / "stage4" / "ingested" / "variants"
WORK     = ROOT / "stage8_work"
RESULTS  = ROOT / "results" / "stage8"
BINARY   = ROOT / ".uvm_smoke" / "Vqpsk_tb_top"
BUILD    = ROOT / "build_uvm.sh"
BKG_BAK  = WORK / "bkg_backup"

SEEDS = [42, 1337, 9001, 271828, 314159]
TARGET_MAP = {"drv":"qpsk_driver.sv","seq":"qpsk_seq.sv",
              "sb":"qpsk_scoreboard.sv"}

SEALED_CELLS = [
    "S-04_slice_swap_iq", "S-06_demod_valid_skew",
    "S-07_const_sym00_i", "S-08_demod_valid_dup",
    "S-10_ch_drop_valid", "S-12_ch_q_zero",
]

# Q1 triads: 3 from batch-1 Way-1, 6 from Stage-6 assemblies
Q1_TRIADS = [
    # batch-1 Way-1 Q1 survivors
    {"id":"q1_cg_v04","drv":("cg",4),"seq":("cg",4),"sb":("cg",4),"origin":"way1"},
    {"id":"q1_cg_v05","drv":("cg",5),"seq":("cg",5),"sb":("cg",5),"origin":"way1"},
    {"id":"q1_gm_v03","drv":("gm",3),"seq":("gm",3),"sb":("gm",3),"origin":"way1"},
    # Stage-6 cross-model assemblies
    {"id":"q1_X1_cg_drvGm","drv":("gm",3),"seq":("cg",4),"sb":("cg",4),"origin":"stage6"},
    {"id":"q1_X2_cg_seqGm","drv":("cg",4),"seq":("gm",3),"sb":("cg",4),"origin":"stage6"},
    {"id":"q1_X3_cg_sbGm", "drv":("cg",4),"seq":("cg",4),"sb":("gm",3),"origin":"stage6"},
    {"id":"q1_X4_gm_drvCg","drv":("cg",4),"seq":("gm",3),"sb":("gm",3),"origin":"stage6"},
    {"id":"q1_X5_gm_seqCg","drv":("gm",3),"seq":("cg",4),"sb":("gm",3),"origin":"stage6"},
    {"id":"q1_X6_gm_sbCg", "drv":("gm",3),"seq":("gm",3),"sb":("cg",4),"origin":"stage6"},
]

def path_of(m, cat, v):
    return INGESTED / m / f"qpsk_{cat}_{m}_{v:02d}.sv"

def compile_triad(t):
    logdir = WORK / t["id"]; logdir.mkdir(parents=True, exist_ok=True)
    if BINARY.exists(): BINARY.unlink()
    for cat, fn in TARGET_MAP.items():
        shutil.copy(path_of(t[cat][0], cat, t[cat][1]), TB_UVM / fn)
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
    if not m:
        return {"verdict":"FAIL","reason":"no_result","error_count":0}
    if m.group(1) == "PASS":
        ue = re.findall(r'UVM_ERROR\s*:\s*(\d+)', log)
        if ue and int(ue[-1]) > 0:
            return {"verdict":"FAIL","reason":"uvm_error_in_pass",
                    "error_count":int(ue[-1])}
        return {"verdict":"PASS","reason":"","error_count":0}
    return {"verdict":"FAIL","reason":"result_fail",
            "error_count":int(m.group(2) or 0)}

def run_matrix(t, runs_w, runs_f):
    v = {}
    for cell in SEALED_CELLS:
        for seed in SEEDS:
            r = run_one(cell, seed)
            runs_w.writerow([t["id"], t["origin"], cell, seed,
                             r["verdict"], r["error_count"], r["reason"]])
            v[(cell,seed)] = r
        runs_f.flush()
    caught = 0
    for cell in SEALED_CELLS:
        fails = sum(1 for s in SEEDS
                    if v[(cell,s)]["verdict"] == "FAIL"
                    and v[(cell,s)]["reason"] in {"result_fail","uvm_error_in_pass"})
        if fails >= 3: caught += 1
    C_holdout = caught / 6.0
    return dict(id=t["id"], origin=t["origin"],
                caught=caught, C_holdout=C_holdout)

def main():
    RESULTS.mkdir(parents=True, exist_ok=True); WORK.mkdir(parents=True, exist_ok=True)

    runs_f = (RESULTS / "stage8_runs.csv").open("w", newline="")
    runs_w = csv.writer(runs_f)
    runs_w.writerow(["triad","origin","cell","seed","verdict",
                     "error_count","reason"])
    sc_f = (RESULTS / "stage8_scores.csv").open("w", newline="")
    sc_w = csv.writer(sc_f)
    sc_w.writerow(["triad","origin","caught_holdout","C_holdout",
                   "C_dev_assumed","generalization_gap"])

    def backup_bkg():
        BKG_BAK.mkdir(parents=True, exist_ok=True)
        for fn in TARGET_MAP.values():
            shutil.copy2(TB_UVM / fn, BKG_BAK / fn)
    backup_bkg()

    try:
        for t in Q1_TRIADS:
            print(f"\n=== {t['id']} ({t['origin']}) ===")
            ok, why = compile_triad(t)
            if not ok:
                print(f"  COMPILE_FAIL ({why})")
                sc_w.writerow([t["id"], t["origin"], 0, "0.0000",
                               "1.0000", "1.0000"])
                sc_f.flush(); continue
            s = run_matrix(t, runs_w, runs_f)
            gap = 1.0 - s["C_holdout"]   # C_dev is 1.0 by Q1 gate definition
            print(f"  C_holdout={s['C_holdout']:.3f} "
                  f"({s['caught']}/6) gap={gap:+.3f}")
            sc_w.writerow([s["id"], s["origin"], s["caught"],
                           f"{s['C_holdout']:.4f}", "1.0000", f"{gap:+.4f}"])
            sc_f.flush()
    finally:
        for fn in TARGET_MAP.values():
            src = BKG_BAK / fn
            if src.exists(): shutil.copy2(src, TB_UVM / fn)
        runs_f.close(); sc_f.close()
        print("\n[RESTORE] BKG restored to tb/uvm/")

if __name__ == "__main__":
    main()