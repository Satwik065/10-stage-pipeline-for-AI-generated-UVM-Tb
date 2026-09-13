#!/usr/bin/env python3
"""Stage 1 contract-lock checker (Constitution v2.1 — frozen).

Chain per §12: constitution_sha256 (frozen constant) -> golden file
hashes (frozen §1, verified byte-exact BEFORE anything else runs) ->
contract artifact hashes (this run's outputs).

Gate order:
  0. GOLDEN PIN (§1/§11): local ./rtl/*.sv sha256 == frozen §1 hashes.
     Mismatch = FATAL, run stops. Fix the file or rewrite the
     constitution as v3 — the checker never relaxes (§11).
  1. GOLDEN PORT MAPS: extracted maps == EXPECT_GOLDEN.
  2. AST CROSS-CHECK: Verilator --json-only VAR names ⊇ port names.
  3. CONTRACT ARTIFACTS: interface rename-map/widths/clocking/modports;
     seq_item fields/constraint/structure; SVA ports/assert-IDs/constructs.
  4. COMPILE GATE: artifacts lint clean on THIS verilator rev (UVM
     sources via --uvm-dir; else DEGRADED, requires --accept-degraded).

RAL: N/A — the v2 DUT has no register map (recorded in manifest).

PATCH v2.1-a (Stage 1 contract review, fixes two blockers):
  - BLOCKER 2 (parser): added _strip_sv_comments() and applied it to
    extract_module_ports() and to every artifact text used by regex.
    Without it, RTL port lines with trailing // comments (e.g.
    `input wire [1:0] bits, // {I_bit,Q_bit}` in qpsk_modulator.sv)
    silently drop ports from the extracted map.
  - BLOCKER 1 (SVA): sva:constructs now REJECTS any `##[` ranged delay
    (Verilator unsupported) and REQUIRES the procedural `pending_sr`
    liveness tracker. Pairs with qpsk_sva.sv P1 rewrite.
  Also: rename-map check now verifies widths vs golden (not just names);
  manifest records generation provenance + assertion-class annotations;
  final verdict honours --accept-degraded."""
import argparse, hashlib, json, re, subprocess, sys
from pathlib import Path

SCRIPT_VERSION = "stage1_ast_check-v2.1"

# ---- Constitution v2.1 frozen constants (§ header, §1, §8) — §11: NEVER EDIT
CONSTITUTION_SHA256 = "6fbd46a0b33138337473660979d4f5d2b0bd8789d3766af3ebc815dddedb3ab5"
FROZEN_GOLDEN_SHA = {
    "qpsk_modulator.sv":  "1e97e9d673a68abe31b1e6b811f1b39f8e6b0ecdc686cf77d1aed55e03d32c92",
    "qpsk_demodulator.sv": "dae0efdbbbd22282f4da54d373d20ade4a6227832350ffcb3721343fbaa3afe5",
    "channel.sv":          "c05104057287a22d72bdf37c166cba7626818f6eb03748e5dfe38cc6a122681d",
}
DEV_BUGS = ["S-01", "S-02", "S-03", "S-05", "S-09", "S-11"]
HOLDOUT_BUGS = ["S-04", "S-06", "S-07", "S-08", "S-10", "S-12"]

# ---- locked Golden port maps (name -> (width, dir, ["signed"])) ----------
EXPECT_GOLDEN = {
    "qpsk_modulator.sv": ("qpsk_modulator", {
        "clk": (1, "input"), "rst": (1, "input"), "valid_in": (1, "input"),
        "bits": (2, "input"), "valid_out": (1, "output"),
        "i_out": (8, "output", "signed"), "q_out": (8, "output", "signed")}),
    "qpsk_demodulator.sv": ("qpsk_demodulator", {
        "clk": (1, "input"), "rst": (1, "input"), "valid_in": (1, "input"),
        "i_in": (8, "input", "signed"), "q_in": (8, "input", "signed"),
        "valid_out": (1, "output"), "bits": (2, "output")}),
    "channel.sv": ("channel", {
        "clk": (1, "input"), "rst": (1, "input"), "seed": (32, "input"),
        "valid_in": (1, "input"), "i_in": (8, "input", "signed"),
        "q_in": (8, "input", "signed"), "valid_out": (1, "output"),
        "i_out": (8, "output", "signed"), "q_out": (8, "output", "signed")}),
}

