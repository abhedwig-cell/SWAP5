#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fci64-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "FCI64_GATE_FAIL $*" >&2; exit 264; }

CANONICAL="b162e98cc4ad6f85b741a21bd41f3db3d213559b"
OWNER="5d6cea2e6de577fb0267008b2a391770b5bd7a10"
VQ85="f0a6d6f83cda86706bec58d2d3557ade1e6b9eaa"
TYPES="src/kernel/mod_energy_conservation_types.f90"
LEDGER="src/runtime/mod_energy_conservation_ledger.f90"
OWNED="src/runtime/mod_fmr_owned_commit_receipt.f90"
RUNTIME="src/runtime/mod_fmr_serialized_multiswap_runtime.f90"
GENERIC_RECEIPT="src/runtime/mod_fmr_accepted_commit_receipt.f90"
KERNEL_TX="src/kernel/mod_kernel_transactions.f90"
TYPES_BLOB="15a6a9c5c5da6ad0d535c27772e57a23e618658d"
LEDGER_BLOB="cc166e82e51d8e0738fee51b4517626d0a2e890f"
OWNED_BLOB="2ab067d160715ff7358dd31efaa12694ef95852c"
RUNTIME_BLOB="1aa2454048d0e480becaee34f596f20f1a7bd66e"
GENERIC_RECEIPT_BLOB="6798b3296b426950bf028814585c3f5de9be950b"
MODEL_TEST_BLOB="4e901264ef06b146d2f731f52c24b4e1dce07596"
RECEIPT_TEST_BLOB="92d5a053e202f82fc468236a04d06f47ebc41b10"
PREREG="integration/f-ci/F-CI64_PRE_REGISTRATION.json"
AUDIT="integration/f-ci/F-CI64_ARCHITECTURE_AUDIT.json"
STATUS="integration/f-ci/F-CI64_STATUS.json"

git fetch -q origin integration/f-ci-canonical work/eb-i21r-runtime-bound-accepted-receipt-remediation qualification/f-vq85-eb-i21r-runtime-owned-receipt-independent-qualification
live="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$live" == "$CANONICAL" ]] || fail "live canonical drifted: $live"
[[ "$(git rev-parse origin/integration/f-ci-canonical)" == "$CANONICAL" ]] || fail 'fetched canonical mismatch'
[[ "$(git rev-parse origin/work/eb-i21r-runtime-bound-accepted-receipt-remediation)" == "$OWNER" ]] || fail 'EB-I21R authority branch drift'
[[ "$(git rev-parse origin/qualification/f-vq85-eb-i21r-runtime-owned-receipt-independent-qualification)" == "$VQ85" ]] || fail 'F-VQ85 authority branch drift'
git cat-file -e "$OWNER^{commit}"; git cat-file -e "$VQ85^{commit}"
[[ "$(git merge-base "$CANONICAL" HEAD)" == "$CANONICAL" ]] || fail 'qualification head not rooted in frozen canonical'
echo 'FCI64_AUTHORITY_AND_LIVE_CANONICAL_LOCK=PASS'

expected_src=$'src/kernel/mod_energy_conservation_types.f90\nsrc/runtime/mod_energy_conservation_ledger.f90\nsrc/runtime/mod_fmr_owned_commit_receipt.f90\nsrc/runtime/mod_fmr_serialized_multiswap_runtime.f90'
changed_src="$(git diff --name-only "$CANONICAL..HEAD" -- src | LC_ALL=C sort)"
[[ "$changed_src" == "$expected_src" ]] || { printf '%s\n' "$changed_src" >&2; fail 'production delta is not exactly four files'; }
[[ -z "$(git diff --name-only "$CANONICAL..HEAD" -- reference)" ]] || fail 'reference source changed'
for spec in "$TYPES:$TYPES_BLOB" "$LEDGER:$LEDGER_BLOB" "$OWNED:$OWNED_BLOB" "$RUNTIME:$RUNTIME_BLOB"; do
  path="${spec%%:*}"; blob="${spec##*:}"
  [[ "$(git rev-parse "HEAD:$path")" == "$blob" ]] || fail "qualified HEAD blob drift: $path"
  [[ "$(git rev-parse "$OWNER:$path")" == "$blob" ]] || fail "owner blob drift: $path"
