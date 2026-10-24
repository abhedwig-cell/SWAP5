"""Read-only recovery: bind retained physical evidence to a named source cut."""
import argparse,base64,csv,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
REPAIR='ab799416d45a5f780ed7a5f66a849bedd6fcb5d7'
HEAD='src/legacy/b1_10_port/headcalc.f90'
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def main():
 p=argparse.ArgumentParser();p.add_argument('--canonical',required=True);a=p.parse_args()
 canonical=git('rev-parse',a.canonical).decode().strip()
 r=json.loads(git('show',REPAIR+':integration/mc-sol01/drainage/DAY470_RECOVERY.json'))
 e=r['current_evidence'];encoded=git('show',REPAIR+':'+e['path'])
 raw=base64.b64decode(encoded,validate=True);assert sha(raw)==e['decoded_sha256']and len(raw)==e['decoded_bytes']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==e['members']==len({m.name for m in ms})
  assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms)
  f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()}
 cache={}
 def current(p):
  if p not in cache:cache[p]=git('show',(REPAIR if p==HEAD else canonical)+':'+p)
  return cache[p]
 def inputs(d):return sorted(p for p,h in d.items()if sha(current(p))!=h)
 def js(p):return json.loads(f[p])
 native={}
 for opt in ['O0','O2']:
  meta=js('build-'+opt+'/column/build-complete.json');drift=inputs(meta['input_sha256']);assert not drift,drift
  prefix='native-'+opt+'/';n=js(prefix+'result.json');assert n['days']==481 and n['restart_exact']
  for name in ['state.csv','endpoint.csv','budget.csv','restart.bin']:
   assert f[prefix+'full/'+name]==f['prior-native-'+opt+'/'+name]
   if opt=='O2':assert f[prefix+'full/'+name]==f['native-O0/full/'+name]
  for name in ['state.csv','endpoint.csv','restart.bin']:assert f[prefix+'full/'+name]==f[prefix+'resumed/'+name]
  rows=list(csv.DictReader(io.StringIO(f[prefix+'full/budget.csv'].decode())));assert len(rows)==481
  for row in rows:
   d={k:float(v)for k,v in row.items()}
   assert abs(d['water_residual_cm'])<1e-10 and abs(d['solute_residual_mg_cm2'])<1e-10
   gross=d['water_end_cm']-d['water_start_cm']-d['rain_supplied_cm']+d['runoff_cm']+d['soil_evaporation_cm']+d['pond_evaporation_cm']+d['actual_transpiration_cm']-d['bottom_up_cm']+d['drainage_cm']
   assert abs(gross)<1e-10
  native[opt]=dict(bound_inputs=len(meta['input_sha256']),input_drift=drift,days=len(rows),endpoint_restart_and_budgets='RETAINED_BYTES_VERIFIED')
 nut={label:inputs(js(label+'/result.json')['input_sha256'])for label in ['hist','joint']}
 research={kind:inputs(js(kind+'/current/execution.json')['inputs'])for kind in ['fct_reactive','fct_pulse_restart','fct_sinks']}
 assert all(not v for v in research.values()),research
 result=dict(status='RECOVERED_NATIVE_IDENTITY_AND_RAW_BALANCES_PASS',canonical=canonical,repair_source=REPAIR,
  source_selection='Canonical bytes plus exactly the already implemented HeadCalc repair; no current compilation claimed',
  decoded_evidence_sha256=sha(raw),native=native,research_input_drift=research,NUT_input_drift=nut,
  NUT_disposition='CHANGED_INPUTS_REQUIRE_FRESH_OWNING_QUALIFICATION'if any(nut.values())else'UNCHANGED_INPUTS',
  compiler='UNAVAILABLE; apt-get update denied setgroups/setegid/seteuid',FSI35_terminal='UNKNOWN',
  exact_merge_qualified=False,canonically_admitted=False)
 print(json.dumps(result,indent=2))
if __name__=='__main__':main()
