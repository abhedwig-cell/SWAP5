#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fkt03-gate-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
COMMON=(-std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -fopenmp)
TX="$ROOT/src/transaction/mod_transaction_reference.f90"
CONTRACTS="$ROOT/src/runtime/mod_canonical_contracts.f90"
RUNTIME="$ROOT/src/runtime/mod_canonical_interval_runtime.f90"
KERNEL="$ROOT/src/kernel/mod_kernel_transactions.f90"
TEST="$ROOT/tests/fkt/test_fkt03_opaque_transaction_carriers.f90"
FSI02="da1d5da0d909c5ce55efa17507b805bffd6b82f9"

python3 "$ROOT/tools/fkt/fkt03_contract_gate.py"

# Verify the exact downstream ownership boundary consumed by F-KT03.
git fetch --quiet --no-tags origin "$FSI02"
git show "$FSI02:integration/f-si/F-SI01_SOLVER_INTERFACE_CONTRACT.json" | \
python3 -c 'import json,sys; d=json.load(sys.stdin); t=d["transaction_boundary"]; assert d["request"]["base_physical_state"]["ownership"] == "F-KT committed/candidate state view"; assert t["solver_may_mutate_committed_input"] is False; assert t["solver_may_commit"] is False; assert t["solver_may_rollback"] is False; assert t["solver_may_define_t0_t1_semantics"] is False'
git show "$FSI02:docs/integration/F-SI02_REFERENCE_SOLVER_INTERFACE.md" | \
  grep -Fq 'It does not yet route the B1.10 reference Richards calculation through that contract.'
echo 'FKT03_FSI_BOUNDARY_GATE PASS'

for OPT in o0 o2; do
  FLAG="-O0"
  if [[ "$OPT" == "o2" ]]; then FLAG="-O2"; fi
  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/$OPT" \
    "$TX" "$CONTRACTS" "$RUNTIME" "$KERNEL" "$TEST" -o "$BUILD/test_$OPT"
  "$BUILD/test_$OPT"
done

echo 'FKT03_FOCUSED_O0_O2_GATE PASS'
