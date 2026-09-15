#!/usr/bin/env python3
"""Ablation C (L1) — semantic spec, no exact names.

Fixed: detects BOTH body declarations (with widths) and header/clocking
block references (without widths). Prefers the declaration that carries
a width. Classifies findings into: OK / RENAME / WIDTH / MISSING.
"""
import re, csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DIR  = ROOT / "ablation_c_interfaces_l1"
OUT  = ROOT / "results" / "ablations"
OUT.mkdir(parents=True, exist_ok=True)

SLOTS = {
    "clk":       ("clk",       1,  ["clk", "clock"]),
    "rst":       ("rst",       1,  ["rst", "reset", "rst_n", "reset_n"]),
    "ch_seed":   ("ch_seed",   32, ["ch_seed", "seed", "channel_seed",
                                     "ch_seed_in", "chan_seed"]),
    "valid_in":  ("valid_in",  1,  ["valid_in", "in_valid",
                                     "symbol_valid", "dv_in"]),
    "bits_in":   ("bits_in",   2,  ["bits_in", "symbol_in", "data_in",
                                     "i_q_in", "sym_in"]),
    "valid_out": ("valid_out", 1,  ["valid_out", "out_valid",
                                     "symbol_valid_out", "dv_out"]),
    "bits_out":  ("bits_out",  2,  ["bits_out", "symbol_out", "data_out",
                                     "i_q_out", "sym_out"]),
}

# Declaration with explicit width: "logic [N:M] name" / "input logic [N:M] name,"
WIDTHED_RE = re.compile(
    r'(?:input|output|inout)?\s*(?:wire|logic|reg|bit)?\s*(?:signed\s*)?'
    r'\[(\d+)\s*:\s*(\d+)\]\s*(\w+)', re.M)

# Declaration without width: "input logic name," / "output name;" — for header and clocking
BARE_RE = re.compile(
    r'\b(input|output|inout)\s+(?:wire|logic|reg|bit)?\s*(\w+)\s*[,;\)]', re.M)

def extract_decls(text):
    """Returns {name: width}. Widthed declarations win over bare ones."""
    decls = {}
    for m in BARE_RE.finditer(text):
        _, n = m.groups()
        decls.setdefault(n, 1)          # default 1 if no width later overrides
    for m in WIDTHED_RE.finditer(text):
        msb, lsb, n = m.groups()
        decls[n] = int(msb) - int(lsb) + 1
    return decls

def classify(text):
    decls = extract_decls(text)
    by_lower = {k.lower(): (k, w) for k, w in decls.items()}

    findings = {}
    for slot, (canonical, w, aliases) in SLOTS.items():
        match = None
        for alias in aliases:
            if alias.lower() in by_lower:
                match = by_lower[alias.lower()]
                break
        if match is None:
            findings[slot] = "MISSING"
            continue
        got_name, got_w = match
        if got_name == canonical and got_w == w:
            findings[slot] = "OK"
        elif got_w != w:
            findings[slot] = f"WIDTH:{got_name}={got_w}!={w}"
        else:
            findings[slot] = f"RENAME:{got_name}!={canonical}"

    all_aliases = {a.lower() for _, _, a_list in SLOTS.values() for a in a_list}
    extras = [n for n in decls if n.lower() not in all_aliases]
    return findings, extras, decls

def main():
    rows = []
    summary = {}
    for model_dir in sorted(DIR.iterdir()):
        if not model_dir.is_dir(): continue
        model = model_dir.name
        files = sorted(model_dir.glob("*.sv"))
        tot_ok = tot_ren = tot_w = tot_miss = tot_ext = 0
        print(f"\n=== {model} ({len(files)} files) ===")
        for f in files:
            findings, extras, decls = classify(f.read_text())
            o = r = w = m = 0
            for slot, v in findings.items():
                if v == "OK": o += 1
                elif v == "MISSING": m += 1
                elif v.startswith("RENAME"): r += 1
                elif v.startswith("WIDTH"): w += 1
            tot_ok += o; tot_ren += r; tot_w += w; tot_miss += m
            tot_ext += len(extras)
            tag = "OK  " if (o == 7 and not extras) else "DEV "
            print(f"  {tag} {f.name:<34} ok={o} rename={r} width={w} "
                  f"miss={m} extras={len(extras)}")
            rows.append(dict(model=model, file=f.name, ok=o, rename=r,
                             width=w, missing=m, extras=len(extras)))
        summary[model] = dict(files=len(files), ok=tot_ok, rename=tot_ren,
                              width=tot_w, missing=tot_miss)

    print("\n" + "="*72)
    print(f"{'model':<8} {'files':>6} {'OK':>5} {'RENAME':>8} {'WIDTH':>7} {'MISS':>6}")
    print("-"*72)
    for m, s in summary.items():
        print(f"{m:<8} {s['files']:>6} {s['ok']:>5} {s['rename']:>8} "
              f"{s['width']:>7} {s['missing']:>6}")

    with open(OUT / "ablation_C_L1.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader(); w.writerows(rows)
    print(f"\nWrote {OUT/'ablation_C_L1.csv'}")

if __name__ == "__main__":
    main()
