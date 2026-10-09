#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
# Additional scientific owner-successor evidence for changed F-KT and B110.
# DO NOT replace or relax frozen F-CI/B19 exact source postimage checks.
git diff --quiet HEAD -- src/kernel/mod_kernel_transactions.f90 src/runtime/mod_fmr_serialized_reference_backend.f90 ||
 { echo 'UNCOMMITTED_SHARED_OWNER_SOURCE' >&2; exit 1; }
bash tests/fmig431/run_crop_fkt_parameter_identity.sh
bash tests/fmig431/run_crop_certified_sowing_source.sh
bash tests/fmig431/run_crop_certified_hydrothermal_forcing.sh
bash tests/fmig431/run_crop_lifecycle_fkt_compatibility.sh
MICRO02_RESULT="${TMPDIR:-/tmp}/crop-owner-micro02-$$.json" python3 tests/physics/run_ppa_micro02_de_willigen.py
MICRO03_RESULT="${TMPDIR:-/tmp}/crop-owner-micro03-$$.json" python3 tests/physics/run_ppa_micro03_runtime.py
BUILD="$(mktemp -d "${TMPDIR:-/tmp}/ppa-wu05b19-low-air-crop-owner-XXXXXX")"
trap 'rm -rf "$BUILD"' EXIT
python3 tests/frost/build_ppa_wu05b19_runtime.py --route low_air --build "$BUILD"
for opt in 0 2; do
  GFORTRAN_UNBUFFERED_ALL=y "$BUILD/o$opt/test" 1 8192 > "$BUILD/o$opt/case-1.log" 2> "$BUILD/o$opt/case-1.err"
  grep -Fq 'B19_CASE_1_RUNTIME=PASS' "$BUILD/o$opt/case-1.log"
  grep -Fq 'B19_APPLICATION=PASS' "$BUILD/o$opt/case-1.log"
  test "$(grep -c B19_FINE_COMPARISON "$BUILD/o$opt/case-1.log")" -eq 1
  echo "CROP_FKT_B110_B19_O${opt}=PASS"
done
cmp "$BUILD/o0/case-1.log" "$BUILD/o2/case-1.log"
echo 'CROP_FKT_B110_B19_CURRENT_HEAD_O0_O2=PASS'
echo 'CROP_FKT_B110_SHARED_OWNER_SCIENTIFIC_SUCCESSOR=PASS'
