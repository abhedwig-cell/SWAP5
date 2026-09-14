#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "FPM19_DRAINAGE_V1_FINAL_GATE_FAIL $*" >&2; exit 119; }

CANONICAL='6425fb3290da637357e47618b459f4caf65a78d8'
PM13='e5cd87eafb95356ca0d5ef8399fcb64feae78fd2'
PM14='52c1a9aebddc435ef3792378f958305a96308ed0'
PM17='45455f54c0c3554150e273aff07bfccd06d69c14'
VQ73='ea40e2d850aa9b4b23b25ba6b4a63ffd39811001'
VQ74='60c121a0993993bd79fb30ddfd54e2a9d14f042e'
VQ76='5ee4920ffe680c920b64996159060fc1f509fcd8'
FCI61='eb2b2b17b2d54eeab22c4cba922426d8168e56a9'
FCI61P='e79b0272edb544ec4c8000a4d6869274f1ab3ae5'
FCI62='46ed64aba280bf721bce6f99446d0dd4ed00e38f'
FCI62P_SECOND_PARENT='9bec0cf6068046b42b9818913470e28bd4fbcb45'
VQ76_STATUS_BLOB='c61081dbede3518d5625714926246cf438106222'
VQ76_WRAPPER_BLOB='751ae59d081be80c926e451505e22c77a39a77dc'
VQ76_INNER_BLOB='b5269247a8d5939a2c639239d8512451f9eca8b2'
VQ76_PREREG_BLOB='9ec4f4388c58b677bc1a40ebe58ae2579150fd2b'
VQ76_AUDIT_BLOB='f8c2cefd1e15938e9b0f84eceaa9913efa3134e0'

LIVE="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE" == "$CANONICAL" ]] || fail "live canonical drift expected=$CANONICAL actual=$LIVE"
git merge-base --is-ancestor "$CANONICAL" HEAD || fail 'F-PM19 is not descended from exact current canonical'
git diff --quiet "$CANONICAL"..HEAD -- src reference || fail 'F-PM19 changes production or reference source'
echo 'FPM19_EXACT_LIVE_CANONICAL_AND_AUDIT_ONLY_DELTA=PASS'

# Frozen denominator and closure authorities are immutable inputs.
[[ "$(git rev-parse "$PM13:integration/f-pm/F-PM13_DRAINAGE_V1_FINAL_COMPLETION.json")" == 'ce4dc39da4a97f070539896e9929f00c475d7ffa' ]] || fail 'F-PM13 denominator authority drift'
[[ "$(git rev-parse "$PM14:integration/f-pm/F-PM14_STATUS.json")" == 'b31714551ccd3f934d540d94c164d6eea822f6c1' ]] || fail 'F-PM14 status drift'
[[ "$(git rev-parse "$PM17:integration/f-pm/F-PM17_STATUS.json")" == 'ff7e444ad99271ea6daf7bde5be6c84896d1aeab' ]] || fail 'F-PM17 scope authority drift'
[[ "$(git rev-parse "$VQ73:integration/f-vq/F-VQ73_STATUS.json")" == 'c3bf68d2e885ec2f576e1400fcfb5d359806d319' ]] || fail 'F-VQ73 status drift'
[[ "$(git rev-parse "$VQ74:integration/f-vq/F-VQ74_STATUS.json")" == '6d11601f5d4929af801fdadd526bb4918281b6d2' ]] || fail 'F-VQ74 status drift'
[[ "$(git rev-parse "$VQ76:integration/f-vq/F-VQ76_STATUS.json")" == "$VQ76_STATUS_BLOB" ]] || fail 'F-VQ76 status drift'
[[ "$(git rev-parse "$VQ76:tests/fvq/run_fvq76_current_canonical_reconciled.sh")" == "$VQ76_WRAPPER_BLOB" ]] || fail 'F-VQ76 wrapper drift'
[[ "$(git rev-parse "$VQ76:tests/fvq/run_fvq76_drainage_post_fci62_preservation_requalification.sh")" == "$VQ76_INNER_BLOB" ]] || fail 'F-VQ76 executable gate drift'
[[ "$(git rev-parse "$VQ76:integration/f-vq/F-VQ76_PRE_REGISTRATION.json")" == "$VQ76_PREREG_BLOB" ]] || fail 'F-VQ76 preregistration drift'
[[ "$(git rev-parse "$VQ76:integration/f-vq/F-VQ76_ARCHITECTURE_AUDIT.json")" == "$VQ76_AUDIT_BLOB" ]] || fail 'F-VQ76 architecture audit drift'
echo 'FPM19_CORE_AUTHORITIES_EXACT=PASS'

