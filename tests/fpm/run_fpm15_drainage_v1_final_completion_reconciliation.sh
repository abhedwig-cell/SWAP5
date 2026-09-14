#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="${TMPDIR:-/tmp}/swap5-fpm15-$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"; rm -f "$ROOT/tests/fvq/test_fvq73_fpm14_drainage_response_independent.f90" "$ROOT/tests/fvq/.fpm15_fvq73.sh" "$ROOT/tests/fvq/test_fvq74_drainage_cross_cutting_independent.f90" "$ROOT/tests/fvq/.fpm15_fvq74.sh" "$ROOT/tests/fpm/.fpm15_preservation.sh"' EXIT
cd "$ROOT"

fail(){ echo "FPM15_FINAL_COMPLETION_GATE_FAIL $*" >&2; exit 115; }
CANONICAL='e79b0272edb544ec4c8000a4d6869274f1ab3ae5'
PM13='e5cd87eafb95356ca0d5ef8399fcb64feae78fd2'
PM14='52c1a9aebddc435ef3792378f958305a96308ed0'
VQ73='ea40e2d850aa9b4b23b25ba6b4a63ffd39811001'
VQ73_TESTED='3dd8b92b9601f4e3e41cd9ff79a37dd293b35641'
VQ74='60c121a0993993bd79fb30ddfd54e2a9d14f042e'

# ---------------------------------------------------------------------------
# A. Audit purity and frozen denominator.
# ---------------------------------------------------------------------------
git merge-base --is-ancestor "$CANONICAL" HEAD || fail 'F-PM15 is not descended from frozen canonical base'
git diff --quiet "$CANONICAL"..HEAD -- src reference || fail 'F-PM15 changes production/reference source'
echo 'FPM15_AUDIT_ONLY_NO_PRODUCTION_REFERENCE_CHANGE=PASS'

[[ "$(git rev-parse "$PM13:integration/f-pm/F-PM13_DRAINAGE_V1_FINAL_COMPLETION.json")" == 'ce4dc39da4a97f070539896e9929f00c475d7ffa' ]] || fail 'PM13 denominator authority drift'
[[ "$(git rev-parse "$PM14:integration/f-pm/F-PM14_STATUS.json")" == 'b31714551ccd3f934d540d94c164d6eea822f6c1' ]] || fail 'PM14 status drift'
[[ "$(git rev-parse "$PM14:integration/f-pm/F-PM14_ARCHITECTURE_AUDIT.json")" == '518d171e608c4a6320d2bdd4d3825015d4298f67' ]] || fail 'PM14 audit drift'
[[ "$(git rev-parse "$VQ73:integration/f-vq/F-VQ73_STATUS.json")" == 'c3bf68d2e885ec2f576e1400fcfb5d359806d319' ]] || fail 'VQ73 status drift'
[[ "$(git rev-parse "$VQ74:integration/f-vq/F-VQ74_STATUS.json")" == '6d11601f5d4929af801fdadd526bb4918281b6d2' ]] || fail 'VQ74 status drift'
[[ "$(git rev-parse "HEAD:integration/f-ci/F-CI61_STATUS.json")" == 'b15d2916e6db6125bceaf6688ca616825e5f9d19' ]] || fail 'F-CI61 status drift on canonical postimage'
[[ "$(git rev-parse "HEAD:integration/f-ci/F-CI61P_STATUS.json")" == '8905f5c1a665fa99708ebb39116b76e0c2a3d153' ]] || fail 'F-CI61P status drift on canonical postimage'

echo 'FPM15_AUTHORITY_BLOBS_EXACT=PASS'

python3 - "$PM13" "$PM14" "$VQ73" "$VQ74" <<'PY'
import json,subprocess,sys
pm13,pm14,vq73,vq74=sys.argv[1:]
def load(sha,path):
    return json.loads(subprocess.check_output(['git','show',f'{sha}:{path}'],text=True))
