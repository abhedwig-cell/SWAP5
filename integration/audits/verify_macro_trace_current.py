"""Source-bound external macro water receipts; inherited physics stays explicitly dated."""
import base64,csv,hashlib,io,json,re,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='2d21939f285615818ba94352187d40abe2466d8e'
STATUS='integration/mc-sol01/drainage/MACRO_TRACE_STATUS.json'
SELF='integration/audits/verify_macro_trace_current.py'
PARENT='integration/audits/verify_picard_corner_current.py'
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits']
PRODUCTION={'src/runtime/mod_fmr_serialized_reference_backend.f90','src/runtime/mod_macropore_single_column_runtime.f90'}
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def projection():
 text=subprocess.check_output(['git','show',BASE+':'+PARENT],cwd=ROOT,text=True)
 for name,args in [('source','reader,changed'),('verify',''),('fsi35_successors',''),('self_test','')]:
  at=text.index('\n',re.search(r'^def '+name+r'\(',text,re.M).start())+1
  hook="    if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"
  text=text[:at]+hook+text[at:]
 return text.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 r=json.loads(reader(STATUS));assert r['baseline']==BASE
 git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={x.split('\t')[1]:x.split('\t')[0]for x in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 assert delta==r['scientific_delta'],'foreign macro trace delta'
 assert {p for p in delta if p.startswith('src/')}==PRODUCTION
 assert not git('status','--porcelain','--',*SCIENCE),'unpersisted macro trace postimage'
 assert reader(PARENT)==projection(),'prior Picard assertion bodies changed'
 for p,h in r['postimages'].items():assert sha(reader(p))==h,('macro trace source',p)
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign macro trace caller'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def capsule():
 e=json.loads((ROOT/STATUS).read_bytes())['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes(),validate=True)
 assert sha(raw)==e['sha256'] and len(raw)==e['bytes']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==e['members']==len({m.name for m in ms})
  assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms)
  f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()};return f
