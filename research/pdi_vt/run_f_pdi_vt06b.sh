#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$ROOT/research/pdi_vt/.f_pdi_vt06b_runtime.sh"
curl -fsSL "https://raw.githubusercontent.com/abhedwig-cell/SWAP5/71ae7bee45afb2b844ec81f5b38ff6cdf21d5f15/research/pdi_vt/run_f_pdi_vt04_full_swap.sh" -o "$TMP"
sed -i 's/f_pdi_vt04_make_case.py/f_pdi_vt06b_cold_case.py/g' "$TMP"
# Diagnostic-only: preserve the runtime tree after the frozen gate so BFO state/flux arrays can be analysed.
sed -i "s/trap 'rm -rf \"\$BUILDROOT\"' EXIT/trap ':' EXIT/" "$TMP"
chmod +x "$TMP"
bash "$TMP" /tmp/f_pdi_vt06b_base.json

BUILDROOT="$(find "${RUNNER_TEMP:-/tmp}" -maxdepth 1 -type d -name 'f-pdi-vt04-*' -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)"
[[ -n "$BUILDROOT" && -d "$BUILDROOT" ]]
for label in control-vap candidate-vap control-novap candidate-novap; do
  cp "$BUILDROOT/$label/result.bfo" "/tmp/${label}.bfo"
done

python3 "$ROOT/research/pdi_vt/f_pdi_vt04a_analyze.py" \
  /tmp/control-vap.bfo /tmp/candidate-vap.bfo \
  /tmp/control-novap.bfo /tmp/candidate-novap.bfo \
  | tee /tmp/F-PDI-VT06B_DIAGNOSTICS.json
