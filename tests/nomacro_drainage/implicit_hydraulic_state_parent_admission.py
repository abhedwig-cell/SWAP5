"""Actual signed canonical824 admission and original observers; zero model replay."""
import json,subprocess
from pathlib import Path
from contextlib import ExitStack
from analytical_hydraulic_archives import Archive,SHA
from frost_boundary_git_archive import GitArchiveSource
from frost_boundary_state_calendar_parent_admission import archived_commit
from frost_analytical_boundary_parent_admission import parent_admission as previous_admission
R=Path(__file__).resolve().parents[2]
BASE='22520105f5a3ccac2bd2ae1b726f27b7b0d67b1e'
PREVIOUS='9af88c3de6198ddec40c2674dd1542a89fa9c0d7'
CANDIDATE='fc2c49ce7ee866ca961e6189007287214d16189b'
SYNTHETIC='f5add718dfd76a6d780199dbc88f830a670ad21d'
ADMISSION_SHA='33ddbc31944e78b6cb3e34c24853aa3fe5a4f539550f51815936fd89c2b0819b'
git=lambda *a:subprocess.check_output(['git',*a],cwd=R)

def parent_admission():
    head=git('rev-parse','HEAD').decode().strip();data=GitArchiveSource(R,head)
    receipt=json.loads((data/'FROST_ANALYTICAL_BOUNDARY10_MERGE_RECEIPT_V1.json').read_text())
    assert receipt['actual_merge']==BASE and receipt['qualified_candidate']==CANDIDATE and receipt['canonical_admission'] and receipt['admission_archive_sha256']==ADMISSION_SHA
    parents=git('show','-s','--format=%P',BASE).decode().split();assert parents==receipt['ordered_parents']==[PREVIOUS,CANDIDATE]
    tree=git('rev-parse',BASE+'^{tree}').decode().strip();assert tree==receipt['whole_tree']==git('rev-parse',CANDIDATE+'^{tree}').decode().strip()
    with ExitStack() as stack:
        store=Archive(data,'FROST_ANALYTICAL_BOUNDARY10_ADMISSION_RAW_V1',stack);assert store.record['sha256']==ADMISSION_SHA
        for name in store.names:store.get(name)
        commits=[]
        for sha in [BASE,SYNTHETIC]:
            raw=store.get('FROST_ANALYTICAL_BOUNDARY10_PR1809_GENUINE_GIT_OBJECT_'+sha+'.bin');commits.append(archived_commit(raw,sha,tree,parents));assert raw==git('cat-file','commit',sha)
        api=json.loads(store.get('FROST_ANALYTICAL_BOUNDARY10_PR1809_ACTUAL_GIT_API_V1.json'));assert api['sha']==BASE and api['verification']['verified'] and api['verification']['reason']=='valid'
        observations={};fixtures=None
        for role,version,sha in [('CANDIDATE','V1',CANDIDATE),('ACTUAL_MERGE','V1',BASE)]:
            for kind in ['PUBLIC','PUBLICATION']:
                label='FROST_ANALYTICAL_BOUNDARY10_'+role+'_'+kind+'_'+version;q=json.loads(store.get(label+'.json'));out=store.get(label+'.stdout.txt')
                assert q['returncode']==0 and q['error'] is None and q['before']==q['after'] and not q['before']['status'] and not store.get(label+'.stderr.txt')
                before=q['before'];assert before['head']==sha and before['tree']==tree and len(before['sparse'])==14 and len(before['original_project_files'])==56
                if fixtures is None:fixtures=before['original_project_files']
                assert fixtures==before['original_project_files']
                if kind=='PUBLIC':assert json.loads(out)['coadmission']==receipt['coadmission']
                else:assert b'PUBLICATION_REPLAY_SELECTED=false' in out and q['ordinary_python_default_dont_write_bytecode'] is False and q['child_bytecode_environment_variables_absent']
                observations[label]=q['seconds']
        ci=json.loads(store.get('FROST_ANALYTICAL_BOUNDARY10_PR1809_FINAL_ALL_CI_API_V1.json'));runs=ci['runs']['workflow_runs'];checks=ci['checks']['check_runs']
        assert ci['runs']['total_count']==len(runs)==len({x['workflow_id'] for x in runs})==14
        assert all(x['status']=='completed' and x['conclusion']=='success' and x['head_sha']==CANDIDATE for x in runs)
        assert ci['checks']['total_count']==len(checks)==45 and all(x['head_sha']==CANDIDATE and x['status']=='completed' and x['conclusion'] in ['success','skipped'] for x in checks)
        assert sum(x['conclusion']=='success' for x in checks)==28 and sum(x['conclusion']=='skipped' for x in checks)==17
        for role in ['CO2','DVS','LRV','FCI_MODULAR','TIMEINT_STARTUP','TIMEINT_INVERSE']:
            label='FROST_ANALYTICAL_BOUNDARY10_PR1809_'+role+'_ORIGINAL_CI_V1.log';raw=store.get(label);q=json.loads(store.get(label+'.json'))
            assert len(raw)==q['bytes'] and SHA(raw)==q['sha256'] and q['actual_source']==CANDIDATE and CANDIDATE.encode() in raw and SYNTHETIC.encode() in raw
        negative=json.loads(store.get('FROST_ANALYTICAL_BOUNDARY10_FINAL1_NEGATIVES_V1.json'));assert negative['candidate']==CANDIDATE and negative['status']=='FOUR_ACTUAL_COMMITTED_PUSHED_CLEAN14_PUBLIC_NEGATIVES_REFUSED'
        assert len(negative['controls'])==4 and {x['role'] for x in negative['controls']}=={'SOURCE','RAW','INHERITED','PUBLICATION'}
        for item in negative['controls']:
            assert item['actual_refusal'] and item['actual_one_file_delta'] and git('show','-s','--format=%P',item['head']).decode().split()==[CANDIDATE]
            assert git('diff','--name-only',CANDIDATE,item['head']).decode().splitlines()==[item['path']]
        selection=json.loads(store.get('FROST_ANALYTICAL_BOUNDARY10_MCSOL_UNCHANGED_DEPENDENCY_SELECTION_V1.json'))
        assert selection['actual_candidate']==CANDIDATE and selection['actual_parent']==PREVIOUS and selection['unchanged_tracked_files']==1063 and not git('diff',PREVIOUS,BASE,'--',*selection['unchanged_dependency_paths'])
        canonical=json.loads(store.get('FROST_ANALYTICAL_BOUNDARY10_ACTUAL_MERGE_ALL_CI_API_V1.json'))
        assert canonical['total_count']==len(canonical['workflow_runs'])==4
        for run in canonical['workflow_runs']:
            assert run['head_sha']==BASE and run['status']=='completed' and run['conclusion']=='success'
            jobs=json.loads(store.get('FROST_ANALYTICAL_BOUNDARY10_ACTUAL_MERGE_CI_JOBS_'+str(run['id'])+'_V1.json'))['jobs']
            assert jobs and all(j['status']=='completed' and j['conclusion'] in ['success','skipped'] for j in jobs)
        assert receipt['new_scientific_contexts']==64 and not receipt['scientific_producers_rebound'] and receipt['coadmission']['contexts']==824
    prior=previous_admission();assert prior['receipt']['actual_merge']==PREVIOUS and git('rev-parse','HEAD').decode().strip()==head
    return dict(status='GENUINE_CANONICAL824_ANALYTICAL_FROST_SIGNED_MERGE_ACTUAL_PUBLIC_PUB_14CI45CHECKS_SIX_LOGS_REAL_NEGATIVES_AND_PRIOR_CHAIN_PASS',actual_parent=BASE,receipt=receipt,observations=observations,original_archived_signed_commit_custody=commits,prior_760_admission=prior,compiler_executions=0,model_executions=0)
