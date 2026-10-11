#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="ed0219402072f121856d82cb6068ab74c70f34d1"
cd "$ROOT"

fail() {
  echo "FCI21_CLOSEOUT_READINESS_FAIL $*" >&2
  exit 1
}

# First prove the current production postimage itself, not only archived evidence.
bash tests/fci/run_fci21_temporal_materialization_gate.sh
echo 'FCI21_CLOSEOUT_CURRENT_MATERIALIZATION_GATE=PASS'

cat > /tmp/fci21-closeout-expected-src.txt <<'EOF'
src/adapter/mod_reference_richards_legacy_binding.f90
src/runtime/mod_canonical_contracts.f90
src/runtime/mod_fmr_runtime_core.f90
src/runtime/mod_fmr_serialized_reference_backend.f90
src/solver/mod_fixed_flux_top_boundary_provider.f90
src/solver/mod_reference_richards_temporal_indicator.f90
src/solver/mod_soil_water_solver_contract.f90
src/transaction/mod_fkt_temporal_indicator_history.f90
EOF
git diff --name-only "$BASE"..HEAD -- src | sort > /tmp/fci21-closeout-actual-src.txt
diff -u /tmp/fci21-closeout-expected-src.txt /tmp/fci21-closeout-actual-src.txt || fail "src delta differs from frozen eight-path closure"
echo 'FCI21_CLOSEOUT_EXACT_EIGHT_PATH_SRC_DELTA=PASS'

if ! git diff --quiet "$BASE"..HEAD -- integration/f-ci/canonical-source-manifest.json; then
  fail "canonical-source-manifest.json changed inside F-CI21"
fi
echo 'FCI21_CLOSEOUT_CANONICAL_MANIFEST_UNCHANGED=PASS'

python3 - <<'PY'
import json
from pathlib import Path

root = Path('integration/f-ci')

def load(name):
    p = root / name
    if not p.is_file():
        raise SystemExit(f'FCI21_CLOSEOUT_READINESS_FAIL missing evidence {name}')
    return json.loads(p.read_text(encoding='utf-8'))

def req(cond, msg):
    if not cond:
        raise SystemExit('FCI21_CLOSEOUT_READINESS_FAIL ' + msg)

compile_q = load('F-CI21_MATERIALIZATION_COMPILE_QUALIFICATION.json')
si25 = load('F-CI21_SI25_SCIENTIFIC_REPLAY_EVIDENCE.json')
vq30 = load('F-CI21_VQ30_HELD_OUT_REPLAY_EVIDENCE.json')
vq31 = load('F-CI21_VQ31_TRANSACTION_HISTORY_REPLAY_EVIDENCE.json')
vq32 = load('F-CI21_VQ32_HEAD_BUDGET_NORMALIZATION_REPLAY_EVIDENCE.json')
vq33 = load('F-CI21_VQ33_FAILURE_KT11_REMEDIATION_RECONCILIATION.json')
vq34 = load('F-CI21_VQ34_REMEDIATED_CERTIFICATE_REPLAY_EVIDENCE.json')
pres = load('F-CI21_WOF42_MR18_PRESERVATION_EVIDENCE.json')
readiness = load('F-CI21_CLOSEOUT_READINESS.json')

req(compile_q.get('state') == 'MATERIALIZATION_COMPILE_QUALIFIED', 'compile qualification state')
req(compile_q.get('materialized_source', {}).get('production_delta_count') == 8, 'compile qualification production delta count')
req(compile_q.get('canonical_modified') is False, 'compile qualification canonical modified')
print('FCI21_CLOSEOUT_COMPILE_EVIDENCE=PASS')

req(si25.get('decision') == 'SI25_SCIENTIFIC_REPLAY_QUALIFIED_ON_WOF42_MATERIALIZED_POSTIMAGE', 'SI25 decision')
req(si25.get('results', {}).get('cases') == 15, 'SI25 case count')
req(si25.get('results', {}).get('owner_replay_pass') is True, 'SI25 owner replay')
req(si25.get('results', {}).get('owner_replay_max_abs_diff') == 0.0, 'SI25 exact owner replay')
req(si25.get('results', {}).get('additional_full_nonlinear_solves') == 0, 'SI25 nonlinear cost')
req(si25.get('results', {}).get('additional_defect_tridiagonal_solves') == 1, 'SI25 defect solve cost')
req(si25.get('canonical_modified') is False, 'SI25 canonical modified')
print('FCI21_CLOSEOUT_SI25_EVIDENCE=PASS')

