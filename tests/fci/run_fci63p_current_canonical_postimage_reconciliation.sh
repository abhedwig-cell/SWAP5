#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "FCI63P_POSTIMAGE_GATE_FAIL $*" >&2; exit 163; }

PRE=5e5e498dc56d1df1dd7ebebbf9901c946445a1ab
ADMISSION=78fdb96520d52fddb1e33b14611fee364de916e7
POSTIMAGE=e16262d0d9af3c83f40234ab669f0faa66e12519
OWNER=788ff3c9af90143960a5aa3831f0171160aa8c47
VQ79=77496e5eb0fe8712613ca2959552d612f3c2a29d
OLD_AUTH=46ed64aba280bf721bce6f99446d0dd4ed00e38f
STATUS=integration/f-ci/F-CI63P_STATUS.json
CANONICAL_WORKFLOW=.github/workflows/fci-canonical.yml

for object in "$PRE" "$ADMISSION" "$POSTIMAGE" "$OWNER" "$VQ79"; do
  git cat-file -e "$object^{commit}" || fail "missing authority $object"
done
[[ "$(git rev-parse "$POSTIMAGE^1")" == "$PRE" ]] || fail 'postimage first parent mismatch'
[[ "$(git rev-parse "$POSTIMAGE^2")" == "$ADMISSION" ]] || fail 'postimage second parent mismatch'
[[ "$(git rev-list --parents -n1 "$POSTIMAGE" | awk '{print NF-1}')" -eq 2 ]] || fail 'F-CI63 admission is not a true two-parent merge'
[[ "$(git rev-parse "$POSTIMAGE^{tree}")" == "$(git rev-parse "$ADMISSION^{tree}")" ]] || fail 'promoted tree differs from exact final green F-CI63 tree'
git merge-base --is-ancestor "$POSTIMAGE" HEAD || fail 'reconciliation not descended from admitted postimage'
LIVE="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE" == "$POSTIMAGE" ]] || fail "live canonical drift expected=$POSTIMAGE actual=$LIVE"
echo 'FCI63P_TRUE_TWO_PARENT_PROMOTION_AND_LIVE_POSTIMAGE_LOCK=PASS'

declare -A BLOBS=(
  [src/process/mod_liquid_water_sensible_enthalpy.f90]=2247370ee34fac73a0e2d0b9fa15e171467aded3
  [src/runtime/mod_fmr_bottom_external_thermal_binding.f90]=ed2a2ee36add299ebb5f8bde276da2f3b360cc28
  [src/runtime/mod_fmr_bottom_external_thermal_provider.f90]=885cc50ad1f5cfc17843e412c0f5dfdb989d553b
  [src/runtime/mod_fmr_bottom_sensible_energy.f90]=6c7e9b9ed77d116104fd6299a6404037a2548960
  [src/runtime/mod_fmr_bottom_thermal_carrier.f90]=c371be3e22eaa6da70ca8cbb060bc42d1e0e0bfb
  [src/runtime/mod_fmr_serialized_multiswap_runtime.f90]=07d3699e3e3972921fdb36352d75c47cb12d03b7
  [src/runtime/mod_fmr_serialized_reference_backend.f90]=3506b453ba6a00111d182f29db8cbfb288001854
)
for path in "${!BLOBS[@]}"; do
  [[ "$(git rev-parse "$POSTIMAGE:$path")" == "${BLOBS[$path]}" ]] || fail "postimage blob mismatch $path"
  [[ "$(git rev-parse "$VQ79:$path")" == "${BLOBS[$path]}" ]] || fail "F-VQ79 authority blob mismatch $path"
  [[ "$(git rev-parse "HEAD:$path")" == "${BLOBS[$path]}" ]] || fail "reconciliation source drift $path"
done
[[ -z "$(git diff --name-only "$POSTIMAGE..HEAD" -- src reference)" ]] || fail 'F-CI63P changes production/reference source'
echo 'FCI63P_EXACT_SEVEN_CANONICAL_POSTIMAGE_BLOBS=PASS'

