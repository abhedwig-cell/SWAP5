#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${ROOT}/tests/fvq/.fvq101-build"
HOST="${ROOT}/src/runtime/mod_fmr_soil_water_application_host.f90"
EXPECTED_HOST_BLOB="daca18b77673608436425e81ecd397ef3e35e4b2"

rm -rf "${BUILD}"
mkdir -p "${BUILD}/o0" "${BUILD}/o2"
trap 'rm -rf "${BUILD}"' EXIT

actual_blob="$(git -C "${ROOT}" rev-parse HEAD:src/runtime/mod_fmr_soil_water_application_host.f90)"
test "${actual_blob}" = "${EXPECTED_HOST_BLOB}"
echo "FVQ101_OWNER_HOST_BLOB_LOCK=PASS"

if grep -E '^[[:space:]]*use[[:space:]]' "${HOST}" >/dev/null; then
  echo 'FVQ101_FAIL=generic host imports another production module'
  exit 1
fi
echo "FVQ101_GENERIC_HOST_NO_PRODUCTION_MODULE_DEPENDENCY=PASS"

compile_and_run() {
  local opt="$1"
  local outdir="$2"
  gfortran "-${opt}" -std=f2008 -Wall -Wextra -pedantic \
    -J "${outdir}" -I "${outdir}" \
    "${HOST}" \
    "${ROOT}/tests/fvq/test_fvq101_fapp01_independent.f90" \
    -o "${outdir}/fvq101.exe"
  "${outdir}/fvq101.exe" > "${outdir}/output.txt"
}

compile_and_run O0 "${BUILD}/o0"
compile_and_run O2 "${BUILD}/o2"

cmp "${BUILD}/o0/output.txt" "${BUILD}/o2/output.txt"
sha256sum "${BUILD}/o0/output.txt" | awk '{print "FVQ101_O0_O2_SHA256=" $1}'
cat "${BUILD}/o0/output.txt"
echo "FVQ101_O0_O2_IDENTITY=PASS"
echo "FVQ101_INDEPENDENT_QUALIFICATION=PASS"