# Scientific qualification authorities for every member of the eight-variant denominator.
declare -A SCI_STATUS=(
  [origin/qualification/f-vq44-fpm08a-linear-drainage:integration/f-vq/F-VQ44_STATUS.json]=cf7e97b5d1e2da76e92bf1e788e5fd05eb8a4b63
  [origin/qualification/f-vq47-fpm08br-spatial-distribution-requalification:integration/f-vq/F-VQ47_STATUS.json]=8fe7c3fb9db8e5e6c56098382b075c8b347ab8b1
  [origin/qualification/f-vq40-fpm08c1r-tabulated-drainage:integration/f-vq/F-VQ40_STATUS.json]=5142a33e7b6773254603b904d6e13623a8d1938d
  [origin/qualification/f-vq38-fpm08c2-hooghoudt-ernst:integration/f-vq/F-VQ38_STATUS.json]=2c451139bfc08c8dad829422f50653c326b5a573
  [origin/qualification/f-vq42-fpm08c3-empirical-interflow:integration/f-vq/F-VQ42_STATUS.json]=404db3d42997d40ce196ebfa501fc693f32c7310
  [origin/qualification/f-vq43-fpm08c4-multilevel-aggregation:integration/f-vq/F-VQ43_STATUS.json]=d2ca28908615e7a1536e91a7c8db8ea28d5733ed
  [origin/qualification/f-vq59-fpm08d7-fixed-weir-current-canonical:integration/f-vq/F-VQ59_STATUS.json]=bd0c5a2209112e3dad7aa37c23f96b53ab982da7
)
for spec in "${!SCI_STATUS[@]}"; do
  [[ "$(git rev-parse "$spec")" == "${SCI_STATUS[$spec]}" ]] || fail "scientific authority drift: $spec"
done
echo 'FPM19_ALL_FROZEN_VARIANT_SCIENTIFIC_AUTHORITIES_EXACT=PASS'

python3 - "$PM13" "$PM14" "$PM17" "$VQ73" "$VQ74" "$VQ76" <<'PY'
import json,subprocess,sys
pm13,pm14,pm17,vq73,vq74,vq76=sys.argv[1:]
def load(c,p): return json.loads(subprocess.check_output(['git','show',f'{c}:{p}'],text=True))
a=load(pm13,'integration/f-pm/F-PM13_DRAINAGE_V1_FINAL_COMPLETION.json')
o=load(pm14,'integration/f-pm/F-PM14_STATUS.json')
s=load(pm17,'integration/f-pm/F-PM17_STATUS.json')
v73=load(vq73,'integration/f-vq/F-VQ73_STATUS.json')
v74=load(vq74,'integration/f-vq/F-VQ74_STATUS.json')
v76=load(vq76,'integration/f-vq/F-VQ76_STATUS.json')
assert a['denominator']['changed'] is False and a['denominator']['scope_reduced'] is False
assert len(a['denominator']['frozen_variants']) == 8
assert [x['id'] for x in a['hard_blockers']] == ['G1_RUNTIME_COMPOSITION','G2_TRANSACTION_MASS_RESTART_MULTISWAP_DIAGNOSTICS','G3_CANONICAL_ADMISSION_PRESERVATION']
assert o['owner_qualified'] is True and o['preservation_qualified'] is True
assert s['decision']=='F_PM15_G1R_NOT_A_FROZEN_DRAINAGE_V1_EXIT_REQUIREMENT'
assert s['frozen_denominator_changed'] is False and s['scope_expanded_for_completion'] is False
assert s['fully_implicit_implementation_authorized'] is False
assert v73['decision']=='QUALIFIED_FPM14_DRAINAGE_RESPONSE_RUNTIME_INDEPENDENTLY' and v73['independently_qualified'] is True
assert v74['decision']=='QUALIFIED_DRAINAGE_V1_CROSS_CUTTING_G2_INDEPENDENTLY' and v74['independently_qualified'] is True
assert v76['decision']=='QUALIFIED_DRAINAGE_RUNTIME_PRESERVED_ON_F_CI62_POSTIMAGE_INDEPENDENTLY'
assert v76['current_canonical']['sha']=='6425fb3290da637357e47618b459f4caf65a78d8'
assert v76['current_canonical']['source_reference_bit_equivalent_to_preregistered_postimage'] is True
assert v76['architecture_invariants_1_30']=='PASS_ALL_QUALIFIED_OR_PRESERVED'
assert v76['independently_qualified'] is True and v76['mass_conservation_concession'] is False
print('FPM19_FIXED_DENOMINATOR_SCOPE_AND_RUNTIME_AUTHORITIES=PASS')
PY

