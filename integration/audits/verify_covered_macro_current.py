"""Source-bound covered donor/receiver receipts; predecessor proofs remain dated."""
import base64,csv,hashlib,io,json,re,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE='9d108ee89ae6e1e19d8705a696779555a4a0491c';D='integration/mc-sol01/drainage/';STATUS=D+'COVERED_MACRO_TRACE_STATUS.json';SELF='integration/audits/verify_covered_macro_current.py';PARENT='integration/audits/verify_saturation_storage_current.py';SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits'];sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def projection():
 t=subprocess.check_output(['git','show',BASE+':'+PARENT],cwd=ROOT,text=True)
 for name,args in [('source','reader,changed'),('verify',''),('self_test',''),('fsi35_successors','')]:
  at=re.search(r'^def '+name+r'\(',t,re.M).start();end=t.index('):',at)+2
  if t[end:end+1]!='\n':t=t[:end]+'\n '+t[end:]
  end+=1;t=t[:end]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+t[end:]
 return t.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 if (ROOT/'integration/mc-sol01/drainage/MACRO_HEAT_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_macro_heat_current.py'))['source'](reader,changed)
 s=json.loads(reader(STATUS));assert s['baseline']==BASE;git('merge-base','--is-ancestor',BASE,'HEAD');assert not git('status','--porcelain','--',*SCIENCE),'unpersisted covered receipt source'
 delta={x.split('\t')[1]:x.split('\t')[0]for x in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()};assert delta==s['scientific_delta'],'foreign covered receipt delta';assert reader(PARENT)==projection(),'predecessor owner body changed'
 for p,h in s['postimages'].items():assert sha(reader(p))==h,p
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign covered receipt caller'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def capsule():
 s=json.loads((ROOT/STATUS).read_bytes());e=s['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes(),validate=True);assert sha(raw)==e['sha256']and len(raw)==e['bytes']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==e['members']==len({m.name for m in ms});assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms);f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()};return f
def validate(f):
 js=lambda p:json.loads(f[p]);parent=js('parent/owner.json');assert parent['result']['qualified']and parent['result']['days']==481 and len(parent['negative_controls'])==10;raw=f['parent/commit.raw'];assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==BASE
 for p,h in js('executed-hashes.json').items():assert sha((ROOT/p).read_bytes())==h and sha(f['executed/'+p])==h,p
 covered=[]
 for opt in ['O0','O2']:
  r=js('covered-'+opt+'/RESULT.json');assert len(r['results'])==4 and all(x['returncode']==0 for x in r['results'].values());assert all(e['returncode']==0 for e in r['events'])
  for p,h in r['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
  for wet in [0,1]:
   prefix='covered-'+opt+'/wet'+str(wet)+'-trace';off=f[prefix+'0.stdout'];on=f[prefix+'1.stdout'];clean=lambda b:b'\n'.join(x for x in b.splitlines()if not x.startswith(b'MACRO_TRACE_CHECK_PASS'));assert clean(off)==clean(on)
   lines=[x.decode().split()for x in on.splitlines()if x.startswith(b'MACRO_TRACE_CHECK_PASS')];assert len(lines)==2
   for row in lines:
    assert int(row[1])>0 and max(abs(float(x))for x in row[2:5])<1e-10
    assert(float(row[-1])>0)if wet else(float(row[-1])==0)
   if wet:covered.append(lines)
  old=js('counter/'+opt+'/RESULT.json')
  for p,h in old['build']['input_sha256'].items():assert sha(f['parent/executed/'+p])==h,p
  assert old['baseline']and old['results']['wet0-trace0']['returncode']==old['results']['wet1-trace0']['returncode']==0
  for wet in [0,1]:
   assert old['results']['wet'+str(wet)+'-trace1']['returncode']!=0
   assert b'macro trace missing accepted path'in f['counter/'+opt+'/wet'+str(wet)+'-trace1.stderr']
   assert f['counter/'+opt+'/wet'+str(wet)+'-trace0.stdout']==f['covered-'+opt+'/wet'+str(wet)+'-trace0.stdout'],'observer-independent predecessor physical stream drift'
  u=js('uncovered-'+opt+'/RESULT.json');assert len(u['results'])==10 and len(u['events'])==22 and all(e['returncode']==0 for e in u['events']);assert u['results']==js('prior/uncovered-'+opt+'.json')['results']
  for p,h in u['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
 assert covered[0]==covered[1],'O0/O2 covered receipt drift'
 for name,expected in [('nut-joint','ACTUAL_PARTITION_CROP_RICHARDS_O0_O2_PASS'),('nut-nonjuvenile','NONJUVENILE_ACTUAL_PARTITION_CROP_RICHARDS_O0_O2_PASS')]:
  n=js(name+'/result.json');assert n['status']==expected and n['runs']==4 and n['restarts']==8;assert n['results']==js('prior/'+name+'.json')['results'];assert all(e['returncode']==0 for e in js(name+'/events.json'))
  for p,h in n['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
 m=js('matrix/RESULT.json');assert m['status']=='CURRENT_NATIVE_MATRIX5_O0_O2_EXACT'and m['days']==5 and m['nodes']==112 and not m['full481_reexecuted'];assert all(e['returncode']==0 for e in m['events'])
 for opt in ['O0','O2']:assert m['results']['baseline/'+opt]==m['results']['current/'+opt]
 return dict(qualified=True,covered_O0_O2_exact=True,positive_internal_transfer=True,covered_depths=[3,4],positive_probe_interval_day=1e-3/4096,covered_configurations=4,covered_native_processes=8,corruption_controls_per_substep=12,original_replay_rollback_and_FMR_restore_assertions_retained=True,trace_ON_OFF_physical_stdout_exact=True,current_uncovered_configurations=20,current_uncovered_native_processes=40,current_NUT_runs=8,current_NUT_separate_process_restarts=16,current_matrix_days=5,current_matrix_artifacts_predecessor_exact=True,full481_reexecuted=False,full_original_Andelst=False,macro_chemistry_or_heat_admitted=False,canonically_admitted=False)
def verify():
 if (ROOT/'integration/mc-sol01/drainage/MACRO_HEAT_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_macro_heat_current.py'))['verify']()
 source();return validate(capsule())
def fsi35_successors():
 if (ROOT/'integration/mc-sol01/drainage/MACRO_HEAT_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_macro_heat_current.py'))['fsi35_successors']()
 source();deps=json.loads((ROOT/'integration/audits/FCI93_NON_M1_COMPILE_DEPENDENCIES_20261011.json').read_bytes())['dependencies']
 for d in deps:assert git('rev-parse','HEAD:'+d['path'])==git('rev-parse',BASE+':'+d['path']),d['path']
 return json.loads(capsule()['parent/fsi35.json'])
def self_test():
 if (ROOT/'integration/mc-sol01/drainage/MACRO_HEAT_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_macro_heat_current.py'))['self_test']()
 source();f=capsule();validate(f);passed=[]
 def reject(name,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError,TypeError,UnicodeError):passed.append(name);return
  raise AssertionError('accepted corrupt covered receipt proof '+name)
 for p in json.loads((ROOT/STATUS).read_bytes())['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if q==p else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_covered.f90':'A'}))
 for p in ['covered-O0/RESULT.json','covered-O2/wet1-trace1.stdout','counter/O0/wet1-trace0.stdout','uncovered-O2/RESULT.json','nut-joint/result.json','matrix/RESULT.json','parent/commit.raw']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':print(json.dumps(dict(result=verify(),negative_controls=self_test()),indent=2))
