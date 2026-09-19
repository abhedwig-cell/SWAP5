#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CANONICAL_START=9bb73821bb78a04c759b763746b50a3f777cd416
PREREG=integration/f-rom/LARE_DYN0A_CQ_PREREGISTRATION.json
TEST=tests/rom/test_lare_dyn0a_reference.f90
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
VARIABLE=tests/rom/materialize_lare_variable_grid_stubs.py
ANALYZER=tests/rom/analyze_lare_dyn0a_coarse_temporal_qualification.py

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-lare-dyn0a-cq-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${LARE_DYN0A_CQ_EVIDENCE_DIR:-$ROOT/LARE_DYN0A_CQ_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "LARE_DYN0A_CQ_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$CANONICAL_START" HEAD || fail "canonical start not ancestor"
git diff --quiet "$CANONICAL_START"...HEAD -- src reference || fail "CQ changed src/reference"
echo 'LARE_DYN0A_CQ_SOURCE_FREEZE=PASS'

python3 - "$PREREG" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p["phase"]=="PREREGISTERED_BEFORE_COARSE_RICHARDS_TEMPORAL_REFINEMENT"
assert p["temporal_refinement"]["substeps_per_observation"]==[1,2,4,8,16]
assert "NO_SPATIAL_GRID_CHANGE" in p["firewalls"]
assert p["production_rom_authorized"] is False
print("LARE_DYN0A_CQ_AUTHORITY_LOCK=PASS")
PY

python3 "$VARIABLE" --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$BUILD/d3.f90" --layer-thickness-cm 140,10,10
python3 "$VARIABLE" --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$BUILD/d2.f90" --layer-thickness-cm 150,10

cases=()
for s in 1 2 3; do
  for f in 1 2 3 4; do
    cases+=("S${s}_B1_F${f}")
  done
done

python3 - "$EVIDENCE/execution_manifest.json" <<'PY'
import json,sys
cases=[f"S{s}_B1_F{f}" for s in (1,2,3) for f in (1,2,3,4)]
json.dump({
  "schema":"swap5.lare.dyn0a.cq.execution-manifest.v1",
  "cases":cases,
  "runs":{"d3":{c:{} for c in cases},"d2":{c:{} for c in cases}}
},open(sys.argv[1],"w"),indent=2,sort_keys=True)
PY

for geometry in d3 d2; do
  for opt in 0 2; do
    OUT="$BUILD/${geometry}-o${opt}"
    python3 "$COMPILER"       --root "$ROOT"       --stub "$BUILD/${geometry}.f90"       --target "$TEST"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$OUT"       --opt "$opt"
  done

  for case_id in "${cases[@]}"; do
    for substeps in 1 2 4 8 16; do
      statuses=()
      for opt in 0 2; do
        logfile="$EVIDENCE/${geometry}-${case_id}-sub${substeps}-o${opt}.txt"
        set +e
        LARE_DYN0A_BOTTOM_FILTER=1         LARE_DYN0A_CASE_FILTER="$case_id"         LARE_DYN0A_SUBSTEPS="$substeps"           "$BUILD/${geometry}-o${opt}/rom0_test" > "$logfile" 2>&1
        rc=$?
        set -e

        status="$(python3 - "$logfile" "$rc" <<'PY'
import re,sys
path,rc_raw=sys.argv[1:]
rc=int(rc_raw)
raw=open(path,errors='replace').read()
hs=[float(x) for x in re.findall(r'\|H=([^|\n]+)',raw)]
max_h=max(hs) if hs else float('-inf')
if rc==0:
    if 'LAREDYN0R_EXECUTION_COMPLETE=PASS' not in raw:
        raise SystemExit('successful process omitted completion marker')
    if raw.count('LAREDYN0R_STATE|')!=1024:
        raise SystemExit('successful process did not emit 1024 observation states')
    print('QUALIFIED')
else:
    if max_h >= -0.01 or 'LAREDYN0R_FAIL LAREDYN0R prospective representation bound' in raw:
        print('OUTSIDE_QUALIFIED_DOMAIN_NEAR_SATURATION')
    elif 'LAREDYN0R_FAIL ' in raw:
        print('BLOCKED_REFERENCE_NUMERICAL_QUALIFICATION')
    else:
        print('TECHNICAL_FAILURE')
PY
)"
        [[ "$status" != "TECHNICAL_FAILURE" ]] || { tail -n 100 "$logfile" >&2; fail "unexpected technical failure ${geometry} ${case_id} sub${substeps} O${opt}"; }
        statuses+=("$status")
      done

      [[ "${statuses[0]}" == "${statuses[1]}" ]] || fail "O0/O2 status drift ${geometry} ${case_id} sub${substeps}"

      if [[ "${statuses[0]}" == "QUALIFIED" ]]; then
        grep -E '^LAREDYN0R_(STATE|NODE|FALLBACK|HISTORY_PASS)' "$EVIDENCE/${geometry}-${case_id}-sub${substeps}-o0.txt" > "$BUILD/o0.norm"
        grep -E '^LAREDYN0R_(STATE|NODE|FALLBACK|HISTORY_PASS)' "$EVIDENCE/${geometry}-${case_id}-sub${substeps}-o2.txt" > "$BUILD/o2.norm"
        cmp "$BUILD/o0.norm" "$BUILD/o2.norm" || fail "O0/O2 scientific trace drift ${geometry} ${case_id} sub${substeps}"
      fi

      python3 - "$EVIDENCE/execution_manifest.json" "$geometry" "$case_id" "$substeps" "${statuses[0]}" <<'PY'
import json,sys
path,geom,case,sub,status=sys.argv[1:]
p=json.load(open(path))
p["runs"][geom][case][sub]={
  "status":status,
  "o0_file":f"{geom}-{case}-sub{sub}-o0.txt",
  "o2_file":f"{geom}-{case}-sub{sub}-o2.txt"
}
json.dump(p,open(path,"w"),indent=2,sort_keys=True)
PY
    done
  done
done

python3 "$ANALYZER"   --evidence-dir "$EVIDENCE"   --output "$EVIDENCE/LARE_DYN0A_CQ_RESULT.json" |
  tee "$EVIDENCE/analyzer.txt"

cat "$EVIDENCE/LARE_DYN0A_CQ_RESULT.json"
sha256sum "$EVIDENCE"/*.txt "$EVIDENCE"/*.json > "$EVIDENCE/sha256.txt"
git diff --check "$CANONICAL_START"...HEAD
echo 'LARE_DYN0A_CQ_GATE=PASS'
