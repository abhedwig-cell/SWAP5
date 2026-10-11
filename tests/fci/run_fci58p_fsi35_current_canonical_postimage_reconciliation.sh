#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
MODE="${FCI58P_MODE:-reconciliation}"
fail(){ echo "FCI58P_FAIL mode=$MODE $*" >&2; exit 58; }

PREIMAGE=267f2a6ec61f78d3ba4ce75b3e5a7fdc08479135
ADMISSION=daaa41509a55be43c00cd6b92cf2ddf9590e35db
POSTIMAGE=3cf018a44b0d3e626fdf66cb3ab5a34e06ee165d
POSTIMAGE_TREE=8710a9f8b9657c5efc613f17a994f0a6e6ce1f1d
COMPOSITION=040627c77720829c297a0ba06e908efce683133c
OWNER=15ccbf4b6bcf6895b824a68c221762bef0bc08b9
OWNER_SOURCE=5898e6616dbb6871a9f52d489038235ba1172cae
FVQ68=fd93e50da5973f3e15c8f1b7fa57d72df6c31b72
FSI34=b522fe150610f900f253eeea9bf78329107de362
CANONICAL_RUN=34774219679
TASK2=src/adapter/mod_b110_production_soil_water_task2.f90
SOILWATER=src/legacy/b1_10_port/soilwater.f90
TASK2_BLOB=3090e1d3d5701a87b3624412ad88590e17369d63
SOILWATER_BLOB=c1850ea7fa82a1ed8974af57e1da95aa11a771be

for object in "$PREIMAGE" "$ADMISSION" "$POSTIMAGE" "$COMPOSITION" "$OWNER" "$OWNER_SOURCE" "$FVQ68" "$FSI34"; do
  git cat-file -e "$object^{commit}" 2>/dev/null || fail "missing authority $object"
done
[[ "$(git rev-parse "$POSTIMAGE^{tree}")" == "$POSTIMAGE_TREE" ]] || fail 'postimage tree mismatch'
[[ "$(git rev-parse "$POSTIMAGE^1")" == "$PREIMAGE" ]] || fail 'postimage first parent is not pre-admission canonical'
[[ "$(git rev-parse "$POSTIMAGE^2")" == "$ADMISSION" ]] || fail 'postimage second parent is not exact F-CI58 admission head'
git merge-base --is-ancestor "$POSTIMAGE" HEAD || fail 'qualification/preservation head does not descend from admitted canonical postimage'
echo 'FCI58P_TRUE_TWO_PARENT_ADMISSION_ANCESTRY=PASS'

for spec in "$TASK2:$TASK2_BLOB" "$SOILWATER:$SOILWATER_BLOB"; do
  path="${spec%%:*}"; blob="${spec##*:}"
  for ref in "$COMPOSITION" "$ADMISSION" "$POSTIMAGE" HEAD "$OWNER_SOURCE" "$OWNER" "$FVQ68"; do
    [[ "$(git rev-parse "$ref:$path")" == "$blob" ]] || fail "qualified production blob drift ref=$ref path=$path"
  done
done
echo 'FCI58P_EXACT_ADMITTED_PRODUCTION_BLOBS=PASS'

# Mandatory production seam and HeadCalc isolation are permanent preservation conditions.
! grep -Eqi '(^|[^[:alnum:]_])headcalc([^[:alnum:]_]|$)' "$SOILWATER" || fail 'MOD_SoilWater regained a HeadCalc dependency'
grep -Fq 'use mod_b110_production_soil_water_task2, only: run_b110_production_task2' "$SOILWATER" || fail 'Task2 service binding missing'
grep -Fq 'call run_b110_production_task2(worker)' "$SOILWATER" || fail 'worker Task2 bypasses common service'
grep -Fq 'call run_b110_production_task2()' "$SOILWATER" || fail 'standalone Task2 bypasses common service'
grep -Fq 'class(soil_water_solver_t), intent(inout) :: solver' "$TASK2" || fail 'typed common solver service seam missing'
grep -Fq 'type, extends(soil_water_solver_t) :: b110_legacy_compat_solver_t' "$TASK2" || fail 'legacy frozen-v1 coverage is not behind soil_water_solver_t'
grep -Fq 'call invoke_soil_water_solver(solver, request, workspace, result)' "$TASK2" || fail 'common solver invocation missing'

