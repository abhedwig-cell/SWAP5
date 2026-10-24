"""Bounded real macropore/Robin successor; earlier scope stays explicitly dated."""
import base64,csv,hashlib,io,json,re,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='9be9a09b9c890a8240490d1f72a99c14c0cf72f8'
UNIT='integration/mc-sol01/drainage/'
STATUS=UNIT+'ANDELST_COMPOSITION_QUALIFICATION.json'
PARENT='integration/audits/verify_native_cauchy_current.py'
SELF='integration/audits/verify_cauchy_macro_current.py'
CHANGED={'src/runtime/mod_fmr_serialized_reference_backend.f90','src/adapter/mod_reference_richards_legacy_binding.f90'}
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def record(reader=lambda p:(ROOT/p).read_bytes()):return json.loads(reader(STATUS))
def projection():
 s=subprocess.check_output(['git','show',BASE+':'+PARENT],cwd=ROOT).decode()
 for name,args in [('source','reader,changed'),('verify',''),('self_test',''),('fsi35_successors','')]:
  at=s.index('\n',re.search(r'^def '+name+r'\(',s,re.M).start())+1
  # The predecessor uses compact function bodies in some earlier owners.
  first=re.search(r'^def '+name+r'\([^\n]*',s,re.M).group()
  if not first.endswith(':'):
   colon=s.index(':',s.index(first))+1;s=s[:colon]+'\n '+s[colon:];at=colon+1
  s=s[:at]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+s[at:]
 return s.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 r=record(reader);assert r['baseline']==BASE;git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={l.split('\t')[1]:l.split('\t')[0]for l in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 assert delta==r['scientific_delta'] and not git('status','--porcelain','--',*SCIENCE),'unqualified macro successor'
 assert {p for p in delta if p.startswith('src/')}==CHANGED
 assert reader(PARENT)==projection(),'predecessor assertion body changed'
 for p,h in r['postimages'].items():assert sha(reader(p))==h,('macro source',p)
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign caller'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def unpack(e):
 raw=base64.b64decode((ROOT/e['path']).read_bytes(),validate=True);assert len(raw)==e['bytes'] and sha(raw)==e['sha256']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==e['members']==len({m.name for m in ms})
  assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms)
  f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()};return f
def capsule():return unpack(record()['evidence'])
def macro_capsule():return unpack(json.loads((ROOT/(UNIT+'ANDELST_COMPOSITION_RESULT.json')).read_bytes())['evidence'])
def validate(f):
 js=lambda p:json.loads(f[p]);rows=lambda p:list(csv.DictReader(io.StringIO(f[p].decode())))
 parent=js('parent.json');raw=base64.b64decode(parent['commit_base64'],validate=True)
 assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==BASE==parent['canonical']
 assert parent['owner']['qualified'] and len(parent['controls'])==25
 old=macro_capsule()
 for opt in ['O0','O2']:
  p='oracle-'+opt+'/';line=f[p+'native.stdout'].splitlines()[-1].split()
  assert line[:2]==[b'CAUCHY_MACRO_INDEPENDENT_PASS',b'54']
  errors=list(map(float,line[2:]));assert len(errors)==5 and errors[0]<1e-12 and max(errors[1:])<1e-10
  es=js(p+'events.json');assert all(e['returncode']==0 for e in es)
  if opt=='O2':assert f[p+'native.stdout']==f['oracle-O0/native.stdout']
  b=js(p+'native/build-complete.json');assert b['reused_provider_objects']==193
  for path,h in b['input_sha256'].items():assert sha((ROOT/path).read_bytes())==h,('fresh BBC dependency',path)
  assert all(e['returncode']==0 for e in b['events']if e['category']!='full')
  # The first O0 native calculation completed; only its Python publication
  # failed on metadata. The restored manifest retains that failure explicitly.
  if opt=='O0':assert js(p+'native/full/manifest.json')['recovered_publication'] and any(e['returncode']==1 for e in b['events'])
  for name in ['budget.csv','state.csv','endpoint.csv','restart.bin']:
   assert f[p+'native/full/'+name]==f['retained-'+opt+'/'+name]
   if name!='budget.csv':assert f[p+'native/full/'+name]==f[p+'native/resumed/'+name]
  data=rows(p+'native/full/budget.csv');assert len(data)==481 and data[365:]==rows(p+'native/resumed/budget.csv')
  for row in data:
   d={k:float(v)for k,v in row.items()};assert abs(d['water_residual_cm'])<1e-10 and abs(d['solute_residual_mg_cm2'])<1e-10
   gross=d['water_end_cm']-d['water_start_cm']-d['rain_supplied_cm']+d['runoff_cm']+d['soil_evaporation_cm']+d['pond_evaporation_cm']+d['actual_transpiration_cm']-d['bottom_up_cm']+d['drainage_cm'];assert abs(gross)<1e-10
  m='andelst-macro-bbc6-'+opt+'/';r=json.loads(old[m+'RESULT.json']);assert r['status']=='PROBE_COMPLETE'
  for private,path in [('candidate_backend.f90','src/runtime/mod_fmr_serialized_reference_backend.f90'),('candidate_binding.f90','src/adapter/mod_reference_richards_legacy_binding.f90')]:assert old[m+private]==(ROOT/path).read_bytes()
  for driver in ['trial','replay']:
   assert old[m+driver+'-incumbent-canonical.stdout']==old[m+driver+'-incumbent-candidate.stdout']
   for mode in [1,2,3]:
    key=driver+'-candidate-mode'+str(mode);assert r['results'][key]==0
    text=old[m+key+'.stdout'];assert b'RUTTER_BOESTEN_MACROPORE'in text
    if driver=='replay':assert b'RUTTER_BOESTEN_MACROPORE_RESTART=PASS'in text and b'RUTTER_UNSUPPORTED_ENVELOPE_10_REJECT=PASS'in text
    values=[abs(float(v))for v in re.findall(rb'\|MASS=([^|\r\n]+)',text)];assert values and max(values)<1e-9
    if opt=='O2':assert text==old['andelst-macro-bbc6-O0/'+key+'.stdout']
 return dict(qualified=True,status='MACRO_CAUCHY_BOUNDED_ROBIN_CELL_MASS_RESTART_QUALIFIED',independent_cases_per_optimization=54,
  BBC481_exact=True,restart365_exact=True,three_owner_runs=12,retained_parent_controls=25,
  prior_scope='Original parent assertions executed at exact canonical; dated NUT/FCT evidence, no fresh NUT/FCT execution',
  full_original_Andelst=False,heat_drainage_composition=False,wet4x_qualified=False,canonically_admitted=False)
def verify():source();return validate(capsule())
def fsi35_successors():
 source();rows=json.loads(capsule()['parent.json'])['fsi35']
 for p,row in rows.items():
  assert row['canonical_blob']==git('rev-parse',BASE+':'+p)
  now=git('rev-parse','HEAD:'+p)
  if now!=row['canonical_blob']:assert p in CHANGED;row['canonical_blob']=now
 return rows
def self_test():
 source();f=capsule();validate(f);passed=[]
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError):passed.append(label);return
  raise AssertionError('accepted macro corruption '+label)
 for p in record()['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if q==p else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_macro.f90':'A'}))
 for p in ['parent.json','oracle-O0/native.stdout','oracle-O2/native/full/budget.csv','oracle-O2/native/resumed/restart.bin','retained-O0/state.csv']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':print(json.dumps(verify(),indent=2))
