#!/usr/bin/env python3
"""Stage 4 ingestion lint + dedup ladder + diversity table
(STAGE4_5_PROTOCOL sections 4.1 / 4.2 / 9).

Inputs : uvm_variants/{cg,qw,gm}/qpsk_{drv,seq,sb}_{model}_?{vv}.sv
         (accepts both qpsk_drv_gm01.sv and qpsk_drv_gm_01.sv; warns)
         optional control/ batch (unseeded group, diversity report only)
Process: 1. INGEST LINT (4.1): fence strip (only permitted edit) ->
            forbidden-token scan -> TASK-conformance quick checks.
            Any violation = INELIGIBLE, recorded, never hand-fixed.
         2. DEDUP LADDER (4.2): raw sha256 -> normalized sha256
            (comments + blank lines stripped, whitespace collapsed,
            CRLF folded). Within model+category: lowest version index =
            representative, clones excluded from triad pools.
            Cross-model duplicates: allowed, reported.
Outputs: stage4/ingested/<model>/*.sv   (fence-stripped, compile-ready)
         results/stage4_ingest.csv
         results/diversity_table.csv
         variants_manifest.json         (mechanical fields; chat_date /
                                         re_asks left null for manual fill)

Zero LLM in the loop. Deterministic; re-running is idempotent."""
import argparse, csv, hashlib, json, re, sys
from pathlib import Path

SCRIPT_VERSION = "stage4_ingest_lint-v1.0"
MODELS = ["cg", "qw", "gm"]
CATS   = ["drv", "seq", "sb"]
CLASS_NAME = {"drv": "qpsk_driver", "seq": "qpsk_base_seq", "sb": "qpsk_scoreboard"}

FILE_RE = re.compile(r'^qpsk_(drv|seq|sb)_(cg|qw|gm)_?(\d{2})\.sv$')
CTRL_RE = re.compile(r'^qpsk_(drv|seq|sb)_(cg|qw|gm)_unseeded_v(\d+)\.sv$')

def sha256_bytes(b): return hashlib.sha256(b).hexdigest()

# ---------------- fence strip (the ONLY permitted edit, 4.1) -------------
def strip_fences(text):
    lines = text.replace('\r\n', '\n').split('\n')
    return '\n'.join(ln for ln in lines if not ln.lstrip().startswith('```'))

# ---------------- comment stripper (string-literal aware) ----------------
def strip_comments(text):
    out, i, n = [], 0, len(text)
    in_str = in_line = in_block = False
    while i < n:
        c = text[i]
        nxt = text[i + 1] if i + 1 < n else ''
        if in_line:
            if c == '\n':
                in_line = False; out.append(c)
            i += 1
        elif in_block:
            if c == '*' and nxt == '/':
                in_block = False; i += 2
            else:
                if c == '\n': out.append(c)
                i += 1
        elif in_str:
            out.append(c)
            if c == '\\' and i + 1 < n:
                out.append(nxt); i += 2; continue
            if c == '"': in_str = False
            i += 1
        else:
            if c == '/' and nxt == '/':
                in_line = True; i += 2
            elif c == '/' and nxt == '*':
                in_block = True; i += 2
            else:
                if c == '"': in_str = True
                out.append(c); i += 1
    return ''.join(out)

def normalize(text):
    """Dedup key: comments + blank lines gone, whitespace collapsed,
    CRLF folded. Same code, different comments => same hash (photocopy)."""
    text = strip_comments(text.replace('\r\n', '\n'))
    lines = (re.sub(r'\s+', ' ', ln).strip() for ln in text.split('\n'))
    return '\n'.join(ln for ln in lines if ln)

