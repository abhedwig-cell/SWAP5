#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CANONICAL="5e5e498dc56d1df1dd7ebebbf9901c946445a1ab"
CANDIDATE="15184dd06c1d0f8accc0d306a12d25a3568f1f2e"
CANDIDATE_TREE="eb3b7fa3f848ac40d5c60e1d060bd1e2f14e3e2f"
fail() { echo "FVQ77_FAIL $*" >&2; exit 177; }

# Independent scope and provenance lock. Qualification files may extend the
# candidate branch, but production/reference source must stay exactly equal to
# the tested EB-I18R2 candidate.
git fetch -q origin integration/f-ci-canonical
test "$(git rev-parse origin/integration/f-ci-canonical)" = "$CANONICAL" || fail 'live canonical moved'
git merge-base --is-ancestor "$CANONICAL" "$CANDIDATE" || fail 'candidate not based on pinned canonical'
git merge-base --is-ancestor "$CANDIDATE" HEAD || fail 'verifier branch does not contain exact candidate'
test "$(git show -s --format=%T "$CANDIDATE")" = "$CANDIDATE_TREE" || fail 'candidate tree drift'

changed_src="$(git diff --name-only "$CANONICAL" "$CANDIDATE" -- src | sort)"
expected_src=$'src/process/mod_liquid_water_sensible_enthalpy.f90\nsrc/runtime/mod_fmr_bottom_external_thermal_binding.f90\nsrc/runtime/mod_fmr_bottom_external_thermal_provider.f90\nsrc/runtime/mod_fmr_bottom_sensible_energy.f90\nsrc/runtime/mod_fmr_bottom_thermal_carrier.f90'
[[ "$changed_src" == "$expected_src" ]] || { printf '%s\n' "$changed_src" >&2; fail 'unexpected candidate production source delta'; }
! git diff --name-only "$CANONICAL" "$CANDIDATE" -- reference | grep -q . || fail 'candidate reference source changed'
! git diff --name-only "$CANDIDATE" HEAD -- src reference | grep -q . || fail 'qualification branch changed production/reference source'

declare -A EXPECTED_BLOBS=(
  [src/process/mod_liquid_water_sensible_enthalpy.f90]=2247370ee34fac73a0e2d0b9fa15e171467aded3
  [src/runtime/mod_fmr_bottom_thermal_carrier.f90]=c371be3e22eaa6da70ca8cbb060bc42d1e0e0bfb
  [src/runtime/mod_fmr_bottom_external_thermal_binding.f90]=ed2a2ee36add299ebb5f8bde276da2f3b360cc28
  [src/runtime/mod_fmr_bottom_external_thermal_provider.f90]=885cc50ad1f5cfc17843e412c0f5dfdb989d553b
  [src/runtime/mod_fmr_bottom_sensible_energy.f90]=1f3d6f975278f960feac4388b0cdd36a0f5f162d
)
for path in "${!EXPECTED_BLOBS[@]}"; do
  test "$(git rev-parse "$CANDIDATE:$path")" = "${EXPECTED_BLOBS[$path]}" || fail "candidate blob drift: $path"
done
echo 'FVQ77_SCOPE_PROVENANCE_AND_BLOBS=PASS'

TMP="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq77-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$TMP/o0" "$TMP/o2"
trap 'rm -rf "$TMP"' EXIT

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SOURCES=(
  src/process/mod_liquid_water_sensible_enthalpy.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/runtime/mod_fmr_bottom_external_thermal_binding.f90
  src/runtime/mod_fmr_bottom_external_thermal_provider.f90
  src/runtime/mod_fmr_bottom_sensible_energy.f90
  tests/fvq/test_fvq77_bottom_energy_independent.f90
)

