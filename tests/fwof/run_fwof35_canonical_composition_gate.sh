#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof35-gate-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'git -C "$ROOT" worktree remove --force "$BUILD/fwof33" >/dev/null 2>&1 || true; rm -rf "$BUILD"' EXIT

CANONICAL_BASE="3144c35eb8c60f822cc363dc48c21591e14b4cf4"
FWO34_SOURCE="85c0f7838d56c63d49f16af8242bdf4cbe4219d9"
FWO33_CLOSEOUT="b75342a6b9d1249ba7c87b4692acabc97d11ed13"
FCI19_CANDIDATE_A="4a792636ef73d25c671c5e0953cefd11978cd0ec"
FCI19_PRESERVATION_HEAD="5d5ece58b2b8e053a270992ded52377dd524f9c4"
EXPECTED_CANONICAL_SRC_TREE="b0a17a9610ee82ea1900a3ff3db3b5ba215443ca"
EXPECTED_CANONICAL_REFERENCE_TREE="9d08625217d7c0a7385df9da6a04183bcd9cb9e6"
EXPECTED_FWO34_OUTPUT_SHA="d36bb86e5e2dfd3fde242321442cf7393efd3cd218259eeeb35c37cb1559d007"
EXPECTED_FWO33_OUTPUT_SHA="cfb21d02eff5086f0f17abdfe1813b116765ffc22856fe8d0e1037a7e0fc693f"

python3 - "$ROOT" "$CANONICAL_BASE" "$FCI19_CANDIDATE_A" "$EXPECTED_CANONICAL_SRC_TREE" "$EXPECTED_CANONICAL_REFERENCE_TREE" <<'PY'
import pathlib, subprocess, sys
root=pathlib.Path(sys.argv[1]); base=sys.argv[2]; candidate=sys.argv[3]
expected_src=sys.argv[4]; expected_ref=sys.argv[5]
merge_base=subprocess.check_output(['git','-C',str(root),'merge-base',base,'HEAD'], text=True).strip()
assert merge_base == base, (merge_base, base)
def rev(expr):
    return subprocess.check_output(['git','-C',str(root),'rev-parse',expr], text=True).strip()
assert rev(base+':src') == expected_src
assert rev(base+':reference') == expected_ref
assert rev(candidate+':src') == expected_src
assert rev(candidate+':reference') == expected_ref
expected={
 'src/crop/mod_wofost_actual_biomass_state.f90':'feab0672b38e1c9668ac418cbe9d800f032cf4d8',
 'src/crop/mod_wofost_crop_owner_state.f90':'31bb390a0b70bec0a3f525f1d704a2c53890f9b4',
 'src/crop/mod_wofost_one_day_structural_evolution.f90':'c1fd9704ca1617f1f34d41fd7ec38640cce81d94',
 'src/runtime/mod_fmr_wofost_accepted_window_lineage.f90':'0e3f5d506f24669cae731fe71eb1411abc8d9008',
 'tests/fwof/test_fwof34_accepted_window_runtime_lineage.f90':'44510fd1393653a39f22750c66843b95c655da19',
}
for path, want in expected.items():
    got=rev('HEAD:'+path)
    assert got == want, (path, got, want)
changed=subprocess.check_output(['git','-C',str(root),'diff','--name-only',base+'..HEAD','--','src','reference'], text=True).splitlines()
expected_delta=sorted([
 'src/crop/mod_wofost_actual_biomass_state.f90',
 'src/crop/mod_wofost_crop_owner_state.f90',
 'src/crop/mod_wofost_one_day_structural_evolution.f90',
 'src/runtime/mod_fmr_wofost_accepted_window_lineage.f90',
])
assert sorted(changed) == expected_delta, (sorted(changed), expected_delta)
print('FWOF35_CANONICAL_FCI19_TREE_AND_EXACT_DONOR_BLOBS=PASS')
PY

