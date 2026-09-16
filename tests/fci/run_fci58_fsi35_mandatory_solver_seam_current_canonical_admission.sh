#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "FCI58_FAIL $*" >&2; exit 58; }

RESTART=267f2a6ec61f78d3ba4ce75b3e5a7fdc08479135
COMPOSITION=040627c77720829c297a0ba06e908efce683133c
OWNER=15ccbf4b6bcf6895b824a68c221762bef0bc08b9
OWNER_SOURCE=5898e6616dbb6871a9f52d489038235ba1172cae
FVQ68=fd93e50da5973f3e15c8f1b7fa57d72df6c31b72
FINDING=b522fe150610f900f253eeea9bf78329107de362
TASK2=src/adapter/mod_b110_production_soil_water_task2.f90
SOILWATER=src/legacy/b1_10_port/soilwater.f90
TASK2_BLOB=3090e1d3d5701a87b3624412ad88590e17369d63
SOILWATER_BLOB=c1850ea7fa82a1ed8974af57e1da95aa11a771be

for object in "$RESTART" "$COMPOSITION" "$OWNER" "$OWNER_SOURCE" "$FVQ68" "$FINDING"; do
  git cat-file -e "$object^{commit}" || fail "missing authority $object"
done
[[ "$(git rev-parse "$COMPOSITION^")" == "$RESTART" ]] || fail 'composition is not directly based on restart canonical'
git merge-base --is-ancestor "$COMPOSITION" HEAD || fail 'qualification head lost exact production composition ancestry'
LIVE_CANONICAL="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE_CANONICAL" == "$RESTART" ]] || fail "live canonical drift expected=$RESTART actual=$LIVE_CANONICAL"
echo 'FCI58_AUTHORITY_AND_LIVE_CANONICAL_LOCKS=PASS'

mapfile -t prod_changed < <(git diff --name-only "$RESTART..$COMPOSITION" | sort)
expected=("$TASK2" "$SOILWATER")
[[ "${#prod_changed[@]}" -eq 2 ]] || fail "composition changed ${#prod_changed[@]} paths, expected 2"
[[ "${prod_changed[0]}" == "${expected[0]}" && "${prod_changed[1]}" == "${expected[1]}" ]] || {
  printf 'FCI58_COMPOSITION_SCOPE_FAIL actual: %s\n' "${prod_changed[*]}" >&2
  exit 58
}
for spec in "$TASK2:$TASK2_BLOB" "$SOILWATER:$SOILWATER_BLOB"; do
  path="${spec%%:*}"; blob="${spec##*:}"
  for ref in "$COMPOSITION" HEAD "$OWNER_SOURCE" "$OWNER" "$FVQ68"; do
    [[ "$(git rev-parse "$ref:$path")" == "$blob" ]] || fail "blob mismatch ref=$ref path=$path"
  done
done
echo 'FCI58_EXACT_OWNER_FVQ68_PRODUCTION_BLOBS_LOCKED=PASS'

allowed=(
  integration/f-ci/F-CI58_PRE_REGISTRATION.json
  integration/f-ci/F-CI58_ARCHITECTURE_AUDIT.json
  integration/f-ci/F-CI58_STATUS.json
  tests/fci/run_fci58_fsi35_mandatory_solver_seam_current_canonical_admission.sh
  .github/workflows/fci58-fsi35-mandatory-solver-seam-current-canonical-admission.yml
)
mapfile -t qual_changed < <(git diff --name-only "$COMPOSITION..HEAD")
for path in "${qual_changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do [[ "$path" == "$candidate" ]] && ok=1 && break; done
  [[ "$ok" -eq 1 ]] || fail "qualification scope contains unexpected path: $path"
done
echo 'FCI58_QUALIFICATION_SCOPE_ALLOWLIST=PASS'

python3 - "$OWNER" "$FVQ68" <<'PY'
import json, subprocess, sys
owner, fvq = sys.argv[1:]
def show(ref, path):
    return json.loads(subprocess.check_output(['git','show',f'{ref}:{path}'], text=True))
