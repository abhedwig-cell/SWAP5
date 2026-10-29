"""Bound original Hupsel fallow execution; retain historical evidence as historical."""
import csv,hashlib,io,json,math,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='3bcf96ccf64008bc7ba09c0ab8e82ea8f77d21e5'
STATUS='integration/dataqual12/STATUS.json'
sha=lambda b:hashlib.sha256(b).hexdigest()
def source(reader=None,changed=None):
 if reader is None:reader=lambda p:(ROOT/p).read_bytes()
 s=json.loads(reader(STATUS));assert s['baseline']==BASE
 domains=['src','app','tools','tests','reference','integration/audits','.github']
 delta=subprocess.check_output(['git','diff','--name-status',BASE,'HEAD','--',*domains],cwd=ROOT,text=True).strip()
 assert dict((r.split('\t')[1],r.split('\t')[0])for r in delta.splitlines())==s['scientific_delta'],'unreviewed delta'
 assert not subprocess.check_output(['git','diff','HEAD','--',*domains],cwd=ROOT), 'uncommitted source'
 for p,h in s['source_files'].items():assert sha(reader(p))==h,p
 # Every predecessor fingerprint remains binding unless explicitly replaced by
 # this measured successor. No old run is promoted to a current backend proof.
 for old,key in [('dataqual10','postimages'),('dataqual11','source_files')]:
  for p,h in json.loads(reader('integration/'+old+'/STATUS.json'))[key].items():
   if p not in s['source_files']:assert sha(reader(p))==h,p
 manifest=json.loads(reader('reference/swap-4.3.1/projects/MANIFEST.json'))
 for p,m in manifest['members'].items():
  raw=reader('reference/swap-4.3.1/projects/'+p);assert sha(raw)==m['sha256']and len(raw)==m['bytes'],p
 raw=reader('integration/dataqual12/EVIDENCE.tar.xz');assert sha(raw)==s['evidence_sha256']
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def verify():
 source();s=json.loads((ROOT/STATUS).read_bytes())
 with tarfile.open(ROOT/'integration/dataqual12/EVIDENCE.tar.xz','r:xz')as t:
  members=t.getmembers();assert len(members)==len({m.name for m in members})
  assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in members)
  files={m.name:t.extractfile(m).read()for m in members}
 inventory=json.loads(files.pop('MANIFEST.json'));assert inventory=={p:sha(b)for p,b in files.items()}
 for name in ['O0-5','O2-5','O2-30','O2-restart30','O2-120','O2-full120','O0-120']:
  prefix='model/'+name+'/';m=json.loads(files[prefix+'manifest.json']);assert m['status']=='COMPLETE'and m['returncode']==0
  for p,h in m['files'].items():assert sha(files[prefix+p])==h,(name,p)
  for p,h in m['build_input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
  rows=list(csv.DictReader(io.StringIO(files[prefix+'budget.csv'].decode())));assert rows
  assert all(math.isfinite(float(v))for row in rows for v in row.values())
  assert max(abs(float(r['water_residual_cm']))for r in rows)<1e-10
  assert max(abs(float(r['solute_residual_mg_cm2']))for r in rows)<1e-10
 for a,b in [('O0-5','O2-5'),('O2-30','O2-restart30'),('O2-full120','O2-120'),('O2-full120','O0-120')]:
  for p in ['state.csv','temperature.csv','endpoint.csv','restart.bin']:assert files['model/'+a+'/'+p]==files['model/'+b+'/'+p],(a,b,p)
 for opt in ['O0','O2']:
  for name in ['test_ppa_wu04a_black_process','test_ppa_wu04a_black_runtime','test_ppa_wu01_production_application_bootstrap','test_ppa_wu03_common_forcing_adapter']:
   assert b'PASS'in files['black/'+opt+'/'+name+'.log']
  assert 'PASS' in str(json.loads(files['thermal/result.json'])['results'][opt])
 for p in ['state.csv','temperature.csv','budget.csv','progress.csv','cost.csv','diagnostics.csv']:
  assert files['preservation/current/'+p]==files['preservation/baseline/'+p],p
 assert files['preservation/current/restart.bin'][72:-4]==files['preservation/baseline/restart.bin'][72:-4]
 result=json.loads((ROOT/'integration/dataqual12/RESULT.json').read_bytes());assert result==json.loads(files['RESULT.json'])
 assert result['new_original_projects_executed']==1 and result['longest_new_project_days']==120
 return result
if __name__=='__main__':print(json.dumps(verify(),indent=2))