done
[[ "$(git rev-parse "HEAD:tests/fvq/mod_fvq84_receipt_model.f90")" == "$MODEL_TEST_BLOB" ]] || fail 'independent model fixture drift'
[[ "$(git rev-parse "HEAD:tests/fvq/test_fvq85_runtime_owned_receipt_independent.f90")" == "$RECEIPT_TEST_BLOB" ]] || fail 'independent receipt oracle drift'
[[ "$(git rev-parse "$VQ85:tests/fvq/mod_fvq84_receipt_model.f90")" == "$MODEL_TEST_BLOB" ]] || fail 'F-VQ85 model authority drift'
[[ "$(git rev-parse "$VQ85:tests/fvq/test_fvq85_runtime_owned_receipt_independent.f90")" == "$RECEIPT_TEST_BLOB" ]] || fail 'F-VQ85 test authority drift'
[[ "$(git rev-parse "HEAD:$GENERIC_RECEIPT")" == "$GENERIC_RECEIPT_BLOB" ]] || fail 'generic receipt blob changed'
[[ "$(git rev-parse "$CANONICAL:$GENERIC_RECEIPT")" == "$GENERIC_RECEIPT_BLOB" ]] || fail 'canonical generic receipt mismatch'
git diff --quiet "$CANONICAL..HEAD" -- "$KERNEL_TX" "$GENERIC_RECEIPT" || fail 'generic kernel/receipt contract changed'
echo 'FCI64_EXACT_FOUR_FILE_PRODUCTION_POSTIMAGE=PASS'

# Architecture ownership must remain runtime-local and fail closed.
grep -Fq 'public :: fmr_commit_candidate_with_owned_receipt' "$OWNED" || fail 'owned commit producer missing'
grep -Fq 'if (owner_instance_id <= 0_int64) then' "$OWNED" || fail 'invalid-owner precommit guard missing'
grep -Fq 'fmr_commit_candidate_with_owned_receipt(column%column_id' "$RUNTIME" || fail 'runtime does not bind executing column id at commit callsite'
grep -Fq 'local_energy_receipt%owner_instance_id() /= column%column_id' "$RUNTIME" || fail 'runtime postcommit owner assertion missing'
grep -Fq 'receipt%owner_instance_id() /= prepared%owner_instance_id' "$LEDGER" || fail 'ledger foreign-owner guard missing'
! grep -Fq 'owner_instance_id' "$GENERIC_RECEIPT" || fail 'generic accepted receipt polluted with runtime ownership'
! grep -Eiq '^[[:space:]]*save\b|random_number|system_clock|atomic_' "$OWNED" || fail 'hidden/global owner identity mechanism detected'
echo 'FCI64_RUNTIME_KERNEL_OWNERSHIP_SEPARATION=PASS'

python3 - <<'PY'
import json
p=json.load(open('integration/f-ci/F-CI64_PRE_REGISTRATION.json'))
a=json.load(open('integration/f-ci/F-CI64_ARCHITECTURE_AUDIT.json'))
assert p['work_unit']=='F-CI64'
assert p['canonical_base']['sha']=='b162e98cc4ad6f85b741a21bd41f3db3d213559b'
assert len(p['production_scope'])==4
assert p['scope_guards']['second_water_ledger'] is False
assert p['scope_guards']['kernel_column_identity_added'] is False
assert p['scope_guards']['new_persistent_column_state'] is False
assert a['work_unit']=='F-CI64'
assert len(a['invariants'])==30
assert [x['id'] for x in a['invariants']]==list(range(1,31))
assert all(x['assessment']=='NO_ADVERSE_ADMISSION_DELTA' for x in a['invariants'])
assert a['overall']=='30_OF_30_NO_ADVERSE_ADMISSION_DELTA'
assert a['canonical_admission'] is False
print('FCI64_GOVERNANCE_AND_30_INVARIANTS=PASS')
PY

