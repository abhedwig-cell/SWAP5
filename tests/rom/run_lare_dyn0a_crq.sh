#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CANONICAL_START=9bb73821bb78a04c759b763746b50a3f777cd416
TEST=tests/rom/test_lare_dyn0a_reference.f90
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
VARIABLE=tests/rom/materialize_lare_variable_grid_stubs.py
PREREG=integration/f-rom/LARE_DYN0A_PREREGISTRATION.json

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-lare-dyn0a-crq-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${LARE_DYN0A_CRQ_EVIDENCE_DIR:-$ROOT/LARE_DYN0A_CRQ_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "LARE_DYN0A_CRQ_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$CANONICAL_START" HEAD || fail "canonical start not ancestor"
git diff --quiet "$CANONICAL_START"...HEAD -- src reference || fail "CRQ changed src/reference"

python3 - "$PREREG" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
q=p['pre_comparison_reference_qualification']['coarse_richards_temporal_qualification']
assert q['label']=='DYN0A_CRQ'
assert q['substep_counts']==[1,2,4,8]
assert q['internal_dt_day']==[0.0008,0.0004,0.0002,0.0001]
assert 'no tolerance relaxation' in q['forbidden']
assert 'no new fallback class' in q['forbidden']
print('LARE_DYN0A_CRQ_AUTHORITY=PASS')
PY

python3 "$VARIABLE" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/d3.f90" --layer-thickness-cm 140,10,10
python3 "$VARIABLE" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/d2.f90" --layer-thickness-cm 150,10

cases=()
for s in 1 2 3; do
  for f in 1 2 3 4; do
    cases+=("S${s}_B1_F${f}")
  done
done

: > "$EVIDENCE/status.tsv"

for geometry in d3 d2; do
  case "$geometry" in d3) nodes=3 ;; d2) nodes=2 ;; esac
  for opt in 0 2; do
    OUT="$BUILD/${geometry}-o${opt}"
    python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/${geometry}.f90"       --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90       --build "$OUT" --opt "$opt"

    for nsub in 1 2 4 8; do
      for case_id in "${cases[@]}"; do
        logfile="$EVIDENCE/${geometry}-${case_id}-s${nsub}-o${opt}.txt"
        set +e
        LARE_DYN0A_BOTTOM_FILTER=1         LARE_DYN0A_CASE_FILTER="$case_id"         LARE_DYN0A_SUBSTEPS="$nsub"           "$OUT/rom0_test" > "$logfile" 2>&1
        rc=$?
        set -e

        status="$(python3 - "$logfile" "$rc" "$nodes" "$nsub" <<'PY'
import re,sys
path,rc_raw,nodes_raw,nsub_raw=sys.argv[1:]
rc=int(rc_raw); nodes=int(nodes_raw); nsub=int(nsub_raw)
raw=open(path,errors='replace').read()
hs=[float(x) for x in re.findall(r'\|H=([^|\n]+)',raw)]
masses=[abs(float(x)) for x in re.findall(r'\|MASS=([^|\n]+)',raw)]
states=raw.count('LAREDYN0R_STATE|')
node_rows=raw.count('LAREDYN0R_NODE|')
marker=re.search(r'LAREDYN0R_SUBSTEPS=(\d+)',raw)
if marker and int(marker.group(1))!=nsub:
    raise SystemExit('substep marker drift')
max_h=max(hs) if hs else float('-inf')
if rc==0:
    if 'LAREDYN0R_EXECUTION_COMPLETE=PASS' not in raw:
        raise SystemExit('completion marker missing')
    if states!=1024 or node_rows!=1024*nodes:
        raise SystemExit(f'qualified structure mismatch states={states} nodes={node_rows}')
    if max(masses,default=0.0)>1e-12:
        raise SystemExit('hard mass gate drift')
    if max_h>=-0.01:
        print('OUTSIDE_QUALIFIED_DOMAIN_NEAR_SATURATION')
    else:
        print('QUALIFIED')
else:
    if 'LAREDYN0R_FAIL LAREDYN0R prospective representation bound' in raw or max_h>=-0.01:
        print('OUTSIDE_QUALIFIED_DOMAIN_NEAR_SATURATION')
    elif 'LAREDYN0R_FAIL ' in raw:
        print('BLOCKED_REFERENCE_NUMERICAL_QUALIFICATION')
    else:
        raise SystemExit('unexpected technical Reference failure')
PY
)" || fail "${geometry} ${case_id} s${nsub} O${opt} classification"

        printf '%s\t%s\t%s\t%s\t%s\n'           "$geometry" "$case_id" "$nsub" "$opt" "$status" >> "$EVIDENCE/status.tsv"
      done
    done
  done