allowed=(
  integration/f-ci/F-CI63P_STATUS.json
  tests/fci/run_fci63p_current_canonical_postimage_reconciliation.sh
  .github/workflows/fci63p-current-canonical-postimage-reconciliation.yml
  .github/workflows/fci63p-materialize-moving-current.yml
  .github/workflows/fci-canonical.yml
)
mapfile -t changed < <(git diff --name-only "$POSTIMAGE..HEAD")
for path in "${changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do
    [[ "$path" == "$candidate" ]] && ok=1 && break
  done
  [[ "$ok" -eq 1 ]] || fail "unexpected reconciliation path: $path"
done
echo 'FCI63P_RECONCILIATION_SCOPE_ALLOWLIST=PASS'

grep -Fq "AUTH=$POSTIMAGE" "$CANONICAL_WORKFLOW" || fail 'moving-current authority not advanced to F-CI63 postimage'
if grep -Fq "AUTH=$OLD_AUTH" "$CANONICAL_WORKFLOW"; then
  fail 'stale F-CI62 moving-current authority remains active'
fi
for path in "${!BLOBS[@]}"; do
  grep -Fq "$path" "$CANONICAL_WORKFLOW" || fail "F-CI63 source absent from moving dependency surface: $path"
done
grep -Fq 'FCI63_MOVING_BOTTOM_ENERGY_PUBLICATION_PRESERVATION=PASS' "$CANONICAL_WORKFLOW" || fail 'F-CI63 moving preservation marker absent'
grep -Fq 'FCI62_MOVING_PRESCRIBED_QBOT_TEMPORAL_RUNTIME_PRESERVATION=PASS' "$CANONICAL_WORKFLOW" || fail 'F-CI62 preservation marker lost'
echo 'FCI63P_MOVING_CURRENT_AUTHORITY_RECONCILIATION=PASS'

python3 - "$ADMISSION" "$VQ79" "$STATUS" <<'PY'
import json, pathlib, subprocess, sys
admission, vq, status_path = sys.argv[1:]
def at(commit, path):
    return json.loads(subprocess.check_output(['git','show',f'{commit}:{path}'], text=True))
a = at(admission, 'integration/f-ci/F-CI63_STATUS.json')
v = at(vq, 'qualification/F-VQ79_STATUS.json')
assert a['decision'] == 'QUALIFIED_F_CI63_READY_FOR_CANONICAL_PROMOTION'
assert a['ready_for_canonical_promotion'] is True
assert a['canonical_admission'] is False
assert a['postimage_reconciled'] is False
assert a['architecture_invariants'] == '30_OF_30_NO_ADVERSE_ADMISSION_DELTA'
assert abs(a['qualification_evidence']['max_abs_mass_residual_cm']) <= 1.0e-12
assert v['decision'] == 'QUALIFIED_FOR_CURRENT_CANONICAL_ADMISSION_REVIEW'
assert v['conclusion'] == 'success'
assert v['independent_evidence']['remediation_production_delta_exactly_three_files'] is True
assert v['independent_evidence']['reference_source_changed'] is False
assert v['independent_evidence']['no_physics_tolerance_or_solver_policy_change'] is True
assert v['independent_evidence']['pre_post_numeric_semantic_identity'] == 'PASS'
assert abs(v['independent_evidence']['max_abs_mass_residual_cm']) <= 1.0e-12
assert v['independent_evidence']['O0_O2_semantic_identity'] is True
if pathlib.Path(status_path).exists():
    s = json.loads(pathlib.Path(status_path).read_text())
    assert s['decision'] == 'QUALIFIED_F_CI63P_CURRENT_CANONICAL_POSTIMAGE_RECONCILIATION'
    assert s['production_canonical_admitted'] is True
    assert s['postimage_reconciled'] is True
    assert s['moving_current_preservation_reconciled'] is True
    assert s['full_energy_balance_complete'] is False
print('FCI63P_FCI63_AND_FVQ79_AUTHORITY_RECONCILIATION=PASS')
PY

