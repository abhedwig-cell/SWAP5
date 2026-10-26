"""Exact-source original geometry adapter; complete macro initialization excluded."""
import base64,hashlib,io,json,re,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE='69885373cc8b15e33a5e970aaf189ca70dcb7da4';D='integration/mc-sol01/drainage/';STATUS=D+'NATIVE_MACRO_BOOTSTRAP_STATUS.json';SELF='integration/audits/verify_native_macro_geometry_current.py';PARENT='integration/audits/verify_native_rutter_current.py';SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits'];sha=lambda b:hashlib.sha256(b).hexdigest()
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
 delta={x.split('\t')[1]:x.split('\t')[0]for x in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()};assert delta==s['scientific_delta'],'foreign geometry delta';assert reader(PARENT)==projection(),'changed predecessor assertions'
 old=subprocess.check_output(['git','show',BASE+':tools/solute/legacy_reader_sources.py'],cwd=ROOT);current=reader('tools/solute/legacy_reader_sources.py');assert current[:len(old)]==old and current[len(old):].startswith(b'\ndef materialize_macro_geometry('),'old reader materialization changed'
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
 js=lambda p:json.loads(f[p]);parent=js('parent/owner.json');assert parent['result']['qualified']and parent['result']['original_native_rutter_preparation']and len(parent['negative_controls'])==21
 raw=f['parent/commit.raw'];assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==BASE
 for p,h in js('executed-hashes.json').items():assert sha((ROOT/p).read_bytes())==h and sha(f['executed/'+p])==h,p
 for p,h in js('raw-hashes.json').items():assert sha(f[p])==h,p
 r=js('geometry/RESULT.json');assert r['status']=='ORIGINAL_MACRO112_FIVE_DOMAIN_GEOMETRY_O0_O2_TYPED_PASS'and r['nodes']==112 and r['domains']==5 and r['original_SWP_preserved']and not r['macroinit']and not r['canonical_initial_state']
 assert len(r['events'])==18 and all((e['returncode']==0)==e['expected_success']for e in r['events'])
 assert r['results']['O0']==r['results']['O2']and f['geometry/O0.nml']==f['geometry/O2.nml']and sha(f['geometry/swap.swp'])==r['original_SWP_sha256']
 for p,h in r['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
 for o in ['O0','O2']:
  b=js('geometry/'+o+'/build-complete.json');assert b['status']=='BUILT'and not b['full_water_kernel_linked']and len(b['events'])==5 and all(e['returncode']==0 for e in b['events']);assert b['original_source_identity']['raw_sha256']['macropore.f90']=='f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f'
  assert sha(f['geometry/'+o+'/original_macro_geometry.f90'])==b['generated_source_sha256']
  assert sha(f['geometry/'+o+'.nml'])==r['results'][o]['geometry_sha256']
  assert sha(f['geometry/'+o+'-consumer-native.stdout'])==r['results'][o]['consumer_stdout_sha256']and b'PRODUCTION_PASS nodes=112 domains=5'in f['geometry/'+o+'-consumer-native.stdout']
 result=dict(parent['result']);result.update(qualified=True,original_native_macro_geometry=True,original_macro_nodes=112,original_macro_domains=5,geometry_O0_O2_exact=True,retained_geometry_rows=112,existing_reader_materializer_exact=True,macroinit=False,canonical_macro_initial_state=False,whole_water_dispatch=False,full_original_Andelst=False,canonically_admitted=False)
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
  raise AssertionError('accepted corrupt macro geometry proof '+name)
 for p in json.loads((ROOT/STATUS).read_bytes())['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if q==p else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_geometry.f90':'A'}))
 for p in ['geometry/RESULT.json','geometry/O2.nml','geometry/O0-consumer-native.stdout','geometry/O2/original_macro_geometry.f90','parent/commit.raw']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':print(json.dumps(dict(result=verify(),negative_controls=self_test()),indent=2))
