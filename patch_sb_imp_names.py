#!/usr/bin/env python3
"""
patch_sb_imp_names.py — Mechanical rename of analysis-imp member names
in batch-2 scoreboards to the canonical names the frozen env expects.

Frozen tb/uvm/qpsk_env.sv connects:
    agent.ap.connect(scb.ap_imp_observed);
    agent.ap_expected.connect(scb.ap_imp_expected);

Batch-1 prompts explicitly named these two members. Batch-2 (naive)
prompts did not, so every model invented its own name
(expected_imp, exp_port, expected_export, ...). This script renames
whatever member name each scoreboard declared to the canonical names.

Wiring-name normalization, not a logic edit. Scoreboard comparison
logic (what the ablation tests) is untouched.

Idempotent: files already using canonical names are skipped.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent

TARGETS = []
for m in ("pp", "km", "gm"):
    for base in (ROOT / "uvm_variants_b2" / m,
                 ROOT / "stage4" / "ingested_b2" / "variants" / m):
        if base.is_dir():
            TARGETS += sorted(base.glob("qpsk_sb_*.sv"))

DECL_RE = {
    "expected": re.compile(
        r'uvm_analysis_imp_expected\s*#\s*\(\s*[^)]*\)\s*([A-Za-z_]\w*)\s*;'),
    "observed": re.compile(
        r'uvm_analysis_imp_observed\s*#\s*\(\s*[^)]*\)\s*([A-Za-z_]\w*)\s*;'),
}
CANON = {"expected": "ap_imp_expected", "observed": "ap_imp_observed"}


def patch_file(p: Path):
    text = p.read_text()
    found = {}
    for kind, rx in DECL_RE.items():
        m = rx.search(text)
        if m:
            found[kind] = m.group(1)

    if not found:
        return False, "no-imp-decl-found"

    changes = []
    for kind, old in found.items():
        new = CANON[kind]
        if old == new:
            changes.append(f"{kind}=canonical")
            continue
        # Whole-word identifier rename
        text = re.sub(rf'\b{re.escape(old)}\b', new, text)
        # String literal rename inside new("...", this)
        text = text.replace(f'new("{old}",', f'new("{new}",')
        changes.append(f"{old}->{new}")

    p.write_text(text)
    return True, ", ".join(changes)


def main():
    patched = canon = skipped = 0
    for p in TARGETS:
        ok, info = patch_file(p)
        rel = p.relative_to(ROOT)
        if not ok:
            print(f"[SKIP]  {rel}: {info}")
            skipped += 1
        elif "->" in info:
            print(f"[PATCH] {rel}: {info}")
            patched += 1
        else:
            print(f"[OK]    {rel}: {info}")
            canon += 1
    print(f"\nPatched={patched}  canonical={canon}  skipped={skipped}")


if __name__ == "__main__":
    main()