violations=0
while IFS= read -r hit; do
  [[ -z "$hit" ]] && continue
  case "$hit" in
    src/adapter/mod_reference_richards_legacy_binding.f90:*) echo "ADAPTER_BOUNDARY_ALLOWED $hit" ;;
    src/adapter/mod_b110_production_soil_water_task2.f90:*) echo "ADAPTER_BOUNDARY_ALLOWED $hit" ;;
    *) echo "PRODUCTION_INTERFACE_VIOLATION $hit" >&2; violations=$((violations+1)) ;;
  esac
done < <(grep -RinE --include='*.f90' 'call[[:space:]]+headcalc[[:space:]]*\(' src || true)
[[ "$violations" -eq 0 ]] || fail "$violations production HeadCalc interface violations"
echo 'SOLVER_INTERNAL_ALLOWED src/legacy/b1_10_port/headcalc.f90'
echo 'FCI58P_HEADCALC_DEPENDENCY_AUDIT_ZERO_VIOLATIONS=PASS'
echo 'FCI58P_MANDATORY_TYPED_SOLVER_SEAM_PRESERVATION=PASS'

# Owner and independent qualification remain the exact source-bound authorities.
python3 - "$OWNER" "$FVQ68" "$FSI34" <<'PY'
import json, subprocess, sys
owner, fvq, fsi34 = sys.argv[1:]
def load(ref, path):
    return json.loads(subprocess.check_output(['git','show',f'{ref}:{path}'], text=True))
o = load(owner, 'integration/f-si/F-SI35_QUALIFICATION.json')
q = load(fvq, 'integration/f-vq/F-VQ68_QUALIFICATION.json')
g = load(fsi34, 'integration/f-si/F-SI34_STATUS.json')
assert o['decision'] == 'QUALIFIED_MANDATORY_PRODUCTION_SOIL_WATER_SOLVER_SEAM_READY_FOR_INDEPENDENT_QUALIFICATION_AND_CANONICAL_ADMISSION'
assert o['qualified_source_candidate']['sha'] == '5898e6616dbb6871a9f52d489038235ba1172cae'
assert o['architecture_result']['production_interface_violation_count'] == 0
assert o['architecture_result']['scope_reduced'] is False
assert o['architecture_result']['full_richards_algorithm_changed'] is False
assert q['decision'] == 'QUALIFIED_FSI35_MANDATORY_PRODUCTION_SOLVER_SEAM_INDEPENDENTLY_READY_FOR_CANONICAL_ADMISSION'
assert q['candidate']['source_sha'] == '5898e6616dbb6871a9f52d489038235ba1172cae'
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
assert q['scope']['denominator_changed'] is False
assert q['scope']['scope_reduced'] is False
assert q['scope']['rossfast_required'] is False
assert g['decision'] == 'SOLVER_INTERFACE_HEADCALC_ISOLATION_V1_FINAL_CLOSURE_GAPS_IDENTIFIED'
assert g['qualified_100_percent'] is False
assert g['denominator_changed'] is False and g['scope_reduced'] is False
assert 'direct HeadCalc production call in MOD_SoilWater when worker absent' in g['hard_blockers']
assert 'common solver seam therefore not mandatory for standalone and all production Task2 routes' in g['hard_blockers']
print('FCI58P_FSI34_FSI35_FVQ68_AUTHORITIES=PASS')
PY

if [[ "$MODE" == "preservation" ]]; then
  echo "FCI58P_PRESERVATION_HEAD=$(git rev-parse HEAD)"
  echo 'F-CI58P F-SI35 PERMANENT PRESERVATION GATE PASS'
  exit 0
fi
[[ "$MODE" == "reconciliation" ]] || fail "unsupported mode $MODE"

# This workunit is metadata/test-only: no production source may differ from the admitted postimage.
if [[ -n "$(git diff --name-only "$POSTIMAGE..HEAD" -- src)" ]]; then
  git diff --name-only "$POSTIMAGE..HEAD" -- src >&2
  fail 'postimage reconciliation changed production source'
fi
allowed=(
  .github/workflows/fci58p-fsi35-postimage-reconciliation.yml
  integration/f-ci/F-CI58P_PRE_REGISTRATION.json
  integration/f-ci/F-CI58P_ARCHITECTURE_AUDIT.json
  integration/f-ci/F-CI58P_STATUS.json
  integration/f-si/F-SI35_FINAL_COMPLETION.json
  tests/fci/run_fci58p_fsi35_current_canonical_postimage_reconciliation.sh
)
mapfile -t changed < <(git diff --name-only "$POSTIMAGE..HEAD")
for path in "${changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do [[ "$path" == "$candidate" ]] && ok=1 && break; done
  [[ "$ok" -eq 1 ]] || fail "unexpected reconciliation path: $path"
done
echo 'FCI58P_METADATA_TEST_ONLY_SCOPE=PASS'

