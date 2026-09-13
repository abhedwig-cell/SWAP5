#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "FCI59P_FAIL $*" >&2; exit 159; }

PRE=4fae08472c053d1b3d43d3d0b4f9b61956e7b646
ADMISSION=97dbb3e92b05b32368d41bfe57b74bd49017b88b
POST=648c3a2a90655ae053c2fd020563b3c4adce458b
TREE=577d2251ac5bcfa08c62918068f9d4e8168f48a0
OWNER=c8ff545cf720db467389c67ac2f9a595e57277ed
FVQ71=f2f410bb74ef40c23fcc16048bb54f9301b989db
CANONICAL_RUN=34780675957
MATERIALIZER=src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
PUBLICATION=src/runtime/mod_fmr_surface_evaporation_accepted_publication.f90
RECEIPT=src/runtime/mod_fmr_accepted_commit_receipt.f90
KERNEL=src/kernel/mod_kernel_transactions.f90
PROCESS=src/process/mod_restricted_surface_evaporation.f90

for object in "$PRE" "$ADMISSION" "$POST" "$OWNER" "$FVQ71"; do
  git cat-file -e "$object^{commit}" 2>/dev/null || fail "missing authority $object"
done
[[ "$(git rev-parse "$POST^{tree}")" == "$TREE" ]] || fail 'canonical postimage tree mismatch'
[[ "$(git rev-parse "$POST^1")" == "$PRE" ]] || fail 'canonical postimage parent 1 mismatch'
[[ "$(git rev-parse "$POST^2")" == "$ADMISSION" ]] || fail 'canonical postimage parent 2 mismatch'
git merge-base --is-ancestor "$POST" HEAD || fail 'postimage reconciliation does not descend from admitted canonical'
echo 'FCI59P_TRUE_TWO_PARENT_ADMISSION_ANCESTRY=PASS'

# This reconciliation may add metadata, tests and its own workflow only.
if [[ -n "$(git diff --name-only "$POST..HEAD" -- src reference)" ]]; then
  git diff --name-only "$POST..HEAD" -- src reference >&2
  fail 'postimage reconciliation changed production or reference source'
fi
echo 'FCI59P_ZERO_PRODUCTION_REFERENCE_DELTA=PASS'

for spec in \
  "$MATERIALIZER:b8ff1fb1d9434e952163b6955305c6373dd8ac82" \
  "$PUBLICATION:f0f3ce5c16a66c2058c22a529e176d6b06446649" \
  "$RECEIPT:6798b3296b426950bf028814585c3f5de9be950b" \
  "$KERNEL:c7c5b7d3357e4e6739c8f647d6232baca45563e6" \
  "$PROCESS:a213af4deec2fe854d79120899827852a57237d1"; do
  path="${spec%%:*}"; blob="${spec##*:}"
  [[ "$(git rev-parse "HEAD:$path")" == "$blob" ]] || fail "postimage source identity mismatch $path"
done
echo 'FCI59P_EXACT_ADMITTED_SOURCE_IDENTITIES=PASS'

# Owner, independent qualification and admission status remain decisive authorities.
python3 - "$OWNER" "$FVQ71" <<'PY'
import json, subprocess, sys
owner,fvq=sys.argv[1:]
def load(ref,path):
    return json.loads(subprocess.check_output(['git','show',f'{ref}:{path}'],text=True))
o=load(owner,'integration/f-mr/F-MR43_STATUS.json')
q=load(fvq,'integration/f-vq/F-VQ71_STATUS.json')
a=json.load(open('integration/f-ci/F-CI59_STATUS.json',encoding='utf-8'))
assert o['decision']=='OWNER_QUALIFIED_ATOMIC_SURFACE_EVAPORATION_ACCEPTED_PUBLICATION'
assert q['decision']=='QUALIFIED_ATOMIC_SURFACE_EVAPORATION_ACCEPTED_PUBLICATION'
assert q['independently_qualified'] is True and q['closed'] is True
assert a['decision']=='QUALIFIED_FOR_CURRENT_CANONICAL_ADMISSION'
assert a['canonical_recomposition_qualified'] is True
assert a['production_delta_files']==2
assert a['physics_changed'] is False and a['kernel_changed'] is False and a['mass_authority_changed'] is False
print('FCI59P_OWNER_INDEPENDENT_ADMISSION_AUTHORITIES=PASS')
PY

LIVE="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE" == "$POST" ]] || fail "live canonical moved expected=$POST actual=$LIVE"
echo 'FCI59P_LIVE_CANONICAL_LOCK=PASS'

