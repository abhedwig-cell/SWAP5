#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fkt09-gate-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT

SRC="$ROOT/src/transaction/mod_transaction_reference.f90"
TEST_CERT="$ROOT/tests/transaction/test_transaction_model_certificate.f90"
TEST_CONTEXT="$ROOT/tests/transaction/test_transaction_attempt_context.f90"
COMMON=(-std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace)

bash "$ROOT/tests/transaction/run_a23bl_gate.sh"

gfortran "${COMMON[@]}" -O0 -J "$BUILD/o0" "$SRC" "$TEST_CERT" -o "$BUILD/cert_o0"
"$BUILD/cert_o0" | tee "$BUILD/cert_o0.txt"
gfortran "${COMMON[@]}" -O2 -J "$BUILD/o2" "$SRC" "$TEST_CERT" -o "$BUILD/cert_o2"
"$BUILD/cert_o2" | tee "$BUILD/cert_o2.txt"
diff -u "$BUILD/cert_o0.txt" "$BUILD/cert_o2.txt"

gfortran "${COMMON[@]}" -O0 -J "$BUILD/o0" "$SRC" "$TEST_CONTEXT" -o "$BUILD/context_o0"
"$BUILD/context_o0" | tee "$BUILD/context_o0.txt"
gfortran "${COMMON[@]}" -O2 -J "$BUILD/o2" "$SRC" "$TEST_CONTEXT" -o "$BUILD/context_o2"
"$BUILD/context_o2" | tee "$BUILD/context_o2.txt"
diff -u "$BUILD/context_o0.txt" "$BUILD/context_o2.txt"

if grep -Ein 'mod_soil_water|mod_reference_richards|pressure_head' "$SRC"; then
  echo 'FKT09_GENERICITY_GATE FAIL: model-specific dependency found in transaction source' >&2
  exit 1
fi
if ! grep -Fq 'integer :: temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF' "$SRC"; then
  echo 'FKT09_DEFAULT_MODE_GATE FAIL: legacy full-half mode is not the explicit default' >&2
  exit 1
fi
if ! grep -Fq 'policy%temporal_mode == TX_TEMPORAL_MODEL_CERTIFICATE' "$SRC"; then
  echo 'FKT09_CERTIFICATE_MODE_GATE FAIL: explicit certificate mode dispatch missing' >&2
  exit 1
fi
if ! grep -Fq 'outcome%temporal_certificate_available' "$SRC"; then
  echo 'FKT09_CERTIFICATE_MODE_GATE FAIL: fail-closed certificate availability check missing' >&2
  exit 1
fi

echo 'FKT09_EXISTING_TRANSACTION_REGRESSION=PASS'
echo 'FKT09_MODEL_CERTIFICATE_O0_O2_IDENTITY=PASS'
echo 'FKT09_ATTEMPT_CONTEXT_REGRESSION=PASS'
echo 'FKT09_GENERICITY_GATE=PASS'
echo 'FKT09_MODEL_CERTIFICATE_GATE=PASS'
