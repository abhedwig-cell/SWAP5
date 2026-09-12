#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

candidate_branch="work/f-gc19r-prepared-ledger-publication"
candidate_head="d92b84c815f9e6c5509d280953b4d659c5cb14ac"
candidate_source_blob="b0887577774d8c015ac9b1324b547e880059789e"
fgc17_blob="fc598d14eabafcb025bb55621f7b00d6d1816f10"
base_candidate="$candidate_head"

live_candidate="$(git ls-remote origin "refs/heads/$candidate_branch" | awk '{print $1}')"
test "$live_candidate" = "$candidate_head" || { echo "FGC19R_CANDIDATE_RACE_FAIL expected=$candidate_head actual=$live_candidate" >&2; exit 20; }
test "$(git rev-parse HEAD:src/runtime/mod_groundwater_interface_mass_ledger.f90)" = "$candidate_source_blob"
test "$(git rev-parse HEAD:src/runtime/mod_groundwater_coupling_contract.f90)" = "$fgc17_blob"

allowed=(
  ".github/workflows/fgc19r-prepared-ledger-publication-owner-qualification.yml"
  "integration/f-gc/F-GC19R_OWNER_QUALIFICATION_ARCHITECTURE_AUDIT.json"
  "integration/f-gc/F-GC19R_OWNER_QUALIFICATION_STATUS.json"
  "tests/fgc/run_fgc19r_prepared_ledger_publication_owner_qualification.sh"
  "tests/fgc/test_fgc19r_prepared_ledger_publication_adversarial.f90"
)
mapfile -t changed < <(git diff --name-only "$base_candidate..HEAD")
for path in "${changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do [[ "$path" == "$candidate" ]] && ok=1 && break; done
  [[ "$ok" -eq 1 ]] || { echo "FGC19R_QUAL_SCOPE_FAIL unexpected path: $path" >&2; exit 21; }
done

! grep -Eiq 'MODFLOW|\.swp|midnight|86400' src/runtime/mod_groundwater_interface_mass_ledger.f90
! grep -Eiq 'mass_tolerance|balance_tolerance' src/runtime/mod_groundwater_interface_mass_ledger.f90

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
compile_and_run() {
  local opt="$1"
  local out="$2"
  local dir="$work/$opt"
  mkdir -p "$dir"
  gfortran "-$opt" -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -J"$dir" -I"$dir" \
    src/runtime/mod_groundwater_coupling_contract.f90 \
    src/runtime/mod_groundwater_interface_mass_ledger.f90 \
    tests/fgc/test_fgc19r_prepared_ledger_publication_adversarial.f90 \
    -o "$dir/test_fgc19r_owner_qualification"
  "$dir/test_fgc19r_owner_qualification" > "$out"
}

compile_and_run O0 "$work/o0.txt"
compile_and_run O2 "$work/o2.txt"
diff -u "$work/o0.txt" "$work/o2.txt"
grep -q '^FGC19R_FOREIGN_PREPARED_HANDLE_ACCEPTANCE=REPRODUCED$' "$work/o0.txt"
grep -q '^FGC19R_SAME_LEDGER_STALE_REPLAY=REJECTED$' "$work/o0.txt"
grep -q '^FGC19R_ABORT_COMMITTED_MASS_PRESERVATION=PASS$' "$work/o0.txt"
grep -q '^FGC19R_EXACT_ACTION_REACTION=PASS$' "$work/o0.txt"
grep -q '^FGC19R_OWNER_QUALIFICATION=BLOCKED_REMEDIATION_REQUIRED$' "$work/o0.txt"

python3 - <<'PY'
import json
p='integration/f-gc/F-GC19R_OWNER_QUALIFICATION_ARCHITECTURE_AUDIT.json'
d=json.load(open(p))
assert d['overall']=='BLOCKED_REMEDIATION_REQUIRED'
assert d['mass_conservation']=='BLOCKED_UNTIL_FOREIGN_HANDLE_PROVENANCE_IS_CLOSED'
ids=[x['id'] for x in d['invariants']]
assert ids==list(range(1,31))
blocked={x['id'] for x in d['invariants'] if x['status']=='BLOCKED'}
assert blocked=={7,11,13,26,29}
PY

cat "$work/o0.txt"
echo 'FGC19R_CANDIDATE_HEAD_LOCK=PASS'
echo 'FGC19R_SOURCE_BLOB_LOCK=PASS'
echo 'FGC19R_FGC17_CONTRACT_LOCK=PASS'
echo 'FGC19R_O0_O2_IDENTITY=PASS'
echo 'FGC19R_QUALIFICATION_SCOPE_ALLOWLIST=PASS'
