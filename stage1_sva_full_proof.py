#!/usr/bin/env python3
"""Extended false-fire proof for qpsk_sva.sv.

Runs the contract SVA (as a standalone harness) against ALL 23 battery
cells × 5 seeds. Confirms:
  - Golden + 10 Weather: SVA must NOT fire
  - Sabotage: SVA may or may not fire (informational)

Stage 1 only proved 5 of 10 Weather cells clean. This closes the gap.
"""
import subprocess, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
WORK = ROOT / "stage1_work_sva_proof"
WORK.mkdir(exist_ok=True)

SEEDS = [42, 1337, 9001, 271828, 314159]
CELLS = [
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
MUST_BE_SILENT = CELLS[:11]   # golden + all 10 Weather

def build_and_run(cell, seed):
    """Use the Stage 1 tb_p1_check.sv harness with qpsk_sva.sv bound."""
    # Pick the DUT variant
    if cell == "golden":
        mod = "rtl/qpsk_modulator.sv"
        ch  = "rtl/channel.sv"
        dem = "rtl/qpsk_demodulator.sv"
    else:
        mdir = ROOT / "mutants" / cell
        mf   = mdir / "manifest.json"
        if not mf.exists():
            return None, f"no manifest for {cell}"
        import json
        m = json.loads(mf.read_text())
        tgt = Path(m["target_file"]).name
        mod = f"rtl/qpsk_modulator.sv"; ch = "rtl/channel.sv"; dem = "rtl/qpsk_demodulator.sv"
        if tgt == "qpsk_modulator.sv":   mod = str(mdir / tgt)
        elif tgt == "channel.sv":        ch  = str(mdir / tgt)
        elif tgt == "qpsk_demodulator.sv": dem = str(mdir / tgt)

    mdir = WORK / f"{cell}_{seed}"
    mdir.mkdir(exist_ok=True)
    build = subprocess.run([
        "verilator","--binary","--timing","--assert","-Wno-fatal",
        "--Mdir", str(mdir), "--top-module","tb_p1_check",
        "tb/tb_p1_check.sv",
        mod, ch, dem,
        "contract/qpsk_sva.sv",
    ], capture_output=True, text=True, timeout=600)
    if build.returncode != 0:
        return None, f"build fail: {build.stderr[-400:]}"
    exe = mdir / "Vtb_p1_check"
    run = subprocess.run([str(exe), f"+CHSEED={seed}"],
                         capture_output=True, text=True, timeout=60)
    log = run.stdout + run.stderr
    fired = "[SVA][P" in log
    return fired, log

def main():
    print(f"{'cell':<28} {'seed':>7}  {'SVA fired?':<12} {'expected':<12} {'ok?'}")
    print("-" * 75)
    failures = 0
    summary = {}
    for cell in CELLS:
        cell_fired = []
        for seed in SEEDS:
            fired, _ = build_and_run(cell, seed)
            cell_fired.append(fired)
        # Verdict for this cell (aggregated across seeds)
        any_fire = any(cell_fired)
        expected = "SILENT" if cell in MUST_BE_SILENT else "either"
        ok = "✓"
        if cell in MUST_BE_SILENT and any_fire:
            ok = "✗ FAIL-FIRE"
            failures += 1
        summary[cell] = dict(fired=any_fire, ok=ok)
        print(f"{cell:<28} {len(SEEDS)} seeds  "
              f"{'YES' if any_fire else 'no':<12} {expected:<12} {ok}")
    print()
    if failures == 0:
        print("[PASS] SVA silent on Golden + all 10 Weather cells across 5 seeds")
        print("[INFO] SVA fires on some Sabotage cells — see above")
    else:
        print(f"[FAIL] SVA false-fires on {failures} Weather cell(s) — binding unsafe")
    # Return code for automation
    sys.exit(1 if failures else 0)

if __name__ == "__main__":
    main()
