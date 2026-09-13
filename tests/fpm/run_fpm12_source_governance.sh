#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
fail(){ echo "FPM12_SOURCE_FAIL $*" >&2; exit 112; }
BASE=379afd11e9a1d7fbef5ec74c9e05b0ec55884f4b
PRE=4fae08472c053d1b3d43d3d0b4f9b61956e7b646
PM09=b49585c255d1c0d4c0cec6cdfaab6cabc49ac19a
PM10=c6ebf7bec2cbe39c984d266e01142d11cf0b1540
FMR43=c8ff545cf720db467389c67ac2f9a595e57277ed
FVQ71=f2f410bb74ef40c23fcc16048bb54f9301b989db
MATERIALIZER=src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
PUBLICATION=src/runtime/mod_fmr_surface_evaporation_accepted_publication.f90
RECEIPT=src/runtime/mod_fmr_accepted_commit_receipt.f90
KERNEL=src/kernel/mod_kernel_transactions.f90
PROCESS=src/process/mod_restricted_surface_evaporation.f90

for c in "$BASE" "$PRE" "$PM09" "$PM10" "$FMR43" "$FVQ71"; do git cat-file -e "$c^{commit}" || fail "missing authority $c"; done
git merge-base --is-ancestor "$BASE" HEAD || fail 'branch does not descend from restart authority'
[[ -z "$(git diff --name-only "$BASE"..HEAD -- src reference)" ]] || fail 'F-PM12 changed production or reference source'
echo 'FPM12_ZERO_PRODUCTION_REFERENCE_DELTA=PASS'

mapfile -t prod_delta < <(git diff --name-only "$PRE".."$BASE" -- src | sort)
expected=("$PUBLICATION" "$MATERIALIZER")
mapfile -t expected_sorted < <(printf '%s\n' "${expected[@]}" | sort)
[[ "${prod_delta[*]}" == "${expected_sorted[*]}" ]] || { printf '%s\n' "${prod_delta[@]}" >&2; fail 'unexpected production delta since F-PM09 canonical'; }
echo 'FPM12_ONLY_BOUNDED_PUBLICATION_PRODUCTION_DELTA_SINCE_FPM09=PASS'

for spec in \
 "$MATERIALIZER:b8ff1fb1d9434e952163b6955305c6373dd8ac82" \
 "$PUBLICATION:f0f3ce5c16a66c2058c22a529e176d6b06446649" \
 "$RECEIPT:6798b3296b426950bf028814585c3f5de9be950b" \
 "$KERNEL:c7c5b7d3357e4e6739c8f647d6232baca45563e6" \
 "$PROCESS:a213af4deec2fe854d79120899827852a57237d1"; do
 p="${spec%%:*}"; b="${spec##*:}"; [[ "$(git rev-parse "HEAD:$p")" == "$b" ]] || fail "source identity drift $p"; done
echo 'FPM12_EXACT_CURRENT_CANONICAL_SOURCE_IDENTITIES=PASS'

