#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CACHE_AUTH=0e68a716f655f9bba3a0962cf35ccb724b5184c3
FROSS22_HEAD=533de8c40ac243d26681f5c529b4ce3308a22ad3
FROSS22_RESULT_AUTH=9ba02ce1e525ede27f3913f664ff02ac6b5e0f3c
FROSS22_RESULT=integration/f-ross/F-ROSS22_PRODUCTION_TIERED_CERTIFICATE_RESULT.json
KERNEL=src/solver/mod_rossfast_d3r_table_kernel.f90
SOLVER=src/solver/mod_rossfast_d3r_soil_water_solver.f90
MODEL=src/runtime/mod_rossfast_d3r_model_binding.f90
PROVIDER=src/solver/mod_rossfast_d3r_table_provider.f90
POLICY=src/runtime/mod_rossfast_d3r_execution_policy.f90
CONTRACT=src/solver/mod_soil_water_solver_contract.f90
SELECTION=src/runtime/mod_fmr_rossfast_solver_selection_binding.f90
APP_HOST=src/runtime/mod_fmr_soil_water_application_host.f90

CACHE_KERNEL=2ad2a680e62744451d6763de48585f1bd45d3067
CACHE_SOLVER=dbb441f3529be179d64fb57f9c44336d3d20c540
TIERED_KERNEL=438ee46e012e9eb183b8f2532437e2fe56aa18ed
TIERED_SOLVER=2b134c36097aed2a44a56bfe8e2194b15aa063aa
MODEL_BLOB=5442fd7e7a2f392c9b796cd17c76b17977259f22
PROVIDER_BLOB=ac997bf06c56a37080d1c8db69b6d4208f4b75ca
POLICY_BLOB=a39a636d01f373ae6ef0dc3ac0e1e25b6522fda9
CONTRACT_BLOB=40a1ddc05fb8e2c1822763de645fd07a094568a3
SELECTION_BLOB=cca61af52bde3eed12b756547277cc2776589648
APP_HOST_BLOB=daca18b77673608436425e81ecd397ef3e35e4b2
RESULT_BLOB=2f83ae1fd15e6242f54942b5b8487798d18b6764

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fross22-admission-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail() { echo "FROSS22_ADMISSION_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$CACHE_AUTH" HEAD || fail 'admitted F-CI107 canonical parent not ancestor'
test "$(git rev-parse "$CACHE_AUTH:$KERNEL")" = "$CACHE_KERNEL" || fail 'cache parent kernel drift'
test "$(git rev-parse "$CACHE_AUTH:$SOLVER")" = "$CACHE_SOLVER" || fail 'cache parent solver drift'
test "$(git rev-parse "HEAD:$KERNEL")" = "$TIERED_KERNEL" || fail 'tiered kernel postimage mismatch'
test "$(git rev-parse "HEAD:$SOLVER")" = "$TIERED_SOLVER" || fail 'tiered solver postimage mismatch'

mapfile -t PROD_DIFF < <(git diff --name-only "$CACHE_AUTH" HEAD -- src reference)
printf '%s\n' "${PROD_DIFF[@]}" | sort > "$BUILD/actual.txt"
printf '%s\n' "$KERNEL" "$SOLVER" | sort > "$BUILD/expected.txt"
cmp -s "$BUILD/actual.txt" "$BUILD/expected.txt" || {
  diff -u "$BUILD/expected.txt" "$BUILD/actual.txt" >&2 || true
  fail 'production/reference delta is not exact two-file F-ROSS22 mutation'
}
echo 'FROSS22_ADMISSION_EXACT_TWO_FILE_PRODUCTION_DELTA=PASS'

for spec in "$MODEL:$MODEL_BLOB" "$PROVIDER:$PROVIDER_BLOB" "$POLICY:$POLICY_BLOB" "$CONTRACT:$CONTRACT_BLOB" "$SELECTION:$SELECTION_BLOB" "$APP_HOST:$APP_HOST_BLOB"; do
  path="${spec%%:*}"; blob="${spec##*:}"
  test "$(git rev-parse "HEAD:$path")" = "$blob" || fail "qualified dependency drift: $path"
done
echo 'FROSS22_ADMISSION_DEPENDENCY_CLOSURE=PASS'

if ! git cat-file -e "$FROSS22_HEAD^{commit}" 2>/dev/null; then git fetch --no-tags origin "$FROSS22_HEAD"; fi
if ! git cat-file -e "$FROSS22_RESULT_AUTH^{commit}" 2>/dev/null; then git fetch --no-tags origin "$FROSS22_RESULT_AUTH"; fi
test "$(git rev-parse "$FROSS22_HEAD:$KERNEL")" = "$TIERED_KERNEL" || fail 'qualified science head kernel drift'
test "$(git rev-parse "$FROSS22_HEAD:$SOLVER")" = "$TIERED_SOLVER" || fail 'qualified science head solver drift'
test "$(git rev-parse "$FROSS22_RESULT_AUTH:$FROSS22_RESULT")" = "$RESULT_BLOB" || fail 'immutable F-ROSS22 result blob drift'
git show "$FROSS22_RESULT_AUTH:$FROSS22_RESULT" > "$BUILD/fross22-result.json"
python3 - "$BUILD/fross22-result.json" "$TIERED_KERNEL" "$TIERED_SOLVER" <<'PY'
import json,sys
p,kernel,solver=sys.argv[1:]
x=json.load(open(p,encoding="utf-8"))
if x.get("schema")!="swap5.f-ross22.production-tiered-certificate-result.v1": raise SystemExit("schema drift")
pm=x.get("production_mutation",{})
if pm.get("kernel_blob")!=kernel or pm.get("solver_blob")!=solver: raise SystemExit("postimage identity drift")
a=x.get("all_material",{})
required={"case_count":216,"route_valid_count":216,"temporal_accepted_count":216,"mass_pass_count":216,"work_contract_pass_count":216,"retry_contract_pass_count":216,"K2_final_count":212,"K4_final_count":2,"K8_final_count":2}
for key,val in required.items():
    if a.get(key)!=val: raise SystemExit(f"all-material authority drift {key}")
i=x.get("production_research_identity",{})
if i.get("all_cases_exact") is not True or i.get("gate")!="PASS": raise SystemExit("research identity drift")
if x.get("adjudication",{}).get("science_and_preservation_gate")!="PASS": raise SystemExit("science gate drift")
print("FROSS22_IMMUTABLE_QUALIFICATION_AUTHORITY=PASS")
PY

bash tests/ross/run_ross13_36_material_production_envelope.sh > "$BUILD/provider.txt"
grep -Fq 'F_ROSS13_36_MATERIAL_PRODUCTION_ENVELOPE=PASS' "$BUILD/provider.txt" || fail 'provider envelope replay failed'

bash tests/ross/run_fross22_admission_all_material.sh > "$BUILD/allmat.txt"
grep -Fq 'FROSS22_ADMISSION_ALL_MATERIAL_GATE=PASS' "$BUILD/allmat.txt" || fail '216-case admission replay failed'

SWAP5_ROSSFAST_EXPECT_TIERED_WORK=1 EXPECTED_ROSSFAST_KERNEL_BLOB="$TIERED_KERNEL" EXPECTED_ROSSFAST_ADAPTER_BLOB="$TIERED_SOLVER" \
  bash tests/ross/run_ross13_ross12_semantic_successor_preservation.sh > "$BUILD/semantic.txt"
grep -Fq 'F_ROSS13_ROSS12_UNIT_SEMANTIC_SUCCESSOR_PRESERVATION=PASS' "$BUILD/semantic.txt" || fail 'adapter/selection semantic successor failed'

bash tests/ross/run_ross12_serialized_production_wiring.sh > "$BUILD/serialized.txt"
grep -Fq 'F_ROSS12_SERIALIZED_PRODUCTION_WIRING=PASS' "$BUILD/serialized.txt" || fail 'serialized production wiring failed'

bash tests/publication/run_pub_p2e01_e0_paired_pilot.sh > "$BUILD/p2e01.txt"
grep -Fq 'PUB_P2E01_E0_SOLVER_SEAM_PAIRED_PILOT=PASS' "$BUILD/p2e01.txt" || fail 'solver-seam paired replay failed'

cat "$BUILD/provider.txt" "$BUILD/allmat.txt" "$BUILD/semantic.txt" "$BUILD/serialized.txt" "$BUILD/p2e01.txt"
echo 'FROSS22_ADMISSION_PROVIDER_PRESERVATION=PASS'
echo 'FROSS22_ADMISSION_216_CASE_SCIENCE=PASS'
echo 'FROSS22_ADMISSION_ROUTE_SEMANTICS=PASS'
echo 'FROSS22_ADMISSION_SERIALIZED_PRODUCTION=PASS'
echo 'FROSS22_ADMISSION_SOLVER_SEAM_PRESERVATION=PASS'
echo 'FROSS22_TIERED_PRODUCTION_ADMISSION_OWNER_GATE=PASS'