TX="$ROOT/src/transaction/mod_transaction_reference.f90"
CONTRACTS="$ROOT/src/runtime/mod_canonical_contracts.f90"
CANONICAL_RUNTIME="$ROOT/src/runtime/mod_canonical_interval_runtime.f90"
KERNEL="$ROOT/src/kernel/mod_kernel_transactions.f90"
BIOMASS="$ROOT/src/crop/mod_wofost_actual_biomass_state.f90"
OWNER="$ROOT/src/crop/mod_wofost_crop_owner_state.f90"
STRUCTURAL="$ROOT/src/crop/mod_wofost_one_day_structural_evolution.f90"
LINEAGE="$ROOT/src/runtime/mod_fmr_wofost_accepted_window_lineage.f90"
TEST="$ROOT/tests/fwof/test_fwof34_accepted_window_runtime_lineage.f90"
COMMON=(-std=f2008 -Wall -Wextra -Werror -ffree-line-length-none -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

for OPT in o0 o2; do
  FLAG="-O0"; [[ "$OPT" == "o2" ]] && FLAG="-O2"
  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/$OPT" \
    "$TX" "$CONTRACTS" "$CANONICAL_RUNTIME" "$KERNEL" \
    "$BIOMASS" "$OWNER" "$STRUCTURAL" "$LINEAGE" "$TEST" \
    -o "$BUILD/test_$OPT"
  "$BUILD/test_$OPT" > "$BUILD/out_$OPT.txt"
  cat "$BUILD/out_$OPT.txt"
  echo "FWOF35_${OPT^^}=PASS"
done

cmp "$BUILD/out_o0.txt" "$BUILD/out_o2.txt"
echo 'FWOF35_O0_O2_OUTPUT_IDENTITY=PASS'
SHA=$(sha256sum "$BUILD/out_o0.txt" | awk '{print $1}')
[[ "$SHA" == "$EXPECTED_FWO34_OUTPUT_SHA" ]]
echo "FWOF35_FWO34_EXACT_TRANSCRIPT_IDENTITY=PASS SHA256=$SHA"

# Use the exact already-qualified F-CI19 composition-preservation harness as the
# behavioral oracle for the current canonical transaction/runtime source tree.
# Historical gates remain untouched. Only the preservation harness' Candidate-A
# source-identity assertions are adapted in the disposable working tree so they
# admit exactly the four byte-locked F-WOF donor additions and nothing else.
git -C "$ROOT" archive "$FCI19_PRESERVATION_HEAD" tests tools integration/f-kt | tar -x -C "$ROOT"
FCI19_BASE="$ROOT/tests/fci/run_fci19_candidate_a_preservation_gate.sh"
FCI19_V2="$ROOT/tests/fci/run_fci19_candidate_a_preservation_gate_v2.sh"
[[ "$(git -C "$ROOT" hash-object "$FCI19_BASE")" == "$(git -C "$ROOT" rev-parse "$FCI19_PRESERVATION_HEAD:tests/fci/run_fci19_candidate_a_preservation_gate.sh")" ]]
[[ "$(git -C "$ROOT" hash-object "$FCI19_V2")" == "$(git -C "$ROOT" rev-parse "$FCI19_PRESERVATION_HEAD:tests/fci/run_fci19_candidate_a_preservation_gate_v2.sh")" ]]

python3 - "$FCI19_BASE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text(encoding='utf-8')
allowed='''cat > "$BUILD/fwof35-allowed-source-delta.txt" <<'EOF'\nsrc/crop/mod_wofost_actual_biomass_state.f90\nsrc/crop/mod_wofost_crop_owner_state.f90\nsrc/crop/mod_wofost_one_day_structural_evolution.f90\nsrc/runtime/mod_fmr_wofost_accepted_window_lineage.f90\nEOF\ngit diff --name-only "$CANDIDATE"..HEAD -- src reference | sort > "$BUILD/fwof35-actual-source-delta.txt"\ndiff -u "$BUILD/fwof35-allowed-source-delta.txt" "$BUILD/fwof35-actual-source-delta.txt" || fail "F-WOF35 source delta exceeds exact donor closure"'''
old1='git diff --exit-code "$CANDIDATE"..HEAD -- src reference || fail "Candidate A production/reference source changed"'
new1=allowed+'\necho \'FWOF35_FCI19_EXACT_DONOR_ONLY_SOURCE_DELTA=PASS\''
if old1 not in s:
    raise SystemExit('F-CI19 initial source identity anchor missing')
s=s.replace(old1,new1,1)
old2='git diff --exit-code "$CANDIDATE"..HEAD -- src reference || fail "production/reference source drift during qualification"'
new2=allowed+'\necho \'FWOF35_FCI19_POST_REPLAY_SOURCE_DELTA_STABLE=PASS\''
if old2 not in s:
    raise SystemExit('F-CI19 final source identity anchor missing')
s=s.replace(old2,new2,1)
p.write_text(s, encoding='utf-8')
PY

bash "$FCI19_V2" > "$BUILD/fci19-preservation.out" 2>&1 || {
  cat "$BUILD/fci19-preservation.out" >&2
  exit 1
}
grep -Fq 'FCI19_GATE PASS_CANDIDATE_A_COMPOSITION_PRESERVATION' "$BUILD/fci19-preservation.out"
grep -Fq 'FCI19_HARD_MASS_PRESERVATION=PASS' "$BUILD/fci19-preservation.out"
grep -Fq 'FCI19_ROLLBACK_REPLAY_PRESERVATION=PASS' "$BUILD/fci19-preservation.out"
grep -Fq 'FCI19_O0_O2_PRESERVATION=PASS' "$BUILD/fci19-preservation.out"
grep -Fq 'FWOF35_FCI19_EXACT_DONOR_ONLY_SOURCE_DELTA=PASS' "$BUILD/fci19-preservation.out"
grep -Fq 'FWOF35_FCI19_POST_REPLAY_SOURCE_DELTA_STABLE=PASS' "$BUILD/fci19-preservation.out"
echo 'FWOF35_FCI19_CANONICAL_SEMANTIC_PRESERVATION=PASS'

# Preserve the exact historical F-WOF33 reference gate on its immutable tree.
git -C "$ROOT" worktree add --detach "$BUILD/fwof33" "$FWO33_CLOSEOUT" >/dev/null
bash "$BUILD/fwof33/tests/fwof/run_fwof33_two_phase_crop_window_gate.sh" > "$BUILD/fwof33.out"
grep -q 'FWOF33_TWO_PHASE_CROP_WINDOW_GATE PASS' "$BUILD/fwof33.out"
grep -q "FWOF33_OUTPUT_SHA256=$EXPECTED_FWO33_OUTPUT_SHA" "$BUILD/fwof33.out"
echo 'FWOF35_FWO33_EXACT_CLOSEOUT_REGRESSION=PASS'

echo 'FWOF35_CANONICAL_COMPOSITION_GATE PASS'
