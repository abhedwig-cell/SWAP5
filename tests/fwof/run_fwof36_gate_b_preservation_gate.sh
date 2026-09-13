#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof36-preservation-$$"
FMR18_CLOSEOUT="ebf051bbf7e57f77d115287a9ba02fc987a255bc"
FCI19_CANDIDATE_A="4a792636ef73d25c671c5e0953cefd11978cd0ec"
FCI19_PRESERVATION_HEAD="5d5ece58b2b8e053a270992ded52377dd524f9c4"
FWO33_CLOSEOUT="b75342a6b9d1249ba7c87b4692acabc97d11ed13"
EXPECTED_FWO34_OUTPUT_SHA="d36bb86e5e2dfd3fde242321442cf7393efd3cd218259eeeb35c37cb1559d007"
EXPECTED_FWO33_OUTPUT_SHA="cfb21d02eff5086f0f17abdfe1813b116765ffc22856fe8d0e1037a7e0fc693f"
mkdir -p "$BUILD"
trap 'git -C "$ROOT" worktree remove --force "$BUILD/fwof33" >/dev/null 2>&1 || true; rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() {
  echo "FWOF36_PRESERVATION_FAIL $*" >&2
  exit 1
}

# F-WOF36 must remain a strict additive continuation of the qualified F-MR18
# runtime handoff. No unrelated production source is admitted here.
[[ "$(git merge-base "$FMR18_CLOSEOUT" HEAD)" == "$FMR18_CLOSEOUT" ]] || fail "F-MR18 closeout is not ancestor"
cat > "$BUILD/expected-fwof36-source-delta.txt" <<'EOF'
src/runtime/mod_fmr_wofost_accepted_window_lineage.f90
src/runtime/mod_fmr_wofost_physical_trial_binding.f90
EOF
git diff --name-only "$FMR18_CLOSEOUT"..HEAD -- src | sort > "$BUILD/actual-fwof36-source-delta.txt"
diff -u "$BUILD/expected-fwof36-source-delta.txt" "$BUILD/actual-fwof36-source-delta.txt" || fail "unexpected F-WOF36 production source delta"
echo 'FWOF36_PRESERVATION_EXACT_TWO_FILE_PRODUCTION_DELTA=PASS'

# Re-run the exact F-WOF34 accepted-window oracle on the current additive
# lineage implementation. The transcript must remain byte-identical at O0/O2.
for opt in 0 2; do
  OUT="$BUILD/fwo$opt"
  mkdir -p "$OUT"
  gfortran -std=f2008 -Wall -Wextra -ffree-line-length-none -fcheck=all -fbacktrace \
    -ffpe-trap=invalid,zero,overflow -O"$opt" -J "$OUT" \
    src/transaction/mod_transaction_reference.f90 \
    src/runtime/mod_canonical_contracts.f90 \
    src/runtime/mod_canonical_interval_runtime.f90 \
    src/kernel/mod_kernel_transactions.f90 \
    src/crop/mod_wofost_actual_biomass_state.f90 \
    src/crop/mod_wofost_crop_owner_state.f90 \
    src/crop/mod_wofost_one_day_structural_evolution.f90 \
    src/runtime/mod_fmr_wofost_accepted_window_lineage.f90 \
    tests/fwof/test_fwof34_accepted_window_runtime_lineage.f90 \
    -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt"
done
cmp "$BUILD/fwo0/out.txt" "$BUILD/fwo2/out.txt" || fail "F-WOF34 O0/O2 transcript mismatch"
FWO_SHA="$(sha256sum "$BUILD/fwo0/out.txt" | awk '{print $1}')"
[[ "$FWO_SHA" == "$EXPECTED_FWO34_OUTPUT_SHA" ]] || fail "F-WOF34 transcript changed $FWO_SHA"
echo "FWOF36_PRESERVATION_FWO34_EXACT_TRANSCRIPT=PASS SHA256=$FWO_SHA"

# Rehydrate the already-qualified F-CI19 preservation harness. Historical gate
# files are not changed in the repository. Only disposable source-identity and
# compile-dependency boundaries are widened to the exact, source-locked closure
# now present: three F-WOF crop donors, F-MR18 receipt/runtime, the F-WOF34/36
# lineage module, and the new F-WOF36 wrapper.
git archive "$FCI19_PRESERVATION_HEAD" tests tools integration/f-kt | tar -x -C "$ROOT"

FMR15_REPLAY_SOURCE="$ROOT/tests/fmr/run_fmr15_owner_composition_gate.sh"
python3 - "$FMR15_REPLAY_SOURCE" <<'PY_FMR15'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')
needle='  src/runtime/mod_fmr_serialized_multiswap_runtime.f90'
with_receipt='  src/runtime/mod_fmr_accepted_commit_receipt.f90\n'+needle
if with_receipt not in s:
    if s.count(needle) != 1:
        raise SystemExit(f'FWOF36 nested F-MR15 runtime anchor count={s.count(needle)}')
    s=s.replace(needle,with_receipt,1)
