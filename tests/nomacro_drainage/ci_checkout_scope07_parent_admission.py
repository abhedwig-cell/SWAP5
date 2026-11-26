"""Genuine canonical648 admission, signed commits and original observations."""
import hashlib,json,subprocess
from pathlib import Path
from contextlib import ExitStack
from analytical_hydraulic_archives import Archive,SHA
from frost_boundary_git_archive import GitArchiveSource
from frost_boundary_state_calendar_parent_admission import archived_commit
from frost_implicit_hys2_parent_admission import parent_admission as prior_admission
R=Path(__file__).resolve().parents[2]
BASE='df00f9393ac552b0a6cab8ee84f8b8d8c06ac26c'
CANDIDATE='cb712974e37e41256877d9770a0af071afe241dd'
SYNTHETIC='c65c7eb92cdc82ab786f62cb96bf376404e45130'
ADMISSION_SHA='686d02451f9e5f3b5f624a10fea5c464000d91abc94d46243a0c5ef3526d1b7f'
git=lambda *a:subprocess.check_output(['git',*a],cwd=R)


def parent_admission():
    head=git('rev-parse','HEAD').decode().strip();data=GitArchiveSource(R,head)
    receipt=json.loads((data/'FROST_IMPLICIT_HYS2_YEAR06_MERGE_RECEIPT_V1.json').read_text())
    assert receipt['actual_merge']==BASE and receipt['qualified_candidate']==CANDIDATE and receipt['canonical_admission']
    assert receipt['admission_archive_sha256']==ADMISSION_SHA
    parents=git('show','-s','--format=%P',BASE).decode().split();assert parents==receipt['ordered_parents']==['47124f4de18a752fc466d50e2752e843548e5fea',CANDIDATE]
    tree=git('rev-parse',BASE+'^{tree}').decode().strip();assert tree==receipt['whole_tree']==git('rev-parse',CANDIDATE+'^{tree}').decode().strip()
    with ExitStack() as stack:
        store=Archive(data,'FROST_IMPLICIT_HYS2_YEAR06_ADMISSION_RAW_V1',stack);assert store.record['sha256']==ADMISSION_SHA
        for name in store.names:store.get(name)
        commits=[]
        for sha in [BASE,SYNTHETIC]:
            raw=store.get('FROST_IMPLICIT_HYS2_YEAR06_PR1805_GENUINE_GIT_OBJECT_'+sha+'.bin');commits.append(archived_commit(raw,sha,tree,parents))
            if sha==BASE:assert raw==git('cat-file','commit',sha)
        observations={};inputs=None
        for role,version,sha in [('CANDIDATE','V1',CANDIDATE),('ACTUAL_MERGE','V1',BASE)]:
            for kind in ['PUBLIC','PUBLICATION']:
                label='FROST_IMPLICIT_HYS2_YEAR06_'+role+'_'+kind+'_'+version
                q=json.loads(store.get(label+'.json'));out=store.get(label+'.stdout.txt')
                assert q['returncode']==0 and q['before']==q['after'] and not q['before']['status']
                assert q['before']['head']==sha and q['before']['tree']==tree and len(q['before']['sparse'])==14 and len(q['before']['original_project_files'])==56
                assert not store.get(label+'.stderr.txt')
                if inputs is None:inputs=q['before']['original_project_files']
                assert inputs==q['before']['original_project_files']
                if kind=='PUBLIC':assert json.loads(out)['coadmission']==receipt['coadmission']
                else:assert b'PUBLICATION_REPLAY_SELECTED=false' in out and q['ordinary_python_default_dont_write_bytecode'] is False and q['child_bytecode_environment_variables_absent']
                observations[label]=q['seconds']
        ci=json.loads(store.get('FROST_IMPLICIT_HYS2_YEAR06_PR1805_FINAL_ALL_CI_API_V1.json'));runs=ci['runs']['workflow_runs'];checks=ci['checks']['check_runs']
        assert len(runs)==14 and all(x['status']=='completed' and x['conclusion']=='success' and x['head_sha']==CANDIDATE for x in runs)
        assert len(checks)==45 and sum(x['conclusion']=='success' for x in checks)==28 and sum(x['conclusion']=='skipped' for x in checks)==17
        for role in ['CO2','DVS','LRV','FCI_MODULAR','TIMEINT_STARTUP','TIMEINT_INVERSE']:
            label='FROST_IMPLICIT_HYS2_YEAR06_PR1805_'+role+'_ORIGINAL_CI_V1.log';raw=store.get(label);q=json.loads(store.get(label+'.json'))
            assert len(raw)==q['bytes'] and SHA(raw)==q['sha256'] and CANDIDATE.encode() in raw and SYNTHETIC.encode() in raw
        negatives=json.loads(store.get('FROST_IMPLICIT_HYS2_YEAR06_FINAL_NEGATIVES_V1.json'))
        assert negatives['candidate']==CANDIDATE and negatives['status']=='FOUR_ACTUAL_COMMITTED_PUSHED_CLEAN14_PUBLIC_NEGATIVES_REFUSED'
        assert {x['role'] for x in negatives['controls']}=={'SOURCE','RAW','INHERITED','PUBLICATION'}
        for item in negatives['controls']:
            assert item['actual_refusal'] and item['actual_one_file_delta']
            assert git('show','-s','--format=%P',item['head']).decode().split()==[CANDIDATE]
            assert git('diff','--name-only',CANDIDATE,item['head']).decode().splitlines()==[item['path']]
        closure=json.loads(store.get('FROST_IMPLICIT_HYS2_YEAR06_PREMERGE_CLOSURE_V1.json'))
        assert closure['actual_candidate']==CANDIDATE and closure['unaffected_MCSOL_model_replay']=='NOT_SELECTED_IMPACT_1063_DEPENDENCY_FILES_EXACT'
    prior=prior_admission();assert git('rev-parse','HEAD').decode().strip()==head
    return dict(status='GENUINE_CANONICAL648_SIGNED_MERGE_ACTUAL_PUBLIC_PUB_14CI_SIX_LOGS_REAL_NEGATIVES_AND_PRIOR600_CHAIN_PASS',actual_parent=BASE,receipt=receipt,observations=observations,original_archived_signed_commit_custody=commits,prior_600_admission=prior,compiler_executions=0,model_executions=0)
