"""Read genuine canonical880 admission without projecting current source or HEAD."""
from contextlib import ExitStack
import json
from closed_gardner_state_feedback import R,SHA,git
from analytical_hydraulic_archives import Archive
from frost_boundary_git_archive import GitArchiveSource
from frost_boundary_state_calendar_parent_admission import archived_commit
BASE='105b9a8e6ca9e846f214d69a71afe73ed18be11d'
PARENT='22520105f5a3ccac2bd2ae1b726f27b7b0d67b1e'
CANDIDATE='e4d9a56143d85550ee272fbac55f1d4a08173195'
SYNTHETIC='51a85657597eb5937667c4f084a6ad98351fee28'
TREE='a5e95a0420e7ae330926c41e256392fc8c52cadc'
ADMISSION_SHA='4517de7ded03c9a6b1433a03d8656b7a61f97a6bbc2b627016ce7314d3ca6077'


def parent_admission():
    head=git('rev-parse','HEAD').decode().strip();data=GitArchiveSource(R,head)
    receipt=json.loads((data/'IMPLICIT_HYDRAULIC_STATE11_MERGE_RECEIPT_V1.json').read_text())
    assert receipt['actual_merge']==BASE and receipt['qualified_candidate']==CANDIDATE and receipt['canonical_admission']
    assert receipt['ordered_parents']==[PARENT,CANDIDATE] and receipt['whole_tree']==TREE and receipt['admission_archive_sha256']==ADMISSION_SHA
    assert receipt['coadmission']['contexts']==880 and receipt['new_scientific_contexts']==56
    assert receipt['actual_primary_portable_producer']=='c40ca084d8e5eb638e0b4ac5c471463d9aad01c3'
    assert receipt['original_ubuntu_producer_workflow_conclusion']=='failure' and not receipt['producer_roles_rebound']
    assert receipt['actual_ubuntu_observer_only_source']=='ede801b4a67be2777742d3918090c3b67740fb25'
    assert receipt['selected_model5_exact_chain_rule_Jacobian_is_new_numerical_policy'] is True
    assert not receipt['physical_equations_changed'] and not receipt['new_physical_state'] and not receipt['additional_28_local_contexts_counted_again']
    assert git('show','-s','--format=%P',BASE).decode().split()==[PARENT,CANDIDATE]
    assert git('rev-parse',BASE+'^{tree}').decode().strip()==git('rev-parse',CANDIDATE+'^{tree}').decode().strip()==TREE
    with ExitStack() as stack:
        store=Archive(data,'IMPLICIT_HYDRAULIC_STATE11_ADMISSION_RAW_V1',stack)
        assert store.record['sha256']==ADMISSION_SHA and len(store.names)==530 and store.z.testzip() is None
        for member in store.names:store.get(member)
        commits=[]
        for sha in [BASE,SYNTHETIC]:
            raw=store.get('IMPLICIT_HYDRAULIC_STATE11_PR1810_GENUINE_GIT_OBJECT_'+sha+'.bin')
            assert raw==git('cat-file','commit',sha);commits.append(archived_commit(raw,sha,TREE,[PARENT,CANDIDATE]))
        api=json.loads(store.get('IMPLICIT_HYDRAULIC_STATE11_PR1810_ACTUAL_GIT_API_V1.json'))
        assert api['sha']==BASE and api['verification']['verified'] and api['verification']['reason']=='valid'
        observations={};fixtures=None
        for role,sha in [('CANDIDATE',CANDIDATE),('ACTUAL_MERGE',BASE)]:
            for kind in ['PUBLIC','PUBLICATION']:
                label='IMPLICIT_HYDRAULIC_STATE11_'+role+'_'+kind+'_V3';q=json.loads(store.get(label+'.json'));out=store.get(label+'.stdout.txt')
                assert q['returncode']==0 and q['error'] is None and q['before']==q['after'] and not q['before']['status'] and not store.get(label+'.stderr.txt')
                before=q['before'];assert before['head']==sha and before['tree']==TREE and len(before['sparse'])==14 and len(before['original_project_files'])==56
                if fixtures is None:fixtures=before['original_project_files']
                assert before['original_project_files']==fixtures
                if kind=='PUBLIC':assert json.loads(out)['coadmission']==receipt['coadmission']
                else:assert b'PUBLICATION_REPLAY_SELECTED=false' in out and q['ordinary_python_default_dont_write_bytecode'] is False and q['child_bytecode_environment_variables_absent']
                observations[label]=q['seconds']
        ci=json.loads(store.get('IMPLICIT_HYDRAULIC_STATE11_PR1810_FINAL3_ALL_CI_API_V1.json'));runs=ci['runs']['workflow_runs'];checks=ci['checks']['check_runs']
        assert ci['runs']['total_count']==len(runs)==len({v['workflow_id'] for v in runs})==15
        assert all(v['head_sha']==CANDIDATE and v['status']=='completed' and v['conclusion']=='success' for v in runs)
        assert ci['checks']['total_count']==len(checks)==47
        assert all(v['head_sha']==CANDIDATE and v['status']=='completed' and v['conclusion'] in ('success','skipped') for v in checks)
        assert sum(v['conclusion']=='success' for v in checks)==30 and sum(v['conclusion']=='skipped' for v in checks)==17
        roles=['CO2','DVS','LRV','FCI_MODULAR','TIMEINT_STARTUP','TIMEINT_INVERSE','POND_SUCCESS',
               *['FCI110_'+v for v in ['AHL_APPLICATION','AHL_DEFAULT_OFF','AHL_FAILCLOSED','AHL_MATRIX','AHL_OWNERSHIP','AHL_PROVIDER','AHL_SCALE','B1_POISON','FKT22','PLANVALID','PPA']]]
        for role in roles:
            label='IMPLICIT_HYDRAULIC_STATE11_PR1810_FINAL3_'+role+'_ORIGINAL_CI_V1.log';raw=store.get(label);q=json.loads(store.get(label+'.json'))
            assert len(raw)==q['bytes'] and SHA(raw)==q['sha256'] and CANDIDATE.encode() in raw and SYNTHETIC.encode() in raw
        negative=json.loads(store.get('IMPLICIT_HYDRAULIC_STATE11_FINAL3_NEGATIVES_V3.json'))
        assert negative['candidate']==CANDIDATE and len(negative['controls'])==4 and {v['role'] for v in negative['controls']}=={'SOURCE','RAW','INHERITED','PUBLICATION'}
        for item in negative['controls']:
            assert item['actual_refusal'] and item['actual_one_file_delta']
            assert git('show','-s','--format=%P',item['head']).decode().split()==[CANDIDATE]
            assert git('diff','--name-only',CANDIDATE,item['head']).decode().splitlines()==[item['path']]
        canonical=json.loads(store.get('IMPLICIT_HYDRAULIC_STATE11_ACTUAL_MERGE_ALL_CI_API_V1.json'))
        assert canonical['total_count']==len(canonical['workflow_runs'])==4
        for run in canonical['workflow_runs']:
            assert run['head_sha']==BASE and run['status']=='completed' and run['conclusion']=='success'
            jobs=json.loads(store.get('IMPLICIT_HYDRAULIC_STATE11_ACTUAL_MERGE_CI_JOBS_'+str(run['id'])+'_V1.json'))['jobs']
            assert jobs and all(v['status']=='completed' and v['conclusion'] in ('success','skipped') for v in jobs)
        selection=json.loads(store.get('IMPLICIT_HYDRAULIC_STATE11_MCSOL_UNCHANGED_DEPENDENCY_SELECTION_V3.json'))
        assert selection['actual_candidate']==CANDIDATE and selection['unchanged_tracked_files']==1063
        assert not git('diff',PARENT,BASE,'--',*selection['unchanged_dependency_paths'])
    assert git('rev-parse','HEAD').decode().strip()==head
    return dict(status='GENUINE_CANONICAL880_SIGNED_MERGE_PUBLIC_PUBLICATION_15CI47CHECKS_18LOGS_AND_REAL_NEGATIVES_PRESERVED',actual_observer=head,
                receipt=receipt,actual_signed_commit_custody=commits,observations=observations,compiler_executions=0,model_executions=0)
