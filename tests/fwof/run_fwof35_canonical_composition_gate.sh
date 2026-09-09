#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof35-gate-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'git -C "$ROOT" worktree remove --force "$BUILD/fwof33" >/dev/null 2>&1 || true; rm -rf "$BUILD"' EXIT

CANONICAL_BASE="3144c35eb8c60f822cc363dc48c21591e14b4cf4"
FWO34_SOURCE="85c0f7838d56c63d49f16af8242bdf4cbe4219d9"
FWO33_CLOSEOUT="b75342a6b9d1249ba7c87b4692acabc97d11ed13"
EXPECTED_FWO34_OUTPUT_SHA="d36bb86e5e2dfd3fde242321442cf7393efd3cd218259eeeb35c37cb1559d007"
EXPECTED_FWO33_OUTPUT_SHA="cfb21d02eff5086f0f17abdfe1813b116765ffc22856fe8d0e1037a7e0fc693f"

python3 - "$ROOT" "$CANONICAL_BASE" <<'PY'
import pathlib, subprocess, sys
root=pathlib.Path(sys.argv[1]); base=sys.argv[2]
merge_base=subprocess.check_output(['git','-C',str(root),'merge-base',base,'HEAD'], text=True).strip()
assert merge_base == base, (merge_base, base)
expected={
 'src/crop/mod_wofost_actual_biomass_state.f90':'feab0672b38e1c9668ac418cbe9d800f032cf4d8',
 'src/crop/mod_wofost_crop_owner_state.f90':'31bb390a0b70bec0a3f525f1d704a2c53890f9b4',
 'src/crop/mod_wofost_one_day_structural_evolution.f90':'c1fd9704ca1617f1f34d41fd7ec38640cce81d94',
 'src/runtime/mod_fmr_wofost_accepted_window_lineage.f90':'0e3f5d506f24669cae731fe71eb1411abc8d9008',
 'tests/fwof/test_fwof34_accepted_window_runtime_lineage.f90':'44510fd1393653a39f22750c66843b95c655da19',
}
for path, want in expected.items():
    got=subprocess.check_output(['git','-C',str(root),'rev-parse',f'HEAD:{path}'], text=True).strip()
    assert got == want, (path, got, want)
print('FWOF35_CANONICAL_ANCESTRY_AND_EXACT_DONOR_BLOBS=PASS')
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

# Re-run the transaction/runtime/mass/temporal canonical gates that exercise
# the owners changed on the F-CI19 lineage. These are behavioral regressions,
# not a weakening of any historical source-identity gate.
bash "$ROOT/tests/fci/run_fci03_gate.sh"
bash "$ROOT/tests/fci/run_fci04_gate.sh"
bash "$ROOT/tests/fci/run_fci10_gate.sh"
bash "$ROOT/tests/fci/run_fci12_gate.sh"
bash "$ROOT/tests/fci/run_fci13_gate.sh"
bash "$ROOT/tests/fci/run_fci14_gate.sh"
echo 'FWOF35_CANONICAL_TRANSACTION_RUNTIME_MASS_TEMPORAL_REGRESSION=PASS'

# Preserve the exact historical F-WOF33 reference gate on its immutable tree.
git -C "$ROOT" worktree add --detach "$BUILD/fwof33" "$FWO33_CLOSEOUT" >/dev/null
bash "$BUILD/fwof33/tests/fwof/run_fwof33_two_phase_crop_window_gate.sh" > "$BUILD/fwof33.out"
grep -q 'FWOF33_TWO_PHASE_CROP_WINDOW_GATE PASS' "$BUILD/fwof33.out"
grep -q "FWOF33_OUTPUT_SHA256=$EXPECTED_FWO33_OUTPUT_SHA" "$BUILD/fwof33.out"
echo 'FWOF35_FWO33_EXACT_CLOSEOUT_REGRESSION=PASS'

echo 'FWOF35_CANONICAL_COMPOSITION_GATE PASS'
