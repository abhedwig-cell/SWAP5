#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fgc31-preservation-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
fail(){ echo "FGC31_PRESERVATION_FAIL $*" >&2; exit 31; }

python3 tests/qualification/fvq89/fvq89_make_reference_stubs.py   tests/fsi/fsi04_real_headcalc_stubs.f90 "$BUILD/reference_stubs.f90" >/dev/null

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
REFERENCE_SRC=(
  "$BUILD/reference_stubs.f90"
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
)

run_reference_preservation(){
  local opt="$1" tag="$2" out="$BUILD/reference-$2"
  mkdir -p "$out"
  local objects=()
  for src in "${REFERENCE_SRC[@]}"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out"     -c tests/qualification/fvq89/test_fvq89_fsi37_independent.f90 -o "$out/test.o"
  gfortran "$opt" "${objects[@]}" "$out/test.o" -o "$out/test"
  timeout 180s "$out/test" > "$out/output.txt" 2>&1 || { cat "$out/output.txt" >&2; fail "FVQ89 replay $tag"; }
  for marker in     'FVQ89_FD_CASES=5'     'FVQ89_ACCEPTED_ENDPOINT_REFERENCE=PASS'     'FVQ89_ZERO_SINGLE_MIXED_DIRECTIONS=PASS'     'FVQ89_NO_COMMITTED_STATE_MUTATION=PASS'     'FVQ89_RETRY_NO_DERIVATIVE_LEAK=PASS'     'FVQ89_FAIL_CLOSED=PASS'     'FVQ89_FSI37_INDEPENDENT PASS'; do
    grep -Fxq "$marker" "$out/output.txt" || { cat "$out/output.txt" >&2; fail "FVQ89 marker $tag $marker"; }
  done
  grep '^FVQ89_SIGNATURE ' "$out/output.txt" > "$out/signatures.txt"
}
run_reference_preservation -O0 o0
run_reference_preservation -O2 o2
cmp "$BUILD/reference-o0/signatures.txt" "$BUILD/reference-o2/signatures.txt" || fail 'FVQ89 O0/O2 signature drift'
echo 'FGC31_FSI37_BEHAVIORAL_REPLAY=PASS'
echo 'FGC31_FSI37_O0_O2_SIGNATURE_IDENTITY=PASS'

run_fkt_core(){
  local opt="$1" tag="$2" out="$BUILD/fkt-$2"
  mkdir -p "$out"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c     src/solver/mod_soil_water_accepted_step_direction_contract.f90 -o "$out/contract.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c     src/transaction/mod_accepted_trajectory_directional_sensitivity.f90 -o "$out/trajectory.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c     src/transaction/mod_accepted_trajectory_directional_publication.f90 -o "$out/publication.o"

  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c     tests/fkt/test_fkt21_accepted_trajectory_direction.f90 -o "$out/test.o"
  gfortran "$opt" "$out/contract.o" "$out/trajectory.o" "$out/test.o" -o "$out/test"
  "$out/test" > "$out/output.txt"
  grep -Fxq 'FKT21_ACCEPTED_TRAJECTORY_DIRECTION PASS' "$out/output.txt" || fail "FKT21 core $tag"
  grep -Fxq 'FKT21_WHOLE_TRAJECTORY_CENTERED_FD=PASS' "$out/output.txt" || fail "FKT21 FD $tag"
  grep -Fxq 'FKT21_REJECT_RETRY=PASS' "$out/output.txt" || fail "FKT21 retry $tag"
  grep -Fxq 'FKT21_BOUNDED_COST=PASS' "$out/output.txt" || fail "FKT21 cost $tag"

  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c     tests/fkt/test_fkt21_provenance.f90 -o "$out/provenance.o"
  gfortran "$opt" "$out/contract.o" "$out/trajectory.o" "$out/provenance.o" -o "$out/provenance"
  "$out/provenance" > "$out/provenance.txt"
  grep -Fxq 'FKT21_PROVENANCE_HARDENING PASS' "$out/provenance.txt" || fail "FKT21 provenance $tag"

  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c     tests/fkt/test_fkt21_publication_identity.f90 -o "$out/publication_test.o"
  gfortran "$opt" "$out/contract.o" "$out/trajectory.o" "$out/publication.o" "$out/publication_test.o" -o "$out/publication"
  "$out/publication" > "$out/publication.txt"
  grep -Fxq 'FKT21_PUBLICATION_IDENTITY PASS' "$out/publication.txt" || fail "FKT21 publication $tag"

  { grep '^FKT21_' "$out/output.txt"; grep '^FKT21_' "$out/provenance.txt"; grep '^FKT21_' "$out/publication.txt"; } > "$out/stable.txt"
}
run_fkt_core -O0 o0
run_fkt_core -O2 o2
cmp "$BUILD/fkt-o0/stable.txt" "$BUILD/fkt-o2/stable.txt" || fail 'FKT21 O0/O2 marker drift'
echo 'FGC31_FKT21_CORE_REPLAY=PASS'
echo 'FGC31_FKT21_O0_O2_MARKER_IDENTITY=PASS'

echo 'F-GC31 DIRECTIONAL PRESERVATION GATE PASS'
