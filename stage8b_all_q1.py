#!/usr/bin/env python3
"""Stage 8b — hold-out on ALL Q1 survivors (not just the 9 selected)."""
import csv, re, shutil, subprocess
from pathlib import Path

ROOT     = Path(__file__).resolve().parent
TB_UVM   = ROOT / "tb" / "uvm"
INGESTED = ROOT / "stage4" / "ingested" / "variants"
WORK     = ROOT / "stage8b_work"
RESULTS  = ROOT / "results" / "stage8b"
BINARY   = ROOT / ".uvm_smoke" / "Vqpsk_tb_top"
BUILD    = ROOT / "build_uvm.sh"
BKG_BAK  = WORK / "bkg_backup"

SEEDS = [42, 1337, 9001, 271828, 314159]
TARGET_MAP = {"drv":"qpsk_driver.sv","seq":"qpsk_seq.sv","sb":"qpsk_scoreboard.sv"}
SEALED = ["S-04_slice_swap_iq","S-06_demod_valid_skew","S-07_const_sym00_i",
          "S-08_demod_valid_dup","S-10_ch_drop_valid","S-12_ch_q_zero"]
GENUINE = {"result_fail","uvm_error_in_pass"}

# All Q1 triads from recompute v2 output
Q1 = [
    # Batch-1 Way-1 (3)
    ("b1_cg_v04",   ("cg",4),("cg",4),("cg",4)),
    ("b1_cg_v05",   ("cg",5),("cg",5),("cg",5)),
    ("b1_gm_v03",   ("gm",3),("gm",3),("gm",3)),
    # Batch-1 Way-2 (17)
    ("b1_cg_drv01", ("cg",1),("cg",4),("cg",4)),
    ("b1_cg_drv02", ("cg",2),("cg",4),("cg",4)),
    ("b1_cg_drv03", ("cg",3),("cg",4),("cg",4)),
    ("b1_cg_drv05", ("cg",5),("cg",4),("cg",4)),
    ("b1_cg_sb01",  ("cg",4),("cg",4),("cg",1)),
    ("b1_cg_sb02",  ("cg",4),("cg",4),("cg",2)),
    ("b1_cg_sb03",  ("cg",4),("cg",4),("cg",3)),
    ("b1_cg_sb05",  ("cg",4),("cg",4),("cg",5)),
    ("b1_cg_seq05", ("cg",4),("cg",5),("cg",4)),
    ("b1_gm_drv01", ("gm",1),("gm",3),("gm",3)),
    ("b1_gm_drv02", ("gm",2),("gm",3),("gm",3)),
    ("b1_gm_drv04", ("gm",4),("gm",3),("gm",3)),
    ("b1_gm_drv05", ("gm",5),("gm",3),("gm",3)),
    ("b1_gm_sb01",  ("gm",3),("gm",3),("gm",1)),
    ("b1_gm_sb02",  ("gm",3),("gm",3),("gm",2)),
    ("b1_gm_sb05",  ("gm",3),("gm",3),("gm",5)),
    ("b1_gm_seq04", ("gm",3),("gm",4),("gm",3)),
    # Stage-6 cross-model (6)
    ("s6_X1",       ("gm",3),("cg",4),("cg",4)),
    ("s6_X2",       ("cg",4),("gm",3),("cg",4)),
    ("s6_X3",       ("cg",4),("cg",4),("gm",3)),
    ("s6_X4",       ("cg",4),("gm",3),("gm",3)),
    ("s6_X5",       ("gm",3),("cg",4),("gm",3)),
    ("s6_X6",       ("gm",3),("gm",3),("cg",4)),
]

def pth(m,cat,v):
    return INGESTED / m / f"qpsk_{cat}_{m}_{v:02d}.sv"

def compile_triad(t):
    logdir = WORK / t["id"]; logdir.mkdir(parents=True, exist_ok=True)
    if BINARY.exists(): BINARY.unlink()
    for cat in ["drv","seq","sb"]:
        shutil.copy(pth(*t[cat][:1], cat, t[cat][1]), TB_UVM/TARGET_MAP[cat])
    try:
        r = subprocess.run([str(BUILD)], capture_output=True, text=True,
                           timeout=1800, cwd=str(ROOT))
    except subprocess.TimeoutExpired:
        (logdir/"build.log").write_text("TIMEOUT")
        return False
    (logdir/"build.log").write_text(r.stdout+"\n"+r.stderr)
    return r.returncode == 0 and BINARY.exists()

def run_one(cell, seed, timeout=120):
    try:
        r = subprocess.run(
            [str(BINARY), "+UVM_TESTNAME=qpsk_base_test",
             f"+CHSEED={seed}", f"+SVSEED={seed}", f"+CELL={cell}"],
            capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return dict(verdict="FAIL", reason="timeout", error_count=0)
    log = r.stdout + r.stderr
    m = re.search(r'\[RESULT\]\s+(PASS|FAIL)(?:\s+errors=(\d+))?', log)
    if not m:
        return dict(verdict="FAIL", reason="no_result", error_count=0)
    if m.group(1) == "PASS":
        return dict(verdict="PASS", reason="", error_count=0)
    return dict(verdict="FAIL", reason="result_fail",
                error_count=int(m.group(2) or 0))

def main():
    RESULTS.mkdir(parents=True, exist_ok=True); WORK.mkdir(parents=True, exist_ok=True)
    runs_f = (RESULTS/"stage8b_runs.csv").open("w",newline="")
    runs_w = csv.writer(runs_f)
    runs_w.writerow(["triad","cell","seed","verdict","error_count","reason"])
    sc_f = (RESULTS/"stage8b_scores.csv").open("w",newline="")
    sc_w = csv.writer(sc_f)
    sc_w.writerow(["triad","caught_holdout","C_holdout"])

    BKG_BAK.mkdir(parents=True, exist_ok=True)
    for fn in TARGET_MAP.values():
        shutil.copy2(TB_UVM/fn, BKG_BAK/fn)

    try:
        for tid, d, s, sb in Q1:
            print(f"\n=== {tid} ===")
            t = dict(id=tid, drv=d, seq=s, sb=sb)
            if not compile_triad(t):
                print("  COMPILE_FAIL")
                sc_w.writerow([tid, 0, "0.0000"]); sc_f.flush(); continue
            v = {}
            for cell in SEALED:
                for seed in SEEDS:
                    r = run_one(cell, seed)
                    runs_w.writerow([tid, cell, seed, r["verdict"],
                                     r["error_count"], r["reason"]])
                    v[(cell,seed)] = r
                runs_f.flush()
            caught = sum(1 for cell in SEALED
                         if sum(1 for s_ in SEEDS
                                if v[(cell,s_)]["verdict"]=="FAIL"
                                and v[(cell,s_)]["reason"] in GENUINE) >= 3)
            ch = caught/6.0
            print(f"  C_holdout = {caught}/6 = {ch:.3f}")
            sc_w.writerow([tid, caught, f"{ch:.4f}"]); sc_f.flush()
    finally:
        for fn in TARGET_MAP.values():
            src = BKG_BAK/fn
            if src.exists(): shutil.copy2(src, TB_UVM/fn)
        runs_f.close(); sc_f.close()
        print("\n[RESTORE] BKG restored")

if __name__ == "__main__":
    main()