done

python3 - "$EVIDENCE" <<'PY'
import json,pathlib,re,sys,math
root=pathlib.Path(sys.argv[1])
rows=[]
for line in (root/'status.tsv').read_text().splitlines():
    g,c,s,o,st=line.split('\t')
    rows.append((g,c,int(s),int(o),st))

def node_series(path):
    out={}
    for line in path.read_text(errors='replace').splitlines():
        if not line.startswith('LAREDYN0R_NODE|'): continue
        d={}
        for bit in line.split('|')[1:]:
            if '=' in bit:
                k,v=bit.split('=',1); d[k]=v
        out.setdefault(int(d['STEP']),[]).append((int(d['NODE']),float(d['THETA'])))
    return {k:[v for _,v in sorted(vals)] for k,vals in out.items()}

result={}
for geom in ('d3','d2'):
    result[geom]={}
    for case in sorted({r[1] for r in rows if r[0]==geom}):
        levels={}
        for nsub in (1,2,4,8):
            vals=[r for r in rows if r[0]==geom and r[1]==case and r[2]==nsub]
            assert len(vals)==2 and vals[0][4]==vals[1][4]
            st=vals[0][4]
            raw=(root/f'{geom}-{case}-s{nsub}-o2.txt').read_text(errors='replace')
            masses=[abs(float(x)) for x in re.findall(r'\|MASS=([^|\n]+)',raw)]
            levels[str(nsub)]={
                'status':st,
                'max_abs_mass_residual_cm':max(masses,default=None),
                'state_count':raw.count('LAREDYN0R_STATE|'),
            }
        successful=[n for n in (1,2,4,8) if levels[str(n)]['status']=='QUALIFIED']
        finest=max(successful) if successful else None
        deltas={}
        for a,b in ((1,2),(2,4),(4,8)):
            if levels[str(a)]['status']=='QUALIFIED' and levels[str(b)]['status']=='QUALIFIED':
                A=node_series(root/f'{geom}-{case}-s{a}-o2.txt')
                B=node_series(root/f'{geom}-{case}-s{b}-o2.txt')
                assert set(A)==set(range(1,1025)) and set(B)==set(range(1,1025))
                max_theta=max(
                    abs(x-y)
                    for step in range(1,1025)
                    for x,y in zip(A[step],B[step])
                )
                # Fixed layer thickness, so theta-to-storage conversion is exact.
                dz=[140.,10.,10.] if geom=='d3' else [150.,10.]
                max_storage=max(
                    abs(x-y)*dz[i]
                    for step in range(1,1025)
                    for i,(x,y) in enumerate(zip(A[step],B[step]))
                )
                deltas[f'{a}_vs_{b}']={
                    'max_abs_theta_difference':max_theta,
                    'max_abs_layer_storage_difference_cm':max_storage,
                }
        result[geom][case]={
            'levels':levels,
            'successful_substep_counts':successful,
            'finest_successful_substep_count':finest,
            'successive_refinement_differences':deltas,
            'comparison_ready':finest is not None,
        }

payload={
  'schema':'swap5.lare.dyn0a.crq.v1',
  'decision':'LARE_DYN0A_COARSE_RICHARDS_TEMPORAL_QUALIFICATION_CHARACTERIZED',
  'substep_counts':[1,2,4,8],
  'internal_dt_day':[0.0008,0.0004,0.0002,0.0001],
  'geometries':result,
  'qualified_case_counts':{
      g:sum(v['comparison_ready'] for v in result[g].values()) for g in result
  },
  'all_routes_blocked_counts':{
      g:sum(not v['comparison_ready'] for v in result[g].values()) for g in result
  },
  'finite_reference_claim':False,
  'conservative_error_bound_claim':False,
  'application_tolerance_selected':False,
  'production_rom_authorized':False,
}
(root/'LARE_DYN0A_CRQ_RESULT.json').write_text(json.dumps(payload,indent=2,sort_keys=True)+'\n')
print(json.dumps({
 'decision':payload['decision'],
 'qualified_case_counts':payload['qualified_case_counts'],
 'all_routes_blocked_counts':payload['all_routes_blocked_counts'],
},sort_keys=True))
PY

sha256sum "$EVIDENCE"/*.txt "$EVIDENCE"/*.json > "$EVIDENCE/sha256.txt"
git diff --check "$CANONICAL_START"...HEAD
echo 'LARE_DYN0A_CRQ_GATE=PASS'
