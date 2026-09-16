#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GOV_CANON='992a5c657bfe10a10100f92e0cb77c4825ae65b6'
GOV_TREE='dec751ba5182fd9ceee86568020090952d118fae'
SCI_CANON='50346642bd565f79134ea17d5462e544b354998c'
SCI_TREE='3b085d7dea3d3f3fce42ad9d8f259a8350205846'
POST_GC28='3baf2aa135e3bf257942d9e6c5928990c2d1b2e1'
FGC28_CLOSE='4c545af6f212fa4e95a27b9444ab3b01c277ff0b'
PE11_CLOSE='f928f309d21c18679977cc3d2c4a76f7c3be04c6'
PE11_META='00d735939cb4a8da8b027b20b7dd25725cd73526'
SNOW_VQ='25d83778dcade34225b4630059fd43142f95193d'
FVQ65='b1fd9e15a22d4dd68997ec38c074ce343eec0a70'
VQ73='ea40e2d850aa9b4b23b25ba6b4a63ffd39811001'
VQ74='60c121a0993993bd79fb30ddfd54e2a9d14f042e'

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-status-a-v2-${GITHUB_RUN_ID:-local}-$$"
rm -rf "$BUILD"; mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "STATUS_A_V2_FAIL $*" >&2; exit 196; }
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

# 1. Exact current governance boundary and unchanged scientific product image.
LIVE="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE" == "$GOV_CANON" ]] || fail "canonical moved expected=$GOV_CANON actual=$LIVE"
[[ "$(git rev-parse "$GOV_CANON^{tree}")" == "$GOV_TREE" ]] || fail 'governance tree mismatch'
[[ "$(git rev-parse "$SCI_CANON^{tree}")" == "$SCI_TREE" ]] || fail 'scientific tree mismatch'
git merge-base --is-ancestor "$GOV_CANON" HEAD || fail 'qualification head not descended from governance canonical'
git diff --quiet "$GOV_CANON"..HEAD -- src reference || fail 'qualification branch modifies production/reference'
[[ -z "$(git diff --name-only "$SCI_CANON".."$GOV_CANON" -- src reference)" ]] || fail 'Status-A admission changed production/reference'
changed="$(git diff --name-only "$SCI_CANON".."$GOV_CANON")"
[[ "$changed" == 'tests/qualification/status-a-baseline-20260916/STATUS_A_RELEASE_READINESS_BASELINE.md' ]] || fail 'unexpected post-scientific governance delta'
echo 'STATUS_A_V2_BOUNDARY_AND_ZERO_PRODUCTION_DELTA=PASS'

# Since post-F-GC28 the only production/reference delta is admitted WOFOST81.
actual="$(git diff --name-only "$POST_GC28".."$SCI_CANON" -- src reference | sort)"
expected="$(printf '%s\n' src/runtime/mod_fmr_wofost81_crop_event_lifecycle.f90 src/runtime/mod_fmr_wofost81_crop_transaction.f90 | sort)"
[[ "$actual" == "$expected" ]] || fail 'unexpected post-F-GC28 production/reference dependency delta'
echo 'STATUS_A_V2_POST_GC28_DELTA_IS_WOFOST81_ONLY=PASS'

# 2. Immutable close authorities and exact source locks for inherited scopes.
for c in "$FGC28_CLOSE" "$PE11_CLOSE" "$PE11_META" "$SNOW_VQ" "$FVQ65" "$VQ73" "$VQ74"; do git cat-file -e "$c^{commit}" || fail "missing authority $c"; done
python3 - "$FGC28_CLOSE" <<'PY'
import json,subprocess,sys
c=sys.argv[1]
d=json.loads(subprocess.check_output(['git','show',f'{c}:integration/f-gc/F-GC28_CLOSEOUT.json'],text=True))
assert d['verdict']=='CLOSED_CANONICAL_ADMITTED'
assert d['qualify']['verdict']=='INDEPENDENTLY_QUALIFIED_GROUNDWATER_COUPLING_V1_COMPLETION_AUDIT'
for p,want in d['admitted_production_blobs'].items():
    got=subprocess.check_output(['git','rev-parse',f'HEAD:{p}'],text=True).strip()
    assert got==want,(p,want,got)
