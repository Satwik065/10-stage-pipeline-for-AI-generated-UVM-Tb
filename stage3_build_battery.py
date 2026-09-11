#!/usr/bin/env python3
"""Stage 3 battery builder — deterministic clone+mutate (Constitution v1.5).
Reads ./rtl/qpsk_modulator.sv and ./rtl/qpsk_demodulator.sv, writes 14
mutants into ./mutants/<ID>/ (mutated file + manifest.json each) plus
./mutants/battery.json. Pure anchored string substitution — zero LLM.
Every anchor must occur EXACTLY once or the build aborts. Re-running
produces byte-identical output; --verify proves it. v1.5.

NOTE (S-07 redesign per Constitution §8): the tabled S-07 (constellation
arms 01/10 transposed) is observably identical in loopback to S-04 (I/Q
slice swap) — both yield only {01->10, 10->01}. S-07 is therefore built
as "symbol 00 I corrupted to -128" (CONST, hold-out, ONLY 00->10).
§8 table now reflects S-07 redesign; freezing v1.5."""
import argparse, hashlib, json, shutil, sys
from pathlib import Path

SCRIPT_VERSION = "stage3_build_battery-v1.5"
MOD_FILE = "qpsk_modulator.sv"
DEM_FILE = "qpsk_demodulator.sv"
GOLDEN_DIR = Path("./rtl")
OUT_DIR = Path("./mutants")

# ---- exact anchors from the hashed Golden RTL (Constitution §1) --------
A_ALWAYS   = "    always @(posedge clk) begin\n"
A_IFRST    = "        if (rst) begin\n"
A_RST_M    = ("            valid_out <= 1'b0;\n"
              "            i_out     <= 8'sd0;\n"
              "            q_out     <= 8'sd0;\n")
A_RST_D    = ("            valid_out <= 1'b0;\n"
              "            bits      <= 2'b00;\n")
A_VOUT     = "            valid_out <= valid_in;\n"
A_ARM00    = "                2'b00: begin i_out <=  127; q_out <=  127; end\n"
A_ARM01    = "                2'b01: begin i_out <=  127; q_out <= -128; end\n"
A_ARM10    = "                2'b10: begin i_out <= -128; q_out <=  127; end\n"
A_BODY_M   = ("            valid_out <= valid_in;\n"
              "            case (bits)\n"
              "                2'b00: begin i_out <=  127; q_out <=  127; end\n"
              "                2'b01: begin i_out <=  127; q_out <= -128; end\n"
              "                2'b10: begin i_out <= -128; q_out <=  127; end\n"
              "                2'b11: begin i_out <= -128; q_out <= -128; end\n"
              "            endcase\n")
A_SLICE_I  = "            bits[1]   <= (i_in < 8'sd0) ? 1'b1 : 1'b0;\n"
A_SLICE_Q  = "            bits[0]   <= (q_in < 8'sd0) ? 1'b1 : 1'b0;\n"
A_BODY_D   = A_VOUT + A_SLICE_I + A_SLICE_Q

IND_CASE = ("                2'b00: begin i_out <=  127; q_out <=  127; end\n"
            "                2'b01: begin i_out <=  127; q_out <= -128; end\n"
            "                2'b10: begin i_out <= -128; q_out <=  127; end\n"
            "                2'b11: begin i_out <= -128; q_out <= -128; end\n"
            "            endcase\n")