# Independent receipt-ownership attack, compiled against the composed HEAD.
STRICT=(-std=f2008 -Wall -Wextra -Werror -ffree-line-length-none -fcheck=all -fbacktrace)
BASE=(-std=f2008 -Wall -Wextra -Werror -Wno-error=compare-reals -ffree-line-length-none -fcheck=all -fbacktrace)
BASE_MODULES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
)
compile_attack(){
  local opt="$1" out="$2" src obj
  mkdir -p "$out"; local objects=()
  for src in "${BASE_MODULES[@]}"; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${BASE[@]}" -O"$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  for src in "$OWNED" "$TYPES" "$LEDGER"; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c tests/fvq/mod_fvq84_receipt_model.f90 -o "$out/model.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c tests/fvq/test_fvq85_runtime_owned_receipt_independent.f90 -o "$out/test.o"
  gfortran -O"$opt" "${objects[@]}" "$out/model.o" "$out/test.o" -o "$out/test"
  "$out/test" > "$out/out.txt"
}
compile_attack 0 "$BUILD/attack-o0"
compile_attack 2 "$BUILD/attack-o2"
cmp -s "$BUILD/attack-o0/out.txt" "$BUILD/attack-o2/out.txt" || fail 'receipt attack O0/O2 semantic drift'
cat "$BUILD/attack-o0/out.txt"
for marker in \
  'FVQ85_INVALID_OWNER_PRECOMMIT_FAIL_CLOSED=PASS' \
  'FVQ85_REAL_COLUMNS_SCALAR_RECEIPT_ALIAS_REPRODUCED=PASS' \
  'FVQ85_GENERIC_RECEIPT_EXPORT_COMPATIBILITY=PASS' \
  'FVQ85_FOREIGN_COLUMN_RECEIPT_FAIL_CLOSED=PASS' \
  'FVQ85_RIGHTFUL_OWNER_COMMIT_EXACTLY_ONCE=PASS' \
  'FVQ85_RUNTIME_OWNED_RECEIPT_INDEPENDENT_ORACLE=PASS'; do
  grep -Fq "$marker" "$BUILD/attack-o0/out.txt" || fail "missing receipt attack marker: $marker"
done
echo 'FCI64_INDEPENDENT_CROSS_COLUMN_RECEIPT_ATTACK=PASS'

