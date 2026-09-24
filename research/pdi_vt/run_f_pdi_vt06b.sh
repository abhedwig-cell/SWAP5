#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$ROOT/research/pdi_vt/.f_pdi_vt06b_runtime.sh"
curl -fsSL "https://raw.githubusercontent.com/abhedwig-cell/SWAP5/71ae7bee45afb2b844ec81f5b38ff6cdf21d5f15/research/pdi_vt/run_f_pdi_vt04_full_swap.sh" -o "$TMP"
sed -i 's/f_pdi_vt04_make_case.py/f_pdi_vt06b_cold_case.py/g' "$TMP"
chmod +x "$TMP"
bash "$TMP" /tmp/f_pdi_vt06b_base.json
# Comparator normalization repair: Generated-at metadata is ignored by f_pdi_vt04_compare.py.
# Vapor-on activation comparison is also metadata-normalized.
