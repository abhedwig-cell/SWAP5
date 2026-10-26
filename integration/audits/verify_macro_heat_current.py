"""Bounded existing-owner macro/Rutter/heat evidence; full native remains excluded."""
import base64,hashlib,io,json,re,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE='043e92ac319d3a3b8ca40b57e995be60db91679a';D='integration/mc-sol01/drainage/';STATUS=D+'MACRO_HEAT_STATUS.json';SELF='integration/audits/verify_macro_heat_current.py';PARENT='integration/audits/verify_covered_macro_current.py';SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits'];sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def projection():
 t=subprocess.check_output(['git','show',BASE+':'+PARENT],cwd=ROOT,text=True)
 for name,args in [('source','reader,changed'),('verify',''),('self_test',''),('fsi35_successors','')]:
  at=re.search(r'^def '+name+r'\(',t,re.M).start();end=t.index('):',at)+2
  if t[end:end+1]!='\n':t=t[:end]+'\n '+t[end:]
  end+=1;t=t[:end]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+t[end:]
 return t.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 if (ROOT/'integration/mc-sol01/drainage/NATIVE_RUTTER_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_native_rutter_current.py'))['source'](reader,changed)
 s=json.loads(reader(STATUS));assert s['baseline']==BASE;git('merge-base','--is-ancestor',BASE,'HEAD')
 assert not git('status','--porcelain','--',*SCIENCE),'unpersisted macro heat source'
 delta={x.split('\t')[1]:x.split('\t')[0]for x in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()};assert delta==s['scientific_delta'],'foreign macro heat delta'
 assert reader(PARENT)==projection(),'changed predecessor assertions'
 for p,h in s['postimages'].items():assert sha(reader(p))==h,p
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign macro heat caller'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def capsule():
 e=json.loads((ROOT/STATUS).read_bytes())['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes(),validate=True);assert sha(raw)==e['sha256']and len(raw)==e['bytes']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==e['members']==len({m.name for m in ms});assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms);f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()};return f
def validate(f):
 js=lambda p:json.loads(f[p]);parent=js('parent/owner.json');assert parent['result']['qualified']and len(parent['negative_controls'])==19
 raw=f['parent/commit.raw'];assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==BASE
 for p,h in js('executed-hashes.json').items():assert sha((ROOT/p).read_bytes())==h and sha(f['executed/'+p])==h,p
 for p,h in js('raw-hashes.json').items():assert sha(f[p])==h,p
 physical={};maxwater=0.;maxenergy=0.
 clean=lambda b:b'\n'.join(l for l in b.splitlines()if not l.startswith(b'MACRO_TRACE_CHECK_PASS'))
 for opt in ['O0','O2']:
  r=js('heat-'+opt+'/RESULT.json');assert len(r['results'])==3 and len(r['events'])==7 and all(e['returncode']==0 for e in r['events'])
  for p,h in r['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
  for case in ['rutter-static','rutter-1','rutter-2']:
   prefix='heat-'+opt+'/replay-'+case;off=f[prefix+'-0.stdout'];on=f[prefix+'-1.stdout'];assert clean(off)==clean(on),'thermal observer changed physics'
   for stream in [off,on]:
    for marker in [b'MACRO_HEAT_EIGHT_REJECTIONS_ATOMIC_PASS',b'PPA_WU05A9_FMR_TOP_INPUT_REJECT_REPLAY=PASS',b'PPA_WU05_MIGMAC10_RUTTER_BOESTEN_MACROPORE_RESTART=PASS',b'PPA_WU05A9_FMR_TOP_INPUT_RESTART=PASS']:assert marker in stream,marker
   heat=[l.split()[1:]for l in on.splitlines()if l.startswith(b'MACRO_HEAT_CHECK_PASS')];assert len(heat)==1
   values=list(map(float,heat[0]));assert len(values)==5 and abs(values[0])<=1e-9 and max(values[1:])>12.
   maxenergy=max(maxenergy,abs(values[0]));traces=[l.split()[1:]for l in on.splitlines()if l.startswith(b'MACRO_TRACE_CHECK_PASS')];assert len(traces)==2
   for line in traces:assert int(line[0])>0 and max(abs(float(x))for x in line[1:4])<1e-10
   maxwater=max(maxwater,max(abs(float(x))for line in traces for x in line[1:4]));physical[opt+'/'+case]=[heat,traces]
  u=js('uncovered-'+opt+'/RESULT.json');old=js('prior/uncovered-'+opt+'.json');assert u['results']==old['results']and len(u['results'])==10 and all(e['returncode']==0 for e in u['events'])
  c=js('covered-'+opt+'/RESULT.json');assert all(x['returncode']==0 for x in c['results'].values())and len(c['results'])==4
  for wet in [0,1]:
   for trace in [0,1]:
    name='wet'+str(wet)+'-trace'+str(trace)+'.stdout';assert f['covered-'+opt+'/'+name]==f['prior/covered-'+opt+'/'+name]
  for record in [u,c]:
   for p,h in record['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
 for case in ['rutter-static','rutter-1','rutter-2']:assert physical['O0/'+case]==physical['O2/'+case],'thermal O0/O2 drift'
 counter=js('counter/RESULT.json');assert counter['status']=='EXACT_DRIVER_BASELINE_REJECTION'and counter['baseline']==BASE
 assert counter['driver_sha256']==sha(f['heat-O0/replay.f90'])==sha(f['counter/replay.f90'])
 assert b'COMPLETED=F'in f['counter/native.stdout']and b'ERROR STOP A9 FMR top-input active serialized trial'in f['counter/native.stderr']
 matrix=js('matrix/RESULT.json');assert matrix['status']=='CURRENT_NATIVE_MATRIX5_O0_O2_EXACT'and matrix['days']==5 and not matrix['full481_reexecuted']and all(e['returncode']==0 for e in matrix['events'])
 for opt in ['O0','O2']:assert matrix['results']['baseline/'+opt]==matrix['results']['current/'+opt]
 result=dict(parent['result']);result.update(qualified=True,bounded_macro_rutter_numeric_heat=True,heat_configurations=6,heat_native_processes=12,additional_atomic_heat_rejections_per_process=8,typed_temperature_restart_exact=True,temperature_rollback_and_retry_exact=True,water_max_cm=maxwater,observed_last_heat_residual_j_cm2=maxenergy,current_NUT_runs=0,current_NUT_separate_process_restarts=0,prior_NUT_evidence_retained=True,full_original_Andelst=False,full481_reexecuted=False,file_macro_heat_restart=False,canonically_admitted=False)
 return result
def verify():
 if (ROOT/'integration/mc-sol01/drainage/NATIVE_RUTTER_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_native_rutter_current.py'))['verify']()
 source();return validate(capsule())
def fsi35_successors():
 if (ROOT/'integration/mc-sol01/drainage/NATIVE_RUTTER_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_native_rutter_current.py'))['fsi35_successors']()
 source();deps=json.loads((ROOT/'integration/audits/FCI93_NON_M1_COMPILE_DEPENDENCIES_20261011.json').read_bytes())['dependencies']
 for d in deps:assert git('rev-parse','HEAD:'+d['path'])==git('rev-parse',BASE+':'+d['path']),d['path']
 return dict(status='UNCHANGED_EXECUTABLE_DEPENDENCIES',dependencies=len(deps),baseline=BASE)
def self_test():
 if (ROOT/'integration/mc-sol01/drainage/NATIVE_RUTTER_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_native_rutter_current.py'))['self_test']()
 source();f=capsule();validate(f);passed=[]
 def reject(name,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError,TypeError,UnicodeError):passed.append(name);return
  raise AssertionError('accepted corrupt macro heat proof '+name)
 for p in json.loads((ROOT/STATUS).read_bytes())['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if q==p else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_macro_heat.f90':'A'}))
 for p in ['heat-O0/RESULT.json','heat-O2/replay-rutter-static-1.stdout','counter/native.stderr','uncovered-O2/RESULT.json','covered-O0/wet1-trace1.stdout','matrix/RESULT.json','parent/commit.raw']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':print(json.dumps(dict(result=verify(),negative_controls=self_test()),indent=2))
