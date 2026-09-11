#!/usr/bin/env bash
set -euo pipefail

BASE="0b284b5f4e224c5f76d7d78b9dbb51c99514479d"
CANONICAL_BRANCH="integration/f-ci-canonical"
DONOR_BRANCH="work/f-kt15-production-soil-water-solver-service-transaction-composition"
DONOR="eacdacb60524221d0c286571444271089347dbcc"
FSI30="46735abda379aa4bf4908f00a49c0926adee0693"
FKT14="2f7995df362c65916671278a5552ed9976ed39b3"

fail(){ echo "FKT15R_FAIL $*" >&2; exit 1; }

# The recomposition is meaningful only against this exact current canonical.
git fetch --no-tags origin "${CANONICAL_BRANCH}:refs/remotes/origin/${CANONICAL_BRANCH}" >/dev/null 2>&1
actual_canonical="$(git rev-parse refs/remotes/origin/${CANONICAL_BRANCH})"
[[ "$actual_canonical" == "$BASE" ]] || fail "canonical race expected $BASE got $actual_canonical"
git merge-base --is-ancestor "$BASE" HEAD || fail "HEAD is not descended from F-CI48 base"
echo "FKT15R_CANONICAL_RACE_GUARD=PASS"

allowed=(
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_soil_water_transaction_result_bridge.f90
  src/kernel/mod_kernel_transactions.f90
  src/legacy/b1_10_port/headcalc.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/transaction/mod_transaction_reference.f90
)
mapfile -t actual_src < <(git diff --name-only "$BASE"..HEAD -- src | sort)
printf '%s\n' "${allowed[@]}" | sort > /tmp/fkt15r-expected-src
printf '%s\n' "${actual_src[@]}" > /tmp/fkt15r-actual-src
diff -u /tmp/fkt15r-expected-src /tmp/fkt15r-actual-src || fail "source allowlist mismatch"
if git diff --name-only "$BASE"..HEAD -- reference | grep -q .; then fail "reference delta forbidden"; fi
echo "FKT15R_EXACT_SOURCE_ALLOWLIST=PASS"

# Pin the combined qualified owner postimage.
git fetch --no-tags origin "${DONOR_BRANCH}:refs/remotes/origin/${DONOR_BRANCH}" >/dev/null 2>&1
[[ "$(git rev-parse refs/remotes/origin/${DONOR_BRANCH})" == "$DONOR" ]] || fail "combined donor branch moved"
for path in "${allowed[@]}"; do
  [[ "$(git rev-parse HEAD:$path)" == "$(git rev-parse $DONOR:$path)" ]] || fail "donor blob drift $path"
done
echo "FKT15R_COMBINED_DONOR_BLOB_IDENTITY=PASS"

# F-CI48 optional-state layout source must remain untouched.
check_blob(){ local p="$1" e="$2" a; a="$(git rev-parse HEAD:$p)"; [[ "$a" == "$e" ]] || fail "F-CI48 lock drift $p $a"; }
check_blob src/runtime/mod_fmr_restart_state_contract.f90 4a9c1644665c02de77c82e4b5fa2baaaf0a1fb6d
check_blob src/runtime/mod_fmr_runtime_core.f90 88adf19e274956ab0f97fe6b4f6307fbfb453790
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 2364c765935813675dee0d2838a7ce183d81f560
echo "FKT15R_FCI48_NONOVERLAP_LOCKS=PASS"

# Bring exact closed qualification tests into an isolated worktree, but run them
# against THIS recomposed source postimage rather than the historical source trees.
for rev in "$FSI30" "$FKT14"; do git cat-file -e "$rev^{commit}" 2>/dev/null || git fetch --no-tags origin "$rev"; done
WT="${RUNNER_TEMP:-/tmp}/fkt15r-recomposition-${GITHUB_RUN_ID:-local}"
rm -rf "$WT"
git worktree add --detach "$WT" HEAD >/dev/null
cleanup(){ git worktree remove --force "$WT" >/dev/null 2>&1 || true; }
trap cleanup EXIT
mkdir -p "$WT/tests/fsi" "$WT/tests/fkt"
git archive "$FSI30" tests/fsi | tar -x -C "$WT"
git archive "$FKT14" tests/fkt | tar -x -C "$WT"

(
  cd "$WT"
  bash tests/fsi/run_fsi30_abi_adapter_compile_gate.sh
  bash tests/fsi/run_fsi30_headcalc_compile_gate.sh
  bash tests/fsi/run_fsi30_adapter_identity_gate.sh
  bash tests/fsi/run_fsi30_dynamic_headcalc_execution_gate.sh
)
echo "FKT15R_FSI30_RECOMPOSED_SOURCE_REPLAY=PASS"

# Re-run F-KT14 accepted transport and solver-result bridge against the recomposed
# F-SI30-compatible contract layer at O0 and O2 and require observable identity.
for opt in 0 2; do
  B="$WT/build/fkt15r-fkt14-o${opt}"
  mkdir -p "$B"
  gfortran -std=f2008 -ffree-line-length-none -O"$opt" -J"$B" -I"$B" \
    "$WT/src/transaction/mod_transaction_reference.f90" \
    "$WT/src/runtime/mod_canonical_contracts.f90" \
    "$WT/src/runtime/mod_canonical_interval_runtime.f90" \
    "$WT/src/kernel/mod_kernel_transactions.f90" \
    "$WT/tests/fkt/test_fkt14_interface_sensitivity_transport.f90" \
    -o "$B/test_transport"
  "$B/test_transport" > "$B/transport.out"

  gfortran -std=f2008 -ffree-line-length-none -O"$opt" -J"$B" -I"$B" \
    "$WT/src/solver/mod_soil_water_solver_contract.f90" \
    "$WT/src/transaction/mod_transaction_reference.f90" \
    "$WT/src/adapter/mod_soil_water_transaction_result_bridge.f90" \
    "$WT/tests/fkt/test_fkt14_solver_result_bridge.f90" \
    -o "$B/test_bridge"
  "$B/test_bridge" > "$B/bridge.out"
done
diff -u "$WT/build/fkt15r-fkt14-o0/transport.out" "$WT/build/fkt15r-fkt14-o2/transport.out"
diff -u "$WT/build/fkt15r-fkt14-o0/bridge.out" "$WT/build/fkt15r-fkt14-o2/bridge.out"
echo "FKT15R_FKT14_ACCEPTED_TRANSPORT_O0_O2=PASS"

# Ensure this workunit has not yet changed the real SoilWater task-2 callsite.
[[ "$(git rev-parse HEAD:src/legacy/b1_10_port/soilwater.f90)" == "$(git rev-parse $BASE:src/legacy/b1_10_port/soilwater.f90)" ]] || fail "task-2 production route changed during recomposition"
echo "FKT15R_TASK2_IMPLEMENTATION_NOT_YET_STARTED=PASS"

echo "FKT15R_GATE=PASS"
echo "FKT15R_EXACT_HEAD=$(git rev-parse HEAD)"
