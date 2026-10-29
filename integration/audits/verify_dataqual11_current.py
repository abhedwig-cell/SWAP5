"""Admit isolated original-input/forcing additions; preserve every old model byte."""
import csv,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='61f723911c1936fd1860947053857eb7b7b9a84b'
PARENT='integration/audits/verify_dataqual10_current.py'
SELF='integration/audits/verify_dataqual11_current.py'
STATUS='integration/dataqual11/STATUS.json'
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def baseline(p):return subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT)
def parent_projection():
 old=baseline(PARENT).decode();needle='def source(reader=None,changed=None):\n'
 assert old.count(needle)==1
 return old.replace(needle,needle+" if (ROOT/'integration/dataqual11/STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['source'](reader,changed)\n",1).encode()
def source(reader=None,changed=None):
 if (ROOT/'integration/dataqual12/STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_dataqual12_current.py'))['source'](reader,changed)
 if reader is None:reader=lambda p:(ROOT/p).read_bytes()
 s=json.loads(reader(STATUS));assert s['baseline']==BASE
 assert not git('diff','HEAD','--','src','app','tools','tests','reference','integration/audits')
 delta={r.split('\t')[1]:r.split('\t')[0]for r in git('diff','--name-status',BASE,'HEAD','--','src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance').splitlines()}
 assert delta==s['allowed_delta'],'unreviewed scientific delta'
 assert delta[PARENT]=='M' and all(v=='A'for p,v in delta.items()if p!=PARENT)
 assert reader(PARENT)==parent_projection(),'predecessor projection changed'
 # The predecessor's immutable evidence still requires every old provider,
 # driver and owning validator. Only its exact delegation is replaced.
 previous=json.loads(reader('integration/dataqual10/STATUS.json'))
 for p,h in previous['postimages'].items():
  if p!=PARENT:assert sha(reader(p))==h,p
 for p,h in s['source_files'].items():assert sha(reader(p))==h,p
 manifest_path='reference/swap-4.3.1/projects/MANIFEST.json'
 assert sha(reader(manifest_path))==s['original_manifest_sha256']
 manifest=json.loads(reader(manifest_path))
 assert manifest['distribution_sha256']=='2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360'
 for p,h in manifest['members'].items():
  b=reader('reference/swap-4.3.1/projects/'+p);assert sha(b)==h['sha256']and len(b)==h['bytes'],p
 raw=reader('integration/dataqual11/EVIDENCE.tar.xz');assert sha(raw)==s['evidence_sha256']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  members=t.getmembers();assert len(members)==len({m.name for m in members})
  assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in members)
  files={m.name:t.extractfile(m).read()for m in members}
 q=json.loads(reader('integration/dataqual11/RAIN_QUALIFICATION.json'))
 assert q==json.loads(files['rain-qualification/RESULT.json'])
 assert q['status']=='PASS_FORCING_ONLY'
 for key in ['full_model_executed','water_balance_qualified','solute_balance_qualified','restart_qualified']:assert q[key]is False
 for p,h in q['dependencies'].items():assert sha(reader(p))==h,p
 for opt in ['O0','O2']:
  assert b'DAILY_RAIN_DURATION_CONTRACT_PASS'in files[f'rain-qualification/{opt}/contract.stdout']
  oracle=files[f'rain-qualification/{opt}/oracle.stdout'].split()
  assert oracle==[b'ORIGINAL_DURATION_ORACLE_PASS',b'1827',b'951']
  raw_events=files[f'rain-qualification/{opt}/rain_events.csv']
  expected=next(r for r in q['results']if r['optimization']==opt)
  assert sha(raw_events)==expected['output_sha256']
  rows=list(csv.DictReader(io.StringIO(raw_events.decode())))
  met=reader('reference/swap-4.3.1/projects/2.grassgrowth/260.met').decode()
  weather=list(csv.DictReader(l for l in met.splitlines()if l.strip()and not l.startswith('*')))
  depths=[0.]*len(weather);start=0.
  for row in rows:
   end=float(row['end_day']);rate=float(row['rate_cm_day']);assert end>start and rate>=0
   depths[int(start+1e-10)]+=(end-start)*rate;start=end
  assert start==len(weather)==1827 and len(rows)==2778
  assert max(abs(d-float(w['Rain'])*.1)for d,w in zip(depths,weather))<=1e-10
 assert files['rain-qualification/O0/rain_events.csv']==files['rain-qualification/O2/rain_events.csv']
 matrix=json.loads(reader('integration/dataqual11/MIGRATION_MATRIX.json'))
 assert matrix['denominator']['independent_original_projects']==3
 assert matrix['new_integral_model_projects_executed']==0 and matrix['new_physical_laws']==0
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def self_test():
 source();s=json.loads((ROOT/STATUS).read_bytes())
 paths=list(s['source_files'])+[PARENT,'reference/swap-4.3.1/projects/2.grassgrowth/260.met','integration/dataqual11/EVIDENCE.tar.xz']
 for p in paths:
  try:source(lambda q:(ROOT/q).read_bytes()+b' 'if q==p else(ROOT/q).read_bytes())
  except AssertionError:continue
  raise AssertionError('accepted corrupt addition '+p)
 return dict(passed=len(paths))
if __name__=='__main__':source();print(json.dumps(dict(source='PASS',controls=self_test())))
