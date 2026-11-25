"""Genuine signed canonical500 parent, original observers, CI and real negatives."""
import hashlib,json,subprocess
from pathlib import Path
from contextlib import ExitStack
from analytical_hydraulic_archives import Archive
from frost_boundary_git_archive import GitArchiveSource

ROOT=Path(__file__).resolve().parents[2]
BASE='1c3b8725548c836c9a73570c2579dd6cdc683217'
CANDIDATE='3250f0c59337334994b0e8edda624afe8f91b11f'
SYNTHETIC='ecd8ad97ca5a6e19239ebd06fe0547711cf3ec68'
ADMISSION_SHA='5fc94d202dc7b7d1de61418e25f96384eea667f49d63aacd4d86f1da163310a6'
git=lambda *a:subprocess.check_output(['git',*a],cwd=ROOT)


def parent_admission():
    head=git('rev-parse','HEAD').decode().strip();data=GitArchiveSource(ROOT,head)
    receipt=json.loads((data/'FROST_CALENDAR_STATE02_MERGE_RECEIPT_V1.json').read_text())
    assert receipt['actual_merge']==BASE and receipt['qualified_candidate']==CANDIDATE and receipt['canonical_admission']
    assert receipt['admission_archive_sha256']==ADMISSION_SHA
    assert git('show','-s','--format=%P',BASE).decode().split()==receipt['ordered_parents']==['8dbe3db7c7832dd6a1f86c4275cd43f054552df3',CANDIDATE]
    tree=git('rev-parse',BASE+'^{tree}').decode().strip();assert tree==receipt['whole_tree']==git('rev-parse',CANDIDATE+'^{tree}').decode().strip()
    with ExitStack() as stack:
        store=Archive(data,'FROST_CALENDAR_STATE02_ADMISSION_RAW_V1',stack);assert store.record['sha256']==ADMISSION_SHA
        for name in store.names:store.get(name)
        for sha in (BASE,SYNTHETIC):
            raw=store.get('FROST_CALENDAR_STATE02_PR1801_GENUINE_GIT_OBJECT_'+sha+'.bin')
            assert raw==git('cat-file','commit',sha) and hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==sha
        observations={};inputs=None;stats=None
        for role,version,sha in [('CANDIDATE','V3',CANDIDATE),('ACTUAL_MERGE','V1',BASE)]:
            for kind in ('PUBLIC','PUBLICATION'):
                label='FROST_CALENDAR_STATE02_'+role+'_'+kind+'_'+version
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
        assert (stats['contexts'],stats['short35_contexts'],stats['year367_contexts'],stats['new_short_calendar_contexts'],stats['native_calendar_samples'],stats['exact_cold_windows'],stats['compiled_initialization_postimages'])==(500,486,2,12,3450,1484,375)
        ci=json.loads(store.get('FROST_CALENDAR_STATE02_PR1801_FINAL_ALL_CI_API_V1.json'))
        runs=ci['runs']['workflow_runs'];checks=ci['checks']['check_runs']
        assert len(runs)==17 and all(x['status']=='completed' and x['conclusion']=='success' and x['head_sha']==CANDIDATE for x in runs)
        assert len(checks)==48 and sum(x['conclusion']=='success' for x in checks)==31 and sum(x['conclusion']=='skipped' for x in checks)==17
        for role in ('CO2','DVS','LRV','FCI_MODULAR','TIMEINT_STARTUP','TIMEINT_INVERSE','MCSOL_SWP','MCSOL_COLUMN'):
            label='FROST_CALENDAR_STATE02_PR1801_'+role+'_ORIGINAL_CI_V1.log';raw=store.get(label);q=json.loads(store.get(label+'.json'))
            assert len(raw)==q['bytes'] and hashlib.sha256(raw).hexdigest()==q['sha256'] and CANDIDATE.encode() in raw and SYNTHETIC.encode() in raw
        negative=json.loads(store.get('FROST_CALENDAR_STATE02_BOTHCI_FINAL_NEGATIVES_V1.json'))
        assert negative['candidate']==CANDIDATE and negative['status']=='FOUR_ACTUAL_COMMITTED_PUSHED_CLEAN14_PUBLIC_NEGATIVES_REFUSED'
        assert {x['role'] for x in negative['controls']}=={'SOURCE','RAW','INHERITED','PUBLICATION'} and len(negative['controls'])==4
        for item in negative['controls']:
            assert item['actual_refusal'] and item['actual_one_file_delta']
            assert git('show','-s','--format=%P',item['head']).decode().split()==[CANDIDATE]
            assert git('diff','--name-only',CANDIDATE,item['head']).decode().splitlines()==[item['path']]
    assert git('rev-parse','HEAD').decode().strip()==head
    return dict(status='ACTUAL_CANONICAL500_SIGNED_PARENT_ORIGINAL_PUBLIC_PUB_ALL17CI_EIGHT_ORIGINAL_LOGS_AND_REAL_NEGATIVES_PASS',
                actual_parent=BASE,receipt=receipt,actual_admitted_coadmission=stats,observations=observations,
                inherited_model_periods_reexecuted=0,compiler_executions=0,model_executions=0)
