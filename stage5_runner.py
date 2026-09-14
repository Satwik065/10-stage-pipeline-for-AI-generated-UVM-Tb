#!/usr/bin/env python3
"""stage5_runner.py — Way-1 + Way-2 triad runner for Stage 5.

Reads INGESTED variants from stage4/ingested/variants/<model>/
Builds Way-1 triads (matched version indices per model), runs the
17-cell x 5-seed matrix, scores T / C_dev / quadrant, then selects each
model's Way-2 baseline with the FROZEN rule (protocol 6.2: C_dev desc ->
T desc -> lowest version-sum; C_holdout never touches selection because
hold-out cells are never executed here) and runs leave-one-out swaps
(protocol 6.3). Emits stage5_runs.csv, stage5_scores.csv,
way2_attribution.csv.

Constitution/protocol compliance:
  * Sealed cells (S-04,S-06,S-07,S-08,S-10,S-12) are ASSERTED absent
    from ACTIVE_CELLS and the exclusion is logged (protocol 5).
  * Compile failure = T=0, C_dev=0, never retried (Const. 5).
  * Wall-clock timeout = INVALID -> retried exactly once PER SEED
    (Const. 5 infra list); timeout-after-retry = variant-attributed
    FAIL (operationalization P5-R1, pre-registered before first run).
  * Missing [RESULT] = FAIL, never retried (Const. 5).
  * Binary freshness guard: binary is deleted before every build and
    asserted present after — a triad can never be scored against a
    previous triad's binary.
  * BKG driver/seq/scoreboard are backed up before the sweep and
    restored in a finally block.

Zero LLM in the loop. Resume-safe: existing stage5_scores.csv rows are
honored; already-scored triads are skipped (delete the CSVs for a clean run)."""
import csv, json, re, shutil, subprocess, sys
from pathlib import Path

ROOT     = Path(__file__).resolve().parent
TB_UVM   = ROOT / "tb" / "uvm"
INGESTED = ROOT / "stage4" / "ingested" / "variants"
MANIFEST = ROOT / "variants_manifest.json"
WORK     = ROOT / "stage5_work"
RESULTS  = ROOT / "results"
BINARY   = ROOT / ".uvm_smoke" / "Vqpsk_tb_top"
BUILD    = ROOT / "build_uvm.sh"
BKG_BAK  = WORK / "bkg_backup"

MODELS, CATEGORIES = ["cg", "qw", "gm"], ["drv", "seq", "sb"]
SEEDS = [42, 1337, 9001, 271828, 314159]

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
SEALED_CELLS = ["S-04_slice_swap_iq", "S-06_demod_valid_skew",
                "S-07_const_sym00_i", "S-08_demod_valid_dup",
                "S-10_ch_drop_valid", "S-12_ch_q_zero"]
DEV_BUGS = {"S-01_const_sym10_i", "S-02_const_sym01_q", "S-03_slice_invert_i",
            "S-05_mod_valid_gate", "S-09_ch_q_inversion", "S-11_ch_noise_overload"}
NON_DEV = [c for c in ACTIVE_CELLS if c not in DEV_BUGS]          # 11 cells
TARGET_MAP = {"drv": "qpsk_driver.sv", "seq": "qpsk_seq.sv",
              "sb":  "qpsk_scoreboard.sv"}

# ---------------------------------------------------------------- discovery
def discover():
    pool, pools = {}, {}
    for m in MODELS:
        for c in CATEGORIES:
            vs = []
            for v in range(1, 6):
                p = INGESTED / m / f"qpsk_{c}_{m}_{v:02d}.sv"
                if p.exists():
                    pool[(m, c, v)] = p
                    vs.append(v)
                else:
                    print(f"[MISSING] {p}", file=sys.stderr)
            pools[(m, c)] = vs
    return pool, pools

def filter_by_manifest(pool):
    if not MANIFEST.exists():
        return pool
    man = json.loads(MANIFEST.read_text())
    clean = {}
    for k, p in pool.items():
        e = man.get(p.name, {})
        if e.get("lint_status") == "OK" and \
           not str(e.get("dedup_class", "unique")).startswith("duplicate_of"):
            clean[k] = p
        else:
            print(f"[EXCLUDE] {p.name}: {e.get('lint_status')} / {e.get('dedup_class')}")
    return clean

def way1_triads(pool):
    triads = []
    for m in MODELS:
        for v in range(1, 6):
            if all((m, c, v) in pool for c in CATEGORIES):
                triads.append(dict(id=f"{m}_v{v:02d}", model=m, way="way1",
                                   components={"drv": v, "seq": v, "sb": v}))
    return triads