# Canonical source-admission and preservation lineage must be exact.
[[ "$(git rev-list --parents -n1 "$FCI61")" == "$FCI61 e7b512cb4d7f400ed8e1d7aeb24f6dfe165ac557 0ac2f09642f71269ee43301cfedde4f2dd95ade6" ]] || fail 'F-CI61 merge lineage drift'
[[ "$(git rev-list --parents -n1 "$FCI61P")" == "$FCI61P $FCI61 537695a6194d22b19e28d2d9abfb0d80da42dd93" ]] || fail 'F-CI61P merge lineage drift'
[[ "$(git rev-list --parents -n1 "$FCI62")" == "$FCI62 $FCI61P 9745433b4ff7e6eb1337b58e0d861e73a9f1ade8" ]] || fail 'F-CI62 merge lineage drift'
[[ "$(git rev-list --parents -n1 "$CANONICAL")" == "$CANONICAL $FCI62 $FCI62P_SECOND_PARENT" ]] || fail 'F-CI62P merge lineage drift'
[[ "$(git rev-parse "$CANONICAL:integration/f-ci/F-CI62P_STATUS.json")" == 'a1151d1b37801db20b13054347dff2109726004b' ]] || fail 'F-CI62P status drift'
python3 - <<'PY'
import json
from pathlib import Path
s=json.loads(Path('integration/f-ci/F-CI62P_STATUS.json').read_text())
assert s['decision']=='QUALIFIED_F_CI62P_CURRENT_CANONICAL_POSTIMAGE_RECONCILIATION'
assert s['production_canonical_admitted'] is True
assert s['postimage_reconciled'] is True
assert s['moving_current_preservation_reconciled'] is True
assert s['production_reference_delta_in_reconciliation'] is False
print('FPM19_CANONICAL_ADMISSION_AND_MOVING_PRESERVATION=PASS')
PY

# Exact current protected production surface.
declare -A CURRENT_BLOBS=(
  [src/process/mod_drainage_empirical_interflow_response.f90]=eb53096b678d08b76d3fb1adb2247bc2a58ee748
  [src/process/mod_drainage_ernst_ipos45_preparation.f90]=fa1d5d400bb32be42e78889c0ff2a3bcab335142
  [src/process/mod_drainage_ernst_ipos45_response.f90]=b00ef0ae1f10182af2d0a8ea636d10b196e93379
  [src/process/mod_drainage_hooghoudt_equivalent_depth.f90]=6b7b2bb1fd259879d3f26c46abfc071ea2b2f108
  [src/process/mod_drainage_hooghoudt_ipos1_response.f90]=89f26e2d2b77bef5bdd0c5fdb2ce9ca1f03206fa
  [src/process/mod_drainage_hooghoudt_ipos23_response.f90]=5637ddb4d33141f00b4ebf737d1c7f7fe1824164
  [src/process/mod_drainage_multilevel_aggregation.f90]=70d35512ef7c5958f7e4bf284cba104a7b641fdb
  [src/process/mod_drainage_process.f90]=dbacd49da3bb0b94f822f9ee0478d15183e9c0fa
  [src/process/mod_drainage_tabulated_response.f90]=738f57c334910ab73bc8870e3aa8dda1c1a48c7a
  [src/runtime/mod_fmr_drainage_response_binding.f90]=76c2a2ea569a4e85e490ebd2e7fb89c28d8b3fb5
  [src/runtime/mod_fmr_serialized_reference_backend.f90]=21e0e4229f202f1a3a74c4da004aa32a2c855f03
  [src/process/mod_drainage_spatial_distribution.f90]=1f538174b7451aaa7a3c50d6078b7c1fc3ad8f5a
  [src/runtime/mod_fmr_divdra_serialized_runtime.f90]=9a384658ec37b68d2ef911e741aa89707dcb3e77
  [src/process/mod_restricted_fixed_weir_surface_water.f90]=16da4f6ec3d120b5a40f17ef04fb8faa457f4eaa
  [src/runtime/mod_fmr_fixed_weir_serialized_runtime.f90]=f81229c2f4ad766fb8606111ca965963ebba46fe
)
for p in "${!CURRENT_BLOBS[@]}"; do
  [[ "$(git rev-parse "HEAD:$p")" == "${CURRENT_BLOBS[$p]}" ]] || fail "current drainage dependency blob drift: $p"
done
echo 'FPM19_CURRENT_DRAINAGE_DEPENDENCY_SURFACE_EXACT=PASS'