req(vq30.get('status') == 'COMPLETE_QUALIFIED', 'VQ30 status')
req(vq30.get('decision') == 'VQ30_HELD_OUT_OPERATOR_REPLAY_QUALIFIED_ON_FCI21_MATERIALIZED_POSTIMAGE', 'VQ30 decision')
req(vq30.get('aggregate_results', {}).get('cases') == 16, 'VQ30 case count')
req(vq30.get('aggregate_results', {}).get('O0_cases_pass') == 16 and vq30.get('aggregate_results', {}).get('O2_cases_pass') == 16, 'VQ30 O0/O2 cases')
req(vq30.get('aggregate_results', {}).get('B_inf_replay_max_abs_diff') == 0.0, 'VQ30 exact B_inf replay')
req(vq30.get('aggregate_results', {}).get('max_candidate_mass_residual', 1.0) <= vq30.get('aggregate_results', {}).get('hard_mass_tolerance', 0.0), 'VQ30 hard mass')
req(vq30.get('aggregate_results', {}).get('additional_full_nonlinear_solves_per_indicator') == 0, 'VQ30 nonlinear cost')
print('FCI21_CLOSEOUT_VQ30_EVIDENCE=PASS')

req(vq31.get('replay_result') == 'PASS_MATERIALIZED_FVQ31_TRANSACTION_HISTORY_BEHAVIOR_PRESERVED', 'VQ31 result')
req(vq31.get('frozen_contract_replay', {}).get('disjoint_cases') == 12, 'VQ31 disjoint case count')
req(vq31.get('frozen_contract_replay', {}).get('frozen_fvq30_cases') == 16, 'VQ31 frozen VQ30 case count')
req(vq31.get('transaction_lifecycle', {}).get('clone_isolation') == 'PASS', 'VQ31 clone isolation')
req(vq31.get('transaction_lifecycle', {}).get('a_b_a_history_isolation') == 'PASS', 'VQ31 A-B-A history isolation')
req(vq31.get('real_richards_binding', {}).get('additional_full_nonlinear_trajectories') == 0, 'VQ31 nonlinear cost')
req(vq31.get('invariant_checks', {}).get('mass_conservation_hard_gate') == 'PASS', 'VQ31 mass gate')
print('FCI21_CLOSEOUT_VQ31_EVIDENCE=PASS')

cand32 = vq32.get('candidate_lock', {})
req(vq32.get('replay_result') == 'PASS_MATERIALIZED_FVQ32_HEAD_BUDGET_NORMALIZATION_BEHAVIOR_PRESERVED', 'VQ32 result')
req(cand32.get('formula') == 'C_h=B_inf/H_budget', 'VQ32 formula')
req(cand32.get('default_H_budget') is None, 'VQ32 default H_budget forbidden')
req(cand32.get('empirical_multiplier') is None, 'VQ32 empirical multiplier forbidden')
req(cand32.get('nonlinear_true_error_bound_claim') is False, 'VQ32 nonlinear true-error claim forbidden')
req(vq32.get('fresh_nonlinear_replay', {}).get('cases') == 12, 'VQ32 nonlinear case count')
req(vq32.get('invalid_input_semantics', {}).get('result') == 'PASS', 'VQ32 invalid input fail closed')
print('FCI21_CLOSEOUT_VQ32_EVIDENCE=PASS')

hist33 = vq33.get('historical_failed_authority', {})
interp33 = vq33.get('interpretation', {})
post33 = vq33.get('F_CI21_postimage_reconciliation', {})
req(vq33.get('decision') == 'PRESERVE_FVQ33_FAILURE_AND_REQUIRE_FVQ34_FOR_POSITIVE_REMEDIATED_QUALIFICATION', 'VQ33 reconciliation decision')
req(hist33.get('decision') == 'COMPLETE_FAIL_CLOSED_SOURCE_CONTRADICTION_NATIVE_INVALID_BUDGET_DIAGNOSTIC_NOT_PRESERVED', 'VQ33 failed decision')
req(hist33.get('must_remain_failed') is True, 'VQ33 must remain failed')
req(hist33.get('executable_cases_started') is False, 'VQ33 executable cases unexpectedly claimed')
req(interp33.get('F_VQ33_reinterpreted_as_pass') is False, 'VQ33 reinterpreted as pass')
req(interp33.get('old_candidate_allowed_as_positive_evidence') is False, 'VQ33 old candidate used positively')
req(post33.get('current_backend_is_rejected_F_VQ33_candidate') is False, 'rejected VQ33 backend materialized')
req(post33.get('current_backend_is_remediated_F_KT11_candidate') is True, 'remediated KT11 backend absent')
print('FCI21_CLOSEOUT_VQ33_NEGATIVE_SENTINEL=PASS')