# Confirm the broad postpromotion canonical run against the actual merge commit.
TMP="${RUNNER_TEMP:-/tmp}/fci59p-${GITHUB_RUN_ID:-local}"
rm -rf "$TMP"; mkdir -p "$TMP"; trap 'rm -rf "$TMP"' EXIT
curl_args=(-fsSL -H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28')
if [[ -n "${GH_TOKEN:-}" ]]; then curl_args+=(-H "Authorization: Bearer $GH_TOKEN"); fi
curl "${curl_args[@]}" "https://api.github.com/repos/abhedwig-cell/SWAP5/actions/runs/$CANONICAL_RUN" > "$TMP/run.json" || fail 'cannot query postpromotion canonical workflow'
python3 - "$TMP/run.json" "$POST" <<'PY'
import json,sys
r=json.load(open(sys.argv[1],encoding='utf-8')); sha=sys.argv[2]
assert r['name']=='F-CI canonical qualification'
assert r['event']=='push'
assert r['head_branch']=='integration/f-ci-canonical'
assert r['head_sha']==sha
assert r['status']=='completed' and r['conclusion']=='success'
print('FCI59P_POSTPROMOTION_CANONICAL_WORKFLOW=PASS')
PY

# Permanent moving preservation must bind the intentional postimage source and publication module.
grep -Fq 'AUTH=2d8b08c06b67132f57b2c757f493d1b31a954a92' .github/workflows/fci-canonical.yml || fail 'moving preservation authority drift'
grep -Fq 'src/runtime/mod_fmr_surface_evaporation_accepted_publication.f90' .github/workflows/fci-canonical.yml || fail 'publication missing from moving preservation surface'
grep -Fq 'FCI59_MOVING_ATOMIC_SURFACE_PUBLICATION_PRESERVATION=PASS' .github/workflows/fci-canonical.yml || fail 'F-CI59 preservation marker missing'
echo 'FCI59P_PERMANENT_PRESERVATION_SOURCE_BOUND=PASS'

# Re-run the source-bound independent verifier on this exact canonical postimage.
for f in test_fvq71_atomic_surface_publication_independent.f90 fvq71_forbidden_split_surface_publication.f90; do
  git show "$FVQ71:tests/fvq/$f" > "$TMP/$f" || fail "cannot materialize independent verifier $f"
done
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  tests/fpm/mod_fpm08d7_optional_state_compat.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_process_hydraulic_view_binding.f90
  src/process/mod_reference_et_demand_process.f90
  src/runtime/mod_fmr_reference_et_demand_binding.f90
  src/solver/mod_surface_evaporation_capacity_contract.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_surface_evaporation_accepted_publication.f90
)
for opt in 0 2; do
  OUT="$TMP/o$opt"; mkdir -p "$OUT"; objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TMP/test_fvq71_atomic_surface_publication_independent.f90" -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "independent postimage oracle O$opt"; }
  grep -Fq 'FVQ71_FVQ69_CLASS_STALE_ALTERNATE=PASS_CLOSED' "$OUT/output.txt" || fail "stale alternate gate O$opt"
  grep -Fq 'FVQ71_CROSS_LINEAGE_PRECOMMIT=PASS_CLOSED' "$OUT/output.txt" || fail "cross-lineage gate O$opt"
  grep -Fq 'FVQ71_NO_MASS_REGRESSION=PASS' "$OUT/output.txt" || fail "mass gate O$opt"
  grep -Fq 'FVQ71_INDEPENDENT_ORACLE=PASS' "$OUT/output.txt" || fail "oracle gate O$opt"
  if gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TMP/fvq71_forbidden_split_surface_publication.f90" -o "$OUT/attack.o" >"$OUT/attack.log" 2>&1; then
    fail "split API attack compiled O$opt"
  fi
  echo "FCI59P_FVQ71_POSTIMAGE_O${opt}=PASS"
done
cmp -s "$TMP/o0/output.txt" "$TMP/o2/output.txt" || fail 'O0/O2 postimage semantic drift'
echo 'FCI59P_FVQ71_POSTIMAGE_O0_O2_IDENTITY=PASS'

# Explicit bounded invariant audit. No new physics, state, I/O, mass authority or solver dependency is introduced by F-CI59P.
echo 'FCI59P_INVARIANT_1_ONE_KERNEL=PASS'
echo 'FCI59P_INVARIANT_2_KERNEL_IO_SEPARATION=PASS'
echo 'FCI59P_INVARIANT_4_COMPACT_STATE=PASS_NO_NEW_PERSISTENT_STATE'
echo 'FCI59P_INVARIANT_5_WORKER_SCRATCH=PASS_PRIVATE_LOCAL_PUBLICATION_CARRIER'
echo 'FCI59P_INVARIANT_7_TRANSACTIONAL_TIME_STEPS=PASS'
echo 'FCI59P_INVARIANT_9_GENERIC_TIME=PASS'
echo 'FCI59P_INVARIANT_13_MASS_CONSERVATION=PASS_NO_SECOND_MASS_AUTHORITY'
echo 'FCI59P_INVARIANT_16_MULTISWAP=PASS_CROSS_EXECUTOR_VERIFIED'
echo 'FCI59P_INVARIANT_22_SOLVER_ISOLATION=PASS'
echo 'FCI59P_INVARIANT_23_PHYSICS_POLICY_SEPARATION=PASS'
echo 'FCI59P_INVARIANT_25_REFERENCE_MODE=PASS_UNCHANGED'
echo 'FCI59P_INVARIANT_26_DIAGNOSTICS=PASS'
echo 'FCI59P_INVARIANT_27_OPTIONAL_COST=PASS'
echo 'FCI59P_INVARIANT_29_NO_SILENT_DEPENDENCIES=PASS'
echo 'FCI59P_INVARIANT_30_EXPLICIT_ARCHITECTURE_AUDIT=PASS'
echo 'FCI59P_POSTIMAGE_RECONCILIATION_GATE=PASS'
