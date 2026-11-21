"""Seal actual model7 canonical admission, keeping every neutral research role."""
import argparse
from contextlib import ExitStack
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile
from model7_search_science import Store,grid

ROOT=Path(__file__).resolve().parents[2]
HEAD='dcd7adebd6414b69e825e955471941a179be47b1'
PARENT='085c95c3202380bb01987fdb5741b437d2acbf12'
CANONICAL='0abcdd5eb3a00327d505cdc897e92c50030ed3e7'
SYNTHETIC='8f4b72014ce73ad95af56460971f775d6dfc2172'
TREE='7c5dbb9bc08f5b3ed1745e7914c3ce6f47f4c8a6'
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def decoded(q):
    if isinstance(q,dict) and isinstance(q.get('content'),str):return json.loads(q['content'])
    if isinstance(q,dict) and isinstance(q.get('content'),list):return json.loads(q['content'][0]['text'])
    return q


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--evidence',type=Path,required=True);a=p.parse_args()
    proof=ROOT/'integration/f-ci/nomacro-complete01';ev=a.evidence
    git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
    load=lambda name:decoded(json.loads((ev/name).read_text()))
    for commit in (CANONICAL,SYNTHETIC):assert git('show','-s','--format=%P',commit).split()==[PARENT,HEAD]
    assert all(git('rev-parse',commit+'^{tree}')==TREE for commit in (HEAD,CANONICAL,SYNTHETIC))
    cases=[('MODEL7_CANDIDATE_PUBLIC_OWNER_V1',HEAD,None),
        ('MODEL7_FINAL_SOURCE_NEGATIVE_PUBLIC_V1','43c69219be305856ad6ac861735d119a946a2c0f','Actual model7 compiler source differs from qualified runtime'),
        ('MODEL7_FINAL_RAW_NEGATIVE_PUBLIC_V1','4ffba86388541bf91041c8f2eb4462f27783840e','Actual model7 original raw archive changed'),
        ('MODEL7_FINAL_INHERITED_NEGATIVE_PUBLIC_V1','24ba6538f86dd8f32f6004c210da8af91fc3c3fc','Inherited actual implicit Frost admission changed'),
        ('MODEL7_FINAL_PUBLICATION_NEGATIVE_PUBLIC_V1','1972c78986e203d50979169899eb754ba31ad8f0','Earlier observer changed beyond model7 delegation'),
        ('MODEL7_ACTUAL_CANONICAL_PUBLIC_OWNER_V1',CANONICAL,None)]
    files={};receipts=[]
    for label,head,error in cases:
        q=load(label+'.json');receipts.append(q)
        assert q['before']==q['after'] and q['before']['head']==head and q['before']['status']=='' and len(q['before']['sparse'])==33
        assert q['model_executions']==q['compiler_executions']==0 and q['command'][-1]=='tests/hupsel51/verify_successor.py'
        stdout=(ev/(label+'.stdout.txt')).read_bytes();stderr=(ev/(label+'.stderr.txt')).read_bytes()
        if error:assert q['returncode']!=0 and error in stderr.decode()
        else:assert q['returncode']==0 and not stderr and q['before']['tree']==TREE and json.loads(stdout)['status']=='BOUNDED_MODEL7_CAPACITY_SATURATED_SEARCH_SOURCE_RAW_ADMISSION_PASS'
        for suffix in ('.json','.stdout.txt','.stderr.txt'):files[label+suffix]=ev/(label+suffix)
    expected=['app/hybrid_water/model7_terminal_water.py','integration/f-ci/nomacro-complete01/HYDRAULIC_MODEL7_SEARCH_WINDOWS_RAW_V1.zip',
        'integration/f-ci/nomacro-complete01/FROST_IMPLICIT_ADMISSION_RAW_V1.zip','tests/publication/run_pub_p2e09_reference_threshold_freeze.sh']
    for case,path in zip(cases[1:5],expected):assert git('diff','--name-only',HEAD,case[1])==path
    positive=load('MODEL7_FINAL_PUBLICATION_SCOPE_POSITIVE_V1.json')
    assert positive['head']==CANONICAL and positive['tree']==TREE and not positive['status'] and 'PUBLICATION_REPLAY_SELECTED=false' in positive['stdout']
    assert 'PUBLICATION_REPLAY_SELECTED=true' in (ev/'MODEL7_FINAL_PUBLICATION_SCOPE_NEGATIVE_V1.txt').read_text()
    checks=load('MODEL7_PR1777_ALL53_TERMINAL_CHECKS_V1.json')
    assert checks['headRevision']==HEAD and len(checks['checks'])==53 and not checks['hasMore'] and not checks['statuses']
    assert all(c['head_sha']==HEAD and c['status']=='completed' and c['conclusion'] in ('success','skipped') for c in checks['checks'])
    assert sum(c['conclusion']=='success' for c in checks['checks'])==38
    pre=load('MODEL7_PR1777_IMMEDIATE_PREMERGE_V1.json');merge=load('MODEL7_PR1777_ACTUAL_MERGE_API_V1.json')
    assert pre['head']['sha']==HEAD and pre['base']['sha']==PARENT and pre['merge_commit_sha']==SYNTHETIC and pre['mergeable'] and not pre['draft']
    assert merge['sha']==CANONICAL and merge['merged'] is True
    cancelled=load('MODEL7_PR1777_CANCELLED_RUN1_V1.json');assert cancelled['id']==44844163689 and cancelled['conclusion']=='cancelled' and cancelled['head_sha']==HEAD
    original=ev/'MODEL7_PR1777_CANCELLED_HUPSEL_ORIGINAL.zip';assert original.stat().st_size==7179475 and SHA(original.read_bytes())=='64f63d4622186842fc914a502453187e6b5c7460243af20249975fd954beddf8'
    assert 'undrained FULL_AND_NATIVE_RESTART_PASS' in (ev/'MODEL7_PR1777_CANCELLED_JOB136659682089_FULL.txt').read_text()
    for job in (136659681837,136666483356):assert 'BOUNDED_MODEL7_CAPACITY_SATURATED_SEARCH_SOURCE_RAW_ADMISSION_PASS' in (ev/f'MODEL7_PR1777_FINAL_JOB{job}_FULL.txt').read_text()
    retry=(ev/'MODEL7_PR1777_FINAL_JOB136668617147_FULL.txt').read_text();assert all(word in retry for word in ('grass FULL_AND_NATIVE_RESTART_PASS','hupsel FULL_AND_NATIVE_RESTART_PASS','salt FULL_AND_NATIVE_RESTART_PASS'))
    qualpath='integration/f-ci/nomacro-complete01/HYDRAULIC_MODEL7_QUALIFICATION.json';q=json.loads((ROOT/qualpath).read_text())
    paths=[qualpath]+[str(Path(qualpath).parent/name) for item in q['archives'].values() for name in (item['record'],item['archive'])]
    assert len(paths)==9 and not git('diff',HEAD,'--',*paths),'Neutral model7 role changed'
    # Earlier Windows capacity grids remain research evidence, read directly
    # here rather than counted as new periods or rebound to a later producer.
    with ExitStack() as stack:
        research=Store(proof,'HYDRAULIC_MODEL7_PRETERMINAL_RESEARCH_RAW_V1',stack)
        windows_grid={opt:grid(research.view('profiles/hydraulic-model7-grid-original-'+opt+'-v1'),research.view('profiles/hydraulic-model7-grid-corrected-'+opt+'-v1')) for opt in ('O0','O2')}
    extra=['MODEL7_PUBLIC_OBSERVE_V1.py','MODEL7_FINAL_PUBLICATION_SCOPE_POSITIVE_V1.json','MODEL7_FINAL_PUBLICATION_SCOPE_NEGATIVE_V1.txt','MODEL7_FINAL_NEGATIVES_OBSERVE_V1.json','MODEL7_ACTUAL_CANONICAL_POSTIMAGE_V1.json']
    for name in extra:files[name]=ev/name
    for path in ev.glob('MODEL7_PR1777_*'):assert path.is_file();files[path.name]=path
    archive=proof/'HYDRAULIC_MODEL7_ADMISSION_RAW_V1.zip';assert not archive.exists() and not archive.with_suffix('.json').exists()
    members={name:dict(bytes=path.stat().st_size,sha256=SHA(path.read_bytes())) for name,path in files.items()}
    with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
        for name,path in sorted(files.items()):z.write(path,name)
    with zipfile.ZipFile(archive) as z:
        assert len(z.namelist())==len(set(z.namelist()))==len(members)
        for name,item in members.items():raw=z.read(name);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
    digest=SHA(archive.read_bytes());record=dict(status='ACTUAL_CANONICAL_MODEL7_ADMISSION_RAW_SEALED',canonical=CANONICAL,candidate=HEAD,
        ordered_parents=[PARENT,HEAD],full_tree=TREE,archive=archive.name,bytes=archive.stat().st_size,sha256=digest,members=members,
        sealer_source=git('rev-parse','HEAD'),actual_original_Windows_capacity_grid=windows_grid,
        retained_preterminal_research_archive_sha256='5b11bee40e7dd392fe1a0cf87cf6164cb840cac5f45516baf7a06b7dce083350',
        original_cancelled_attempt_retained=True,exact_head_retry_job=136668617147,neutral_scientific_archives_changed=False,
        functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)
    archive.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n')
    receipt=dict(status='ACTUAL_CANONICAL_BOUNDED_MODEL7_ADMISSION_VERIFIED',PR=1777,url='https://github.com/abhedwig-cell/SWAP5/pull/1777',previous_canonical=PARENT,
        qualified_head=HEAD,synthetic_merge=SYNTHETIC,actual_merge=CANONICAL,ordered_parents=[PARENT,HEAD],whole_qualified_tree=TREE,
        all_terminal_PR_checks=53,success=38,skipped=15,actual_candidate_public_seconds=receipts[0]['seconds'],actual_canonical_public_seconds=receipts[-1]['seconds'],
        actual_canonical_sparse_patterns=33,admission_archive_sha256=digest,model7_admitted=True,neutral_qualification_and_four_archives_unchanged=True,
        original_cancelled_attempt_retained=True,exact_head_retry_job=136668617147,actual_original_Windows_capacity_grid=windows_grid,
        public_compiler_executions=0,public_model_executions=0,AGE_admitted=False,implicit_nondefault_conductivity_admitted=False,other_hydraulic_models_admitted=False,
        new_physical_state=False,tolerance_changed=False,whole_historical_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False,
        scope=q['scope'],canonical085_unrelated_push_preservation_failures_retained=True)
    (proof/'HYDRAULIC_MODEL7_MERGE_RECEIPT_V1.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(record['status'],record['bytes'],digest,len(members),flush=True)


if __name__=='__main__':main()
