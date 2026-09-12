#!/usr/bin/env python3
"""Stage 3 battery builder — deterministic clone+mutate (Constitution v2.0).
Reads rtl/qpsk_modulator.sv, rtl/qpsk_demodulator.sv, rtl/channel.sv.
Writes 22 mutants (10 Weather, 12 Sabotage) into ./mutants/<ID>/.
Pure anchored string substitution — zero LLM. Every anchor must occur
EXACTLY once or the build aborts. Re-running produces byte-identical
output; --verify proves it. v2.0 adds 8 channel-targeted mutants."""
import argparse, hashlib, json, shutil, sys
from pathlib import Path

SCRIPT_VERSION = "stage3_build_battery-v2.0"
MOD_FILE = "qpsk_modulator.sv"
DEM_FILE = "qpsk_demodulator.sv"
CH_FILE  = "channel.sv"
GOLDEN_DIR = Path("./rtl")
OUT_DIR = Path("./mutants")

# ---- modulator anchors -------------------------------------------------
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

# ---- channel anchors ---------------------------------------------------
CH_NOISE_BODY = (
    "            3'd0:    noise3 = -9'sd3;\n"
    "            3'd1:    noise3 = -9'sd2;\n"
    "            3'd2:    noise3 = -9'sd1;\n"
    "            3'd3:    noise3 =  9'sd0;\n"
    "            3'd4:    noise3 =  9'sd1;\n"
    "            3'd5:    noise3 =  9'sd2;\n"
    "            default: noise3 =  9'sd3;   // 3'd6, 3'd7\n"
)
CH_ROT_BLOCK = (
    "    wire signed [8:0] i_rot = i_ext - (q_ext >>> 4);\n"
    "    wire signed [8:0] q_rot = q_ext + (i_ext >>> 4);\n"
)
CH_OUT_BLOCK = (
    "    always @(posedge clk) begin\n"
    "        if (rst) begin\n"
    "            valid_out <= 1'b0;\n"
    "            i_out     <= 8'sd0;\n"
    "            q_out     <= 8'sd0;\n"
    "        end else begin\n"
    "            valid_out <= valid_in;                            // timing untouched\n"
    "            i_out     <= sat8(i_rot + noise3(lfsr[2:0]));\n"
    "            q_out     <= sat8(q_rot + noise3(lfsr[5:3]));\n"
    "        end\n"
    "    end\n"
)

