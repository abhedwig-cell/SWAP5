#!/usr/bin/env bash
set -euo pipefail

fail() { echo "F-MR11_PRE_ADMISSION_FAIL $*" >&2; exit 1; }

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git rev-parse "HEAD:${path}")"
  [[ "$actual" == "$expected" ]] || fail "blob mismatch ${path}: ${actual} != ${expected}"
  echo "F-MR11_SOURCE_LOCK PASS ${path} ${actual}"
}

check_blob src/adapter/mod_reference_richards_legacy_binding.f90 db432cac3f1156a179c636435a25f52cdececffc
check_blob src/legacy/b1_10_port/headcalc.f90 d92f77963329d61ab3feb988f912252c0161436c
check_blob src/solver/mod_reference_richards_workspace.f90 a09ba3457a8ce3685df446bfacbf5220cd401507
check_blob src/solver/mod_soil_water_solver_contract.f90 4271372085d800fd5da969a2ed073b00422d79c6

echo "F-MR11_FSI12_FSI16_SOLVER_POSTIMAGE_LOCK PASS"

bash tests/fmr/run_fmr10_root_uptake_binding_gate.sh
bash tests/fmr/run_fmr09_root_sink_runtime_gate.sh

echo "F-MR11_PRE_ADMISSION_GATE PASS"
