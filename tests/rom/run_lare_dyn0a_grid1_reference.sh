#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CANONICAL_START=9bb73821bb78a04c759b763746b50a3f777cd416
PRED=integration/f-rom/LARE_DYN0A_GRID1_PREDICTIONS.json
PREREG=integration/f-rom/LARE_DYN0A_GRID1_PREREGISTRATION.json
TEST=tests/rom/test_lare_dyn0a_grid1_reference.f90
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
UNIFORM=tests/rom/materialize_f_rom0_headcalc_stubs.py

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-lare-dyn0a-grid1-ref-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${LARE_DYN0A_GRID1_REFERENCE_DIR:-$ROOT/LARE_DYN0A_GRID1_REFERENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "LARE_DYN0A_GRID1_REFERENCE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$CANONICAL_START" HEAD || fail "canonical start not ancestor"
git diff --quiet "$CANONICAL_START"...HEAD -- src reference || fail "GRID1 changed src/reference"

python3 - "$PREREG" "$PRED" "$BUILD/cases.tsv" <<'PY'
import json,sys
pre=json.load(open(sys.argv[1]))
pred=json.load(open(sys.argv[2]))
assert pre["phase"]=="PREREGISTERED_BEFORE_NEW_PATH_GUIDED_GRID_REFERENCE_TRAJECTORIES"
assert pred["generated_before_new_reference_trajectory"] is True
assert pred["response_data_used"] is False
assert pred["selected_scale"]=="PATH_GEOMETRIC_D"
assert pred["qualified_prediction_count"]==12
idx={0.65:1,0.85:2,0.95:3}
rows=[]
for material,cases in pred["materials"].items():
    for row in cases:
        if row["status"]!="GRID_PREDICTION_QUALIFIED":
            continue
        fi=2 if row["forcing"]=="WET" else 3
        rows.append((material,f"S{idx[float(row['se0'])]}_B1_F{fi}"))
assert len(rows)==12
with open(sys.argv[3],"w") as f:
    for material,case in rows:
        f.write(f"{material}\t{case}\n")
print("LARE_DYN0A_GRID1_PREDICTION_LOCK=PASS cases=12")
PY

python3 "$UNIFORM"   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/fine.f90"   --nodes 16   --dz-cm 10

: > "$EVIDENCE/status.tsv"
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER"     --root "$ROOT"     --stub "$BUILD/fine.f90"     --target "$TEST"     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT"     --opt "$opt"

  while IFS=$'\t' read -r material case_id; do
    logfile="$EVIDENCE/fine-${material}-${case_id}-o${opt}.txt"
    set +e
    LARE_DYN0A_MATERIAL="$material"     LARE_DYN0A_BOTTOM_FILTER=1     LARE_DYN0A_CASE_FILTER="$case_id"       "$OUT/rom0_test" > "$logfile" 2>&1
    rc=$?
    set -e

    status="$(python3 - "$logfile" "$rc" <<'PY'
import re,sys
path,rc_raw=sys.argv[1:]
rc=int(rc_raw)
raw=open(path,errors='replace').read()
hs=[float(x) for x in re.findall(r'\|H=([^|\n]+)',raw)]
max_h=max(hs) if hs else float('-inf')
states=raw.count('LAREDYN0R_STATE|')
nodes=raw.count('LAREDYN0R_NODE|')
if rc==0:
    if 'LAREDYN0R_EXECUTION_COMPLETE=PASS' not in raw:
        raise SystemExit('successful process omitted completion marker')
    if states!=1024 or nodes!=1024*16:
        raise SystemExit(f'qualified structure mismatch states={states} nodes={nodes}')
    print('OUTSIDE_QUALIFIED_DOMAIN_NEAR_SATURATION' if max_h>=-0.01 else 'QUALIFIED')
else:
    known_domain=('LAREDYN0R_FAIL LAREDYN0R prospective representation bound' in raw or max_h>=-0.01)
    if known_domain:
        print('OUTSIDE_QUALIFIED_DOMAIN_NEAR_SATURATION')
    elif 'LAREDYN0R_FAIL ' in raw:
        print('BLOCKED_REFERENCE_NUMERICAL_QUALIFICATION')
    else:
        tail='\n'.join(raw.splitlines()[-40:])
        raise SystemExit('unexpected technical GRID1 Reference failure\n'+tail)
PY
)" || fail "$material $case_id O$opt classification"
    printf '%s\t%s\t%s\t%s\n' "$material" "$case_id" "$opt" "$status" >> "$EVIDENCE/status.tsv"
  done < "$BUILD/cases.tsv"
