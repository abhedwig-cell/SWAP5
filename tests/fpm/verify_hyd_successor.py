#!/usr/bin/env python3
"""Exact bounded HYD proof and default-OFF projection, not whole-model F-CI."""
import base64,hashlib,io,json,os,subprocess,sys,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='b7faa67907e75d4447ceb126e40f9de47dbab165'
PROJECTION_BASE='2194651f55881e5aa7ea7ffd3f9e2eebfae952f9'
STATUS='integration/audits/SWAP431_HYD_HYST_STATUS.json'
SURFACE=['src','tests','tools','reference','.github']
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def check(value,label):
 if not value:raise ValueError(label)
def sha(b):return hashlib.sha256(b).hexdigest()
def record():return json.loads((ROOT/STATUS).read_text())['full_profile_followup_20261016']
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def projected_bytes(path):
 recipe=json.loads((ROOT/'tests/fpm/hyd_default_projection.json').read_text())
 check(recipe['base']==PROJECTION_BASE,'unknown HYD projection base')
 raw=(ROOT/path).read_text().splitlines(keepends=True)
 for edit in reversed(recipe['files'][path]):
  i,j=edit['start'],edit['end'];check(''.join(raw[i:j])==edit['postimage'],'unknown HYD projection hunk')
  raw[i:j]=edit['preimage'].splitlines(keepends=True)
 b=''.join(raw).encode()
 check(b==subprocess.check_output(['git','show',PROJECTION_BASE+':'+path],cwd=ROOT),'HYD default preimage drift '+path)
 return b
def verify_source(git_reader=None):
 g=git if git_reader is None else git_reader;r=record();g('merge-base','--is-ancestor',BASE,'HEAD')
 check(not g('status','--porcelain','--',*SURFACE),'dirty HYD scientific surface')
 rows={s.split('\t')[1]:s.split('\t')[0] for s in g('diff','--name-status',BASE,'HEAD','--',*SURFACE).splitlines()}
 expected=r['postimages'];check(rows=={p:x['status'] for p,x in expected.items()},'foreign HYD dependency delta')
 source={'src/solver/mod_b110_default_mvg_provider.f90','src/solver/mod_reference_richards_temporal_indicator.f90','src/runtime/mod_fmr_serialized_reference_backend.f90'}
 check({p for p in expected if p.startswith('src/')}==source,'HYD production scope changed')
 for p,x in expected.items():check(g('rev-parse','HEAD:'+p)==x['blob']==blob((ROOT/p).read_bytes()),'HYD postimage drift '+p)
 check(g('rev-parse','HEAD:reference')==g('rev-parse',BASE+':reference'),'HYD reference drift')
 for p in source:projected_bytes(p)
 # Every admitted root owner input remains exactly at the new canonical base.
 # Its original source/evidence guards run unchanged at that immutable checkout.
 for p in g('diff','--name-only',PROJECTION_BASE,BASE,'--',*SURFACE).splitlines():
  if p not in {'tests/fpm/verify_int12c_successor.py','tests/fpm/test_int12c_successor_controls.py'}:
   check((ROOT/p).read_bytes()==subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT),'admitted root input drift '+p)
 return {'baseline':BASE,'source_tree':g('rev-parse','HEAD:src'),'hyd_successor':True,'int12c_successor':True,
         'co2_successor':True,'swrd3_successor':True,'swrd2_successor':True,'harvest_successor':True,
         'surface_successor':True,'qualified':False,'admitted':False}
def evidence():
 a=record()['evidence'];raw=base64.b64decode((ROOT/a['path']).read_bytes());check(sha(raw)==a['decoded_sha256'],'HYD archive corruption')
 with tarfile.open(fileobj=io.BytesIO(raw)) as t:
  members=t.getmembers();check(len(members)==a['members']==len({m.name for m in members}),'HYD member set')
  check(all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members),'unsafe HYD archive')
  d={m.name:t.extractfile(m).read() for m in members}
 check(set(d)==set(a['member_sha256']),'HYD incomplete archive')
 for n,h in a['member_sha256'].items():check(sha(d[n])==h,'HYD member corruption '+n)
 return d
