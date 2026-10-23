"""Current typed policy plus canonical organic/FCT owners; exact bounded proofs.

Historical full owner controls are executed in isolated exact worktrees, not
relabeled current. Current source controls, NUT original physical assertions,
FCT original assessments and negative raw controls are executed separately.
"""
import hashlib,io,json,re,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='1b69c9d90a5e57b32c24517b1d378eb6d6275071'
FCT_BASE='f33adbe938368449e97aa14301c40d13440a65c1'
TYPED='3cdebc0c52121a477fe605d092529b0c2cb1254e'
STATUS='benchmarks/performance/PERF01_TYPED_WATER_FLUX_20261023_STATUS.json'
SELF='integration/audits/verify_perf01_live_composition.py'
PARENT='integration/audits/verify_nut_empty_pool.py'
OLD='integration/audits/verify_perf01_typed_water_flux.py'
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def before(p,ref=BASE):return subprocess.check_output(['git','show',ref+':'+p],cwd=ROOT)
def record(reader=lambda p:(ROOT/p).read_bytes()):return json.loads(reader(STATUS))['live_composition']
def projection(path):
 s=before(path,TYPED if path==OLD else BASE).decode()
 for name,args in [('source','reader,changed'),('verify',''),('self_test','')]:
  at=s.index('\n',re.search(r'^def '+name+r'\(',s,re.M).start())+1
  hook=" if 'live_composition' in json.loads((ROOT/'"+STATUS+"').read_text()):return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"
  s=s[:at]+hook+s[at:]
 return s.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 r=record(reader);assert r['base']==BASE and r['typed_predecessor']==TYPED
 git('merge-base','--is-ancestor',BASE,'HEAD');git('merge-base','--is-ancestor',TYPED,'HEAD')
 git('merge-base','--is-ancestor',FCT_BASE,'HEAD')
 delta={l.split('\t')[1]:l.split('\t')[0]for l in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 assert delta==r['scientific_delta'],'foreign live composition delta'
 assert not git('status','--porcelain','--',*SCIENCE),'dirty live science'
 for p,h in r['postimages'].items():assert sha(reader(p))==h,('live postimage',p)
 for kind in ['fct_reactive','fct_pulse_restart','fct_sinks']:
  p='integration/mc-sol01/'+kind+'/verify.py';assert reader(p)==before(p,FCT_BASE),'original FCT assertions changed '+p
 for p in [PARENT,OLD]:assert reader(p)==projection(p),'predecessor assertion bodies changed '+p
 authority='integration/performance/authority.py'
 hook="    if 'live_composition' in json.loads((ROOT/'"+STATUS+"').read_text()):\n        return runpy.run_path(str(ROOT/'"+SELF+"'))['fsi35_successors']()\n"
 assert reader(authority)==before(authority).replace(b'def fsi35_successors():\n',('def fsi35_successors():\n'+hook).encode(),1),'FSI35 registry body changed'
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign caller'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def capsule():
 e=record()['evidence'];raw=(ROOT/e['path']).read_bytes();assert sha(raw)==e['sha256']and len(raw)==e['bytes']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==e['members']==len({m.name for m in ms})and all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms)
  f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()};return f
def canonical_namespace():
 ns=dict(__file__=str(ROOT/PARENT),__name__='exact_canonical_nut_assertions')
 exec(compile(before(PARENT),PARENT,'exec'),ns);return ns
def nut_files(f):
 n=canonical_namespace();old=n['capsule']()
 for p,b in f.items():
  if p.startswith('nut/'):old[p[4:]]=b
 return n,old
def fct_files(f,kind):
 here=ROOT/'integration/mc-sol01'/kind;n=runpy.run_path(str(here/'verify.py'))
 index=json.loads((here/'EVIDENCE_INDEX.json').read_text());old=n['unpack'](here/'EVIDENCE.tar.xz.b64',index['decoded_sha256'])
 labels=json.loads(old['ROUNDS.json']);label='typed-live';assert label not in labels
 for p,b in f.items():
  if p.startswith(kind+'/'):old[label+'/'+p[len(kind)+1:]]=b
 old['ROUNDS.json']=json.dumps(labels+[label]).encode();return n,old