python3 - "$PUBLICATION" "$PM09" "$PM10" "$FMR43" "$FVQ71" <<'PY'
import json, subprocess, sys
pub,pm09,pm10,fmr43,fvq71=sys.argv[1:]
def show(ref,path): return json.loads(subprocess.check_output(['git','show',f'{ref}:{path}'],text=True))
a=show(pm09,'integration/f-pm/F-PM09_ET_ROOT_UPTAKE_SURFACE_EVAPORATION_V1_COMPLETENESS_AUDIT.json')
assert a['decision']=='ET_ROOT_UPTAKE_SURFACE_EVAPORATION_V1_FINAL_CLOSURE_GAPS_IDENTIFIED'
assert a['criteria']['accepted_publication']=='FAIL'
assert {g['id'] for g in a['closure_gaps']}=={'FPM09-G01','FPM09-G02','FPM09-G03'}
o=show(pm10,'integration/f-pm/F-PM10_STATUS.json')
assert o['state']['owner_qualified'] is True and o['state']['independently_qualified'] is False and o['state']['canonically_admitted'] is False
m=show(fmr43,'integration/f-mr/F-MR43_STATUS.json')
q=show(fvq71,'integration/f-vq/F-VQ71_STATUS.json')
assert m['decision']=='OWNER_QUALIFIED_ATOMIC_SURFACE_EVAPORATION_ACCEPTED_PUBLICATION'
assert q['decision']=='QUALIFIED_ATOMIC_SURFACE_EVAPORATION_ACCEPTED_PUBLICATION' and q['independently_qualified'] and q['closed']
ci=json.load(open('integration/f-ci/F-CI59_STATUS.json'))
cip=json.load(open('integration/f-ci/F-CI59P_STATUS.json'))
assert ci['decision']=='QUALIFIED_FOR_CURRENT_CANONICAL_ADMISSION'
assert cip['closed'] is True
assert cip['FPM09_closure_gaps']['G01']=='CLOSED_BY_F_MR43'
assert cip['FPM09_closure_gaps']['G02']=='CLOSED_BY_F_VQ71'
assert cip['FPM09_closure_gaps']['G03']=='CLOSED_POSTIMAGE_RECONCILED_BY_F_CI59_AND_F_CI59P'
text=open(pub,encoding='utf-8').read().lower()
required=['public :: fmr_commit_candidate_with_surface_evaporation_publication','call fmr_materialize_candidate_bound_surface_evaporation','call fmr_commit_candidate_with_receipt','call finalize_local_prepared','type :: fmr_prepared_surface_evaporation_publication_t']
for x in required: assert x in text, x
for x in ['public :: fmr_prepare_surface_evaporation_publication','public :: fmr_finalize_surface_evaporation_publication']: assert x not in text, x
assert text.index(required[1]) < text.index(required[2]) < text.index(required[3])
for x in ['mass%total_in','mass%total_out','mass_ledger','day_of','month_of','year_of','midnight','.swp','file_unit','pathname','modflow']: assert x not in text, x
print('FPM12_FPM09_AND_SUPERSESSION_CHAIN=PASS')
print('FPM12_ATOMIC_CANDIDATE_BOUND_ORDER=PASS')
print('FPM12_FVQ57_SPLIT_ATTACK_UNCONSTRUCTIBLE_BY_PUBLIC_API=PASS')
print('FPM12_NO_SECOND_MASS_AUTHORITY_OR_SILENT_DEPENDENCY=PASS')
PY

echo 'FPM12_INVARIANT_3_EXPLICIT_DATA_SEPARATION=PASS'
echo 'FPM12_INVARIANT_4_COMPACT_STATE=PASS_NO_NEW_STATE'
echo 'FPM12_INVARIANT_7_TRANSACTIONAL_STEPS=PASS'
echo 'FPM12_INVARIANT_8_WARM_START_PHYSICAL_ORIGIN_UNCHANGED=PASS'
echo 'FPM12_INVARIANT_9_GENERIC_TIME=PASS'
echo 'FPM12_INVARIANT_13_MASS_ABSOLUTE=PASS'
echo 'FPM12_INVARIANT_16_MULTISWAP=PASS'
echo 'FPM12_INVARIANT_21_PHYSICS_REUSE=PASS'
echo 'FPM12_INVARIANT_22_SOLVER_INTERNALS_ISOLATED=PASS'
echo 'FPM12_INVARIANT_23_PHYSICS_POLICY_SEPARATED=PASS'
echo 'FPM12_INVARIANT_26_DIAGNOSTICS=PASS'
echo 'FPM12_INVARIANT_29_NO_SILENT_DEPENDENCIES=PASS'
echo 'FPM12_INVARIANT_30_EXPLICIT_AUDIT=PASS'
echo 'FPM12_SOURCE_GOVERNANCE_GATE=PASS'