MUTATIONS = [
 dict(id="W-01_mod_latency_plus1", lane="weather", target=MOD_FILE,
      desc="mod outputs staged through one extra aligned register (+1 cycle)",
      expected="PASS", signature="PASS: no [ERROR] lines; +1 latency only",
      ops=[(MOD_FILE, A_ALWAYS,
            "    reg              r_valid;\n    reg signed [7:0] r_i;"
            "\n    reg signed [7:0] r_q;\n\n" + A_ALWAYS),
           (MOD_FILE, A_RST_M,
            A_RST_M + "            r_valid   <= 1'b0;\n"
            "            r_i       <= 8'sd0;\n            r_q       <= 8'sd0;\n"),
           (MOD_FILE, A_BODY_M,
            "            r_valid   <= valid_in;\n            case (bits)\n"
            "                2'b00: begin r_i <=  127; r_q <=  127; end\n"
            "                2'b01: begin r_i <=  127; r_q <= -128; end\n"
            "                2'b10: begin r_i <= -128; r_q <=  127; end\n"
            "                2'b11: begin r_i <= -128; r_q <= -128; end\n"
            "            endcase\n"
            "            valid_out <= r_valid;\n            i_out     <= r_i;\n"
            "            q_out     <= r_q;\n")]),
 dict(id="W-02_demod_latency_plus1", lane="weather", target=DEM_FILE,
      desc="demod outputs staged through one extra aligned register (+1 cycle)",
      expected="PASS", signature="PASS: no [ERROR] lines; +1 latency only",
      ops=[(DEM_FILE, A_ALWAYS,
            "    reg       r_valid;\n    reg [1:0] r_bits;\n\n" + A_ALWAYS),
           (DEM_FILE, A_RST_D,
            A_RST_D + "            r_valid   <= 1'b0;\n"
            "            r_bits    <= 2'b00;\n"),
           (DEM_FILE, A_VOUT, "            r_valid   <= valid_in;\n"),
           (DEM_FILE, A_SLICE_I + A_SLICE_Q,
            "            r_bits    <= {(i_in < 8'sd0), (q_in < 8'sd0)};\n"
            "            valid_out <= r_valid;\n            bits      <= r_bits;\n")]),
 dict(id="W-03_mod_idle_zero", lane="weather", target=MOD_FILE,
      desc="mod drives I/Q=0 when !valid_in (legal: data meaningful at valid only)",
      expected="PASS", signature="PASS: no [ERROR] lines",
      ops=[(MOD_FILE, A_BODY_M,
            A_VOUT + "            if (valid_in) begin\n                case (bits)\n"
            + IND_CASE
            + "            end else begin\n                i_out <= 8'sd0;\n"
              "                q_out <= 8'sd0;\n            end\n")]),
 dict(id="W-04_demod_idle_zero", lane="weather", target=DEM_FILE,
      desc="demod drives bits=0 when !valid_in",
      expected="PASS", signature="PASS: no [ERROR] lines",
      ops=[(DEM_FILE, A_BODY_D,
            A_VOUT + "            if (valid_in) begin\n"
            "                bits[1]   <= (i_in < 8'sd0) ? 1'b1 : 1'b0;\n"
            "                bits[0]   <= (q_in < 8'sd0) ? 1'b1 : 1'b0;\n"
            "            end else begin\n                bits      <= 2'b00;\n"
            "            end\n")]),
 dict(id="W-05_mod_reset_late", lane="weather", target=MOD_FILE,
      desc="mod reset effective one cycle late (rst_d register) — driver trap",
      expected="PASS", signature="PASS: no [ERROR] lines (BKG is reset-aware)",
      ops=[(MOD_FILE, A_ALWAYS, "    reg rst_d = 1'b1;\n\n" + A_ALWAYS),
           (MOD_FILE, A_IFRST, "        rst_d <= rst;\n        if (rst_d) begin\n")]),
 dict(id="W-06_demod_reset_late", lane="weather", target=DEM_FILE,
      desc="demod reset effective one cycle late (rst_d register) — driver trap",
      expected="PASS", signature="PASS: no [ERROR] lines (BKG is reset-aware)",
      ops=[(DEM_FILE, A_ALWAYS, "    reg rst_d = 1'b1;\n\n" + A_ALWAYS),
           (DEM_FILE, A_IFRST, "        rst_d <= rst;\n        if (rst_d) begin\n")]),
 dict(id="S-01_const_sym10_i", lane="sabotage", target=MOD_FILE,
      desc="symbol 10 I corrupted to +127",
      expected="FAIL",
      signature="ONLY MISMATCH exp=10 got=00 (x10, every sym10); classes={MISMATCH}",
      ops=[(MOD_FILE, A_ARM10,
            "                2'b10: begin i_out <=  127; q_out <=  127; end\n")]),
 dict(id="S-02_const_sym01_q", lane="sabotage", target=MOD_FILE,
      desc="symbol 01 Q corrupted to +127",
      expected="FAIL",
      signature="ONLY MISMATCH exp=01 got=00 (x10, every sym01); classes={MISMATCH}",
      ops=[(MOD_FILE, A_ARM01,
            "                2'b01: begin i_out <=  127; q_out <=  127; end\n")]),
 dict(id="S-03_slice_invert_i", lane="sabotage", target=DEM_FILE,
      desc="demod I comparator polarity inverted (all symbols flip I bit)",
      expected="FAIL",
      signature="MISMATCH {00->10, 01->11, 10->00, 11->01} (x10 each); classes={MISMATCH}",
      ops=[(DEM_FILE, A_SLICE_I,
            "            bits[1]   <= (i_in >= 8'sd0) ? 1'b1 : 1'b0;\n")]),
 dict(id="S-04_slice_swap_iq", lane="sabotage", target=DEM_FILE,
      desc="demod slices I and Q swapped",
      expected="FAIL",
      signature="ONLY MISMATCH {01->10, 10->01} (x10 each); 00/11 clean; classes={MISMATCH}",
      ops=[(DEM_FILE, A_SLICE_I,
            "            bits[1]   <= (q_in < 8'sd0) ? 1'b1 : 1'b0;\n"),
           (DEM_FILE, A_SLICE_Q,
            "            bits[0]   <= (i_in < 8'sd0) ? 1'b1 : 1'b0;\n")]),
 dict(id="S-05_mod_valid_gate", lane="sabotage", target=MOD_FILE,
      desc="mod valid_out suppressed when bits[1]==0 (symbols 00,01 lose valid)",
      expected="FAIL",
      signature="LIVENESS recurring + END MISSING~10 + MISMATCH cascade "
                "(exp00/exp01/exp11 vs got=10, round-phase dependent); "
                "classes={MISMATCH,LIVENESS,MISSING}",
      ops=[(MOD_FILE, A_VOUT, "            valid_out <= valid_in & bits[1];\n")]),
 dict(id="S-06_demod_valid_skew", lane="sabotage", target=DEM_FILE,
      desc="demod data delayed one extra cycle vs valid (skew)",
      expected="FAIL",
      signature="MISMATCH skew: got=previous symbol {01->00, 10->01, 11->10, "
                "00->11 (R2+)}; first symbol clean; classes={MISMATCH}",
      ops=[(DEM_FILE, A_ALWAYS, "    reg [1:0] bits_r = 2'b00;\n\n" + A_ALWAYS),
           (DEM_FILE, A_SLICE_I + A_SLICE_Q,
            "            bits_r[1] <= (i_in < 8'sd0) ? 1'b1 : 1'b0;\n"
            "            bits_r[0] <= (q_in < 8'sd0) ? 1'b1 : 1'b0;\n"
            "            bits      <= bits_r;\n")]),
 dict(id="S-07_const_sym00_i", lane="sabotage", target=MOD_FILE,
      desc="REDESIGNED per §8 (old S-07 collided with S-04): symbol 00 I "
           "corrupted to -128",
      expected="FAIL",
      signature="ONLY MISMATCH exp=00 got=10 (x10, every sym00); classes={MISMATCH}",
      ops=[(MOD_FILE, A_ARM00,
            "                2'b00: begin i_out <= -128; q_out <=  127; end\n")]),
 dict(id="S-08_demod_valid_dup", lane="sabotage", target=DEM_FILE,
      desc="demod asserts valid_out twice per input symbol",
      expected="FAIL",
      signature="DUPLICATE valid_out after every symbol (x40); classes={DUPLICATE}",
      ops=[(DEM_FILE, A_ALWAYS, "    reg valid_d = 1'b0;\n\n" + A_ALWAYS),
           (DEM_FILE, A_VOUT,
            "            valid_out <= valid_in | valid_d;\n"
            "            valid_d   <= valid_in;\n")]),
]

