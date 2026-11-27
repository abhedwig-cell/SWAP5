"""Read genuine canonical1044 admission, signed objects and original control bytes."""
from contextlib import ExitStack
import argparse,hashlib,io,json,re,zipfile
from pathlib import Path
from closed_joint_history_calendar_feedback import R,P,PARENT,SHA,git
from analytical_hydraulic_archives import Archive
from frost_boundary_git_archive import GitArchiveSource
from frost_boundary_state_calendar_parent_admission import archived_commit
BASE=PARENT
PREVIOUS='fa77380ecce3317775bd1129b5de007fcbcf2e1f'
CANDIDATE='f173aede21db35c46198f5a091cf61394b0f2645'
SYNTHETIC='4a3db4731e1d49bda18e3eb0a40c0398df3f3d03'
TREE='efbcf990a4bb2fc2e9ed98835738a92bd7a914c7'
ADMISSION_SHA='74c3fb988e5cc41872c5ff95b118249af077b8b72ef612a1de3cae4f2312ce9e'
NEGATIVE_OBJECTS_SHA='5dc7fc61e3efe7ba6d308c85fa75b598db06a6f115ac4e18c262a4f7ef75e40a'


class OriginalControlObjects:
    """Immutable original nested ZIP; no checkout, import or identity projection."""
    def __init__(self,store,stack):
        name='CLOSED_INITIALIZATION_STATE15_ACTUAL_NEGATIVE_GENUINE_GIT_OBJECTS_V1'
        self.record=json.loads(store.get(name+'.json'));raw=store.get(name+'.zip')
        assert len(raw)==self.record['bytes'] and SHA(raw)==self.record['sha256']==NEGATIVE_OBJECTS_SHA
        self.z=stack.enter_context(zipfile.ZipFile(io.BytesIO(raw)))
        assert len(self.z.namelist())==len(set(self.z.namelist()))==len(self.record['members'])==28
        assert sum(name.startswith('objects/') for name in self.z.namelist())==27
        assert set(self.z.namelist())==set(self.record['members']) and self.z.testzip() is None
        for name in self.record['members']:self.get(name)
    def get(self,name):
        raw=self.z.read(name);v=self.record['members'][name];assert len(raw)==v['bytes'] and SHA(raw)==v['sha256'];return raw


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
    receipt=json.loads((data/'CLOSED_INITIALIZATION_STATE15_MERGE_RECEIPT_V1.json').read_text())
    assert receipt['actual_merge']==BASE and receipt['previous_canonical']==PREVIOUS and receipt['qualified_candidate']==CANDIDATE
    assert receipt['ordered_parents']==[PREVIOUS,CANDIDATE] and receipt['synthetic_merge']==SYNTHETIC and receipt['whole_tree']==TREE
    assert receipt['canonical_admission'] and receipt['admission_archive_sha256']==ADMISSION_SHA and receipt['coadmission']['contexts']==1044 and receipt['new_scientific_contexts']==20
    assert receipt['actual_primary_portable_producer']=='69a8b46d802cad4c95036700b3e4888254af847f' and receipt['actual_local_producers']==['c23ae582a249b4167dad0d59823e33d87e108475']
    assert receipt['additional_ten_local_contexts_counted_again'] is False
    assert (receipt['whole_object_contexts'],receipt['unchanged_whole_objects'])==(10,210)
    assert receipt['original_native_positive_controls']==10 and receipt['original_native_compiled_refusals']==40
    assert receipt['two_inherited_explicit_Gardner_Snow9_numerical_cases_remain_functional_gaps'] and receipt['current_finite_batch_deferred_numerical_cases']==0
    assert receipt['new_numerical_policy'] is False
    assert all(receipt[key] is False for key in ['producer_roles_rebound','physical_equations_changed','new_physical_state','RC3_changed'])
    assert git('rev-parse',BASE+'^{tree}').decode().strip()==TREE
    with ExitStack() as stack:
        store=Archive(data,'CLOSED_INITIALIZATION_STATE15_ADMISSION_RAW_V1',stack)
        assert store.record['sha256']==ADMISSION_SHA and len(store.names)==373 and store.z.testzip() is None
        for name in store.names:store.get(name)
        signed=[]
        for sha in [BASE,SYNTHETIC]:
            raw=store.get('CLOSED_INITIALIZATION_STATE15_PR1814_GENUINE_GIT_OBJECT_'+sha+'.bin')
            signed.append(archived_commit(raw,sha,TREE,[PREVIOUS,CANDIDATE]))
            if sha==BASE:assert raw==git('cat-file','commit',BASE)
        api=json.loads(store.get('CLOSED_INITIALIZATION_STATE15_PR1814_FINAL1_POSTMERGE_ACTUAL_GIT_ORIGINAL_API_V1.json'))
        assert api['sha']==BASE and api['verification']['verified'] and api['verification']['reason']=='valid'
        fixtures=None;observations={}
        for label,sha,kind in [('CANDIDATE2_PUBLIC_V1',CANDIDATE,'PUBLIC'),('CANDIDATE2_PUBLICATION_V1',CANDIDATE,'PUBLICATION'),('ACTUAL_MERGE1_PUBLIC_V1',BASE,'PUBLIC'),('ACTUAL_MERGE1_PUBLICATION_V1',BASE,'PUBLICATION')]:
            stem='CLOSED_INITIALIZATION_STATE15_'+label;q=json.loads(store.get(stem+'.json'));out=store.get(stem+'.stdout.txt')
            assert q['returncode']==0 and q.get('error') is None and q['before']==q['after'] and not q['before']['status'] and not store.get(stem+'.stderr.txt')
            before=q['before'];assert before['head']==sha and before['tree']==TREE and len(before['sparse'])==3 and len(before['original_project_files'])==56
            if fixtures is None:fixtures=before['original_project_files']
            assert before['original_project_files']==fixtures
            if kind=='PUBLIC':assert json.loads(out)['coadmission']==receipt['coadmission']
            else:assert b'PUBLICATION_REPLAY_SELECTED=false' in out and q['ordinary_python_default_dont_write_bytecode'] is False and q['child_bytecode_environment_variables_absent'] is True
            observations[label]=q['seconds']
        ci=json.loads(store.get('CLOSED_INITIALIZATION_STATE15_PR1814_FINAL1_POSTMERGE_ALL_CI_ORIGINAL_API_V1.json'));checks=json.loads(store.get('CLOSED_INITIALIZATION_STATE15_PR1814_FINAL1_POSTMERGE_ALL_CHECKS_ORIGINAL_API_V1.json'))
        runs=ci['workflow_runs'];assert ci['total_count']==len(runs)==len({v['workflow_id'] for v in runs})==14
        assert all(v['head_sha']==CANDIDATE and v['status']=='completed' and v['conclusion']=='success' for v in runs)
        assert checks['total_count']==len(checks['check_runs'])==45
        assert all(v['head_sha']==CANDIDATE and v['status']=='completed' and v['conclusion'] in ('success','skipped') for v in checks['check_runs'])
        assert sum(v['conclusion']=='success' for v in checks['check_runs'])==28 and sum(v['conclusion']=='skipped' for v in checks['check_runs'])==17
        logs=[]
        for name in store.names:
            match=re.fullmatch(r'CLOSED_INITIALIZATION_STATE15_(PR1814_FINAL_HEAD|ACTUAL_MERGE)_JOB_(\d+)_ORIGINAL_CI_V1.log',name)
            if not match:continue
            role,job_id=match.groups();stem=name.removesuffix('_ORIGINAL_CI_V1.log');raw=store.get(name);raw.decode('utf8',errors='strict')
            job=json.loads(store.get(stem+'_ORIGINAL_API_V1.json'));run=json.loads(store.get(stem+'_RUN_ORIGINAL_API_V1.json'));expected=BASE if role=='ACTUAL_MERGE' else CANDIDATE
            assert job['id']==int(job_id) and job['head_sha']==run['head_sha']==expected and job['run_id']==run['id'] and job['status']=='completed' and job['conclusion']=='success'
            assert run['event']==('push' if role=='ACTUAL_MERGE' else 'pull_request')
            logs.append(dict(role=role,job_id=int(job_id),source=expected,bytes=len(raw),sha256=SHA(raw)))
        assert len(logs)==33 and sum(v['role']=='PR1814_FINAL_HEAD' for v in logs)==28
        negative=json.loads(store.get('CLOSED_INITIALIZATION_STATE15_FINAL1_NEGATIVES_V1.json'));custody=json.loads(store.get('CLOSED_INITIALIZATION_STATE15_FINAL1_NEGATIVE_GIT_CUSTODY_V1.json'))
        assert negative['candidate']==CANDIDATE and len(negative['controls'])==4 and negative['status']=='FOUR_ACTUAL_COMMITTED_PUSHED_CLEAN3_PUBLIC_NEGATIVES_REFUSED'
        negatives=negative_objects(OriginalControlObjects(store,stack),negative,custody)
        canonical=json.loads(store.get('CLOSED_INITIALIZATION_STATE15_ACTUAL_MERGE_ALL_CI_ORIGINAL_API_V1.json'));assert canonical['total_count']==len(canonical['workflow_runs'])==4
        for run in canonical['workflow_runs']:
            assert run['head_sha']==BASE and run['status']=='completed' and run['conclusion']=='success'
            jobs=json.loads(store.get('CLOSED_INITIALIZATION_STATE15_ACTUAL_MERGE_JOBS_'+str(run['id'])+'_ORIGINAL_API_V1.json'))['jobs'];assert jobs and all(v['status']=='completed' and v['conclusion'] in ('success','skipped') for v in jobs)
        selection=json.loads(store.get('CLOSED_INITIALIZATION_STATE15_MCSOL_UNCHANGED_SELECTION_V1.json'))
        assert selection['actual_accepted_parent']==PREVIOUS and selection['unchanged_tracked_files']==1063 and not git('diff',PREVIOUS,BASE,'--',*selection['unchanged_dependency_paths'])
    assert git('rev-parse','HEAD').decode().strip()==observer
    return dict(status='GENUINE_CANONICAL1044_SIGNED_MERGE_CLEAN_PUBLIC_PUBLICATION_14CI45CHECKS33ORIGINAL_LOGS_AND_FOUR_REAL_CONTROL_OBJECTS_PRESERVED',actual_observer=observer,receipt=receipt,signed_commits=signed,observations=observations,original_CI_logs=logs,real_negative_controls=negatives,compiler_executions=0,model_executions=0,Git_refs_or_HEAD_substituted=False)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=parent_admission()
    with a.output.open('x',encoding='utf8') as out:json.dump(q,out,indent=2);out.write('\n')
    print(q['status'],flush=True)
