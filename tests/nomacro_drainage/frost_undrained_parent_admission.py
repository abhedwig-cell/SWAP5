"""Actual signed checkout-only canonical648 admission and original observers."""
import json,subprocess
from pathlib import Path
from contextlib import ExitStack
from analytical_hydraulic_archives import Archive,SHA
from frost_boundary_git_archive import GitArchiveSource
from frost_boundary_state_calendar_parent_admission import archived_commit
from ci_checkout_scope07_parent_admission import parent_admission as previous_admission
R=Path(__file__).resolve().parents[2]
BASE='0b482de01847dd8ba5f93c63881b9aeff468d3e3'
PREVIOUS='df00f9393ac552b0a6cab8ee84f8b8d8c06ac26c'
CANDIDATE='082f3d4b8e027d7aa8fcfbb9e3dde603aea85a66'
SYNTHETIC='e2ad1538dae3fc1eefdfd9a5f4507043bdc0a9f3'
ADMISSION_SHA='1b166d8ef25ca8934339d841f45ed7bc05c8405cc0e0176bd2c7b913b41857da'
git=lambda *a:subprocess.check_output(['git',*a],cwd=R)

def parent_admission():
    head=git('rev-parse','HEAD').decode().strip();data=GitArchiveSource(R,head)
    receipt=json.loads((data/'CI_CHECKOUT_SCOPE07_MERGE_RECEIPT_V1.json').read_text())
    assert receipt['actual_merge']==BASE and receipt['qualified_candidate']==CANDIDATE and receipt['canonical_admission'] and receipt['admission_archive_sha256']==ADMISSION_SHA
    parents=git('show','-s','--format=%P',BASE).decode().split();assert parents==receipt['ordered_parents']==[PREVIOUS,CANDIDATE]
    tree=git('rev-parse',BASE+'^{tree}').decode().strip();assert tree==receipt['whole_tree']==git('rev-parse',CANDIDATE+'^{tree}').decode().strip()
    with ExitStack() as stack:
        store=Archive(data,'CI_CHECKOUT_SCOPE07_ADMISSION_RAW_V1',stack);assert store.record['sha256']==ADMISSION_SHA
        for name in store.names:store.get(name)
        commits=[]
        for sha in [BASE,SYNTHETIC]:
            raw=store.get('CI_CHECKOUT_SCOPE07_PR1806_GENUINE_GIT_OBJECT_'+sha+'.bin');commits.append(archived_commit(raw,sha,tree,parents));assert raw==git('cat-file','commit',sha)
        api=json.loads(store.get('CI_CHECKOUT_SCOPE07_PR1806_ACTUAL_GIT_API_V1.json'));assert api['sha']==BASE and api['verification']['verified'] and api['verification']['reason']=='valid'
        observations={};fixtures=None
        for role,version,sha in [('CANDIDATE','V5',CANDIDATE),('ACTUAL_MERGE','V1',BASE)]:
            for kind in ['PUBLIC','PUBLICATION']:
                label='CI_CHECKOUT_SCOPE07_'+role+'_'+kind+'_'+version;q=json.loads(store.get(label+'.json'));out=store.get(label+'.stdout.txt')
                assert q['returncode']==0 and q['error'] is None and q['before']==q['after'] and not q['before']['status'] and not store.get(label+'.stderr.txt')
                before=q['before'];assert before['head']==sha and before['tree']==tree and len(before['sparse'])==14 and len(before['original_project_files'])==56
                if fixtures is None:fixtures=before['original_project_files']
                assert fixtures==before['original_project_files']
                if kind=='PUBLIC':assert json.loads(out)['coadmission']==receipt['coadmission']
                else:assert b'PUBLICATION_REPLAY_SELECTED=false' in out and q['ordinary_python_default_dont_write_bytecode'] is False and q['child_bytecode_environment_variables_absent']
                observations[label]=q['seconds']
        ci=json.loads(store.get('CI_CHECKOUT_SCOPE07_PR1806_FINAL_ALL_CI_API_V2.json'));runs=ci['runs']['workflow_runs'];checks=ci['checks']['check_runs']
        assert ci['runs']['total_count']==len(runs)==len({x['workflow_id'] for x in runs})==16
        assert all(x['status']=='completed' and x['conclusion']=='success' and x['head_sha']==CANDIDATE for x in runs)
        assert ci['checks']['total_count']==len(checks)==48 and all(x['head_sha']==CANDIDATE and x['status']=='completed' and x['conclusion'] in ['success','skipped'] for x in checks)
        assert sum(x['conclusion']=='success' for x in checks)==30 and sum(x['conclusion']=='skipped' for x in checks)==18
        for role in ['CO2','DVS','LRV','FCI_MODULAR','TIMEINT_STARTUP','TIMEINT_INVERSE']:
            label='CI_CHECKOUT_SCOPE07_PR1806_'+role+'_ORIGINAL_CI_V2.log';raw=store.get(label);q=json.loads(store.get(label+'.json'))
            assert len(raw)==q['bytes'] and SHA(raw)==q['sha256'] and q['actual_source']==CANDIDATE and CANDIDATE.encode() in raw and SYNTHETIC.encode() in raw
        negative=json.loads(store.get('CI_CHECKOUT_SCOPE07_FINAL2_NEGATIVES_V1.json'));assert negative['candidate']==CANDIDATE and negative['status']=='FOUR_ACTUAL_COMMITTED_PUSHED_CLEAN14_PUBLIC_NEGATIVES_REFUSED'
        assert len(negative['controls'])==4 and {x['role'] for x in negative['controls']}=={'SOURCE','RAW','INHERITED','PUBLICATION'}
        for item in negative['controls']:
            assert item['actual_refusal'] and item['actual_one_file_delta'] and git('show','-s','--format=%P',item['head']).decode().split()==[CANDIDATE]
            assert git('diff','--name-only',CANDIDATE,item['head']).decode().splitlines()==[item['path']]
        selection=json.loads(store.get('CI_CHECKOUT_SCOPE07_MCSOL_UNCHANGED_DEPENDENCY_SELECTION_V2.json'))
        assert selection['actual_current_head']==CANDIDATE and selection['actual_parent']==PREVIOUS and selection['unchanged_tracked_files']==1063 and not git('diff',PREVIOUS,BASE,'--',*selection['unchanged_dependency_paths'])
        hupsel=json.loads(store.get('CI_CHECKOUT_SCOPE07_PR1806_HUPSEL_IMPACT_ORIGINAL_JOBS_V1.json'));assert {(x['name'],x['conclusion']) for x in hupsel['jobs']}=={('dependency-impact','success'),('qualification','skipped')}
        raw=store.get('CI_CHECKOUT_SCOPE07_PR1806_HUPSEL_IMPACT_ORIGINAL_CI_V1.log')
        for token in [SYNTHETIC.encode(),b'"unchanged_scientific_tracked_files": 1883',b'"original_model_job_body_identical": true',b'"run_models": false']:assert token in raw
        assert receipt['new_scientific_contexts']==0 and not receipt['original_scientific_producer_rebound'] and receipt['coadmission']['contexts']==648
    prior=previous_admission();assert prior['receipt']['actual_merge']==PREVIOUS and git('rev-parse','HEAD').decode().strip()==head
    return dict(status='GENUINE_CANONICAL648_CHECKOUT_SIGNED_MERGE_ACTUAL_PUBLIC_PUB_16CI48CHECKS_SIX_LOGS_REAL_NEGATIVES_AND_PRIOR_CHAIN_PASS',actual_parent=BASE,receipt=receipt,observations=observations,original_archived_signed_commit_custody=commits,prior_648_scientific_admission=prior,compiler_executions=0,model_executions=0)
