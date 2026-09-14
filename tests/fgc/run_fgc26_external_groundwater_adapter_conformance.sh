#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${TMPDIR:-/tmp}/swap5-fgc26-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

EXPECTED_COUPLING_CONTRACT=fc598d14eabafcb025bb55621f7b00d6d1816f10
EXPECTED_EXCHANGE_CONTRACT=e99ae052fccd9992b76c12a91422a987dce059e2
ACTUAL_COUPLING_CONTRACT="$(git hash-object src/runtime/mod_groundwater_coupling_contract.f90)"
ACTUAL_EXCHANGE_CONTRACT="$(git hash-object src/runtime/mod_groundwater_exchange_service_contract.f90)"
test "$ACTUAL_COUPLING_CONTRACT" = "$EXPECTED_COUPLING_CONTRACT"
test "$ACTUAL_EXCHANGE_CONTRACT" = "$EXPECTED_EXCHANGE_CONTRACT"
echo 'FGC26_FGC17_CONTRACT_PIN=PASS'
echo 'FGC26_FGC18_CONTRACT_PIN=PASS'

python3 - <<'PY'
from pathlib import Path
text=Path('src/adapter/mod_groundwater_external_gateway.f90').read_text().lower()
assert 'extends(groundwater_preparable_exchange_service_t)' in text
assert 'class(external_groundwater_backend_t), pointer :: backend' in text
assert 'native_flux_sign_relative_to_groundwater' in text
assert 'head_native_zero_m' in text
assert 'bind_groundwater_external_gateway_batch' in text
for forbidden in ['modflow', 'open(', 'read(', 'write(']:
    assert forbidden not in text.replace(' ', ''), forbidden
print('FGC26_NO_EXTERNAL_MODEL_TYPES_IN_SWAP_GATEWAY=PASS')
print('FGC26_NO_GATEWAY_FILE_IO=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals \
  -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
BASE_SOURCES=(
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_exchange_service_contract.f90
  src/adapter/mod_groundwater_external_gateway.f90
)

for opt in 0 2; do
  dir="$BUILD/o$opt"
  mkdir -p "$dir"
  if ! gfortran "${COMMON[@]}" -O"$opt" -J "$dir" -I "$dir" "${BASE_SOURCES[@]}" \
      tests/fgc/test_fgc26_external_groundwater_adapter_conformance.f90 -o "$dir/test-main" \
      2>"$dir/compiler-main.txt"; then
    echo "FGC26_COMPILE_MAIN_O${opt}=FAIL" >&2
    cat "$dir/compiler-main.txt" >&2
    exit 30
  fi
  if grep -E 'Warning:' "$dir/compiler-main.txt" | grep -v -F '[-Wcompare-reals]'; then
    echo "FGC26_UNEXPECTED_NON_COMPARE_REAL_WARNING_MAIN_O${opt}=FAIL" >&2
    cat "$dir/compiler-main.txt" >&2
    exit 31
  fi

  if ! gfortran "${COMMON[@]}" -O"$opt" -J "$dir" -I "$dir" "${BASE_SOURCES[@]}" \
      tests/fgc/test_fgc26_direct_commit_and_rebind.f90 -o "$dir/test-direct" \
      2>"$dir/compiler-direct.txt"; then
    echo "FGC26_COMPILE_DIRECT_O${opt}=FAIL" >&2
    cat "$dir/compiler-direct.txt" >&2
    exit 32
  fi
  if grep -E 'Warning:' "$dir/compiler-direct.txt" | grep -v -F '[-Wcompare-reals]'; then
    echo "FGC26_UNEXPECTED_NON_COMPARE_REAL_WARNING_DIRECT_O${opt}=FAIL" >&2
    cat "$dir/compiler-direct.txt" >&2
    exit 33
  fi

  "$dir/test-main" >"$dir/output-main.txt"
  "$dir/test-direct" >"$dir/output-direct.txt"
  cat "$dir/output-main.txt" "$dir/output-direct.txt" >"$dir/output.txt"

  for marker in \
      FGC26_DATUM_UNIT_SIGN_ROUND_TRIP=PASS \
      FGC26_ROLLBACK_RESTART_HANDSHAKE=PASS \
      FGC26_PREPARED_PUBLICATION_QUIESCENT=PASS \
      FGC26_STALE_REVISION_FAIL_CLOSED=PASS \
      FGC26_PARTIAL_RESPONSE_FAIL_CLOSED=PASS \
      FGC26_ADAPTER_FAILURE_FAIL_CLOSED=PASS \
      FGC26_MULTI_CELL_BATCH_ISOLATION=PASS \
      FGC26_TYPED_SERVICE_CONFORMANCE=PASS \
      FGC26_DIRECT_CANDIDATE_COMMIT_AND_FAILURE=PASS \
      FGC26_ACTIVE_PREPARED_REBIND_REJECTED=PASS; do
    grep -Fq "$marker" "$dir/output.txt"
  done
  grep -Fq 'F-GC26 EXTERNAL GROUNDWATER ADAPTER CONFORMANCE GATE PASS' "$dir/output.txt"
  grep -Fq 'F-GC26 DIRECT COMMIT AND REBIND GATE PASS' "$dir/output.txt"
  cat "$dir/output.txt"
  echo "FGC26_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FGC26_O0_O2_OUTPUT_IDENTITY=PASS'
echo 'F-GC26 EXTERNAL GROUNDWATER ADAPTER CONFORMANCE QUALIFICATION PASS'
