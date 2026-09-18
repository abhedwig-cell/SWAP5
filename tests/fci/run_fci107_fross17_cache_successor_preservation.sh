#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

SOURCE=585a8719242bf58e4c37c6283298dfad7b20a0ae
STATUS_A_AUTH=50346642bd565f79134ea17d5462e544b354998c
FROSS12_AUTH=786fe5bf59e616dcfa9a86b16b58c67ac0b3b97d
FROSS13_PRODUCTION=0fdba1a603ffd54eff7ee92a3cd7001f2b802678
FROSS17_HEAD=405ad30e823ea44deedf73edc67c68e01564c617
FROSS17_RESULT=integration/f-ross/F-ROSS17_TRANSFORM_CACHE_RESULT.json

KERNEL=src/solver/mod_rossfast_d3r_table_kernel.f90
SOLVER=src/solver/mod_rossfast_d3r_soil_water_solver.f90
MODEL=src/runtime/mod_rossfast_d3r_model_binding.f90
PROVIDER=src/solver/mod_rossfast_d3r_table_provider.f90
POLICY=src/runtime/mod_rossfast_d3r_execution_policy.f90

BASELINE_KERNEL=034136c193b287bcf9a953a9b89df2a8fb0c97cc
CACHE_KERNEL=2ad2a680e62744451d6763de48585f1bd45d3067
SOLVER_BLOB=dbb441f3529be179d64fb57f9c44336d3d20c540
MODEL_BLOB=5442fd7e7a2f392c9b796cd17c76b17977259f22
PROVIDER_BLOB=ac997bf06c56a37080d1c8db69b6d4208f4b75ca
POLICY_BLOB=a39a636d01f373ae6ef0dc3ac0e1e25b6522fda9
FROSS17_RESULT_BLOB=60da54c9957a455723b7f12b833fc80a415533c7
FROSS17_ARTIFACT_DIGEST=sha256:a44bd792504cdb4c2aa3d4c98ac4489a81be80fc0bd6eeef09a6160ce2222e96

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fci107-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail() { echo "FCI107_ROSSFAST_CACHE_ADMISSION_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$STATUS_A_AUTH" HEAD || fail 'Status-A authority not ancestor'
git merge-base --is-ancestor "$FROSS12_AUTH" HEAD || fail 'F-ROSS12 authority not ancestor'
git merge-base --is-ancestor "$FROSS13_PRODUCTION" HEAD || fail 'F-ROSS13 production authority not ancestor'
git merge-base --is-ancestor "$SOURCE" HEAD || fail 'F-CI105 canonical source not ancestor'

test "$(git rev-parse "$SOURCE:$KERNEL")" = "$BASELINE_KERNEL" || fail 'canonical source is not the exact F-ROSS17 baseline kernel'
test "$(git rev-parse "HEAD:$KERNEL")" = "$CACHE_KERNEL" || fail 'candidate kernel is not exact F-ROSS17 cache postimage'
test "$(git rev-parse "HEAD:$SOLVER")" = "$SOLVER_BLOB" || fail 'RossFast solver drift'
test "$(git rev-parse "HEAD:$MODEL")" = "$MODEL_BLOB" || fail 'RossFast model binding drift'
test "$(git rev-parse "HEAD:$PROVIDER")" = "$PROVIDER_BLOB" || fail 'RossFast table provider drift'
test "$(git rev-parse "HEAD:$POLICY")" = "$POLICY_BLOB" || fail 'RossFast execution policy drift'

source_delta="$(git diff --name-only "$SOURCE"...HEAD -- src reference)"
test "$source_delta" = "$KERNEL" || {
  printf 'FCI107_UNEXPECTED_SOURCE_DELTA=\n%s\n' "$source_delta" >&2
  fail 'production/reference delta is not exact cache-only kernel mutation'
}
echo 'FCI107_EXACT_ONE_FILE_PRODUCTION_DELTA=PASS'

if ! git cat-file -e "$FROSS17_HEAD^{commit}" 2>/dev/null; then
  git fetch --no-tags origin "$FROSS17_HEAD"
fi
test "$(git rev-parse "$FROSS17_HEAD:$FROSS17_RESULT")" = "$FROSS17_RESULT_BLOB" || fail 'F-ROSS17 result authority blob drift'
git show "$FROSS17_HEAD:$FROSS17_RESULT" > "$BUILD/fross17-result.json"

python3 - "$BUILD/fross17-result.json" "$BASELINE_KERNEL" "$CACHE_KERNEL" "$FROSS17_ARTIFACT_DIGEST" <<'PY'
import json,sys
path,baseline,candidate,digest=sys.argv[1:]
x=json.load(open(path,encoding="utf-8"))
if x.get("schema")!="swap5.f-ross17.transform-cache-result.v1":
    raise SystemExit("F-ROSS17 schema drift")
if x.get("workunit")!="F-ROSS17":
    raise SystemExit("F-ROSS17 identity drift")
p=x.get("production_mutation",{})
if p.get("baseline_blob")!=baseline or p.get("candidate_blob")!=candidate:
    raise SystemExit("F-ROSS17 kernel lineage drift")
s=x.get("scientific_equivalence",{})
if s.get("case_count")!=36 or s.get("all_cases_pass") is not True:
    raise SystemExit("F-ROSS17 scientific equivalence not PASS")
for k in ("max_head_inf_cm","max_theta_inf","max_storage_abs_cm","max_temporal_indicator_relative"):
    if float(s.get(k,1.0))!=0.0:
        raise SystemExit(f"F-ROSS17 nonzero scientific delta: {k}")
if s.get("linear_solves_per_case")!=24 or s.get("internal_retries")!=0 or s.get("alternative_solver_calls")!=0:
    raise SystemExit("F-ROSS17 workload/route authority drift")
r=x.get("primary_chronological_run",{})
if r.get("workflow_run")!=35295019847 or r.get("artifact_id")!=10528206066 or r.get("artifact_digest")!=digest:
    raise SystemExit("F-ROSS17 immutable evidence identity drift")
a=x.get("adjudication",{})
if a.get("scientific_gate")!="PASS" or a.get("algorithmic_scope_preserved") is not True:
    raise SystemExit("F-ROSS17 adjudication drift")
if a.get("certificate_internal_substeps")!=8 or a.get("candidate_steps_per_solve")!=24:
    raise SystemExit("F-ROSS17 certificate workload drift")
print("FCI107_FROSS17_IMMUTABLE_NEUTRALITY_EVIDENCE=PASS")
PY

# Re-run current production envelope and route semantics under the exact cached kernel.
bash tests/ross/run_ross13_36_material_production_envelope.sh > "$BUILD/provider.txt"
grep -Fq 'F_ROSS13_36_MATERIAL_PRODUCTION_ENVELOPE=PASS' "$BUILD/provider.txt" || fail '36-material production envelope replay failed'

EXPECTED_ROSSFAST_KERNEL_BLOB="$CACHE_KERNEL"   bash tests/ross/run_ross13_ross12_semantic_successor_preservation.sh > "$BUILD/ross12-successor.txt"
grep -Fq 'F_ROSS13_ROSS12_UNIT_SEMANTIC_SUCCESSOR_PRESERVATION=PASS' "$BUILD/ross12-successor.txt" || fail 'Ross12 semantic-successor replay failed'

bash tests/ross/run_ross12_serialized_production_wiring.sh > "$BUILD/serialized.txt"
grep -Fq 'F_ROSS12_SERIALIZED_PRODUCTION_WIRING=PASS' "$BUILD/serialized.txt" || fail 'serialized production wiring replay failed'

bash tests/publication/run_pub_p2e01_e0_paired_pilot.sh > "$BUILD/p2e01.txt"
grep -Fq 'PUB_P2E01_E0_SOLVER_SEAM_PAIRED_PILOT=PASS' "$BUILD/p2e01.txt" || fail 'P2E01 solver-seam paired replay failed'

cat "$BUILD/provider.txt"
cat "$BUILD/ross12-successor.txt"
cat "$BUILD/serialized.txt"
cat "$BUILD/p2e01.txt"

cat "$BUILD/provider.txt" "$BUILD/ross12-successor.txt" "$BUILD/serialized.txt" "$BUILD/p2e01.txt" > "$BUILD/combined.txt"
echo "FCI107_ROSSFAST_CACHE_SUCCESSOR_SHA256=$(sha256sum "$BUILD/combined.txt" | awk '{print $1}')"
echo 'FCI107_FROSS17_CACHE_SCIENTIFIC_NEUTRALITY=PASS'
echo 'FCI107_FROSS13_PROVIDER_SUCCESSOR=PASS'
echo 'FCI107_FROSS12_ROUTE_SEMANTICS=PASS'
echo 'FCI107_P2E01_SOLVER_SEAM_PRESERVATION=PASS'
echo 'FCI107_ROSSFAST_TRANSFORM_CACHE_ADMISSION_GATE=PASS'
