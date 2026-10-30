"""Bind completed original Hupsel runs and incumbent contracts to exact source."""
import csv,hashlib,json,struct,tarfile,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];W=ROOT.parent;out=ROOT/'integration/dataqual15_hupsel';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();rows=lambda p:list(csv.DictReader(p.open()))
a=W/'dq15-hupsel-codec-365-O2';b=W/'dq15-hupsel-codec-365-O0';s=W/'dq15-hupsel-codec-split250-O2';t=W/'dq15-hupsel-codec-split130-O2';long=W/'dq15-hupsel-codec-1096-attempt-O2'
extra=[W/'dq15-hupsel-codec-split250-O0',W/'dq15-hupsel-codec-split130-O0']
for p in [a,b,s,t]+extra:
 r=json.loads((p/'RESULT.json').read_text());assert r['returncode']==0 and not r['censored']
 for x in rows(p/'budget.csv'):
  assert abs(float(x['water_end_cm'])-float(x['water_start_cm'])-float(x['water_in_cm'])+float(x['water_out_cm']))<1e-10
  assert abs(float(x['solute_residual_mg_cm2']))<1e-10
for name in ['budget.csv','state.csv','temperature.csv','endpoint.csv','checkpoint.bin','restart.bin']:assert (a/name).read_bytes()==(b/name).read_bytes(),name
for name in ['state.csv','temperature.csv','endpoint.csv','checkpoint.bin','restart.bin']:assert (a/name).read_bytes()==(s/name).read_bytes(),name
assert rows(a/'budget.csv')[251:]==rows(s/'budget.csv')
assert (a/'checkpoint-145.bin').read_bytes()==(t/'checkpoint.bin').read_bytes()
assert [r for r in rows(a/'budget.csv')if 130<float(r['t1_day'])<=145]==rows(t/'budget.csv')
for base,ss,tt in [(b,extra[0],extra[1])]:
 for name in ['state.csv','temperature.csv','endpoint.csv','checkpoint.bin','restart.bin']:assert (base/name).read_bytes()==(ss/name).read_bytes(),name
 assert rows(base/'budget.csv')[251:]==rows(ss/'budget.csv')
 assert (base/'checkpoint-145.bin').read_bytes()==(tt/'checkpoint.bin').read_bytes()
 assert [r for r in rows(base/'budget.csv')if 130<float(r['t1_day'])<=145]==rows(tt/'budget.csv')
r=json.loads((long/'RESULT.json').read_text());assert r['completed_days']==494 and r['returncode']==1 and not r['censored'];assert 'next original crop owner' in r['reason']
reference=W/'dq15-hupsel-reference';ref=list(csv.DictReader(l for l in(reference/'result_output.csv').read_text().splitlines()if l and not l.startswith('*')));assert len(ref)==1097
comparison=[]
for p in [a,long]:
 for x in rows(p/'budget.csv'):
  clock=float(x['t1_day'])
  if clock!=int(clock):continue
  d=int(clock);y=ref[d]
  comparison.append(dict(day=d,date=y['DATE'],water_cm=float(x['water_end_cm'])-float(y['WTOT'])-float(y['PD_VOL']),solute_mg_cm2=float(x['solute_end_mg_cm2'])-float(y['S_STOT']),transpiration_cm=float(x['actual_transpiration_cm'])-float(y['TACT'])))
maxdiff={k:max(abs(x[k])for x in comparison)for k in ['water_cm','solute_mg_cm2','transpiration_cm']};(out/'REFERENCE_COMPARISON.json').write_text(json.dumps(dict(scope='Reference1096days; current source711f8ce SWAP5 completed494; measured differences, not scientific equivalence',maximum_difference=maxdiff,endpoint494=comparison[-1]),indent=2)+'\n')
builds=[W/'dq15-hupsel-codec-final-O0',W/'dq15-hupsel-codec-final-O2'];surface={}
for p in builds:
 build=json.loads((p/'BUILD.json').read_text());assert build['candidate']=='711f8cec131ba5e468eb5eca03c7c95a6bf6372e';assert sha(p/'swap5_hupsel_germination')==build['executable_sha256']
 for f,h in build['source_sha256'].items():assert sha(Path(f))==h
 for f,h in build['source_sha256'].items():
  if str(ROOT)+'/'in f:surface[str(Path(f).relative_to(ROOT))]=h