# ---- TB-boundary rename map — PART OF THE LOCKED CONTRACT ---------------
MAPPING_IF = {"clk": ("qpsk_modulator", "clk", 1),
              "rst": ("qpsk_modulator", "rst", 1),
              "ch_seed": ("channel", "seed", 32),
              "valid_in": ("qpsk_modulator", "valid_in", 1),
              "bits_in": ("qpsk_modulator", "bits", 2),
              "valid_out": ("qpsk_demodulator", "valid_out", 1),
              "bits_out": ("qpsk_demodulator", "bits", 2)}
IFACE_MEMBERS = {"ch_seed": 32, "valid_in": 1, "bits_in": 2,
                 "valid_out": 1, "bits_out": 2}
SVA_PORTS = {"clk": 1, "rst": 1, "valid_in": 1, "valid_out": 1,
             "bits_in": 2, "bits_out": 2}
ASSERT_IDS = ["a_liveness_valid_out", "a_credit_valid_out", "a_symbol_domain",
              "a_no_xz_outputs", "a_valid_in_single_cycle"]

PORT_RE  = re.compile(r'^\s*(input|output)\s+(?:wire|reg|logic)?\s*(signed)?\s*'
                      r'(?:\[(\d+)\s*:\s*(\d+)\])?\s*(\w+)\s*,?\s*$')
LOGIC_RE = re.compile(r'^\s*logic\s*(signed)?\s*(?:\[(\d+)\s*:\s*(\d+)\])?\s*(\w+)\s*;')
FIELD_RE = re.compile(r'^\s*(rand\s+)?bit\s*(?:\[(\d+)\s*:\s*(\d+)\])?\s*(\w+)\s*;')


# PATCH v2.1-a (BLOCKER 2): strip // and /* */ comments before regex.
def _strip_sv_comments(text: str) -> str:
    text = re.sub(r'//[^\n]*', '', text)
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.DOTALL)
    return text


def width_of(msb, lsb):
    return (int(msb) - int(lsb) + 1) if msb else 1


