#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

owner_branch="work/f-gc19r-r1-prepared-ledger-provenance-remediation"
owner_head="3bf3fec344ee67dd56f5f54b293b3a0a47214efb"
owner_source_blob="d37f1926dafde9d941939cf4147d799cb7478bfc"
blocked_branch="qualification/f-gc19r-prepared-ledger-publication-owner-qualification"
blocked_head="c4b0dc78af0b444edcc4b349cc598b5b6167bd1d"
fgc17_blob="fc598d14eabafcb025bb55621f7b00d6d1816f10"

live_owner="$(git ls-remote origin "refs/heads/$owner_branch" | awk '{print $1}')"
test "$live_owner" = "$owner_head" || { echo "FVQ62_OWNER_RACE_FAIL expected=$owner_head actual=$live_owner" >&2; exit 20; }
live_blocked="$(git ls-remote origin "refs/heads/$blocked_branch" | awk '{print $1}')"
test "$live_blocked" = "$blocked_head" || { echo "FVQ62_BLOCKED_AUTHORITY_RACE_FAIL expected=$blocked_head actual=$live_blocked" >&2; exit 21; }
test "$(git rev-parse HEAD:src/runtime/mod_groundwater_interface_mass_ledger.f90)" = "$owner_source_blob"
test "$(git rev-parse HEAD:src/runtime/mod_groundwater_coupling_contract.f90)" = "$fgc17_blob"

allowed=(
  ".github/workflows/fvq62-fgc19r-r1-prepared-ledger-provenance.yml"
  "integration/f-vq/F-VQ62_PRE_REGISTRATION.json"
  "integration/f-vq/F-VQ62_ARCHITECTURE_AUDIT.json"
  "integration/f-vq/F-VQ62_STATUS.json"
  "tests/fvq/run_fvq62_fgc19r_r1_prepared_ledger_provenance.sh"
  "tests/fvq/test_fvq62_fgc19r_r1_prepared_ledger_provenance.f90"
)
mapfile -t changed < <(git diff --name-only "$owner_head..HEAD")
for path in "${changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do [[ "$path" == "$candidate" ]] && ok=1 && break; done
  [[ "$ok" -eq 1 ]] || { echo "FVQ62_SCOPE_FAIL unexpected path: $path" >&2; exit 22; }
done

src=src/runtime/mod_groundwater_interface_mass_ledger.f90
! grep -Eiq 'MODFLOW|\.swp|midnight|86400' "$src"
! grep -Eiq 'mass_tolerance|balance_tolerance' "$src"
! grep -Eiq 'c_loc|loc\(' "$src"
! grep -Eiq '^[[:space:]]*save([[:space:]:]|$)' "$src"
grep -q 'prepared%ledger_id /= self%ledger_id' "$src"
grep -q 'GW_MASS_LEDGER_IDENTITY_REQUIRED' "$src"
grep -q 'self%preparation_generation >= huge(self%preparation_generation)' "$src"
grep -q 'self%committed_exchange_count >= huge(self%committed_exchange_count)' "$src"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
compile_and_run() {
  local opt="$1"
  local out="$2"
  local dir="$work/$opt"
  mkdir -p "$dir"
  gfortran "-$opt" -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -J"$dir" -I"$dir" \
    src/runtime/mod_groundwater_coupling_contract.f90 \
    "$src" \
    tests/fvq/test_fvq62_fgc19r_r1_prepared_ledger_provenance.f90 \
    -o "$dir/test_fvq62"
  "$dir/test_fvq62" > "$out"
}
compile_and_run O0 "$work/o0.txt"
compile_and_run O2 "$work/o2.txt"
diff -u "$work/o0.txt" "$work/o2.txt"
for marker in \
  FVQ62_UNBOUND_EXTERNAL_PREPARE_FAIL_CLOSED \
  FVQ62_IDENTITY_IMMUTABILITY \
  FVQ62_FOREIGN_HANDLE_SAME_LINEAGE_REJECTION \
  FVQ62_STALE_COPY_REJECTION \
  FVQ62_GENERATION_ADVANCE_REJECTION \
  FVQ62_ABORT_MASS_PRESERVATION \
  FVQ62_LEGACY_ATOMIC_COMPATIBILITY \
  FVQ62_EXACT_ACTION_REACTION; do
  grep -q "^${marker}=PASS$" "$work/o0.txt"
done

python3 - <<'PY'
import json
p='integration/f-vq/F-VQ62_ARCHITECTURE_AUDIT.json'
d=json.load(open(p))
assert d['overall']=='30_OF_30_NO_ADVERSE_DELTA_INDEPENDENTLY_VERIFIED'
assert d['mass_conservation']=='HARD_PRESERVED_WITH_PROVENANCE_SAFE_PUBLICATION'
assert [x['id'] for x in d['invariants']]==list(range(1,31))
assert all(x['status']=='PASS' for x in d['invariants'])
PY

cat "$work/o0.txt"
echo 'FVQ62_OWNER_AUTHORITY_LOCK=PASS'
echo 'FVQ62_FROZEN_BLOCKED_AUTHORITY_LOCK=PASS'
echo 'FVQ62_SOURCE_BLOB_LOCK=PASS'
echo 'FVQ62_FGC17_CONTRACT_LOCK=PASS'
echo 'FVQ62_NO_HIDDEN_GLOBAL_IDENTITY=PASS'
echo 'FVQ62_EXHAUSTION_GUARDS=PASS'
echo 'FVQ62_O0_O2_IDENTITY=PASS'
echo 'FVQ62_SCOPE_ALLOWLIST=PASS'