a=load(pm13,'integration/f-pm/F-PM13_DRAINAGE_V1_FINAL_COMPLETION.json')
o=load(pm14,'integration/f-pm/F-PM14_STATUS.json')
v73=load(vq73,'integration/f-vq/F-VQ73_STATUS.json')
v74=load(vq74,'integration/f-vq/F-VQ74_STATUS.json')
assert a['denominator']['changed'] is False and a['denominator']['scope_reduced'] is False
assert len(a['denominator']['frozen_variants']) == 8
assert [x['id'] for x in a['hard_blockers']] == ['G1_RUNTIME_COMPOSITION','G2_TRANSACTION_MASS_RESTART_MULTISWAP_DIAGNOSTICS','G3_CANONICAL_ADMISSION_PRESERVATION']
assert o['owner_qualified'] is True and o['preservation_qualified'] is True
assert v73['independently_qualified'] is True and v73['decision']=='QUALIFIED_FPM14_DRAINAGE_RESPONSE_RUNTIME_INDEPENDENTLY'
assert v74['independently_qualified'] is True and v74['closed'] is True
assert v74['decision']=='QUALIFIED_DRAINAGE_V1_CROSS_CUTTING_G2_INDEPENDENTLY'
print('FPM15_PM13_DENOMINATOR_UNCHANGED=PASS')
print('FPM15_G2_TRANSACTION_MASS_RESTART_MULTISWAP_DIAGNOSTICS_EVIDENCE_CHAIN=PASS')
PY

# ---------------------------------------------------------------------------
# B. Exact admitted production postimage and preserved legacy-admitted routes.
# ---------------------------------------------------------------------------
declare -A RESPONSE_BLOBS=(
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
  [src/runtime/mod_fmr_serialized_reference_backend.f90]=0f09c0df1559ece894356b146b64d872470c0a32
)
for p in "${!RESPONSE_BLOBS[@]}"; do
  [[ "$(git rev-parse "HEAD:$p")" == "${RESPONSE_BLOBS[$p]}" ]] || fail "admitted response blob drift: $p"
done
[[ "$(git rev-parse HEAD:src/process/mod_drainage_spatial_distribution.f90)" == '1f538174b7451aaa7a3c50d6078b7c1fc3ad8f5a' ]] || fail 'DIVDRA process blob drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_divdra_serialized_runtime.f90)" == '9a384658ec37b68d2ef911e741aa89707dcb3e77' ]] || fail 'DIVDRA active runtime blob drift'
[[ "$(git rev-parse HEAD:src/process/mod_restricted_fixed_weir_surface_water.f90)" == '16da4f6ec3d120b5a40f17ef04fb8faa457f4eaa' ]] || fail 'fixed-weir process blob drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_fixed_weir_serialized_runtime.f90)" == 'f81229c2f4ad766fb8606111ca965963ebba46fe' ]] || fail 'fixed-weir runtime blob drift'
echo 'FPM15_CURRENT_CANONICAL_DRAINAGE_BLOBS_EXACT=PASS'

# Source-admission and preservation are actual history, not inferred from old pre-promotion status booleans.
parents61="$(git rev-list --parents -n1 eb2b2b17b2d54eeab22c4cba922426d8168e56a9)"
[[ "$parents61" == 'eb2b2b17b2d54eeab22c4cba922426d8168e56a9 e7b512cb4d7f400ed8e1d7aeb24f6dfe165ac557 0ac2f09642f71269ee43301cfedde4f2dd95ade6' ]] || fail 'F-CI61 admission merge parents drift'
parents61p="$(git rev-list --parents -n1 "$CANONICAL")"
[[ "$parents61p" == "$CANONICAL eb2b2b17b2d54eeab22c4cba922426d8168e56a9 537695a6194d22b19e28d2d9abfb0d80da42dd93" ]] || fail 'F-CI61P preservation merge parents drift'
echo 'FPM15_G3_CANONICAL_ADMISSION_PRESERVATION_HISTORY=PASS'

# ---------------------------------------------------------------------------
# C. Fail-closed scientific-hold reconciliation: prove the remaining G1R gap.
# ---------------------------------------------------------------------------
for spec in \
  'origin/qualification/f-vq38-fpm08c2-hooghoudt-ernst:integration/f-vq/F-VQ38_STATUS.json:2c451139bfc08c8dad829422f50653c326b5a573' \
  'origin/qualification/f-vq40-fpm08c1r-tabulated-drainage:integration/f-vq/F-VQ40_STATUS.json:5142a33e7b6773254603b904d6e13623a8d1938d' \
  'origin/qualification/f-vq42-fpm08c3-empirical-interflow:integration/f-vq/F-VQ42_STATUS.json:404db3d42997d40ce196ebfa501fc693f32c7310' \
  'origin/qualification/f-vq43-fpm08c4-multilevel-aggregation:integration/f-vq/F-VQ43_STATUS.json:d2ca28908615e7a1536e91a7c8db8ea28d5733ed' \
  'origin/qualification/f-vq44-fpm08a-linear-drainage:integration/f-vq/F-VQ44_STATUS.json:cf7e97b5d1e2da76e92bf1e788e5fd05eb8a4b63'; do
  ref="${spec%%:*}"; rest="${spec#*:}"; path="${rest%:*}"; blob="${rest##*:}"
  [[ "$(git rev-parse "$ref:$path")" == "$blob" ]] || fail "scientific authority drift: $path"
