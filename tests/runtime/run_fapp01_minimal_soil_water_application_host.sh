#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${ROOT}/tests/runtime/.fapp01-build"
rm -rf "${BUILD}"
mkdir -p "${BUILD}/o0" "${BUILD}/o2"
trap 'rm -rf "${BUILD}"' EXIT

compile_and_run() {
  local opt="$1"
  local outdir="$2"
  gfortran "-${opt}" -std=f2008 -Wall -Wextra -pedantic \
    -J "${outdir}" -I "${outdir}" \
    "${ROOT}/src/runtime/mod_fmr_soil_water_application_host.f90" \
    "${ROOT}/tests/runtime/test_fapp01_minimal_soil_water_application_host.f90" \
    -o "${outdir}/fapp01.exe"
  "${outdir}/fapp01.exe" > "${outdir}/output.txt"
}

compile_and_run O0 "${BUILD}/o0"
compile_and_run O2 "${BUILD}/o2"

cmp "${BUILD}/o0/output.txt" "${BUILD}/o2/output.txt"
sha256sum "${BUILD}/o0/output.txt" | awk '{print "FAPP01_O0_O2_SHA256=" $1}'
cat "${BUILD}/o0/output.txt"
echo "FAPP01_O0_O2_IDENTITY=PASS"
echo "FAPP01_MINIMAL_APPLICATION_HOST_CONTRACT=PASS"