# Compile and execute the admitted bottom-energy and prescribed-qbot paths with
# the actual composed serialized runtime. This protects accepted-only energy
# publication and hard water-mass behavior from the runtime receipt change.
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_owned_commit_receipt.f90
  src/kernel/mod_energy_conservation_types.f90
  src/runtime/mod_energy_conservation_ledger.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
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
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/process/mod_liquid_water_sensible_enthalpy.f90
  src/runtime/mod_fmr_bottom_external_thermal_binding.f90
  src/runtime/mod_fmr_bottom_external_thermal_provider.f90
  src/runtime/mod_fmr_bottom_sensible_energy.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
)
for opt in 0 2; do
  OUT="$BUILD/runtime-o$opt"; mkdir -p "$OUT"; objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"; extra=()
    case "$source" in
      "$TYPES"|"$LEDGER"|"$OWNED"|"$RUNTIME") extra=(-Werror=function-elimination -Werror=integer-division) ;;
    esac
    gfortran "${COMMON[@]}" "${extra[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  echo "FCI64_COMPOSED_RUNTIME_COMPILE_O${opt}=PASS"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/eb/test_eb_i18_external_bottom_thermal_provider.f90 -o "$OUT/provider_test.o"
  gfortran -O"$opt" "$OUT/mod_fmr_bottom_external_thermal_provider.o" "$OUT/provider_test.o" -o "$OUT/provider_test"
  "$OUT/provider_test" > "$OUT/provider.txt" 2>&1 || { cat "$OUT/provider.txt" >&2; fail "provider oracle O$opt"; }
  grep -Fq 'EB_I18_EXTERNAL_BOTTOM_THERMAL_PROVIDER_GATE PASS' "$OUT/provider.txt" || fail "provider marker O$opt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/eb/test_eb_i18_transaction_publication.f90 -o "$OUT/energy_test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/energy_test.o" -o "$OUT/energy_test"
  "$OUT/energy_test" > "$OUT/energy.txt" 2>&1 || { cat "$OUT/energy.txt" >&2; fail "bottom-energy publication O$opt"; }
  for marker in \
    'EB_I18_EXTERNAL_COMPLETE_ACCEPTED_PUBLICATION=PASS' \
    'EB_I18_EXTERNAL_UNAVAILABLE_HYDROLOGY_COMMIT=PASS' \
    'EB_I18_EXTERNAL_STALE_HYDROLOGY_COMMIT=PASS' \
    'EB_I18_EXTERNAL_IDENTITY_MISMATCH_FAIL_CLOSED=PASS' \
    'EB_I18_EXTERNAL_INVALID_RESPONSE_FAIL_CLOSED=PASS' \
    'EB_I18_REJECTED_TRIAL_NO_PUBLICATION=PASS' \
    'EB_I18_BACKEND_REUSE_NO_STALE_PUBLICATION=PASS' \
    'EB_I18_TRANSACTION_PUBLICATION_GATE PASS'; do
    grep -Fq "$marker" "$OUT/energy.txt" || fail "missing energy marker O$opt: $marker"
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr44r_serialized_prescribed_qbot_runtime.f90 -o "$OUT/fmr44r.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/fmr44r.o" -o "$OUT/fmr44r"
  "$OUT/fmr44r" > "$OUT/fmr44r.txt" 2>&1 || { cat "$OUT/fmr44r.txt" >&2; fail "FMR44R preservation O$opt"; }
  grep -Fq 'FMR44R_POSITIVE_QBOT_ACCEPTED_INFLOW=PASS' "$OUT/fmr44r.txt" || fail "FMR44R positive-qbot marker O$opt"
  grep -Fq 'FMR44R_SERIALIZED_PRESCRIBED_QBOT_RUNTIME_GATE=PASS' "$OUT/fmr44r.txt" || fail "FMR44R final marker O$opt"
  echo "FCI64_BOTTOM_ENERGY_AND_FMR44R_O${opt}=PASS"
done
cmp -s "$BUILD/runtime-o0/provider.txt" "$BUILD/runtime-o2/provider.txt" || fail 'provider O0/O2 drift'
cmp -s "$BUILD/runtime-o0/energy.txt" "$BUILD/runtime-o2/energy.txt" || fail 'bottom-energy O0/O2 drift'
cmp -s "$BUILD/runtime-o0/fmr44r.txt" "$BUILD/runtime-o2/fmr44r.txt" || fail 'FMR44R O0/O2 drift'
echo 'FCI64_PRESERVATION_O0_O2_SEMANTIC_IDENTITY=PASS'

git diff --check "$CANONICAL..HEAD"
if [[ -f "$STATUS" ]]; then
  python3 - <<'PY'
import json
s=json.load(open('integration/f-ci/F-CI64_STATUS.json'))
assert s['work_unit']=='F-CI64'
assert s['canonical_admission'] is False
assert s['ready_for_canonical_promotion'] is True
print('FCI64_CLOSEOUT_STATUS_CONTRACT=PASS')
PY
fi
echo 'FCI64_ADMISSION_QUALIFICATION=PASS'
echo 'FCI64_CANONICAL_ADMISSION=NOT_YET_PROMOTED'
