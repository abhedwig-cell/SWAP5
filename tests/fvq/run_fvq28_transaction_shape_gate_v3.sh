#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$HERE/.fvq28_gateb_v3_$$.sh"
sed 's/REF_DRIVER_BLOB=68d347550c9f9caaa69c3190e5c7484c12a9d8a6/REF_DRIVER_BLOB=1de0c3037976c73f646f9d680dd09ea4f3fe892c/' \
  "$HERE/run_fvq28_transaction_shape_gate_v2.sh" > "$TMP"
source "$TMP"
