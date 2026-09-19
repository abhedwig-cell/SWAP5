#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CANONICAL_START=9bb73821bb78a04c759b763746b50a3f777cd416
PREREG=integration/f-rom/LARE_CORICHARDS_Q1_PREREGISTRATION.json
TEST=tests/rom/test_lare_dyn0a_reference.f90
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
VARIABLE=tests/rom/materialize_lare_variable_grid_stubs.py
ANALYZER=tests/rom/analyze_lare_corichards_q1_member.py

MEMBER="${1:?member required}"
THICKNESS="${2:?comma-separated thickness required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-corichards-q1-${MEMBER}-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${LARE_CORICHARDS_Q1_EVIDENCE_DIR:-$ROOT/LARE_CORICHARDS_Q1_${MEMBER}_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "LARE_CORICHARDS_Q1_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$CANONICAL_START" HEAD || fail "frozen scientific base not ancestor"
git diff --quiet "$CANONICAL_START"...HEAD -- src reference || fail "Q1 changed src/reference"
echo 'LARE_CORICHARDS_Q1_SOURCE_FREEZE=PASS'

python3 - "$PREREG" "$MEMBER" "$THICKNESS" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); member=sys.argv[2]; thick=[float(x) for x in sys.argv[3].split(",")]
assert p["phase"]=="PREREGISTERED_AFTER_C4O_BEFORE_HIGHER_DIMENSION_CORICHARDS_VIABILITY_CURVE"
spec=next(x for x in p["viability_ladder"] if x["id"]==member)
assert [float(x) for x in spec["thickness_cm"]]==thick
assert len(thick)==spec["dimension"] and abs(sum(thick)-160.0)<=1e-12
assert p["numerical_route"]["temporal_substeps_per_observation"]==[1,2,4,8,16]
assert "NO_USE_OF_LARE_ERROR_TO_SELECT_GRID_OR_DT" in p["firewalls"]
assert p["hydrological_comparison_authorized"] is False
print("LARE_CORICHARDS_Q1_AUTHORITY_LOCK=PASS")
PY

python3 "$VARIABLE" --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$BUILD/grid.f90" --layer-thickness-cm "$THICKNESS"
for opt in 0 2; do
  python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/grid.f90" --target "$TEST"     --external-source src/legacy/b1_10_port/headcalc.f90 --build "$BUILD/o${opt}" --opt "$opt"
done

cases=()
for s in 1 2 3; do for f in 1 2 3 4; do cases+=("S${s}_B1_F${f}"); done; done

python3 - "$EVIDENCE/execution_manifest.json" "$MEMBER" "${cases[@]}" <<'PY'
import json,sys
path,member,*cases=sys.argv[1:]
json.dump({"schema":"swap5.lare.corichards.q1.execution-manifest.v1","member":member,"cases":cases,"runs":{c:{} for c in cases}},open(path,"w"),indent=2,sort_keys=True)
PY

for case_id in "${cases[@]}"; do
  for substeps in 1 2 4 8 16; do
    statuses=()
    files=()
    for opt in 0 2; do
      logfile="$EVIDENCE/${MEMBER}-${case_id}-sub${substeps}-o${opt}.txt"
      set +e
      LARE_DYN0A_BOTTOM_FILTER=1       LARE_DYN0A_CASE_FILTER="$case_id"       LARE_DYN0A_SUBSTEPS="$substeps"         "$BUILD/o${opt}/rom0_test" > "$logfile" 2>&1
      rc=$?
      set -e
      status="$(python3 - "$logfile" "$rc" <<'PY'
import re,sys
path,rc_raw=sys.argv[1:]; rc=int(rc_raw)
raw=open(path,errors="replace").read()
hs=[float(x) for x in re.findall(r'\|H=([^|\n]+)',raw)]
max_h=max(hs) if hs else float("-inf")
if rc==0:
    if 'LAREDYN0R_EXECUTION_COMPLETE=PASS' not in raw: print('TECHNICAL_FAILURE')
    elif raw.count('LAREDYN0R_STATE|')!=1024: print('TECHNICAL_FAILURE')
    else: print('QUALIFIED')
else:
    if max_h >= -0.01 or 'LAREDYN0R_FAIL LAREDYN0R prospective representation bound' in raw:
        print('OUTSIDE_QUALIFIED_DOMAIN_NEAR_SATURATION')
    elif 'LAREDYN0R_FAIL ' in raw:
        print('BLOCKED_REFERENCE_NUMERICAL_QUALIFICATION')
    else:
        print('TECHNICAL_FAILURE')
PY
)"
      statuses+=("$status"); files+=("$logfile")
    done

    status_identity=false
    trace_identity=null
    if [[ "${statuses[0]}" == "${statuses[1]}" ]]; then status_identity=true; fi
    [[ "$status_identity" == true ]] || fail "O0/O2 status drift ${MEMBER} ${case_id} sub${substeps}: ${statuses[*]}"

    if [[ "${statuses[0]}" == "QUALIFIED" ]]; then
      grep -E '^LAREDYN0R_(STATE|NODE|FALLBACK|HISTORY_PASS)' "${files[0]}" > "$BUILD/o0.norm"
      grep -E '^LAREDYN0R_(STATE|NODE|FALLBACK|HISTORY_PASS)' "${files[1]}" > "$BUILD/o2.norm"
      if cmp "$BUILD/o0.norm" "$BUILD/o2.norm"; then trace_identity=true; else fail "O0/O2 trace drift ${MEMBER} ${case_id} sub${substeps}"; fi
    fi

    python3 - "$EVIDENCE/execution_manifest.json" "$case_id" "$substeps" "${statuses[0]}" "$status_identity" "$trace_identity" "$MEMBER" <<'PY'
import json,sys
path,case,sub,status,sid,tid,member=sys.argv[1:]
p=json.load(open(path))
p["runs"][case][sub]={
  "status":status,
  "o0_file":f"{member}-{case}-sub{sub}-o0.txt",
  "o2_file":f"{member}-{case}-sub{sub}-o2.txt",
  "o0_o2_status_identity":sid=="true",
  "o0_o2_scientific_trace_identity":None if tid=="null" else tid=="true",
}
json.dump(p,open(path,"w"),indent=2,sort_keys=True)
PY
  done
done

python3 "$ANALYZER" --evidence-dir "$EVIDENCE" --prereg "$PREREG" --output "$EVIDENCE/LARE_CORICHARDS_Q1_${MEMBER}_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
sha256sum "$EVIDENCE"/*.json "$EVIDENCE"/analyzer.txt > "$EVIDENCE/result_sha256.txt"
git diff --check "$CANONICAL_START"...HEAD
echo 'LARE_CORICHARDS_Q1_MEMBER_GATE=PASS'
