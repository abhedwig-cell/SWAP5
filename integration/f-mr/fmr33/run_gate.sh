#!/usr/bin/env bash
set -euo pipefail

BASE="49863406a6112baa9956f9396b34e7188934e0d4"
PROCESS="src/process/mod_drainage_spatial_distribution.f90"
VIEW="src/solver/mod_process_hydraulic_view.f90"
BACKEND="src/runtime/mod_fmr_serialized_reference_backend.f90"
SOURCESINK="src/solver/mod_b110_source_sink_provider.f90"
BINDING="src/runtime/mod_fmr_divdra_runtime_binding.f90"
TEST="integration/f-mr/fmr33/test_fmr33_divdra_runtime_binding.f90"

expect_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  if [[ "$actual" != "$expected" ]]; then
    echo "BLOB_LOCK_FAIL $path expected=$expected actual=$actual" >&2
    exit 1
  fi
  echo "BLOB_LOCK_OK $path $actual"
}

expect_blob "$PROCESS" "1f538174b7451aaa7a3c50d6078b7c1fc3ad8f5a"
expect_blob "$VIEW" "d7d85fe71ced0d94b29c8d9395859ae1834f7dd6"
expect_blob "$BACKEND" "9af5a494526810324dc00706b444e448e770cba9"
expect_blob "$SOURCESINK" "d6c57add72387e5c0022a44319fff08046194aac"

if grep -Eq 'kernel_committed|committed_state|%snapshot|mod_fmr_process_hydraulic_view_binding' "$BINDING"; then
  echo "HIDDEN_COMMITTED_STATE_CAPTURE_FAIL" >&2
  exit 1
fi
if grep -q 'mod_fmr_serialized_reference_backend' "$BINDING"; then
  echo "BACKEND_COUPLING_FAIL" >&2
  exit 1
fi
if grep -Eq 'jacobian|HeadCalc|headcalc|\.dra|MODFLOW|modflow' "$BINDING"; then
  echo "FORBIDDEN_BINDING_DEPENDENCY_FAIL" >&2
  exit 1
fi

test -z "$(git diff --name-only "$BASE" HEAD -- reference)" || {
  echo "REFERENCE_DELTA_FAIL" >&2
  git diff --name-only "$BASE" HEAD -- reference >&2
  exit 1
}

src_delta="$(git diff --name-only "$BASE" HEAD -- src)"
if [[ "$src_delta" != "$BINDING" ]]; then
  echo "PRODUCTION_DELTA_FAIL" >&2
  printf '%s\n' "$src_delta" >&2
  exit 1
fi

echo "PRODUCTION_DELTA_OK $BINDING"
echo "REFERENCE_DELTA_OK"

compile_and_run() {
  local opt="$1" tag="$2" outdir="build/fmr33_${tag}"
  rm -rf "$outdir"
  mkdir -p "$outdir/mod"
  gfortran "$opt" -std=f2008 -Wall -Wextra -pedantic \
    -J "$outdir/mod" -I "$outdir/mod" \
    src/solver/mod_soil_water_solver_contract.f90 \
    src/solver/mod_process_hydraulic_view.f90 \
    src/process/mod_drainage_spatial_distribution.f90 \
    src/runtime/mod_fmr_divdra_runtime_binding.f90 \
    src/solver/mod_b110_source_sink_provider.f90 \
    "$TEST" \
    -o "$outdir/test_fmr33"
  "$outdir/test_fmr33" > "$outdir/output.txt"
}

compile_and_run -O0 O0
compile_and_run -O2 O2
cmp build/fmr33_O0/output.txt build/fmr33_O2/output.txt
cp build/fmr33_O0/output.txt F-MR33_O0.txt
cp build/fmr33_O2/output.txt F-MR33_O2.txt
sha256sum F-MR33_O0.txt F-MR33_O2.txt

echo "F-MR33_GATE_PASS"
