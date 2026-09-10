#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq46-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

OWNER=840a43ab51b6c5eb903c43efc33b6d735b0a1872
CANDIDATE=7cd18f03293ebd94fce4bb4430bc78ba13e7e237
CANDIDATE_SOURCE=src/runtime/mod_fmr_reference_et_root_uptake_composition.f90
CANDIDATE_BLOB=8ed7610144700f58d0b89482925471fcb2ff7d69

git merge-base --is-ancestor "$CANDIDATE" "$OWNER"
git merge-base --is-ancestor "$OWNER" HEAD
git diff --quiet "$OWNER"..HEAD -- src || {
  echo 'FVQ46_QUALIFICATION_MUTATED_PRODUCTION_SOURCE' >&2
  git diff --name-only "$OWNER"..HEAD -- src >&2
  exit 1
}
test "$(git rev-parse HEAD:$CANDIDATE_SOURCE)" = "$CANDIDATE_BLOB"
echo 'FVQ46_FMR28_PRODUCTION_SOURCE_IMMUTABLE=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git rev-parse "HEAD:$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FVQ46_PROTECTED_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}
check_blob src/runtime/mod_fmr_reference_et_ptra_root_input_binding.f90 11ef6182414af4fbe67eebec3d6f14742df04aca
check_blob src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90 9105126c219cbd06fadfa7757ba95d7b7bd0499b
check_blob src/runtime/mod_fmr_root_uptake_process_binding.f90 2fc348f18e8561096fa34dd3c11c64b359583f11
check_blob src/process/mod_root_water_uptake_process.f90 e6134587cf3c0164bbe09f2f4c87aef6886aaeb3
check_blob src/crop/mod_crop_root_uptake_input_contract.f90 cc5594f6c7a91ac2ff37af611d40c740b7f25521
check_blob src/process/mod_reference_et_demand_process.f90 f5e88ec5089fd3b57ac111065fab2aa32dde0fae
check_blob src/runtime/mod_fmr_reference_et_demand_binding.f90 8c679f911c9a82c498258224d83f5fce3cb09163
echo 'FVQ46_FROZEN_OWNER_AUTHORITIES=PASS'

python3 - <<'PY'
from pathlib import Path
p=Path('src/runtime/mod_fmr_reference_et_root_uptake_composition.f90').read_text().lower()
for required in ('fmr_bind_reference_et_ptra_to_root_input','fmr_evaluate_shared_crop_root_uptake'):
    assert required in p, required
for forbidden in ('evaluate_macro_feddes_drought_uptake','reference_et_mm_per_day','vegetation_cover_fraction',
                  'crop_factor','co2_transpiration_factor','pressure_head','headcalc','newton','jacobian',
                  'mass_accounting','total_in','total_out','open(','read(','write(','save'):
    assert forbidden not in p, forbidden
print('FVQ46_COMPOSITION_BOUNDARY_STATIC=PASS')
print('FVQ46_NO_PHYSICS_REIMPLEMENTATION_OR_MASS_BOOKING=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
DEPENDENCY_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_root_water_uptake_process.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_process_hydraulic_view_binding.f90
  src/runtime/mod_fmr_root_uptake_process_binding.f90
  src/crop/mod_crop_root_uptake_input_contract.f90
  src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90
  src/process/mod_reference_et_demand_process.f90
  src/runtime/mod_fmr_reference_et_demand_binding.f90
  src/runtime/mod_fmr_reference_et_ptra_root_input_binding.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${DEPENDENCY_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  src="$CANDIDATE_SOURCE"
  obj="$OUT/mod_fmr_reference_et_root_uptake_composition.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
  objects+=("$obj")
  echo "FVQ46_FROZEN_CANDIDATE_STRICT_COMPILE_O${opt}=PASS"

  test=tests/fvq/test_fvq46_fmr28_reference_et_root_uptake_execution.f90
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$test" -o "$OUT/test_fvq46.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_fvq46.o" -o "$OUT/test_fvq46"
  "$OUT/test_fvq46" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }

  for marker in \
    'FVQ46_HELD_OUT_ACTIVE_CASES=192' \
    'FVQ46_EXPLICIT_CHAIN_ORACLE=PASS' \
    'FVQ46_STALE_PTRA_INDEPENDENCE=PASS' \
    'FVQ46_UPSTREAM_ET_REJECTION_CONTAINED=PASS' \
    'FVQ46_INVALID_ROOT_GEOMETRY_CONTAINED=PASS' \
    'FVQ46_ACTIVE_UNAVAILABLE_COMMITTED_FAIL_CLOSED=PASS' \
    'FVQ46_INACTIVE_DEPENDENCY_FREE_ZERO_ROUTE=PASS' \
    'FVQ46_STATELESS_A_B_A_IDENTITY=PASS' \
    'FVQ46_FMR28_REFERENCE_ET_ROOT_UPTAKE_EXECUTION_ORACLE PASS'; do
      grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FVQ46_INDEPENDENT_ORACLE_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FVQ46_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FVQ46_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FVQ46_FMR28_REFERENCE_ET_ROOT_UPTAKE_EXECUTION_GATE PASS'