print('STATUS_A_V2_GROUNDWATER_V1_BLOBS=PASS')
PY
[[ "$(git rev-parse HEAD:src/process/mod_snow_process.f90)" == '54702d71b4c84dce2842813549bd14c57301a383' ]] || fail 'Snow process drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == '9b4d6f7d6b63d66fe2e46eb9c46d70d08e32db13' ]] || fail 'Snow/current serialized backend drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_multiswap_runtime.f90)" == '1aa2454048d0e480becaee34f596f20f1a7bd66e' ]] || fail 'Snow/current serialized MultiSWAP drift'
echo 'STATUS_A_V2_SNOW_CURRENT_SOURCE_LOCKS=PASS'
python3 - "$PE11_CLOSE" "$PE11_META" "$SCI_CANON" <<'PY'
import json,subprocess,sys
close,meta,canon=sys.argv[1:]
# Formal closeout must exist and be a successful NO_OP closure.
files=subprocess.check_output(['git','show','--name-only','--format=',close],text=True)
assert 'src/' not in files and 'reference/' not in files
m=json.loads(subprocess.check_output(['git','show',f'{meta}:integration/f-pe/F-PE11_CLOSE_CHECKPOINT.json'],text=True))
assert m['canonical']['post_close_live_head']==canon
p=m['canonical']['post_close_delta_from_qualified_head']
assert p['production_source_changed'] is False
assert p['reference_source_changed'] is False
assert p['FPE11_relevant_dependency_changed'] is False
assert p['requalification_required'] is False
print('STATUS_A_V2_PE11_NOOP_CURRENT_HEAD_PRESERVATION=PASS')
PY
[[ "$(git rev-parse HEAD:testbank/runners/run_ftb11_current_source_replays.sh)" == 'fbfd57f20feae026feeea821043787b83ed35a43' ]] || fail 'FTB11 runner drift'
[[ "$(git rev-parse HEAD:testbank/runners/run_ftb12_drainage_v1_permanent_preservation.sh)" == '99c7ad975b137bad5b46df48b3916881350b6bb1' ]] || fail 'FTB12 runner drift'
[[ "$(git rev-parse HEAD:testbank/runners/run_ftb12p_postimage_reconciliation.sh)" == '4caee39a8874a93060f1de05699036115fc63c4b' ]] || fail 'FTB12P runner drift'
echo 'STATUS_A_V2_PERMANENT_TESTBANK_AUTHORITIES=PASS'

# 3. Independent mass-completeness attack matrix on exact current transaction source.
git show "$FVQ65:tests/fvq/mod_fvq65_mass_attack_support.f90" > "$BUILD/mass_support.f90"
git show "$FVQ65:tests/fvq/test_fvq65_mass_fail_closed.f90" > "$BUILD/mass_test.f90"
for opt in 0 2; do
  out="$BUILD/mass-o$opt"; mkdir -p "$out"
  gfortran "${COMMON[@]}" -O"$opt" -J"$out" -I"$out" -c src/transaction/mod_transaction_reference.f90 -o "$out/tx.o"
  gfortran "${COMMON[@]}" -O"$opt" -J"$out" -I"$out" -c "$BUILD/mass_support.f90" -o "$out/s.o"
  gfortran "${COMMON[@]}" -O"$opt" -J"$out" -I"$out" -c "$BUILD/mass_test.f90" -o "$out/t.o"
  gfortran -O"$opt" "$out/tx.o" "$out/s.o" "$out/t.o" -o "$out/test"
  "$out/test" > "$out/out.txt"
  grep -Fq 'FVQ65_INDEPENDENT_MASS_COMPLETENESS_ATTACK_MATRIX=PASS' "$out/out.txt" || fail "mass O$opt"
done
cmp -s "$BUILD/mass-o0/out.txt" "$BUILD/mass-o2/out.txt" || fail 'mass O0/O2 drift'
echo 'STATUS_A_V2_TRANSACTION_MASS_O0_O2=PASS'

# 4. Current-source solver/trajectory and serialized-runtime gates. These are
# narrow current gates and deliberately do not execute EB or parallel real physics.
bash tests/fkt/run_fkt21_qualification.sh
bash tests/fkt/run_fkt22_fmr_compile_gate.sh
bash tests/fkt/run_fkt22_fmr_runtime_gate.sh
echo 'STATUS_A_V2_CURRENT_SOLVER_SERIALIZED_RUNTIME=PASS'

# 5. Restart and serialized MultiSWAP composition on current source.
# F-GC24 performs true export/restore split equivalence. F-GC25 executes only
# deterministic serialized tile composition; it is not concurrent real physics.
bash tests/fgc/run_fgc24_coupled_restart_split_process_gate.sh
bash tests/fgc/run_fgc25_multiswap_groundwater_composition_gate.sh
echo 'STATUS_A_V2_RESTART_AND_SERIALIZED_MULTISWAP=PASS'

