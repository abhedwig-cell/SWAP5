#!/usr/bin/env python3
"""Analyze provider discontinuity and discriminate the failed smooth oracle."""
import argparse,base64,csv,gzip,hashlib,json
from pathlib import Path
ap=argparse.ArgumentParser();ap.add_argument('--logdir',type=Path,default=Path('/tmp'));a=ap.parse_args()
root=Path(__file__).resolve().parents[2]
out=root/'integration/sw-rib-top03/evidence/constitutive_cut';out.mkdir(parents=True,exist_ok=True)
cols=['cut_head_cm','delta_cm','K_left_cm_day','K_right_cm_day','jump_cm_day','secant_per_day','relative_jump']
records=[];hashes={};failed_oracles=[]
for g in (2,3):
 p=a.logdir/f'top03-cut-g{g}.log';hashes[p.name]=hashlib.sha256(p.read_bytes()).hexdigest()
 lines=[next(csv.reader([l]))[1:] for l in p.read_text().splitlines() if l.startswith('CUT_ORACLE,')]
 assert len(lines)==12 and lines[:6]==lines[6:]
 assert all('TOP03_TRANSITION_O'+str(o)+'=COMPLETED' in p.read_text() for o in (0,2))
 numeric=[dict(zip(cols,map(float,l))) for l in lines[:6]]
 if records:assert numeric==records
 else:records=numeric
 with (out/f'geometry{g}_O0.csv').open('w') as f:
  w=csv.DictWriter(f,fieldnames=cols);w.writeheader();w.writerows(numeric)
 for variant in ('bottom','both'):
  p=a.logdir/f'top03-analytic-g{g}-{variant}.log';hashes[p.name]=hashlib.sha256(p.read_bytes()).hexdigest()
  assert 'FAPP09_GATE_FAIL runtime O0' in p.read_text()
  assert not any(l.startswith('geometry,') for l in p.read_text().splitlines())
  data=[next(csv.reader([l]))[1:] for l in p.read_text().splitlines() if l.startswith('DK_ORACLE,')]
  assert len(data)==20
  plateau=[list(map(float,l)) for l in data if float(l[0])==-0.001]
  assert len(plateau)==4 and all(x[2]>26 and x[3]==0 and x[4]==1 for x in plateau)
  failed_oracles.append({'geometry':g,'variant':variant,'runtime_exit':91,'build':'O0','integrations_executed':0,'O2_executed':False})
  (out/f'failed_smooth_geometry{g}_{variant}_O0.csv').write_text('head_cm,epsilon_cm,analytic_per_day,provider_fd_per_day,relative_error\n'+'\n'.join(','.join(l) for l in data)+'\n')

cut=records[0]['cut_head_cm'];correlation={}
for variant in ('stock','strict'):
 groups={};failed={}
 for g in (2,3):
  for r in csv.DictReader((root/f'integration/sw-rib-top03/evidence/terminal_trace/{variant}_geometry{g}_O0.csv').open()):
   if r['stop_code']=='1':failed[tuple(r[x] for x in ['geometry','bottom_mode','profile','history','steps'])]=int(r['completed'])+1
  for profile in (1,2,3):
   for r in csv.DictReader((root/f'integration/sw-rib-top03/evidence/terminal_trace/{variant}_geometry{g}_profile{profile}_trace_O0.csv').open()):
    key=tuple(str(int(float(r[x]))) for x in ['geometry','bottom_mode','profile','history','steps'])
    if key in failed and int(float(r['step']))==failed[key]:groups.setdefault(key,[]).append(r)
 cross={k:sum((float(r['old_bottom'])-cut)*(float(r['new_bottom'])-cut)<0 for r in rs) for k,rs in groups.items()}
 correlation[variant]={'failed_grids':len(groups),'cross_cut_in_terminal_window':sum(n>0 for n in cross.values()),
 'repeated_crossings':sum(n>=2 for n in cross.values()),'terminal_within_1e_5_cm':sum(abs(float(rs[-1]['new_bottom'])-cut)<1e-5 for rs in groups.values()),
 'crossing_cases':[{'grid':k,'crossings':n} for k,n in cross.items() if n>0]}
source=gzip.decompress(base64.b64decode((root/'reference/swap-4.3.1/b1_10_source/MOD_MvG_functions.f90.gz.b64').read_bytes()))
manifest=json.loads((root/'reference/swap-4.3.1/b1_10_source/MOD_MvG_functions.manifest.json').read_text())
assert hashlib.sha256(source).hexdigest()==manifest['decoded_source_sha256']
assert b'else if (relsat > (1.0d0-1.0d-6)) then' in source
result={'scope':'exact synthetic default-MvG provider cutoff and existing terminal trace correlation',
 'canonical_reviewed':'27b271c2f3d1ea54e0110f56b73400e3b6935e11','preregistration_commit':'e4cdbdbd161ab994bab32f2b86bef5ff535ad333',
 'cut_oracle_O0_O2_identity':True,'cut_head_cm':cut,'finest_bracket':records[-1],
 'smooth_analytic_oracle_runs':failed_oracles,'terminal_trace_correlation':correlation,
 'B110_legacy_cutoff_confirmed':True,'B110_legacy_source_sha256':hashlib.sha256(source).hexdigest(),
 'B111_module_equivalence_claimed':False,'log_sha256':hashes,
 'decision':'ACTUAL_PROVIDER_K_DISCONTINUITY_CONFIRMED__SMOOTH_DERIVATIVE_ROUTE_FALSIFIED',
 'production_qualified':False,'all_remaining_failures_explained':False}
result['source_sha256']={p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in ['tests/fapp/mod_top03_constitutive_cut_probe.f90','tests/fapp/test_sw_rib_top03_constitutive_cut.f90','tests/fapp/run_sw_rib_top03_constitutive_cut.sh','tests/fapp/analyze_sw_rib_top03_constitutive_cut.py','src/solver/mod_b110_default_mvg_provider.f90']}
(root/'integration/sw-rib-top03/TOP03_CONSTITUTIVE_CUT_RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ('log_sha256','source_sha256','terminal_trace_correlation')},indent=2))
print(json.dumps({v:{k:x for k,x in d.items() if k!='crossing_cases'} for v,d in correlation.items()},indent=2))