neg34 = vq34.get('negative_evidence_lock', {})
pol34 = vq34.get('policy_semantics_preserved', {})
id34 = vq34.get('current_production_identity', {})
req(vq34.get('replay_result') == 'PASS_MATERIALIZED_FVQ34_REMEDIATED_CERTIFICATE_BEHAVIOR_PRESERVED', 'VQ34 result')
req(neg34.get('F_VQ33_remains_failed') is True, 'VQ34 lost VQ33 failure')
req(neg34.get('F_VQ33_used_as_positive_evidence') is False, 'VQ34 used VQ33 positively')
req(id34.get('matches_remediated_F_KT11_backend') is True and id34.get('matches_rejected_F_VQ33_backend') is False, 'VQ34 backend identity')
req(pol34.get('formula') == 'C_h=B_inf/H_budget', 'VQ34 formula')
req(pol34.get('explicit_budget_required') is True, 'VQ34 explicit budget')
req(pol34.get('budget_must_be_finite_positive') is True, 'VQ34 finite-positive budget')
req(pol34.get('default_H_budget') is None, 'VQ34 default H_budget forbidden')
req(pol34.get('invalid_native_value_retained_diagnostically') is True, 'VQ34 native invalid diagnostic')
req(pol34.get('mass_gate_precedes_certificate_gate') is True, 'VQ34 mass precedence')
req(pol34.get('certificate_rejection_preserves_committed_state') is True, 'VQ34 rollback')
req(pol34.get('shorter_dt_monotonicity_assumed') is False, 'VQ34 shorter-dt monotonicity claim')
req(pol34.get('B_inf_general_nonlinear_true_error_bound_claim') is False, 'VQ34 nonlinear true-error claim')
print('FCI21_CLOSEOUT_VQ34_REMEDIATED_POLICY=PASS')

req(pres.get('decision') == 'PASS_F_WOF42_AND_F_MR18_POSTIMAGE_PRESERVATION_ON_F_CI21', 'WOF42/MR18 preservation decision')
req(pres.get('production_scope', {}).get('exact_eight_path_delta') is True, 'preservation eight-path delta')
req(pres.get('production_scope', {}).get('production_source_changed_by_preservation_replay') is False, 'preservation changed source')
req(pres.get('F_WOF42_preservation', {}).get('direct_valid_layouts_exact') == 7, 'WOF42 valid layout count')
req(pres.get('F_WOF42_preservation', {}).get('invalid_layouts_fail_closed') == 6, 'WOF42 invalid layout count')
req(pres.get('F_WOF42_preservation', {}).get('external_representation_O0_O2_identity') == 'PASS', 'WOF42 O0/O2')
req(pres.get('F_MR18_authority_locks', {}).get('production_blobs_exact') is True, 'MR18 production blob lock')
req(pres.get('F_MR18_accepted_commit_receipt_preservation', {}).get('final_marker') == 'FMR18_ACCEPTED_COMMIT_RECEIPT_GATE PASS', 'MR18 A/B final')
req(pres.get('F_MR18_multiswap_preservation', {}).get('no_per_column_receipt_state') == 'PASS', 'MR18 no per-column receipt state')
req(pres.get('F_MR18_multiswap_preservation', {}).get('no_receipt_route_physical_and_mass_identity') == 'PASS', 'MR18 mass identity')
req(pres.get('F_MR18_multiswap_preservation', {}).get('final_marker') == 'FMR18_MULTISWAP_RECEIPT_GATE PASS', 'MR18 C final')
req(pres.get('materialization_translation_policy', {}).get('behavioral_oracles_modified') is False, 'preservation behavioral oracle changed')
print('FCI21_CLOSEOUT_WOF42_MR18_PRESERVATION=PASS')

boundary = readiness.get('closeout_boundary', {})
req(boundary.get('updates_canonical') is False, 'readiness permits canonical update')
req(boundary.get('requires_separate_canonical_admission') is True, 'separate canonical admission not required')
req(boundary.get('selects_application_head_budget') is False, 'application H_budget selected')
req(boundary.get('qualifies_general_nonlinear_error_bound') is False, 'general nonlinear error bound claimed')
req(readiness.get('state', {}).get('canonical_modified') is False, 'readiness says canonical modified')
print('FCI21_CLOSEOUT_SCOPE_BOUNDARY=PASS')
PY

# Explicit text sentinel: no F-CI21 evidence may silently flip the historical
# F-VQ33 failure to a positive qualification.
if grep -R --include='F-CI21_*.json' -E '"F_VQ33_reinterpreted_as_pass"[[:space:]]*:[[:space:]]*true|"F_VQ33_used_as_positive_evidence"[[:space:]]*:[[:space:]]*true' integration/f-ci; then
  fail "positive reinterpretation of F-VQ33 detected"
fi
echo 'FCI21_CLOSEOUT_VQ33_TEXT_SENTINEL=PASS'

echo 'FCI21_CLOSEOUT_READINESS_GATE PASS'
