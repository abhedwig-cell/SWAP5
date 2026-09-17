#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fgc30-tangent-adapter-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "FGC30_TANGENT_ADAPTER_FAIL $*" >&2; exit 1; }
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  sources=(
    src/runtime/mod_groundwater_coupling_contract.f90
    src/solver/mod_soil_water_solver_contract.f90
    src/solver/mod_soil_water_accepted_step_direction_contract.f90
    src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
    src/transaction/mod_accepted_trajectory_directional_publication.f90
    src/solver/mod_b110_default_mvg_provider.f90
    src/solver/mod_b110_default_mvg_directional_provider.f90
    src/runtime/mod_modflow6_swap_predictor_response.f90
    src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90
    src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90
  )
  objects=()
  for source in "${sources[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "compile O$opt $source"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/fgc/test_fgc30_predictor_tangent_adapter.f90 -o "$OUT/test.o" || fail "compile adapter oracle O$opt"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test" || fail "link O$opt"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt"; }
  for marker in \
    'FGC30_ACCEPTED_QBOT_TRAJECTORY_ENDPOINT=PASS' \
    'FGC30_ENDPOINT_CONSTITUTIVE_DIRECTION=PASS' \
    'FGC30_ENDPOINT_CENTERED_FD_ORACLE=PASS' \
    'FGC30_ENDPOINT_PROVENANCE=PASS' \
    'FGC30_ENDPOINT_DRAINAGE_FAIL_CLOSED=PASS' \
    'FGC30_ENDPOINT_CONTROL_FAIL_CLOSED=PASS' \
    'FGC30_PREDICTOR_TANGENT_ADAPTER_GATE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing O$opt marker $marker"; }
  done
  cat "$OUT/output.txt"
  echo "FGC30_TANGENT_ADAPTER_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 semantic drift'
}

git diff --check -- src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90 \
  tests/fgc/test_fgc30_predictor_tangent_adapter.f90 \
  tests/fgc/run_fgc30_predictor_tangent_adapter.sh

echo 'FGC30_TANGENT_ADAPTER_O0_O2_IDENTITY=PASS'
echo 'FGC30_TANGENT_ADAPTER_QUALIFICATION=PASS'
