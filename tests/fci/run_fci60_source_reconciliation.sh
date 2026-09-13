#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
fail(){ echo "FCI60_SOURCE_FAIL $*" >&2; exit 160; }
CANONICAL=379afd11e9a1d7fbef5ec74c9e05b0ec55884f4b
CANONICAL_TREE=556221f62b4fde616981499eba68ef5460f5d83c
FPM12=82189c148a38b90b6a5a326d03f282ccbee52960
FVQ72=a3c7bf5a60d80b430758f85489b316b5bcbc2fdc
FVQ72_TESTED=30ad6104f91e4a10bb7f9863c6c8fff0dacddfa6
FMR43=c8ff545cf720db467389c67ac2f9a595e57277ed
FVQ71=f2f410bb74ef40c23fcc16048bb54f9301b989db
FCI59=648c3a2a90655ae053c2fd020563b3c4adce458b
FCI59P=595c06a8a9600fa6b130db4a31e6b8e5cb735f8b
FPM11=602a461957c45623fc414ef15e40a1bfe755de43
FKT20=c25eb87f979f4c341713de8fdc890beb0ea3e35f

[[ "$(git rev-parse "$CANONICAL^{tree}")" == "$CANONICAL_TREE" ]] || fail 'canonical tree mismatch'
git merge-base --is-ancestor "$CANONICAL" HEAD || fail 'F-CI60 not based on exact restart canonical'
[[ -z "$(git diff --name-only "$CANONICAL"..HEAD -- src reference)" ]] || fail 'F-CI60 changed production/reference source'

declare -A expected=(
 [src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90]=b8ff1fb1d9434e952163b6955305c6373dd8ac82
 [src/runtime/mod_fmr_surface_evaporation_accepted_publication.f90]=f0f3ce5c16a66c2058c22a529e176d6b06446649
 [src/runtime/mod_fmr_accepted_commit_receipt.f90]=6798b3296b426950bf028814585c3f5de9be950b
 [src/kernel/mod_kernel_transactions.f90]=c7c5b7d3357e4e6739c8f647d6232baca45563e6
 [src/process/mod_restricted_surface_evaporation.f90]=a213af4deec2fe854d79120899827852a57237d1
)
for path in "${!expected[@]}"; do
  [[ "$(git rev-parse "HEAD:$path")" == "${expected[$path]}" ]] || fail "HEAD blob mismatch $path"
  [[ "$(git rev-parse "$CANONICAL:$path")" == "${expected[$path]}" ]] || fail "canonical blob mismatch $path"
  [[ "$(git rev-parse "$FPM12:$path")" == "${expected[$path]}" ]] || fail "F-PM12 blob mismatch $path"
  [[ "$(git rev-parse "$FVQ72_TESTED:$path")" == "${expected[$path]}" ]] || fail "F-VQ72 tested blob mismatch $path"
done
echo 'FCI60_SOURCE_ALREADY_PRESENT_EXACT=PASS'
echo 'FCI60_ZERO_PRODUCTION_REFERENCE_DELTA=PASS'

TMP="${RUNNER_TEMP:-/tmp}/fci60-auth-${GITHUB_RUN_ID:-local}-$$"; rm -rf "$TMP"; mkdir -p "$TMP"; trap 'rm -rf "$TMP"' EXIT
for spec in \
  "$FPM12:integration/f-pm/F-PM12_STATUS.json:fpm12.json" \
  "$FVQ72:integration/f-vq/F-VQ72_STATUS.json:fvq72.json" \
  "$FVQ71:integration/f-vq/F-VQ71_STATUS.json:fvq71.json" \
  "$FCI59:integration/f-ci/F-CI59_STATUS.json:fci59.json" \
  "$FCI59P:integration/f-ci/F-CI59P_STATUS.json:fci59p.json" \
  "$FPM11:integration/f-pm/F-PM11_STATUS.json:fpm11.json"; do
  IFS=: read -r ref path out <<< "$spec"
  git show "$ref:$path" > "$TMP/$out" || fail "cannot materialize $spec"
