#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG_HEAD=813efe8eae04ae3839180837ee3d709ab4997dee
X1_EXEC_HEAD=fa15fce8a45901f4c9636e24f71542b5f9e1da77
X1_MANIFEST_BLOB=614fcd21dc6e46e5c241757ae1ed16b24c0e5e63
PREREG=integration/f-rom/ROM1X2_PREREGISTRATION.json
X1_STATUS=integration/f-rom/ROM1X1_STATUS.json
MANIFEST=integration/f-rom/ROM1X1_COLLISION_MANIFEST.json
X1_TEST=tests/rom/test_rom1x1_b14_material_transfer.f90
TEST=tests/rom/test_rom1x2_b14_predictive_ambiguity.f90
ANALYZER=tests/rom/analyze_rom1x2_b14_predictive_ambiguity.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rom1x2-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${ROM1X2_EVIDENCE_DIR:-$ROOT/ROM1X2_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "ROM1X2_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG_HEAD" HEAD || fail "X2 preregistration head not ancestor"
git diff --quiet "$PREREG_HEAD"...HEAD -- src reference || fail "X2 changed src/reference after preregistration"
git diff --quiet "$X1_EXEC_HEAD"...HEAD -- "$X1_TEST" || fail "X1 B14 generator drifted since qualified execution"
[[ "$(git hash-object "$MANIFEST")" == "$X1_MANIFEST_BLOB" ]] || fail "X1 collision manifest blob drift"
echo "ROM1X2_SOURCE_GENERATOR_AND_MANIFEST_FREEZE=PASS"

python3 - "$PREREG" "$X1_STATUS" "$MANIFEST" "$BUILD/starts.txt" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); x=json.load(open(sys.argv[2])); m=json.load(open(sys.argv[3]))
assert p["phase"]=="PREREGISTERED_BEFORE_B14_FUTURE_PROBE_EXECUTION"
assert p["frozen_pairs"]["pair_count"]==8
assert p["frozen_pairs"]["coordinate"]=="Z8_PLUS_G8"
assert p["frozen_pairs"]["reselection_allowed"] is False
assert p["future_probes"]["probes"]==["HOLD","TOP_PLUS","BOTTOM_HEAD_RISE","BOTTOM_HEAD_FALL"]
assert p["future_probes"]["horizons_steps"]==[4,16,64]
assert p["numerical_reference_scales"]["pairwise_response"]["total_storage_cm"]==7.105427357601002e-14
assert p["numerical_reference_scales"]["pairwise_response"]["upper_0_40cm_storage_cm"]==4.8537174279772444e-11
assert p["numerical_reference_scales"]["pairwise_response"]["lower_40_160cm_storage_cm"]==4.850164714298444e-11
assert x["decision"]=="ROM1X1_B14_MATERIAL_TRANSFER_STATE_SEPARATION_NO_GO"
assert x["B14_collision_count"]==351
assert len(m["pairs"])==8
starts=set()
for pair in m["pairs"]:
    for side in ("a","b"):
        h=pair[side]["history"]; step=int(pair[side]["step"])
        assert h.startswith("D") and 1<=int(h[1:])<=8 and 1<=step<=64
        starts.add((int(h[1:]),step))
with open(sys.argv[4],"w") as f:
    for ih,step in sorted(starts):
        f.write(f"{ih} {step}\n")
print("ROM1X2_AUTHORITY_LOCK=PASS")
print("ROM1X2_FROZEN_UNIQUE_STARTS="+str(len(starts)))
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10

python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90" \
  --target "$X1_TEST" --external-source src/legacy/b1_10_port/headcalc.f90 \
  --build "$BUILD/x1" --opt 2
"$BUILD/x1/rom0_test" > "$EVIDENCE/x1.txt" 2>&1 || {
  tail -n 500 "$EVIDENCE/x1.txt" >&2
  fail "X1 B14 reference regeneration"
}
grep -Fq 'ROM1X1_EXECUTION_COMPLETE=PASS' "$EVIDENCE/x1.txt" || fail "X1 regeneration completion"

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90" \
    --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$OUT" --opt "$opt"
  ROM1X2_STARTS_FILE="$BUILD/starts.txt" "$OUT/rom0_test" > "$EVIDENCE/o$opt.txt" 2>&1 || {
    tail -n 500 "$EVIDENCE/o$opt.txt" >&2
    fail "X2 B14 probe executable O$opt"
  }
  grep -Fq 'ROM1X2_EXECUTION_COMPLETE=PASS' "$EVIDENCE/o$opt.txt" || fail "X2 completion marker O$opt"
  grep -Fq 'ROM1X2_HELDOUT_USED=FALSE' "$EVIDENCE/o$opt.txt" || fail "X2 no B01 heldout interpretation marker O$opt"
  grep -Fq 'ROM1X2_B14_USED=TRUE' "$EVIDENCE/o$opt.txt" || fail "X2 B14 marker O$opt"
done
cmp "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" || fail "X2 O0/O2 stdout drift"

python3 "$ANALYZER" --input "$EVIDENCE/o2.txt" --repeat "$EVIDENCE/o0.txt" \
  --x1 "$EVIDENCE/x1.txt" --manifest "$MANIFEST" --prereg "$PREREG" \
  --output "$EVIDENCE/ROM1X2_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
cat "$EVIDENCE/ROM1X2_RESULT.json"
cp "$BUILD/starts.txt" "$EVIDENCE/frozen-starts.txt"
sha256sum "$EVIDENCE/x1.txt" "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" \
  "$EVIDENCE/ROM1X2_RESULT.json" "$EVIDENCE/frozen-starts.txt" > "$EVIDENCE/sha256.txt"
git diff --check "$PREREG_HEAD"...HEAD
echo "ROM1X2_EVIDENCE_PRESERVED=PASS"
