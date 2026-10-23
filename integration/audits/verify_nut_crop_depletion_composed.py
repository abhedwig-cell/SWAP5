"""Explicit current crop depletion/shared-water composition, immutable old assertions."""
from pathlib import Path
import base64,hashlib,io,json,re,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[2]
OWN='c237fd8817b1840d6fec179711eb0ee3e3bd17c2'
PEER='462395b00e8c0234bfc5457d9d1fdf92486a7329'
UNIT='integration/mc-nut01/crop_only_depletion/'
STATUS=UNIT+'COMPOSITION.json'
SELF='integration/audits/verify_nut_crop_depletion_composed.py'
CROP='integration/audits/verify_nut_crop_depletion.py'
PERF='integration/audits/verify_perf01_live_composition.py'
PARENT='integration/audits/verify_nut_empty_pool.py'
DAILY='src/process/mod_b111_soil_n_daily_exchange.f90'
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def object_id(kind,b):return hashlib.sha1(kind.encode()+b' '+str(len(b)).encode()+b'\0'+b).hexdigest()
def before(ref,p):
 if ref!=OWN:return subprocess.check_output(['git','show',ref+':'+p],cwd=ROOT)
 f=capsule();commit=f['frozen/own/commit.raw'];assert object_id('commit',commit)==OWN
 tree=commit.splitlines()[0].decode().split()[1]
 for part in Path(p).parts:
  raw=f['frozen/own/trees/'+tree];assert object_id('tree',raw)==tree
  entries={};pos=0
  while pos<len(raw):
   end=raw.index(b'\0',pos);name=raw[pos:end].split(b' ',1)[1].decode();entries[name]=raw[end+1:end+21].hex();pos=end+21
  tree=entries[part]
 b=f['frozen/own/source/'+p];assert object_id('blob',b)==tree;return b
def record():return json.loads((ROOT/STATUS).read_bytes())
def hooked(ref,path,names,target=SELF,marker=STATUS):
 s=before(ref,path).decode().replace('def verify():source();return validate(capsule())\n','def verify():\n source();return validate(capsule())\n')
 for name,args in names:
  at=s.index('\n',re.search(r'^def '+name+r'\(',s,re.M).start())+1
  s=s[:at]+" if (ROOT/'"+marker+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+target+"'))['"+name+"']("+args+")\n"+s[at:]
 return s.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 r=record();assert r['own']==OWN and r['peer']==PEER
 git('merge-base','--is-ancestor',PEER,'HEAD')
 # Own historical commit need not be a live Git ancestor after connector
 # publication. Its exact raw commit/tree/blob Merkle proof remains portable.
 assert reader(UNIT+'STATUS.json')==before(OWN,UNIT+'STATUS.json')
 delta={s.split('\t')[1]:s.split('\t')[0]for s in git('diff','--name-status',PEER,'HEAD','--',*SCIENCE).splitlines()}
 assert delta==r['scientific_delta'],'foreign crop/water composition delta'
 assert not git('status','--porcelain','--',*SCIENCE),'dirty crop/water science'
 assert {p for p in delta if p.startswith('src/')}=={DAILY}
 names=[('source','reader,changed'),('verify',''),('self_test','')]
 assert reader(CROP)==hooked(OWN,CROP,names)
 assert reader(PERF)==hooked(PEER,PERF,names+[('fsi35_successors','')])
 assert reader(PARENT)==hooked(PEER,PARENT,names,CROP,UNIT+'STATUS.json')
 for p,h in r['postimages'].items():assert sha(reader(p))==h,('composed postimage',p)
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',PEER+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign caller'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def unpack(raw):
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==len({m.name for m in ms})and all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms)
  f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()};return f
