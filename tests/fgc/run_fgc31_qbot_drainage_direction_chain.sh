#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fgc31-chain-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
fail(){ echo "FGC31_QBOT_DRAINAGE_CHAIN_GATE_FAIL $*" >&2; exit 31; }
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SRC=(
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/solver/mod_b110_smooth_freatic_projection.f90
  src/process/mod_drainage_process.f90
  src/process/mod_drainage_tabulated_response.f90
  src/process/mod_drainage_hooghoudt_equivalent_depth.f90
  src/process/mod_drainage_hooghoudt_ipos1_response.f90
  src/process/mod_drainage_hooghoudt_ipos23_response.f90
  src/process/mod_drainage_ernst_ipos45_preparation.f90
  src/process/mod_drainage_ernst_ipos45_response.f90
  src/process/mod_drainage_empirical_interflow_response.f90
  src/process/mod_drainage_multilevel_aggregation.f90
  src/runtime/mod_fmr_drainage_response_binding.f90
  src/runtime/mod_fmr_drainage_qbot_directional_binding.f90
)
for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for source in "${SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "compile O$opt $source"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     tests/fgc/test_fgc31_qbot_drainage_direction_chain.f90 -o "$OUT/test.o" || fail "compile test O$opt"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test" || fail "link O$opt"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "run O$opt"; }
  for marker in     'FGC31_QBOT_DGWL_CHAIN_ANALYTIC=PASS'     'FGC31_QBOT_DRAINAGE_CHAIN_CENTERED_FD=PASS'     'FGC31_QBOT_DRAINAGE_BOTTOM_LUMPING=PASS'     'FGC31_QBOT_DRAINAGE_TANGENT_FAIL_CLOSED=PASS'; do
    grep -Fxq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing O$opt marker $marker"; }
  done
  echo "FGC31_QBOT_DRAINAGE_CHAIN_O${opt}=PASS"
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 output drift'
}
echo 'FGC31_QBOT_DRAINAGE_CHAIN_O0_O2_EXACT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo 'F-GC31 QBOT DRAINAGE DIRECTION CHAIN GATE PASS'
