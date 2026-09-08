#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq22-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

CANDIDATE=591363019aa4b2324bec55354b45093b3b189819
CANDIDATE_TREE=dd07ad0d16783e43b951b218904e7e2d1f409af4
[[ "$(git rev-parse "$CANDIDATE^{tree}")" == "$CANDIDATE_TREE" ]]
git diff --quiet "$CANDIDATE" -- src

echo 'FVQ22_CANDIDATE_PRODUCTION_IMMUTABILITY=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FVQ22_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/process/mod_root_water_uptake_process.f90 e6134587cf3c0164bbe09f2f4c87aef6886aaeb3
check_blob src/solver/mod_soil_water_solver_contract.f90 0a57b07712f93538cbfaf9130838682307cede09
check_blob src/solver/mod_process_hydraulic_view.f90 d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
check_blob src/solver/mod_b110_root_sink_provider.f90 ef2d2fd883d116c314b98e8f0f14330150b4778a
check_blob src/solver/mod_b110_source_sink_provider.f90 d6c57add72387e5c0022a44319fff08046194aac
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 fe1c1cf19d3702114cf7598e227d56f7dbc1e267
check_blob src/runtime/mod_fmr_process_hydraulic_view_binding.f90 37f5968ffe00b1ff56f824f77ab94d3825171acf
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 1bb0c6d4683db2729d48de31babcea72bc1a6caf
check_blob src/kernel/mod_kernel_transactions.f90 9f7c16e71cfb93b57f796ba759bae73824318a2f
check_blob src/process/mod_irrigation_process.f90 c0755c1e0d0b7ca1a35e73cf26158c29e9940aec
check_blob src/process/mod_snow_process.f90 54702d71b4c84dce2842813549bd14c57301a383
check_blob src/legacy/b1_10_port/headcalc.f90 420fe2996199e6d3f162b7669957e1a95919f353
check_blob src/adapter/mod_b110_serialized_context_binding.f90 1818338d088ee61a3a1dd5220542e6650ba673ac

echo 'FVQ22_SOURCE_LOCKS=PASS'

python3 - <<'PY'
from pathlib import Path
p=Path('integration/f-vq/F-VQ22_QUALIFICATION_PLAN.json').read_text()
assert '8b7b2846618a8f82f3ed676c2c489d2d34be8c44b0a0d952f7f22ff09af78cd5' in p
assert 'c2df137291357553541d4d7026b8859242c32565affe173c66a685d565190ccf' in p
assert 'owner_test_expected_literals_may_serve_as_scientific_oracle' in p
assert 'false' in p
print('FVQ22_CANONICAL_SOURCE_PROVENANCE_LOCK=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
DIRECT_SRC=(
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_root_water_uptake_process.f90
)
RUNTIME_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
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
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_process_hydraulic_view_binding.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT/direct" "$OUT/runtime"

  direct_objects=()
  for src in "${DIRECT_SRC[@]}"; do
    obj="$OUT/direct/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT/direct" -I "$OUT/direct" -c "$src" -o "$obj"
    direct_objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT/direct" -I "$OUT/direct" \
    -c tests/fvq/test_fvq22_root_uptake_scientific_oracle.f90 -o "$OUT/direct/fvq22_direct.o"
  gfortran -O"$opt" "${direct_objects[@]}" "$OUT/direct/fvq22_direct.o" -o "$OUT/direct/fvq22_direct"
  "$OUT/direct/fvq22_direct" > "$OUT/direct_output.txt" 2>&1 || { cat "$OUT/direct_output.txt" >&2; exit 1; }

  runtime_objects=()
  for src in "${RUNTIME_SRC[@]}"; do
    obj="$OUT/runtime/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT/runtime" -I "$OUT/runtime" -c "$src" -o "$obj"
    runtime_objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT/runtime" -I "$OUT/runtime" \
    -c tests/fvq/test_fvq22_root_uptake_runtime_oracle.f90 -o "$OUT/runtime/fvq22_runtime.o"
  gfortran -O"$opt" "${runtime_objects[@]}" "$OUT/runtime/fvq22_runtime.o" -o "$OUT/runtime/fvq22_runtime"
  "$OUT/runtime/fvq22_runtime" > "$OUT/runtime_output.txt" 2>&1 || { cat "$OUT/runtime_output.txt" >&2; exit 1; }

  for marker in \
    'FVQ22_PTRA_AND_HLIM3_BOUNDARY_ORACLE=PASS' \
    'FVQ22_FEDDES_PRESSURE_BOUNDARY_ORACLE=PASS' \
    'FVQ22_DYNAMIC_ROOT_DISTRIBUTION_ORACLE=PASS' \
    'FVQ22_NO_ROOT_DEPENDENCY_FREE_ORACLE=PASS' \
    'FVQ22_BELOW_NIHIL_DEPENDENCY_FREE_ORACLE=PASS' \
    'FVQ22_EXACT_NIHIL_ACTIVE_EVALUATION=PASS' \
    'FVQ22_ACTIVE_INVALID_DOMAIN_FAIL_CLOSED=PASS' \
    'FVQ22_DIRECT_PROCESS_A_B_A_IDENTITY=PASS' \
    'FVQ22_ROOT_UPTAKE_SCIENTIFIC_ORACLE PASS'; do
      grep -Fq "$marker" "$OUT/direct_output.txt"
  done

  for marker in \
    'FVQ22_CANDIDATE_NODEWISE_QROT_EQUALS_INDEPENDENT_ORACLE=PASS' \
    'FVQ22_RUNTIME_NODE_ORDER_AND_SIGN_PRESERVED=PASS' \
    'FVQ22_RUNTIME_AUTHORITATIVE_ROOT_OUT_EXACTLY_ONCE=PASS' \
    'FVQ22_RUNTIME_AUTHORITATIVE_QSSDI_IN_EXACTLY_ONCE=PASS' \
    'FVQ22_RUNTIME_HYDRAULIC_CANCELLATION=PASS' \
    'FVQ22_RUNTIME_HARD_MASS_CONSERVATION=PASS' \
    'FVQ22_ROOT_UPTAKE_RUNTIME_ORACLE PASS'; do
      grep -Fq "$marker" "$OUT/runtime_output.txt"
  done

  cat "$OUT/direct_output.txt" "$OUT/runtime_output.txt" > "$OUT/output.txt"
  echo "FVQ22_ROOT_UPTAKE_ORACLE_O${opt}=PASS"
done

cmp "$BUILD/o0/direct_output.txt" "$BUILD/o2/direct_output.txt"
cmp "$BUILD/o0/runtime_output.txt" "$BUILD/o2/runtime_output.txt"
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FVQ22_ROOT_UPTAKE_ORACLE_O0_O2_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FVQ22_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FVQ22_ROOT_UPTAKE_SCIENTIFIC_GATE PASS'
