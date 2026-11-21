"""Seal actual analytical-family canonical admission; neutral scientific roles stay fixed."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[2]
HEAD='dcb0a8215573176f73e4fea5dd232e19e4ea8e6a'
PARENT='0abcdd5eb3a00327d505cdc897e92c50030ed3e7'
CANONICAL='5b8373d0809c25e24415f4d5dc01784a92ff481e'
SYNTHETIC='285f92d7dacbd04aecf05008f4b03b3a91e59d72'
TREE='3a397ffce19cfc7e2af027f404aefaf16df6f535'
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def decoded(q):
    if isinstance(q,dict) and 'structuredContent' in q:return decoded(q['structuredContent'])
    if isinstance(q,dict) and isinstance(q.get('content'),str):return json.loads(q['content'])
    if isinstance(q,dict) and isinstance(q.get('content'),list):return json.loads(q['content'][0]['text'])
    return q


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--evidence',type=Path,required=True);p.add_argument('--verify-only',action='store_true');a=p.parse_args();ev=a.evidence;proof=ROOT/'integration/f-ci/nomacro-complete01'
    git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
    load=lambda name:decoded(json.loads((ev/name).read_text(encoding='utf8')))
    for commit in (CANONICAL,SYNTHETIC):assert git('show','-s','--format=%P',commit).split()==[PARENT,HEAD]
    assert all(git('rev-parse',commit+'^{tree}')==TREE for commit in (HEAD,CANONICAL,SYNTHETIC))
    cases=[('ANALYTICAL_FINAL_CANDIDATE_PUBLIC_OWNER_V1',HEAD,None),
        ('ANALYTICAL_FINAL_SOURCE_NEGATIVE_PUBLIC_V1','105044fa83fd18a518d5950ca0f7fdd8676fbc77','Actual analytical compiler source differs from exact guarded runtime'),
        ('ANALYTICAL_FINAL_RAW_NEGATIVE_PUBLIC_V1','3c8da836bb3fc5699f4e3cc93c6aa09474197e72','AssertionError'),
        ('ANALYTICAL_FINAL_INHERITED_NEGATIVE_PUBLIC_V1','d239f030bb8a2d7d9ee1425c09ab3830a428a86f','AssertionError'),
        ('ANALYTICAL_FINAL_PUBLICATION_NEGATIVE_PUBLIC_V1','ffbc6eaaa42241683fffac931d92e00e58f94081','Earlier observer changed beyond exact analytical delegation and component inverse'),
        ('ANALYTICAL_ACTUAL_CANONICAL_PUBLIC_OWNER_V1',CANONICAL,None)]
    files={};receipts=[]
    for label,head,error in cases:
        q=load(label+'.json');receipts.append(q)
        assert q['before']==q['after'] and q['before']['head']==head and not q['before']['status'] and len(q['before']['sparse'])==34
        assert q['model_executions']==q['compiler_executions']==0 and q['command'][-1]=='tests/hupsel51/verify_successor.py'
        stdout=(ev/(label+'.stdout.txt')).read_bytes();stderr=(ev/(label+'.stderr.txt')).read_bytes()
        if error:assert q['returncode']!=0 and error in stderr.decode()
        else:assert q['returncode']==0 and not stderr and q['before']['tree']==TREE and json.loads(stdout)['status']=='BOUNDED_ORIGINAL_EXPLICIT_ANALYTICAL_FAMILY_SOURCE_RAW_NATIVE_PASS'
        for suffix in ('.json','.stdout.txt','.stderr.txt'):files[label+suffix]=ev/(label+suffix)
    paths=['app/hybrid_water/experimental_project.py','integration/f-ci/nomacro-complete01/HYDRAULIC_ANALYTICAL_UBUNTU_O2_RAW_V1.zip','integration/f-ci/nomacro-complete01/HYDRAULIC_MODEL7_ADMISSION_RAW_V1.zip','tests/publication/run_pub_p2e09_reference_threshold_freeze.sh']
    for case,path in zip(cases[1:5],paths):assert git('diff','--name-only',HEAD,case[1])==path
    for role,head in (('POSITIVE',HEAD),('CANONICAL_POSITIVE',CANONICAL)):
        q=load('ANALYTICAL_FINAL_PUBLICATION_SCOPE_'+role+'_V1.json');assert q['before']==q['after'] and q['before']['head']==head and q['before']['tree']==TREE and not q['before']['status'] and not q['publication_replay_selected'] and 'PUBLICATION_REPLAY_SELECTED=false' in q['stdout']
    assert 'PUBLICATION_REPLAY_SELECTED=true' in (ev/'ANALYTICAL_FINAL_PUBLICATION_SCOPE_NEGATIVE_V1.txt').read_text()
    checks=load('ANALYTICAL_PR1778_ALL44_TERMINAL_CHECKS_V1.json');assert checks['headRevision']==HEAD and len(checks['checks'])==44 and not checks['hasMore'] and not checks['statuses']
    assert all(c['head_sha']==HEAD and c['status']=='completed' and c['conclusion'] in ('success','skipped') for c in checks['checks'])
    assert sum(c['conclusion']=='success' for c in checks['checks'])==29
    runs=load('ANALYTICAL_PR1778_ALL15_TERMINAL_RUNS_V1.json')['workflow_runs'];assert len(runs)==15 and all(r['status']=='completed' and r['conclusion']=='success' for r in runs)
    pre=load('ANALYTICAL_PR1778_IMMEDIATE_PREMERGE_V1.json');merge=load('ANALYTICAL_PR1778_ACTUAL_MERGE_API_V1.json')
    assert pre['head']['sha']==HEAD and pre['base']['sha']==PARENT and pre['merge_commit_sha']==SYNTHETIC and pre['mergeable'] and not pre['draft'];assert merge['sha']==CANONICAL and merge['merged'] is True
    for job in (136693192938,136693192959,136695125656):assert 'BOUNDED_ORIGINAL_EXPLICIT_ANALYTICAL_FAMILY_SOURCE_RAW_NATIVE_PASS' in (ev/f'ANALYTICAL_PR1778_FINAL_JOB{job}_FULL.txt').read_text(encoding='utf8')
    qualpath='integration/f-ci/nomacro-complete01/HYDRAULIC_ANALYTICAL_QUALIFICATION.json';qual=json.loads((ROOT/qualpath).read_text());neutral=[qualpath]
    for item in qual['archives'].values():
        record=proof/item['record'];q=json.loads(record.read_text());neutral.append(record.relative_to(ROOT).as_posix());neutral.extend((proof/name).relative_to(ROOT).as_posix() for name in ([v['file'] for v in q['parts']] if q.get('parts') else [q['archive']]))
    assert len(neutral)==14 and not git('diff',HEAD,'--',*neutral),'Neutral scientific qualification or accepted raw identity changed'
    assert qual['analytical_family_admitted'] is False and qual['actual_full1096_contexts']==80 and qual['actual_exact_cold_windows']==800
    for name in ('ANALYTICAL_PUBLIC_OBSERVE_V1.py','ANALYTICAL_FINAL_PUBLICATION_SCOPE_POSITIVE_V1.json','ANALYTICAL_FINAL_PUBLICATION_SCOPE_CANONICAL_POSITIVE_V1.json','ANALYTICAL_FINAL_PUBLICATION_SCOPE_NEGATIVE_V1.txt','ANALYTICAL_FINAL_NEGATIVES_OBSERVE_V1.json','ANALYTICAL_ACTUAL_CANONICAL_POSTIMAGE_V1.json','ANALYTICAL_PR1778_ACTUAL_SYNTHETIC_POSTIMAGE_V1.json'):files[name]=ev/name
    for path in ev.glob('ANALYTICAL_PR1778_*'):assert path.is_file();files[path.name]=path
    # Retain the earlier public owner preflight under its actual, earlier head.
    for suffix in ('.json','.stdout.txt','.stderr.txt'):files['ANALYTICAL_CANDIDATE_PUBLIC_OWNER_V1'+suffix]=ev/('ANALYTICAL_CANDIDATE_PUBLIC_OWNER_V1'+suffix)
    archive=proof/'HYDRAULIC_ANALYTICAL_ADMISSION_RAW_V1.zip';members={name:dict(bytes=path.stat().st_size,sha256=SHA(path.read_bytes())) for name,path in files.items()}
    if a.verify_only:
        record=json.loads(archive.with_suffix('.json').read_text());assert record['members']==members and record['sha256']==SHA(archive.read_bytes())
    else:
        assert not archive.exists() and not archive.with_suffix('.json').exists()
        with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
            for name,path in sorted(files.items()):z.write(path,name)
    with zipfile.ZipFile(archive) as z:
        assert len(z.namelist())==len(set(z.namelist()))==len(members)
        for name,item in members.items():raw=z.read(name);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
    if a.verify_only:print('ACTUAL_ANALYTICAL_CANONICAL_ADMISSION_REVERIFIED_WITHOUT_WRITES');return
    digest=SHA(archive.read_bytes());record=dict(status='ACTUAL_CANONICAL_ANALYTICAL_ADMISSION_RAW_SEALED',canonical=CANONICAL,candidate=HEAD,ordered_parents=[PARENT,HEAD],full_tree=TREE,archive=archive.name,bytes=archive.stat().st_size,sha256=digest,members=members,sealer_source=git('rev-parse','HEAD'),neutral_scientific_archives_changed=False,retained_actual_model7_admission_sha256='dbd18b19cc8ef08044f5f9b48d1db0e20e9f6ca7bd82cf2da69168325f13ca79',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)
    archive.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n')
    receipt=dict(status='ACTUAL_CANONICAL_BOUNDED_ANALYTICAL_FAMILY_ADMISSION_VERIFIED',PR=1778,url='https://github.com/abhedwig-cell/SWAP5/pull/1778',previous_canonical=PARENT,qualified_head=HEAD,synthetic_merge=SYNTHETIC,actual_merge=CANONICAL,ordered_parents=[PARENT,HEAD],whole_qualified_tree=TREE,all_terminal_PR_checks=44,success=29,skipped=15,all15workflow_runs_success=True,actual_candidate_public_seconds=receipts[0]['seconds'],actual_canonical_public_seconds=receipts[-1]['seconds'],actual_canonical_sparse_patterns=34,admission_archive_sha256=digest,analytical_family_admitted=True,neutral_qualification_and_all_six_archive_roles_unchanged=True,full1096_contexts=80,short35_contexts=80,exact_cold_windows=800,additional_actual_model7_postimage_short35=4,additional_model7_postimage_cold_windows=12,admitted_compiled_native_refusals_reused=212,fresh_unaffected_full_periods=0,unselected_admitted_dispatches_unchanged=8,public_compiler_executions=0,public_model_executions=0,AGE_admitted=False,implicit_nondefault_conductivity_admitted=False,vapor_admitted=False,new_physical_state=False,tolerance_changed=False,whole_historical_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False,scope=qual['scope'],canonical_older_source_succession_failures_not_waived=True)
    (proof/'HYDRAULIC_ANALYTICAL_MERGE_RECEIPT_V1.json').write_text(json.dumps(receipt,indent=2)+'\n');print(record['status'],record['bytes'],digest,len(members),flush=True)


if __name__=='__main__':main()
