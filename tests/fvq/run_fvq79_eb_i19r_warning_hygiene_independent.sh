#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CANONICAL="5e5e498dc56d1df1dd7ebebbf9901c946445a1ab"
BASE="b2ba462cfade41eb68643db75ca28e234a123a02"
CANDIDATE="788ff3c9af90143960a5aa3831f0171160aa8c47"
CANDIDATE_TREE="f8d6ab9bbdf620c350c54ed88752e121b8eea763"
BACKEND="src/runtime/mod_fmr_serialized_reference_backend.f90"
RUNTIME="src/runtime/mod_fmr_serialized_multiswap_runtime.f90"
ENERGY="src/runtime/mod_fmr_bottom_sensible_energy.f90"
fail() { echo "FVQ79_FAIL $*" >&2; exit 179; }

git fetch -q origin integration/f-ci-canonical
[[ "$(git rev-parse origin/integration/f-ci-canonical)" == "$CANONICAL" ]] || fail 'live canonical moved'
git merge-base --is-ancestor "$BASE" "$CANDIDATE" || fail 'remediation candidate is not based on EB-I19'
git merge-base --is-ancestor "$CANDIDATE" HEAD || fail 'verifier branch does not contain exact EB-I19R candidate'
[[ "$(git show -s --format=%T "$CANDIDATE")" == "$CANDIDATE_TREE" ]] || fail 'candidate tree drift'

changed_src="$(git diff --name-only "$BASE" "$CANDIDATE" -- src | sort)"
expected_src=$'src/runtime/mod_fmr_bottom_sensible_energy.f90\nsrc/runtime/mod_fmr_serialized_multiswap_runtime.f90\nsrc/runtime/mod_fmr_serialized_reference_backend.f90'
[[ "$changed_src" == "$expected_src" ]] || { printf '%s\n' "$changed_src" >&2; fail 'unexpected remediation production delta'; }
git diff --quiet "$BASE" "$CANDIDATE" -- reference tests/eb/test_eb_i18_transaction_publication.f90 || fail 'remediation changed reference source or qualified fixture'
git diff --quiet "$CANDIDATE" HEAD -- src reference || fail 'F-VQ79 changed production/reference source'

declare -A BLOBS=(
  [src/runtime/mod_fmr_serialized_reference_backend.f90]=3506b453ba6a00111d182f29db8cbfb288001854
  [src/runtime/mod_fmr_serialized_multiswap_runtime.f90]=07d3699e3e3972921fdb36352d75c47cb12d03b7
  [src/runtime/mod_fmr_bottom_sensible_energy.f90]=6c7e9b9ed77d116104fd6299a6404037a2548960
)
for path in "${!BLOBS[@]}"; do
  [[ "$(git rev-parse "$CANDIDATE:$path")" == "${BLOBS[$path]}" ]] || fail "candidate blob drift: $path"
done
echo 'FVQ79_SCOPE_PROVENANCE_AND_BLOBS=PASS'

# Reconstruct the remediation independently from exact EB-I19 and demand
# byte-identical source. This proves the pushed candidate contains only the
# declared bounded transformation.
REPRO="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq79-repro-${GITHUB_RUN_ID:-local}-$$"
BASE_OUT="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq79-base-${GITHUB_RUN_ID:-local}-$$.txt"
CAND_OUT="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq79-cand-${GITHUB_RUN_ID:-local}-$$.txt"
cleanup() {
  rm -f "$BASE_OUT" "$CAND_OUT"
  git worktree remove --force "$REPRO" >/dev/null 2>&1 || true
  rm -rf "$REPRO"
}
trap cleanup EXIT

git worktree add --detach "$REPRO" "$BASE" >/dev/null
(
  cd "$REPRO"
  python3 "$ROOT/tests/eb/_apply_eb_i19r_warning_hygiene.py"
  for path in "$ENERGY" "$BACKEND" "$RUNTIME"; do
    [[ "$(git hash-object "$path")" == "$(git -C "$ROOT" rev-parse "$CANDIDATE:$path")" ]] || exit 184
  done
)
echo 'FVQ79_REMEDIATION_BYTE_RECONSTRUCTION=PASS'

# Independent static interpretation: no tolerance or physical branch was
# changed. Only overflow-safe capacity expression and deterministic readiness
# evaluation order are different.
grep -Fq 'config%max_committed_substeps <= ishft(huge(0), -1)' "$BACKEND" || fail 'new capacity guard missing'
grep -Fq 'if (candidate%ready()) then' "$BACKEND" || fail 'explicit candidate readiness missing'
grep -Fq 'if (.not. response%ready()) then' "$RUNTIME" || fail 'explicit response readiness missing'
grep -Fq 'if (.not. response%identity_matches(request)) then' "$RUNTIME" || fail 'explicit response identity missing'
grep -Fq 'if (.not. candidate%ready()) return' "$ENERGY" || fail 'energy candidate readiness missing'
grep -Fq 'if (.not. parameters%ready()) return' "$ENERGY" || fail 'energy parameter readiness missing'
# Exact zero is a donor-class invariant. It remains exact deliberately; no
# physics tolerance was introduced merely to silence -Wcompare-reals.
grep -Fq 'sample%bottom_outward_exchange_native /= 0.0_real64' "$ENERGY" || fail 'exact donor-none zero invariant changed'
echo 'FVQ79_NO_PHYSICS_TOLERANCE_OR_POLICY_CHANGE_STATIC=PASS'

