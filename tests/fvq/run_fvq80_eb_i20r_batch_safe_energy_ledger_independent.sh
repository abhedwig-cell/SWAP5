#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq80-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT; cd "$ROOT"
fail(){ echo "FVQ80_GATE_FAIL $*" >&2; exit 280; }

CANONICAL="b162e98cc4ad6f85b741a21bd41f3db3d213559b"
OWNER_POSTIMAGE="fa11c2ecac01bb2634b43304588b91aec2d8d341"
TYPES="src/kernel/mod_energy_conservation_types.f90"
LEDGER="src/runtime/mod_energy_conservation_ledger.f90"
TYPES_BLOB="15a6a9c5c5da6ad0d535c27772e57a23e618658d"
LEDGER_BLOB="a6aea349308e8b6b0aedaaa22a64e41f9101b48d"

git fetch -q origin integration/f-ci-canonical work/eb-i20r-batch-safe-energy-ledger-invariant-handling
[[ "$(git rev-parse origin/integration/f-ci-canonical)" == "$CANONICAL" ]] || fail 'canonical drift'
[[ "$(git merge-base "$OWNER_POSTIMAGE" HEAD)" == "$OWNER_POSTIMAGE" ]] || fail 'verifier not descended from exact EB-I20R postimage'
changed="$(git diff --name-only "$CANONICAL..$OWNER_POSTIMAGE" -- src | LC_ALL=C sort)"
[[ "$changed" == $'src/kernel/mod_energy_conservation_types.f90\nsrc/runtime/mod_energy_conservation_ledger.f90' ]] || fail 'owner production delta not exactly two energy modules'
[[ -z "$(git diff --name-only "$CANONICAL..$OWNER_POSTIMAGE" -- reference)" ]] || fail 'owner reference delta'
[[ "$(git rev-parse "$OWNER_POSTIMAGE:$TYPES")" == "$TYPES_BLOB" ]] || fail 'energy types blob drift'
[[ "$(git rev-parse "$OWNER_POSTIMAGE:$LEDGER")" == "$LEDGER_BLOB" ]] || fail 'energy ledger blob drift'
[[ -z "$(git diff --name-only "$OWNER_POSTIMAGE..HEAD" -- src reference)" ]] || fail 'verifier modified production/reference source'
echo 'FVQ80_SCOPE_AND_BLOBS=PASS'

! grep -Eq '^[[:space:]]*error stop' "$LEDGER" || fail 'batch-fatal error stop remains in qualified owner postimage'
grep -Fq 'if (prepared%generation /= self%prepared_generation) return' "$LEDGER" || fail 'prepared generation guard missing'
echo 'FVQ80_BATCH_FATAL_PATHS_ABSENT=PASS'

STRICT=(-std=f2008 -Wall -Wextra -Werror -ffree-line-length-none -fcheck=all -fbacktrace)
BASE=(-std=f2008 -Wall -Wextra -Werror -Wno-error=compare-reals -ffree-line-length-none -fcheck=all -fbacktrace)
BASE_MODULES=(src/transaction/mod_transaction_reference.f90 src/runtime/mod_canonical_contracts.f90 src/runtime/mod_canonical_interval_runtime.f90 src/kernel/mod_kernel_transactions.f90 src/runtime/mod_fmr_accepted_commit_receipt.f90)

compile_attack(){
  local opt="$1" out="$2"; mkdir -p "$out"; local objects=()
  for src in "${BASE_MODULES[@]}"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${BASE[@]}" -O"$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  for src in "$TYPES" "$LEDGER"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${STRICT[@]}" -O"$opt" -J "$out" -I "$out" -c tests/fvq/test_fvq80_cross_ledger_prepared_handle_attack.f90 -o "$out/test.o"
  gfortran -O"$opt" "${objects[@]}" "$out/test.o" -o "$out/test"
  "$out/test" > "$out/out.txt"
}

compile_attack 0 "$BUILD/o0"
compile_attack 2 "$BUILD/o2"
cmp "$BUILD/o0/out.txt" "$BUILD/o2/out.txt" || fail 'O0/O2 attack observation differs'
echo 'FVQ80_ATTACK_O0_O2_IDENTITY=PASS'
cat "$BUILD/o0/out.txt"

if grep -Fq 'FVQ80_CROSS_LEDGER_PREPARED_HANDLE_PROVENANCE=BLOCKER_REPRODUCED' "$BUILD/o0/out.txt"; then
  echo 'FVQ80_INDEPENDENT_QUALIFICATION=NOT_QUALIFIED_CROSS_LEDGER_PREPARED_HANDLE_PROVENANCE'
  echo 'FVQ80_DECISION=REMEDIATION_REQUIRED_BEFORE_ADMISSION'
  exit 0
fi

if grep -Fq 'FVQ80_CROSS_LEDGER_PREPARED_HANDLE_PROVENANCE=FAIL_CLOSED' "$BUILD/o0/out.txt"; then
  echo 'FVQ80_INDEPENDENT_QUALIFICATION=CROSS_LEDGER_PROVENANCE_ATTACK_REPELLED'
  exit 0
fi

fail 'attack produced unexpected state'
