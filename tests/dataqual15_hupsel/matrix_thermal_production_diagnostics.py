"""Precise actual before/current failed verdicts and real deployed six-case data."""
import argparse,json,zipfile,struct,zlib
from pathlib import Path
import matrix_thermal_production as owner
p=owner.private;D=owner.ROOT/'integration/dataqual15_hupsel'
STEM='MATRIX_THERMAL_PRODUCTION_DIAGNOSTICS_20261106'

def observe():
 before_file=D/'MATRIX_THERMAL_PRODUCTION_BEFORE_20261106.zip';fail_file=D/'MATRIX_THERMAL_PRODUCTION_FAILURES_20261106.zip';mc_file=D/'MATRIX_THERMAL_PRODUCTION_MC_20261106.zip'
 with zipfile.ZipFile(before_file) as z:
  report=json.loads(z.read('RESULT.json'));assert report['baseline']==owner.BASE and report['tree']=='ac02481fd882553771ee893a42e2646aaca5f874'
  assert len(report['events'])==16 and all(not e['censored'] and e['returncode']!=0 for e in report['events'])
  before={}
  for e in report['events']:
   for stream in ('stdout','stderr'):assert owner.sha(z.read(e['case']+'.'+stream))==e[stream+'_sha256']
   before[e['case']]=(z.read(e['case']+'.stdout')+z.read(e['case']+'.stderr')).decode()
 records=json.loads((D/'MATRIX_THERMAL_PRODUCTION_FAILURES_20261106.json').read_text());assert owner.sha(fail_file.read_bytes())==records['archive_sha256']
 shared={
  'SWAP5-PERF01 exact implementation admission':('performance','AssertionError: unreviewed delta'),
  'PUB-P2E02 Reference uncertainty':('p2e02','mod_drainage_dramet3_response.mod'),
  'PUB-P2E04 Reference B/C sweeps':('p2e04','mod_drainage_dramet3_response.mod'),
  'PUB-P2E04 Reference failure census':('census','mod_drainage_dramet3_response.mod'),
  'PUB-ME D1 transition authority':('d1','D1 workunit changed production/reference source'),
  'PUB-ME D3 origin authority':('d3','D3 changed production/reference source'),
  'PUB-P2E06 Reference local-balance scaling':('p2e06','reference tree differs from P2E05 canonical base'),
  'PUB-P2E07 Reference cancellation floor':('p2e07','P2E07 mutated src or reference'),
  'PUB-P2E08 Reference valid calibration domain':('p2e08','P2E08 mutated src or reference relative to reconciled canonical'),
  'Hupsel production native crop logical successor':('logical-owner','rotation_native_admission.py'),
  'Hupsel production diagnostic source successor':('logical-owner','rotation_native_admission.py'),
  'Registered Grassgrowth thermal production profile':('thermal-owner','thermal_profile_production.py'),
  'DATAQUAL15 original Grassgrowth sprint':('native-layout','unreviewed production paths'),
  'MC-SOL01 dynamic accepted temperature decay':('mc-source','AssertionError: unreviewed delta'),
 }
 earlier={
  'PUB-P2E09 Reference-only threshold freeze':('p2e09','PUB_P2E09_GATE_FAIL admitted P2E08 Reference replay','PUB_P2E09_GATE_FAIL P2E09 mutated src or reference relative to current canonical merge-base'),
  'PUB-P2E10 broad E0 paired matrix':('p2e10','PUB_P2E10_GATE_FAIL solver contract drift','PUB_P2E10_GATE_FAIL P2E10 mutated src or reference'),
 }
 adjudicated=[]
 with zipfile.ZipFile(fail_file) as z:
  assert {n:owner.sha(z.read(n)) for n in z.namelist()}==records['members'];jobs=json.loads(z.read('JOBS.json'));assert len(jobs)==16
  for workflow in jobs:
   for job in workflow['jobs']:
    text=z.read(str(job['id'])+'.log').decode();name=workflow['name'];assert 'Process completed with exit code' in text
    if name in shared:
     case,signature=shared[name];assert signature in text and signature in before[case]
     if case=='logical-owner':assert '=={SOURCE}' in text and '=={SOURCE}' in before[case]
     if case=='thermal-owner':assert '==PATHS' in text and '==PATHS' in before[case]
     classification='ACTUAL_SAME_FIRST_REFUSAL_NOT_OLD_PASS'
    else:
     case,old_signature,signature=earlier[name];assert old_signature in before[case] and signature in text
     classification='EARLIER_CURRENT_SOURCE_REFUSAL_DISTINCT_FROM_LATER_PREDECESSOR_FAILURE'
    adjudicated.append(dict(run=workflow['run'],job=job['id'],workflow=name,case=case,current_signature=signature,classification=classification,verdict='FAILED_RETAINED'))
 assert len(adjudicated)==19
 # Actual deployed module, original complete source-owned six-case execution.
 with zipfile.ZipFile(mc_file) as current,zipfile.ZipFile(D/'MATRIX_THERMAL_BUILD_FINAL_MC_20261106.zip') as previous:
  assert owner.sha(mc_file.read_bytes())=='75ed91f749ee855d9029583f06e06b712a857dfd38101b27dcfc8c5cd690d121'
  names=current.namelist();assert len(names)==len(set(names)) and set(names)==set(previous.namelist())
  binaries=[n for n in names if n.endswith('.bin')];assert len(binaries)==426 and all(current.read(n)==previous.read(n) for n in binaries)
  for label in ('thermal','nonlinear-0.5','nonlinear-0.8','nonlinear-1.0005','nonlinear-1.5','nonlinear-2'):
   path=label+'-physical/result.json';r=json.loads(current.read(path));old=json.loads(previous.read(path));assert {n for n,h in old['inputs'].items() if h!=r['inputs'][n]}=={owner.SOURCE}
   assert r['inputs'][owner.SOURCE]==owner.sha(owner.normal((owner.ROOT/owner.SOURCE).read_bytes()))
   q=json.loads(current.read(label+'-qualified/result.json'));assert q['physical_sha256']==owner.sha(current.read(path))
   assert r['status']=='FOCUSED_PHYSICAL_PASS_REFINEMENT_ASSESSMENT_PENDING_NOT_ADMITTED' and q['status']=='DYNAMIC_ACCEPTED_ENDPOINT_DECAY_O0_O2_RESTART_REFINEMENT_CRASH_PASS_NOT_ADMITTED'
   assert all(e['returncode']==e['expected_returncode'] for e in q['events'])
 return dict(before_zip_sha256=owner.sha(before_file.read_bytes()),source_failure_zip_sha256=owner.sha(fail_file.read_bytes()),deployed_mc_zip_sha256=owner.sha(mc_file.read_bytes()),adjudicated=adjudicated,deployed_six_cases=True,all426_native_files_exact=True,whole_scientific_admission=False,old_red_pass_claim=False)

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--seal',action='store_true');a=parser.parse_args();owner.guard();actual=observe();file=D/(STEM+'.json')
 if a.seal:file.write_text(json.dumps(actual,indent=2)+'\n')
 else:assert actual==json.loads(file.read_text())
 print('EXACT_FBA16_BEFORE_FAILURES_19_CURRENT_FAILED_JOBS_AND_REAL_DEPLOYED_SIX_CASE_NATIVE_PASS_NO_OLD_RED_PASS_CLAIM')
