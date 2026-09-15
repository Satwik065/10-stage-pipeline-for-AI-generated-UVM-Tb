#!/usr/bin/env python3
"""Stage 5b — Per-assertion taxonomy for AI-generated scoreboards.

For each Q1 survivor scoreboard:
  1. Instrument every errors++ / errors+=N site with a unique [FIRE] tag
  2. Rebuild + run all 23 cells × 5 seeds
  3. Classify each site: Useful / Dead / Harmful / Redundant
  4. Compute AER
"""
import csv, hashlib, json, re, shutil, subprocess, sys
from collections import defaultdict
from pathlib import Path

ROOT     = Path(__file__).resolve().parent
TB_UVM   = ROOT / "tb" / "uvm"
INGESTED = ROOT / "stage4" / "ingested" / "variants"
WORK     = ROOT / "stage5b_work"
RESULTS  = ROOT / "results" / "stage5b"
BUILD    = ROOT / "build_uvm.sh"
BINARY   = ROOT / ".uvm_smoke" / "Vqpsk_tb_top"
BKG_BAK  = WORK / "bkg_backup"

SEEDS = [42, 1337, 9001, 271828, 314159]

ALL_CELLS = [
    "golden",
    "W-01_mod_latency_plus1","W-02_demod_latency_plus1",
    "W-03_mod_idle_zero","W-04_demod_idle_zero",
    "W-05_mod_reset_late","W-06_demod_reset_late",
    "W-07_ch_noise_doubled","W-08_ch_rotation_doubled",
    "W-09_ch_latency_plus1","W-10_ch_idle_zero",
    "S-01_const_sym10_i","S-02_const_sym01_q","S-03_slice_invert_i",
    "S-04_slice_swap_iq","S-05_mod_valid_gate","S-06_demod_valid_skew",
    "S-07_const_sym00_i","S-08_demod_valid_dup","S-09_ch_q_inversion",
    "S-10_ch_drop_valid","S-11_ch_noise_overload","S-12_ch_q_zero",
]
DEV_BUGS = ["S-01_const_sym10_i","S-02_const_sym01_q","S-03_slice_invert_i",
            "S-05_mod_valid_gate","S-09_ch_q_inversion","S-11_ch_noise_overload"]
GW_CELLS = ["golden"] + [c for c in ALL_CELLS if c.startswith("W-")]

TARGET_MAP = {"drv":"qpsk_driver.sv","seq":"qpsk_seq.sv","sb":"qpsk_scoreboard.sv"}

# Triads whose scoreboards we instrument
TRIADS = [
    ("cg_v04", ("cg",4), ("cg",4), ("cg",4)),
    ("cg_v05", ("cg",5), ("cg",5), ("cg",5)),
    ("gm_v03", ("gm",3), ("gm",3), ("gm",3)),
]

# ---------------- Instrumentation ----------------
ERR_INC_PATTERNS = [
    (re.compile(r'^(\s*)errors\+\+\s*;\s*$'),
     lambda indent, ln: f'{indent}begin $display("[FIRE] L{ln}"); errors++; end'),
    (re.compile(r'^(\s*)errors\s*=\s*errors\s*\+\s*1\s*;\s*$'),
     lambda indent, ln: f'{indent}begin $display("[FIRE] L{ln}"); errors = errors + 1; end'),
    (re.compile(r'^(\s*)errors\s*\+=\s*(\w+)\s*;\s*$'),
     lambda indent, ln: None),  # placeholder, handled below
]

def instrument(text):
    lines = text.split('\n')
    out = []
    for i, line in enumerate(lines, 1):
        matched = False
        for pat, sub in ERR_INC_PATTERNS[:2]:
            m = pat.match(line)
            if m:
                indent = m.group(1)
                out.append(sub(indent, i))
                matched = True
                break
        if matched:
            continue
        # errors += N form
        m = re.match(r'^(\s*)errors\s*\+=\s*(\w+)\s*;\s*$', line)
        if m:
            indent, n = m.group(1), m.group(2)
            out.append(f'{indent}begin $display("[FIRE] L{i}"); errors += {n}; end')
            continue
        out.append(line)
    return '\n'.join(out)

# ---------------- Compile & Run ----------------
def pth(m,cat,v):
    return INGESTED / m / f"qpsk_{cat}_{m}_{v:02d}.sv"

def build_triad(tid, d, s, sb_path):
    logdir = WORK / tid; logdir.mkdir(parents=True, exist_ok=True)
    if BINARY.exists(): BINARY.unlink()
    shutil.copy(pth(*d[:1], "drv", d[1]), TB_UVM/TARGET_MAP["drv"])
    shutil.copy(pth(*s[:1], "seq", s[1]), TB_UVM/TARGET_MAP["seq"])
    shutil.copy(sb_path, TB_UVM/TARGET_MAP["sb"])
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
        return []
    log = r.stdout + r.stderr
    return re.findall(r'\[FIRE\]\s+(L\d+)', log)

