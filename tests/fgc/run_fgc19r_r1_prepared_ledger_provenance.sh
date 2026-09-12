#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

blocked_candidate="d92b84c815f9e6c5509d280953b4d659c5cb14ac"
blocked_candidate_branch="work/f-gc19r-prepared-ledger-publication"
blocked_qualification="c4b0dc78af0b444edcc4b349cc598b5b6167bd1d"
blocked_qualification_branch="qualification/f-gc19r-prepared-ledger-publication-owner-qualification"
fgc17_blob="fc598d14eabafcb025bb55621f7b00d6d1816f10"

live_candidate="$(git ls-remote origin "refs/heads/$blocked_candidate_branch" | awk '{print $1}')"
test "$live_candidate" = "$blocked_candidate" || { echo "FGC19R_R1_CANDIDATE_RACE_FAIL expected=$blocked_candidate actual=$live_candidate" >&2; exit 20; }
live_blocked="$(git ls-remote origin "refs/heads/$blocked_qualification_branch" | awk '{print $1}')"
test "$live_blocked" = "$blocked_qualification" || { echo "FGC19R_R1_BLOCKED_AUTHORITY_RACE_FAIL expected=$blocked_qualification actual=$live_blocked" >&2; exit 21; }
test "$(git rev-parse HEAD:src/runtime/mod_groundwater_coupling_contract.f90)" = "$fgc17_blob"

allowed=(
  "src/runtime/mod_groundwater_interface_mass_ledger.f90"
  "tests/fgc/test_fgc19r_r1_prepared_ledger_provenance.f90"
  "tests/fgc/run_fgc19r_r1_prepared_ledger_provenance.sh"
  ".github/workflows/fgc19r-r1-prepared-ledger-provenance.yml"
  "integration/f-gc/F-GC19R_R1_ARCHITECTURE_AUDIT.json"
  "integration/f-gc/F-GC19R_R1_STATUS.json"
)
mapfile -t changed < <(git diff --name-only "$blocked_candidate..HEAD")
for path in "${changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do [[ "$path" == "$candidate" ]] && ok=1 && break; done
  [[ "$ok" -eq 1 ]] || { echo "FGC19R_R1_SCOPE_FAIL unexpected path: $path" >&2; exit 22; }
done

src=src/runtime/mod_groundwater_interface_mass_ledger.f90
! grep -Eiq 'MODFLOW|\.swp|midnight|86400' "$src"
! grep -Eiq 'mass_tolerance|balance_tolerance' "$src"
! grep -Eiq 'c_loc|loc\(' "$src"
! grep -Eiq '^[[:space:]]*save([[:space:]:]|$)' "$src"
grep -q 'procedure, public :: bind_identity' "$src"
grep -q 'prepared%ledger_id /= self%ledger_id' "$src"
grep -q 'self%preparation_generation >= huge(self%preparation_generation)' "$src"
grep -q 'self%committed_exchange_count >= huge(self%committed_exchange_count)' "$src"
grep -q 'call groundwater_mass_prepare_trial_impl(self, prepared, status, .false.)' "$src"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
compile_r1() {
  local opt="$1"
  local out="$2"
  local dir="$work/r1-$opt"
  mkdir -p "$dir"
  gfortran "-$opt" -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -J"$dir" -I"$dir" \
    src/runtime/mod_groundwater_coupling_contract.f90 \
    "$src" \
    tests/fgc/test_fgc19r_r1_prepared_ledger_provenance.f90 \
    -o "$dir/test_r1"
  "$dir/test_r1" > "$out"
}
compile_fgc19_legacy() {
  local opt="$1"
  local out="$2"
  local dir="$work/legacy-$opt"
  mkdir -p "$dir"
  gfortran "-$opt" -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -J"$dir" -I"$dir" \
    src/runtime/mod_groundwater_coupling_contract.f90 \
    "$src" \
    tests/fgc/test_fgc19_groundwater_interface_mass_ledger.f90 \
    -o "$dir/test_legacy"
  "$dir/test_legacy" > "$out"
}

compile_r1 O0 "$work/r1-o0.txt"
compile_r1 O2 "$work/r1-o2.txt"
diff -u "$work/r1-o0.txt" "$work/r1-o2.txt"
for marker in \
  FGC19R_R1_EXPLICIT_LEDGER_IDENTITY \
  FGC19R_R1_FOREIGN_HANDLE_REJECTION \
  FGC19R_R1_SAME_LEDGER_REPLAY_REJECTION \
  FGC19R_R1_ABORT_MASS_PRESERVATION \
  FGC19R_R1_LEGACY_COMMIT_TRIAL \
  FGC19R_R1_EXACT_ACTION_REACTION \
  FGC19R_R1_PROVENANCE_DIAGNOSTICS; do
  grep -q "^${marker}=PASS$" "$work/r1-o0.txt"
done

compile_fgc19_legacy O0 "$work/legacy-o0.txt"
compile_fgc19_legacy O2 "$work/legacy-o2.txt"
diff -u "$work/legacy-o0.txt" "$work/legacy-o2.txt"
grep -q '^FGC19_INTERFACE_MASS_LEDGER=PASS$' "$work/legacy-o0.txt"
grep -q '^FGC19_COMMIT_ONCE=PASS$' "$work/legacy-o0.txt"
grep -q '^FGC19_EXACT_ACTION_REACTION=PASS$' "$work/legacy-o0.txt"

python3 - <<'PY'
import json
p='integration/f-gc/F-GC19R_R1_ARCHITECTURE_AUDIT.json'
d=json.load(open(p))
assert d['overall']=='30_OF_30_NO_ADVERSE_DELTA_AFTER_FGC19R_B1_REMEDIATION'
assert d['mass_conservation']=='HARD_UNCHANGED_WITH_PROVENANCE_SAFE_PUBLICATION'
assert [x['id'] for x in d['invariants']]==list(range(1,31))
assert all(x['status']=='PASS' for x in d['invariants'])
PY

cat "$work/r1-o0.txt"
cat "$work/legacy-o0.txt"
echo 'FGC19R_R1_BLOCKED_AUTHORITY_LOCK=PASS'
echo 'FGC19R_R1_FGC17_CONTRACT_LOCK=PASS'
echo 'FGC19R_R1_NO_HIDDEN_GLOBAL_IDENTITY=PASS'
echo 'FGC19R_R1_EXHAUSTION_GUARDS=PASS'
echo 'FGC19R_R1_O0_O2_IDENTITY=PASS'
echo 'FGC19R_R1_FGC19_BACKWARD_COMPATIBILITY=PASS'
echo 'FGC19R_R1_SCOPE_ALLOWLIST=PASS'