def incumbent_root(controls=False):
 base=ROOT.parent/'hyd-root-incumbent-b7faa679'
 if not base.exists():subprocess.run(['git','worktree','add','--detach',str(base),BASE],cwd=ROOT,check=True,capture_output=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=base,text=True).strip()==BASE,'root incumbent moved')
 check(not subprocess.check_output(['git','status','--porcelain'],cwd=base,text=True).strip(),'root incumbent dirty')
 path='tests/root-growth/check_daily_density_controls.py' if controls else 'tests/root-growth/verify_daily_density_successor.py'
 p=subprocess.run([sys.executable,'-B',path],cwd=base,capture_output=True,text=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
 check(p.returncode==0,'admitted root proof failed '+p.stderr[-1800:])
 if controls:return p.stdout
 result=json.loads(p.stdout);check(result['qualified'],'admitted root owner not qualified');return result
def verify_qualification():
 s=verify_source();d=evidence();r=record();runtime=json.loads(d['runtime/result.json']);literal=json.loads(d['literal/result.json'])
 expected={'analytical','runtime','direct_retention','fsi38','fsi25','incumbent_runtime','incumbent_macropore'}
 check(set(runtime['optimizations'])=={'O0','O2'},'HYD optimization missing')
 for opt in ['O0','O2']:
  runs=runtime['optimizations'][opt]['drivers'];check(set(runs)==expected,'HYD owner missing')
  for n,x in runs.items():check(x['exit']==0 and sha(d['runtime/'+opt+'-'+n+'.stdout'])==x['stdout_sha256'],'HYD failed native '+n)
 check(runtime['pass'] and all(runtime['identities'].values()),'HYD native identity failed')
 for n in expected:check(d['runtime/O0-'+n+'.stdout']==d['runtime/O2-'+n+'.stdout'],'HYD native drift '+n)
 out=d['runtime/O0-runtime.stdout']
 for n in ['MODEL2','MODEL3','MODEL6','POWER']:
  check(('SWAP431_HYD_ANALYTICAL_DYNAMIC_REPLAY_RESTART_'+n+'=PASS').encode() in out,'HYD dynamic/restart evidence missing '+n)
  check(('SWAP431_HYD_RUNTIME_'+n+'=PASS').encode() in out,'HYD runtime absent '+n)
 check(b'SWAP431_HYD_UNQUALIFIED_COMPOSITION=FAIL_CLOSED' in out,'HYD composition negative missing')
 check(literal['pass'] and literal['byte_identity'],'HYD literal failed')
 check(d['literal/O0.stdout']==d['literal/O2.stdout'] and b'HYD_LITERAL_CASES=256|MISMATCHES=0' in d['literal/O0.stdout'],'HYD literal corpus missing')
 for p,h in runtime['source_sha256'].items():check(sha((ROOT/p).read_bytes())==h,'HYD stale compiled source '+p)
 for p,h in literal['source_sha256'].items():
  if p!='@WC':check(sha((ROOT/p).read_bytes())==h,'HYD stale literal input '+p)
 check(literal['source_sha256']['@WC']=='d6038f1c2e0f4d061738bb2a176398cd89b7da59310394a2c4049fd0b4214126','HYD literal WC identity')
 check(b'INT12C_OUTPUT_SHA256=98e323ef612c82510d6dd3e5741c4d51b324051db7c13a6846d14798ed194717' in d['component/int12c.log'],'HYD incumbent component numeric drift')
 for p,h in json.loads(d['component/inputs.json']).items():check(sha((ROOT/p).read_bytes())==h,'HYD stale component input '+p)
 receiving=json.loads(d['root_receiving/RESULTS.json'])
 check(receiving['status']=='PASS','joint root receiving failed')
 rows=receiving['results'];check(len(rows)==8,'joint root receiving incomplete')
 check({(x['opt'],x['driver'],x['mode']) for x in rows}=={(o,n,m) for o in (0,2) for n in ('density','density_supply') for m in ('continuous','restart')},'joint root matrix changed')
 for p,h in receiving['source_inputs'].items():check(sha((ROOT/p).read_bytes())==h,'stale joint root source '+p)
 root_record=json.loads((ROOT/'integration/audits/MC_ROOT01_ROOT_GROWTH_OXYGEN_COMPOSITION_STATUS.json').read_text())['daily_density_supply_20261016']
 raw=base64.b64decode((ROOT/root_record['science_archive']['path']).read_bytes())
 check(sha(raw)==root_record['science_archive']['decoded_sha256'],'root science archive drift')
 with tarfile.open(fileobj=io.BytesIO(raw)) as t:prior=json.loads(t.extractfile('physical/RESULTS.json').read())['results']
 for row in rows:
  check(row['returncode']==0,'joint root native failure')
  old=[x for x in prior if all(x[k]==row[k] for k in ('opt','driver','moisture','mode'))]
  check(len(old)==1 and old[0]['stdout_sha256']==row['stdout_sha256'],'admitted density native drift')
 events=receiving['events']
 native=[(i,x) for i,x in enumerate(events) if any('/test-density' in a for a in x['command']) and '-o' not in x['command']]
 check(len(native)==8,'missing joint root command evidence')
 for i,event in native:
  matches=[b for p,b in d.items() if p.startswith('root_receiving/'+str(i).zfill(5)+'-') and p.endswith('.stdout')]
  check(len(matches)==1 and sha(matches[0])==event['stdout_sha256'],'joint root raw native drift')
  check(b'DAILY_DENSITY_ACTUAL_RICHARDS_SOURCE_RESTART=PASS' in matches[0],'joint root native marker absent')
 for name in ('density','density_supply'):
  check(len({x['stdout_sha256'] for x in rows if x['driver']==name})==1,'joint root restart/optimization drift')
 old=incumbent_root()
 return {**s,'incumbent_root_owner':old,'qualified':True,'preservation':'EXACT_DEFAULT_OFF_PROJECTION_AND_FRESH_DECLARED_OWNER_O0_O2',
         'full_fci':'NOT_CLAIMED_OWNER_PREREQUISITE_ONLY','highest':'NOT_SELECTED_IMPACT'}
if __name__=='__main__':print(json.dumps(verify_source() if '--source-only' in sys.argv else verify_qualification(),indent=2))
