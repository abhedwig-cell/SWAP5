"""Read genuine canonical948 admission and its exact archived control objects."""
from contextlib import ExitStack
import hashlib,json,re
from closed_implicit_state_feedback import R,P,SHA,git
from analytical_hydraulic_archives import Archive
from frost_boundary_git_archive import GitArchiveSource
from frost_boundary_state_calendar_parent_admission import archived_commit
BASE='2e98506b4fb469bbf5995a8ab0b49c88ead0972c'
PREVIOUS='105b9a8e6ca9e846f214d69a71afe73ed18be11d'
CANDIDATE='07cb2850e2cd45deb1e197161409a3784a8975e7'
SYNTHETIC='8fe30349bfb9717e9610008d1eebe5a957a8f476'
TREE='8df17cc12686e8ab5522360b87f6430a345aabdb'
ADMISSION_SHA='d4ec3ee6947288d7a0d21d9d9b393c1178d2e7fca50d9651cc5eb9d78c9e9564'
NEGATIVE_OBJECTS_SHA='dee474b11fab224f8e8620ec2fe5f0877db00e91c331d1674c460e13c39b53c0'


def negative_objects(store,negative,custody):
    assert store.record['sha256']==NEGATIVE_OBJECTS_SHA
    rows=json.loads(store.get('NEGATIVE_OBJECT_RECORDS.json'));assert len(rows)==4
    def get(kind,digest):
        raw=store.get('objects/'+kind+'/'+digest+'.bin')
        assert hashlib.sha1(kind.encode()+b' '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==digest
        return raw
    def headers(raw):
        lines=raw.split(b'\n\n',1)[0].splitlines()
        return dict(tree=next(v[5:].decode() for v in lines if v.startswith(b'tree ')),parents=[v[7:].decode() for v in lines if v.startswith(b'parent ')])
    def entries(digest):
        raw=get('tree',digest);position=0;result={}
        while position<len(raw):
            space=raw.index(b' ',position);zero=raw.index(b'\0',space);name=raw[space+1:zero].decode();mode=raw[position:space].decode();child=raw[zero+1:zero+21].hex()
            assert len(raw[zero+1:zero+21])==20 and name not in result;result[name]=(mode,child);position=zero+21
        assert position==len(raw);return result
    def changes(left,right,prefix=''):
        if left==right:return []
        a,b=entries(left),entries(right);assert a.keys()==b.keys();result=[]
        for name,(mode,x) in a.items():
            other,y=b[name];assert mode==other
            if x!=y:
                if mode=='40000':result.extend(changes(x,y,prefix+name+'/'))
                else:assert mode=='100644';result.append(dict(path=prefix+name,original_blob=x,mutant_blob=y))
        return result
    assert headers(get('commit',CANDIDATE))['tree']==TREE
    assert {v['role'] for v in rows}=={'SOURCE','RAW','INHERITED','PUBLICATION'}
    records=[]
    for row in rows:
        header=headers(get('commit',row['head']));assert header['parents']==[CANDIDATE] and header['tree']==row['tree']
        actual=changes(TREE,header['tree']);assert actual==[row['delta']]
        source=next(v for v in negative['controls'] if v['role']==row['role']);proof=next(v for v in custody['controls'] if v['role']==row['role'])
        assert source['head']==proof['actual_head']==row['head'] and source['exact_parent']==proof['exact_parent']==CANDIDATE
        assert actual[0]['path']==source['path']==proof['path'] and source['actual_refusal'] and source['actual_one_file_delta']
        assert source['actual_public_returncode']!=0 and proof==row['original_actual_Git_byte_custody']
        records.append(dict(role=row['role'],actual_original_negative_head=row['head'],actual_one_file_tree_delta=actual[0],actual_original_refusal=True))
    return records


def parent_admission():
    observer=git('rev-parse','HEAD').decode().strip();data=GitArchiveSource(R,observer)
    receipt=json.loads((data/'CLOSED_GARDNER_STATE12_MERGE_RECEIPT_V1.json').read_text())
    assert receipt['actual_merge']==BASE and receipt['previous_canonical']==PREVIOUS and receipt['qualified_candidate']==CANDIDATE
    assert receipt['ordered_parents']==[PREVIOUS,CANDIDATE] and receipt['synthetic_merge']==SYNTHETIC and receipt['whole_tree']==TREE and receipt['admission_archive_sha256']==ADMISSION_SHA
    assert receipt['canonical_admission'] and receipt['coadmission']['contexts']==948 and receipt['new_scientific_contexts']==68
    assert receipt['actual_primary_portable_producer']=='e112e8f7f6f0bd00e4ae9035d00ef53860477448' and receipt['actual_additional_local_producer']=='d143437f4d9d855f03c036a9db1b8a3f86ec63ef'
    assert receipt['additional_12_local_contexts_counted_again'] is False and receipt['whole_object_contexts']==40 and receipt['whole_objects']==1046
    assert receipt['two_deferred_Gardner_Snow9_numerical_cases_remain_functional_gaps'] is True
    assert receipt['producer_roles_rebound'] is False and receipt['new_numerical_policy'] is False and receipt['physical_equations_changed'] is False and receipt['new_physical_state'] is False
    assert git('rev-parse',BASE+'^{tree}').decode().strip()==TREE
    with ExitStack() as stack:
        store=Archive(data,'CLOSED_GARDNER_STATE12_ADMISSION_RAW_V1',stack);assert store.record['sha256']==ADMISSION_SHA and len(store.names)==331
        assert store.z.testzip() is None
        for member in store.names:store.get(member)
        signed=[]
        for sha in [BASE,SYNTHETIC]:
            raw=store.get('CLOSED_GARDNER_STATE12_PR1811_GENUINE_GIT_OBJECT_'+sha+'.bin');signed.append(archived_commit(raw,sha,TREE,[PREVIOUS,CANDIDATE]))
            if sha==BASE:assert raw==git('cat-file','commit',BASE)
        api=json.loads(store.get('CLOSED_GARDNER_STATE12_PR1811_ACTUAL_GIT_API_V1.json'));assert api['sha']==BASE and api['verification']['verified'] and api['verification']['reason']=='valid'
        fixtures=None;observations={}
        for label,sha,kind in [('CANDIDATE_PUBLIC_V1',CANDIDATE,'PUBLIC'),('CANDIDATE_PUBLICATION_ORDINARY_V2',CANDIDATE,'PUBLICATION'),('ACTUAL_MERGE_PUBLIC_V1',BASE,'PUBLIC'),('ACTUAL_MERGE_PUBLICATION_V1',BASE,'PUBLICATION')]:
            stem='CLOSED_GARDNER_STATE12_'+label;q=json.loads(store.get(stem+'.json'));out=store.get(stem+'.stdout.txt')
            assert q['returncode']==0 and q.get('error') is None and q['before']==q['after'] and not q['before']['status'] and not store.get(stem+'.stderr.txt')
            before=q['before'];assert before['head']==sha and before['tree']==TREE and len(before['sparse'])==14 and len(before['original_project_files'])==56
            if fixtures is None:fixtures=before['original_project_files']
            assert before['original_project_files']==fixtures
            if kind=='PUBLIC':assert json.loads(out)['coadmission']==receipt['coadmission']
            else:assert b'PUBLICATION_REPLAY_SELECTED=false' in out and q['ordinary_python_default_dont_write_bytecode'] is False and q['child_bytecode_environment_variables_absent'] is True
            observations[label]=q['seconds']
        ci=json.loads(store.get('CLOSED_GARDNER_STATE12_PR1811_ALL_CI_API_V1.json'));runs=ci['workflow_runs'];check_api=json.loads(store.get('CLOSED_GARDNER_STATE12_PR1811_ALL_CHECKS_API_V1.json'));checks=check_api['check_runs']
        assert ci['total_count']==len(runs)==len({v['workflow_id'] for v in runs})==14
        assert all(v['head_sha']==CANDIDATE and v['status']=='completed' and v['conclusion']=='success' for v in runs)
        assert check_api['total_count']==len(checks)==45 and all(v['head_sha']==CANDIDATE and v['status']=='completed' and v['conclusion'] in ('success','skipped') for v in checks)
        assert sum(v['conclusion']=='success' for v in checks)==28 and sum(v['conclusion']=='skipped' for v in checks)==17
        log_rows=[]
        for name in store.names:
            match=re.fullmatch(r'CLOSED_GARDNER_STATE12_(PR1811|ACTUAL_MERGE)_JOB_(\d+)_ORIGINAL_CI_V1.log',name)
            if not match:continue
            role,job_id=match.groups();prefix=name.removesuffix('_ORIGINAL_CI_V1.log');raw=store.get(name);raw.decode('utf8',errors='strict');job=json.loads(store.get(prefix+'_ORIGINAL_API_V1.json'));run=json.loads(store.get(prefix+'_RUN_ORIGINAL_API_V1.json'))
            expected=CANDIDATE if role=='PR1811' else BASE
            assert job['id']==int(job_id) and job['head_sha']==run['head_sha']==expected and job['run_id']==run['id'] and job['status']=='completed' and job['conclusion']=='success'
            assert run['event']==('pull_request' if role=='PR1811' else 'push')
            log_rows.append(dict(role=role,job_id=int(job_id),source=expected,bytes=len(raw),sha256=SHA(raw),signed_checkout_printed=(SYNTHETIC if role=='PR1811' else BASE).encode() in raw))
        assert len(log_rows)==33 and sum(v['role']=='PR1811' for v in log_rows)==28
        negative=json.loads(store.get('CLOSED_GARDNER_STATE12_FINAL1_NEGATIVES_V3.json'));custody=json.loads(store.get('CLOSED_GARDNER_STATE12_FINAL1_NEGATIVE_GIT_CUSTODY_V1.json'))
        assert negative['candidate']==CANDIDATE and len(negative['controls'])==4 and negative['status']=='FOUR_ACTUAL_COMMITTED_PUSHED_CLEAN14_PUBLIC_NEGATIVES_REFUSED'
        negatives=negative_objects(Archive(data,'CLOSED_IMPLICIT_STATE13_PARENT_NEGATIVE_GENUINE_GIT_OBJECTS_V1',stack),negative,custody)
        canonical=json.loads(store.get('CLOSED_GARDNER_STATE12_ACTUAL_MERGE_ALL_CI_API_V1.json'));assert canonical['total_count']==len(canonical['workflow_runs'])==4
        for run in canonical['workflow_runs']:
            assert run['head_sha']==BASE and run['status']=='completed' and run['conclusion']=='success'
            jobs=json.loads(store.get('CLOSED_GARDNER_STATE12_ACTUAL_MERGE_CI_JOBS_'+str(run['id'])+'_V1.json'))['jobs'];assert jobs and all(v['status']=='completed' and v['conclusion'] in ('success','skipped') for v in jobs)
        selection=json.loads(store.get('CLOSED_GARDNER_STATE12_MCSOL_UNCHANGED_DEPENDENCY_SELECTION_V1.json'));assert selection['actual_candidate']==CANDIDATE and selection['unchanged_tracked_files']==1063 and not git('diff',PREVIOUS,BASE,'--',*selection['unchanged_dependency_paths'])
    assert git('rev-parse','HEAD').decode().strip()==observer
    return dict(status='GENUINE_CANONICAL948_SIGNED_MERGE_CLEAN_PUBLIC_PUBLICATION_14CI45CHECKS33ORIGINAL_LOGS_AND_FOUR_REAL_CONTROL_OBJECTS_PRESERVED',actual_observer=observer,receipt=receipt,signed_commits=signed,observations=observations,original_CI_logs=log_rows,real_negative_controls=negatives,compiler_executions=0,model_executions=0,Git_refs_or_HEAD_substituted=False)