# 6. Drainage v1 independent frozen oracles rebuilt against current source.
git show "$VQ73:tests/fvq/test_fvq73_fpm14_drainage_response_independent.f90" > "$BUILD/vq73.f90"
git show "$VQ74:tests/fvq/test_fvq74_drainage_cross_cutting_independent.f90" > "$BUILD/vq74.f90"
[[ "$(git hash-object "$BUILD/vq73.f90")" == 'e7008eda5f29ee2e401cb3eb8a1b1523da3bc25a' ]] || fail 'VQ73 oracle drift'
[[ "$(git hash-object "$BUILD/vq74.f90")" == 'dabe53d0714abee8e87b2e90f89c2eed169506e0' ]] || fail 'VQ74 oracle drift'
DRAIN_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/runtime/mod_fmr_top_sensible_boundary_carrier.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_drainage_process.f90
  src/process/mod_drainage_tabulated_response.f90
  src/process/mod_drainage_hooghoudt_equivalent_depth.f90
  src/process/mod_drainage_hooghoudt_ipos1_response.f90
  src/process/mod_drainage_hooghoudt_ipos23_response.f90
  src/process/mod_drainage_ernst_ipos45_preparation.f90
  src/process/mod_drainage_ernst_ipos45_response.f90
  src/process/mod_drainage_empirical_interflow_response.f90
  src/process/mod_drainage_multilevel_aggregation.f90
  src/runtime/mod_fmr_drainage_response_binding.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
  src/process/mod_snow_process.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)
for opt in 0 2; do
  out="$BUILD/drain-o$opt"; mkdir -p "$out"; objs=()
  for source in "${DRAIN_SRC[@]}"; do
    obj="$out/$(printf '%s' "$source" | sha256sum | cut -c1-16).o"
    gfortran "${COMMON[@]}" -O"$opt" -J"$out" -I"$out" -c "$source" -o "$obj" || fail "drain compile O$opt $source"
    objs+=("$obj")
  done
  for n in 73 74; do
    gfortran "${COMMON[@]}" -O"$opt" -J"$out" -I"$out" -c "$BUILD/vq$n.f90" -o "$out/vq$n.o"
    gfortran -O"$opt" "${objs[@]}" "$out/vq$n.o" -o "$out/vq$n"
    "$out/vq$n" > "$out/vq$n.txt" 2>&1 || { cat "$out/vq$n.txt" >&2; fail "VQ$n O$opt"; }
  done
  grep -Fxq 'FVQ73_FPM14_DRAINAGE_RESPONSE_INDEPENDENT_RUNTIME=PASS' "$out/vq73.txt" || fail "VQ73 marker O$opt"
  grep -Fxq 'FVQ74_DRAINAGE_CROSS_CUTTING_INDEPENDENT=PASS' "$out/vq74.txt" || fail "VQ74 marker O$opt"
done
cmp -s "$BUILD/drain-o0/vq73.txt" "$BUILD/drain-o2/vq73.txt" || fail 'VQ73 O0/O2 drift'
cmp -s "$BUILD/drain-o0/vq74.txt" "$BUILD/drain-o2/vq74.txt" || fail 'VQ74 O0/O2 drift'
echo 'STATUS_A_V2_DRAINAGE_INDEPENDENT_O0_O2=PASS'

# 7. WOFOST81 is the only post-F-GC28 production delta, so replay its admitted
# scientific/runtime scope rather than inherit it merely from hashes.
bash tests/fwof/pp03/run_fwof_pp03_runtime_activation_gate.sh
bash tests/fwof/pp03/run_fwof38_fwof39_current_contract_preservation.sh
echo 'STATUS_A_V2_WOFOST81_FULL_ADMITTED_REPLAY=PASS'

# 8. Exit race and branch-integrity check.
LIVE_END="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE_END" == "$GOV_CANON" ]] || fail "canonical moved during replay expected=$GOV_CANON actual=$LIVE_END"
git diff --quiet "$GOV_CANON"..HEAD -- src reference || fail 'production/reference changed in qualification branch'
git diff --check "$GOV_CANON"..HEAD

echo "STATUS_A_V2_GOVERNANCE_CANONICAL=$GOV_CANON"
echo "STATUS_A_V2_GOVERNANCE_TREE=$GOV_TREE"
echo "STATUS_A_V2_SCIENTIFIC_BASE=$SCI_CANON"
echo "STATUS_A_V2_SCIENTIFIC_TREE=$SCI_TREE"
echo 'STATUS_A_V2_EXCLUDED_EB=PASS_NOT_RUN'
echo 'STATUS_A_V2_EXCLUDED_ROSS=PASS_NOT_RUN'
echo 'STATUS_A_V2_EXCLUDED_PARALLEL_REAL_PHYSICS=PASS_NOT_RUN'
echo 'STATUS_A_20260916_RELEASE_QUALIFICATION_V2=PASS'