# ---------------- Classification ----------------
def classify(site_fires, all_sites):
    """site_fires: {site_id: {cell: {seeds that fired}}}"""
    # Build per-site fired-cells (≥3/5 seeds)
    fired_ge3 = {}   # site -> set of cells it fires on ≥3/5 seeds
    fired_any_gw = set()
    for s in all_sites:
        cells_ge3 = set()
        for cell in ALL_CELLS:
            n = len(site_fires[s].get(cell, set()))
            if n >= 3:
                cells_ge3.add(cell)
            if n >= 1 and cell in GW_CELLS:
                fired_any_gw.add(s)
        fired_ge3[s] = cells_ge3

    # Classify
    classes = {}
    for s in all_sites:
        if s in fired_any_gw:
            classes[s] = "HARMFUL"
            continue
        dev_hits = [b for b in DEV_BUGS if b in fired_ge3[s]]
        if not dev_hits:
            classes[s] = "DEAD"
            continue
        classes[s] = "USEFUL"

    # Redundant pass: a useful site whose DEV catch set is subset of the union
    # of previously-kept sites (deterministic keep-order via SHA of site id)
    keep_order = sorted([s for s in all_sites if classes[s] == "USEFUL"],
                        key=lambda s: hashlib.sha256(s.encode()).hexdigest())
    kept_devsets = []
    for s in keep_order:
        dev_set = frozenset(b for b in DEV_BUGS if b in fired_ge3[s])
        if any(dev_set.issubset(k) for k in kept_devsets):
            classes[s] = "REDUNDANT"
        else:
            kept_devsets.append(dev_set)

    return classes, fired_ge3

def compute_aer(classes):
    total = len(classes)
    useful = sum(1 for c in classes.values() if c == "USEFUL")
    return useful / total if total else 0.0

# ---------------- Main ----------------
def main():
    RESULTS.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(parents=True, exist_ok=True)

    # Backup BKG once
    BKG_BAK.mkdir(parents=True, exist_ok=True)
    for fn in TARGET_MAP.values():
        shutil.copy2(TB_UVM/fn, BKG_BAK/fn)

    summary_rows = []

    try:
        for tid, d, s, sb in TRIADS:
            print(f"\n{'='*60}")
            print(f"=== {tid} ===")
            print('='*60)

            # Read + instrument scoreboard
            sb_src = pth(*sb[:1], "sb", sb[1])
            text = sb_src.read_text()
            instrumented = instrument(text)

            # Count sites
            sites = sorted(set(re.findall(r'\[FIRE\]\s+(L\d+)', instrumented)))
            print(f"  Scoreboard: {sb_src.name}")
            print(f"  Check sites found: {len(sites)}  {sites}")

            # Save instrumented scoreboard
            instr_path = WORK / f"{tid}_sb_instr.sv"
            instr_path.write_text(instrumented)

            if not build_triad(tid, d, s, instr_path):
                print("  BUILD FAIL")
                summary_rows.append((tid, len(sites), 0, 0, 0, 0, 0.0, "BUILD_FAIL"))
                continue

            # Run all 23 cells × 5 seeds
            site_fires = {s: defaultdict(set) for s in sites}
            for cell in ALL_CELLS:
                for seed in SEEDS:
                    fired = run_one(cell, seed)
                    for f in fired:
                        if f in site_fires:
                            site_fires[f][cell].add(seed)

            classes, fired_ge3 = classify(site_fires, sites)

            n_useful = sum(1 for c in classes.values() if c == "USEFUL")
            n_dead   = sum(1 for c in classes.values() if c == "DEAD")
            n_harm   = sum(1 for c in classes.values() if c == "HARMFUL")
            n_red    = sum(1 for c in classes.values() if c == "REDUNDANT")
            aer = compute_aer(classes)

            print(f"  Useful={n_useful}  Dead={n_dead}  Harmful={n_harm}  Redundant={n_red}")
            print(f"  AER = {n_useful}/{len(sites)} = {aer:.3f}")

            # Emit per-site table
            (RESULTS / f"{tid}_taxonomy.csv").write_text(
                "site,class,fires_on_ge3\n" + "\n".join(
                    f'{s},{classes[s]},"{";".join(sorted(fired_ge3[s]))}"'
                    for s in sites))

            summary_rows.append((tid, len(sites), n_useful, n_dead, n_harm,
                                 n_red, aer, "OK"))
    finally:
        for fn in TARGET_MAP.values():
            src = BKG_BAK/fn
            if src.exists(): shutil.copy2(src, TB_UVM/fn)
        print("\n[RESTORE] BKG restored")

    # Summary CSV
    with open(RESULTS/"summary.csv","w",newline="") as f:
        w = csv.writer(f)
        w.writerow(["triad","sites","useful","dead","harmful","redundant","AER","status"])
        for row in summary_rows:
            w.writerow(row)
    print(f"\nSummary: {RESULTS/'summary.csv'}")

if __name__ == "__main__":
    main()
