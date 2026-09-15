#!/usr/bin/env python3
"""Extract per-assertion fire matrix from existing Stage 1 SVA proof binaries."""
import re, subprocess
from pathlib import Path
from collections import defaultdict

WORK = Path("stage1_work_sva_proof")
fires = defaultdict(set)   # cell -> set of P# fired

for d in sorted(WORK.iterdir()):
    if not d.is_dir(): continue
    binary = d / "Vtb_p1_check"
    if not binary.exists() or not binary.is_file():
        continue
    # dir name = <cell>_<seed>
    parts = d.name.rsplit("_", 1)
    cell, seed = parts[0], parts[1] if len(parts) == 2 else (d.name, "42")
    try:
        r = subprocess.run([str(binary), f"+CHSEED={seed}"],
                           capture_output=True, text=True, timeout=30)
    except subprocess.TimeoutExpired:
        continue
    log = r.stdout + r.stderr
    for m in re.finditer(r'\[SVA\]\[(P\d)\]', log):
        fires[cell].add(m.group(1))

print(f"{'cell':<30} {'P# fired':<20}")
print("-" * 55)
for cell in sorted(fires):
    if fires[cell]:
        print(f"{cell:<30} {','.join(sorted(fires[cell])):<20}")

print()
print("=== Per-assertion summary ===")
DEV = {"S-01_const_sym10_i","S-02_const_sym01_q","S-03_slice_invert_i",
       "S-05_mod_valid_gate","S-09_ch_q_inversion","S-11_ch_noise_overload"}
for p in ["P1","P2","P3","P4","P5"]:
    hit = sorted(c for c, ps in fires.items() if p in ps)
    dev = [c for c in hit if c in DEV]
    gw  = [c for c in hit if c == "golden" or c.startswith("W-")]
    other_s = [c for c in hit if c.startswith("S-") and c not in DEV]
    if not hit:
        cls = "DEAD"
    elif gw:
        cls = "HARMFUL"
    elif dev:
        cls = "USEFUL"
    else:
        cls = "DEAD"
    print(f"  {p}: {len(hit):>2} cells  DEV={len(dev)} GW={len(gw)} "
          f"other_S={len(other_s)}  -> {cls}")

print()
print("AER (SVA) = useful / total")
useful = sum(1 for p in ["P1","P2","P3","P4","P5"]
             if any(c in DEV for c, ps in fires.items() if p in ps)
             and not any(c == "golden" or c.startswith("W-")
                         for c, ps in fires.items() if p in ps))
print(f"  {useful} / 5 = {useful/5:.3f}")
