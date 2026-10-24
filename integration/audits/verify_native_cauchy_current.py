"""Owning bounded original BBC native composition; predecessor evidence stays dated."""
import base64,csv,hashlib,io,json,re,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='93f12afe2b76900f32dc10afa56de002c841be86'
CURRENT_BASE='43ee311ae4b525afd191a8e38c66a17d9c8b3a17'
EVIDENCE_BASE='d04a8c3cca1ac9246e66dc913ba588472a5fb78c'
RECOVERY='integration/mc-sol01/drainage/CAUCHY3_RECOVERY_QUALIFICATION.json'
STATUS='integration/mc-sol01/drainage/CAUCHY3_QUALIFICATION.json'
PARENT='integration/audits/verify_saturated_picard_current.py'
SELF='integration/audits/verify_native_cauchy_current.py'
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def record(reader=lambda p:(ROOT/p).read_bytes()):return json.loads(reader(STATUS))
def projection():
 s=subprocess.check_output(['git','show',CURRENT_BASE+':'+PARENT],cwd=ROOT).decode()
 for name,args in [('source','reader,changed'),('verify',''),('self_test',''),('fsi35_successors','')]:
  s=re.sub(r'^def '+name+r'\(\):(?=\S)','def '+name+'():\n ',s,flags=re.M)
  at=s.index('\n',re.search(r'^def '+name+r'\(',s,re.M).start())+1
  s=s[:at]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+s[at:]
 return s.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 r=json.loads(reader(RECOVERY));assert r['baseline']==CURRENT_BASE
 git('merge-base','--is-ancestor',CURRENT_BASE,'HEAD')
 delta={s.split('\t')[1]:s.split('\t')[0]for s in git('diff','--name-status',CURRENT_BASE,'HEAD','--',*SCIENCE).splitlines()}
 assert {p for p in delta if p.startswith('src/')}=={'src/adapter/mod_reference_richards_legacy_binding.f90','src/runtime/mod_fmr_serialized_reference_backend.f90'}
 assert delta==r['scientific_delta'] and not git('status','--porcelain','--',*SCIENCE),'unqualified recovered Cauchy delta'
 assert reader(PARENT)==projection(),'canonical predecessor assertion body changed'
 for p,h in r['postimages'].items():assert sha(reader(p))==h,('current source',p)
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',CURRENT_BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign caller'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def capsule():
 e=record()['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes(),validate=True)
 assert sha(raw)==e['sha256'] and len(raw)==e['bytes']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==e['members']==len({m.name for m in ms})
  assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms)
  return {m.name:t.extractfile(m).read()for m in ms}
def validate(f):
 manifest=json.loads(f['MANIFEST.json']);assert manifest=={p:sha(b)for p,b in f.items()if p!='MANIFEST.json'}
 js=lambda p:json.loads(f[p])
 old=js('parent-owner.json');assert old['baseline']==BASE and old['owner']['qualified']and len(old['controls'])==13
 raw=f['parent-commit.raw'];assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==BASE
 rows=lambda p:list(csv.DictReader(io.StringIO(f[p].decode())))
 def outputs(prefix):
  m=js(prefix+'manifest.json');assert m['status']=='COMPLETE'
  for p,h in m['files'].items():assert sha(f[prefix+p])==h
  return m
 for opt in ['O0','O2']:
  p='native-'+opt+'/';r=js(p+'result.json');assert r['status']=='BOUNDED_ORIGINAL_BBC_NATIVE_RESTART_PASS'
  assert r['complete_days']==481 and r['restart_exact']and r['original_full_swp_rejected']and r['temporal_tolerance']==.01
  assert r['original_bbc_sha256']=='ed83fe31870676cef7a57a27ce2372abc53cc0755b0f4ea6b0b6248e152480ff'
  b=js('build-'+opt+'/column/build-complete.json')
  for path,h in b['input_sha256'].items():assert sha((ROOT/path).read_bytes())==h,('executed dependency',path)
  for kind in ['full','split','resumed']:outputs(p+kind+'/')
  for name in ['state.csv','endpoint.csv','restart.bin']:
   assert f[p+'full/'+name]==f[p+'resumed/'+name]
  for name in ['budget.csv','state.csv','endpoint.csv','restart.bin']:
   assert f['native-O0/full/'+name]==f['native-O2/full/'+name]
   assert f['oldflux-'+opt+'/'+name]==f['oldflux-oracle/'+opt+'/'+name]
  data=rows(p+'full/budget.csv');assert len(data)==481 and data[365:]==rows(p+'resumed/budget.csv')
  for d in data:
   d={k:float(v)for k,v in d.items()}
   assert abs(d['water_residual_cm'])<1e-10 and abs(d['solute_residual_mg_cm2'])<1e-10
   gross=d['water_end_cm']-d['water_start_cm']-d['rain_supplied_cm']+d['runoff_cm']+d['soil_evaporation_cm']+d['pond_evaporation_cm']+d['actual_transpiration_cm']-d['bottom_up_cm']+d['drainage_cm']
   assert abs(gross)<1e-10
  for d in rows(p+'full/state.csv'):assert min(float(d[k])for k in ['theta','concentration_mg_cm3','dissolved_mg_cm2','sorbed_mg_cm2'])>=0
  c=js('contracts-'+opt+'/result.json');assert c['status']=='REFERENCE_CAUCHY3_REAL_CONTRACTS_PASS'and all(e['returncode']==0 for e in c['events'])
  assert len(r['events'])==11 and all((e['returncode']==0)==e['expected_success']for e in r['events'])
 a=js('accuracy.json');assert a['qualified_bounded_accuracy']and a['max_profile_head_difference_cm']<.1
 assert a['budget']['runoff_cm']['max_daily_difference']<.001
 assert a['budget']['water_end_cm']['max_daily_difference']<.02
 return dict(qualified=True,status='ORIGINAL_BBC_NATIVE481_O0_O2_RESTART_BOUNDED_QUALIFIED',bounded_days=481,
  temporal_tolerance=.01,old_flux481_bytes_exact=True,predecessor_scope='13 current controls at93f12afe, historical NUT/FCT execution; no fresh NUT/FCT claim',
  full_original_Andelst=False,full_mc_sol01_closed=False,full_mc_nut01_closed=False,wet4x_qualified=False,canonically_admitted=False)
