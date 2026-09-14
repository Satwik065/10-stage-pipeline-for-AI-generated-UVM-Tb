#!/usr/bin/env python3
"""One-shot prompt-omission fix.
Insert `uvm_component_utils(qpsk_driver)` immediately after the class
declaration line in the 6 driver files that omitted it.
Idempotent — skips files where the macro is already present.
"""
import re, sys
from pathlib import Path

FILES = [
    "uvm_variants/cg/qpsk_drv_cg_01.sv",
    "uvm_variants/cg/qpsk_drv_cg_02.sv",
    "uvm_variants/cg/qpsk_drv_cg_03.sv",
    "uvm_variants/cg/qpsk_drv_cg_05.sv",
    "uvm_variants/qw/qpsk_drv_qw_03.sv",
    "uvm_variants/qw/qpsk_drv_qw_05.sv",
]

DECL_RE = re.compile(
    r'^(\s*class\s+qpsk_driver\s+extends\s+uvm_driver\s*#\s*\(\s*qpsk_seq_item\s*\)\s*;\s*)$',
    re.M)

for fn in FILES:
    p = Path(fn)
    if not p.exists():
        print(f"[SKIP missing] {fn}");  continue
    text = p.read_text()
    if "uvm_component_utils(qpsk_driver)" in text:
        print(f"[OK already] {fn}");  continue
    m = DECL_RE.search(text)
    if not m:
        print(f"[FAIL no class line] {fn}");  continue
    indent = re.match(r'^(\s*)', m.group(1)).group(1)
    insert = f"{indent}    `uvm_component_utils(qpsk_driver)\n"
    new_text = text[:m.end()] + "\n" + insert + text[m.end()+1:]
    p.write_text(new_text)
    print(f"[PATCHED] {fn}")