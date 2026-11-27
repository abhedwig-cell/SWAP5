"""Original portable job/run/log and official artifact digest identities."""
from contextlib import ExitStack
import json
from analytical_hydraulic_archives import Archive,SHA
from closed_default_calendar_portable_science import PRODUCER,RUNS
SPECS={'Ubuntu':{'O0':(140658811865,15220524197),'O2':(140658812222,15222030264)},
       'Windows':{'O0':(140658812547,15220429480),'O2':(140658812995,15220374450)}}


def audit(data):
    with ExitStack() as stack:
        store=Archive(data,'CLOSED_DEFAULT_CALENDAR_STATE14_ORIGINAL_CI_AND_OBSERVER_CUSTODY_RAW_V3',stack)
        assert store.record['sha256']=='4dbec70b0020a5d4d83fef00c8cb7d4fe1f0bba343219aba92ab5485ae83322a'
        custody=json.loads(store.get('CLOSED_DEFAULT_CALENDAR_STATE14_FIRST_PORTABLE_ORIGINAL_LOG_CUSTODY_V1.json'))
        assert custody['actual_candidate']==custody['actual_checkout_source']==PRODUCER and len(custody['jobs'])==4
        rows=[]
        for platform,opts in SPECS.items():
            api=json.loads(store.get('official-artifact-api/'+platform.upper()+'_ORIGINAL_ARTIFACT_API_V1.json'))
            assert api['total_count']==len(api['artifacts'])==2
            for opt,(job_id,artifact_id) in opts.items():
                stem='CLOSED_DEFAULT_CALENDAR_STATE14_FIRST_PORTABLE_JOB_'+str(job_id)
                log=store.get(stem+'_ORIGINAL_CI_V1.log');jobraw=store.get(stem+'_ORIGINAL_API_V1.json');runraw=store.get(stem+'_RUN_ORIGINAL_API_V1.json')
                job=json.loads(jobraw);run=json.loads(runraw);log.decode('utf8',errors='strict')
                assert job['id']==job_id and job['run_id']==run['id']==RUNS[platform] and job['head_sha']==run['head_sha']==PRODUCER
                assert run['event']=='push' and job['status']==run['status']=='completed' and job['conclusion']==run['conclusion']=='success'
                assert job['name']=='qualify ('+opt+')' and PRODUCER.encode() in log
                assert b'ALL_SELECTED_CLOSED_DEFAULT_CALENDAR_LOCAL_CONTEXTS_AND_NATIVE_CONTROLS_PASS_NOT_QUALIFIED' in log
                assert log.count(b'INDEPENDENT_ACTUAL_DEFAULT_CALENDAR_INPUT_SOURCE_BUDGET_PRIVATE_NATIVE_COLD_TRANSACTION_PASS')>=5
                record=next(v for v in custody['jobs'] if v['job_id']==job_id)
                assert record['sha256']==SHA(log) and record['bytes']==len(log) and record['original_job_api_sha256']==SHA(jobraw) and record['original_run_api_sha256']==SHA(runraw)
                descriptor=json.loads((data/('CLOSED_DEFAULT_CALENDAR_STATE14_FIRST_'+platform.upper()+'_'+opt+'_ORIGINAL_V1.json')).read_text())
                artifact=next(v for v in api['artifacts'] if v['id']==artifact_id)
                assert artifact['workflow_run']['id']==RUNS[platform] and artifact['workflow_run']['head_sha']==PRODUCER
                assert artifact['size_in_bytes']==descriptor['bytes'] and artifact['digest']=='sha256:'+descriptor['sha256'] and descriptor['actual_artifact_id']==artifact_id
                rows.append(dict(platform=platform,optimization=opt,job_id=job_id,artifact_id=artifact_id,run_id=RUNS[platform],actual_producer=PRODUCER,original_log_sha256=SHA(log),official_artifact_sha256=descriptor['sha256'],official_artifact_bytes=descriptor['bytes']))
        failed=json.loads(store.get('CLOSED_DEFAULT_CALENDAR_STATE14_FIRST_PREFLIGHT_ORIGINAL_LOG_CUSTODY_V1.json'));assert len(failed['jobs'])==4
        for record in failed['jobs']:
            assert record['conclusion']=='failure' and record['actual_source']=='86b03fbce60d6565302d4405235866fce056f96b'
            stem='CLOSED_DEFAULT_CALENDAR_STATE14_FIRST_PREFLIGHT_JOB_'+str(record['job_id']);job=json.loads(store.get(stem+'_ORIGINAL_API_V1.json'));log=store.get(stem+'_ORIGINAL_CI_V1.log')
            assert SHA(log)==record['sha256'] and job['conclusion']=='failure'
            selected=[v for v in job['steps'] if v['name'].startswith('Run five actual original')];assert len(selected)==1 and selected[0]['conclusion']=='skipped'
        return dict(status='FOUR_ACTUAL_PORTABLE_ORIGINAL_CI_IDENTITIES_AND_OFFICIAL_ZIP_DIGESTS_PASS_FOUR_ORIGINAL_PREMODEL_FAILURE_ROLES_PRESERVED',jobs=rows,original_preflight_failures=4,compiler_executions=0,model_executions=0,canonical_admission=False)
