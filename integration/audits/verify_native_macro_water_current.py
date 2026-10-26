"""Bounded actual source112/five-domain water composition and file restart owner."""
import base64,csv,hashlib,io,json,re,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE='72839916e6498b95ab4cb9e120df5a6868e2f20d';D='integration/mc-sol01/drainage/';STATUS=D+'NATIVE_WATER_APPLICATION_STATUS.json';SELF='integration/audits/verify_native_macro_water_current.py';PARENT='integration/audits/verify_macro_root_drain_heat_current.py';SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits'];sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def projection():
 t=subprocess.check_output(['git','show',BASE+':'+PARENT],cwd=ROOT,text=True)
 for name,args in [('source','reader,changed'),('verify',''),('self_test',''),('fsi35_successors','')]:
  at=re.search(r'^def '+name+r'\(',t,re.M).start();end=t.index('):',at)+2
  if t[end:end+1]!='\n':t=t[:end]+'\n '+t[end:]
  end+=1;t=t[:end]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+t[end:]
 return t.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 if (ROOT/'integration/mc-sol01/drainage/ENTRY_RAMP_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_entry_ramp_current.py'))['source'](reader,changed)
 s=json.loads(reader(STATUS));assert s['baseline']==BASE;git('merge-base','--is-ancestor',BASE,'HEAD');assert not git('status','--porcelain','--',*SCIENCE),'unpersisted source'
 delta={x.split('\t')[1]:x.split('\t')[0]for x in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()};assert delta==s['scientific_delta'],'foreign native water delta';assert reader(PARENT)==projection(),'changed predecessor assertions'
 for p,h in s['postimages'].items():assert sha(reader(p))==h,p
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign caller'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def capsule():
 e=json.loads((ROOT/STATUS).read_bytes())['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes(),validate=True);assert sha(raw)==e['sha256']and len(raw)==e['bytes']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==e['members']==len({m.name for m in ms});assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms);f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()};return f
def rows(b):return list(csv.DictReader(io.StringIO(b.decode())))
def validate(f):
 js=lambda p:json.loads(f[p]);parent=js('parent/owner.json');assert parent['result']['qualified']and parent['result']['bounded_macro_root_drain_numeric_heat']
 raw=f['parent/commit.raw'];assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==BASE
 for p,h in js('executed-hashes.json').items():assert sha((ROOT/p).read_bytes())==h and sha(f['executed/'+p])==h,p
 for p,h in js('sealed-raw-hashes.json').items():assert sha(f[p])==h,p
 ordinary=js('ordinary-builder/RESULT.json');assert ordinary['status']=='DEFAULT_PROJECT_BUILDER_PREDECESSOR_EXACT'and ordinary['baseline']==BASE
 assert ordinary['current_source_sha256']==sha((ROOT/'tools/solute/build_project.py').read_bytes())
 assert ordinary['predecessor_source_sha256']==sha(f['ordinary-builder/predecessor.py'])==sha(subprocess.check_output(['git','show',BASE+':tools/solute/build_project.py'],cwd=ROOT))
 assert set(ordinary['exact_executables'])=={'project_reader','crop_reader','root_reader','exe'}and not ordinary['physics_reexecuted']and not ordinary['native_water']
 for mode in ['current','predecessor']:
  bundle=js('ordinary-builder/'+mode+'-bundle.json')
  for key,h in ordinary['exact_executables'].items():assert bundle['executable_sha256'][bundle[key]]==h
 r=js('proof/RESULT.json');assert r['status']=='ORIGINAL112_FIVE_DOMAIN_NATIVE_WATER_SHORT_O0_O2_RESTART_PASS'
 assert r['native_runs']==10 and r['fresh_process_restarts']==4 and r['file_negative_controls']==14 and r['endpoint_files_exact']==12
 assert r['physical_restart_payload_O0_O2_exact']and r['original_source_unmodified']and not r['seasonal']and not r['full481']
 assert len(r['events'])==24 and all((e['returncode']==0)==e['expected_success']for e in r['events'])
 for p,h in r['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
 maxwater=maxcell=maxmatrix=maxcombined=maxsource=maxheat=0.;roots=rapid=direct=pond=0.
 for opt in ['O0','O2']:
  for name in ['continuous','day-prefix','day-resumed','event-prefix','event-resumed']:
   prefix='proof/'+opt+'-'+name;record=js(prefix+'/manifest.json');assert record['status']=='COMPLETE'and all(e['returncode']==0 and not e['censored']for e in record['events'])
   for p,h in record['files'].items():assert sha(f[prefix+'/'+p])==h,(prefix,p)
   budget=rows(f[prefix+'/budget.csv']);progress=rows(f[prefix+'/progress.csv']);assert budget and progress
   assert budget==r['cases'][opt+'-'+name]['rows']and progress==r['cases'][opt+'-'+name]['progress']
   assert all(int(x['mass_rejections'])==0 for x in progress)
   for x in budget:
    for k in ['water_residual_cm','max_macro_cell_cm','max_matrix_cm','max_combined_cm','max_net_source_cm']:assert abs(float(x[k]))<1e-10
    maxwater=max(maxwater,abs(float(x['water_residual_cm'])));maxcell=max(maxcell,float(x['max_macro_cell_cm']));maxmatrix=max(maxmatrix,float(x['max_matrix_cm']));maxcombined=max(maxcombined,float(x['max_combined_cm']));maxsource=max(maxsource,float(x['max_net_source_cm']));maxheat=max(maxheat,float(x['observed_last_heat_residual_j_cm2']))
   if name=='continuous':
    assert float(progress[-1]['t1'])==r['tested_end_day'];assert len(budget)==2
    if opt=='O2':
     roots=sum(float(x['root_cm'])for x in budget);rapid=sum(float(x['rapid_cm'])for x in budget);direct=sum(float(x['direct_macro_cm'])for x in budget);pond=sum(float(x['pond_to_macro_cm'])for x in budget)
   for restart in ['day-resumed','event-resumed']:
    if name=='continuous':
     for p in ['state.csv','temperature.csv','restart.bin']:assert f[prefix+'/'+p]==f['proof/'+opt+'-'+restart+'/'+p]
  for name in ['crc','truncated','dimension','nan-head','negative-pond','clock','foreign-binding']:
   prefix='proof/'+opt+'-bad-'+name
   assert b'native macro water restart rejected'in f['proof/'+opt+'-bad-'+name+'.stdout']
   assert not any(prefix+'/'+p in f for p in ['budget.csv','progress.csv','restart.bin','state.csv','temperature.csv'])
  initial=js('initial/RESULT.json');assert initial['status']=='ORIGINAL_MACROINIT112_FIVE_DOMAIN_TYPED_O0_O2_PASS'
  assert f['initial/'+opt+'.nml']==f['proof/'+opt+'-continuous/macro.nml'].split(b'&macro_configuration')[0]
  for p in [opt+'.nml',opt+'-consumer.stdout']:assert f['initial/'+p]==f['prior-initial/'+p]
  for mode in ['joint','rootless']:
   prefix='preserve-'+opt+'-'+mode;v=js(prefix+'/RESULT.json');assert v['phase']=='pilot'and all(e['returncode']==0 for e in v['events'])
   for p,h in v['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
   for trace in ([1]if mode=='joint'else[0,1]):
    name='replay-rutter-static-'+str(trace)+'.stdout';assert f[prefix+'/'+name]==f['prior-'+opt+'-'+mode+'/'+name]
    assert b'MACRO_HEAT_EIGHT_REJECTIONS_ATOMIC_PASS'in f[prefix+'/'+name]
 for p in ['state.csv','temperature.csv','budget.csv','progress.csv','native.stdout','macro.nml']:assert f['proof/O0-continuous/'+p]==f['proof/O2-continuous/'+p]
 def physical_input(opt):
  raw=f['proof/'+opt+'-continuous/input.nml'].decode();pattern=r'^! (project_reader|crop_reader|root_reader|exe)_executable_sha256=([a-f0-9]{64})$';matches=re.findall(pattern,raw,re.M);assert len(matches)==4
  b=js('proof/'+opt+'-continuous/manifest.json')['compiler_and_source_bundle']
  for key,h in matches:assert b['executable_sha256'][b[key]]==h
  return re.sub(pattern,'',raw,flags=re.M)
 assert physical_input('O0')==physical_input('O2')
 assert f['proof/O0-continuous/restart.bin'][72:-4]==f['proof/O2-continuous/restart.bin'][72:-4]
 assert roots>0 and rapid>0 and direct>0 and maxheat<1e-9
 result=dict(parent['result']);result.update(qualified=True,ordinary_project_build_projection_exact=True,native_full_water_dispatch=True,whole_water_dispatch=True,original112_five_domain_short_water_application=True,file_macro_heat_restart=True,native_source_partition_explicit=True,native_tested_end_day=r['tested_end_day'],native_O0_O2_exact=True,native_water_processes=10,native_fresh_process_restarts=4,native_file_negative_controls=14,native_endpoint_exact_files=12,native_water_max_cm=maxwater,native_macro_cell_max_cm=maxcell,native_matrix_max_cm=maxmatrix,native_combined_max_cm=maxcombined,native_supplied_source_max_cm=maxsource,native_observed_last_heat_max_j_cm2=maxheat,native_root_cm=roots,native_rapid_cm=rapid,native_direct_macro_cm=direct,native_pond_macro_cm=pond,nonempty_degenerate_tip_still_rejects=False,wet_tapered_tip_supported=True,trace_depth_roundoff_floor=True,current_bounded_thermal_native_processes=4,current_bounded_thermal_predecessor_exact=True,joint_runtime_native_processes=2,joint_runtime_configurations=2,full_original_Andelst=False,seasonal_native_macro=False,full481_reexecuted=False,current_NUT_runs=0,current_matrix_days=0,canonically_admitted=False)
 return result
def verify():
 if (ROOT/'integration/mc-sol01/drainage/ENTRY_RAMP_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_entry_ramp_current.py'))['verify']()
 source();return validate(capsule())
def fsi35_successors():
 if (ROOT/'integration/mc-sol01/drainage/ENTRY_RAMP_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_entry_ramp_current.py'))['fsi35_successors']()
 source();deps=json.loads((ROOT/'integration/audits/FCI93_NON_M1_COMPILE_DEPENDENCIES_20261011.json').read_bytes())['dependencies']
 for d in deps:assert git('rev-parse','HEAD:'+d['path'])==git('rev-parse',BASE+':'+d['path']),d['path']
 return dict(status='UNCHANGED_EXECUTABLE_DEPENDENCIES',dependencies=len(deps),baseline=BASE)
def self_test():
 if (ROOT/'integration/mc-sol01/drainage/ENTRY_RAMP_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_entry_ramp_current.py'))['self_test']()
 source();f=capsule();validate(f);passed=[]
 def reject(name,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError,TypeError,UnicodeError):passed.append(name);return
  raise AssertionError('accepted corrupt native water proof '+name)
 for p in json.loads((ROOT/STATUS).read_bytes())['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if q==p else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_water.f90':'A'}))
 for p in ['proof/RESULT.json','proof/O0-continuous/restart.bin','proof/O2-continuous/budget.csv','proof/O2-day-resumed/state.csv','initial/O0.nml','preserve-O2-joint/replay-rutter-static-1.stdout','parent/commit.raw']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':print(json.dumps(dict(result=verify(),negative_controls=self_test()),indent=2))
