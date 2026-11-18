"""Close the completed thermal artifact contracts and only their remaining contexts."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import output_thermal_runtime as probe


def main():
    p=argparse.ArgumentParser()
    for key in ('prior-root','continuation-root'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();records={}
    for name,count in [('revalidation-O0',14),('revalidation-O2',14),('public',3),('reader',6),('preservation',4),('current-preservation',6),('direct-age-preservation',6)]:
        path=a.prior_root/name/'RESULT.json';q=json.loads(path.read_text());assert 'PASS' in q['status']
        if name.startswith('revalidation-'):assert q['model_executions']==0 and q['actual_full_periods']==14 and q['actual_unchanged_member_count']==16388 and q['individual_builds_sources_days_native_and_reports_unchanged'] is True
        elif name=='reader':assert len(q['reader_refusals'])==6 and len(q['descriptor_refusals'])==9
        else:assert len(q['profiles'])==count
        records[name]=dict(status=q['status'],sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    for name,count in [('aquifer-preservation',4),('boundary',2)]:
        path=a.continuation_root/name/'RESULT.json';q=json.loads(path.read_text());assert 'PASS' in q['status'] and len(q['profiles'])==count;records[name]=dict(status=q['status'],sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    q=dict(status='ACTUAL_THERMAL_MATRIX_PUBLIC_READER_PRIOR_AND_TERMINAL_CONTRACTS_COMPLETE_PASS',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=probe.ROOT,text=True).strip(),prior_run=44271536975,prior_run_conclusion='failure: final aquifer preservation CLI lacked required optimization before any extra model ran',read_only_matrix_model_executions=0,portable_prior_contexts=20,original_artifacts_retained_separately=True,completed_actual_contract_reports=records,functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
    (a.continuation_root/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(q['status'],flush=True)


if __name__=='__main__':main()
