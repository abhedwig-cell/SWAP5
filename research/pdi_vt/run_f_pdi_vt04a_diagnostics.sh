#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$ROOT/research/pdi_vt/.f_pdi_vt04a_runtime.sh"
curl -fsSL "https://raw.githubusercontent.com/abhedwig-cell/SWAP5/71ae7bee45afb2b844ec81f5b38ff6cdf21d5f15/research/pdi_vt/run_f_pdi_vt04_full_swap.sh" -o "$TMP"
sed -i 's/f_pdi_vt04_make_case.py/f_pdi_vt04_case_host.py/g' "$TMP"
sed -i "s/trap 'rm -rf \"\$BUILDROOT\"' EXIT/trap ':' EXIT/" "$TMP"
chmod +x "$TMP"
bash "$TMP" /tmp/f_pdi_vt04a_base.json
BUILDROOT="$(find "${RUNNER_TEMP:-/tmp}" -maxdepth 1 -type d -name 'f-pdi-vt04-*' -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)"
[[ -n "$BUILDROOT" && -d "$BUILDROOT" ]]
for label in control-vap candidate-vap control-novap candidate-novap; do
  src="$BUILDROOT/$label/result.bfo"
  [[ -f "$src" ]]
  cp "$src" "/tmp/${label}.bfo"
done
sha256sum /tmp/control-vap.bfo /tmp/candidate-vap.bfo /tmp/control-novap.bfo /tmp/candidate-novap.bfo | tee /tmp/f_pdi_vt04a_bfo.sha256
python3 "$ROOT/research/pdi_vt/f_pdi_vt04a_analyze.py" \
  /tmp/control-vap.bfo /tmp/candidate-vap.bfo \
  /tmp/control-novap.bfo /tmp/candidate-novap.bfo \
  | tee /tmp/f_pdi_vt04a_diagnostics.json
echo "=== BFO header ==="
head -20 /tmp/control-vap.bfo
echo "=== BFO tails ==="
tail -10 /tmp/control-vap.bfo
tail -10 /tmp/candidate-vap.bfo
