"""Seal actual implicit Frost canonical admission separately from neutral science."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[2]
HEAD='05d3a9dcddd9ac55b29e165a487e27442f8204df'
PARENT='ffa7ef153a79aafb4cf098a4c0031845c795e83f'
CANONICAL='085c95c3202380bb01987fdb5741b437d2acbf12'
TREE='6d411502313746a463296bd07b0ffee3530d3867'
SYNTHETIC='102b87f5831933e1f8369ff46ce51e46aab34bb2'
PREFIX='FROST_IMPLICIT_'


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--evidence',type=Path,required=True)
    a=p.parse_args();proof=ROOT/'integration/f-ci/nomacro-complete01'
    git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
    load=lambda name:json.loads((a.evidence/(PREFIX+name)).read_text(encoding='utf-8'))
    assert git('show','-s','--format=%P',CANONICAL).split()==[PARENT,HEAD]
    assert git('show','-s','--format=%P',SYNTHETIC).split()==[PARENT,HEAD]
    assert git('rev-parse',CANONICAL+'^{tree}')==git('rev-parse',SYNTHETIC+'^{tree}')==git('rev-parse',HEAD+'^{tree}')==TREE
    cases=[('CANDIDATE_PUBLIC_OWNER_V1',HEAD,None),
      ('COMMITTED_SOURCE_NEGATIVE_V1','be3930a341b6456997b1cca7124da7431142950a','Actual implicit Frost compiler source differs from qualified runtime'),
      ('COMMITTED_INHERITED_NEGATIVE_V1','9638ebb319c88569d1434796dc4b2db516212ba8','Inherited actual explicit Frost admission changed'),
      ('COMMITTED_RAW_NEGATIVE_V1','dc252beafba1d98181ee1ba5d1c2a08ae8a102c8','Changed actual original Snow raw: FROST_IMPLICIT_WINDOWS_SUPPORT_RAW_ARCHIVE.json'),
      ('ACTUAL_CANONICAL_PUBLIC_OWNER_V1',CANONICAL,None)]
    files={};receipts=[]
    for label,head,error in cases:
        q=load(label+'.json');receipts.append(q)
        assert q['before']==q['after'] and q['before']['head']==head and q['before']['status']=='' and len(q['before']['sparse'])==32
        assert q['compiler_executions']==q['model_executions']==0 and q['command'][-1]=='tests/hupsel51/verify_successor.py'
        stdout=(a.evidence/(PREFIX+label+'.stdout.txt')).read_bytes();stderr=(a.evidence/(PREFIX+label+'.stderr.txt')).read_bytes()
        if error:assert q['returncode']!=0 and error in stderr.decode('utf-8')
        else:assert q['returncode']==0 and not stderr and q['before']['tree']==TREE and json.loads(stdout)['status']=='BOUNDED_IMPLICIT_FROST_NATIVE2_SOURCE_RAW_ADMISSION_PASS'
        for suffix in ('.json','.stdout.txt','.stderr.txt'):files[PREFIX+label+suffix]=a.evidence/(PREFIX+label+suffix)
    expected_paths=['app/hybrid_water/implicit_frost_surface_conductivity.py',
      'integration/f-ci/nomacro-complete01/FROST_DRAINAGE_ADMISSION_RAW_V1.zip',
      'integration/f-ci/nomacro-complete01/FROST_IMPLICIT_WINDOWS_SUPPORT_RAW_ARCHIVE.zip']
    for case,path in zip(cases[1:4],expected_paths):assert git('diff','--name-only',HEAD,case[1])==path
    positive=load('ACTUAL_UNCHANGED_PUBLICATION_SCOPE_V1.json');negative=load('COMMITTED_PUBLICATION_DEPENDENCY_NEGATIVE_V1.json')
    assert positive['head']==HEAD and 'PUBLICATION_REPLAY_SELECTED=false' in positive['stdout']
    assert negative['head']=='d1fe93302369370f32ec9dbd0ff5e70826f1e244' and 'PUBLICATION_REPLAY_SELECTED=true' in negative['stdout']
    assert git('diff','--name-only',HEAD,negative['head'])=='tests/publication/run_pub_p2e09_reference_threshold_freeze.sh'
    checks=load('PR1776_HEAD05D3_ALL48_TERMINAL_CHECKS_V1.json')
    assert checks['headRevision']==HEAD and len(checks['checks'])==48 and not checks['hasMore'] and not checks['statuses']
    assert all(c['head_sha']==HEAD and c['status']=='completed' and c['conclusion'] in ('success','skipped') for c in checks['checks'])
    api=load('PR1776_ACTUAL_MERGE_API_V1.json');pre=api['premerge'];actual=api['merge']
    assert pre['head']['sha']==HEAD and pre['base']['sha']==PARENT and pre['merge_commit_sha']==SYNTHETIC and pre['mergeable'] is True and not pre['draft']
    assert actual['sha']==CANONICAL and actual['merged'] is True
    syn=load('PR1776_SYNTHETIC_EXACT_TREE_V1.json');assert syn['ordered_parents']==[PARENT,HEAD] and syn['whole_tree']==TREE
    paths=[path for path in git('ls-tree','-r','--name-only',HEAD,'--','integration/f-ci/nomacro-complete01').splitlines()
           if Path(path).name.startswith(PREFIX) and ('_RAW_ARCHIVE.' in path or Path(path).name=='FROST_IMPLICIT_QUALIFICATION.json')]
    assert len(paths)==21 and not git('diff',HEAD,'--',*paths),'Neutral source/readers/evidence changed'
    extra=['PUBLIC_OBSERVE_V1.py','ACTUAL_UNCHANGED_PUBLICATION_SCOPE_V1.json','COMMITTED_PUBLICATION_DEPENDENCY_NEGATIVE_V1.json',
      'PR1776_HEAD05D3_ALL48_TERMINAL_CHECKS_V1.json','PR1776_ACTUAL_MERGE_API_V1.json',
      'PR1776_SYNTHETIC_EXACT_TREE_V1.json','PR1776_ACTUAL_MERGE_GIT_IDENTITY_V1.json',
      'PR1776_HEAD05D3_JOB136615728462_FULL.txt','PR1776_HEAD05D3_JOB136623727792_FULL.txt']
    for name in extra:files[PREFIX+name]=a.evidence/(PREFIX+name)
    for job in (136615728462,136623727792):assert 'BOUNDED_IMPLICIT_FROST_NATIVE2_SOURCE_RAW_ADMISSION_PASS' in files[PREFIX+f'PR1776_HEAD05D3_JOB{job}_FULL.txt'].read_text(encoding='utf-8')
    members={name:dict(bytes=path.stat().st_size,sha256=hashlib.sha256(path.read_bytes()).hexdigest()) for name,path in files.items()}
    archive=proof/(PREFIX+'ADMISSION_RAW_V1.zip');assert not archive.exists() and not archive.with_suffix('.json').exists()
    with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
        for name,path in sorted(files.items()):z.write(path,name)
    with zipfile.ZipFile(archive) as z:
        assert set(z.namelist())==set(members)
        for name,item in members.items():raw=z.read(name);assert len(raw)==item['bytes'] and hashlib.sha256(raw).hexdigest()==item['sha256']
    digest=hashlib.sha256(archive.read_bytes()).hexdigest()
    record=dict(status='ACTUAL_CANONICAL_IMPLICIT_FROST_ADMISSION_RAW_SEALED',canonical=CANONICAL,candidate=HEAD,
      ordered_parents=[PARENT,HEAD],full_tree=TREE,archive=archive.name,bytes=archive.stat().st_size,sha256=digest,members=members,
      sealer_source=git('rev-parse','HEAD'),actual_canonical_public_seconds=receipts[-1]['seconds'],
      model_executions=0,compiler_executions=0,neutral_scientific_archives_changed=False,
      functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)
    with archive.with_suffix('.json').open('x',encoding='utf-8') as f:json.dump(record,f,indent=2);f.write('\n')
    receipt=dict(status='ACTUAL_CANONICAL_BOUNDED_IMPLICIT_FROST_ADMISSION_VERIFIED',PR=1776,url='https://github.com/abhedwig-cell/SWAP5/pull/1776',
      previous_canonical=PARENT,qualified_head=HEAD,synthetic_merge=SYNTHETIC,actual_merge=CANONICAL,ordered_parents=[PARENT,HEAD],whole_qualified_tree=TREE,
      all_terminal_PR_checks=48,success=31,skipped=17,actual_candidate_public_seconds=receipts[0]['seconds'],actual_canonical_public_seconds=receipts[-1]['seconds'],
      actual_canonical_sparse_patterns=32,admission_archive_sha256=digest,implicit_Frost_admitted=True,
      neutral_qualification_and_10_archives_unchanged=True,public_compiler_executions=0,public_model_executions=0,
      AGE_admitted=False,broader_calendars_admitted=False,new_physical_state=False,whole_historical_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',
      global_family_and_gap_counts='UNKNOWN',RC3_changed=False,
      scope='Original fitted Mualem implicit daily water/CDE, ordinarySnow1 Frost1 hysteresis2 numericalheat2 primary effectiveSWDIVD1 bottom6, prescribed surface temperature, exact native2 original root diagnostic carry; no aquifer')
    with (proof/(PREFIX+'MERGE_RECEIPT_V1.json')).open('x',encoding='utf-8') as f:json.dump(receipt,f,indent=2);f.write('\n')
    print(record['status'],record['bytes'],digest,len(members),flush=True)


if __name__=='__main__':main()
