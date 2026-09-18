#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG_COMMIT=4af53ee7b226435932ebb16d6df59f3ad33bc2c5
B1_EXEC_HEAD=01312dd2e72ff61123c0dcdfe99e1fda91e80861
B1_MANIFEST_BLOB=225fdaff18ae0119d3995f6ca950d4453d67fc75
PREREG=integration/f-rom/ROM1B2_PREREGISTRATION.json
B1_STATUS=integration/f-rom/ROM1B1_STATUS.json
B1_MANIFEST=integration/f-rom/ROM1B1_PAIR_MANIFEST.json
ROM1A_CLOSE=integration/f-rom/F-ROM1A_SUCCESSOR_CLOSEOUT.json
DISCOVERY_TEST=tests/rom/test_rom1ar1d3_discovery_fallback.f90
TEST=tests/rom/test_rom1b2_future_probe_adjudication.f90
ANALYZER=tests/rom/analyze_rom1b2_future_probe_adjudication.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rom1b2-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${ROM1B2_EVIDENCE_DIR:-$ROOT/ROM1B2_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "ROM1B2_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "B2 preregistration not ancestor"
git diff --quiet "$PREREG_COMMIT"...HEAD -- src reference || fail "B2 changed src/reference"
git diff --quiet "$B1_EXEC_HEAD"...HEAD -- "$DISCOVERY_TEST" || fail "B2 discovery generator drifted since B1 execution"
[[ "$(git hash-object "$B1_MANIFEST")" == "$B1_MANIFEST_BLOB" ]] || fail "B1 pair manifest blob drift"
echo "ROM1B2_SOURCE_GENERATOR_AND_MANIFEST_FREEZE=PASS"

python3 - "$PREREG" "$B1_STATUS" "$B1_MANIFEST" "$ROM1A_CLOSE" "$BUILD/starts.txt" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); b=json.load(open(sys.argv[2])); m=json.load(open(sys.argv[3])); c=json.load(open(sys.argv[4]))
assert p["phase"]=="PREREGISTERED_BEFORE_FUTURE_PROBE_EXECUTION"
assert b["decision"]=="ROM1B1_COLLISION_CENSUS_COMPLETE"
assert b["pair_manifests_frozen"] is True
assert c["decision"]=="PROCEED_TO_ROM1B"
assert p["future_probes"]["probes"]==["HOLD","TOP_PLUS","BOTTOM_HEAD_RISE","BOTTOM_HEAD_FALL"]
assert p["future_probes"]["horizons_steps"]==[4,16,64]
assert p["data_firewall"] if "data_firewall" in p else True
starts=set()
for z in ("Z1","Z2","Z4","Z8"):
    assert len(m["manifests"][z])==8
    for pair in m["manifests"][z]:
        for side in ("a","b"):
            h=pair[side]["history"]; step=int(pair[side]["step"])
            assert h.startswith("D") and 1<=int(h[1:])<=8 and 1<=step<=64
            starts.add((int(h[1:]),step))
with open(sys.argv[5],"w") as f:
    for ih,step in sorted(starts):
        f.write(f"{ih} {step}\n")
print("ROM1B2_AUTHORITY_LOCK=PASS")
print("ROM1B2_FROZEN_UNIQUE_STARTS="+str(len(starts)))
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10

python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90" \
  --target "$DISCOVERY_TEST" --external-source src/legacy/b1_10_port/headcalc.f90 \
  --build "$BUILD/discovery" --opt 2
"$BUILD/discovery/rom0_test" > "$EVIDENCE/discovery.txt" 2>&1 || {
  tail -n 300 "$EVIDENCE/discovery.txt" >&2
  fail "B2 frozen discovery regeneration"
}

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90" \
    --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$OUT" --opt "$opt"
  ROM1B2_STARTS_FILE="$BUILD/starts.txt" "$OUT/rom0_test" > "$EVIDENCE/o$opt.txt" 2>&1 || {
    tail -n 500 "$EVIDENCE/o$opt.txt" >&2
    fail "B2 probe executable O$opt"
  }
  grep -Fq 'ROM1B2_EXECUTION_COMPLETE=PASS' "$EVIDENCE/o$opt.txt" || fail "B2 completion marker O$opt"
  grep -Fq 'ROM1B2_HELDOUT_USED=FALSE' "$EVIDENCE/o$opt.txt" || fail "B2 heldout firewall O$opt"
  grep -Fq 'ROM1B2_B14_USED=FALSE' "$EVIDENCE/o$opt.txt" || fail "B2 B14 firewall O$opt"
done
cmp "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" || fail "B2 O0/O2 stdout drift"

python3 "$ANALYZER" --input "$EVIDENCE/o2.txt" --repeat "$EVIDENCE/o0.txt" \
  --discovery "$EVIDENCE/discovery.txt" --manifest "$B1_MANIFEST" --prereg "$PREREG" \
  --output "$EVIDENCE/ROM1B2_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
cat "$EVIDENCE/ROM1B2_RESULT.json"
cp "$BUILD/starts.txt" "$EVIDENCE/frozen-starts.txt"
sha256sum "$EVIDENCE/discovery.txt" "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" \
  "$EVIDENCE/ROM1B2_RESULT.json" "$EVIDENCE/frozen-starts.txt" > "$EVIDENCE/sha256.txt"
git diff --check "$PREREG_COMMIT"...HEAD
echo "ROM1B2_EVIDENCE_PRESERVED=PASS"
