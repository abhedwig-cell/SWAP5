#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CANONICAL_START=9bb73821bb78a04c759b763746b50a3f777cd416
PREREG=integration/f-rom/LARE_CORICHARDS_Q1_PREREGISTRATION.json
TEST=tests/rom/test_lare_dyn0a_reference.f90
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
VARIABLE=tests/rom/materialize_lare_variable_grid_stubs.py
CASE_ID="${1:?case required}"
THICKNESS='10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10'
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-corichards-q1-r16-${CASE_ID}-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${LARE_CORICHARDS_Q1_CASE_EVIDENCE_DIR:-$ROOT/LARE_CORICHARDS_Q1_R16_${CASE_ID}_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "LARE_CORICHARDS_Q1_R16_CASE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$CANONICAL_START" HEAD || fail "frozen scientific base not ancestor"
git diff --quiet "$CANONICAL_START"...HEAD -- src reference || fail "shard changed src/reference"
python3 - "$PREREG" "$CASE_ID" <<'PY'
import json,sys,re
p=json.load(open(sys.argv[1])); case=sys.argv[2]
assert p["phase"]=="PREREGISTERED_AFTER_C4O_BEFORE_HIGHER_DIMENSION_CORICHARDS_VIABILITY_CURVE"
r16=next(x for x in p["viability_ladder"] if x["id"]=="R16")
assert r16["dimension"]==16 and r16["thickness_cm"]==[10]*16
assert re.fullmatch(r"S[123]_B1_F[1234]",case)
assert p["numerical_route"]["temporal_substeps_per_observation"]==[1,2,4,8,16]
print("LARE_CORICHARDS_Q1_R16_SHARD_AUTHORITY_LOCK=PASS")
PY

python3 "$VARIABLE" --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$BUILD/grid.f90" --layer-thickness-cm "$THICKNESS"
for opt in 0 2; do
  python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/grid.f90" --target "$TEST"     --external-source src/legacy/b1_10_port/headcalc.f90 --build "$BUILD/o${opt}" --opt "$opt"
done

python3 - "$EVIDENCE/case_manifest.json" "$CASE_ID" <<'PY'
import json,sys
path,case=sys.argv[1:]
json.dump({"schema":"swap5.lare.corichards.q1.r16-case-manifest.v1","member":"R16","case":case,"runs":{}},open(path,"w"),indent=2,sort_keys=True)
PY

for substeps in 1 2 4 8 16; do
  statuses=()
  files=()
  for opt in 0 2; do
    logfile="$EVIDENCE/R16-${CASE_ID}-sub${substeps}-o${opt}.txt"
    set +e
    LARE_DYN0A_BOTTOM_FILTER=1     LARE_DYN0A_CASE_FILTER="$CASE_ID"     LARE_DYN0A_SUBSTEPS="$substeps"       "$BUILD/o${opt}/rom0_test" > "$logfile" 2>&1
    rc=$?
    set -e
    status="$(python3 - "$logfile" "$rc" <<'PY'
import re,sys
path,rc_raw=sys.argv[1:]; rc=int(rc_raw)
raw=open(path,errors="replace").read()
hs=[float(x) for x in re.findall(r'\|H=([^|\n]+)',raw)]
max_h=max(hs) if hs else float("-inf")
if rc==0:
    if 'LAREDYN0R_EXECUTION_COMPLETE=PASS' not in raw or raw.count('LAREDYN0R_STATE|')!=1024:
        print('TECHNICAL_FAILURE')
    else:
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
    statuses+=("$status"); files+=("$logfile")
  done

  [[ "${statuses[0]}" == "${statuses[1]}" ]] || fail "O0/O2 status drift ${CASE_ID} sub${substeps}"
  status_identity=true
  trace_identity=null
  if [[ "${statuses[0]}" == "QUALIFIED" ]]; then
    grep -E '^LAREDYN0R_(STATE|NODE|FALLBACK|HISTORY_PASS)' "${files[0]}" > "$BUILD/o0.norm"
    grep -E '^LAREDYN0R_(STATE|NODE|FALLBACK|HISTORY_PASS)' "${files[1]}" > "$BUILD/o2.norm"
    cmp "$BUILD/o0.norm" "$BUILD/o2.norm" || fail "O0/O2 trace drift ${CASE_ID} sub${substeps}"
    trace_identity=true
  fi

  python3 - "$EVIDENCE/case_manifest.json" "$substeps" "${statuses[0]}" "$status_identity" "$trace_identity" "$CASE_ID" <<'PY'
import json,sys
path,sub,status,sid,tid,case=sys.argv[1:]
p=json.load(open(path))
p["runs"][sub]={
  "status":status,
  "o0_file":f"R16-{case}-sub{sub}-o0.txt",
  "o2_file":f"R16-{case}-sub{sub}-o2.txt",
  "o0_o2_status_identity":sid=="true",
  "o0_o2_scientific_trace_identity":None if tid=="null" else tid=="true",
}
json.dump(p,open(path,"w"),indent=2,sort_keys=True)
PY
done
sha256sum "$EVIDENCE"/* > "$EVIDENCE/sha256.txt"
echo 'LARE_CORICHARDS_Q1_R16_SHARD_GATE=PASS'
