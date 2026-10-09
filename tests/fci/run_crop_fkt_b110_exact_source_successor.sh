#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
# Candidate-specific successor gate; DOES NOT amend or override the frozen
# canonical F-CI checks. Admission requires a separate accepted transition.
BASE=799b9a70fc1e0a436d8c32509aa640d557fbf749
KERNEL=da7a00b6aec996cff504d8d30a90e51a8cce2162
BACKEND=b218ac657db52612bc12da671716c97430200f0a
test "$(git rev-parse HEAD:src/kernel/mod_kernel_transactions.f90)" = "$KERNEL" ||
  { echo 'CROP_FKT_CERT_KERNEL_BLOB_MISMATCH' >&2; exit 1; }
test "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" = "$BACKEND" ||
  { echo 'CROP_FKT_CERT_BACKEND_BLOB_MISMATCH' >&2; exit 1; }
git merge-base --is-ancestor "$BASE" HEAD
# No unrelated solver, reference, transaction or physical production changes.
while IFS= read -r changed; do
 case "$changed" in
  src/kernel/mod_kernel_transactions.f90|src/runtime/mod_fmr_serialized_reference_backend.f90|src/runtime/mod_fmr_crop_certified_sowing_source.f90|src/runtime/mod_fmr_crop_certified_hydrothermal_forcing.f90) ;;
  *) echo "CROP_FKT_CERT_UNQUALIFIED_SOURCE=$changed" >&2; exit 1 ;;
 esac
done < <(git diff --name-only "$BASE" HEAD -- src)
test "$(git rev-parse HEAD:reference)" = "$(git rev-parse "$BASE:reference")" ||
 { echo 'CROP_FKT_CERT_REFERENCE_DRIFT' >&2; exit 1; }
echo 'CROP_FKT_CERT_EXACT_SOURCE_SURFACE=PASS'
if [[ "${1:-}" == '--verify-only' ]]; then exit 0; fi
bash tests/fmig431/run_crop_fkt_b110_scientific_successor.sh
echo 'CROP_FKT_CERT_CANDIDATE_SUCCESSOR=PASS'