LIVE_CANONICAL="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE_CANONICAL" == "$POSTIMAGE" ]] || fail "live canonical moved during reconciliation expected=$POSTIMAGE actual=$LIVE_CANONICAL"
echo 'FCI58P_LIVE_CANONICAL_POSTIMAGE_LOCK=PASS'

# Reconfirm the already-completed broad post-promotion canonical workflow from GitHub itself.
TMP="${RUNNER_TEMP:-/tmp}/fci58p-${GITHUB_RUN_ID:-local}"
rm -rf "$TMP"; mkdir -p "$TMP"; trap 'rm -rf "$TMP"' EXIT
curl_args=(-fsSL -H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28')
if [[ -n "${GH_TOKEN:-}" ]]; then curl_args+=(-H "Authorization: Bearer $GH_TOKEN"); fi
curl "${curl_args[@]}" "https://api.github.com/repos/abhedwig-cell/SWAP5/actions/runs/$CANONICAL_RUN" > "$TMP/canonical-run.json" || fail 'cannot query canonical post-promotion workflow'
python3 - "$TMP/canonical-run.json" "$POSTIMAGE" <<'PY'
import json, sys
p, sha = sys.argv[1:]
r = json.load(open(p, encoding='utf-8'))
assert r['id'] == 34774219679
assert r['name'] == 'F-CI canonical qualification'
assert r['event'] == 'push'
assert r['head_branch'] == 'integration/f-ci-canonical'
assert r['head_sha'] == sha
assert r['status'] == 'completed'
assert r['conclusion'] == 'success'
print('FCI58P_POSTPROMOTION_BROAD_CANONICAL_WORKFLOW=PASS')
PY

# F-SI31, process view, transactions, MultiSWAP and groundwater/coupling sources
# must be byte-identical to the admitted postimage during this closure audit.
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
  [[ "$(git rev-parse "HEAD:$path")" == "$(git rev-parse "$POSTIMAGE:$path")" ]] || fail "protected source drift: $path"
done
echo 'FCI58P_RESEARCH_PROCESS_TRANSACTION_MULTISWAP_GROUNDWATER_PRESERVATION=PASS'

# Explicit architecture invariant audit must cover exactly all 30 frozen principles and no adverse delta.
python3 - integration/f-ci/F-CI58P_ARCHITECTURE_AUDIT.json <<'PY'
import json, sys
p=sys.argv[1]
a=json.load(open(p, encoding='utf-8'))
inv=a['architecture_invariants']
assert len(inv)==30
assert sorted(x['id'] for x in inv)==list(range(1,31))
assert all(x['adverse_delta'] is False for x in inv)
assert a['result']=='PASS_30_OF_30_NO_ADVERSE_DELTA'
print('FCI58P_ARCHITECTURE_INVARIANTS_30_OF_30=PASS')
PY

# Re-run the exact source-bound F-SI35 numerical/transaction/boundary/sensitivity oracle on this canonical postimage.
mkdir -p tests/fsi
for f in run_fsi35_mandatory_solver_seam_gate.sh test_fsi35_task2_dispatch_equivalence.f90; do
  git show "$OWNER_SOURCE:tests/fsi/$f" > "tests/fsi/$f" || fail "cannot materialize F-SI35 oracle $f"
done
chmod +x tests/fsi/run_fsi35_mandatory_solver_seam_gate.sh
bash tests/fsi/run_fsi35_mandatory_solver_seam_gate.sh

echo 'FCI58P_FSI35_POSTIMAGE_NUMERICAL_TRANSACTION_BOUNDARY_SENSITIVITY_REPLAY=PASS'
echo 'FCI58P_FSI34_G1_HEADCALC_ISOLATION=CLOSED'
echo 'FCI58P_FSI34_G2_SOLVER_INTERFACE=CLOSED'
echo 'FCI58P_FSI34_G3_TRANSACTION=CLOSED_BY_COMMON_SERVICE_AND_TRANSACTION_REPLAY'
echo 'FCI58P_FSI34_G4_ALTERNATIVE_SOLVER_SEAM=CLOSED_ARCHITECTURAL_SEAM_FSI31_PRESERVED_NO_ROSSFAST_PRODUCTION_REQUIRED'
echo 'FCI58P_FSI34_G5_RUNTIME_ISOLATION=CLOSED_MOD_SOILWATER_RUNTIME_BYPASS_REMOVED'
echo "FCI58P_RECONCILIATION_HEAD=$(git rev-parse HEAD)"
echo 'F-CI58P CURRENT-CANONICAL POSTIMAGE RECONCILIATION GATE PASS'