def way2_swaps(baselines, pool):
    """baselines: model -> version int (Way-1 winner). One slot swapped at a
    time, up to 4 alternatives per category -> max 12 per model (protocol 6.3)."""
    triads = []
    for m, bv in baselines.items():
        for cat in CATEGORIES:
            for v in range(1, 6):
                if v == bv or (m, cat, v) not in pool:
                    continue
                comp = {"drv": bv, "seq": bv, "sb": bv}
                comp[cat] = v
                triads.append(dict(id=f"{m}_w2_{cat}{v:02d}", model=m, way="way2",
                                   components=comp, swap_cat=cat, swap_ver=v))
    return triads

# ---------------------------------------------------------------- compile
def compile_triad(t, pool):
    logdir = WORK / t["id"]; logdir.mkdir(parents=True, exist_ok=True)
    if BINARY.exists():
        BINARY.unlink()                       # freshness guard: no stale scoring
    for cat, fn in TARGET_MAP.items():
        shutil.copy(pool[(t["model"], cat, t["components"][cat])], TB_UVM / fn)
    try:
        r = subprocess.run([str(BUILD)], capture_output=True, text=True,
                           timeout=1800, cwd=str(ROOT))
    except subprocess.TimeoutExpired:
        (logdir / "build.log").write_text("BUILD WALL-CLOCK TIMEOUT (1800s)")
        return False, "compile_timeout"
    (logdir / "build.log").write_text(r.stdout + "\n" + r.stderr)
    if r.returncode != 0:
        return False, "compile_error"
    if not BINARY.exists():
        return False, "no_binary_after_build"
    return True, ""