def validate(f):
 js=lambda p:json.loads(f[p])
 for name,count,ref in [('typed',241,TYPED),('canonical',198,BASE)]:
  assert f['frozen/'+name+'/commit.raw']==subprocess.check_output(['git','cat-file','commit',ref],cwd=ROOT)
  assert js('frozen/'+name+'/verify.json')['qualified']
  c=js('frozen/'+name+'/controls.json');assert len(c)==len(set(c))==count
  assert not f['frozen/'+name+'/verify.stderr']and not f['frozen/'+name+'/controls.stderr']
 # The native194 closure has zero overlap with the later organic/fixture
 # changes. Retain the physical469/481, failure atomicity and62-case proof
 # only after checking every actually compiled input against current bytes.
 previous=json.loads(before(STATUS,TYPED));raw=(ROOT/previous['owner_evidence']['path']).read_bytes()
 assert sha(raw)==previous['owner_evidence']['sha256']
 typed=runpy.run_path(str(ROOT/'benchmarks/performance/seal_perf01_typed_water_flux.py'))
 owner=typed['unpack'](raw)
 for opt in ['O0','O2']:
  meta=json.loads(owner['build-'+opt+'/column/build-complete.json'])
  for p,h in meta['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,('retained native input',p)
 primary=json.loads((ROOT/'benchmarks/performance/PERF01_TYPED_WATER_FLUX_20261023_RESULT.json').read_text())
 raw=(ROOT/primary['evidence']['path']).read_bytes();assert sha(raw)==primary['evidence']['sha256']
 assert typed['validate'](typed['unpack'](raw))['native_option_processes']==62
 n,nut=nut_files(f);current=n['validate'](nut)
 assert current['actual_coupled_runs']==26 and current['process_restarts']==52
 for p,h in js('nut/hist/result.json')['input_sha256'].items():assert sha(f['source/'+p])==sha((ROOT/p).read_bytes())==h
 for p,h in js('nut/joint/result.json')['input_sha256'].items():assert sha(f['source/'+p])==sha((ROOT/p).read_bytes())==h
 # Seal every reused object to the immediately preceding typed execution;
 # no historical canonical object is substituted for the new dispatch.
 es=js('nut/hist/events.json');reuse=js('reuse-objects.json')
 for e in es:
  if e['category']=='compile'and e['receipt_scope'].startswith('REUSED_'):
   opt=next(v[1:]for v in e['command']if v in ['-O0','-O2']);name=Path(e['command'][-1]).name
   assert e['object_sha256']==reuse[opt+'/'+name]
 results={}
 for kind in ['fct_reactive','fct_pulse_restart','fct_sinks']:
  ns,files=fct_files(f,kind);results[kind]=ns['assess'](files)
 return dict(qualified=True,status='TYPED_WATER_FLUX_CANONICAL_1B_NUT_FCT_COMPOSITION_QUALIFIED',canonically_admitted=False,
  current_NUT_HIST_processes=78,current_NUT_process_restarts=56,current_NUT_coupled_runs=26,current_NUT_coupled_restarts=52,
  fresh_HIST_compiles=44,reused_exact_HIST_compiles=610,typed_native_processes=62,
  inherited_native_469_481='Exact executed native194 inputs unchanged; immutable typed owner physical proofs retained',
  exact_historical_owner_controls=dict(typed=241,canonical=198),current_FCT=results,
  full_mc_sol01_closed=False,full_mc_nut01_closed=False,default_on=False,
  open_limits='Drainage day470/wet-day7 fail-closed limits unchanged; changed-accuracy bounded option only')
def verify():source();return validate(capsule())
def fsi35_successors():
 source();rows=json.loads(capsule()['frozen/canonical/fsi35.json'])
 # Preserve original historical identities. Only this exact typed source
 # successor may update an actually changed current implementation identity.
 allowed={'src/transaction/mod_transaction_reference.f90','src/runtime/mod_fmr_serialized_reference_backend.f90','src/process/mod_pond_water_temporal_difference.f90','src/runtime/mod_fmr_b111_pond_joint_application.f90'}
 for p,row in rows.items():
  old=git('rev-parse',BASE+':'+p);now=git('rev-parse','HEAD:'+p)
  assert row['canonical_blob']==old,'foreign frozen FSI35 table'
  if old!=now:assert p in allowed;row['canonical_blob']=now
 return rows
def self_test():
 source();f=capsule();validate(f);passed=[]
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError,TypeError):passed.append(label);return
  raise AssertionError('accepted live corruption '+label)
 for p in record()['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if p==q else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_live.f90':'A'}))
 # Re-execute original canonical19 successor source/raw controls using the
 # freshly composed physical files. Its179 older controls are explicitly
 # inherited from their isolated exact canonical execution, not rerun claims.
 ns,files=nut_files(f);older=[p.removeprefix('predecessor:')for p in json.loads(f['frozen/canonical/controls.json'])[:179]]
 ns['source']=source;ns['capsule']=lambda:files;ns['predecessor']=lambda:{'self_test':lambda:older}
 current=ns['self_test']();assert len(current)==198
 passed+=['canonical-current:'+p for p in current[179:]]
 for kind in ['fct_reactive','fct_pulse_restart','fct_sinks']:
  n,files=fct_files(f,kind);passed+=[kind+':'+p for p in n['controls'](files)]
 for p in ['nut/hist/O0/default.endpoint','nut/joint/O2/empty_both.fresh-4.ledger','nut/joint/O0/empty_nh4.endpoint','frozen/typed/verify.json','reuse-objects.json']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':
 import sys
 print(json.dumps(self_test()if'--self-test'in sys.argv else verify(),indent=2))
