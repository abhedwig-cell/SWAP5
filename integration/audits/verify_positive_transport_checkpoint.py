"""Strict research checkpoint gate. Annual and canonical admission remain false."""
import argparse,base64,csv,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
STATUS='integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'
def sha(raw):return hashlib.sha256(raw).hexdigest()
def capsule(path):
 raw=base64.b64decode(path.read_bytes())
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as archive:
  members=archive.getmembers()
  assert all(m.isfile()and not m.name.startswith('/')and'..'not in Path(m.name).parts for m in members)
  assert len({m.name for m in members})==len(members)
  files={m.name:archive.extractfile(m).read()for m in members}
 assert json.loads(files['MANIFEST.json'])=={p:sha(v)for p,v in files.items()if p!='MANIFEST.json'}
 return raw,files
def validate(files):
 c=json.loads(files['CURRENT.json'])
 assert c['status']=='BOUNDED_RESEARCH_DEFAULT_PRESERVATION_ANNUAL_BLOCKED'
 assert c['annual_qualified']is False and c['full_historical_migration']is False and c['canonically_admitted']is False
 paths=subprocess.check_output(['git','diff','--name-only',c['baseline'],c['source_checkpoint']],cwd=ROOT,text=True).splitlines()
 paths=[p for p in paths if p!=STATUS and not p.startswith('integration/audits/evidence/')]
 assert set(paths)==set(c['postimages']),'postimage census changed'
 for p,h in c['postimages'].items():assert sha((ROOT/p).read_bytes())==h,('current postimage changed',p)
 def report(group):return json.loads(files[group+'/result.json'])
 expected={
  'implicit-conservative-process':'TRANSPORT_IMPLICIT_POSITIVE_MASS_ORACLE_REFERENCE_REJECTION_O0_O2_PASS',
  'picard-final-default-root-daily':'ROOT_SUBSTEP_DAILY_O0_O2_MASS_RESTART_DEFAULT_EXACT_PASS',
  'picard-final-default-transaction':'ROOT_SUBSTEP_REAL_TRACE_REJECT_RETRY_ABA_O0_O2_PASS',
  'picard-final-transaction':'PICARD_ROOT_SUBSTEP_REAL_TRACE_REJECT_RETRY_ABA_O0_O2_PASS',
  'picard-final-policy-restart':'PICARD_TRANSPORT_NATIVE_WITHIN_POLICY_RESTART_CROSS_POLICY_REJECT_O0_O2_PASS',
  'picard-historical-exfiltration-source':'HISTORICAL_SURFACE_EXACT_ZERO_UPWARD_O0_O2_PASS',
  'picard-final-nut-cold':'NATIVE_TRUE_OUTPUT_PROJECT_O0_O2_FRESH_PASS',
  'picard-final-nut-calendar':'NATIVE_CALENDAR_OUTPUT_ACTUAL_O0_O2_FRESH_PASS',
  'picard-final-nut-thermal':'THERMAL_OUTPUT_ACTUAL_O0_O2_RESTART_ATOMIC_PASS',
  'picard-final-nut-harvest':'HARVEST_OUTPUT_PHASE_O0_O2_ATOMIC_FRESH_PASS',
  'picard-final-nut-saved':'SAVED_HARVEST_FALLOW_OUTPUT_O0_O2_ATOMIC_FRESH_PASS'}
 for group,status in expected.items():assert report(group)['status']==status,(group,report(group)['status'])
 for group in ['picard-final-nut-cold','picard-final-nut-calendar','picard-final-nut-thermal','picard-final-nut-harvest','picard-final-nut-saved']:
  r=report(group)
  for p,h in {**r.get('cold_input_sha256',{}),**r['input_sha256']}.items():assert sha((ROOT/p).read_bytes())==h,(group,p)
 cold=report('picard-final-nut-cold');prior=report('conservative-nut-cold')
 assert cold['results']==prior['results'],'incumbent native/default endpoint changed'
 for opt in ['O0','O2']:
  b=json.loads(files['picard-final-build-'+opt+'/column/build-complete.json'])
  assert '-'+opt in b['flags']and b['reused_provider_objects']==193
  for p,h in b['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,('current physical build changed',p)
  assert report('picard-final-day257-'+opt)['status']=='ACTUAL_WATER_DAY_PASS'
  assert report('picard-historical-exfiltration-day267-'+opt)['status']=='ACTUAL_WATER_DAY_PASS'
  for grid,days in [('coarse',266),('refined',64)]:
   group='picard-'+grid+'-'+opt;assert report(group)['status']=='FAILED'
   prefix=group+'/'+opt+'/annual1998/full.pending-'
   hits=[p for p in files if p.startswith(prefix)and p.endswith('/budget.csv')];assert len(hits)==1
   rows=list(csv.DictReader(io.StringIO(files[hits[0]].decode())));assert len(rows)==days
   for r in rows:
    assert abs(float(r['water_residual_cm']))<1e-10 and abs(float(r['solute_residual_mg_cm2']))<1e-10
   stdout=files[hits[0].rsplit('/',1)[0]+'/stdout']
   assert (b'3           0           2'in stdout)if grid=='coarse'else(b'2           2           1'in stdout)
   assert not any(p.startswith(group+'/'+opt+'/annual1998/full/')for p in files),'failed generation published'
 for grid in ['coarse','refined']:
  def artifact(opt,suffix):
   prefix='picard-'+grid+'-'+opt+'/'+opt+'/annual1998/full.pending-'
   return next(v for p,v in files.items()if p.startswith(prefix)and p.endswith('/'+suffix))
  for suffix in ['budget.csv','diagnostic-rejected.bin']:assert artifact('O0',suffix)==artifact('O2',suffix),(grid,suffix)
 assert b'CHEM_CARRIER_RETURN         140'in files['picard-final-day267-O2/0002.stdout']
 assert json.loads(files['picard-nut-cold/PROVENANCE_REJECTION.json'])['status']=='NOT_QUALIFICATION_MIXED_SOURCE_POSTIMAGES'
 assert report('picard-transaction-preflight')['status']=='INVALID_PREFLIGHT_O0_BUILD_SUPPLIED_FOR_BOTH_CASES'
 status=json.loads((ROOT/STATUS).read_bytes());p=status
 for key in ['swp_water_successor','daily_meteo_successor','etref_successor','simple_crop_preparation_successor','root_joint_successor','substep_feedback_work']:p=p[key]
 record=p.pop('native_project_successor')
 baseline=json.loads(subprocess.check_output(['git','show','80dbce8d325e9197a53b7189ad184bcdf91f6f5c:'+STATUS],cwd=ROOT))
 assert status==baseline,'predecessor status changed'
 assert record['full_historical_migration']is False
 return dict(status=c['status'],annual_qualified=False,canonically_admitted=False,current_controls=len(expected),failed_picard_daily_observations=660)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('capsule',type=Path);a=ap.parse_args()
 raw,files=capsule(a.capsule);r=validate(files)
 status=json.loads((ROOT/STATUS).read_text());p=status
 for key in ['swp_water_successor','daily_meteo_successor','etref_successor','simple_crop_preparation_successor','root_joint_successor','substep_feedback_work','native_project_successor','positive_transport_successor']:p=p[key]
 assert sha(raw)==p['research_evidence']['decoded_sha256'],'research capsule identity changed'
 r['decoded_sha256']=sha(raw);print(json.dumps(r,indent=2))
if __name__=='__main__':main()
