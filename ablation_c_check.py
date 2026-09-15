#!/usr/bin/env python3
"""Ablation C — No Contract Lock.

Checks AI-generated interface files against the required contract.
Reports per-file pass/fail and per-model hallucination rate.

Required contract (frozen Stage 1):
  clk      1   input
  rst      1   input
  ch_seed  32  (driven by TB)
  valid_in 1   (driven by TB)
  bits_in  2   (driven by TB)
  valid_out 1  (observed)
  bits_out 2   (observed)
  + clocking blocks + modports driver/monitor
"""
import re, csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DIR  = ROOT / "ablation_c_interfaces"
OUT  = ROOT / "results" / "ablations"
OUT.mkdir(parents=True, exist_ok=True)

REQUIRED = {
    "clk":       1,
    "rst":       1,
    "ch_seed":   32,
    "valid_in":  1,
    "bits_in":   2,
    "valid_out": 1,
    "bits_out":  2,
}

DECL_RE = re.compile(
    r'^\s*(input|output|inout)\s+(?:wire|logic|reg)?\s*'
    r'(?:signed\s*)?(?:\[(\d+)\s*:\s*(\d+)\])?\s*(\w+)\s*[,;]',
    re.M)

def width(msb, lsb):
    return (int(msb) - int(lsb) + 1) if msb else 1

def check(text):
    issues = []
    if "interface qpsk_dut_if" not in text:
        issues.append("wrong-interface-name")
    decls = {}
    for m in DECL_RE.finditer(text):
        d, msb, lsb, n = m.groups()
        decls[n] = width(msb, lsb)
    for name, w in REQUIRED.items():
        if name not in decls:
            issues.append(f"missing:{name}")
        elif decls[name] != w:
            issues.append(f"width:{name}={decls[name]}!={w}")
    # Extra ports the AI invented
    extras = [n for n in decls if n not in REQUIRED]
    for e in extras:
        issues.append(f"extra:{e}")
    if "modport driver" not in text:
        issues.append("missing-modport:driver")
    if "modport monitor" not in text:
        issues.append("missing-modport:monitor")
    if "clocking" not in text:
        issues.append("missing-clocking")
    return issues, decls

def main():
    rows = []
    summary = {}
    for model_dir in sorted(DIR.iterdir()):
        if not model_dir.is_dir(): continue
        model = model_dir.name
        files = sorted(model_dir.glob("*.sv"))
        passed = 0
        print(f"\n=== {model} ({len(files)} files) ===")
        for f in files:
            try:
                issues, decls = check(f.read_text())
            except Exception as e:
                issues, decls = [f"read-error:{e}"], {}
            status = "PASS" if not issues else "FAIL"
            if not issues: passed += 1
            tag = "PASS" if not issues else "FAIL"
            print(f"  {tag}  {f.name:<32} "
                  f"ports={len(decls)} issues={len(issues)}")
            if issues:
                for i in issues[:6]:
                    print(f"         - {i}")
            rows.append(dict(model=model, file=f.name, status=status,
                             port_count=len(decls),
                             issue_count=len(issues),
                             issues=";".join(issues)))
        summary[model] = (passed, len(files))

    print("\n" + "="*60)
    print(f"{'model':<8} {'pass':>6} {'total':>6} {'halluc_rate':>14}")
    print("-"*60)
    for m, (p, t) in summary.items():
        rate = (t-p)/t if t else 0
        print(f"{m:<8} {p:>6} {t:>6} {rate:>13.1%}")

    with open(OUT / "ablation_C_contract_lock.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader(); w.writerows(rows)
    print(f"\nWrote {OUT/'ablation_C_contract_lock.csv'}")

if __name__ == "__main__":
    main()
