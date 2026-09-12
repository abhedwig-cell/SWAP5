#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

remediation_base="a7eada40c4d0a1f718052c3410c467597783f10d"
canonical_restart="54de4ba714599128e1405d82d541298b10124591"
donor="7c1c5251a2dff94291db381cf0b66631b81e9f05"
allowed=(
  "src/runtime/mod_groundwater_exchange_service_contract.f90"
  "tests/fgc/test_fgc18r_prepared_commit.f90"
  "tests/fgc/run_fgc18r_prepared_commit.sh"
  ".github/workflows/fgc18r-prepared-commit.yml"
  "integration/f-gc/F-GC18R_R1_ARCHITECTURE_AUDIT.json"
  "integration/f-gc/F-GC18R_R1_STATUS.json"
)

git merge-base --is-ancestor "$canonical_restart" HEAD
git merge-base --is-ancestor "$donor" HEAD
mapfile -t changed < <(git diff --name-only "$remediation_base..HEAD")
for path in "${changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do [[ "$path" == "$candidate" ]] && ok=1 && break; done
  [[ "$ok" -eq 1 ]] || { echo "FGC18R_R1_SCOPE_FAIL unexpected path: $path" >&2; exit 20; }
done

test "$(git rev-parse HEAD:src/runtime/mod_groundwater_coupling_contract.f90)" = fc598d14eabafcb025bb55621f7b00d6d1816f10
python3 - <<'PY'
from pathlib import Path
s=Path('src/runtime/mod_groundwater_exchange_service_contract.f90').read_text()
assert 'type, abstract, public :: groundwater_exchange_service_t' in s
base=s.split('type, abstract, public :: groundwater_exchange_service_t',1)[1].split('end type groundwater_exchange_service_t',1)[0]
for name in ['capture_backend','trial_backend','commit_backend','discard_backend']:
    assert name in base
assert 'prepare_backend' not in base
assert 'type, abstract, extends(groundwater_exchange_service_t), public :: groundwater_preparable_exchange_service_t' in s
assert 'type(groundwater_reservation_slot_t), allocatable :: reservation_slots(:)' in s
assert 'reservation_generation' in s
assert 'GW_EXCHANGE_STALE_PREPARED' in s
assert 'GW_EXCHANGE_REVISION_EXHAUSTED' in s
assert 'safe_revision_successor' in s
assert s.count('call consume_prepared_slot(') == 2
assert 'subroutine gw_commit_prepared_backend_ifc(self, prepare_token)' in s
assert 'subroutine gw_abort_prepared_backend_ifc(self, prepare_token)' in s
assert 'call service%commit_prepared_backend(prepared%backend_prepare_token)' in s
assert 'call service%abort_prepared_backend(prepared%backend_prepare_token)' in s
for unsafe in [
    'checkpoint%origin_revision_value + 1_int64',
    'self%origin_revision_value + 1_int64'
]:
    assert unsafe not in s
low=s.lower()
for forbidden in ['modflow','.swp','midnight']:
    assert forbidden not in low
PY

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
compile_base_abi() {
  local opt="$1"
  local out="$2"
  local dir="$work/base-$opt"
  mkdir -p "$dir"
  gfortran "-$opt" -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -J"$dir" -I"$dir" \
    src/runtime/mod_groundwater_coupling_contract.f90 \
    src/runtime/mod_groundwater_exchange_service_contract.f90 \
    tests/fgc/test_fgc18_groundwater_exchange_service.f90 \
    -o "$dir/test_base"
  "$dir/test_base" > "$out"
}
compile_prepared() {
  local opt="$1"
  local out="$2"
  local dir="$work/prepared-$opt"
  mkdir -p "$dir"
  gfortran "-$opt" -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -J"$dir" -I"$dir" \
    src/runtime/mod_groundwater_coupling_contract.f90 \
    src/runtime/mod_groundwater_exchange_service_contract.f90 \
    tests/fgc/test_fgc18r_prepared_commit.f90 \
    -o "$dir/test_prepared"
  "$dir/test_prepared" > "$out"
}
compile_base_abi O0 "$work/base-o0.txt"
compile_base_abi O2 "$work/base-o2.txt"
diff -u "$work/base-o0.txt" "$work/base-o2.txt"
grep -q '^FGC18_TRANSACTIONAL_GW_SERVICE=PASS$' "$work/base-o0.txt"
grep -q '^FGC18_COMMIT_ONCE_AND_STALE_REJECT=PASS$' "$work/base-o0.txt"

compile_prepared O0 "$work/prepared-o0.txt"
compile_prepared O2 "$work/prepared-o2.txt"
diff -u "$work/prepared-o0.txt" "$work/prepared-o2.txt"
for marker in \
  FGC18R_PREPARE_ABORT_NO_PUBLICATION \
  FGC18R_PREPARE_BLOCKS_NEW_TRIAL \
  FGC18R_PREPARED_COMMIT_ONCE \
  FGC18R_STALE_PREPARE_REJECTED \
  FGC18R_COPIED_ABORT_REPLAY_REJECTED \
  FGC18R_COPIED_COMMIT_REPLAY_REJECTED \
  FGC18R_BACKEND_TOKEN_REUSE_GENERATION_GUARDED \
  FGC18R_REVISION_INT64_BOUNDARY_FAIL_CLOSED \
  FGC18R_NO_RECOVERABLE_FINAL_COMMIT_STATUS \
  FGC18R_BASE_SERVICE_ABI_RETAINED; do
  grep -q "^${marker}=PASS$" "$work/prepared-o0.txt"
done

if [[ -f integration/f-gc/F-GC18R_R1_ARCHITECTURE_AUDIT.json ]]; then
python3 - <<'PY'
import json
d=json.load(open('integration/f-gc/F-GC18R_R1_ARCHITECTURE_AUDIT.json'))
assert d['overall']=='30_OF_30_NO_ADVERSE_DELTA_AFTER_FVQ60_REMEDIATION'
assert d['mass_conservation']=='HARD_UNCHANGED_FAIL_CLOSED_REPLAY_GUARD'
assert [x['id'] for x in d['invariants']]==list(range(1,31))
assert all(x['status']=='PASS' for x in d['invariants'])
PY
fi

cat "$work/base-o0.txt"
cat "$work/prepared-o0.txt"
echo "FGC18R_R1_REMEDIATION_BASE=PASS:$remediation_base"
echo "FGC18R_R1_CURRENT_CANONICAL_ANCESTRY=PASS:$canonical_restart"
echo "FGC18R_R1_DONOR_ANCESTRY=PASS:$donor"
echo 'FGC18R_R1_SCOPE_ALLOWLIST=PASS'
echo 'FGC18R_R1_FGC17_CONTRACT_LOCK=PASS'
echo 'FGC18R_R1_O0_O2_IDENTITY=PASS'
