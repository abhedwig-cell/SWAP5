"""Validate original CI log/API identities and official digests of all four ZIPs."""
from contextlib import ExitStack
import json
from analytical_hydraulic_archives import Archive,SHA
from closed_implicit_state_portable_science import PRODUCER,RUNS
SPECS={'Ubuntu':{'O0':(140577714527,15208208109),'O2':(140577715122,15207653766)},'Windows':{'O0':(140577715220,15207459491),'O2':(140577715748,15210630271)}}


def audit(data):
    with ExitStack() as stack:
        store=Archive(data,'CLOSED_IMPLICIT_STATE13_QUALIFICATION_CUSTODY_AND_OBSERVER_RECOVERY_RAW_V9',stack);assert store.record['sha256']=='77657e4cb12a8c91199308a97b3d9639b6fc0cc077cff81a4d6846d9d70eef0a'
        custody=json.loads(store.get('closure13-portable-ci-original-logs-v1/CUSTODY.json'));assert custody['actual_producer']==PRODUCER and len(custody['jobs'])==4
        rows=[]
        for platform,opts in SPECS.items():
            api=json.loads((data/('CLOSED_IMPLICIT_STATE13_FIRST_'+platform.upper()+'_ORIGINAL_ARTIFACT_API_V1.json')).read_text());assert api['total_count']==len(api['artifacts'])==2
            for opt,(job_id,artifact_id) in opts.items():
                prefix='closure13-portable-ci-original-logs-v1/job-'+str(job_id);log=store.get(prefix+'.original.log');jobraw=store.get(prefix+'.original-job-api.json');runraw=store.get(prefix+'.original-run-api.json');job=json.loads(jobraw);run=json.loads(runraw);log.decode('utf8',errors='strict')
                assert job['id']==job_id and job['run_id']==run['id']==RUNS[platform] and job['head_sha']==run['head_sha']==PRODUCER and run['event']=='push' and job['status']==run['status']=='completed' and job['conclusion']==run['conclusion']=='success'
                assert job['name']=='qualify ('+opt+')' and PRODUCER.encode() in log and b'ALL_SELECTED_CLOSED_IMPLICIT_LOCAL_CONTEXTS_AND_NATIVE_CONTROLS_PASS_NOT_QUALIFIED' in log and b'INDEPENDENT_CLOSED_IMPLICIT_ORIGINAL_INPUTS_1E10_NATIVE_COLD_AND_COMPILED_REFUSALS_PASS_NOT_ADMITTED' in log
                record=next(v for v in custody['jobs'] if v['job_id']==job_id);assert record['original_log_sha256']==SHA(log) and record['original_job_API_sha256']==SHA(jobraw) and record['original_run_API_sha256']==SHA(runraw) and record['log_normalized_or_recoded'] is False
                descriptor=json.loads((data/('CLOSED_IMPLICIT_STATE13_FIRST_'+platform.upper()+'_'+opt+'_ORIGINAL_V1.json')).read_text());artifact=next(v for v in api['artifacts'] if v['id']==artifact_id)
                assert artifact['workflow_run']['id']==RUNS[platform] and artifact['workflow_run']['head_sha']==PRODUCER and artifact['size_in_bytes']==descriptor['bytes'] and artifact['digest']=='sha256:'+descriptor['sha256'] and descriptor['actual_artifact_id']==artifact_id
                rows.append(dict(platform=platform,optimization=opt,job_id=job_id,artifact_id=artifact_id,run_id=RUNS[platform],actual_producer=PRODUCER,original_log_sha256=SHA(log),original_artifact_sha256=descriptor['sha256'],official_artifact_bytes=descriptor['bytes']))
        return dict(status='FOUR_ORIGINAL_PORTABLE_CI_LOGS_OFFICIAL_JOB_RUN_ARTIFACT_API_IDENTITIES_AND_ZIP_DIGESTS_PASS',jobs=rows,compiler_executions=0,model_executions=0,canonical_admission=False)
