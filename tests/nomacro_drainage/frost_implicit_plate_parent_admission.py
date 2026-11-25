"""Genuine canonical568 admission, signed commits and original observations."""
import hashlib,json,subprocess
from pathlib import Path
from contextlib import ExitStack
from analytical_hydraulic_archives import Archive,SHA
from frost_boundary_git_archive import GitArchiveSource
from frost_boundary_state_calendar_parent_admission import archived_commit,parent_admission as prior_admission
R=Path(__file__).resolve().parents[2]
BASE='087fc67db3e1e58d45215522eb284e89cb6c12f1'
CANDIDATE='e66867c5de454f45fd8d4adde31f68454c61cf9c'
SYNTHETIC='18e31348e7e72fadc564c3046ce3645578bd46b1'
ADMISSION_SHA='6ea2618bb8115ba18b1222aa92d18b5f10647af330703faad6a44882ca9f7455'
git=lambda *a:subprocess.check_output(['git',*a],cwd=R)


def parent_admission():
    head=git('rev-parse','HEAD').decode().strip();data=GitArchiveSource(R,head)
    receipt=json.loads((data/'FROST_BOUNDARY_STATE_CALENDAR04_MERGE_RECEIPT_V1.json').read_text())
    assert receipt['actual_merge']==BASE and receipt['qualified_candidate']==CANDIDATE and receipt['canonical_admission']
    assert receipt['admission_archive_sha256']==ADMISSION_SHA
    parents=git('show','-s','--format=%P',BASE).decode().split();assert parents==receipt['ordered_parents']==['9936bcda75eb920d67aa74e47018baf39ab18f78',CANDIDATE]
    tree=git('rev-parse',BASE+'^{tree}').decode().strip();assert tree==receipt['whole_tree']==git('rev-parse',CANDIDATE+'^{tree}').decode().strip()
    with ExitStack() as stack:
        store=Archive(data,'FROST_BOUNDARY_STATE_CALENDAR04_ADMISSION_RAW_V1',stack);assert store.record['sha256']==ADMISSION_SHA
        for name in store.names:store.get(name)
        commits=[]
        for sha in [BASE,SYNTHETIC]:
            raw=store.get('FROST_BOUNDARY_STATE_CALENDAR04_PR1803_GENUINE_GIT_OBJECT_'+sha+'.bin');commits.append(archived_commit(raw,sha,tree,parents))
            if sha==BASE:assert raw==git('cat-file','commit',sha)
        observations={};inputs=None
        for role,version,sha in [('CANDIDATE','V2',CANDIDATE),('ACTUAL_MERGE','V1',BASE)]:
            for kind in ['PUBLIC','PUBLICATION']:
                label='FROST_BOUNDARY_STATE_CALENDAR04_'+role+'_'+kind+'_'+version
                q=json.loads(store.get(label+'.json'));out=store.get(label+'.stdout.txt')
                assert q['returncode']==0 and q['before']==q['after'] and not q['before']['status']
                assert q['before']['head']==sha and q['before']['tree']==tree and len(q['before']['sparse'])==14 and len(q['before']['original_project_files'])==56
                assert not store.get(label+'.stderr.txt')
                if inputs is None:inputs=q['before']['original_project_files']
                assert inputs==q['before']['original_project_files']
                if kind=='PUBLIC':assert json.loads(out)['coadmission']==receipt['coadmission']
                else:assert b'PUBLICATION_REPLAY_SELECTED=false' in out and q['ordinary_python_default_dont_write_bytecode'] is False and q['child_bytecode_environment_variables_absent']
                observations[label]=q['seconds']
        ci=json.loads(store.get('FROST_BOUNDARY_STATE_CALENDAR04_PR1803_FINAL_ALL_CI_API_V1.json'));runs=ci['runs']['workflow_runs'];checks=ci['checks']['check_runs']
        assert len(runs)==15 and all(x['status']=='completed' and x['conclusion']=='success' and x['head_sha']==CANDIDATE for x in runs)
        assert len(checks)==46 and sum(x['conclusion']=='success' for x in checks)==29 and sum(x['conclusion']=='skipped' for x in checks)==17
        for role in ['CO2','DVS','LRV','FCI_MODULAR','TIMEINT_STARTUP','TIMEINT_INVERSE','POND']:
            label='FROST_BOUNDARY_STATE_CALENDAR04_PR1803_'+role+'_ORIGINAL_CI_V1.log';raw=store.get(label);q=json.loads(store.get(label+'.json'))
            assert len(raw)==q['bytes'] and SHA(raw)==q['sha256'] and CANDIDATE.encode() in raw and SYNTHETIC.encode() in raw
        negatives=json.loads(store.get('FROST_BOUNDARY_STATE_CALENDAR04_FINAL_NEGATIVES_V1.json'))
        assert negatives['candidate']==CANDIDATE and negatives['status']=='FOUR_ACTUAL_COMMITTED_PUSHED_CLEAN14_PUBLIC_NEGATIVES_REFUSED'
        assert {x['role'] for x in negatives['controls']}=={'SOURCE','RAW','INHERITED','PUBLICATION'}
        for item in negatives['controls']:
            assert item['actual_refusal'] and item['actual_one_file_delta']
            assert git('show','-s','--format=%P',item['head']).decode().split()==[CANDIDATE]
            assert git('diff','--name-only',CANDIDATE,item['head']).decode().splitlines()==[item['path']]
        closure=json.loads(store.get('FROST_BOUNDARY_STATE_CALENDAR04_PREMERGE_CLOSURE_V1.json'))
        assert closure['actual_candidate']==CANDIDATE and closure['unaffected_MCSOL_model_replay']=='NOT_SELECTED_IMPACT_1063_DEPENDENCY_FILES_EXACT'
    prior=prior_admission();assert git('rev-parse','HEAD').decode().strip()==head
    return dict(status='GENUINE_CANONICAL568_SIGNED_MERGE_ACTUAL_PUBLIC_PUB_15CI_SEVEN_LOGS_REAL_NEGATIVES_AND_PRIOR524_CHAIN_PASS',actual_parent=BASE,receipt=receipt,observations=observations,original_archived_signed_commit_custody=commits,prior_524_admission=prior,compiler_executions=0,model_executions=0)
