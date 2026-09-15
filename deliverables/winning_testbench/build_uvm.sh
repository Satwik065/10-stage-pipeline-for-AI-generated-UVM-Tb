#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
verilator --binary --timing --assert -Wno-fatal \
  -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-UNSIGNED -Wno-TIMESCALEMOD -Wno-DECLFILENAME \
  +define+UVM_NO_DPI \
  --build-jobs "$(nproc)" \
  --Mdir .uvm_smoke --top-module qpsk_tb_top \
  +incdir+"$UVM_DIR/src" +incdir+tb/uvm +incdir+contract \
  "$UVM_DIR/src/uvm_pkg.sv" \
  contract/interface.sv \
  tb/uvm/qpsk_pkg.sv tb/uvm/qpsk_tb_top.sv \
  rtl/qpsk_modulator.sv rtl/channel.sv rtl/qpsk_demodulator.sv
