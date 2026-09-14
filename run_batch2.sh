#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"

mkdir -p results/b2

echo "==============================================="
echo "[$(date)] STEP 1 — layout check"
echo "==============================================="
for m in pp km gm; do
  n=$(ls uvm_variants_b2/$m/qpsk_*.sv 2>/dev/null | wc -l)
  echo "  $m: $n files"
done

echo
echo "==============================================="
echo "[$(date)] STEP 2 — ingest"
echo "==============================================="
python3 stage4_ingest_lint.py \
  --variants-dir uvm_variants_b2 \
  --out-dir stage4/ingested_b2 \
  --manifest variants_manifest_b2.json \
  --results-dir results/b2 \
  2>&1 | tee results/b2/stage4_ingest_log.txt

echo
echo "==============================================="
echo "[$(date)] STEP 3 — ingest summary (last 40 lines)"
echo "==============================================="
tail -40 results/b2/stage4_ingest_log.txt

echo
echo "==============================================="
echo "[$(date)] STEP 4 — runner (Way-1 + Way-2)"
echo "==============================================="
python3 stage5_runner_b2.py 2>&1 | tee results/b2/stage5_runlog_b2.txt

echo
echo "==============================================="
echo "[$(date)] DONE"
echo "==============================================="
