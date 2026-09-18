#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=f7bd4d470d14bdedcbe60ef2b674fce4f1575e9c
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
TEST=tests/rom/test_f_rom0r_gravity_steady_seed.f90
CONTROL=tests/fmr/test_fmr44r_serialized_prescribed_qbot_runtime.f90
PREREG=integration/f-rom/F-ROM0R_R1_PREREGISTRATION.json
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-f-rom0r-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROM0R_EVIDENCE_DIR:-$ROOT/F-ROM0R_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "F_ROM0R_R1_GATE_FAIL $*" >&2; exit 1; }

if [[ "${GITHUB_EVENT_NAME:-}" == "pull_request" && -n "${GITHUB_HEAD_REF:-}" ]]; then
  CANDIDATE="$(git rev-parse "origin/$GITHUB_HEAD_REF")"
else
  CANDIDATE="$(git rev-parse HEAD)"
fi

git merge-base --is-ancestor "$BASE" "$CANDIDATE" || fail "R1 base not ancestor"
git diff --quiet "$BASE...$CANDIDATE" -- src reference || fail "R1 mutated production/reference source"
echo "F_ROM0R_R1_PRODUCTION_REFERENCE_DELTA=NONE"

python3 - "$PREREG" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p["phase"]=="PREREGISTERED_BEFORE_EXECUTION"
assert p["materials"]==["B01","B14"]
assert p["geometry"]=={"nodes":16,"dz_cm":10.0,"depth_cm":160.0}
assert p["initial_state"]["effective_saturation"]==0.85
assert p["boundary"]["top_flux_expression"]=="-K(h0)"
assert p["boundary"]["bottom_flux_expression"]=="-K(h0)"
assert p["requested_observation_interval_day"]==0.0016
assert p["requested_intervals"]==8
assert p["r2_authorized_by_preregistration"] is False
assert p["threshold_retuning_after_execution_allowed"] is False
print("F_ROM0R_R1_PREREGISTRATION_LOCK=PASS")
PY

# Existing accepted-runtime control, unchanged.
python3 "$COMPILER"   --root "$ROOT"   --stub tests/fsi/fsi04_real_headcalc_stubs.f90   --target "$CONTROL"   --external-source src/legacy/b1_10_port/headcalc.f90   --build "$BUILD/control"   --opt 2
"$BUILD/control/rom0_test" >"$EVIDENCE/F-ROM0R_R1_RUNTIME_CONTROL.txt" 2>&1 || {
  cat "$EVIDENCE/F-ROM0R_R1_RUNTIME_CONTROL.txt" >&2
  fail "accepted-runtime control failed"
}
for marker in   'FMR44R_MODE2_EQUILIBRIUM_TRANSACTION=PASS'   'FMR44R_POSITIVE_QBOT_ACCEPTED_INFLOW=PASS'   'FMR44R_NEARBY_BOTTOM_MODE_FAIL_CLOSED=PASS'   'FMR44R_SERIALIZED_PRESCRIBED_QBOT_RUNTIME_GATE=PASS'; do
  grep -Fq "$marker" "$EVIDENCE/F-ROM0R_R1_RUNTIME_CONTROL.txt" || fail "missing control marker $marker"
done
echo "F_ROM0R_R1_RUNTIME_CONTROL=PASS"

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/rom0r_stubs_n16.f90" --nodes 16 --dz-cm 10

python3 "$COMPILER"   --root "$ROOT"   --stub "$BUILD/rom0r_stubs_n16.f90"   --target "$TEST"   --external-source src/legacy/b1_10_port/headcalc.f90   --build "$BUILD/r1"   --opt 2

EXE="$BUILD/r1/rom0_test"
for material in B01 B14; do
  out="$EVIDENCE/F-ROM0R_R1_${material}.txt"
  if ! "$EXE" "$material" >"$out" 2>&1; then
    cat "$out" >&2
    fail "R1 seed failed for $material"
  fi
  grep -Fq "F_ROM0R_R1_PASS|MATERIAL=$material" "$out" || {
    cat "$out" >&2
    fail "missing R1 pass marker for $material"
  }
  [[ "$(grep -Fc 'F_ROM0R_R1_ACCEPTED|' "$out")" == "8" ]] || fail "expected eight accepted intervals for $material"
  cat "$out"
done

python3 - "$EVIDENCE/F-ROM0R_R1_B01.txt" "$EVIDENCE/F-ROM0R_R1_B14.txt"   "$EVIDENCE/F-ROM0R_R1_RESULT.json" <<'PY'
import json,re,sys
def parse(path):
    case=None; storage=None; accepted=0
    for line in open(path):
        if line.startswith("F_ROM0R_R1_CASE|"):
            case=line.strip()
        elif line.startswith("F_ROM0R_R1_ACCEPTED|"):
            accepted+=1
        elif line.startswith("F_ROM0R_R1_STORAGE|"):
            d={}
            for token in line.strip().split("|")[1:]:
                k,v=token.split("=",1); d[k]=v
            storage=d
    if case is None or storage is None or accepted!=8:
        raise SystemExit(f"incomplete R1 evidence {path}")
    return {"file":path,"accepted_intervals":accepted,
            "max_abs_storage_drift_cm":float(storage["MAX_ABS_DRIFT_CM"]),
            "roundoff_envelope_cm":float(storage["ROUND_OFF_ENVELOPE_CM"])}
res={
 "schema":"swap5.f-rom0r.r1-result.v1",
 "decision":"PROCEED_TO_ROM0R_R2_PERTURBATION_PREREGISTRATION",
 "runtime_control":"PASS",
 "materials":{"B01":parse(sys.argv[1]),"B14":parse(sys.argv[2])},
 "rom1a_authorized":False,
 "production_source_mutation":"NONE"
}
open(sys.argv[3],"w").write(json.dumps(res,indent=2,sort_keys=True)+"\n")
print("F_ROM0R_R1_DECISION=PROCEED_TO_ROM0R_R2_PERTURBATION_PREREGISTRATION")
PY

sha256sum "$EVIDENCE"/*.txt "$EVIDENCE/F-ROM0R_R1_RESULT.json" >"$EVIDENCE/sha256.txt"
cat "$EVIDENCE/F-ROM0R_R1_RESULT.json"
echo "F_ROM0R_R1_GATE=PASS"
