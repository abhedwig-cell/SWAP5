"""Original scientific push APIs/logs and four unchanged official ZIP identities."""
from contextlib import ExitStack
import json
from analytical_hydraulic_archives import Archive,SHA
PRODUCER='e8da5a5e30d28c74a41d57ddbfe3c44390a2a8af'
RUNS={'UBUNTU':(46075802361,433205693),'WINDOWS':(46075802339,433205692)}


def audit(data):
    with ExitStack() as stack:
        store=Archive(data,'CLOSED_JOINT_HISTORY_STATE16_ORIGINAL_PORTABLE_CI_RAW_V3',stack)
        assert store.record['sha256']=='d276b20543a83711f59ca9b8336e5a8927af3292d2164fab95e44880d72098c8'
        record=json.loads(store.get('CLOSED_JOINT_HISTORY_STATE16_ORIGINAL_PORTABLE_CI_CUSTODY_V1.json'))
        assert record['actual_scientific_producer']==PRODUCER and record['original_bytes_normalized'] is False and len(record['runs'])==2 and len(record['jobs'])==len(record['artifacts'])==4
        rows=[]
        for platform,(run_id,workflow_id) in RUNS.items():
            prefix='CLOSED_JOINT_HISTORY_STATE16_FIRST_'+platform
            run=json.loads(store.get(prefix+'_RUN_ORIGINAL_API_V1.json'));jobs=json.loads(store.get(prefix+'_JOBS_ORIGINAL_API_V1.json'));artifacts=json.loads(store.get(prefix+'_ARTIFACTS_ORIGINAL_API_V1.json'))
            assert run['id']==run_id and run['head_sha']==PRODUCER and run['workflow_id']==workflow_id and run['event']=='push' and run['status']=='completed' and run['conclusion']=='success'
            assert jobs['total_count']==len(jobs['jobs'])==artifacts['total_count']==len(artifacts['artifacts'])==2
            for opt in ['O0','O2']:
                job=next(v for v in jobs['jobs'] if v['name']=='qualify ('+opt+')');api=json.loads(store.get(prefix+'_'+opt+'_JOB_ORIGINAL_API_V1.json'))
                assert api['id']==job['id'] and api['run_id']==job['run_id']==run_id and api['head_sha']==job['head_sha']==PRODUCER and api['status']==job['status']=='completed' and api['conclusion']==job['conclusion']=='success'
                name=prefix+'_'+opt+'_ORIGINAL_CI_V1.log';raw=store.get(name);raw.decode('utf8',errors='strict');assert PRODUCER.encode() in raw and b'ACTUAL_INITIAL1_AND2_CLOSED_CALENDAR_COMPLETE_SOURCE_INVERSE_PASS' in raw
                original=next(v for v in record['jobs'] if v['job_id']==job['id']);assert original['log']==name and original['bytes']==len(raw) and original['sha256']==SHA(raw) and original['conclusion']=='success'
                descriptor=json.loads((data/(prefix+'_'+opt+'_ORIGINAL_V1.json')).read_text())
                artifact=next(v for v in artifacts['artifacts'] if v['id']==descriptor['artifact_id']);assert not artifact['expired']
                assert descriptor['run_id']==run_id and descriptor['job_id']==job['id'] and descriptor['actual_producer']==PRODUCER and descriptor['bytes']==artifact['size_in_bytes'] and artifact['digest']==descriptor['official_artifact_digest']=='sha256:'+descriptor['sha256']
                rows.append(dict(platform=platform,optimization=opt,actual_original_source=PRODUCER,run_id=run_id,job_id=job['id'],artifact_id=artifact['id'],actual_original_log_sha256=SHA(raw),actual_original_artifact_sha256=descriptor['sha256']))
        return dict(status='TWO_ORIGINAL_PORTABLE_SCIENTIFIC_PUSH_RUNS_FOUR_ACTUAL_SUCCESSFUL_LOGS_APIS_AND_UNCHANGED_OFFICIAL_ARTIFACT_DIGESTS_PASS',contexts=rows,original_source_roles_rebound=False,compiler_executions=0,model_executions=0)