# ---------------- ingest lint (4.1) --------------------------------------
def lint(ingested, cat):
    v = []
    if re.search(r'^\s*```', ingested, re.M):      v.append("fence-residue")
    if re.search(r'^\s*module\b', ingested, re.M): v.append("module-wrapper")
    if re.search(r'^\s*package\b', ingested, re.M):v.append("package-wrapper")
    if re.search(r'\bimport\s+uvm_pkg\b', ingested): v.append("import-uvm_pkg")
    if re.search(r'`\s*include\s+"uvm_macros', ingested):
        v.append("include-uvm_macros")
    if re.search(r'\bexpect\b', ingested):         v.append("reserved-expect")
    # $display rule: drv/seq -> banned; sb -> every $display must be [RESULT]
    for m in re.finditer(r'\$display', ingested):
        line = ingested[m.start():ingested.find('\n', m.start())]
        if cat in ("drv", "seq"):
            v.append("$display-in-" + cat); break
        if "[RESULT]" not in line:
            v.append("$display-without-RESULT"); break
    # TASK-conformance quick checks (compile-gate prefilter, deterministic)
    classes = re.findall(r'^\s*class\s+(\w+)', ingested, re.M)
    if len(classes) != 1:
        v.append(f"class-count={len(classes)}")
    elif classes[0] != CLASS_NAME[cat]:
        v.append(f"class-name={classes[0]}!={CLASS_NAME[cat]}")
    if ingested.count("endclass") != 1:
        v.append(f"endclass-count={ingested.count('endclass')}")
            # Required UVM registration macro per category. Compiler will fail
    # without it; catch at ingest instead. Added after the driver-prompt
    # omission of 2026-09-14.
    REQ = {"drv": "uvm_component_utils(qpsk_driver)",
           "seq": "uvm_object_utils(qpsk_base_seq)",
           "sb":  "uvm_component_utils(qpsk_scoreboard)"}
    if REQ[cat] not in ingested:
        v.append(f"missing-macro:{REQ[cat]}")
    return v

