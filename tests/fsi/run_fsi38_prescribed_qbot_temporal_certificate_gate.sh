#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fsi38-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FSI38_GATE_FAIL $*" >&2; exit 138; }

INDICATOR=src/solver/mod_reference_richards_temporal_indicator.f90

grep -Fq '(request%boundary%bottom_mode /= 5 .and. request%boundary%bottom_mode /= 2)' "$INDICATOR" || \
  fail 'mode2 boundary envelope admission missing'
grep -Fq 'if (request%boundary%bottom_mode == 5) then' "$INDICATOR" || \
  fail 'mode5-only Dirichlet bottom stiffness guard missing'
grep -Fq 'diagonal(n) = diagonal(n)+face_conductance' "$INDICATOR" || \
  fail 'mode5 Dirichlet bottom stiffness term missing'
grep -Fq "indicator_result%route = 'boundary-envelope-deferred'" "$INDICATOR" || \
  fail 'unsupported boundary fail-closed route missing'
echo 'FSI38_STATIC_OPERATOR_CONTRACT=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/fsi/test_fsi38_prescribed_qbot_temporal_certificate.f90 -o "$OUT/fsi38.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/fsi38.o" -o "$OUT/fsi38"
  "$OUT/fsi38" > "$OUT/fsi38.txt" 2>&1 || { cat "$OUT/fsi38.txt" >&2; fail "F-SI38 executable O$opt"; }
  grep -Fq 'FSI38_MODE2_CASES=10' "$OUT/fsi38.txt" || { cat "$OUT/fsi38.txt" >&2; fail "mode2 matrix count O$opt"; }
  grep -Eq 'FSI38_WRONG_DIRICHLET_SEPARATIONS=[1-9][0-9]*' "$OUT/fsi38.txt" || {
    cat "$OUT/fsi38.txt" >&2
    fail "Neumann/Dirichlet distinction O$opt"
  }
  grep -Fq 'FSI38_PRESCRIBED_QBOT_TEMPORAL_CERTIFICATE=PASS' "$OUT/fsi38.txt" || {
    cat "$OUT/fsi38.txt" >&2
    fail "F-SI38 PASS marker O$opt"
  }
  cat "$OUT/fsi38.txt"
  echo "FSI38_MODE2_ORACLE_O${opt}=PASS"

  # Preservation: execute the previously qualified production mode-5 seam
  # unchanged. F-SI38 may extend the boundary envelope but must not alter the
  # prescribed-head certificate semantics or its cost/noninterference contract.
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/fsi/test_fsi25_reference_indicator_production_seam.f90 -o "$OUT/fsi25.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/fsi25.o" -o "$OUT/fsi25"
  "$OUT/fsi25" -75.0 0.01 > "$OUT/fsi25.txt" 2>&1 || { cat "$OUT/fsi25.txt" >&2; fail "F-SI25 preservation O$opt"; }
  grep -Fq 'FSI25_REFERENCE_INDICATOR_CASE PASS' "$OUT/fsi25.txt" || {
    cat "$OUT/fsi25.txt" >&2
    fail "F-SI25 preservation marker O$opt"
  }
  grep -Fq ':EXTRA_NONLINEAR=0:EXTRA_TRIDAG=1:' "$OUT/fsi25.txt" || {
    cat "$OUT/fsi25.txt" >&2
    fail "F-SI25 cost preservation O$opt"
  }
  cat "$OUT/fsi25.txt"
  echo "FSI38_MODE5_PRESERVATION_O${opt}=PASS"
done

cmp -s "$BUILD/o0/fsi38.txt" "$BUILD/o2/fsi38.txt" || {
  diff -u "$BUILD/o0/fsi38.txt" "$BUILD/o2/fsi38.txt" >&2 || true
  fail 'F-SI38 O0/O2 semantic drift'
}
echo 'FSI38_MODE2_O0_O2_SEMANTIC_IDENTITY=PASS'

cmp -s "$BUILD/o0/fsi25.txt" "$BUILD/o2/fsi25.txt" || {
  diff -u "$BUILD/o0/fsi25.txt" "$BUILD/o2/fsi25.txt" >&2 || true
  fail 'F-SI25 preservation O0/O2 semantic drift'
}
echo 'FSI38_MODE5_O0_O2_SEMANTIC_IDENTITY=PASS'

git diff --check -- "$INDICATOR" tests/fsi/test_fsi38_prescribed_qbot_temporal_certificate.f90 \
  tests/fsi/run_fsi38_prescribed_qbot_temporal_certificate_gate.sh

echo 'FSI38_QUALIFICATION_GATE=PASS'