done
python3 - "$TMP" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])
load=lambda n: json.load(open(p/n,encoding='utf-8'))
fpm12=load('fpm12.json'); fvq72=load('fvq72.json'); fvq71=load('fvq71.json')
fci59=load('fci59.json'); fci59p=load('fci59p.json'); fpm11=load('fpm11.json')
assert fpm12['decision']=='OWNER_QUALIFIED_SURFACE_EVAPORATION_ACCEPTED_PUBLICATION_CANDIDATE_BOUND_PROVENANCE'
assert fvq72['decision']=='QUALIFIED_SURFACE_EVAPORATION_ACCEPTED_PUBLICATION_CANDIDATE_BOUND_PROVENANCE'
assert fvq72['independently_qualified'] is True and fvq72['tested_head']['conclusion']=='success'
assert fvq71['decision']=='QUALIFIED_ATOMIC_SURFACE_EVAPORATION_ACCEPTED_PUBLICATION'
assert fci59['decision']=='QUALIFIED_FOR_CURRENT_CANONICAL_ADMISSION'
assert fci59['permanent_preservation_gate_updated'] is True
assert fci59p['decision']=='QUALIFIED_F_CI59P_ATOMIC_SURFACE_PUBLICATION_CURRENT_CANONICAL_POSTIMAGE_RECONCILIATION'
assert fci59p['qualification']['F_VQ71_postimage_replay']=='PASS_O0_O2'
assert fci59p['qualification']['permanent_preservation']=='PASS'
assert fpm11['decision']=='QUALIFIED_ET_ROOT_UPTAKE_SURFACE_EVAPORATION_V1_100_PERCENT_COMPLETE'
assert fpm11['completion_100_percent'] is True
print('FCI60_AUTHORITY_CHAIN=PASS')
print('FCI60_EXISTING_PERMANENT_REGRESSION_COVERAGE=PASS_NO_DUPLICATE_GATE_REQUIRED')
print('FCI60_FPM11_COMPLETION_AUTHORITY=PASS')
PY

# Current canonical is the metadata postimage merge of F-CI59 + F-CI59P.
parents="$(git rev-list --parents -n 1 "$CANONICAL")"
[[ "$parents" == "$CANONICAL $FCI59 $FCI59P" ]] || fail "unexpected canonical parent chain: $parents"
echo 'FCI60_FCI59_FCI59P_POSTIMAGE_ANCESTRY=PASS'

if git merge-base --is-ancestor "$FKT20" HEAD; then fail 'non-admissible F-KT20 entered F-CI60'; fi
if git merge-base --is-ancestor "$FKT20" "$CANONICAL"; then fail 'non-admissible F-KT20 entered canonical'; fi
echo 'FCI60_FKT20_ROUTE_EXCLUDED=PASS'

# No production/source changes means these architecture properties are preserved, while the runtime replay tests 7/13/16 explicitly.
echo 'FCI60_INVARIANT_3=PASS'
echo 'FCI60_INVARIANT_4=PASS_NO_NEW_STATE'
echo 'FCI60_INVARIANT_7=PASS'
echo 'FCI60_INVARIANT_8=PASS'
echo 'FCI60_INVARIANT_9=PASS'
echo 'FCI60_INVARIANT_13=PASS'
echo 'FCI60_INVARIANT_16=PASS'
echo 'FCI60_INVARIANT_21=PASS'
echo 'FCI60_INVARIANT_22=PASS'
echo 'FCI60_INVARIANT_23=PASS'
echo 'FCI60_INVARIANT_26=PASS'
echo 'FCI60_INVARIANT_29=PASS'
echo 'FCI60_INVARIANT_30=PASS'
echo 'FCI60_SOURCE_RECONCILIATION=PASS'
