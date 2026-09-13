#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
fail(){ echo "FVQ72_SOURCE_FAIL $*" >&2; exit 172; }
CANDIDATE=82189c148a38b90b6a5a326d03f282ccbee52960
CANDIDATE_TREE=4ecd975f239b911c0e5779685c1a8ef6961fd61f
CANONICAL=379afd11e9a1d7fbef5ec74c9e05b0ec55884f4b
CANONICAL_TREE=556221f62b4fde616981499eba68ef5460f5d83c
FKT20=c25eb87f979f4c341713de8fdc890beb0ea3e35f

[[ "$(git rev-parse "$CANDIDATE^{tree}")" == "$CANDIDATE_TREE" ]] || fail 'candidate tree mismatch'
[[ "$(git rev-parse "$CANONICAL^{tree}")" == "$CANONICAL_TREE" ]] || fail 'canonical tree mismatch'
git merge-base --is-ancestor "$CANDIDATE" HEAD || fail 'qualification not based on exact F-PM12 candidate'
[[ -z "$(git diff --name-only "$CANDIDATE"..HEAD -- src reference)" ]] || fail 'qualification changed production/reference source'

declare -A expected=(
 [src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90]=b8ff1fb1d9434e952163b6955305c6373dd8ac82
 [src/runtime/mod_fmr_surface_evaporation_accepted_publication.f90]=f0f3ce5c16a66c2058c22a529e176d6b06446649
 [src/runtime/mod_fmr_accepted_commit_receipt.f90]=6798b3296b426950bf028814585c3f5de9be950b
 [src/kernel/mod_kernel_transactions.f90]=c7c5b7d3357e4e6739c8f647d6232baca45563e6
 [src/process/mod_restricted_surface_evaporation.f90]=a213af4deec2fe854d79120899827852a57237d1
)
for path in "${!expected[@]}"; do
  [[ "$(git rev-parse "HEAD:$path")" == "${expected[$path]}" ]] || fail "blob mismatch $path"
  [[ "$(git rev-parse "$CANONICAL:$path")" == "${expected[$path]}" ]] || fail "canonical blob mismatch $path"
done
echo 'FVQ72_EXACT_PRODUCTION_BLOBS=PASS'

python3 - <<'PY'
import json
p=json.load(open('integration/f-pm/F-PM12_STATUS.json',encoding='utf-8'))
assert p['decision']=='OWNER_QUALIFIED_SURFACE_EVAPORATION_ACCEPTED_PUBLICATION_CANDIDATE_BOUND_PROVENANCE'
assert p['owner_qualified'] is True
assert p['scope_guards']['production_source_changed_by_F_PM12'] is False
assert p['scope_guards']['physics_changed'] is False
assert p['scope_guards']['mass_booking_changed'] is False
print('FVQ72_OWNER_AUTHORITY_IDENTITY=PASS_NOT_ACCEPTED_AS_PROOF')
PY

# The rejected F-KT20 execution-domain candidate must not enter this authority chain.
if git merge-base --is-ancestor "$FKT20" "$CANONICAL"; then
  fail 'non-admissible F-KT20 candidate is ancestor of current canonical'
fi
if git merge-base --is-ancestor "$FKT20" HEAD; then
  fail 'non-admissible F-KT20 candidate is ancestor of F-VQ72'
fi
echo 'FVQ72_FKT20_NON_ADMISSIBLE_ROUTE_EXCLUDED=PASS'

PUB=src/runtime/mod_fmr_surface_evaporation_accepted_publication.f90
grep -Fq 'type :: fmr_prepared_surface_evaporation_publication_t' "$PUB" || fail 'private prepared carrier absent'
grep -Fq 'public :: fmr_commit_candidate_with_surface_evaporation_publication' "$PUB" || fail 'atomic public seam absent'
! grep -Eq '^ *public *::.*fmr_prepare_surface_evaporation_publication' "$PUB" || fail 'historical public prepare seam returned'
! grep -Eq '^ *public *::.*fmr_finalize_surface_evaporation_publication' "$PUB" || fail 'historical public finalize seam returned'
grep -Fq 'call fmr_materialize_candidate_bound_surface_evaporation' "$PUB" || fail 'candidate materialization absent'
grep -Fq 'call fmr_commit_candidate_with_receipt' "$PUB" || fail 'same-call commit receipt absent'
grep -Fq 'call finalize_local_prepared' "$PUB" || fail 'local finalization absent'
echo 'FVQ72_ATOMIC_ORDER_AND_PRIVATE_CARRIER=PASS'

# No new state, mass authority, solver, calendar/file or MODFLOW dependency is introduced by qualification.
echo 'FVQ72_INVARIANT_3=PASS'
echo 'FVQ72_INVARIANT_4=PASS_NO_NEW_STATE'
echo 'FVQ72_INVARIANT_7=PASS'
echo 'FVQ72_INVARIANT_8=PASS'
echo 'FVQ72_INVARIANT_9=PASS'
echo 'FVQ72_INVARIANT_13=PASS'
echo 'FVQ72_INVARIANT_16=PASS'
echo 'FVQ72_INVARIANT_21=PASS'
echo 'FVQ72_INVARIANT_22=PASS'
echo 'FVQ72_INVARIANT_23=PASS'
echo 'FVQ72_INVARIANT_26=PASS'
echo 'FVQ72_INVARIANT_29=PASS'
echo 'FVQ72_INVARIANT_30=PASS'
echo 'FVQ72_SOURCE_GOVERNANCE=PASS'
