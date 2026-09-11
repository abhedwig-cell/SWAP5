#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fgc07-$$"
ART="$ROOT/.fgc07-artifacts"
rm -rf "$BUILD" "$ART"
mkdir -p "$BUILD" "$ART"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

CANONICAL_SOURCE_HEAD=0aeb0a2ed4096e1f9493d3dabc70962ea5270182
fail(){ echo "FGC07_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$CANONICAL_SOURCE_HEAD" HEAD || fail 'branch is not descended from frozen current-canonical source head'
if ! git diff --quiet "$CANONICAL_SOURCE_HEAD" HEAD -- src; then
  fail 'F-GC07 changed production source'
fi
echo 'FGC07_PRODUCTION_SOURCE_UNCHANGED=PASS'

# Lock the current physical/temporal seams used by the measurement harness.
[[ "$(git rev-parse HEAD:src/solver/mod_soil_water_solver_contract.f90)" == dc7b14a06f64c8ab0af9747f707b3394a5f5cbe0 ]] || fail 'soil-water contract drift'
[[ "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" == 6eda1fec1bd03c03a1c0a8f2df29a273f70d962f ]] || fail 'reference Richards adapter drift'
[[ "$(git rev-parse HEAD:src/solver/mod_reference_richards_temporal_indicator.f90)" == fe8f87d11257d4c6bc019f1d628ac41ba3106d4e ]] || fail 'temporal indicator drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_checkpoint_orchestrator.f90)" == 232875e7192f995930c102609cee08dc8938c86a ]] || fail 'checkpoint orchestrator drift'
echo 'FGC07_SOURCE_SEAMS_LOCKED=PASS'

# The current contract has a first-class sensitivity carrier, but the current
# reference Richards binding must not be claimed to provide a tangent unless it
# actually populates that carrier.
grep -Fq 'type, public :: soil_water_interface_sensitivity_t' src/solver/mod_soil_water_solver_contract.f90 || fail 'interface sensitivity carrier missing'
grep -Fq 'real(real64) :: dh_bottom_dq_bottom' src/solver/mod_soil_water_solver_contract.f90 || fail 'dh/dq field missing'
if grep -Eq 'interface_sensitivity[[:space:]]*%' src/adapter/mod_reference_richards_legacy_binding.f90; then
  fail 'reference solver now appears to populate interface sensitivity; reclassify F-GC07 tangent scope before testing'
fi
echo 'FGC07_TANGENT_API_PRESENT_REFERENCE_EMISSION_ABSENT=PASS'

python3 tests/fsi/fsi18_make_reference_tridag_stubs.py tests/fsi/fsi04_real_headcalc_stubs.f90 "$BUILD/reference_tridag_stubs.f90"
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  "$BUILD/reference_tridag_stubs.f90"
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
)
DRIVER=tests/fgc/test_fgc07_temporal_coupling.f90

build(){
  local opt="$1" tag="$2" out="$BUILD/$2"
  mkdir -p "$out"
  local objects=()
  for src in "${MODULE_SRC[@]}"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -Werror "$opt" -J "$out" -I "$out" -c "$DRIVER" -o "$out/fgc07.o"
  gfortran "$opt" "${objects[@]}" "$out/fgc07.o" -o "$out/fgc07"
}

build -O0 o0
build -O2 o2

timeout 180s "$BUILD/o0/fgc07" 0.2 0.25 2 PC1 > "$BUILD/smoke_o0.txt" 2>&1 || { cat "$BUILD/smoke_o0.txt" >&2; fail 'O0 smoke'; }
timeout 180s "$BUILD/o2/fgc07" 0.2 0.25 2 PC1 > "$BUILD/smoke_o2.txt" 2>&1 || { cat "$BUILD/smoke_o2.txt" >&2; fail 'O2 smoke'; }
cmp "$BUILD/smoke_o0.txt" "$BUILD/smoke_o2.txt" || { diff -u "$BUILD/smoke_o0.txt" "$BUILD/smoke_o2.txt" >&2 || true; fail 'O0/O2 smoke drift'; }
echo 'FGC07_O0_O2_SMOKE_IDENTITY=PASS'

python3 tools/fgc/fgc07_analyze.py "$BUILD/o2/fgc07" "$ART"
cp "$BUILD/smoke_o2.txt" "$ART/fgc07_smoke.txt"
sha256sum "$ART"/* > "$ART/SHA256SUMS.txt"
echo "FGC07_RESULTS_SHA256=$(sha256sum "$ART/fgc07_results.json" | cut -d' ' -f1)"
echo 'FGC07_TEMPORAL_COUPLING_GATE PASS'
