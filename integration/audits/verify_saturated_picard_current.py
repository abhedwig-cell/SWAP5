"""Current canonical composition of the already qualified day470 repair."""
import base64,hashlib,io,json,re,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='2de14588d192197d547d5287384e0317ad7514b2'
STATUS='integration/mc-sol01/drainage/DAY470_CURRENT_STATUS.json'
PARENT='integration/audits/verify_nut_crop_depletion_composed.py'
SELF='integration/audits/verify_saturated_picard_current.py'
HEAD='src/legacy/b1_10_port/headcalc.f90'
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def record(reader=lambda p:(ROOT/p).read_bytes()):return json.loads(reader(STATUS))
def projection():
 s=subprocess.check_output(['git','show',BASE+':'+PARENT],cwd=ROOT).decode()
 for name,args in [('source','reader,changed'),('verify',''),('self_test',''),('fsi35_successors','')]:
  s=re.sub(r'^def '+name+r'\(\):(?=\S)','def '+name+'():\n ',s,flags=re.M)
  at=s.index('\n',re.search(r'^def '+name+r'\(',s,re.M).start())+1
  s=s[:at]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+s[at:]
 return s.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 if (ROOT/'integration/mc-sol01/drainage/CAUCHY3_QUALIFICATION.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_native_cauchy_current.py'))['source'](reader,changed)
 if (ROOT/'integration/mc-nut01/competing_sinks/QUALIFIED_INPUTS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_partition.py'))['source'](reader,changed)
 r=record(reader);assert r['baseline']==BASE
 git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={s.split('\t')[1]:s.split('\t')[0]for s in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 assert delta==r['scientific_delta']and not git('status','--porcelain','--',*SCIENCE),'unqualified current Picard delta'
 assert {p for p in delta if p.startswith('src/')}=={HEAD}
 assert git('rev-parse','HEAD:'+HEAD)=='123189920b9690335c4294ff08542bf07b8c1907'
 assert reader(PARENT)==projection(),'predecessor assertions changed'
 for p,h in r['postimages'].items():assert sha(reader(p))==h,('current source',p)
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign caller'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def capsule():
 e=record()['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes(),validate=True);assert sha(raw)==e['sha256']and len(raw)==e['bytes']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==e['members']==len({m.name for m in ms})and all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms)
  f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()};return f
def validate(f):
 js=lambda p:json.loads(f[p])
 old=js('frozen.json');assert old['owner']['qualified']and len(old['controls'])==316
 raw=f['frozen-commit.raw'];assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==BASE
 identity=js('native-identity.json');assert identity['status']=='RECOVERED_NATIVE_IDENTITY_AND_RAW_BALANCES_PASS'and identity['canonical']==BASE
 assert all(not d['input_drift']and d['bound_inputs']==198 and d['days']==481 for d in identity['native'].values())
 for label in ['hist','joint']:
  r=js(label+'/result.json')
  for p,h in r['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,('current executed input',p)
  assert all(e['returncode']==0 for e in js(label+'/events.json'))
 h=js('hist/result.json');assert h['status']=='HIST_BOUNDED_PHYSICAL_PASS_NOT_FULL_MIGRATION'and h['results']==js('prior-hist.json')['results']
 es=js('hist/events.json');assert sum(e['category']=='compile'for e in es)==654 and sum(e['category']in ['native','restart_native','trace_native']for e in es)==78
 j=js('joint/result.json');assert j['status']=='CROP_DEPLETION_ACTUAL_CROP_IMMOBILISATION_O0_O2_PASS'and j['actual_runs']==30 and j['separate_process_restarts']==60
 assert j['results']==js('prior-joint.json')['results']
 for key,row in j['results'].items():
  p='joint/'+key;assert sha(f[p+'.endpoint'])==row['endpoint_sha256']and sha(f[p+'.endpoint.ledger'])==row['ledger_sha256']
  assert row['ledger'][11]<1e-12 and row['ledger'][12]<1e-10
  for day in [1,4]:
   for suffix in ['','.ledger']:assert f[p+'.endpoint'+suffix]==f[p+'.fresh-'+str(day)+suffix]
  for day in [2,5]:
   for kind in ['exhaust','stale','water']:assert f[p+'.restart.before-'+str(day)]==f[p+'.restart.'+kind+'-reject-'+str(day)]
 n=runpy.run_path(str(ROOT/'integration/mc-sol01/fct_sink_restart/verify.py'));files={p[5:]:b for p,b in f.items()if p.startswith('disk/')}
 disk=n['assess'](files);controls=n['controls'](files);assert disk['disk_cases']==48 and len(controls)==5
 return dict(qualified=True,status='CURRENT_NATIVE481_CROP_DEPLETION_AND_SINK_DISK_QUALIFIED',bounded_days=481,current_NUT_processes=78,current_NUT_coupled_runs=30,current_NUT_process_restarts=60,frozen_predecessor_controls=316,retained_native_scope=identity['source_selection'],disk=disk,disk_controls=controls,full_original_Andelst=False,full_mc_sol01_closed=False,full_mc_nut01_closed=False,canonically_admitted=False)
def verify():
 if (ROOT/'integration/mc-sol01/drainage/CAUCHY3_QUALIFICATION.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_native_cauchy_current.py'))['verify']()
 if (ROOT/'integration/mc-nut01/competing_sinks/QUALIFIED_INPUTS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_partition.py'))['verify']()
 source();return validate(capsule())
def fsi35_successors():
 if (ROOT/'integration/mc-sol01/drainage/CAUCHY3_QUALIFICATION.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_native_cauchy_current.py'))['fsi35_successors']()
 if (ROOT/'integration/mc-nut01/competing_sinks/QUALIFIED_INPUTS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_partition.py'))['fsi35_successors']()
 source();rows=json.loads(capsule()['fsi35.json'])
 for p,row in rows.items():
  assert row['canonical_blob']==git('rev-parse',BASE+':'+p)
  now=git('rev-parse','HEAD:'+p)
  if now!=row['canonical_blob']:assert p==HEAD;row['canonical_blob']=now
 return rows
def self_test():
 if (ROOT/'integration/mc-sol01/drainage/CAUCHY3_QUALIFICATION.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_native_cauchy_current.py'))['self_test']()
 if (ROOT/'integration/mc-nut01/competing_sinks/QUALIFIED_INPUTS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_partition.py'))['self_test']()
 source();f=capsule();validate(f);passed=[]
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError):passed.append(label);return
  raise AssertionError('accepted current Picard corruption '+label)
 for p in record()['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if p==q else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_day470.f90':'A'}))
 for p in ['frozen.json','native-identity.json','hist/result.json','joint/O0/crop_nh4.endpoint','joint/O2/crop_both.fresh-4.ledger','joint/O0/crop_both.restart.exhaust-reject-2','disk/round1/execution.json']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':print(json.dumps(verify(),indent=2))
