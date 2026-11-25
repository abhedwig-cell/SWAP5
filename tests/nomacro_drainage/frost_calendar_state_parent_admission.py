"""Actual admitted Frost parent receipt, signed object and original observer bytes."""
import sys,json,subprocess,hashlib
from pathlib import Path
from contextlib import ExitStack
R=Path(__file__).resolve().parents[2];P=R/'integration/f-ci/nomacro-complete01';sys.path.insert(0,str(R/'tests/nomacro_drainage'))
from analytical_hydraulic_archives import Archive
BASE='8dbe3db7c7832dd6a1f86c4275cd43f054552df3'
ADMISSION_SHA='4c6da7790d3e0732f1fc474b8ae4373c76e92e2ae93575dd1dea5b5a36c29508'
def git(*args):return subprocess.check_output(['git',*args],cwd=R)
def parent_admission(anchor):
    path='integration/f-ci/nomacro-complete01/FROST_HYSTERESIS_STATE01_MERGE_RECEIPT_V1.json';raw=(R/path).read_bytes().replace(b'\r\n',b'\n');assert raw==git('show',anchor+':'+path);receipt=json.loads(raw)
    candidate=receipt['qualified_candidate'];assert receipt['actual_merge']==BASE and receipt['canonical_admission'] and receipt['admission_archive_sha256']==ADMISSION_SHA
    assert git('rev-parse',BASE+'^{tree}').decode().strip()==receipt['whole_tree']==git('rev-parse',candidate+'^{tree}').decode().strip()
    assert git('show','-s','--format=%P',BASE).decode().split()==receipt['ordered_parents']
    with ExitStack() as stack:
        store=Archive(P,'FROST_HYSTERESIS_STATE01_ADMISSION_RAW_V1',stack);assert store.record['sha256']==ADMISSION_SHA
        for name in store.names:store.get(name)
        raw=store.get('FROST_HYSTERESIS_STATE01_PR1800_GENUINE_GIT_OBJECT_'+BASE+'.bin');assert raw==git('cat-file','commit',BASE) and hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==BASE
        label='FROST_HYSTERESIS_STATE01_ACTUAL_MERGE_PUBLIC_V1';q=json.loads(store.get(label+'.json'));public=json.loads(store.get(label+'.stdout.txt'));assert q['before']==q['after'] and q['before']['head']==BASE and q['returncode']==0 and not store.get(label+'.stderr.txt')
        assert len(q['before']['sparse'])==14 and len(q['before']['original_project_files'])==56;stats=public['coadmission'];assert stats==receipt['coadmission']
        assert (stats['contexts'],stats['native_calendar_samples'],stats['exact_cold_windows'],stats['compiled_initialization_postimages'])==(472,3310,1420,375)
        label='FROST_HYSTERESIS_STATE01_ACTUAL_MERGE_PUBLICATION_V1';q=json.loads(store.get(label+'.json'));assert q['before']==q['after'] and q['before']['head']==BASE and q['returncode']==0 and b'PUBLICATION_REPLAY_SELECTED=false' in store.get(label+'.stdout.txt')
        assert q['ordinary_python_default_dont_write_bytecode'] is False and q['child_bytecode_environment_variables_absent']
        ci=json.loads(store.get('FROST_HYSTERESIS_STATE01_PR1800_FINAL_ALL_CI_API_V1.json'));runs=ci['runs']['workflow_runs'];assert len(runs)==16 and all(x['status']=='completed' and x['conclusion']=='success' and x['head_sha']==candidate for x in runs)
        checks=ci['checks']['check_runs'];assert len(checks)==47 and sum(x['conclusion']=='success' for x in checks)==30 and sum(x['conclusion']=='skipped' for x in checks)==17
        negatives=json.loads(store.get('FROST_HYSTERESIS_STATE01_FINAL_NEGATIVES_V1.json'));assert negatives['candidate']==candidate and len(negatives['controls'])==4
        assert {x['role'] for x in negatives['controls']}=={'SOURCE','RAW','INHERITED','PUBLICATION'}
        for x in negatives['controls']:
            assert x['actual_refusal'] and x['actual_one_file_delta'] and x['exact_parent']==candidate
            assert git('show','-s','--format=%P',x['head']).decode().split()==[candidate]
            assert git('diff','--name-only',candidate,x['head']).decode().splitlines()==[x['path']]
    return dict(status='ACTUAL_CANONICAL472_SIGNED_PARENT_ORIGINAL_CLEAN14_PUBLIC_PUBLICATION_CI_AND_PUSHED_NEGATIVES_PASS',receipt=receipt,actual_admitted_coadmission=stats,parent_model_periods_reexecuted=0,old_scientific_math_reexecution_claimed=False)
