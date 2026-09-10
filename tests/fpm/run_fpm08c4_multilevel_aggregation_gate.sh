#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpm08c4-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=4a2b7a82287a209dc8150dcb70c6c2d6e459c592
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "src/process/mod_drainage_multilevel_aggregation.f90" ]] || {
  echo 'FPM08C4_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FPM08C4_PRODUCTION_DELTA_SINGLE_AGGREGATION_MODULE=PASS'

changed_ref="$(git diff --name-only "$BASE" -- reference)"
[[ -z "$changed_ref" ]] || {
  echo 'FPM08C4_REFERENCE_DELTA_NONE=FAIL' >&2
  printf '%s\n' "$changed_ref" >&2
  exit 1
}
echo 'FPM08C4_REFERENCE_DELTA_NONE=PASS'

for authority in \
  3ce245e3cac068268bdff2f0af0fdcdf022c82aa \
  3553c63e753bbf714378cd0dff5047769ad3185b \
  49728b999b884a37643908c1dad40269f4e2db9b \
  f5f567c6af4879bf80107a7579dd342de6d5afe0 \
  702db051bf5dd0960a962be919ea0cfbf01895a4; do
  git cat-file -e "$authority^{commit}"
done

git show 49728b999b884a37643908c1dad40269f4e2db9b:integration/f-vq/F-VQ38_STATUS.json | \
  grep -Fq 'QUALIFIED_DRAMET2_IPOS1_TO_5_RESPONSE_FAMILY_SCIENTIFIC_EQUIVALENCE_WITHIN_NORMALIZED_VALID_DOMAIN'
git show f5f567c6af4879bf80107a7579dd342de6d5afe0:integration/f-vq/F-VQ40_STATUS.json | \
  grep -Fq 'QUALIFIED_DRAMET1_TABULATED_RESPONSE_SCIENTIFIC_EQUIVALENCE_WITH_EXPLICIT_FAIL_CLOSED_LEGACY_DEGENERATE'
git show 702db051bf5dd0960a962be919ea0cfbf01895a4:integration/f-vq/F-VQ42_STATUS.json | \
  grep -Fq 'QUALIFIED_EMPIRICAL_INTERFLOW_DRAINAGE_SIDE_RESPONSE_AND_SENSITIVITY_WITH_EXPLICIT_ACTIVATION_SINGULARITY'
echo 'FPM08C4_UPSTREAM_RESPONSE_AUTHORITIES_LOCKED=PASS'

python3 - <<'PY'
import json
from pathlib import Path
src = Path('src/process/mod_drainage_multilevel_aggregation.f90').read_text()
low = src.lower()
for forbidden in ['headcalc', 'modflow', '.dra', 'owltab', 't1900', 'calendar', 'madr', 'nrlevs', 'allocate(', 'deallocate(', ' save ', 'sum(']:
    assert forbidden not in low, forbidden
for required in [
    'drainage_level_exchange_t', 'levels(:)', 'level_index', 'flux_defined',
    'signed_soil_to_drain_rate', 'derivative_defined', 'dq_dgroundwater_level',
    'branch_boundary', 'singular_tangent', 'derivative_unavailable_level_count',
    'aggregate_derivative_numerically_unrepresentable',
    'total_is_derived_view_not_additional_transfer', 'persistent_process_state',
    'fixed_legacy_level_capacity', 'do level = 1, size(levels)'
]:
    assert required in low, required
assert low.count('do level = 1, size(levels)') >= 3
print('FPM08C4_DYNAMIC_ASSUMED_SHAPE_NO_LEGACY_CAPACITY=PASS')
print('FPM08C4_DETERMINISTIC_LEVEL_ORDER_STATIC=PASS')
print('FPM08C4_NO_IO_RUNTIME_SOLVER_OR_SPATIAL_DISTRIBUTION_LEAKAGE=PASS')
print('FPM08C4_MASS_VIEW_AND_SENSITIVITY_SEPARATION_STATIC=PASS')

audit = json.loads(Path('integration/f-pm/F-PM08C4_INVARIANT_AUDIT.json').read_text())
assert audit['work_unit'] == 'F-PM08C4'
assert audit['audit_result'] == 'PASS'
items = audit['invariants']
assert len(items) == 30
assert [x['id'] for x in items] == list(range(1, 31))
assert all(x['status'] == 'PASS' and x['rationale'].strip() for x in items)
print('FPM08C4_30_INVARIANT_AUDIT=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror=compare-reals -fcheck=all -fbacktrace)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    src/process/mod_drainage_multilevel_aggregation.f90 \
    tests/fpm/test_fpm08c4_multilevel_aggregation.f90 \
    -o "$OUT/test_fpm08c4"
  "$OUT/test_fpm08c4" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }
  echo "FPM08C4_CANDIDATE_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FPM08C4_CANDIDATE_O0_O2_OUTPUT_IDENTITY=PASS'

for marker in \
  'FPM08C4_ONE_LEVEL_IDENTITY=PASS' \
  'FPM08C4_DETERMINISTIC_MULTILEVEL_SUM=PASS' \
  'FPM08C4_ALL_DEFINED_DERIVATIVE_SUM=PASS' \
  'FPM08C4_MIXED_SIGNED_TRANSFER_AGGREGATION=PASS' \
  'FPM08C4_TOTAL_IS_DERIVED_MASS_VIEW=PASS' \
  'FPM08C4_UNAVAILABLE_TANGENT_PRESERVES_FLUX=PASS' \
  'FPM08C4_BRANCH_AND_SINGULARITY_UNION=PASS' \
  'FPM08C4_NONFINITE_TANGENT_METADATA_PRESERVES_FLUX=PASS' \
  'FPM08C4_INVALID_FLUX_FAILS_CLOSED=PASS' \
  'FPM08C4_LEVEL_IDENTITY_ORDER_FAILS_CLOSED=PASS' \
  'FPM08C4_EMPTY_COLLECTION_FAILS_CLOSED=PASS' \
  'FPM08C4_DYNAMIC_LEVEL_COUNT_ABOVE_LEGACY_CAPACITY=PASS' \
  'FPM08C4_AGGREGATE_DERIVATIVE_OVERFLOW_PRESERVES_FLUX=PASS' \
  'FPM08C4_STATELESS_A_B_A_IDENTITY=PASS' \
  'FPM08C4_MULTILEVEL_AGGREGATION_TEST PASS'; do
  grep -Fq "$marker" "$BUILD/o0/output.txt"
done

cat "$BUILD/o0/output.txt"
echo "FPM08C4_CANDIDATE_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FPM08C4_MULTILEVEL_AGGREGATION_GATE PASS'