# Machine-readable completion and architecture audits must agree and be fail-closed.
python3 - <<'PY'
import json
from pathlib import Path
c=json.loads(Path('integration/f-pm/F-PM19_DRAINAGE_V1_FINAL_COMPLETION.json').read_text())
a=json.loads(Path('integration/f-pm/F-PM19_ARCHITECTURE_AUDIT.json').read_text())
assert c['canonical']['sha']=='6425fb3290da637357e47618b459f4caf65a78d8'
assert c['frozen_denominator']['variant_count']==8 and len(c['frozen_denominator']['variants'])==8
assert c['frozen_denominator']['changed'] is False and c['frozen_denominator']['scope_reduced'] is False and c['frozen_denominator']['scope_expanded'] is False
assert len(c['variant_completion'])==8 and all(x['disposition']=='PASS_COMPLETE' for x in c['variant_completion'])
assert [x['id'] for x in c['blocker_reconciliation']]==['G1_RUNTIME_COMPOSITION','G2_TRANSACTION_MASS_RESTART_MULTISWAP_DIAGNOSTICS','G3_CANONICAL_ADMISSION_PRESERVATION']
assert all(x['status']=='CLOSED' for x in c['blocker_reconciliation'])
for k,v in c['completion_contract'].items():
    assert v is True, (k,v)
assert c['production_source_changed_by_F_PM19'] is False
assert c['reference_source_changed_by_F_PM19'] is False
assert c['mass_conservation_concession'] is False
assert c['drainage_v1_100_percent_complete'] is True
assert c['final_decision']=='QUALIFIED_DRAINAGE_V1_100_PERCENT_COMPLETE'
assert a['invariant_count']==30 and len(a['invariants'])==30
assert [x['id'] for x in a['invariants']]==list(range(1,31))
assert all(x['status'] in {'QUALIFIED','PRESERVED'} for x in a['invariants'])
assert a['all_invariants_pass_or_preserved'] is True and a['adverse_invariants']==[]
assert a['mass_conservation_concession'] is False
assert a['production_change'] is False and a['reference_change'] is False
assert a['scope_reduction'] is False and a['scope_expansion'] is False
assert a['fully_implicit_drainage_solver_coupling_added'] is False
assert a['assessment']=='PASS_FOR_FIXED_DENOMINATOR_DRAINAGE_V1_COMPLETION'
print('FPM19_MACHINE_READABLE_EIGHT_VARIANT_G1_G2_G3_AND_INVARIANTS=PASS')
PY

# Re-execute the exact independent F-VQ76 preservation gate from the PM19 head.
TMP_WRAPPER='tests/fvq/run_fvq76_current_canonical_reconciled.sh'
TMP_INNER='tests/fvq/run_fvq76_drainage_post_fci62_preservation_requalification.sh'
TMP_PREREG='integration/f-vq/F-VQ76_PRE_REGISTRATION.json'
TMP_AUDIT='integration/f-vq/F-VQ76_ARCHITECTURE_AUDIT.json'
[[ ! -e "$TMP_WRAPPER" && ! -e "$TMP_INNER" && ! -e "$TMP_PREREG" && ! -e "$TMP_AUDIT" ]] || fail 'temporary VQ76 materialization paths unexpectedly exist in canonical'
trap 'rm -f "$TMP_WRAPPER" "$TMP_INNER" "$TMP_PREREG" "$TMP_AUDIT" tests/fvq/.fvq76_reconciled_inner.sh tests/fpm/.fvq76_pm14_preservation.sh' EXIT
git show "$VQ76:$TMP_WRAPPER" > "$TMP_WRAPPER"
git show "$VQ76:$TMP_INNER" > "$TMP_INNER"
git show "$VQ76:$TMP_PREREG" > "$TMP_PREREG"
git show "$VQ76:$TMP_AUDIT" > "$TMP_AUDIT"
[[ "$(git hash-object "$TMP_WRAPPER")" == "$VQ76_WRAPPER_BLOB" ]] || fail 'materialized VQ76 wrapper differs'
[[ "$(git hash-object "$TMP_INNER")" == "$VQ76_INNER_BLOB" ]] || fail 'materialized VQ76 inner gate differs'
[[ "$(git hash-object "$TMP_PREREG")" == "$VQ76_PREREG_BLOB" ]] || fail 'materialized VQ76 preregistration differs'
[[ "$(git hash-object "$TMP_AUDIT")" == "$VQ76_AUDIT_BLOB" ]] || fail 'materialized VQ76 architecture audit differs'
chmod +x "$TMP_WRAPPER" "$TMP_INNER"
bash "$TMP_WRAPPER"
echo 'FPM19_INDEPENDENT_CURRENT_POSTIMAGE_EXECUTABLE_REPLAY=PASS'

git diff --check "$CANONICAL..HEAD"
echo "FPM19_EXACT_HEAD=$(git rev-parse HEAD)"
echo 'F-PM19 DRAINAGE V1 AUTHORITATIVE 100 PERCENT COMPLETION GATE=PASS'
