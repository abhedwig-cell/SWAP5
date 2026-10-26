"""Bounded macro/Rutter/heat with actual plain substep roots and DRAMET3 owner."""
import base64,hashlib,io,json,re,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE='53db6ca034c988dddaa66172036ae70fd5772630';D='integration/mc-sol01/drainage/';STATUS=D+'MACRO_ROOT_DRAIN_HEAT_STATUS.json';SELF='integration/audits/verify_macro_root_drain_heat_current.py';PARENT='integration/audits/verify_native_macro_initial_current.py';SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits'];sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def projection():
 t=subprocess.check_output(['git','show',BASE+':'+PARENT],cwd=ROOT,text=True)
 for name,args in [('source','reader,changed'),('verify',''),('self_test',''),('fsi35_successors','')]:
  at=re.search(r'^def '+name+r'\(',t,re.M).start();end=t.index('):',at)+2
  if t[end:end+1]!='\n':t=t[:end]+'\n '+t[end:]
  end+=1;t=t[:end]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+t[end:]
 return t.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 s=json.loads(reader(STATUS));assert s['baseline']==BASE;git('merge-base','--is-ancestor',BASE,'HEAD');assert not git('status','--porcelain','--',*SCIENCE),'unpersisted source'
 delta={x.split('\t')[1]:x.split('\t')[0]for x in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()};assert delta==s['scientific_delta'],'foreign joint runtime delta';assert reader(PARENT)==projection(),'changed predecessor assertions'
 for p,h in s['postimages'].items():assert sha(reader(p))==h,p
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign caller'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def capsule():
 e=json.loads((ROOT/STATUS).read_bytes())['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes(),validate=True);assert sha(raw)==e['sha256']and len(raw)==e['bytes']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==e['members']==len({m.name for m in ms});assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms);f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()};return f
def validate(f):
 js=lambda p:json.loads(f[p]);parent=js('parent/owner.json');assert parent['result']['qualified']and parent['result']['original_native_macro_initial_preparation']and len(parent['negative_controls'])==24
 raw=f['parent/commit.raw'];assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==BASE
 for p,h in js('executed-hashes.json').items():assert sha((ROOT/p).read_bytes())==h and sha(f['executed/'+p])==h,p
 for p,h in js('raw-hashes.json').items():assert sha(f[p])==h,p
 maxwater=0.;maxheat=0.;physical={}
 for opt in ['O0','O2']:
  build=js('runtime-'+opt+'/build-complete.json');assert build['status']=='BUILT'and len(build['recompiled_sources'])==17 and len(build['reused_objects'])==177 and all(e['returncode']==0 for e in build['rebuild_events'])
  for p,h in build['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
  for mode in ['root','drain','joint']:
   prefix=opt+'-'+mode;record=js(prefix+'/RESULT.json');assert record['root_drain']==mode and record['phase']=='pilot'and len(record['events'])==2 and all(e['returncode']==0 for e in record['events'])
   for p,h in record['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
   out=f[prefix+'/replay-rutter-static-1.stdout'];assert out==f['O0-'+mode+'/replay-rutter-static-1.stdout'],'joint O0/O2 drift'
   for marker in [b'MACRO_ROOT_DRAIN_FOUR_REJECTIONS_ATOMIC_PASS',b'MACRO_HEAT_EIGHT_REJECTIONS_ATOMIC_PASS',b'PPA_WU05A9_FMR_TOP_INPUT_REJECT_REPLAY=PASS',b'PPA_WU05_MIGMAC10_RUTTER_BOESTEN_MACROPORE_RESTART=PASS',b'PPA_WU05A9_FMR_TOP_INPUT_RESTART=PASS']:assert marker in out,marker
   lines=lambda marker:[list(map(float,l.split()[1:]))for l in out.splitlines()if l.startswith(marker)]
   joint=lines(b'MACRO_ROOT_DRAIN_CHECK_PASS');heat=lines(b'MACRO_HEAT_CHECK_PASS');traces=lines(b'MACRO_TRACE_CHECK_PASS');assert len(joint)==len(heat)==1 and len(traces)==2
   roots,drain,oracle=joint[0];assert oracle==0.0
   if mode in ['root','joint']:assert abs(roots-2.5e-5)<1e-18
   else:assert roots==0.0
   if mode in ['drain','joint']:assert drain>1e-8
   else:assert drain==0.0
   assert len(heat[0])==5 and abs(heat[0][0])<1e-9 and min(heat[0][1:])>12.
   maxheat=max(maxheat,abs(heat[0][0]))
   for line in traces:assert len(line)==8 and int(line[0])>0 and max(abs(x)for x in line[1:4])<1e-10;maxwater=max(maxwater,max(abs(x)for x in line[1:4]))
   physical[prefix]=dict(root_cm=roots,drainage_cm=drain,root_oracle_error_cm_day=oracle,heat=heat[0],traces=traces)
  preserve=js('preserve-'+opt+'/RESULT.json');assert preserve['phase']=='pilot'and preserve['root_drain']is None and len(preserve['events'])==3 and all(e['returncode']==0 for e in preserve['events'])
  for p,h in preserve['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
  for trace in [0,1]:
   name='replay-rutter-static-'+str(trace)+'.stdout';assert f['preserve-'+opt+'/'+name]==f['prior-'+opt+'/'+name],'old rootless thermal changed'
 counter=js('counter/RESULT.json');assert counter['baseline']==BASE and counter['status']=='EXACT_DRIVER_BASELINE_REJECTION'and counter['driver_sha256']==sha(f['O0-joint/replay.f90'])==sha(f['counter/replay.f90'])
 assert b'COMPLETED=F'in f['counter/native.stdout']and b'A9 FMR top-input active serialized trial'in f['counter/native.stderr']
 result=dict(parent['result']);result.update(qualified=True,bounded_macro_root_drain_numeric_heat=True,plain_substep_Feddes_Rutter_demand_coupled=True,source_dramet3_drainage_only=True,joint_runtime_configurations=6,joint_runtime_native_processes=6,joint_atomic_rejections_per_process=4,joint_root_oracle_error_cm_day=0.,joint_water_max_cm=maxwater,joint_observed_last_heat_max_j_cm2=maxheat,joint_physical_results=physical,current_bounded_thermal_native_processes=4,current_bounded_thermal_predecessor_exact=True,full_original_Andelst=False,whole_water_dispatch=False,native_full_water_dispatch=False,file_macro_heat_restart=False,full481_reexecuted=False,current_NUT_runs=0,current_NUT_separate_process_restarts=0,current_matrix_days=0,canonically_admitted=False)
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
  raise AssertionError('accepted corrupt native initialization proof '+name)
 for p in json.loads((ROOT/STATUS).read_bytes())['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if q==p else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_initial.f90':'A'}))
 for p in ['O2-joint/RESULT.json','O0-root/replay-rutter-static-1.stdout','O2-drain/replay-rutter-static-1.stdout','O2-joint/replay-rutter-static-1.stdout','counter/native.stdout','preserve-O2/replay-rutter-static-0.stdout','parent/commit.raw']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':print(json.dumps(dict(result=verify(),negative_controls=self_test()),indent=2))
