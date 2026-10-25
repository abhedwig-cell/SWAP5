"""One-provider rational crossing repair; predecessor facts remain dated."""
import base64,csv,hashlib,io,json,re,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE='3f1b2e5eca5881e5e6739686aa1338dc9ebd5267';D='integration/mc-sol01/drainage/';STATUS=D+'SATURATION_STORAGE_STATUS.json';SELF='integration/audits/verify_saturation_storage_current.py';PARENT='integration/audits/verify_composed_heat_current.py';COUNTER=D+'verify_original_matrix_profile.py';PROVIDER='src/solver/mod_b110_default_mvg_provider.f90';sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def projection(path):
 t=subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT,text=True)
 names=[('source','reader,changed'),('verify',''),('self_test',''),('fsi35_successors','')]if path==PARENT else[('source','reader'),('verify',''),('self_test','')]
 for name,args in names:
  start=re.search(r'^def '+name+r'\(',t,re.M).start();colon=t.index(':',t.index(')',start))+1
  if t[colon:colon+1]!='\n':t=t[:colon]+'\n '+t[colon:]
  at=t.index('\n',start)+1;t=t[:at]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+t[at:]
 return t.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 if (ROOT/'integration/mc-sol01/drainage/COVERED_MACRO_TRACE_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_covered_macro_current.py'))['source'](reader,changed)
 s=json.loads(reader(STATUS));assert not git('status','--porcelain','--','src','app','tools','tests','examples','reference','.github','integration/audits');assert s['baseline']==BASE;git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={x.split('\t')[1]:x.split('\t')[0]for x in git('diff','--name-status',BASE,'HEAD','--','src','app','tools','tests','examples','reference','.github','integration/audits').splitlines()};assert delta==s['scientific_delta'];assert reader(PARENT)==projection(PARENT)and reader(COUNTER)==projection(COUNTER)
 old=subprocess.check_output(['git','show',BASE+':'+PROVIDER],cwd=ROOT);now=reader(PROVIDER)
 start=now.index(b'      else if(self%parameters%continuous_saturation_conductivity.and..not.self%parameters%elastic_storage_active.and. &');end=now.index(b'      else\n        increment(i) = b110_watcon_increment',start);assert now[:start]+now[end:]==old
 for p,h in s['postimages'].items():assert sha(reader(p))==h,p
 preservation=json.loads(reader(D+'SATURATION_STORAGE_PRESERVATION.json'));assert preservation['native_pass']and preservation['final']['returncode']==0
 for p,h in preservation['compiled_source_sha256'].items():assert sha(reader(p))==h,p
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign caller'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def capsule():
 e=json.loads((ROOT/STATUS).read_bytes())['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes(),validate=True);assert sha(raw)==e['sha256']and len(raw)==e['bytes']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==e['members']==len({m.name for m in ms});assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms);f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()};return f
def validate(f):
 parent=json.loads(f['parent/proof.json']);assert parent['canonical']==BASE and parent['owner']['qualified'];raw=f['parent/commit.raw'];assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==BASE
 results=[];rows=lambda b:list(csv.DictReader(io.StringIO(b.decode())))
 for opt in ['O0','O2']:
  comp=json.loads(f['component-'+opt+'/RESULT.json']);assert comp['status']=='RATIONAL_SATURATION_REAL128_PASS'and comp['independent_cases']==864 and comp['provider_objects']==2
  assert comp['raw_stdout'].encode()==f['component-'+opt+'/native.stdout'];assert b'864'in f['component-'+opt+'/native.stdout']and b'198'in f['component-'+opt+'/native.stdout'];assert all(e['returncode']==0 for e in comp['events'])
  pre='native-'+opt+'/';r=json.loads(f[pre+'RESULT.json']);assert r['status']=='ORIGINAL_MATRIX112_STORAGE_REPAIR30_RESTART_PASS'and len(r['events'])==6
  assert all((e['returncode']==0)==e['expected_success']for e in r['events']);assert r['physical_results']['days']==30 and r['physical_results']['split_day']==9 and r['physical_results']['nodes']==112
  assert r['build']['provider_module_interface_exact']and r['build']['reused_provider_objects']==192
  for record in [comp,r]:
   for p,h in record['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h and sha(f['executed/'+p])==h,p
  result=r['results'];results.append(result);budget=rows(f[pre+'full/budget.csv']);assert len(budget)==30 and budget==result['budget']and budget[9:]==rows(f[pre+'resumed/budget.csv'])
  for p,h in result['files'].items():assert sha(f[pre+'full/'+p])==h and f[pre+'full/'+p]==f[pre+'resumed/'+p]
  assert f[pre+'full/restart.bin'][:8]==b'S5PT0002'and result['pairs']['full']==result['pairs']['resumed']
  for row in budget:
   assert abs(float(row['water_residual_cm']))<1e-10 and abs(float(row['solute_residual_mg_cm2']))<1e-10 and 0<=float(row['observed_heat_residual_j_cm2'])<=1e-9
   assert abs(float(row['potential_transpiration_cm'])-float(row['actual_transpiration_cm'])-float(row['drought_reduction_cm'])-float(row['oxygen_reduction_cm']))<1e-12
   gross=float(row['water_end_cm'])-float(row['water_start_cm'])-float(row['rain_supplied_cm'])+float(row['runoff_cm'])+float(row['soil_evaporation_cm'])+float(row['pond_evaporation_cm'])+float(row['actual_transpiration_cm'])-float(row['bottom_up_cm'])+float(row['drainage_cm']);assert abs(gross)<1e-10
 assert results[0]==results[1]
 return dict(qualified=True,repair='Stable rational saturation-crossing storage, unchanged physical equation',direct_real128_cases=1728,source_layers=8,linked_component_provider_objects=2,coupled_cases=2,days_per_case=30,exact_day9_restarts=2,full481_qualified=False,full_original_Andelst=False,old_accepted_evidence='Preserved as predecessor execution on unchanged branches; not freshly executed',canonically_admitted=False)
def verify():
 if (ROOT/'integration/mc-sol01/drainage/COVERED_MACRO_TRACE_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_covered_macro_current.py'))['verify']()
 source();return validate(capsule())
def fsi35_successors():
 if (ROOT/'integration/mc-sol01/drainage/COVERED_MACRO_TRACE_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_covered_macro_current.py'))['fsi35_successors']()
 source();rows=json.loads(capsule()['parent/proof.json'])['fsi35'];rows[PROVIDER]=dict(rows[PROVIDER],canonical_blob=git('rev-parse','HEAD:'+PROVIDER),authority=STATUS);return rows
def self_test():
 if (ROOT/'integration/mc-sol01/drainage/COVERED_MACRO_TRACE_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_covered_macro_current.py'))['self_test']()
 source();f=capsule();validate(f);passed=[]
 def reject(name,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError,TypeError,UnicodeError):passed.append(name);return
  raise AssertionError('accepted corrupt saturation storage proof '+name)
 for p in json.loads((ROOT/STATUS).read_bytes())['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if q==p else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_saturation.f90':'A'}))
 for p in ['native-O0/RESULT.json','native-O2/resumed/restart.bin','native-O0/full/budget.csv','component-O2/native.stdout','parent/proof.json']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':print(json.dumps(verify(),indent=2))