def fresh_capsule():
 e=json.loads((ROOT/RECOVERY).read_bytes())['fresh_evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes(),validate=True)
 assert sha(raw)==e['sha256'] and len(raw)==e['bytes']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==e['members']==len({m.name for m in ms})
  assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms)
  f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()};return f
def validate_fresh(f):
 historical=capsule()
 js=lambda p:json.loads(f[p])
 rows=lambda p:list(csv.DictReader(io.StringIO(f[p].decode())))
 for opt in ['O0','O2']:
  b=js('build-'+opt+'/column/build-complete.json')
  for p,h in b['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,('fresh executed input',p)
  assert '-'+opt in b['flags'] and '-fcheck=all' in b['flags']
  p='native-'+opt+'/';r=js(p+'result.json')
  assert r['status']=='BOUNDED_ORIGINAL_BBC_NATIVE_RESTART_PASS' and len(r['events'])==11
  assert all((e['returncode']==0)==e['expected_success']for e in r['events'])
  for name in ['budget.csv','state.csv','endpoint.csv','restart.bin']:
   assert f[p+'full/'+name]==historical['native-'+opt+'/full/'+name],('retained output',opt,name)
   assert f['oldflux-'+opt+'/'+name]==historical['oldflux-oracle/'+opt+'/'+name]
   if opt=='O2':assert f[p+'full/'+name]==f['native-O0/full/'+name]
  for name in ['state.csv','endpoint.csv','restart.bin']:assert f[p+'full/'+name]==f[p+'resumed/'+name]
  data=rows(p+'full/budget.csv');assert len(data)==481 and rows(p+'resumed/budget.csv')==data[365:]
  for row in data:
   d={k:float(v)for k,v in row.items()}
   assert abs(d['water_residual_cm'])<1e-10 and abs(d['solute_residual_mg_cm2'])<1e-10
   gross=d['water_end_cm']-d['water_start_cm']-d['rain_supplied_cm']+d['runoff_cm']+d['soil_evaporation_cm']+d['pond_evaporation_cm']+d['actual_transpiration_cm']-d['bottom_up_cm']+d['drainage_cm']
   assert abs(gross)<1e-10
  c=js('contracts-'+opt+'/result.json');assert c['status']=='REFERENCE_CAUCHY3_REAL_CONTRACTS_PASS' and len(c['events'])==4 and all(e['returncode']==0 for e in c['events'])
  for p,h in c['source_sha256'].items():assert sha((ROOT/p).read_bytes())==h
 cpu=js('cpu/result.json');assert cpu['runs']['wet']['returncode']==1 and cpu['runs']['wet']['complete_days']==3
 assert f['cpu/wet/diagnostic-rejected.bin']==historical['wet-prefix3/restart.bin']
 raw=f['canonical-commit.raw'];assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==EVIDENCE_BASE
 peer=js('canonical-peer.json');assert peer['canonical']==EVIDENCE_BASE and peer['owner']['qualified'] and len(peer['controls'])==46
 assert peer['scope']=='Retained exact canonical NUT/FCT evidence; no fresh NUT/FCT physical execution claimed'
 latest=json.loads((ROOT/'integration/mc-sol01/drainage/CAUCHY3_CANONICAL_PEER.json').read_bytes())
 raw=base64.b64decode(latest['commit_base64'],validate=True)
 assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==CURRENT_BASE==latest['canonical']
 assert latest['owner']['qualified'] and len(latest['controls'])==86
 return dict(fresh_checked_O0_O2=True,restart365_exact=True,retained_outputs_exact=True,canonical_peer_controls=86,earlier_peer_controls=46)
def verify():
 source();r=validate(capsule());r['recovery']=validate_fresh(fresh_capsule());return r
def fsi35_successors():
 source();rows=json.loads(capsule()['parent-owner.json'])['fsi35']
 for p,row in rows.items():
  assert row['canonical_blob']==git('rev-parse',BASE+':'+p)
  now=git('rev-parse','HEAD:'+p)
  if now!=row['canonical_blob']:
   assert p in ['src/runtime/mod_fmr_serialized_reference_backend.f90','src/adapter/mod_reference_richards_legacy_binding.f90']
   row['canonical_blob']=now
 return rows
def self_test():
 source();f=capsule();validate(f);fresh=fresh_capsule();validate_fresh(fresh);passed=[]
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError):passed.append(label);return
  raise AssertionError('accepted Cauchy corruption '+label)
 for p in json.loads((ROOT/RECOVERY).read_bytes())['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if p==q else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_cauchy.f90':'A'}))
 for p in ['parent-owner.json','native-O0/full/budget.csv','native-O2/resumed/restart.bin','contracts-O0/result.json','accuracy.json','oldflux-oracle/O2/restart.bin']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 for p in ['native-O0/full/budget.csv','native-O2/resumed/restart.bin','canonical-peer.json','contracts-O2/result.json']:
  bad=dict(fresh);bad[p]+=b'!';reject('fresh raw '+p,lambda bad=bad:validate_fresh(bad))
 return passed
if __name__=='__main__':print(json.dumps(verify(),indent=2))