done

python3 - <<'PY'
from pathlib import Path
import json,subprocess

def load(ref,path):
    return json.loads(subprocess.check_output(['git','show',f'{ref}:{path}'],text=True))
v38=load('origin/qualification/f-vq38-fpm08c2-hooghoudt-ernst','integration/f-vq/F-VQ38_STATUS.json')
v40=load('origin/qualification/f-vq40-fpm08c1r-tabulated-drainage','integration/f-vq/F-VQ40_STATUS.json')
v43=load('origin/qualification/f-vq43-fpm08c4-multilevel-aggregation','integration/f-vq/F-VQ43_STATUS.json')
v44=load('origin/qualification/f-vq44-fpm08a-linear-drainage','integration/f-vq/F-VQ44_STATUS.json')
assert 'No solver Jacobian chain-rule or fully implicit drainage qualification.' in v38['holds']
assert 'No solver Jacobian assembly is qualified here.' in v40['holds']
assert v43['qualified_scope']['solver_Jacobian'] is False
assert v44['scope_holds']['fully_implicit_solver_coupling_qualified'] is False

contract=Path('src/solver/mod_soil_water_solver_contract.f90').read_text()
provider=Path('src/solver/mod_b110_source_sink_provider.f90').read_text()
backend=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
binding=Path('src/runtime/mod_fmr_drainage_response_binding.f90').read_text()

sig='subroutine source_sink_evaluate_ifc(self, pressure_head, water_content, source, sink)'
assert sig in contract
iface=contract[contract.index(sig):contract.index('end subroutine source_sink_evaluate_ifc',contract.index(sig))]
assert 'deriv' not in iface.lower() and 'jacob' not in iface.lower() and 'tangent' not in iface.lower()

peval=provider[provider.index('subroutine b110_source_sink_evaluate'):provider.index('end subroutine b110_source_sink_evaluate')]
assert 'sink = sink + self%drainage_flux_by_level(level,:)' in peval
assert 'dq_dgroundwater_level' not in peval and 'derivative' not in peval.lower()

resp='call evaluate_fmr_drainage_response_bottom_lumped'
solve='call self%solver%solve'
assert resp in backend and solve in backend and backend.index(resp) < backend.index(solve)
segment=backend[backend.index(resp):backend.index(solve)]
assert 'hydraulic_start' in segment
assert 'bind_b110_source_sink_provider' in segment
assert 'dq_dgroundwater_level' not in segment
assert 'derivative_defined' not in segment
assert 'real(real64) :: dq_dgroundwater_level' in binding
assert 'logical :: derivative_defined' in binding

print('FPM15_SCIENTIFIC_FULLY_IMPLICIT_HOLDS_STILL_EXPLICIT=PASS')
print('FPM15_SOURCE_SINK_ABI_IS_FLUX_ONLY=PASS')
print('FPM15_RESPONSE_EVALUATED_FROM_HYDRAULIC_START_BEFORE_SOLVE=PASS')
print('FPM15_RESPONSE_DERIVATIVE_NOT_PROPAGATED_TO_SOLVER_JACOBIAN=PASS')
print('FPM15_G1R_REAL_SOFTWARE_QUALIFICATION_GAP=PASS')
PY