for opt in 0 2; do
  out="$TMP/o$opt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" "${SOURCES[@]}" -o "$out/fvq77_oracle"
  "$out/fvq77_oracle" > "$out/oracle.txt" 2>&1 || { cat "$out/oracle.txt" >&2; fail "independent oracle O$opt"; }
  for marker in \
    'FVQ77_MISSING_EXTERNAL_DONOR_FAIL_CLOSED=PASS' \
    'FVQ77_RESOLVED_EXTERNAL_DONOR=PASS' \
    'FVQ77_LINEAGE_MISMATCH_FAIL_CLOSED=PASS' \
    'FVQ77_UNAVAILABLE_BINDING_NO_ZERO_FALLBACK=PASS' \
    'FVQ77_CROSS_CLASS_BINDING_FAIL_CLOSED=PASS' \
    'FVQ77_PROVIDER_IDENTITY_AND_UNAVAILABLE=PASS' \
    'FVQ77_CARRIER_CHECKPOINT_ROLLBACK=PASS' \
    'FVQ77_BOTTOM_ENERGY_INDEPENDENT_ORACLE=PASS'; do
    grep -Fq "$marker" "$out/oracle.txt" || { cat "$out/oracle.txt" >&2; fail "missing independent marker O$opt: $marker"; }
  done
  grep -Fq 'FVQ77_RESOLVED_TOTAL_ENERGY_J_M2=' "$out/oracle.txt" || fail "missing energy oracle O$opt"
  cat "$out/oracle.txt"
  echo "FVQ77_INDEPENDENT_ORACLE_O${opt}=PASS"
done

cmp -s "$TMP/o0/oracle.txt" "$TMP/o2/oracle.txt" || {
  diff -u "$TMP/o0/oracle.txt" "$TMP/o2/oracle.txt" >&2 || true
  fail 'independent O0/O2 semantic drift'
}
echo 'FVQ77_INDEPENDENT_O0_O2_SEMANTIC_IDENTITY=PASS'

# Owner evidence is replayed only after the independent oracle. This replay is
# used to verify the full staged transaction/backend composition, not as the
# sole basis for F-VQ77's semantic conclusion.
bash tests/eb/run_eb_i18r2_current_canonical_gate.sh > "$TMP/owner.txt" 2>&1 || {
  cat "$TMP/owner.txt" >&2
  fail 'EB-I18R2 owner replay'
}
for marker in \
  'EB_I18_EXTERNAL_COMPLETE_ACCEPTED_PUBLICATION=PASS' \
  'EB_I18_REJECTED_TRIAL_NO_PUBLICATION=PASS' \
  'EB_I18_BACKEND_REUSE_NO_STALE_PUBLICATION=PASS' \
  'EB_I18R_O0_O2_SEMANTIC_IDENTITY=PASS' \
  'EB_I18R_CURRENT_CANONICAL_STAGED_QUALIFICATION=PASS' \
  'EB_I18R2_CURRENT_CANONICAL_QUALIFICATION=PASS'; do
  grep -Fq "$marker" "$TMP/owner.txt" || { cat "$TMP/owner.txt" >&2; fail "missing owner replay marker: $marker"; }
done

python3 - "$TMP/owner.txt" <<'PY'
import math
import re
import sys
text = open(sys.argv[1], encoding='utf-8').read()
rows = re.findall(r'FMR44R_POSITIVE_QBOT_MASS residual=\s*([+\-0-9.Ee]+) total_in=\s*([+\-0-9.Ee]+) total_out=\s*([+\-0-9.Ee]+)', text)
if len(rows) < 2:
    raise SystemExit('FVQ77_OWNER_PARSE_FAIL mass rows')
for raw in rows:
    residual, total_in, total_out = map(float, raw)
    if not all(math.isfinite(x) for x in (residual, total_in, total_out)):
        raise SystemExit('FVQ77_OWNER_NUMERIC_FAIL nonfinite')
    if abs(residual) > 1.0e-12:
        raise SystemExit(f'FVQ77_OWNER_NUMERIC_FAIL mass={residual}')
    if total_in <= 0.0 or total_out <= 0.0 or abs(total_in-total_out) > 1.0e-12:
        raise SystemExit('FVQ77_OWNER_NUMERIC_FAIL transfer closure')
print(f'FVQ77_OWNER_MASS_ROWS={len(rows)}')
print('FVQ77_OWNER_HARD_MASS_ORACLE=PASS')
PY

echo 'FVQ77_TRANSACTIONAL_OWNER_REPLAY=PASS'
echo 'FVQ77_INDEPENDENT_QUALIFICATION=PASS'
