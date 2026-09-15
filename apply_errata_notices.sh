#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

NOTICE='> **POST-ERRATA NOTICE (2026-09-15).** Certain numbers in this
> document are superseded by `errata_v1.md`. Specifically: catch
> semantics (v2), Stage 8 scope (9 → 26 survivors), Weather lane
> attribution (0 unique kills), Qwen reclassification (structural
> malformation, not just backtick-drop), and AER numbers. See
> `errata_v1.md` for the corrected claims. This document is preserved
> as the frozen historical record; errata is the source of truth for
> any number cited in the paper.

---

'

for f in stage5_final.md stage5_b2.md ablation_B.md ablation_C.md \
         experiment_flowchart.md stage8.md stage6.md; do
  if [ ! -f "$f" ]; then
    echo "  [skip] $f (missing)"
    continue
  fi
  # Only prepend if not already present
  if head -5 "$f" | grep -q "POST-ERRATA"; then
    echo "  [ok] $f (already has notice)"
    continue
  fi
  # Prepend notice
  tmp=$(mktemp)
  printf '%s' "$NOTICE" > "$tmp"
  cat "$f" >> "$tmp"
  mv "$tmp" "$f"
  echo "  [patched] $f"
done

echo
echo "Done."