def capsule():
 e=record()['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes(),validate=True)
 assert sha(raw)==e['sha256']and len(raw)==e['bytes'];f=unpack(raw);assert len(f)+1==e['members'];return f
def frozen(ref,path):
 ns=dict(__file__=str(ROOT/path),__name__='immutable_composition_assertions')
 exec(compile(before(ref,path),path,'exec'),ns);return ns
def crop_namespace(f):
 n=frozen(OWN,CROP);validate=n['validate'];h=json.loads(f['hist/REUSE.json'])
 counts=(h['fresh_compile_events'],h['reused_compile_events']);assert counts==(208,446)
 n['source']=source;n['capsule']=lambda:f;n['validate']=lambda files:validate(files,counts)
 older=json.loads(f['frozen/own/controls.json'])[:198]
 n['predecessor']=lambda:{'self_test':lambda:older}
 return n
def peer_namespace():
 n=frozen(PEER,PERF);old_daily=before(PEER,DAILY)
 class ArchivedPath:
  def read_bytes(self):return old_daily
 class HistoricalRoot:
  def __str__(self):return str(ROOT)
  def __fspath__(self):return str(ROOT)
  def __truediv__(self,p):return ArchivedPath()if p==DAILY else ROOT/p
 historical=HistoricalRoot();n['ROOT']=historical
 original=n['canonical_namespace']
 def canonical():
  ns=original();ns['ROOT']=historical;return ns
 n['canonical_namespace']=canonical
 def projected(reader=None,changed=None):
  if reader is None:return source(changed=changed)
  def mapped(p):
   b=reader(p)
   if p==DAILY and b in [old_daily,old_daily+b'!']:return (ROOT/p).read_bytes()+b[len(old_daily):]
   return b
  return source(mapped,changed)
 n['source']=projected
 original_fct=n['fct_files']
 def fct_files(f,kind):
  loaded,files=original_fct(f,kind);ns=loaded['assess'].__globals__
  r=json.loads(files['typed-live/execution.json'])
  paths=[p for ps in r['closures'].values()for p in ps if '/src/'in p]
  prefixes={p.split('/src/')[0]for p in paths};assert len(prefixes)==1
  prefix=next(iter(prefixes))
  class PortablePath:
   def __init__(self,p):self.p=p
   def __str__(self):return str(Path(prefix)/self.p)
   def __fspath__(self):return str(self)
   def read_bytes(self):return (ROOT/self.p).read_bytes()
  class PortableRoot:
   def __str__(self):return prefix
   def __fspath__(self):return prefix
   def __truediv__(self,p):return PortablePath(p)
  ns['ROOT']=PortableRoot();return ns,files
 n['fct_files']=fct_files
 # Pass the unmodified projected reader before mutation controls are trusted.
 projected(lambda p:(historical/p).read_bytes())
 return n
def validate(f):
 assert object_id('commit',f['frozen/own/commit.raw'])==OWN
 assert sha(before(OWN,CROP))==json.loads(before(OWN,UNIT+'STATUS.json'))['postimages'][CROP]
 old=json.loads(f['frozen/own/controls.json']);assert len(old)==len(set(old))==220
 assert json.loads(f['frozen/own/verify.json'])['qualified']
 own=crop_namespace(f)['validate'](f)
 assert json.loads(f['joint/result.json'])['results']==json.loads(f['frozen/own/joint-result.json'])['results'],'default current coupled bytes changed'
 peer=peer_namespace();preserved=peer['validate'](peer['capsule']())
 assert preserved['qualified']and preserved['typed_native_processes']==62
 return {**own,'fresh_hist_compiles':208,'reused_hist_compiles':446,'composition_peer':PEER,'precomposition_own':OWN,
  'historical_predecessor_controls':198,'current_NUT_coupled_runs':30,'current_NUT_process_restarts':60,
  'peer_assertions':'Unmodified peer numerical/raw assertion bodies, explicitly archived old daily-N identity, current exact native194/FCT inputs',
  'typed_native_processes_inherited_exact_inputs':62,'canonically_admitted':False,'status':'CROP_ONLY_SHARED_WATER_COMPOSITION_QUALIFIED'}
def verify():source();return validate(capsule())
def self_test():
 source();f=capsule();validate(f);n=crop_namespace(f);crop=n['self_test']();assert len(crop)==220
 passed=['crop-current:'+p for p in crop[198:]]
 peer=peer_namespace();controls=peer['self_test']();assert len(controls)==163
 passed+=['peer-preserved:'+p for p in controls]
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError,TypeError):passed.append(label);return
  raise AssertionError('accepted composed corruption '+label)
 for p in record()['postimages']:reject('composed source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if p==q else b'')))
 reject('composed foreign caller',lambda:source(changed={'src/foreign_composed.f90':'A'}))
 for p in ['frozen/own/commit.raw','frozen/own/controls.json','frozen/own/joint-result.json','joint/O2/crop_both.endpoint','hist/REUSE.json']:
  bad=dict(f);bad[p]+=b'!';reject('composed raw '+p,lambda bad=bad:validate(bad))
 return passed
def fsi35_successors():source();return peer_namespace()['fsi35_successors']()
if __name__=='__main__':
 import sys
 print(json.dumps(self_test()if'--self-test'in sys.argv else verify(),indent=2))