o = show(owner, 'integration/f-si/F-SI35_QUALIFICATION.json')
q = show(fvq, 'integration/f-vq/F-VQ68_QUALIFICATION.json')
assert o['decision'] == 'QUALIFIED_MANDATORY_PRODUCTION_SOIL_WATER_SOLVER_SEAM_READY_FOR_INDEPENDENT_QUALIFICATION_AND_CANONICAL_ADMISSION'
assert o['qualified_source_candidate']['sha'] == '5898e6616dbb6871a9f52d489038235ba1172cae'
assert o['architecture_result']['production_interface_violation_count'] == 0
assert o['architecture_result']['scope_reduced'] is False
assert o['architecture_result']['full_richards_algorithm_changed'] is False
assert q['decision'] == 'QUALIFIED_FSI35_MANDATORY_PRODUCTION_SOLVER_SEAM_INDEPENDENTLY_READY_FOR_CANONICAL_ADMISSION'
assert q['candidate']['source_sha'] == '5898e6616dbb6871a9f52d489038235ba1172cae'
assert q['candidate']['base_canonical'] == '267f2a6ec61f78d3ba4ce75b3e5a7fdc08479135'
assert q['independent_execution']['conclusion'] == 'success'
assert q['source_identity']['candidate_source_identity'] == 'EXACT'
assert q['independent_findings']['direct_HeadCalc_call_policy']['PRODUCTION_INTERFACE_VIOLATION'] == []
assert q['independent_findings']['standalone_worker_bitwise_dispatch_equivalence'] == 'PASS'
assert q['independent_findings']['accepted_rejected_retry_transaction_replay'] == 'PASS'
assert q['independent_findings']['dynamic_top_boundary_regimes'] == 'PASS'
assert q['independent_findings']['prescribed_qbot_sensitivity'] == 'PASS'
assert q['independent_findings']['hard_mass_qualified_profile'] == 'PASS'
assert q['independent_findings']['worker_scratch_isolation'] == 'PASS'
assert q['independent_findings']['F_SI31_research_contract_preservation'] == 'PASS'
assert q['independent_findings']['process_hydraulic_view_preservation'] == 'PASS'
assert q['independent_findings']['serialized_MultiSWAP_source_preservation'] == 'PASS'
assert q['independent_findings']['groundwater_coupling_source_preservation'] == 'PASS'
assert q['scope']['denominator_changed'] is False and q['scope']['scope_reduced'] is False
assert q['scope']['rossfast_required'] is False
print('FCI58_OWNER_AND_FVQ68_AUTHORITIES_LOCKED=PASS')
PY

# Independent post-composition HeadCalc dependency audit.
! grep -Eqi '(^|[^[:alnum:]_])headcalc([^[:alnum:]_]|$)' "$SOILWATER" || fail 'MOD_SoilWater still knows HeadCalc'
grep -Fq 'call run_b110_production_task2(worker)' "$SOILWATER" || fail 'worker common service dispatch missing'
grep -Fq 'call run_b110_production_task2()' "$SOILWATER" || fail 'standalone common service dispatch missing'
grep -Fq 'class(soil_water_solver_t), intent(inout) :: solver' "$TASK2" || fail 'typed common solver service seam missing'
violations=0
while IFS= read -r hit; do
  [[ -z "$hit" ]] && continue
  case "$hit" in
    src/adapter/mod_reference_richards_legacy_binding.f90:*) echo "ADAPTER_BOUNDARY_ALLOWED $hit" ;;
    src/adapter/mod_b110_production_soil_water_task2.f90:*) echo "ADAPTER_BOUNDARY_ALLOWED $hit" ;;
    *) echo "PRODUCTION_INTERFACE_VIOLATION $hit" >&2; violations=$((violations+1)) ;;
  esac
done < <(grep -RinE --include='*.f90' 'call[[:space:]]+headcalc[[:space:]]*\(' src || true)
[[ "$violations" -eq 0 ]] || fail "$violations production HeadCalc violations"
echo 'SOLVER_INTERNAL_ALLOWED src/legacy/b1_10_port/headcalc.f90'
echo 'FCI58_HEADCALC_DEPENDENCY_AUDIT_ZERO_VIOLATIONS=PASS'

# Sources that define transactions, research isolation, hydraulic process view,
# MultiSWAP serialization and groundwater coupling must remain byte-identical
# to the restart canonical. F-SI35 is admitted only at the Task2 adapter seam.
protected=(
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_coupling_policy.f90
  src/runtime/mod_groundwater_predictor_corrector_window.f90
  src/transaction/mod_transaction_reference.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/legacy/b1_10_port/headcalc.f90
)
for path in "${protected[@]}"; do
  [[ "$(git rev-parse "HEAD:$path")" == "$(git rev-parse "$RESTART:$path")" ]] || fail "protected source drift: $path"
done
echo 'FCI58_TRANSACTION_RESEARCH_MULTISWAP_PROCESS_GROUNDWATER_SOURCE_PRESERVATION=PASS'

# Materialize, but do not commit, the exact source-bound F-SI35 numerical oracle.
mkdir -p tests/fsi
for f in run_fsi35_mandatory_solver_seam_gate.sh test_fsi35_task2_dispatch_equivalence.f90; do
  git show "$OWNER_SOURCE:tests/fsi/$f" > "tests/fsi/$f" || fail "cannot materialize F-SI35 oracle $f"
done
chmod +x tests/fsi/run_fsi35_mandatory_solver_seam_gate.sh
bash tests/fsi/run_fsi35_mandatory_solver_seam_gate.sh

echo 'FCI58_FSI35_SOURCE_BOUND_NUMERICAL_TRANSACTION_BOUNDARY_SENSITIVITY_REPLAY=PASS'
echo "FCI58_EXACT_HEAD=$(git rev-parse HEAD)"
echo 'F-CI58 CURRENT-CANONICAL ADMISSION GATE PASS'
