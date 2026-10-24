"""Independent native state, gross balance, restart identity and raw/source gates."""
import argparse,base64,csv,hashlib,io,itertools,json,math,struct,tarfile,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def assess(files):
 for p in ['verify_native.py','seal_native.py','generate.py','build_native.py','run_native.py']:
  assert files['validation/'+p]==(HERE/p).read_bytes(),('validation source changed',p)
 maxima={'water':0.,'solute':0.};profiles={};processes=0
 for opt in ['o0','o2']:
  prefix='native-'+opt+'/';r=json.loads(files[prefix+'RESULT.json']);b=json.loads(files['build-'+opt+'/build.json'])
  assert r['status']=='BOUNDED_NATIVE_CALLER_AND_PROCESS_RESTART_PASS' and len(r['cases'])==12 and len(r['events'])==48
  assert b['status']=='BUILT_RESEARCH_NATIVE' and len(b['closure'])==201
  assert r['build']==b and len(set(b['closure']))==201
  raw=files['build-'+opt+'/commit.raw'];assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==b['baseline']
  for p,h in b['inputs'].items():assert sha((ROOT/p).read_bytes())==h and sha(files['build-'+opt+'/source/'+p])==h
  for p,h in b['generated'].items():assert sha(files['build-'+opt+'/'+p])==h
  cmd=b['events'][-1]['command'];assert '-fcheck=all' in cmd and '-ffpe-trap=invalid,zero,overflow' in cmd and '-'+opt.upper() in cmd
  assert [p for p in cmd if p.endswith('.f90')]==b['closure']
  roots=set()
  for p in b['closure']:
   matches=[key for key in b['inputs'] if p.endswith('/'+key)]
   if matches:
    assert len(matches)==1;roots.add(p[:-len(matches[0])])
   else:assert Path(p).name in b['generated'] and Path(p).parent==Path(cmd[-1]).parent
  assert len(roots)==1
  driver=files['build-'+opt+'/native_driver.f90'];assert b'p%parameter_set_id=p%parameter_set_id+1000000_int64' in driver and b'supply%exact_empty_pool_chemistry=.true.' in driver
  seen=set()
  def rows(p):return list(csv.DictReader(io.StringIO(files[p].decode())))
  for c in r['cases']:
   key=(c['exponent'],c['uptake'],c['grid']);assert key not in seen;seen.add(key)
   case=f'{prefix}{key[0]}-{key[1]}-{key[2]}/'
   assert b'ends_day=.1,.2,.3,.4' in files[case+'input.nml']
   swp=files[case+'project.swp'].decode();assert f'FREXP={key[0]}' in swp and f'TSCF={key[1]}' in swp
   for p in ['restart.bin','state.csv','endpoint.csv']:assert files[case+'full/'+p]==files[case+'resume/'+p]
   for label,identity in [('full',1670001),('split',1670001),('resume',1670001)]:
    raw=files[case+label+'/restart.bin'];assert struct.unpack_from('<q',raw,12)[0]==identity and struct.unpack_from('<I',raw,len(raw)-4)[0]==zlib.crc32(raw[:-4])
   raw=files[case+'wrong-policy.bin'];assert struct.unpack_from('<q',raw,12)[0]==670001 and struct.unpack_from('<I',raw,len(raw)-4)[0]==zlib.crc32(raw[:-4])
   assert case+'wrong-policy/restart.bin' not in files
   budget=rows(case+'full/budget.csv');assert len(budget)==4 and budget[2:]==rows(case+'resume/budget.csv')
   assert [float(v['t1_day']) for v in budget]==[.1,.2,.3,.4]
   assert sum(float(v['actual_transpiration_cm']) for v in budget)>0 and max(float(v['infiltration_cm']) for v in budget)>.09
   for row in budget:
    for s,u in [('water','cm'),('solute','mg_cm2')]:
     residual=float(row[f'{s}_end_{u}'])-float(row[f'{s}_start_{u}'])-float(row[f'{s}_in_{u}'])+float(row[f'{s}_out_{u}'])
     assert abs(residual)<1e-10;maxima[s]=max(maxima[s],abs(residual))
   state=rows(case+'full/state.csv');n=60 if key[2]=='uniform' else 41;assert len(state)==n
   for i,row in enumerate(state):
    v={k:float(x) for k,x in row.items()};assert all(math.isfinite(x) for x in v.values())
    h=v['dz_cm'];theta=v['theta'];conc=v['concentration_mg_cm3'];m=v['dissolved_mg_cm2'];s=v['sorbed_mg_cm2']
    assert min(h,theta,conc,m,s)>=0 and abs(m-theta*h*conc)<1e-11
    capacity=.26 if i<20 else .6;assert abs(s-capacity*h*conc**key[0])<1e-11
   endpoint=rows(case+'full/endpoint.csv')[0];assert float(endpoint['time_day'])==.4 and float(endpoint['pond_cm'])==0
   assert abs(sum(float(v['theta'])*float(v['dz_cm']) for v in state)-float(endpoint['total_water_cm']))<1e-10
   assert abs(sum(float(v['dissolved_mg_cm2'])+float(v['sorbed_mg_cm2']) for v in state)+float(endpoint['pond_solute_mg_cm2'])-float(endpoint['total_solute_mg_cm2']))<1e-10
   profiles[(opt,*key)]=[float(x) for row in state for x in row.values()]
  assert seen==set(itertools.product([.5,1.,2.],[0.,1.],['uniform','unequal']))
  for e in r['events']:
   if e.get('expected')=='REJECT':assert e['returncode']!=0 and 'restart rejected' in e['stdout']
   else:assert e['returncode']==0
  processes+=len(r['events'])
 diff=max(abs(a-b) for key,p in profiles.items() if key[0]=='o0' for a,b in zip(p,profiles[('o2',*key[1:])]))
 assert diff<1e-12
 preservation=json.loads(files['PRESERVATION.json']);assert preservation['qualified'] and preservation['controls']>=13
 return dict(status='BOUNDED_NATIVE_FCT_AND_FRESH_PROCESS_RESTART_QUALIFIED',cases=24,processes=processes,exact_restarts=24,wrong_policy_rejections=24,maxima=maxima,max_O0_O2_difference=diff,days=.4,original_full_historical_project=False,production_activated=False)
