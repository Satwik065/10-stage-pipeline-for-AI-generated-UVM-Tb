#!/usr/bin/env bash
# Stage 1 contract false-fire proof (Verilator only).
set -uo pipefail
cd "$(dirname "$0")"

SEEDS=(42 1337 9001 271828 314159)
MUTANTS=(
  golden
  W-01_mod_latency_plus1
  W-02_demod_latency_plus1
  W-05_mod_reset_late
  W-06_demod_reset_late
  W-09_ch_latency_plus1
)

mkdir -p .p1_work
FAILS=0
for mut in "${MUTANTS[@]}"; do
  MOD=./rtl/qpsk_modulator.sv
  CH=./rtl/channel.sv
  DEM=./rtl/qpsk_demodulator.sv
  if [[ "$mut" != "golden" ]]; then
    if [[ ! -f "mutants/${mut}/manifest.json" ]]; then
      echo "MISSING_MANIFEST  $mut"; FAILS=$((FAILS+1)); continue
    fi
    TGT_BASE=$(python3 -c "import json; print(json.load(open('mutants/${mut}/manifest.json'))['target_file'].split('/')[-1])")
    case "$TGT_BASE" in
      qpsk_modulator.sv)   MOD="mutants/${mut}/${TGT_BASE}" ;;
      channel.sv)          CH="mutants/${mut}/${TGT_BASE}" ;;
      qpsk_demodulator.sv) DEM="mutants/${mut}/${TGT_BASE}" ;;
      *) echo "UNKNOWN_TARGET  $mut -> $TGT_BASE"; FAILS=$((FAILS+1)); continue ;;
    esac
  fi

  MDIR=".p1_work/${mut}"
  rm -rf "$MDIR"; mkdir -p "$MDIR"

  # Try --binary first (Verilator 5.x); fall back to --main for older 5.x.
  if ! verilator --binary --timing --assert -Wno-fatal \
       --Mdir "$MDIR" --top-module tb_p1_check \
       tb/tb_p1_check.sv "$MOD" "$CH" "$DEM" contract/qpsk_sva.sv \
       > "$MDIR/build.log" 2>&1; then
    # Fallback: --main instead of --binary
    rm -rf "$MDIR"; mkdir -p "$MDIR"
    if ! verilator --main --timing --assert -Wno-fatal \
         --Mdir "$MDIR" --top-module tb_p1_check \
         tb/tb_p1_check.sv "$MOD" "$CH" "$DEM" contract/qpsk_sva.sv \
         > "$MDIR/build.log" 2>&1; then
      echo "BUILD_FAIL    $mut  (see $MDIR/build.log)"; FAILS=$((FAILS+1)); continue
    fi
  fi

  # binary name: V<top> for --binary; both modes produce ./V<top> in Mdir
  BIN="$MDIR/Vtb_p1_check"
  if [[ ! -x "$BIN" ]]; then
    echo "NO_BINARY     $mut  (looked for $BIN; see $MDIR/build.log)"
    FAILS=$((FAILS+1)); continue
  fi

  for seed in "${SEEDS[@]}"; do
    LOG="$MDIR/run_${seed}.log"
    "$BIN" "+CHSEED=${seed}" > "$LOG" 2>&1 || true
    if   grep -q "\[SVA\]\[P1\]" "$LOG"; then
      echo "P1_FIRE       $mut seed=$seed  (see $LOG)"; FAILS=$((FAILS+1))
    elif grep -q "\[SVA\]\[P2\]" "$LOG"; then
      echo "P2_FIRE       $mut seed=$seed  (see $LOG)"; FAILS=$((FAILS+1))
    elif grep -q "\[SVA\]\[P3\]" "$LOG"; then
      echo "P3_FIRE       $mut seed=$seed  (see $LOG)"; FAILS=$((FAILS+1))
    elif grep -q "\[SVA\]\[P4\]" "$LOG"; then
      echo "P4_FIRE       $mut seed=$seed  (see $LOG)"; FAILS=$((FAILS+1))
    elif grep -q "\[RESULT\] PASS" "$LOG"; then
      echo "OK            $mut seed=$seed"
    else
      echo "NO_RESULT     $mut seed=$seed  (see $LOG)"; FAILS=$((FAILS+1))
    fi
  done
done

echo
if [[ $FAILS -eq 0 ]]; then
  echo "CONTRACT FALSE-FIRE PROOF: PASS (0 assertion fires across 30 cells/seeds)"
  exit 0
else
  echo "CONTRACT FALSE-FIRE PROOF: FAIL ($FAILS failures)"
  exit 1
fi