# ---------------- main ----------------------------------------------------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--variants-dir", default="uvm_variants")
    ap.add_argument("--control-dir", default="control")
    ap.add_argument("--out-dir", default="stage4/ingested")
    ap.add_argument("--results-dir", default="results")
    ap.add_argument("--manifest", default="variants_manifest.json")
    a = ap.parse_args()
    vdir, out, res = Path(a.variants_dir), Path(a.out_dir), Path(a.results_dir)
    res.mkdir(parents=True, exist_ok=True)

    rows, by_group = [], {}          # by_group[(group,model,cat)] = [rec,...]
    for group, base, rx in (("variants", vdir, FILE_RE),
                            ("control", Path(a.control_dir), CTRL_RE)):
        for model in MODELS:
            d = base / model
            if not d.is_dir():
                if group == "variants":
                    sys.exit(f"[FATAL] missing {d} — all three model dirs required")
                continue
            for f in sorted(d.glob("*.sv")):
                m = rx.match(f.name)
                if not m:
                    print(f"[WARN] {f} does not match naming convention — skipped")
                    continue
                cat, mdl, ver = m.group(1), m.group(2), int(m.group(3))
                raw = f.read_text()
                raw_sha = sha256_bytes(f.read_bytes())
                ing = strip_fences(raw)
                viol = lint(ing, cat)
                status = "OK" if not viol else "INELIGIBLE"
                norm_sha = sha256_bytes(normalize(ing).encode()) if status == "OK" else ""
                # write compile-ready ingested copy (raw stays untouched)
                od = out / group / mdl; od.mkdir(parents=True, exist_ok=True)
                (od / f.name).write_text(ing)
                rec = dict(group=group, model=mdl, category=cat, version=ver,
                           filename=f.name, raw_sha256=raw_sha,
                           ingested_sha256=sha256_bytes(ing.encode()),
                           normalized_sha256=norm_sha, lint_status=status,
                           violations=";".join(viol), dedup_class="",
                           representative="", cross_model_dup_of="")
                rows.append(rec)
                by_group.setdefault((group, mdl, cat), []).append(rec)

    # ---------------- dedup ladder (4.2) ----------------------------------
    for (group, mdl, cat), recs in by_group.items():
        if group != "variants":
            for r in recs: r["dedup_class"] = "control"
            continue
        elig = [r for r in recs if r["lint_status"] == "OK"]
        for r in recs:
            if r["lint_status"] != "OK": r["dedup_class"] = "ineligible"
        seen = {}
        for r in sorted(elig, key=lambda r: r["version"]):
            h = r["normalized_sha256"]
            if h in seen:
                r["dedup_class"] = f"duplicate_of:{seen[h]}"
            else:
                seen[h] = r["filename"]
                r["dedup_class"] = "unique"
                r["representative"] = r["filename"]
        for r in elig:
            if r["dedup_class"] == "unique":
                r["representative"] = r["filename"]
    # cross-model duplicates (representatives only; allowed, reported)
    glob = {}
    for (group, mdl, cat), recs in by_group.items():
        if group != "variants": continue
        for r in recs:
            if r["dedup_class"] == "unique":
                glob.setdefault(r["normalized_sha256"], []).append(r["filename"])
    for recs in by_group.values():
        for r in recs:
            if r["dedup_class"] == "unique" and len(glob[r["normalized_sha256"]]) > 1:
                others = [x for x in glob[r["normalized_sha256"]] if x != r["filename"]]
                r["cross_model_dup_of"] = ";".join(others)

    # ---------------- outputs ---------------------------------------------
    with open(res / "stage4_ingest.csv", "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        w.writeheader(); w.writerows(rows)

    div_rows = []
    for group, mdl in sorted({(g, m) for (g, m, _) in by_group}):
        for cat in CATS + ["ALL"]:
            recs = [r for (g, m, c), rs in by_group.items() if (g, m) == (group, mdl)
                    and (cat == "ALL" or c == cat) for r in rs]
            div_rows.append(dict(
                group=group, model=mdl, category=cat,
                raw=len(recs),
                ineligible=sum(1 for r in recs if r["lint_status"] != "OK"),
                duplicates_excluded=sum(1 for r in recs if r["dedup_class"].startswith("duplicate_of")),
                functional=sum(1 for r in recs if r["dedup_class"] in ("unique", "control"))))
    with open(res / "diversity_table.csv", "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(div_rows[0].keys()))
        w.writeheader(); w.writerows(div_rows)

    # manifest: update mechanical fields, preserve manual ones
    mpath = Path(a.manifest)
    man = json.loads(mpath.read_text()) if mpath.is_file() else {}
    for r in rows:
        e = man.get(r["filename"], {})
        e.update({k: r[k] for k in ("group", "model", "category", "version",
                                    "raw_sha256", "ingested_sha256",
                                    "normalized_sha256", "lint_status",
                                    "violations", "dedup_class",
                                    "representative", "cross_model_dup_of")})
        e["style_seed_id"] = f"v{r['version']:02d}"
        e.setdefault("chat_date", None)      # fill manually from your chat log
        e.setdefault("re_asks", None)        # fill manually (0 or 1)
        e.setdefault("compile_status", None) # filled at triad compile gate
        man[r["filename"]] = e
    mpath.write_text(json.dumps(man, indent=2, sort_keys=True) + "\n")

    # ---------------- console report --------------------------------------
    for r in rows:
        tag = r["dedup_class"] or r["lint_status"]
        print(f"{r['model']}/{r['filename']:<26} {r['lint_status']:<11} "
              f"norm={r['normalized_sha256'][:8] or '--------':<8} {tag}"
              + (f"  [{r['violations']}]" if r["violations"] else ""))
    print()
    for (group, mdl, cat), recs in sorted(by_group.items()):
        if group != "variants": continue
        pool = sorted(r["version"] for r in recs if r["dedup_class"] == "unique")
        if len(pool) < 2:
            print(f"[NOTE] {mdl}/{cat}: functional pool = {pool} (<2 -> "
                  f"swaps skipped for this category per 4.2, reported as result)")
    for mdl in MODELS:
        pools = {cat: sorted(r["version"] for r in by_group.get(("variants", mdl, cat), [])
                             if r["dedup_class"] == "unique") for cat in CATS}
        triads = sorted(set(pools["drv"]) & set(pools["seq"]) & set(pools["sb"]))
        print(f"Way-1 triads available for {mdl}: {triads}  "
              f"(pools: drv={pools['drv']} seq={pools['seq']} sb={pools['sb']})")
    n_ok = sum(1 for r in rows if r["group"] == "variants"
               and r["dedup_class"] in ("unique", "duplicate_of:"))
    n_inel = sum(1 for r in rows if r["group"] == "variants"
                 and r["lint_status"] != "OK")
    n_dup = sum(1 for r in rows if r["group"] == "variants"
                and r["dedup_class"].startswith("duplicate_of"))
    print(f"\nINGEST DONE: {n_ok} eligible / {n_dup} photocopies benched / "
          f"{n_inel} ineligible — manifest: {a.manifest}")

if __name__ == "__main__":
    main()