# EB-I19R was qualified against the pre-admission live canonical. Keep that
# historical gate immutable. For postimage replay, copy it inside tests/eb and
# replace only its live-canonical lock with the admitted postimage. All source,
# fixture, warning-hygiene, O0/O2 and F-MR44R checks remain byte-identical.
TMP_GATE="$(mktemp "$ROOT/tests/eb/.fci63p-i19r-postimage.XXXXXX.sh")"
OUT="$(mktemp "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/fci63p-i19r.XXXXXX.txt")"
cleanup(){ rm -f "$TMP_GATE" "$OUT"; }
trap cleanup EXIT
python3 - tests/eb/run_eb_i19r_warning_hygiene_gate.sh "$TMP_GATE" "$PRE" "$POSTIMAGE" <<'PY'
from pathlib import Path
import sys
source, target, old, new = map(Path, sys.argv[1:3]) if False else (Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], sys.argv[4])
text = source.read_text()
needle = f'CANONICAL="{old}"'
replacement = f'CANONICAL="{new}"'
if text.count(needle) != 1:
    raise SystemExit(f'FCI63P expected one historical canonical lock, found {text.count(needle)}')
target.write_text(text.replace(needle, replacement, 1))
PY
chmod +x "$TMP_GATE"
bash "$TMP_GATE" > "$OUT" 2>&1 || { cat "$OUT" >&2; fail 'EB-I19R postimage replay'; }
cat "$OUT"

python3 - "$OUT" <<'PY'
import math, re, sys
text = open(sys.argv[1], encoding='utf-8').read()
required = [
  'EB_I18_EXTERNAL_COMPLETE_ACCEPTED_PUBLICATION=PASS',
  'EB_I18_EXTERNAL_UNAVAILABLE_HYDROLOGY_COMMIT=PASS',
  'EB_I18_EXTERNAL_STALE_HYDROLOGY_COMMIT=PASS',
  'EB_I18_EXTERNAL_IDENTITY_MISMATCH_FAIL_CLOSED=PASS',
  'EB_I18_EXTERNAL_INVALID_RESPONSE_FAIL_CLOSED=PASS',
  'EB_I18_REJECTED_TRIAL_NO_PUBLICATION=PASS',
  'EB_I18_BACKEND_REUSE_NO_STALE_PUBLICATION=PASS',
  'EB_I19R_AFFECTED_PRODUCTION_WARNING_HYGIENE_O0=PASS',
  'EB_I19R_AFFECTED_PRODUCTION_WARNING_HYGIENE_O2=PASS',
  'EB_I19R_O0_O2_SEMANTIC_IDENTITY=PASS',
  'EB_I19R_WARNING_HYGIENE_QUALIFICATION=PASS',
]
missing = [m for m in required if m not in text]
if missing:
    raise SystemExit('FCI63P_POSTIMAGE_MARKER_FAIL ' + ','.join(missing))
rows = re.findall(r'FMR44R_POSITIVE_QBOT_MASS residual=\s*([+\-0-9.Ee]+) total_in=\s*([+\-0-9.Ee]+) total_out=\s*([+\-0-9.Ee]+)', text)
if len(rows) != 2:
    raise SystemExit(f'FCI63P_MASS_ROW_COUNT_FAIL {len(rows)}')
for row in rows:
    residual, total_in, total_out = map(float, row)
    if not all(math.isfinite(x) for x in (residual, total_in, total_out)):
        raise SystemExit('FCI63P_NONFINITE_MASS')
    if abs(residual) > 1.0e-12 or abs(total_in-total_out) > 1.0e-12:
        raise SystemExit('FCI63P_HARD_MASS_FAIL')
print(f'FCI63P_POSTIMAGE_MASS_ROWS={len(rows)}')
print('FCI63P_POSTIMAGE_HARD_MASS_ORACLE=PASS')
PY

echo 'FCI63P_EB_I19R_POSTIMAGE_RUNTIME_REPLAY=PASS'
git diff --quiet -- src reference || fail 'postimage runtime replay mutated production/reference source'
git diff --check "$POSTIMAGE..HEAD"
echo "FCI63P_EXACT_HEAD=$(git rev-parse HEAD)"
echo 'F-CI63P CURRENT-CANONICAL POSTIMAGE RECONCILIATION GATE PASS'
