"""Verify exact canonical admission and retain every broader FAILED observation."""
import copy,io,json,subprocess,zipfile
from pathlib import Path
import generation_publication_admission as owner
ROOT=owner.ROOT;BASE=ROOT/'integration/dataqual15_hupsel';sha=owner.sha

def audit(receipt=None,source=None,logs=None):
 owner.guard()
 r=receipt if receipt is not None else json.loads((BASE/'GENERATION_PUBLICATION_CANONICAL_RECEIPT_20261106.json').read_text())
 raw=(BASE/'GENERATION_PUBLICATION_SOURCE_ADJUDICATION_20261106.json').read_bytes();assert sha(raw)==r['raw_source_adjudication_sha256']
 s=source if source is not None else json.loads(raw)
 assert r['source_pr']==1579 and r['actual_source_merge']=='2eaf9c76f6c990358204d2ddc3e83c8357fe89f2'
 assert r['qualified_source_head']==s['source_head']=='521629d66592adeb58a9cd1f60b30fc89ff6628a'
 for ref in (r['actual_source_merge'],r['qualified_source_head']):assert owner.git('rev-parse',ref+'^{tree}')==r['qualified_and_actual_tree']=='b2706d6c549af77d223b0f2042aa39c62a07cacc'
 subprocess.run(['git','merge-base','--is-ancestor',r['actual_source_merge'],'HEAD'],cwd=ROOT,check=True,capture_output=True)
 assert r['production_admission'] is True and r['whole_scientific_admission'] is False and r['all_ci_pass'] is False
 assert s['whole_scientific_admission'] is False and s['all_ci_pass'] is False
 assert len(s['workflows'])==s['terminal']==r['source_workflows_terminal']==41
 assert all(w['status']=='completed' and w['conclusion'] in ('success','failure') for w in s['workflows'])
 assert sum(w['conclusion']=='success' for w in s['workflows'])==r['source_success']==s['success']==24
 failed={w['id'] for w in s['workflows'] if w['conclusion']=='failure'};assert len(failed)==r['source_failed']==s['failed']==17
 assert len(s['failed_jobs'])==r['failed_jobs_individually_adjudicated']==20 and {j['run_id']for j in s['failed_jobs']}==failed
 archive=(BASE/'GENERATION_PUBLICATION_SOURCE_LOGS_20261106.zip').read_bytes();assert sha(archive)==r['raw_source_logs_zip_sha256']
 if logs is None:
  with zipfile.ZipFile(io.BytesIO(archive))as z:logs={n:z.read(n)for n in z.namelist()}
 assert logs['SOURCE_ADJUDICATION.json']==raw
 before=json.loads((BASE/'GENERATION_PUBLICATION_BASELINE_POSIX_20261106.json').read_text())['report'];earlier=[]
 for j in s['failed_jobs']:
  rawlog=logs['job-'+str(j['job_id'])+'.json'];assert sha(rawlog)==j['raw_log_sha256'];text=json.loads(rawlog)['content']
  assert j['current_verdict']=='FAILED' and j['actual_before']==before[j['case']] and j['actual_before']['returncode']!=0 and j['actual_before']['censored'] is False
  assert j['current_signature'] in text
  if j['attribution']=='EARLIER_UNMODIFIED_NO_PRODUCTION_DELTA_REFUSAL':
   assert j['case'] in ('p2e09','p2e10') and j['current_signature']!=before[j['case']]['signature'];earlier.append(j['case'])
  else:assert j['attribution']=='SAME_OBSERVED_LEGACY_FAILURE_PREDICATE' and j['current_signature']==before[j['case']]['signature']
 assert sorted(earlier)==['p2e09','p2e10']
 assert not owner.git('diff','--name-only',s['exact_predecessor'],s['source_head'],'--',*s['legacy_gate_paths_unchanged'])
 reader_raw=(BASE/'GENERATION_PUBLICATION_SWP_READER_20261106.json').read_bytes();assert sha(reader_raw)==r['swp_reader_record_sha256'];reader=json.loads(reader_raw)
 assert reader['actual_native_workflow_steps_passed']==4 and reader['whole_workflow_verdict']=='FAILED' and reader['whole_scientific_admission'] is False
 data=(BASE/'GENERATION_PUBLICATION_SWP_READER_20261106.zip').read_bytes();assert sha(data)==reader['archive_sha256']
 with zipfile.ZipFile(io.BytesIO(data))as z:
  assert {n:sha(z.read(n))for n in z.namelist()if not n.endswith('/')}==reader['members']
  for n,status in reader['native_result_statuses'].items():assert json.loads(z.read(n))['status']==status and status in ('PASS','ORIGINAL_SWP_CHEMISTRY_O0_O2_MAPPING_BALANCE_RESTART_REJECTION_PASS')
 return dict(exact_canonical_source=True,terminal=41,success=24,failed=17,failed_jobs=20,swp_native_stages=4,whole_scientific_admission=False)

def main():
 result=audit();r=json.loads((BASE/'GENERATION_PUBLICATION_CANONICAL_RECEIPT_20261106.json').read_text());s=json.loads((BASE/'GENERATION_PUBLICATION_SOURCE_ADJUDICATION_20261106.json').read_text())
 for label in ('tree','verdict','science'):
  rr=copy.deepcopy(r);ss=copy.deepcopy(s)
  if label=='tree':rr['qualified_and_actual_tree']='0'*40
  if label=='verdict':ss['failed_jobs'][0]['current_verdict']='PASS'
  if label=='science':rr['whole_scientific_admission']=True
  try:audit(rr,ss)
  except AssertionError:pass
  else:raise AssertionError('corrupt canonical receipt admitted: '+label)
 print('EXACT_CANONICAL_PUBLICATION_SOURCE_AND_ALL_FAILED_VERDICTS_PRESERVED_THREE_REFUSALS_PASS',result)
if __name__=='__main__':main()
