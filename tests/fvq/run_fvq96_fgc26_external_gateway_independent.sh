#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

expect_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  if [[ "$actual" != "$expected" ]]; then
    echo "FVQ96_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  fi
  printf 'FVQ96_BLOB_PIN %s=%s\n' "$path" "$actual"
}

# Exact owner-qualified production and unchanged direct contracts.
expect_blob src/adapter/mod_groundwater_external_gateway.f90 f307f17e2fd20983432f91e91ac90aaae8311849
expect_blob src/runtime/mod_groundwater_coupling_contract.f90 fc598d14eabafcb025bb55621f7b00d6d1816f10
expect_blob src/runtime/mod_groundwater_exchange_service_contract.f90 e99ae052fccd9992b76c12a91422a987dce059e2

# Current-canonical owner boundaries that F-GC26 must consume/compose with, not recreate.
expect_blob src/runtime/mod_groundwater_tile_aggregation.f90 d62ecba039d9bef178acde6900b81e9d5b0931eb
expect_blob src/runtime/mod_groundwater_accuracy_binding.f90 b8ac03e810c73519b433f7851c6fd143ba26676a
expect_blob src/runtime/mod_groundwater_coupling_response.f90 645141676536ae8289b9d52433798a965c7baa04
expect_blob src/runtime/mod_groundwater_coupled_restart.f90 0596933ff3ae89c61ab7a0913189a4fa3179e50b
expect_blob src/runtime/mod_groundwater_multiswap_coupler.f90 f2bf0e7d144fd3c0b9dc18f24f24eb4ffb7ffa0f

GATE=src/adapter/mod_groundwater_external_gateway.f90
if grep -Eiq 'use[[:space:]]+mod_groundwater_(tile_aggregation|accuracy_binding|coupling_response|response_sensitivity|coupled_restart|multiswap)' "$GATE"; then
  echo 'FVQ96_ARCHITECTURE_FAIL gateway imports later owner layer' >&2
  exit 1
fi
if grep -Eiq '(area[_ ]?weight|tile[_ ]?fraction|normaliz(e|ed|ation)|temporal[_ ]?accuracy|interface[_ ]?tolerance|response[_ ]?tangent)' "$GATE"; then
  echo 'FVQ96_ARCHITECTURE_FAIL gateway recreates later aggregation/accuracy/tangent semantics' >&2
  exit 1
fi
if grep -Eiq '(modflow|mf6|flopy|xmiwrapper)' "$GATE"; then
  echo 'FVQ96_ARCHITECTURE_FAIL backend-specific type/name leaked into generic gateway' >&2
  exit 1
fi
if grep -Eiq '^[[:space:]]*(open|read|write|inquire|rewind|backspace|endfile)[[:space:]]*\(' "$GATE"; then
  echo 'FVQ96_ARCHITECTURE_FAIL gateway file IO detected' >&2
  exit 1
fi
printf '%s\n' 'FVQ96_OWNER_BOUNDARY_GUARDS=PASS'
printf '%s\n' 'FVQ96_NO_BACKEND_TYPE_LEAK=PASS'
printf '%s\n' 'FVQ96_NO_GATEWAY_FILE_IO=PASS'

FC="${FC:-gfortran}"
command -v "$FC" >/dev/null
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

compile_and_run() {
  local opt="$1"
  local tag="$2"
  local exe="$BUILD/fvq96_${tag}"
  local moddir="$BUILD/mod_${tag}"
  mkdir -p "$moddir"
  "$FC" -std=f2008 -ffree-line-length-none -Wall -Wextra -pedantic "$opt" \
    -J"$moddir" -I"$moddir" \
    src/runtime/mod_groundwater_coupling_contract.f90 \
    src/runtime/mod_groundwater_exchange_service_contract.f90 \
    src/adapter/mod_groundwater_external_gateway.f90 \
    tests/fvq/test_fvq96_fgc26_external_gateway_independent.f90 \
    -o "$exe"
  "$exe" > "$BUILD/out_${tag}.txt"
}

compile_and_run -O0 O0
compile_and_run -O2 O2

diff -u "$BUILD/out_O0.txt" "$BUILD/out_O2.txt"
cat "$BUILD/out_O0.txt"
printf '%s\n' 'FVQ96_O0_O2_OUTPUT_IDENTITY=PASS'
printf '%s\n' 'F-VQ96 F-GC26 INDEPENDENT QUALIFICATION GATE PASS'
