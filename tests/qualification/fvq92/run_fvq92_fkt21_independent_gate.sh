#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

OWNER_RECEIPT_HEAD="eee5f15a742d11b268d2a872a4c376e1f2c475c0"
OWNER_SOURCE_HEAD="19a67f7c398fcadbcbc9729509680a1c0c5424f3"
BUILD="${TMPDIR:-/tmp}/swap5-fvq92-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "FVQ92_FAIL $*" >&2; exit 1; }

# F-VQ92 is verifier-only. Production and owner qualification artifacts must
# remain byte-identical to the green F-KT21 owner authority.
git merge-base --is-ancestor "$OWNER_RECEIPT_HEAD" HEAD || fail 'branch is not descended from F-KT21 owner receipt authority'
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  case "$path" in
    tests/qualification/fvq92/*|qualification/F-VQ92_STATUS.json|.github/workflows/fvq92-fkt21-independent.yml) ;;
    *) fail "out-of-scope verifier delta: $path" ;;
  esac
done < <(git diff --name-only "$OWNER_RECEIPT_HEAD"..HEAD)

git diff --quiet "$OWNER_RECEIPT_HEAD" HEAD -- src tests/fkt integration/f-kt/F-KT21_CAPABILITY_QUALIFICATION.json || \
  fail 'F-KT21 owner production/test/receipt postimage drifted'
git diff --quiet "$OWNER_SOURCE_HEAD" "$OWNER_RECEIPT_HEAD" -- src tests/fkt || \
  fail 'owner receipt changed qualified source or tests'

echo 'FVQ92_SCOPE_LOCK=PASS'
echo 'FVQ92_OWNER_POSTIMAGE_LOCK=PASS'

# The four F-SI37 dependencies pinned by F-KT21 are now canonical authority.
# Recheck both the verifier head and the live canonical branch. Unrelated
# canonical movement is allowed; these exact semantic dependency blobs are not.
check_si37_blobs(){
  local ref="$1"
  [[ "$(git rev-parse "$ref:src/solver/mod_soil_water_accepted_step_direction_contract.f90")" == 52698b1ad2350bf787862a053a49c7c73c3358f0 ]] || fail "F-SI37 contract drift at $ref"
  [[ "$(git rev-parse "$ref:src/solver/mod_b110_default_mvg_directional_provider.f90")" == b1e794d2f0e661a2abb14280a59175e1cf1d5724 ]] || fail "F-SI37 constitutive derivative drift at $ref"
  [[ "$(git rev-parse "$ref:src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90")" == 0a957376b9a9fdea00ab6009f129803fb5341e4a ]] || fail "F-SI37 dynamic-top derivative drift at $ref"
  [[ "$(git rev-parse "$ref:src/adapter/mod_reference_richards_accepted_step_directional_service.f90")" == ef395ac3fb0cf6f347031bf2081a74b74b5167ae ]] || fail "F-SI37 accepted-step service drift at $ref"
}
check_si37_blobs HEAD
git fetch --no-tags origin integration/f-ci-canonical >/dev/null 2>&1
CANONICAL_HEAD="$(git rev-parse FETCH_HEAD)"
check_si37_blobs "$CANONICAL_HEAD"
echo "FVQ92_CANONICAL_HEAD=$CANONICAL_HEAD"
echo 'FVQ92_FSI37_CANONICAL_DEPENDENCY_LOCK=PASS'

# Replay the unchanged owner gate. This is inherited evidence only and is not
# counted as the independent oracle below.
bash tests/fkt/run_fkt21_qualification.sh | tee "$BUILD/owner_gate.txt"
grep -Fq 'FKT21_QUALIFICATION PASS' "$BUILD/owner_gate.txt" || fail 'owner qualification replay missing final marker'
echo 'FVQ92_OWNER_GATE_REPLAY=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
run_independent(){
  local opt="$1"
  local tag="$2"
  local out="$BUILD/$tag"
  mkdir -p "$out"

  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/solver/mod_soil_water_accepted_step_direction_contract.f90 -o "$out/contract.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_accepted_trajectory_directional_sensitivity.f90 -o "$out/trajectory.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_accepted_trajectory_directional_publication.f90 -o "$out/publication.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_transaction_reference.f90 -o "$out/transaction.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_accepted_trajectory_transaction_binding.f90 -o "$out/binding.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c tests/qualification/fvq92/test_fvq92_fkt21_independent.f90 -o "$out/test.o"
  gfortran "$opt" "$out/contract.o" "$out/trajectory.o" "$out/publication.o" "$out/transaction.o" "$out/binding.o" "$out/test.o" -o "$out/fvq92"
  "$out/fvq92" | tee "$out/output.txt"

  grep -Fq 'FVQ92_WHOLE_WINDOW_CENTERED_FD=PASS' "$out/output.txt" || fail "independent whole-window FD missing $tag"
  grep -Fq 'FVQ92_REJECTED_STEP_NO_LEAK=PASS' "$out/output.txt" || fail "reject leak oracle missing $tag"
  grep -Fq 'FVQ92_RETRY_ABA_REJECTED=PASS' "$out/output.txt" || fail "ABA oracle missing $tag"
  grep -Fq 'FVQ92_TRANSACTION_PUBLICATION_GUARDS=PASS' "$out/output.txt" || fail "transaction guard oracle missing $tag"
  grep -Fq 'FVQ92_SHORTENED_INTERVAL_PROVENANCE=PASS' "$out/output.txt" || fail "shortened provenance oracle missing $tag"
  grep -Fq 'F_VQ92_INDEPENDENT_ORACLE=PASS' "$out/output.txt" || fail "independent final marker missing $tag"
}

run_independent -O0 o0
run_independent -O2 o2
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail 'independent O0/O2 output drift'

ORACLE_SHA256="$(sha256sum tests/qualification/fvq92/test_fvq92_fkt21_independent.f90 | awk '{print $1}')"
echo "FVQ92_INDEPENDENT_ORACLE_SHA256=$ORACLE_SHA256"
echo 'FVQ92_INDEPENDENT_O0_O2_IDENTITY=PASS'
echo 'F_VQ92_FINAL_GATE=PASS'