done

while IFS=$'\t' read -r material case_id; do
  s0="$(awk -F '\t' -v m="$material" -v c="$case_id" '$1==m && $2==c && $3=="0"{print $4}' "$EVIDENCE/status.tsv")"
  s2="$(awk -F '\t' -v m="$material" -v c="$case_id" '$1==m && $2==c && $3=="2"{print $4}' "$EVIDENCE/status.tsv")"
  [[ -n "$s0" && "$s0" == "$s2" ]] || fail "$material $case_id O0/O2 status drift"
  grep -E '^LAREDYN0R_(STATE|NODE|FALLBACK|HISTORY_PASS|FAIL|MATERIAL)' "$EVIDENCE/fine-${material}-${case_id}-o0.txt" > "$BUILD/o0.norm" || true
  grep -E '^LAREDYN0R_(STATE|NODE|FALLBACK|HISTORY_PASS|FAIL|MATERIAL)' "$EVIDENCE/fine-${material}-${case_id}-o2.txt" > "$BUILD/o2.norm" || true
  cmp "$BUILD/o0.norm" "$BUILD/o2.norm" || fail "$material $case_id O0/O2 scientific trace drift"
done < "$BUILD/cases.tsv"
echo 'LARE_DYN0A_GRID1_CASEWISE_O0_O2_IDENTITY=PASS'

python3 - "$EVIDENCE" "$BUILD/cases.tsv" "$PRED" <<'PY'
import json,pathlib,re,sys
root=pathlib.Path(sys.argv[1]); case_file=pathlib.Path(sys.argv[2])
pred=json.load(open(sys.argv[3]))
expected=[tuple(x.split('\t')) for x in case_file.read_text().splitlines()]
rows=[line.split('\t') for line in (root/'status.tsv').read_text().splitlines()]
out={}
for material,case in expected:
    vals=[r for r in rows if r[0]==material and r[1]==case]
    assert len(vals)==2 and vals[0][3]==vals[1][3]
    status=vals[0][3]
    raw=(root/f'fine-{material}-{case}-o2.txt').read_text(errors='replace')
    hs=[float(x) for x in re.findall(r'\|H=([^|\n]+)',raw)]
    masses=[abs(float(x)) for x in re.findall(r'\|MASS=([^|\n]+)',raw)]
    out.setdefault(material,{})[case]={
      'status':status,
      'state_count':raw.count('LAREDYN0R_STATE|'),
      'max_pressure_head_cm':max(hs) if hs else None,
      'max_abs_mass_residual_cm':max(masses) if masses else None,
    }
    if status=='QUALIFIED':
        assert out[material][case]['state_count']==1024
        assert max(masses,default=0.0)<=1e-12
        assert max(hs,default=-1e99)<-0.01

summary={
  'schema':'swap5.lare.dyn0a.grid1.reference-status.v1',
  'decision':'LARE_DYN0A_GRID1_BLIND_REFERENCE_PANEL_CHARACTERIZED',
  'prediction_qualified_count':pred['qualified_prediction_count'],
  'prediction_censored_count':pred['censored_prediction_count'],
  'materials':out,
  'qualified_reference_count':sum(v['status']=='QUALIFIED' for cases in out.values() for v in cases.values()),
  'outside_domain_count':sum(v['status']=='OUTSIDE_QUALIFIED_DOMAIN_NEAR_SATURATION' for cases in out.values() for v in cases.values()),
  'numerical_block_count':sum(v['status']=='BLOCKED_REFERENCE_NUMERICAL_QUALIFICATION' for cases in out.values() for v in cases.values()),
  'production_rom_authorized':False
}
(root/'LARE_DYN0A_GRID1_REFERENCE_STATUS.json').write_text(json.dumps(summary,indent=2,sort_keys=True)+'\n')
print(json.dumps(summary,sort_keys=True))
PY

sha256sum "$EVIDENCE"/*.txt "$EVIDENCE"/*.json > "$EVIDENCE/reference-sha256.txt"
git diff --check "$CANONICAL_START"...HEAD
echo 'LARE_DYN0A_GRID1_REFERENCE_GATE=PASS'
