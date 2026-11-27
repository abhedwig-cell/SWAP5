"""Read genuine canonical1004 admission, signed objects and original control bytes."""
from contextlib import ExitStack
import argparse,hashlib,io,json,re,zipfile
from pathlib import Path
from closed_default_calendar_feedback import R,P,PARENT,SHA,git
from analytical_hydraulic_archives import Archive
from frost_boundary_git_archive import GitArchiveSource
from frost_boundary_state_calendar_parent_admission import archived_commit
BASE=PARENT
PREVIOUS='2e98506b4fb469bbf5995a8ab0b49c88ead0972c'
CANDIDATE='2d810e6db3acf6eb81ff96dae90859670eae9b3a'
SYNTHETIC='c1eb28258a92b231748645a384c032c818c671d6'
TREE='202bb30e809e46770b591bb56ce94866dbdffbfb'
ADMISSION_SHA='a9d020082d1c45e220e7161492c0df1e7c49b483e6840d5c51f2d4d8797b3a11'
NEGATIVE_OBJECTS_SHA='e83038ea285360961ad803ed24cedd1fcb1bf9bd46bed4ccedd2c7129277a27b'


class OriginalControlObjects:
    """Immutable original nested ZIP; no checkout, import or identity projection."""
    def __init__(self,store,stack):
        name='CLOSED_IMPLICIT_STATE13_ACTUAL_NEGATIVE_GENUINE_GIT_OBJECTS_V1'
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
    receipt=json.loads((data/'CLOSED_IMPLICIT_STATE13_MERGE_RECEIPT_V1.json').read_text())
    assert receipt['actual_merge']==BASE and receipt['previous_canonical']==PREVIOUS and receipt['qualified_candidate']==CANDIDATE
    assert receipt['ordered_parents']==[PREVIOUS,CANDIDATE] and receipt['synthetic_merge']==SYNTHETIC and receipt['whole_tree']==TREE
    assert receipt['canonical_admission'] and receipt['admission_archive_sha256']==ADMISSION_SHA and receipt['coadmission']['contexts']==1004 and receipt['new_scientific_contexts']==56
    assert receipt['actual_primary_portable_producer']=='62cf6eefb110099ab1c181b06f2a5ae74b48f144' and receipt['actual_additional_local_producer']=='ae8ddfbb9e029190baa0d4f42f9002cc3bce8b30'
    assert receipt['additional_four_local_contexts_counted_again'] is False
    assert (receipt['whole_object_contexts'],receipt['whole_objects'],receipt['unchanged_whole_objects'],receipt['changed_static_native_guard_objects'])==(40,1046,1022,24)
    assert receipt['original_native_positive_controls']==24 and receipt['original_native_compiled_refusals']==480
    assert receipt['two_inherited_explicit_Gardner_Snow9_numerical_cases_remain_functional_gaps'] and receipt['current_finite_batch_deferred_numerical_cases']==0
    assert receipt['new_numerical_policy'] is True and receipt['numerical_policy']=='original-closed-implicit-residual-start-and-conditional-convergence-v3'
    assert all(receipt[key] is False for key in ['producer_roles_rebound','physical_equations_changed','new_physical_state','RC3_changed'])
    assert git('rev-parse',BASE+'^{tree}').decode().strip()==TREE
    with ExitStack() as stack:
        store=Archive(data,'CLOSED_IMPLICIT_STATE13_ADMISSION_RAW_V2',stack)
        assert store.record['sha256']==ADMISSION_SHA and len(store.names)==524 and store.z.testzip() is None
        for name in store.names:store.get(name)
        signed=[]
        for sha in [BASE,SYNTHETIC]:
            raw=store.get('CLOSED_IMPLICIT_STATE13_PR1812_GENUINE_GIT_OBJECT_'+sha+'.bin')
            signed.append(archived_commit(raw,sha,TREE,[PREVIOUS,CANDIDATE]))
            if sha==BASE:assert raw==git('cat-file','commit',BASE)
        api=json.loads(store.get('CLOSED_IMPLICIT_STATE13_PR1812_POSTMERGE_ACTUAL_GIT_ORIGINAL_API_V1.json'))
        assert api['sha']==BASE and api['verification']['verified'] and api['verification']['reason']=='valid'
        fixtures=None;observations={}
        for label,sha,kind in [('CANDIDATE_PUBLIC_V2',CANDIDATE,'PUBLIC'),('CANDIDATE_PUBLICATION_V2',CANDIDATE,'PUBLICATION'),('ACTUAL_MERGE_PUBLIC_V1',BASE,'PUBLIC'),('ACTUAL_MERGE_PUBLICATION_V1',BASE,'PUBLICATION')]:
            stem='CLOSED_IMPLICIT_STATE13_'+label;q=json.loads(store.get(stem+'.json'));out=store.get(stem+'.stdout.txt')
            assert q['returncode']==0 and q.get('error') is None and q['before']==q['after'] and not q['before']['status'] and not store.get(stem+'.stderr.txt')
            before=q['before'];assert before['head']==sha and before['tree']==TREE and len(before['sparse'])==14 and len(before['original_project_files'])==56
            if fixtures is None:fixtures=before['original_project_files']
            assert before['original_project_files']==fixtures
            if kind=='PUBLIC':assert json.loads(out)['coadmission']==receipt['coadmission']
            else:assert b'PUBLICATION_REPLAY_SELECTED=false' in out and q['ordinary_python_default_dont_write_bytecode'] is False and q['child_bytecode_environment_variables_absent'] is True
            observations[label]=q['seconds']
        ci=json.loads(store.get('CLOSED_IMPLICIT_STATE13_PR1812_POSTMERGE_ALL_CI_ORIGINAL_API_V1.json'));checks=json.loads(store.get('CLOSED_IMPLICIT_STATE13_PR1812_POSTMERGE_ALL_CHECKS_ORIGINAL_API_V1.json'))
        runs=ci['workflow_runs'];assert ci['total_count']==len(runs)==len({v['workflow_id'] for v in runs})==14
        assert all(v['head_sha']==CANDIDATE and v['status']=='completed' and v['conclusion']=='success' for v in runs)
        assert checks['total_count']==len(checks['check_runs'])==45
        assert all(v['head_sha']==CANDIDATE and v['status']=='completed' and v['conclusion'] in ('success','skipped') for v in checks['check_runs'])
        assert sum(v['conclusion']=='success' for v in checks['check_runs'])==28 and sum(v['conclusion']=='skipped' for v in checks['check_runs'])==17
        logs=[]
        for name in store.names:
            match=re.fullmatch(r'CLOSED_IMPLICIT_STATE13_(PR1812_FINAL_HEAD|ACTUAL_MERGE)_JOB_(\d+)_ORIGINAL_CI_V1.log',name)
            if not match:continue
            role,job_id=match.groups();stem=name.removesuffix('_ORIGINAL_CI_V1.log');raw=store.get(name);raw.decode('utf8',errors='strict')
            job=json.loads(store.get(stem+'_ORIGINAL_API_V1.json'));run=json.loads(store.get(stem+'_RUN_ORIGINAL_API_V1.json'));expected=BASE if role=='ACTUAL_MERGE' else CANDIDATE
            assert job['id']==int(job_id) and job['head_sha']==run['head_sha']==expected and job['run_id']==run['id'] and job['status']=='completed' and job['conclusion']=='success'
            assert run['event']==('push' if role=='ACTUAL_MERGE' else 'pull_request')
            logs.append(dict(role=role,job_id=int(job_id),source=expected,bytes=len(raw),sha256=SHA(raw)))
        assert len(logs)==33 and sum(v['role']=='PR1812_FINAL_HEAD' for v in logs)==28
        negative=json.loads(store.get('CLOSED_IMPLICIT_STATE13_FINAL1_NEGATIVES_V3.json'));custody=json.loads(store.get('CLOSED_IMPLICIT_STATE13_FINAL1_NEGATIVE_GIT_CUSTODY_V1.json'))
        assert negative['candidate']==CANDIDATE and len(negative['controls'])==4 and negative['status']=='FOUR_ACTUAL_COMMITTED_PUSHED_CLEAN14_PUBLIC_NEGATIVES_REFUSED'
        negatives=negative_objects(OriginalControlObjects(store,stack),negative,custody)
        canonical=json.loads(store.get('CLOSED_IMPLICIT_STATE13_ACTUAL_MERGE_ALL_CI_ORIGINAL_API_V1.json'));assert canonical['total_count']==len(canonical['workflow_runs'])==4
        for run in canonical['workflow_runs']:
            assert run['head_sha']==BASE and run['status']=='completed' and run['conclusion']=='success'
            jobs=json.loads(store.get('CLOSED_IMPLICIT_STATE13_ACTUAL_MERGE_JOBS_'+str(run['id'])+'_ORIGINAL_API_V1.json'))['jobs'];assert jobs and all(v['status']=='completed' and v['conclusion'] in ('success','skipped') for v in jobs)
        selection=json.loads(store.get('CLOSED_IMPLICIT_STATE13_MCSOL_UNCHANGED_DEPENDENCY_SELECTION_V1.json'))
        assert selection['actual_candidate']==CANDIDATE and selection['unchanged_tracked_files']==1063 and not git('diff',PREVIOUS,BASE,'--',*selection['unchanged_dependency_paths'])
    assert git('rev-parse','HEAD').decode().strip()==observer
    return dict(status='GENUINE_CANONICAL1004_SIGNED_MERGE_CLEAN_PUBLIC_PUBLICATION_14CI45CHECKS33ORIGINAL_LOGS_AND_FOUR_REAL_CONTROL_OBJECTS_PRESERVED',actual_observer=observer,receipt=receipt,signed_commits=signed,observations=observations,original_CI_logs=logs,real_negative_controls=negatives,compiler_executions=0,model_executions=0,Git_refs_or_HEAD_substituted=False)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=parent_admission()
    with a.output.open('x',encoding='utf8') as out:json.dump(q,out,indent=2);out.write('\n')
    print(q['status'],flush=True)
