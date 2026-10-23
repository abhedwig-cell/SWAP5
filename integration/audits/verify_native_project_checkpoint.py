"""Verify bounded draft checkpoint. NEVER an annual or canonical admission gate."""
import argparse,base64,csv,hashlib,io,json,math,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
STATUS='integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'
def sha(raw):return hashlib.sha256(raw).hexdigest()
def node(document):
 p=document
 for key in ['swp_water_successor','daily_meteo_successor','etref_successor','simple_crop_preparation_successor','root_joint_successor','substep_feedback_work']:p=p[key]
 return p
def capsule(path):
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode(path.read_bytes())),mode='r:xz')as archive:
  members=archive.getmembers();assert all(m.isfile()and not m.name.startswith('/')and'..'not in Path(m.name).parts for m in members)
  assert len({m.name for m in members})==len(members)
  files={m.name:archive.extractfile(m).read()for m in members}
 manifest=json.loads(files['MANIFEST.json'])
 assert manifest=={p:sha(v)for p,v in files.items()if p!='MANIFEST.json'},'capsule manifest'
 return files
def validate(files):
 current=json.loads(files['CURRENT.json']);assert current['status']=='PROPOSED_ANNUAL_TRANSPORT_BLOCKED_NOT_ADMITTED'
 for p,h in current['postimages'].items():assert sha((ROOT/p).read_bytes())==h,('changed current input',p)
 status=json.loads((ROOT/STATUS).read_bytes());record=node(status).pop('native_project_successor')
 baseline=json.loads(subprocess.check_output(['git','show',current['baseline']+':'+STATUS],cwd=ROOT))
 assert status==baseline,'predecessor status changed'
 assert record['full_historical_migration']is False
 def report(group):return json.loads(files[group+'/result.json'])
 for group,expected in [('preparation-final','NATIVE_PROJECT_HISTORICAL_PREPARATION_ONLY_O0_O2_PASS'),
  ('short-final','NATIVE_PROJECT_SHORT_PASS'),('spatial','TRANSPORT_SPATIAL_COARSE_NEGATIVE_RESOLVED_MASS_O0_O2_PASS'),
  ('rejection','PROJECT_REAL_COARSE_REJECTION_ATOMIC_O0_O2_PASS')]:
  r=report(group);assert r['status']==expected,(group,r['status'])
  for p,h in r['inputs'].items():assert sha((ROOT/p).read_bytes())==h,('executed input changed',p)
 prep=report('preparation-final');assert prep['original_exact_values']==39114 and prep['invalid_inputs']==12
 assert set(prep['cases'])=={'O0-annual1998','O2-annual1998','O0-cross_year','O2-cross_year'}
 for name,case in prep['cases'].items():
  folder='preparation-final/'+name.replace('-', '/',1)
  audit=json.loads(files[folder+'/audit.json']);assert case['source_sha256']==audit['original_sources']
  for p in audit['prepared_periods']:
   original=list(csv.DictReader(io.StringIO(files[folder+'/oracle/original-'+str(p['index'])+'.csv'].decode())))
   assert [{k:float(v)for k,v in r.items()}for r in original]==[{k:float(v)for k,v in r.items()}for r in p['plan']]
 short=report('short-final');assert(short['invalid_inputs'],short['fresh_restarts'],short['exact_single_files'])==(14,2,8)
 assert short['optimizations']==['O0','O2']
 for group,case in current['failed_years'].items():
  r=report(group);assert r['events'][-1]['returncode']!=0 and r['events'][-1]['expected_success']
  budgets=[p for p in files if p.startswith(group+'/')and'/annual1998/full.pending-'in p and p.endswith('/budget.csv')]
  assert len(budgets)==1,(group,budgets)
  rows=list(csv.DictReader(io.StringIO(files[budgets[0]].decode())));assert len(rows)==case['days']
  for row in rows:
   assert all(math.isfinite(float(v))for v in row.values())
   assert abs(float(row['water_residual_cm']))<1e-10 and abs(float(row['solute_residual_mg_cm2']))<1e-10
 for opt in ['O0','O2']:
  prefix='rejection/'+opt+'/'
  assert files[prefix+'before.bin']==files[prefix+'diagnostic-rejected.bin']
  assert b'229           3        2221'in files[prefix+'stdout']or [229,3,2221]==list(map(int,next(l for l in files[prefix+'stdout'].decode().splitlines()if'rejected window/process/completed:'in l).split(':')[1].split()))
 assert not subprocess.check_output(['git','diff','--name-only',current['baseline'],'--','src'],cwd=ROOT).strip()
 return dict(status=current['status'],original_preparation_exact_values=39114,short_fresh_restarts=2,
  invalid_inputs=26,annual_transport='FAILED_NOT_QUALIFIED',cross_year_transport='NOT_REACHED_DEPENDENCY')
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--evidence',type=Path,required=True);ap.add_argument('--self-test',action='store_true');a=ap.parse_args()
 files=capsule(a.evidence);result=validate(files)
 if a.self_test:
  changed=dict(files);c=json.loads(changed['CURRENT.json']);c['status']='CANONICALLY_ADMITTED';changed['CURRENT.json']=json.dumps(c).encode()
  try:validate(changed)
  except AssertionError:pass
  else:raise AssertionError('false admission accepted')
  result['false_admission_negative']='PASS'
 print(json.dumps(result))
if __name__=='__main__':main()