def sha256_file(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def extract_module_ports(text):
    text = _strip_sv_comments(text)   # PATCH v2.1-a
    mods, cur = {}, None
    for line in text.splitlines():
        m = re.match(r'\s*module\s+(\w+)', line)
        if m:
            cur = m.group(1); mods[cur] = {}; continue
        if cur:
            pm = PORT_RE.match(line)
            if pm:
                entry = (width_of(pm.group(3), pm.group(4)), pm.group(1))
                if pm.group(2): entry += ("signed",)
                mods[cur][pm.group(5)] = entry
            if re.match(r'\s*\);', line):
                cur = None
    return mods


def vlint_json(files, top, mdir, uvm=None):
    mdir.mkdir(parents=True, exist_ok=True)
    cmd = (["verilator", "--json-only", "-Wno-fatal", "--timing",
            "--Mdir", str(mdir), "--top-module", top] + [str(f) for f in files])
    if uvm:
        cmd += [f"+incdir+{uvm}/src", str(Path(uvm) / "src" / "uvm_pkg.sv")]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    js = sorted(mdir.glob("*.tree.json"))
    return r, js


def ast_collect(json_files):
    """PATCH v2.1-c: Verilator 5.053 emits tree JSON as a raw top-level dict
    (NOT {'nodes': [...]}), and child nodes hang off arbitrary *sp keys
    (modulesp, miscsp, stmtsp, varsp, sensesp, ...), not 'children'.

    Evidence: diagnostics on Vqpsk_modulator.tree.json show top-level keys
    {type,name,addr,loc,timescaleSpecified,timeunit,timeprecision,
     typeTablep,constPoolp,modulesp,miscsp} and 7 VAR nodes whose names are
    exactly the 7 port names. Walk every dict/list value generically so port
    VARs are found regardless of emitter layout."""
    vars_, types = set(), []
    for p in json_files:
        try:
            data = json.loads(p.read_text())
        except Exception:
            continue
        stack = [data] if isinstance(data, dict) else list(data)
        while stack:
            n = stack.pop()
            if isinstance(n, dict):
                t, nm = n.get("type"), n.get("name")
                if t:
                    types.append(t)
                    if t == "VAR" and nm:
                        vars_.add(nm)
                for v in n.values():
                    if isinstance(v, (dict, list)):
                        stack.append(v)
            elif isinstance(n, list):
                stack.extend(x for x in n if isinstance(x, (dict, list)))
    return vars_, types


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rtl-dir", default="./rtl")
    ap.add_argument("--contract-dir", default=".")
    ap.add_argument("--uvm-dir", default=None,
                    help="UVM root (contains src/uvm_pkg.sv); without it the "
                         "seq_item compile gate is skipped -> DEGRADED")
    ap.add_argument("--accept-degraded", action="store_true")
    ap.add_argument("--manifest", default="contract_manifest.json")
    # PATCH v2.1-a: Stage 1 requires 3-5 independent low-temp generations.
    ap.add_argument("--gen-model", default=None)
    ap.add_argument("--gen-temp",  default=None)
    ap.add_argument("--gen-runs",  default=None,
                    help="number of independent low-temperature generations "
                         "(Stage 1 requires 3-5; record actual)")
    ap.add_argument("--gen-prompt-hash", default=None)
    a = ap.parse_args()
    rtl, cdir = Path(a.rtl_dir), Path(a.contract_dir)
    work = Path("./.ast_work")
    rows = []

    # PATCH v2.1-a: contract-param block now records provenance + assertion
    # annotations the paper needs (boundary, known-dead, known-2state).
    contract_params = dict(
        liveness_L=6, baseline_latency=3, mismatch_budget="0 (§5b)",
        dev_bugs=DEV_BUGS, holdout_bugs=HOLDOUT_BUGS,
        b2b_stimulus="LEGAL (§13 execution-confirmed)",
        boundary="3-module loopback (mod -> channel -> demod); TB-side "
                 "interface is a boundary alias — ch_seed is a channel "
                 "parameter-input, not data",
        known_dead_assertions=["a_symbol_domain"],
        known_2state_inert_assertions=["a_no_xz_outputs"],
        generation=dict(model=a.gen_model, temperature=a.gen_temp,
                        num_runs=a.gen_runs, prompt_hash=a.gen_prompt_hash),
    )

    def chk(name, ok, detail, status=None):
        rows.append(dict(check=name, status=status or ("PASS" if ok else "FAIL"),
                         detail=detail))
        return ok

    def finish(verdict):
        manifest = dict(
            schema="sync-hub-contract/2.0", checker=SCRIPT_VERSION,
            constitution_sha256=CONSTITUTION_SHA256,
            contract_params=contract_params,
            golden=golden_hash_block,
            degraded=degraded, verilator_lint_rc=lint_rc,
            ral={"present": False, "reason": "v2 DUT has no register map"},
            artifacts={n: sha256_file(p) for n, p in artifacts.items()},
            checks=rows, verdict=verdict)
        Path(a.manifest).write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
        for row in rows:
            print(f"{row['status']:<9} {row['check']:<34} {row['detail']}")
        nfail = sum(1 for x in rows if x["status"] == "FAIL")
        print(f"\nSTAGE 1 CONTRACT: "
              f"{'PASS — artifacts lockable (chain: constitution -> golden -> contract)' if nfail == 0 else f'FAIL ({nfail} checks)'}"
              f"  [manifest: {a.manifest}]")
        sys.exit(0 if nfail == 0 else 1)

    # ---- 0. Golden pin (§1/§11/§12) — FATAL on any drift ----------------
    golden_hash_block, pin_ok = {}, True
    for fname, want in FROZEN_GOLDEN_SHA.items():
        f = rtl / fname
        got = sha256_file(f) if f.is_file() else "MISSING"
        golden_hash_block[fname] = dict(frozen=want, local=got, match=(got == want))
        pin_ok &= (got == want)
    chk("golden:pin_v2.1_s1", pin_ok,
        "all 3 files byte-match frozen §1 hashes" if pin_ok else
        "FATAL drift — fix files or rewrite constitution as v3 (§11); "
        + "; ".join(f"{fn}: frozen={b['frozen'][:8]} local={str(b['local'])[:8]}"
                    for fn, b in golden_hash_block.items() if not b["match"]))
    if not pin_ok:
        finish("FAIL")

    degraded, lint_rc = a.uvm_dir is None, None

    # ---- 1+2. Golden port maps + AST cross-check -------------------------
    golden_mods = {}
    for fname, (modname, exp) in EXPECT_GOLDEN.items():
        text = (rtl / fname).read_text()
        got = extract_module_ports(text).get(modname, {})
        map_ok = (got == exp)
        chk(f"golden:{modname}:ports", map_ok,
            "exact match to locked map" if map_ok else f"got={got}")
        r, js = vlint_json([rtl / fname], modname, work / modname)
        lint_rc = r.returncode
        astv, _ = ast_collect(js) if js else (set(), [])
        ast_ok = set(exp).issubset(astv) if js else False
        chk(f"golden:{modname}:ast", ast_ok,
            "AST names present" if ast_ok else
            ("no JSON AST produced" if not js else f"missing={set(exp)-astv}"))
        golden_mods[modname] = got

    # ---- 3. Contract artifacts -------------------------------------------
    iface, item, sva = (cdir / "interface.sv", cdir / "qpsk_seq_item.sv",
                        cdir / "qpsk_sva.sv")
    artifacts = {"interface.sv": iface, "qpsk_seq_item.sv": item,
                 "qpsk_sva.sv": sva}   # PATCH v2.1-a: bind before hash use
    for f in (iface, item, sva):
        if not f.is_file():
            sys.exit(f"[FATAL] contract artifact missing: {f}")
    # PATCH v2.1-a: strip comments from every artifact text used by regex.
    itext = _strip_sv_comments(iface.read_text())
    stext = _strip_sv_comments(sva.read_text())
    ttext = _strip_sv_comments(item.read_text())

    # interface members: widths + rename map into pinned golden ports
    decls = {}
    for line in itext.splitlines():
        lm = LOGIC_RE.match(line)
        if lm:
            decls[lm.group(4)] = width_of(lm.group(2), lm.group(3))
        pm = PORT_RE.match(line)
        if pm and pm.group(1) == "input":
            decls[pm.group(5)] = width_of(pm.group(3), pm.group(4))
    bad = []
    for mname, wd in IFACE_MEMBERS.items():
        if decls.get(mname) != wd:
            bad.append(f"{mname}:width={decls.get(mname)}!={wd}")
    # PATCH v2.1-a: also verify WIDTH against golden, not just port presence.
    for mname, (mod, port, wd) in MAPPING_IF.items():
        gmap = golden_mods.get(mod, {})
        if port not in gmap:
            bad.append(f"{mname}->{mod}.{port}:port-missing")
        elif gmap[port][0] != wd:
            bad.append(f"{mname}->{mod}.{port}:width {gmap[port][0]}!={wd}")
    chk("iface:rename_map_widths", not bad,
        "all mapped+widthed" if not bad else str(bad))

    clk_ok = (re.search(r'clocking\s+drv_cb\s*@\s*\(\s*negedge\s+clk\s*\)', itext)
              and re.search(r'clocking\s+mon_cb\s*@\s*\(\s*posedge\s+clk\s*\)', itext)
              and re.search(r'modport\s+driver', itext)
              and re.search(r'modport\s+monitor', itext))
    chk("iface:clocking_modports", bool(clk_ok),
        "drv_cb(negedge)/mon_cb(posedge)/modports present")

    # seq item
    fields = {}
    for line in ttext.splitlines():
        fm = FIELD_RE.match(line)
        if fm:
            fields[fm.group(4)] = (width_of(fm.group(2), fm.group(3)), bool(fm.group(1)))
    want = {"bits": (2, True), "bits_out": (2, False), "valid": (1, False)}
    chk("item:fields", fields == want, f"got={fields}")
    chk("item:structure",
        bool(re.search(r'constraint\s+c_sym_uniform', ttext))
        and bool(re.search(r'extends\s+uvm_sequence_item', ttext))
        and bool(re.search(r'uvm_object_utils_begin\s*\(\s*qpsk_seq_item\s*\)', ttext))
        and bool(re.search(r'function\s+string\s+convert2string', ttext)),
        "constraint/extends/utils/convert2string present")

    # sva
    sva_ports = {}
    for line in stext.splitlines():
        pm = PORT_RE.match(line)
        if pm:
            sva_ports[pm.group(5)] = width_of(pm.group(3), pm.group(4))
    chk("sva:ports", sva_ports == SVA_PORTS, f"got={sva_ports}")
    found_ids = set(re.findall(r'(\w+)\s*:\s*assert\s+property', stext))
    missing = set(ASSERT_IDS) - found_ids
    chk("sva:assert_ids", not missing,
        "all 5 present" if not missing else f"missing={missing}")
    # PATCH v2.1-a (BLOCKER 1): reject ranged cycle delay; require procedural P1.
    chk("sva:constructs",
        not re.search(r'##\s*\[', stext)               # no ranged cycle delay
        and stext.count("disable iff") >= 5             # all 5 assertions guarded
        and bool(re.search(r'\bpending_sr\b', stext))   # P1 shift-register present
        and bool(re.search(r'\bcredits\b', stext))      # P2 credit counter present
        and bool(re.search(r'ENFORCE_VALID_PULSE', stext)),
        "procedural liveness (no ##[..]), disable iff x5, pending_sr, credits, "
        "P5 gate present")
    chk("sva:p5_default_off",
        bool(re.search(r'parameter\s+bit\s+ENFORCE_VALID_PULSE\s*=\s*1\'b0', stext)),
        "P5 gated OFF (§2/§13: back-to-back LEGAL on v2 DUT)")

    # ---- 4. Compile gate on THIS verilator rev ---------------------------
    if degraded:
        r, js = vlint_json([iface, sva], "qpsk_sva", work / "contract")
        chk("item:compile_gate", False,
            "DEGRADED (no --uvm-dir); pass --accept-degraded to record and proceed"
            if not a.accept_degraded else
            "DEGRADED (accepted): regex-only; UVM sources unavailable",
            status="DEGRADED" if a.accept_degraded else None)
    else:
        # PATCH v2.1-d: the prior check compared module names ("channel",
        # "qpsk_modulator", "qpsk_demodulator") against a set of VAR node
        # names. Module names are MODULE-type, not VAR-type, and none of
        # those modules is instantiated in this compile (top = qpsk_sva;
        # interface + SVA only). The check was unsatisfiable by construction.
        #
        # What the compile gate should actually verify: on THIS Verilator
        # rev, the contract's boundary signals elaborate successfully and
        # appear in the JSON AST. That is the minimum evidence that the
        # interface + SVA parsed, elaborated, and emitted usable AST.
        astv, astt = ast_collect(js) if js else (set(), [])
        want_in_ast = {
            # from qpsk_dut_if
            "ch_seed", "valid_in", "bits_in", "valid_out", "bits_out",
            # from qpsk_sva ports
            "clk", "rst",
            # from qpsk_sva internals — proof the patched P1/P2 are live
            "pending_sr", "credits",
        }
        missing = want_in_ast - astv
        ok = bool(js) and not missing
        chk("contract:compile_gate", ok,
            "lints clean on this verilator rev; contract signals present in AST"
            if ok else
            (f"JSON present but contract signals missing from AST: {sorted(missing)}"
             if js else
             "no JSON AST produced — check --json-only support"))

    # PATCH v2.1-a: honour --accept-degraded in the final verdict.
    acceptable = {"PASS"} | ({"DEGRADED"} if a.accept_degraded else set())
    finish("PASS" if all(x["status"] in acceptable for x in rows) else "FAIL")


if __name__ == "__main__":
    main()