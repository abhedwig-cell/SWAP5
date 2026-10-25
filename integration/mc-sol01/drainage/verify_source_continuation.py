"""Replay the sealed continuation evidence; never launch native calculations."""
import base64,csv,hashlib,io,json,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];D=Path('integration/mc-sol01/drainage');sha=lambda b:hashlib.sha256(b).hexdigest()
def rows(b):return list(csv.DictReader(io.StringIO(b.decode())))
def validate(f):
 r=json.loads(f['RESULT.json']);assert r['status']=='CONTINUATION_SEGMENT_PASS' and r['completed_days'] in [367,481] and r['optimization']=='O2'
 assert r['baseline']=='d6e3955914819ede9d25aaf7b764e48c8467909c'
 inherited=runpy.run_path(str(ROOT/'integration/audits/verify_saturation_storage_current.py'));assert inherited['verify']()['qualified'];accepted=inherited['capsule']()
 for p in [n for n in f if n.startswith('seed/')]:assert f[p]==accepted['native-O2/full/'+p[5:]],p
 assert r['original_macro_Rutter_excluded'] and not r['full_original_Andelst'];assert len(r['events'])==len(r['segments']) and all(e['returncode']==0 for e in r['events'])
 for p,h in r['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
 def generation(prefix,end,parent):
  m=json.loads(f[prefix+'/manifest.json']);assert m['status']=='COMPLETE' and m['returncode']==0 and m['stop_after']==end
  assert m['executable_sha256']==r['executable_sha256'] and m['parent_restart_sha256']==parent
  for p,h in m['files'].items():assert sha(f[prefix+'/'+p])==h,(prefix,p)
  assert f[prefix+'/restart.bin'][:8]==b'S5PT0002'
  for p in ['input.nml','input.swp']:assert f[prefix+'/'+p]==f['seed/'+p]
  state=rows(f[prefix+'/state.csv']);assert len(state)==112 and all(min(float(x[k])for k in ['theta','concentration_mg_cm3','dissolved_mg_cm2','sorbed_mg_cm2'])>=0 for x in state)
  return m
 m=generation('seed',30,None);assert m['files']['restart.bin']==r['seed_restart_sha256'];parent=r['seed_restart_sha256'];start=30;allrows=rows(f['seed/budget.csv']);assert len(allrows)==30
 for s in r['segments']:
  assert s['start']==start and 0<s['end']-start<=120;m=generation(s['folder'],s['end'],parent)
  assert s['parent_restart_sha256']==parent and s['restart_sha256']==m['files']['restart.bin'] and s['native_seconds']==m['native_seconds']
  extra=rows(f[s['folder']+'/budget.csv']);assert [int(x['window'])for x in extra]==list(range(start+1,s['end']+1))
  assert float(extra[0]['water_start_cm'])==float(allrows[-1]['water_end_cm']) and float(extra[0]['solute_start_mg_cm2'])==float(allrows[-1]['solute_end_mg_cm2'])
  allrows+=extra;parent=m['files']['restart.bin'];start=s['end']
 assert start==r['completed_days'] and allrows==r['all_budget'] and [int(x['window'])for x in allrows]==list(range(1,r['completed_days']+1))
 for x in allrows:
  assert abs(float(x['water_residual_cm']))<1e-10 and abs(float(x['solute_residual_mg_cm2']))<1e-10
  assert abs(float(x['potential_transpiration_cm'])-float(x['actual_transpiration_cm'])-float(x['drought_reduction_cm'])-float(x['oxygen_reduction_cm']))<1e-12
  assert 0<=float(x['observed_heat_residual_j_cm2'])<=1e-9
  gross=float(x['water_end_cm'])-float(x['water_start_cm'])-float(x['rain_supplied_cm'])+float(x['runoff_cm'])+float(x['soil_evaporation_cm'])+float(x['pond_evaporation_cm'])+float(x['actual_transpiration_cm'])-float(x['bottom_up_cm'])+float(x['drainage_cm']);assert abs(gross)<1e-10
 assert r['physical_results']==dict(nodes=112,complete_days=r['completed_days'],water_max_cm=max(abs(float(x['water_residual_cm']))for x in allrows),solute_max_mg_cm2=max(abs(float(x['solute_residual_mg_cm2']))for x in allrows),observed_heat_max_j_cm2=max(float(x['observed_heat_residual_j_cm2'])for x in allrows))
 s365=next(s for s in r['segments']if s['end']==365);s367=next(s for s in r['segments']if s['end']==367)
 replay=generation('year-replay',367,s365['restart_sha256']);assert replay['native_seconds']>0
 assert rows(f['year-replay/budget.csv'])==[x for x in allrows if 365<int(x['window'])<=367]
 exact=['restart.bin','state.csv','endpoint.csv','temperature.csv']
 for p in exact:assert f['year-replay/'+p]==f[s367['folder']+'/'+p],p
 return dict(qualified=True,days=r['completed_days'],nodes=112,optimization='O2',segments=len(r['segments']),exact_year_boundary_replay_days=[366,367],exact_files=exact,physical_results=r['physical_results'],full_uninterrupted_run=False,full481_O0=False,full_original_Andelst=False)
def capsule():
 s=json.loads((ROOT/D/'SOURCE_PROFILE_CONTINUATION_STATUS.json').read_text());e=s['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes(),validate=True);assert sha(raw)==e['sha256'] and len(raw)==e['bytes']
 for p,h in s['postimages'].items():assert sha((ROOT/p).read_bytes())==h,p
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==e['members']==len({m.name for m in ms});assert all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in ms);f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()};return f
def self_test():
 f=capsule();validate(f);passed=[]
 for p in ['RESULT.json','seed/restart.bin','to-367/budget.csv','year-replay/restart.bin','to-367/state.csv']:
  bad=dict(f);bad[p]+=b'!'
  try:validate(bad)
  except (AssertionError,ValueError,KeyError,UnicodeError):passed.append(p);continue
  raise AssertionError('Accepted corrupt continuation '+p)
 return passed
if __name__=='__main__':print(json.dumps(dict(result=validate(capsule()),negative_controls=self_test()),indent=2))
