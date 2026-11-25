"""Historical canonical524 admission custody; plate convergence is separately reopened."""
import hashlib,json,subprocess
from pathlib import Path
from contextlib import ExitStack
from analytical_hydraulic_archives import Archive
from frost_boundary_git_archive import GitArchiveSource

ROOT=Path(__file__).resolve().parents[2]
BASE='9936bcda75eb920d67aa74e47018baf39ab18f78'
CANDIDATE='2e9dc651b13e54eca0ba91a867d0849dd7904959'
SYNTHETIC='601d706e04de3e548e00b775cf584d76ff6eefbd'
ADMISSION_SHA='70ab469b46905909c6b68cc613b5bd72815677fbe36ddc2dc6c39512f3cb5350'
git=lambda *a:subprocess.check_output(['git',*a],cwd=ROOT)


def archived_commit(raw,sha,tree,parents):
    """Verify genuine frozen commit data without requiring an ephemeral ref."""
    assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==sha
    headers,message=raw.split(b'\n\n',1);lines=headers.split(b'\n')
    assert [line[5:].decode() for line in lines if line.startswith(b'tree ')]==[tree]
    assert [line[7:].decode() for line in lines if line.startswith(b'parent ')]==parents
    assert all(sum(line.startswith(key+b' ') for line in lines)==1 for key in (b'author',b'committer',b'gpgsig'))
    assert message
    return dict(status='ORIGINAL_ARCHIVED_SIGNED_COMMIT_EXACT_GIT_SHA1_TREE_AND_ORDERED_PARENTS_PASS',
                sha=sha,tree=tree,parents=parents,bytes=len(raw),raw_sha256=hashlib.sha256(raw).hexdigest(),
                archive_data_not_a_local_Git_object_projection=True)


def parent_admission():
    head=git('rev-parse','HEAD').decode().strip();data=GitArchiveSource(ROOT,head)
    receipt=json.loads((data/'FROST_BOUNDARY03_MERGE_RECEIPT_V1.json').read_text())
    assert receipt['actual_merge']==BASE and receipt['qualified_candidate']==CANDIDATE and receipt['canonical_admission']
    assert receipt['admission_archive_sha256']==ADMISSION_SHA
    assert git('show','-s','--format=%P',BASE).decode().split()==receipt['ordered_parents']==['1c3b8725548c836c9a73570c2579dd6cdc683217',CANDIDATE]
    tree=git('rev-parse',BASE+'^{tree}').decode().strip();assert tree==receipt['whole_tree']==git('rev-parse',CANDIDATE+'^{tree}').decode().strip()
    with ExitStack() as stack:
        store=Archive(data,'FROST_BOUNDARY03_ADMISSION_RAW_V1',stack);assert store.record['sha256']==ADMISSION_SHA
        for name in store.names:store.get(name)
        commits=[]
        for sha in (BASE,SYNTHETIC):
            raw=store.get('FROST_BOUNDARY03_PR1802_GENUINE_GIT_OBJECT_'+sha+'.bin')
            commits.append(archived_commit(raw,sha,tree,receipt['ordered_parents']))
            if sha==BASE:assert raw==git('cat-file','commit',sha)
        observations={};inputs=None;stats=None
        for role,version,sha in [('CANDIDATE','V5',CANDIDATE),('ACTUAL_MERGE','V1',BASE)]:
            for kind in ('PUBLIC','PUBLICATION'):
                label='FROST_BOUNDARY03_'+role+'_'+kind+'_'+version
                q=json.loads(store.get(label+'.json'));out=store.get(label+'.stdout.txt')
                assert q['before']==q['after'] and q['before']['head']==sha and q['before']['tree']==tree and q['returncode']==0
                assert not q['before']['status'] and len(q['before']['sparse'])==14 and len(q['before']['original_project_files'])==56
                assert not store.get(label+'.stderr.txt')
                if inputs is None:inputs=q['before']['original_project_files']
                assert inputs==q['before']['original_project_files']
                if kind=='PUBLIC':
                    observed=json.loads(out)['coadmission'];assert observed==receipt['coadmission']
                    stats=observed
                else:
                    assert b'PUBLICATION_REPLAY_SELECTED=false' in out and q['ordinary_python_default_dont_write_bytecode'] is False and q['child_bytecode_environment_variables_absent']
                observations[label]=q['seconds']
        assert (stats['contexts'],stats['short35_contexts'],stats['year367_contexts'],stats['new_short_calendar_contexts'],stats['native_calendar_samples'],stats['exact_cold_windows'],stats['compiled_initialization_postimages'])==(524,510,2,12,3618,1556,375)
        ci=json.loads(store.get('FROST_BOUNDARY03_PR1802_FINAL_ALL_CI_API_V1.json'))
        runs=ci['runs']['workflow_runs'];checks=ci['checks']['check_runs']
        assert len(runs)==16 and all(x['status']=='completed' and x['conclusion']=='success' and x['head_sha']==CANDIDATE for x in runs)
        assert len(checks)==47 and sum(x['conclusion']=='success' for x in checks)==30 and sum(x['conclusion']=='skipped' for x in checks)==17
        for role in ('CO2','DVS','LRV','FCI_MODULAR','TIMEINT_STARTUP','TIMEINT_INVERSE','MCSOL_SWP','MCSOL_COLUMN'):
            label='FROST_BOUNDARY03_PR1802_'+role+'_ORIGINAL_CI_V2.log';raw=store.get(label);q=json.loads(store.get(label+'.json'))
            assert len(raw)==q['bytes'] and hashlib.sha256(raw).hexdigest()==q['sha256'] and CANDIDATE.encode() in raw and SYNTHETIC.encode() in raw
        negative=json.loads(store.get('FROST_BOUNDARY03_SRC5_FINAL_NEGATIVES_V1.json'))
        assert negative['candidate']==CANDIDATE and negative['status']=='FOUR_ACTUAL_COMMITTED_PUSHED_CLEAN14_PUBLIC_NEGATIVES_REFUSED'
        assert {x['role'] for x in negative['controls']}=={'SOURCE','RAW','INHERITED','PUBLICATION'} and len(negative['controls'])==4
        for item in negative['controls']:
            assert item['actual_refusal'] and item['actual_one_file_delta']
            assert git('show','-s','--format=%P',item['head']).decode().split()==[CANDIDATE]
            assert git('diff','--name-only',CANDIDATE,item['head']).decode().splitlines()==[item['path']]
    assert git('rev-parse','HEAD').decode().strip()==head
    return dict(status='HISTORICAL_CANONICAL524_SIGNED_PARENT_ORIGINAL_PUBLIC_PUB_ALL16CI_EIGHT_ORIGINAL_LOGS_AND_REAL_NEGATIVES_PASS',
                actual_parent=BASE,receipt=receipt,actual_admitted_coadmission=stats,observations=observations,
                original_archived_signed_commit_custody=commits,
                inherited_model_periods_reexecuted=0,compiler_executions=0,model_executions=0,plate_convergence='REOPENED_8_CONTEXTS_SEPARATE_CURRENT_QUALIFICATION_REQUIRED')