# ---- mutations ---------------------------------------------------------
MUTATIONS = [
 # =================== ORIGINAL (v1.5) — DUT-level =====================
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
      desc="mod drives I/Q=0 when !valid_in",
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
      desc="mod reset effective one cycle late",
      expected="PASS", signature="PASS: no [ERROR] lines (BKG is reset-aware)",
      ops=[(MOD_FILE, A_ALWAYS, "    reg rst_d = 1'b1;\n\n" + A_ALWAYS),
           (MOD_FILE, A_IFRST, "        rst_d <= rst;\n        if (rst_d) begin\n")]),
 dict(id="W-06_demod_reset_late", lane="weather", target=DEM_FILE,
      desc="demod reset effective one cycle late",
      expected="PASS", signature="PASS: no [ERROR] lines (BKG is reset-aware)",
      ops=[(DEM_FILE, A_ALWAYS, "    reg rst_d = 1'b1;\n\n" + A_ALWAYS),
           (DEM_FILE, A_IFRST, "        rst_d <= rst;\n        if (rst_d) begin\n")]),
 dict(id="S-01_const_sym10_i", lane="sabotage", target=MOD_FILE,
      desc="symbol 10 I corrupted to +127", expected="FAIL",
      signature="ONLY MISMATCH exp=10 got=00 (x10, every sym10); classes={MISMATCH}",
      ops=[(MOD_FILE, A_ARM10,
            "                2'b10: begin i_out <=  127; q_out <=  127; end\n")]),
 dict(id="S-02_const_sym01_q", lane="sabotage", target=MOD_FILE,
      desc="symbol 01 Q corrupted to +127", expected="FAIL",
      signature="ONLY MISMATCH exp=01 got=00 (x10, every sym01); classes={MISMATCH}",
      ops=[(MOD_FILE, A_ARM01,
            "                2'b01: begin i_out <=  127; q_out <=  127; end\n")]),
 dict(id="S-03_slice_invert_i", lane="sabotage", target=DEM_FILE,
      desc="demod I comparator polarity inverted", expected="FAIL",
      signature="MISMATCH {00->10, 01->11, 10->00, 11->01}; classes={MISMATCH}",
      ops=[(DEM_FILE, A_SLICE_I,
            "            bits[1]   <= (i_in >= 8'sd0) ? 1'b1 : 1'b0;\n")]),
 dict(id="S-04_slice_swap_iq", lane="sabotage", target=DEM_FILE,
      desc="demod slices I and Q swapped", expected="FAIL",
      signature="ONLY MISMATCH {01->10, 10->01}; 00/11 clean; classes={MISMATCH}",
      ops=[(DEM_FILE, A_SLICE_I,
            "            bits[1]   <= (q_in < 8'sd0) ? 1'b1 : 1'b0;\n"),
           (DEM_FILE, A_SLICE_Q,
            "            bits[0]   <= (i_in < 8'sd0) ? 1'b1 : 1'b0;\n")]),
 dict(id="S-05_mod_valid_gate", lane="sabotage", target=MOD_FILE,
      desc="mod valid_out suppressed when bits[1]==0", expected="FAIL",
      signature="LIVENESS + MISSING cascade; classes={MISMATCH,LIVENESS,MISSING}",
      ops=[(MOD_FILE, A_VOUT, "            valid_out <= valid_in & bits[1];\n")]),
 dict(id="S-06_demod_valid_skew", lane="sabotage", target=DEM_FILE,
      desc="demod data delayed one extra cycle vs valid", expected="FAIL",
      signature="MISMATCH skew: got=previous symbol; first symbol clean",
      ops=[(DEM_FILE, A_ALWAYS, "    reg [1:0] bits_r = 2'b00;\n\n" + A_ALWAYS),
           (DEM_FILE, A_SLICE_I + A_SLICE_Q,
            "            bits_r[1] <= (i_in < 8'sd0) ? 1'b1 : 1'b0;\n"
            "            bits_r[0] <= (q_in < 8'sd0) ? 1'b1 : 1'b0;\n"
            "            bits      <= bits_r;\n")]),
 dict(id="S-07_const_sym00_i", lane="sabotage", target=MOD_FILE,
      desc="symbol 00 I corrupted to -128", expected="FAIL",
      signature="ONLY MISMATCH exp=00 got=10; classes={MISMATCH}",
      ops=[(MOD_FILE, A_ARM00,
            "                2'b00: begin i_out <= -128; q_out <=  127; end\n")]),
 dict(id="S-08_demod_valid_dup", lane="sabotage", target=DEM_FILE,
      desc="demod asserts valid_out twice per input symbol", expected="FAIL",
      signature="DUPLICATE valid_out after every symbol; classes={DUPLICATE}",
      ops=[(DEM_FILE, A_ALWAYS, "    reg valid_d = 1'b0;\n\n" + A_ALWAYS),
           (DEM_FILE, A_VOUT,
            "            valid_out <= valid_in | valid_d;\n"
            "            valid_d   <= valid_in;\n")]),

 # =================== NEW (v2.0) — CHANNEL-LEVEL =====================
 dict(id="W-07_ch_noise_doubled", lane="weather", target=CH_FILE,
      desc="channel noise amplitude doubled (±6 LSB) — still recoverable",
      expected="PASS",
      signature="PASS: no [ERROR] lines; BER within MISMATCH_BUDGET",
      ops=[(CH_FILE, CH_NOISE_BODY,
            "            3'd0:    noise3 = -9'sd6;\n"
            "            3'd1:    noise3 = -9'sd4;\n"
            "            3'd2:    noise3 = -9'sd2;\n"
            "            3'd3:    noise3 =  9'sd0;\n"
            "            3'd4:    noise3 =  9'sd2;\n"
            "            3'd5:    noise3 =  9'sd4;\n"
            "            default: noise3 =  9'sd6;   // 3'd6, 3'd7\n")]),
 dict(id="W-08_ch_rotation_doubled", lane="weather", target=CH_FILE,
      desc="channel rotation angle doubled (~7°) — still recoverable",
      expected="PASS",
      signature="PASS: no [ERROR] lines; symbols still far from decision boundary",
      ops=[(CH_FILE, CH_ROT_BLOCK,
            "    wire signed [8:0] i_rot = i_ext - (q_ext >>> 3);\n"
            "    wire signed [8:0] q_rot = q_ext + (i_ext >>> 3);\n")]),
 dict(id="W-09_ch_latency_plus1", lane="weather", target=CH_FILE,
      desc="channel adds one extra cycle (baseline 3 -> 4 cycles)",
      expected="PASS",
      signature="PASS: no [ERROR] lines (BKG queue is latency-agnostic)",
      ops=[(CH_FILE, CH_OUT_BLOCK,
            "    reg              r_valid;\n"
            "    reg signed [7:0] r_i, r_q;\n"
            "    always @(posedge clk) begin\n"
            "        if (rst) begin\n"
            "            r_valid   <= 1'b0;\n"
            "            r_i       <= 8'sd0;\n"
            "            r_q       <= 8'sd0;\n"
            "            valid_out <= 1'b0;\n"
            "            i_out     <= 8'sd0;\n"
            "            q_out     <= 8'sd0;\n"
            "        end else begin\n"
            "            r_valid   <= valid_in;\n"
            "            r_i       <= sat8(i_rot + noise3(lfsr[2:0]));\n"
            "            r_q       <= sat8(q_rot + noise3(lfsr[5:3]));\n"
            "            valid_out <= r_valid;\n"
            "            i_out     <= r_i;\n"
            "            q_out     <= r_q;\n"
            "        end\n"
            "    end\n")]),
 dict(id="W-10_ch_idle_zero", lane="weather", target=CH_FILE,
      desc="channel drives I/Q=0 when !valid_in (legal)",
      expected="PASS", signature="PASS: no [ERROR] lines",
      ops=[(CH_FILE, CH_OUT_BLOCK,
            "    always @(posedge clk) begin\n"
            "        if (rst) begin\n"
            "            valid_out <= 1'b0;\n"
            "            i_out     <= 8'sd0;\n"
            "            q_out     <= 8'sd0;\n"
            "        end else if (valid_in) begin\n"
            "            valid_out <= 1'b1;\n"
            "            i_out     <= sat8(i_rot + noise3(lfsr[2:0]));\n"
            "            q_out     <= sat8(q_rot + noise3(lfsr[5:3]));\n"
            "        end else begin\n"
            "            valid_out <= 1'b0;\n"
            "            i_out     <= 8'sd0;\n"
            "            q_out     <= 8'sd0;\n"
            "        end\n"
            "    end\n")]),
 dict(id="S-09_ch_q_inversion", lane="sabotage", target=CH_FILE,
      desc="channel negates Q — every symbol flips Q-bit",
      expected="FAIL",
      signature="MISMATCH {00->01, 01->00, 10->11, 11->10}; classes={MISMATCH}",
      ops=[(CH_FILE, CH_OUT_BLOCK,
            "    always @(posedge clk) begin\n"
            "        if (rst) begin\n"
            "            valid_out <= 1'b0;\n"
            "            i_out     <= 8'sd0;\n"
            "            q_out     <= 8'sd0;\n"
            "        end else begin\n"
            "            valid_out <= valid_in;\n"
            "            i_out     <= sat8(i_rot + noise3(lfsr[2:0]));\n"
            "            q_out     <= sat8(-(q_rot + noise3(lfsr[5:3])));\n"
            "        end\n"
            "    end\n")]),
 dict(id="S-10_ch_drop_valid", lane="sabotage", target=CH_FILE,
      desc="channel suppresses valid_out every 4th valid input",
      expected="FAIL",
      signature="Periodic MISSING/LIVENESS; classes={LIVENESS,MISSING}",
      ops=[(CH_FILE, CH_OUT_BLOCK,
            "    reg [2:0] cnt = 3'd0;\n"
            "    always @(posedge clk) begin\n"
            "        if (rst) cnt <= 3'd0;\n"
            "        else if (valid_in) cnt <= cnt + 3'd1;\n"
            "    end\n"
            "    always @(posedge clk) begin\n"
            "        if (rst) begin\n"
            "            valid_out <= 1'b0;\n"
            "            i_out     <= 8'sd0;\n"
            "            q_out     <= 8'sd0;\n"
            "        end else begin\n"
            "            valid_out <= valid_in & (cnt != 3'd3);\n"
            "            i_out     <= sat8(i_rot + noise3(lfsr[2:0]));\n"
            "            q_out     <= sat8(q_rot + noise3(lfsr[5:3]));\n"
            "        end\n"
            "    end\n")]),
 dict(id="S-11_ch_noise_overload", lane="sabotage", target=CH_FILE,
      desc="channel noise amplitude overloaded (±200 LSB) — unrecoverable",
      expected="FAIL",
      signature="Widespread MISMATCH (BER >> budget); classes={MISMATCH}",
      ops=[(CH_FILE, CH_NOISE_BODY,
            "            3'd0:    noise3 = -9'sd200;\n"
            "            3'd1:    noise3 = -9'sd128;\n"
            "            3'd2:    noise3 = -9'sd64;\n"
            "            3'd3:    noise3 =  9'sd0;\n"
            "            3'd4:    noise3 =  9'sd64;\n"
            "            3'd5:    noise3 =  9'sd128;\n"
            "            default: noise3 =  9'sd200;   // 3'd6, 3'd7\n")]),
 dict(id="S-12_ch_q_zero", lane="sabotage", target=CH_FILE,
      desc="channel forces Q=0 — symbols 01 and 11 lose their Q-bit",
      expected="FAIL",
      signature="MISMATCH {01->00, 11->10}; 00/10 clean; classes={MISMATCH}",
      ops=[(CH_FILE, CH_OUT_BLOCK,
            "    always @(posedge clk) begin\n"
            "        if (rst) begin\n"
            "            valid_out <= 1'b0;\n"
            "            i_out     <= 8'sd0;\n"
            "            q_out     <= 8'sd0;\n"
            "        end else begin\n"
            "            valid_out <= valid_in;\n"
            "            i_out     <= sat8(i_rot + noise3(lfsr[2:0]));\n"
            "            q_out     <= 8'sd0;\n"
            "        end\n"
            "    end\n")]),
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
    gtxt = {f: (GOLDEN_DIR / f).read_text() for f in (MOD_FILE, DEM_FILE, CH_FILE)}
    if OUT_DIR.exists(): shutil.rmtree(OUT_DIR)
    OUT_DIR.mkdir(parents=True)
    rendered = render(gtxt)
    battery = dict(schema="sync-hub-battery/2.0", builder=SCRIPT_VERSION,
                   golden={f: sha256_bytes(t.encode()) for f, t in gtxt.items()},
                   channel_sha256=sha256_bytes(gtxt[CH_FILE].encode()),
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
    gtxt = {f: (GOLDEN_DIR / f).read_text() for f in (MOD_FILE, DEM_FILE, CH_FILE)}
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
    ap.add_argument("--verify", action="store_true")
    a = ap.parse_args()
    verify() if a.verify else build()