def validate(f):
 js=lambda p:json.loads(f[p]);parent=js('parent/proof.json');assert parent['owner']['qualified']and len(parent['controls'])==12
 raw=f['parent/commit.raw'];assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==BASE
 assert f['parent/owner.py']==subprocess.check_output(['git','show',BASE+':'+PARENT],cwd=ROOT)
 rows=lambda p:list(csv.DictReader(io.StringIO(f[p].decode())))
 for opt in ['O0','O2']:
  r=js('macro-'+opt+'/RESULT.json');assert r['phase']=='full'and len(r['results'])==10
  assert len(r['events'])==22 and all(e['returncode']==0 for e in r['events'])
  for p,h in r['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,('macro executed source',p)
  for case,checks in r['results'].items():
   assert checks
   for row in checks:
    assert row[0]=='MACRO_TRACE_CHECK_PASS'and int(row[1])>0
    assert max(abs(float(v))for v in row[2:5])<1e-10
   if case=='trial/rutter-5':assert sum(float(x[6])for x in checks)>0,'rapid drain not executed'
   if case=='trial/pond-PARTIAL':assert sum(float(x[7])for x in checks)>0 and sum(float(x[8])for x in checks)>0
   name,label=case.split('/');off=f['macro-'+opt+'/'+name+'-'+label+'-0.stdout'];on=f['macro-'+opt+'/'+name+'-'+label+'-1.stdout']
   clean=lambda b:b'\n'.join(x for x in b.splitlines()if not x.startswith(b'MACRO_TRACE_CHECK_PASS'))
   assert clean(off)==clean(on),'observer changed incumbent output'
  if opt=='O2':assert r['results']==js('macro-O0/RESULT.json')['results'],'O0/O2 macro receipt drift'
  b=js('build-'+opt+'/build-complete.json');assert len(b['current_transitive_build']['recompiled_sources'])==17
  assert len(b['current_transitive_build']['reused_objects'])==177
  assert all(e['returncode']==0 for e in b['current_transitive_build']['fresh'])
  assert b['compiler'].startswith('GNU Fortran')and '-fcheck=all'in b['flags']and '-ffpe-trap=invalid,zero,overflow'in b['flags']
  for p,h in b['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,('build source',p)
  a=js('bbc-'+opt+'/RESULT.json');assert a['days']==481 and all(e['returncode']==0 for e in a['events'])
  for p,h in a['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,('BBC executed source',p)
  for name in ['budget.csv','state.csv','endpoint.csv','restart.bin']:
   assert sha(f['bbc-'+opt+'/full/'+name])==a['prior_sha256'][name]
   if name!='budget.csv':assert f['bbc-'+opt+'/full/'+name]==f['bbc-'+opt+'/resumed/'+name]
  data=rows('bbc-'+opt+'/full/budget.csv');assert len(data)==481 and rows('bbc-'+opt+'/resumed/budget.csv')==data[365:]
  for row in data:assert abs(float(row['water_residual_cm']))<1e-10 and abs(float(row['solute_residual_mg_cm2']))<1e-10
 for label,status in [('nut-joint','ACTUAL_PARTITION_CROP_RICHARDS_O0_O2_PASS'),('nut-nonjuvenile','NONJUVENILE_ACTUAL_PARTITION_CROP_RICHARDS_O0_O2_PASS')]:
  r=js(label+'/result.json');assert r['status']==status and r['runs']==4 and r['restarts']==8
  assert all(e['returncode']==0 for e in js(label+'/events.json'))
  for p,h in r['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,('NUT executed source',p)
  assert r['results']==js('prior/'+label+'.json')['results'],'NUT physical/ledger drift'
  for key,record in r['results'].items():
   assert sha(f[label+'/'+key+'.endpoint'])==record['endpoint_sha256']
   for day in [1,4]:
    for suffix in ['', '.ledger']:assert f[label+'/'+key+'.endpoint'+suffix]==f[label+'/'+key+'.fresh-'+str(day)+suffix]
   for day in [2,5]:
    for kind in ['exhaust','stale','water']:assert f[label+'/'+key+'.restart.before-'+str(day)]==f[label+'/'+key+'.restart.'+kind+'-reject-'+str(day)]
 return dict(qualified=True,status='EXTERNAL_MACRO_WATER_TRACE_AND_CURRENT_COMPOSITION_QUALIFIED',macro_configurations=20,macro_native_processes=40,observer_physical_stdout_exact=True,O0_O2_macro_receipts_exact=True,independent_cell_and_declared_boundary_budgets=True,receipt_negative_controls_per_substep=8,original_BBC481_and365_restart_exact=True,current_NUT_runs=8,current_NUT_separate_process_restarts=16,covering_admitted=False,full_original_Andelst=False,macrosolute_or_heat_admitted=False,full_historical_migration=False,canonically_admitted=False)
def verify():source();return validate(capsule())
def fsi35_successors():
 source();f=capsule();r=json.loads(f['parent/proof.json'])['fsi35']
 deps=json.loads((ROOT/'integration/audits/FCI93_NON_M1_COMPILE_DEPENDENCIES_20261011.json').read_bytes())['dependencies']
 for d in deps:assert git('rev-parse','HEAD:'+d['path'])==git('rev-parse',BASE+':'+d['path']),'changed FSI35 executable dependency'
 return r
def self_test():
 source();f=capsule();validate(f);passed=[]
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError,TypeError,UnicodeError):passed.append(label);return
  raise AssertionError('accepted macro trace corruption '+label)
 for p in json.loads((ROOT/STATUS).read_bytes())['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if p==q else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_macro_trace.f90':'A'}))
 for p in ['macro-O0/RESULT.json','macro-O2/trial-pond-PARTIAL-1.stdout','bbc-O0/full/budget.csv','bbc-O2/resumed/restart.bin','nut-joint/O0/crop_both.fresh-4.ledger','nut-nonjuvenile/O2/crop_nh4.restart.water-reject-2','build-O0/build-complete.json']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':print(json.dumps(verify(),indent=2))