# Compare full qualified semantic outputs before and after remediation. The
# baseline uses the EB-I19 gate in its detached worktree; the candidate uses the
# EB-I19R gate. Both gates internally require O0/O2 identity and F-MR44R replay.
(
  cd "$REPRO"
  git reset --hard "$BASE" >/dev/null
  bash tests/eb/run_eb_i19_production_materialization_gate.sh
) > "$BASE_OUT" 2>&1 || { cat "$BASE_OUT" >&2; fail 'baseline EB-I19 replay'; }

bash tests/eb/run_eb_i19r_warning_hygiene_gate.sh > "$CAND_OUT" 2>&1 || {
  cat "$CAND_OUT" >&2
  fail 'candidate EB-I19R replay'
}

python3 - "$BASE_OUT" "$CAND_OUT" <<'PY'
import math
import re
import sys
base = open(sys.argv[1], encoding='utf-8').read()
cand = open(sys.argv[2], encoding='utf-8').read()

markers = [
    'EB_I18_EXTERNAL_COMPLETE_ACCEPTED_PUBLICATION=PASS',
    'EB_I18_EXTERNAL_UNAVAILABLE_HYDROLOGY_COMMIT=PASS',
    'EB_I18_EXTERNAL_STALE_HYDROLOGY_COMMIT=PASS',
    'EB_I18_EXTERNAL_IDENTITY_MISMATCH_FAIL_CLOSED=PASS',
    'EB_I18_EXTERNAL_INVALID_RESPONSE_FAIL_CLOSED=PASS',
    'EB_I18_REJECTED_TRIAL_NO_PUBLICATION=PASS',
    'EB_I18_BACKEND_REUSE_NO_STALE_PUBLICATION=PASS',
    'EB_I18_TRANSACTION_PUBLICATION_GATE PASS',
    'FMR44R_POSITIVE_QBOT_ACCEPTED_INFLOW=PASS',
    'FMR44R_NEARBY_BOTTOM_MODE_FAIL_CLOSED=PASS',
    'FMR44R_SERIALIZED_PRESCRIBED_QBOT_RUNTIME_GATE=PASS',
]
for marker in markers:
    if marker not in base or marker not in cand:
        raise SystemExit(f'FVQ79_MARKER_MISMATCH {marker}')

patterns = {
    'mass': r'FMR44R_POSITIVE_QBOT_MASS residual=\s*([+\-0-9.Ee]+) total_in=\s*([+\-0-9.Ee]+) total_out=\s*([+\-0-9.Ee]+)',
    'cert': r'FMR44R_POSITIVE_QBOT_CERTIFICATE Binf=\s*([+\-0-9.Ee]+) Ch=\s*([+\-0-9.Ee]+)',
    'qeq': r'FMR44R_QEQ=\s*([+\-0-9.Ee]+)',
    'qbot': r'FMR44R_POSITIVE_QBOT=\s*([+\-0-9.Ee]+)',
    'budget': r'FMR44R_QUALIFICATION_HEAD_BUDGET_CM=\s*([+\-0-9.Ee]+)',
}
for label, pattern in patterns.items():
    b = re.findall(pattern, base)
    c = re.findall(pattern, cand)
    if b != c or not b:
        raise SystemExit(f'FVQ79_NUMERIC_SEMANTIC_DRIFT {label} base={b} cand={c}')

rows = re.findall(patterns['mass'], cand)
for row in rows:
    residual, total_in, total_out = map(float, row)
    if not all(math.isfinite(v) for v in (residual, total_in, total_out)):
        raise SystemExit('FVQ79_NONFINITE_MASS')
    if abs(residual) > 1.0e-12 or abs(total_in-total_out) > 1.0e-12:
        raise SystemExit('FVQ79_MASS_CLOSURE_FAIL')
print(f'FVQ79_MATCHED_MASS_ROWS={len(rows)}')
print('FVQ79_PRE_POST_NUMERIC_SEMANTIC_IDENTITY=PASS')
print('FVQ79_HARD_MASS_ORACLE=PASS')
PY

grep -Fq 'EB_I19R_AFFECTED_PRODUCTION_WARNING_HYGIENE_O0=PASS' "$CAND_OUT" || fail 'O0 warning hygiene marker missing'
grep -Fq 'EB_I19R_AFFECTED_PRODUCTION_WARNING_HYGIENE_O2=PASS' "$CAND_OUT" || fail 'O2 warning hygiene marker missing'
grep -Fq 'EB_I19R_O0_O2_SEMANTIC_IDENTITY=PASS' "$CAND_OUT" || fail 'candidate O0/O2 identity missing'

echo 'FVQ79_WARNING_HYGIENE_INDEPENDENT_REQUALIFICATION=PASS'