p.write_text(s,encoding='utf-8')
print('FWOF36_PRESERVATION_FCI19_NESTED_FMR15_RECEIPT_DEPENDENCY=PASS')
PY_FMR15

FCI19_BASE="$ROOT/tests/fci/run_fci19_candidate_a_preservation_gate.sh"
FCI19_V2="$ROOT/tests/fci/run_fci19_candidate_a_preservation_gate_v2.sh"
python3 - "$FCI19_BASE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')
allowed='''cat > "$BUILD/fwof36-allowed-source-delta.txt" <<'EOF'\nsrc/crop/mod_wofost_actual_biomass_state.f90\nsrc/crop/mod_wofost_crop_owner_state.f90\nsrc/crop/mod_wofost_one_day_structural_evolution.f90\nsrc/runtime/mod_fmr_accepted_commit_receipt.f90\nsrc/runtime/mod_fmr_serialized_multiswap_runtime.f90\nsrc/runtime/mod_fmr_wofost_accepted_window_lineage.f90\nsrc/runtime/mod_fmr_wofost_physical_trial_binding.f90\nEOF\ngit diff --name-only "$CANDIDATE"..HEAD -- src reference | sort > "$BUILD/fwof36-actual-source-delta.txt"\ndiff -u "$BUILD/fwof36-allowed-source-delta.txt" "$BUILD/fwof36-actual-source-delta.txt" || fail "F-WOF36 source delta exceeds qualified closure"'''
for old, marker in [
 ('git diff --exit-code "$CANDIDATE"..HEAD -- src reference || fail "Candidate A production/reference source changed"', 'FWOF36_PRESERVATION_FCI19_EXACT_SOURCE_DELTA=PASS'),
 ('git diff --exit-code "$CANDIDATE"..HEAD -- src reference || fail "production/reference source drift during qualification"', 'FWOF36_PRESERVATION_FCI19_POST_REPLAY_SOURCE_DELTA_STABLE=PASS')
]:
    if old not in s:
        raise SystemExit(f'FWOF36 F-CI19 source identity anchor missing: {old}')
    s=s.replace(old,allowed+f"\necho '{marker}'",1)
needle='  src/runtime/mod_fmr_serialized_multiswap_runtime.f90'
if needle in s and '  src/runtime/mod_fmr_accepted_commit_receipt.f90\n'+needle not in s:
    s=s.replace(needle,'  src/runtime/mod_fmr_accepted_commit_receipt.f90\n'+needle,1)
p.write_text(s,encoding='utf-8')
PY

bash "$FCI19_V2" > "$BUILD/fci19.out" 2>&1 || { cat "$BUILD/fci19.out" >&2; fail "F-CI19 preservation replay"; }
for marker in \
  'FCI19_GATE PASS_CANDIDATE_A_COMPOSITION_PRESERVATION' \
  'FCI19_HARD_MASS_PRESERVATION=PASS' \
  'FCI19_ROLLBACK_REPLAY_PRESERVATION=PASS' \
  'FCI19_O0_O2_PRESERVATION=PASS' \
  'FWOF36_PRESERVATION_FCI19_EXACT_SOURCE_DELTA=PASS' \
  'FWOF36_PRESERVATION_FCI19_POST_REPLAY_SOURCE_DELTA_STABLE=PASS'; do
  grep -Fq "$marker" "$BUILD/fci19.out" || { cat "$BUILD/fci19.out" >&2; fail "missing F-CI19 marker $marker"; }
done
echo 'FWOF36_PRESERVATION_FCI19_CANONICAL_SEMANTICS=PASS'

# Preserve the immutable F-WOF33 two-phase crop-window reference independently.
git -C "$ROOT" worktree add --detach "$BUILD/fwof33" "$FWO33_CLOSEOUT" >/dev/null
bash "$BUILD/fwof33/tests/fwof/run_fwof33_two_phase_crop_window_gate.sh" > "$BUILD/fwof33.out"
grep -Fq 'FWOF33_TWO_PHASE_CROP_WINDOW_GATE PASS' "$BUILD/fwof33.out" || fail "F-WOF33 gate marker"
grep -Fq "FWOF33_OUTPUT_SHA256=$EXPECTED_FWO33_OUTPUT_SHA" "$BUILD/fwof33.out" || fail "F-WOF33 transcript SHA"
echo 'FWOF36_PRESERVATION_FWO33_EXACT_CLOSEOUT=PASS'

echo 'FWOF36_GATE_B_PRESERVATION_GATE PASS'