# ---------------------------------------------------------------- run one
def run_one(cell, seed, timeout=120):
    try:
        r = subprocess.run(
            [str(BINARY), "+UVM_TESTNAME=qpsk_base_test",
             f"+CHSEED={seed}", f"+SVSEED={seed}", f"+CELL={cell}"],
            capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return {"verdict": "INVALID", "error_count": 0,
                "reason": "wallclock_timeout"}          # infra -> retry once
    log = r.stdout + r.stderr
    m = re.search(r'\[RESULT\]\s+(PASS|FAIL)(?:\s+errors=(\d+))?', log)
    if not m:
        return {"verdict": "FAIL", "error_count": 0,
                "reason": "no_result"}                  # never retried (Const.5)
    if m.group(1) == "PASS":
        ue = re.findall(r'UVM_ERROR\s*:\s*(\d+)', log)  # summary line only
        if ue and int(ue[-1]) > 0:                      # last = report summary
            return {"verdict": "FAIL", "error_count": int(ue[-1]),
                    "reason": "uvm_error_in_pass"}
        return {"verdict": "PASS", "error_count": 0, "reason": ""}
    return {"verdict": "FAIL", "error_count": int(m.group(2) or 0),
            "reason": "result_fail"}

def run_cell(cell, seed):
    """Constitution 5: wall-clock timeout is an infra fault -> retry exactly
    once, per seed. Still timing out -> variant-attributed FAIL (P5-R1)."""
    r = run_one(cell, seed)
    if r["reason"] == "wallclock_timeout":
        r = run_one(cell, seed)
        if r["verdict"] == "INVALID":
            return {"verdict": "FAIL", "error_count": 0,
                    "reason": "timeout_after_retry"}
    return r

# ---------------------------------------------------------------- scoring
def run_matrix(t, pool, runs_w, runs_f):
    v, retried = {}, 0
    for cell in ACTIVE_CELLS:
        for seed in SEEDS:
            r = run_cell(cell, seed)
            if "after_retry" in r["reason"]:
                retried += 1
            runs_w.writerow([t["id"], t["way"], t["model"], cell, seed,
                             r["verdict"], r.get("error_count", 0),
                             r.get("reason", "")])
            v[(cell, seed)] = r
        runs_f.flush()
    ff     = sum(1 for (c, s), r in v.items()
                 if c in NON_DEV and r["verdict"] == "FAIL")
    caught = sum(1 for bug in DEV_BUGS
                 if sum(1 for s in SEEDS
                        if v[(bug, s)]["verdict"] == "FAIL") >= 3)
    T, C_dev = 1.0 - ff / 55.0, caught / 6.0
    if   T == 1.0 and C_dev == 1.0: q = "Q1_SURVIVOR"
    elif T == 1.0:                  q = "Q2_BLIND"
    elif C_dev == 1.0:              q = "Q3_FRAGILE"
    else:                           q = "Q4_DEAD"
    return dict(triad=t["id"], way=t["way"], model=t["model"],
                components=dict(t["components"]),
                caught=caught, ff=ff, T=T, C_dev=C_dev,
                quadrant=q, retries=retried)

# ---------------------------------------------------------------- resume
def load_existing_scores(path):
    """triad_id -> dict(way, model, T, C_dev, quadrant) from a previous run."""
    if not path.exists():
        return {}
    out = {}
    with open(path, newline="") as fh:
        for row in csv.DictReader(fh):
            out[row["triad"]] = dict(way=row["way"], model=row["model"],
                                     T=float(row["T"]), C_dev=float(row["C_dev"]),
                                     quadrant=row["quadrant"])
    return out

def counts_from_row(row):
    """Exact inverse of the T/C_dev formulas (values are exact multiples)."""
    return round(row["C_dev"] * 6), round((1.0 - row["T"]) * 55)

def baseline_selection(scores_all):
    """FROZEN rule 6.2 over raw counts: caught desc (C_dev) -> ff asc (T) ->
    lowest version-sum. Way-1 triad ids embed the version as _vNN."""
    baselines, report = {}, []
    for m in MODELS:
        rows = [dict(tid=tid, v=int(tid.split("_v")[1]),
                     **dict(zip(("caught", "ff"), counts_from_row(r))))
                for tid, r in scores_all.items()
                if r["model"] == m and r["way"] == "way1"
                and r["quadrant"] != "COMPILE_FAIL"]
        if not rows:
            report.append(f"  {m}: NO eligible Way-1 baseline (all COMPILE_FAIL) — swaps skipped")
            continue
        b = min(rows, key=lambda r: (-r["caught"], r["ff"], r["v"]))
        baselines[m] = b["v"]
        report.append(f"  {m}: baseline {m}_v{b['v']:02d} "
                      f"(caught={b['caught']}/6, ff={b['ff']}/55)")
    return baselines, report

# ---------------------------------------------------------------- main
def main():
    RESULTS.mkdir(exist_ok=True); WORK.mkdir(exist_ok=True)
    assert not set(SEALED_CELLS) & set(ACTIVE_CELLS), \
        "[FATAL] sealed cell in ACTIVE_CELLS — protocol §5 violated"
    print(f"[FIREWALL] {len(ACTIVE_CELLS)} active cells; sealed (never run in "
          f"Stage 4-5, Stage 8 only): {sorted(SEALED_CELLS)}")

    pool, _ = discover()
    pool = filter_by_manifest(pool)
    print(f"Pool after ingestion filter: {len(pool)} / 45")
    triads1 = way1_triads(pool)
    print(f"Way-1 triads: {len(triads1)}")
    if not triads1:
        sys.exit("[FATAL] No triads formed — check ingestion + naming")

    existing = load_existing_scores(RESULTS / "stage5_scores.csv")
    scores_all = dict(existing)
    if existing:
        print(f"[RESUME] {len(existing)} triads already scored — they will be skipped")

    runs_mode = "a" if existing else "w"
    runs_f = (RESULTS / "stage5_runs.csv").open(runs_mode, newline="")
    runs_w = csv.writer(runs_f)
    sc_f   = (RESULTS / "stage5_scores.csv").open(runs_mode, newline="")
    sc_w   = csv.writer(sc_f)
    if not existing:
        runs_w.writerow(["triad", "way", "model", "cell", "seed",
                         "verdict", "error_count", "reason"])
        sc_w.writerow(["triad", "way", "model", "T", "C_dev", "quadrant"])

    def backup_bkg():
        BKG_BAK.mkdir(parents=True, exist_ok=True)
        for fn in TARGET_MAP.values():
            shutil.copy2(TB_UVM / fn, BKG_BAK / fn)

    backup_bkg()
    try:
        # ---------------- Way 1 ----------------
        for t in triads1:
            if t["id"] in existing:
                print(f"\n=== {t['id']} === (skipped, already scored)")
                continue
            print(f"\n=== {t['id']} ===")
            ok, why = compile_triad(t, pool)
            if not ok:
                print(f"  COMPILE FAIL ({why}) -> T=0, C_dev=0")
                sc_w.writerow([t["id"], t["way"], t["model"],
                               "0.0000", "0.0000", "COMPILE_FAIL"]); sc_f.flush()
                scores_all[t["id"]] = dict(way="way1", model=t["model"],
                                           T=0.0, C_dev=0.0, quadrant="COMPILE_FAIL")
                continue
            s = run_matrix(t, pool, runs_w, runs_f)
            print(f"  T={s['T']:.3f}  C_dev={s['C_dev']:.3f}  {s['quadrant']}"
                  + (f"  ({s['retries']} timeout-retries)" if s["retries"] else ""))
            sc_w.writerow([t["id"], t["way"], t["model"],
                           f"{s['T']:.4f}", f"{s['C_dev']:.4f}", s["quadrant"]])
            sc_f.flush()
            scores_all[t["id"]] = dict(way="way1", model=t["model"],
                                       T=s["T"], C_dev=s["C_dev"],
                                       quadrant=s["quadrant"])

        # ---------------- Way 2 ----------------
        baselines, report = baseline_selection(scores_all)
        print("\n[WAY2] frozen baseline selection (caught desc -> ff asc -> "
              "lowest version-sum):")
        print("\n".join(report))
        swaps = way2_swaps(baselines, pool)
        print(f"Way-2 swap triads: {len(swaps)}")
        for t in swaps:
            if t["id"] in existing:
                print(f"\n=== {t['id']} === (skipped, already scored)")
                continue
            print(f"\n=== {t['id']} === (swap {t['swap_cat']}->{t['swap_ver']:02d} "
                  f"vs baseline {t['model']}_v{baselines[t['model']]:02d})")
            ok, why = compile_triad(t, pool)
            if not ok:
                print(f"  COMPILE FAIL ({why}) -> T=0, C_dev=0")
                sc_w.writerow([t["id"], t["way"], t["model"],
                               "0.0000", "0.0000", "COMPILE_FAIL"]); sc_f.flush()
                scores_all[t["id"]] = dict(way="way2", model=t["model"],
                                           T=0.0, C_dev=0.0, quadrant="COMPILE_FAIL",
                                           swap_cat=t["swap_cat"],
                                           swap_ver=t["swap_ver"])
                continue
            s = run_matrix(t, pool, runs_w, runs_f)
            print(f"  T={s['T']:.3f}  C_dev={s['C_dev']:.3f}  {s['quadrant']}")
            sc_w.writerow([t["id"], t["way"], t["model"],
                           f"{s['T']:.4f}", f"{s['C_dev']:.4f}", s["quadrant"]])
            sc_f.flush()
            scores_all[t["id"]] = dict(way="way2", model=t["model"],
                                       T=s["T"], C_dev=s["C_dev"],
                                       quadrant=s["quadrant"],
                                       swap_cat=t["swap_cat"], swap_ver=t["swap_ver"])

        # ---------------- attribution (protocol §9) ----------------
        with (RESULTS / "way2_attribution.csv").open("w", newline="") as fh:
            w = csv.writer(fh)
            w.writerow(["model", "category", "swap_version", "baseline_version",
                        "T", "C_dev", "dT", "dC_dev", "quadrant"])
            for tid, s in scores_all.items():
                if s["way"] != "way2" or "swap_cat" not in s:
                    continue
                bv = baselines[s["model"]]
                btid = f"{s['model']}_v{bv:02d}"
                b = scores_all.get(btid)
                if b and b["quadrant"] != "COMPILE_FAIL" and s["quadrant"] != "COMPILE_FAIL":
                    w.writerow([s["model"], s["swap_cat"], f"{s['swap_ver']:02d}",
                                f"{bv:02d}", f"{s['T']:.4f}", f"{s['C_dev']:.4f}",
                                f"{s['T'] - b['T']:+.4f}",
                                f"{s['C_dev'] - b['C_dev']:+.4f}", s["quadrant"]])
                else:
                    w.writerow([s["model"], s["swap_cat"], f"{s['swap_ver']:02d}",
                                f"{bv:02d}", f"{s['T']:.4f}", f"{s['C_dev']:.4f}",
                                "N/A", "N/A", s["quadrant"]])

        # ---------------- leaderboard (display only, same frozen rule) ----
        print("\n[LEADERBOARD] sorted per frozen rule (display only):")
        for m in MODELS:
            rows = [(tid, r) for tid, r in scores_all.items()
                    if r["model"] == m and r["way"] == "way1"]
            rows.sort(key=lambda kv: (0 if kv[1]["quadrant"] == "COMPILE_FAIL" else 1,
                                      -round(kv[1]["C_dev"] * 6),
                                      round((1 - kv[1]["T"]) * 55),
                                      int(kv[0].split("_v")[1])))
            for tid, r in rows:
                print(f"  {tid:<10} T={r['T']:.3f} C_dev={r['C_dev']:.3f} {r['quadrant']}")
    finally:
        for fn in TARGET_MAP.values():
            src = BKG_BAK / fn
            if src.exists():
                shutil.copy2(src, TB_UVM / fn)
        print("\n[RESTORE] BKG driver/seq/scoreboard restored to tb/uvm/")
        runs_f.close(); sc_f.close()

    print(f"\nWrote {RESULTS/'stage5_runs.csv'}, {RESULTS/'stage5_scores.csv'}, "
          f"{RESULTS/'way2_attribution.csv'}")

if __name__ == "__main__":
    main()