result=dict(work_unit='DATAQUAL15_HUPSEL',qualified_source_commit='711f8cec131ba5e468eb5eca03c7c95a6bf6372e',project='1.hupselbrook',original_days=1096,completed_days_O2=494,qualified_days_O0_O2=365,full_original_project=False,scientific_equivalence=False,optimizations_exact=True,restart_250_to365_exact=True,restart_130_to145_exact=True,corruption_controls_per_optimization=16,maximum_water_residual_cm=max(json.loads((p/'RESULT.json').read_text())['maximum_water_residual_cm']for p in [a,b,s,t,long]),maximum_solute_residual_mg_cm2=max(json.loads((p/'RESULT.json').read_text())['maximum_solute_residual_mg_cm2']for p in [a,b,s,t,long]),maximum_heat_accounting_residual_j_cm2=max(abs(float(x['observed_heat_residual_j_cm2']))for p in [a,b,long]for x in rows(p/'budget.csv')),reference_comparison=maxdiff,source_sha256=surface,diagnostic_log_scope='Only budget/state/temperature/endpoint/checkpoint outputs are certified as complete. O0 germination diagnostic ends early despite complete365 budget and exact terminal state; no full diagnostic-log equality claim.',failed_feedback='Initial focused Jarvis driver added an invalid trap flag that traps its deliberate NaN rejection control; rerun with original driver flags passes O0/O2. Failed raw retained, excluded from PASS.',numerical_controls=dict(source_imported=['MAXIT30','MAXBACKTR5','SWKMEAN2','DTMIN1e-6','DTMAX0.04','SWKIMPL0'],canonical_stricter='Head/nonlinear balance and hard1e-10 water/solute transaction acceptance remain canonical; not literal original tolerances.'),cost_seconds={p.name:json.loads((p/'RESULT.json').read_text())['seconds']for p in [a,b,s,t,long]},remaining='Second crop starts10May2003 at494days: complete WOFOST/DeWilligen/adaptive roots/Bartholomeus/salinity/Rutter/scheduled irrigation composition and joint persistence.',canonical_admitted=False)
folders=[a,b,s,t,long]+extra+[W/'dq15-hupsel-source-oracle-535',W/'dq15-hupsel-contracts-535-originalflags',W/'dq15-hupsel-codec-restart-controls-O0',W/'dq15-hupsel-codec-restart-controls-O2',W/'dq15-hupsel-contracts-535']
files=[]
for p in folders:
 files.extend(f for f in p.rglob('*')if f.is_file()and(f.suffix in ['.csv','.json','.bin','.stdout','.stderr','.txt']or f.name in ['stdout','stderr','input.nml','prepare.stdout','prepare.stderr']))
for p in builds:files.extend([p/'BUILD.json',p/'EVENTS.json',p/'swap5_hupsel_germination',p/'read_fallow',p/'legacy_swp_original.f90'])
files.append(Path('/workspace/scratch/f29d9f3066a3/dq13-reference431/providers/ttobj/libttutil.a'))
files.extend([reference/n for n in ['result_output.csv','swap.swp','maize.crp','potato.crp','grass.crp','283.met','swap.dra','stdout','stderr','native.stdout','native.stderr','swap.ok','COMPARISON.json']if(reference/n).exists()])
for p in (W/'dq15-hupsel-codec-final-O2').glob('original_input*'):files.append(p)
files=sorted(set(files));name=lambda p:str(p.relative_to(W)) if p.is_relative_to(W) else 'legacy_input_archive/libttutil.a'
manifest={name(p):sha(p)for p in files};(out/'EVIDENCE_MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n')
with tarfile.open(out/'EVIDENCE.tar.xz','w:xz')as archive:
 for p in files:archive.add(p,arcname=name(p),recursive=False)
result['evidence_sha256']=sha(out/'EVIDENCE.tar.xz');(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items()if k!='source_sha256'},indent=2))