# ---------------------------------------------------------------------------
# D. Parse the F-PM15 audit products. 100% must remain false while G1R is open.
# ---------------------------------------------------------------------------
python3 - <<'PY'
import json
from pathlib import Path
c=json.loads(Path('integration/f-pm/F-PM15_DRAINAGE_V1_FINAL_COMPLETION.json').read_text())
a=json.loads(Path('integration/f-pm/F-PM15_ARCHITECTURE_AUDIT.json').read_text())
assert c['denominator']['changed'] is False and c['denominator']['scope_reduced'] is False
assert len(c['denominator']['variants']) == 8
by={x['id']:x for x in c['original_pm13_blocker_reconciliation']}
assert by['G1_RUNTIME_COMPOSITION']['status']=='PARTIAL_CLOSED_REMAINDER_IDENTIFIED'
assert by['G2_TRANSACTION_MASS_RESTART_MULTISWAP_DIAGNOSTICS']['status']=='CLOSED'
assert by['G3_CANONICAL_ADMISSION_PRESERVATION']['status']=='CLOSED'
assert c['remaining_gap']['id']=='G1R_FULLY_IMPLICIT_DRAINAGE_RESPONSE_SOLVER_COUPLING'
assert c['remaining_gap']['class']=='REAL_SOFTWARE_AND_INDEPENDENT_QUALIFICATION_CLOSURE_GAP'
assert c['hundred_percent_complete'] is False
assert c['final_decision']=='DRAINAGE_V1_FINAL_CLOSURE_GAPS_REMAIN'
assert a['invariant_count']==30 and len(a['invariants'])==30
assert [x['id'] for x in a['invariants']]==list(range(1,31))
assert a['all_invariants_nonadverse'] is True
assert a['mass_conservation_concession'] is False
assert a['scope_reduction'] is False
assert a['hundred_percent_complete'] is False
assert a['completion_blocker']=='G1R_FULLY_IMPLICIT_DRAINAGE_RESPONSE_SOLVER_COUPLING'
print('FPM15_FINAL_ASSESSMENT_FAIL_CLOSED_CONSISTENT=PASS')
print('FPM15_ARCHITECTURE_INVARIANTS_1_30_RECONCILED=PASS')
PY

# ---------------------------------------------------------------------------
# E. Replay already-closed behavioral evidence against this exact postimage.
# ---------------------------------------------------------------------------
git show "$VQ73_TESTED:tests/fvq/test_fvq73_fpm14_drainage_response_independent.f90" > tests/fvq/test_fvq73_fpm14_drainage_response_independent.f90
git show "$VQ73_TESTED:tests/fvq/run_fvq73_independent_runtime.sh" > tests/fvq/.fpm15_fvq73.sh
chmod +x tests/fvq/.fpm15_fvq73.sh
bash tests/fvq/.fpm15_fvq73.sh > "$TMP/vq73.log" 2>&1 || { cat "$TMP/vq73.log" >&2; fail 'VQ73 current-postimage replay'; }
grep -Fq 'FVQ73_INDEPENDENT_RUNTIME_GATE=PASS' "$TMP/vq73.log" || fail 'VQ73 replay marker'
echo 'FPM15_VQ73_CURRENT_POSTIMAGE_REPLAY=PASS'
rm -f tests/fvq/test_fvq73_fpm14_drainage_response_independent.f90 tests/fvq/.fpm15_fvq73.sh

git show "$VQ74:tests/fvq/test_fvq74_drainage_cross_cutting_independent.f90" > tests/fvq/test_fvq74_drainage_cross_cutting_independent.f90
git show "$VQ74:tests/fvq/run_fvq74_drainage_cross_cutting_independent.sh" > tests/fvq/.fpm15_fvq74.sh
chmod +x tests/fvq/.fpm15_fvq74.sh
bash tests/fvq/.fpm15_fvq74.sh > "$TMP/vq74.log" 2>&1 || { cat "$TMP/vq74.log" >&2; fail 'VQ74 current-postimage replay'; }
grep -Fq 'FVQ74_DRAINAGE_CROSS_CUTTING_GATE=PASS' "$TMP/vq74.log" || fail 'VQ74 replay marker'
echo 'FPM15_VQ74_CURRENT_POSTIMAGE_REPLAY=PASS'
rm -f tests/fvq/test_fvq74_drainage_cross_cutting_independent.f90 tests/fvq/.fpm15_fvq74.sh

git show "$PM14:tests/fpm/run_fpm14_precomputed_divdra_fixed_weir_preservation.sh" > tests/fpm/.fpm15_preservation.sh
chmod +x tests/fpm/.fpm15_preservation.sh
bash tests/fpm/.fpm15_preservation.sh > "$TMP/preservation.log" 2>&1 || { cat "$TMP/preservation.log" >&2; fail 'DIVDRA/fixed-weir preservation replay'; }
grep -Fq 'FPM14_PRECOMPUTED_DIVDRA_FIXED_WEIR_PRESERVATION_GATE=PASS' "$TMP/preservation.log" || fail 'preservation replay marker'
echo 'FPM15_DIVDRA_FIXED_WEIR_CURRENT_POSTIMAGE_REPLAY=PASS'
rm -f tests/fpm/.fpm15_preservation.sh

git diff --check "$CANONICAL"..HEAD
echo 'FPM15_DRAINAGE_V1_FINAL_COMPLETION_RECONCILIATION_GATE=PASS'