def controls(files):
 passed=[];base='native-o0/0.5-0.0-uniform/'
 for p in [base+'full/restart.bin',base+'resume/state.csv',base+'wrong-policy.bin','build-o0/native_driver.f90','PRESERVATION.json']:
  f=dict(files);f.pop(p)
  try:assess(f)
  except (AssertionError,KeyError,ValueError):passed.append('missing '+p);continue
  raise AssertionError('accepted missing '+p)
 def reject(label,change):
  f=dict(files);change(f)
  try:assess(f)
  except (AssertionError,KeyError,ValueError):passed.append(label);return
  raise AssertionError('accepted '+label)
 def forged_root(f):
  b=json.loads(f['build-o0/build.json']);old=b['closure'][0];new='/foreign'+old
  b['closure']=[new if p==old else p for p in b['closure']]
  b['events'][-1]['command']=[new if p==old else p for p in b['events'][-1]['command']]
  f['build-o0/build.json']=json.dumps(b).encode();r=json.loads(f['native-o0/RESULT.json']);r['build']=b;f['native-o0/RESULT.json']=json.dumps(r).encode()
 reject('mixed archived source roots with rebound execution metadata',forged_root)
 def forged_policy(f):
  p=base+'wrong-policy.bin';raw=bytearray(f[p]);struct.pack_into('<q',raw,12,1670001);raw[-4:]=struct.pack('<I',zlib.crc32(raw[:-4]));f[p]=bytes(raw)
 reject('wrong policy control replaced by CRC-valid active identity',forged_policy)
 def lost_limit(f):
  p='build-o0/native_driver.f90';f[p]=f[p].replace(b'supply%exact_empty_pool_chemistry=.true.',b'supply%exact_empty_pool_chemistry=.false.')
  b=json.loads(f['build-o0/build.json']);b['generated']['native_driver.f90']=sha(f[p]);f['build-o0/build.json']=json.dumps(b).encode()
  r=json.loads(f['native-o0/RESULT.json']);r['build']=b;f['native-o0/RESULT.json']=json.dumps(r).encode()
 reject('lost analytical empty-pool policy with rebound hashes',lost_limit)
 return passed
def unpack():
 i=json.loads((HERE/'NATIVE_EVIDENCE_INDEX.json').read_text());raw=base64.b64decode((HERE/'NATIVE_EVIDENCE.tar.xz.b64').read_bytes());assert sha(raw)==i['sha256']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==len({m.name for m in ms}) and all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in ms)
  f={m.name:t.extractfile(m).read() for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b) for p,b in f.items()};return f
if __name__=='__main__':
 f=unpack();r=assess(f);r['controls']=controls(f);print(json.dumps(r,indent=2))
