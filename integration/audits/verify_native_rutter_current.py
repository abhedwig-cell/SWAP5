"""Original Rutter ETref/crop/source preparation; full water application excluded."""
import base64,hashlib,io,json,re,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE='e15d5ffd1b28701eb96da7ae817f85c47a15a597';D='integration/mc-sol01/drainage/';STATUS=D+'NATIVE_RUTTER_STATUS.json';SELF='integration/audits/verify_native_rutter_current.py';PARENT='integration/audits/verify_macro_heat_current.py';ET='src/process/mod_reference_et_demand_process.f90';SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits'];sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def projection():
 t=subprocess.check_output(['git','show',BASE+':'+PARENT],cwd=ROOT,text=True)
 for name,args in [('source','reader,changed'),('verify',''),('self_test',''),('fsi35_successors','')]:
  at=re.search(r'^def '+name+r'\(',t,re.M).start();end=t.index('):',at)+2
  if t[end:end+1]!='\n':t=t[:end]+'\n '+t[end:]
  end+=1;t=t[:end]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+t[end:]
 return t.encode()
def et_projection(reader=lambda p:(ROOT/p).read_bytes()):
 t=reader(ET).decode();start=t.index('  ! Original MOD_meteo:ETpot wet-canopy partition');end=t.index('  pure logical function result_is_valid(result)',start);t=t[:start]+t[end:];t=t.replace('  public :: evaluate_restricted_reference_et_demand, evaluate_reference_et_rutter_demand','  public :: evaluate_restricted_reference_et_demand',1)
 assert t.encode()==subprocess.check_output(['git','show',BASE+':'+ET],cwd=ROOT),'existing ET procedures changed'
 return True
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 s=json.loads(reader(STATUS));assert s['baseline']==BASE;git('merge-base','--is-ancestor',BASE,'HEAD')
 assert not git('status','--porcelain','--',*SCIENCE),'unpersisted native Rutter source'
 delta={x.split('\t')[1]:x.split('\t')[0]for x in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()};assert delta==s['scientific_delta'],'foreign native Rutter delta'
 assert reader(PARENT)==projection(),'changed predecessor assertions';et_projection(reader)
 for p,h in s['postimages'].items():assert sha(reader(p))==h,p
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign native Rutter caller'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def capsule():
 e=json.loads((ROOT/STATUS).read_bytes())['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes(),validate=True);assert sha(raw)==e['sha256']and len(raw)==e['bytes']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==e['members']==len({m.name for m in ms});assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms);f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()};return f
def validate(f):
 js=lambda p:json.loads(f[p]);parent=js('parent/owner.json');assert parent['result']['qualified']and parent['result']['bounded_macro_rutter_numeric_heat']and len(parent['negative_controls'])==19
 raw=f['parent/commit.raw'];assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==BASE
 for p,h in js('executed-hashes.json').items():assert sha((ROOT/p).read_bytes())==h and sha(f['executed/'+p])==h,p
 for p,h in js('raw-hashes.json').items():assert sha(f[p])==h,p
 et=js('et/RESULT.json');assert et['status']=='ORIGINAL_RUTTER_ETREF_O0_O2_864_BIT_EXACT'and all(e['returncode']==0 for e in et['events'])
 assert et['original_mod_meteo_sha256']=='99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f'
 assert sha(f['et/original_ETpot.body'])==et['exact_original_body_sha256']and f['et/O0/native.stdout']==f['et/O2/native.stdout']and b'CASES=864'in f['et/O0/native.stdout']
 reader=js('reader/RESULT.json');assert reader['status']=='ORIGINAL_RUTTER_CROP_WEATHER481_O0_O2_PREPARATION_PASS'and reader['crop_periods']==2 and len(reader['events'])==34
 assert all((e['returncode']==0)==e['expected_success']for e in reader['events'])and len(reader['results'])==4
 for i in ['1','2']:
  assert reader['results']['O0-period'+i]==reader['results']['O2-period'+i]
  for opt in ['O0','O2']:
   r=reader['results'][opt+'-period'+i];assert r['days']==481 and r['capacity_max_cm']>0
   for n,k in [('qualified-crop.csv','crop_sha256'),('qualified-rutter.csv','rutter_sha256')]:assert sha(f['reader/'+opt+'-period'+i+'/'+n])==r[k]
 src=js('source/RESULT.json');assert src['status']=='ORIGINAL_RUTTER_SOURCE481_O0_O2_TYPED_RESTART_PASS'and src['days']==481 and src['source_records']==3085 and not src['hydraulic_execution']and not src['file_restart']and all(e['returncode']==0 for e in src['events'])
 assert sha(f['source/original-source.dat'])==src['source_data_sha256']
 for p,h in src['prepared_input_sha256'].items():assert sha(f['reader/'+str(Path(p).relative_to(src['reader_proof_root']))])==h,p
 streams=[f['source/'+o+'/'+m+'.stdout']for o in ['O0','O2']for m in ['plain','restart']];assert len(set(streams))==1 and src['output'].encode()==streams[0]
 row=next(l for l in src['output'].splitlines()if l.startswith('ORIGINAL_NATIVE_RUTTER_SOURCE_BALANCES='));values=list(map(float,row.split('=')[1].split()));assert len(values)==6 and values[0]>values[1]>0 and values[2]>0 and values[3]==0 and max(values[4:])<1e-12 and abs(values[0]-sum(values[1:4]))<1e-10
 for r in [et,reader,src]:
  for p,h in r['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
 # All old ET procedures are exact. The current physical runtime/state source
 # is unchanged; prior matrix/macro/N science stays dated, not re-executed.
 result=dict(parent['result']);result.update(qualified=True,original_native_rutter_preparation=True,original_crop_periods=2,prepared_days=481,source_records=3085,source_O0_O2_typed_restart_exact=True,source_water_max_cm=values[4],source_refinement_max_cm=values[5],original_etpot_cases_per_optimization=864,existing_ET_procedures_source_exact=True,native_full_water_dispatch=False,current_matrix_days=0,prior_matrix5_exact_runtime_preservation_retained=True,full_original_Andelst=False,full481_reexecuted=False,canonically_admitted=False)
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
  raise AssertionError('accepted corrupt native Rutter proof '+name)
 for p in json.loads((ROOT/STATUS).read_bytes())['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if q==p else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_native_rutter.f90':'A'}))
 for p in ['et/RESULT.json','et/O2/native.stdout','reader/RESULT.json','reader/O0-period1/qualified-rutter.csv','source/RESULT.json','source/original-source.dat','source/O2/restart.stdout','parent/commit.raw']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':print(json.dumps(dict(result=verify(),negative_controls=self_test()),indent=2))
