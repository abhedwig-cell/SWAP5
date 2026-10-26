"""Bounded opt-in original-grid entry-ramp owner; literal source law stays default."""
import base64,csv,hashlib,io,json,re,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE='362cf65f0d98a1620ab2a245e11e61c84b4946ff';D='integration/mc-sol01/drainage/';STATUS=D+'ENTRY_RAMP_STATUS.json';SELF='integration/audits/verify_entry_ramp_current.py';PARENT='integration/audits/verify_native_macro_water_current.py';SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits'];sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def projection():
 t=subprocess.check_output(['git','show',BASE+':'+PARENT],cwd=ROOT,text=True)
 for name,args in [('source','reader,changed'),('verify',''),('self_test',''),('fsi35_successors','')]:
  at=re.search(r'^def '+name+r'\(',t,re.M).start();end=t.index('):',at)+2
  if t[end:end+1]!='\n':t=t[:end]+'\n '+t[end:]
  end+=1;t=t[:end]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+t[end:]
 return t.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 s=json.loads(reader(STATUS));assert s['baseline']==BASE and s['qualified'];git('merge-base','--is-ancestor',BASE,'HEAD');assert not git('status','--porcelain','--',*SCIENCE),'unpersisted entry source'
 delta={x.split('\t')[1]:x.split('\t')[0]for x in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()};assert delta==s['scientific_delta'],'foreign entry delta';assert reader(PARENT)==projection(),'predecessor assertions changed'
 for p,h in s['postimages'].items():assert sha(reader(p))==h,p
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign caller'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def capsule():
 e=json.loads((ROOT/STATUS).read_bytes())['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes(),validate=True);assert sha(raw)==e['sha256']and len(raw)==e['bytes']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==e['members']==len({m.name for m in ms});assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms);f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(v)for p,v in f.items()};return f
def rows(raw):return list(csv.DictReader(io.StringIO(raw.decode())))
def validate(f):
 js=lambda p:json.loads(f[p]);r=js('RESULT.json');assert r['qualified']and r['end_day']==2 and not r['seasonal'];parent=js('parent/owner.json');assert parent['result']['qualified']and len(parent['negative_controls'])==27
 raw=f['parent/commit.raw'];assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==BASE
 for p,h in js('executed-hashes.json').items():assert sha((ROOT/p).read_bytes())==h and sha(f['executed/'+p])==h,p
 assert js('sealed-raw-hashes.json')=={p:sha(f[p])for p in js('sealed-raw-hashes.json')}
 maxwater=pond=0.;native=0
 for opt in ['O0','O2']:
  for name in ['two','prefix','resumed','default']:
   pre='runs/'+name+'-'+opt;m=js(pre+'/manifest.json');assert m['status']=='COMPLETE'and all(e['returncode']==0 and not e['censored']for e in m['events']);native+=1
   for p,h in m['files'].items():assert sha(f[pre+'/'+p])==h,(pre,p)
   progress=rows(f[pre+'/progress.csv']);budget=rows(f[pre+'/budget.csv']);assert progress and budget
   assert all(int(x['mass_rejections'])==0 for x in progress)
   for x in budget:
    for k in ['water_residual_cm','max_macro_cell_cm','max_matrix_cm','max_combined_cm','max_net_source_cm']:
     v=abs(float(x[k]));assert v<1e-10;maxwater=max(maxwater,v)
   if name=='two':
    assert float(progress[-1]['t1'])==2.;assert sum(int(x['solver_rejections'])for x in progress)==0
    if opt=='O2':pond=sum(float(x['pond_to_macro_cm'])for x in budget);assert pond>0
   if name=='prefix':assert float(progress[-1]['t1'])==1.9400000000023283
  for p in ['state.csv','temperature.csv','restart.bin']:assert f['runs/two-'+opt+'/'+p]==f['runs/resumed-'+opt+'/'+p]
  for p in ['state.csv','temperature.csv','budget.csv','progress.csv','native.stdout','macro.nml']:assert f['runs/default-'+opt+'/'+p]==f['prior-default/'+opt+'/'+p]
  assert f['runs/default-'+opt+'/restart.bin'][72:-4]==f['prior-default/'+opt+'/restart.bin'][72:-4]
  for mode in ['joint','rootless']:
   q=js('preserve/'+opt+'-'+mode+'/RESULT.json');assert all(e['returncode']==0 for e in q['events'])
   for p in q['input_sha256']:assert sha((ROOT/p).read_bytes())==q['input_sha256'][p],p
   for name in ['replay-rutter-static-1.stdout']+([]if mode=='joint'else['replay-rutter-static-0.stdout']):assert f['preserve/'+opt+'-'+mode+'/'+name]==f['prior-preserve/'+opt+'-'+mode+'/'+name]
  q=js('joint/'+opt+'/RESULT.json');assert q['anchored_entry_ramp']and all(e['returncode']==0 for e in q['events'])
  out=f['joint/'+opt+'/replay-rutter-static-1.stdout'];assert b'ENTRY_SIX_REJECTIONS_ATOMIC_PASS'in out and b'PPA_WU05A9_FMR_TOP_INPUT_REPLAY_GATE=PASS'in out
  assert f['leaf/'+opt+'/jump.stdout']==f['prior-leaf/'+opt+'.stdout'];assert b'NATIVE_ENTRY_RAMP_RATE_JACOBIAN_PASS'in f['leaf/'+opt+'/ramp.stdout']
 for p in ['state.csv','temperature.csv','budget.csv','progress.csv','native.stdout','macro.nml']:assert f['runs/two-O0/'+p]==f['runs/two-O2/'+p]
 assert f['runs/two-O0/restart.bin'][72:-4]==f['runs/two-O2/restart.bin'][72:-4]
 assert f['leaf/O0/ramp.stdout']==f['leaf/O2/ramp.stdout'];assert len(js('controls/events.json'))==10 and all(e['returncode']!=0 for e in js('controls/events.json'))
 assert js('runs/width-small-O2/manifest.json')['status']=='COMPLETE';sensitivity=r['width_sensitivity'];assert sensitivity['max_head_cm']<1.e-5 and sensitivity['runoff_cm']==0 and sensitivity['max_water_flux_cm']<1.e-8
 assert js('runs/five-resumed-O2/manifest.json')['status']=='CENSORED'and not r['five_day_complete']
 result=dict(parent['result']);result.update(qualified=True,canonically_admitted=False,corrected_native_entry_ramp_two_days=True,corrected_native_tested_end_day=2.,literal_native_tested_end_day=1.0539999999964493,entry_transition_width_cm=.0001,anchored_cauchy_ceiling=True,entry_native_O0_O2_exact=True,entry_native_processes=native,entry_fresh_process_restarts=2,entry_exact_endpoint_files=6,entry_unsupported_atomic_controls=12,entry_input_restart_controls=10,entry_water_max_cm=maxwater,entry_pond_to_macro_cm=pond,entry_width_sensitivity=sensitivity,current_literal_default_prefix_exact=True,current_joint_rootless_default_exact=True,five_day_complete=False,seasonal_native_macro=False,full_original_Andelst=False)
 return result
def verify():source();return validate(capsule())
def fsi35_successors():
 source();deps=json.loads((ROOT/'integration/audits/FCI93_NON_M1_COMPILE_DEPENDENCIES_20261011.json').read_bytes())['dependencies']
 for d in deps:assert git('rev-parse','HEAD:'+d['path'])==git('rev-parse',BASE+':'+d['path']),d['path']
 return dict(status='UNCHANGED_EXECUTABLE_DEPENDENCIES',dependencies=len(deps),baseline=BASE)
def self_test():
 source();f=capsule();validate(f);passed=[]
 def reject(name,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError,TypeError,UnicodeError):passed.append(name);return
  raise AssertionError('accepted corrupt entry proof '+name)
 for p in json.loads((ROOT/STATUS).read_bytes())['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if q==p else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_entry.f90':'A'}))
 for p in ['runs/two-O2/restart.bin','runs/resumed-O0/state.csv','leaf/O2/ramp.stdout','joint/O0/replay-rutter-static-1.stdout','parent/commit.raw','runs/default-O2/native.stdout']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':print(json.dumps(dict(result=verify(),negative_controls=self_test()),indent=2))