def sha256_bytes(b): return hashlib.sha256(b).hexdigest()

def apply_ops(fname, text, mid, ops):
    for i, (_f, anchor, repl) in enumerate(ops):
        n = text.count(anchor)
        if n != 1:
            sys.exit(f"[FATAL] {mid} op{i}: anchor found {n}x (need exactly 1) "
                     f"in {fname}:\n{anchor!r}")
        text = text.replace(anchor, repl)
    return text

def render(gtxt):
    """Deterministically render all mutant file texts + manifest dicts."""
    out = []
    for m in MUTATIONS:
        tgt = m["target"]
        text = apply_ops(tgt, gtxt[tgt], m["id"], m["ops"])
        man = dict(id=m["id"], lane=m["lane"], target_file=tgt,
                   transform_description=m["desc"],
                   expected_verdict=m["expected"], signature=m["signature"],
                   golden_source_sha256=sha256_bytes(gtxt[tgt].encode()),
                   mutated_file_sha256=sha256_bytes(text.encode()),
                   builder=SCRIPT_VERSION)
        out.append((m, text, man))
    return out

def build():
    gtxt = {f: (GOLDEN_DIR / f).read_text() for f in (MOD_FILE, DEM_FILE)}
    if OUT_DIR.exists(): shutil.rmtree(OUT_DIR)
    OUT_DIR.mkdir(parents=True)
    rendered = render(gtxt)
    battery = dict(schema="sync-hub-battery/1.5", builder=SCRIPT_VERSION,
                   golden={f: sha256_bytes(t.encode()) for f, t in gtxt.items()},
                   mutants=[])
    for m, text, man in rendered:
        vdir = OUT_DIR / m["id"]; vdir.mkdir()
        (vdir / m["target"]).write_text(text)
        (vdir / "manifest.json").write_text(json.dumps(man, indent=2) + "\n")
        battery["mutants"].append(dict(id=m["id"], lane=m["lane"],
                                       target_file=m["target"],
                                       expected_verdict=m["expected"]))
    (OUT_DIR / "battery.json").write_text(json.dumps(battery, indent=2) + "\n")
    print(f"[OK] built {len(MUTATIONS)} mutants in {OUT_DIR}/ "
          f"(idempotent; re-run to confirm byte-identical)")

def verify():
    gtxt = {f: (GOLDEN_DIR / f).read_text() for f in (MOD_FILE, DEM_FILE)}
    rendered = render(gtxt)
    bad = []
    for m, text, man in rendered:
        vdir = OUT_DIR / m["id"]
        disk = (vdir / m["target"]).read_bytes() if (vdir / m["target"]).exists() else b""
        if disk != text.encode(): bad.append(f"{m['id']}/{m['target']}")
        dman = json.loads((vdir / "manifest.json").read_text())
        if dman != man: bad.append(f"{m['id']}/manifest.json")
    print("[OK] verify: all mutants byte-identical to deterministic rebuild"
          if not bad else f"[FAIL] verify mismatches: {bad}")
    sys.exit(0 if not bad else 1)

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--verify", action="store_true",
                    help="rebuild in memory and byte-compare (idempotence proof)")
    a = ap.parse_args()
    verify() if a.verify else build()