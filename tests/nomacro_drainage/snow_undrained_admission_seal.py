"""Seal actual canonical admission separately from immutable neutral Snow science."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[2]
HEAD='2c392b437bc07c9fde50b35da9e741fedc2846f1'
PARENT='b546801eaf24a01ee4dc457eb857ef46e6b61c30'
TREE='327360a86900e12cc2b08b98e526402455a00401'
PREFIX='SNOW_UNDRAINED_'


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--evidence',type=Path,required=True);p.add_argument('--canonical',required=True);a=p.parse_args()
    git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
    assert git('show','-s','--format=%P',a.canonical).split()==[PARENT,HEAD]
    assert git('rev-parse',a.canonical+'^{tree}')==git('rev-parse',HEAD+'^{tree}')==TREE
    files={};receipts=[]
    labels=('CLEAN_CANDIDATE_PUBLIC_OWNER_V1','COMMITTED_SOURCE_NEGATIVE_V1',
        'COMMITTED_INHERITED_NEGATIVE_V1','ACTUAL_CANONICAL_PUBLIC_OWNER_V1')
    heads=(HEAD,'01517aacc63b1861c78fb105690b9d4b15b9216e','80cd763c790c5b222336b055949f46cde284fb9e',a.canonical)
    errors={1:'Actual ordinary Snow undrained compiler source differs from qualified runtime',2:'Inherited water Snow groundwater admission changed'}
    for index,(label,expected) in enumerate(zip(labels,heads)):
        stem=PREFIX+label;q=json.loads((a.evidence/(stem+'.json')).read_text(encoding='utf-8'));receipts.append(q)
        assert q['before']==q['after'] and q['before']['head']==expected and q['before']['status']==''
        assert q['model_executions']==q['compiler_executions']==0 and q['command'][-1]=='tests/hupsel51/verify_successor.py'
        assert len(q['before']['sparse'])==29 and q['before']['sparse'][-1]=='/integration/f-ci/nomacro-complete01/SNOW_UNDRAINED_*'
        stdout=(a.evidence/(stem+'.stdout.txt')).read_bytes();stderr=(a.evidence/(stem+'.stderr.txt')).read_bytes()
        if index in errors:assert q['returncode']!=0 and errors[index] in stderr.decode('utf-8')
        else:assert q['returncode']==0 and not stderr and q['before']['tree']==TREE and json.loads(stdout)['status']=='BOUNDED_SNOW_UNDRAINED_SOURCE_RAW_ADMISSION_PASS'
        for suffix in ('.json','.stdout.txt','.stderr.txt'):files[stem+suffix]=a.evidence/(stem+suffix)
    assert git('diff','--name-only',HEAD,heads[1])=='app/hybrid_water/snow_undrained_build.py'
    assert git('diff','--name-only',HEAD,heads[2])=='integration/f-ci/nomacro-complete01/WATER_SNOW_GROUNDWATER_ADMISSION_RAW_V1.zip'
    load=lambda name:json.loads((a.evidence/(PREFIX+name)).read_text(encoding='utf-8'))
    checks=load('PR1774_TERMINAL_CHECKS_V1.json')
    assert checks['headRevision']==HEAD and len(checks['checks'])==47 and not checks['hasMore'] and not checks['statuses']
    assert all(c['status']=='completed' and c['conclusion'] in ('success','skipped') for c in checks['checks'])
    pre=load('PREMERGE_V1.json');assert pre['ordered_parents']==[PARENT,HEAD] and pre['full_tree']==TREE
    assert git('show','-s','--format=%P',pre['synthetic']).split()==[PARENT,HEAD] and git('rev-parse',pre['synthetic']+'^{tree}')==TREE
    api=load('PR1774_PREMERGE_API_V1.json');assert api['head']['sha']==HEAD and api['base']['sha']==PARENT and api['mergeable'] is True
    assert api['state']=='open' and api['merge_commit_sha']==pre['synthetic']
    assert load('PREMERGE_CANONICAL_API_V1.json')['object']['sha']==PARENT
    merged=load('PR1774_MERGE_API_V1.json');assert merged['merged'] is True and merged['sha']==a.canonical
    actual=load('ACTUAL_MERGE_TREE_API_V1.json');assert actual['sha']==a.canonical and actual['tree']['sha']==TREE
    assert [v['sha'] for v in actual['parents']]==[PARENT,HEAD]
    names=('PR1774_TERMINAL_CHECKS_V1.json','PREMERGE_V1.json','PR1774_PREMERGE_API_V1.json',
        'PREMERGE_CANONICAL_API_V1.json','PR1774_SYNTHETIC_MERGE_API_V1.json',
        'PR1774_MERGE_API_V1.json','ACTUAL_MERGE_TREE_API_V1.json',
        'PR1774_MODULAR_FEEDBACK_TERMINAL_V1.log','PR1774_ORIGINAL_READER_TERMINAL_V1.log','PUBLIC_OBSERVE_V1.py')
    for name in names:files[PREFIX+name]=a.evidence/(PREFIX+name)
    for role in ('MODULAR_FEEDBACK','ORIGINAL_READER'):
        assert 'BOUNDED_SNOW_UNDRAINED_SOURCE_RAW_ADMISSION_PASS' in files[PREFIX+f'PR1774_{role}_TERMINAL_V1.log'].read_text(encoding='utf-8')
    members={n:dict(bytes=f.stat().st_size,sha256=hashlib.sha256(f.read_bytes()).hexdigest()) for n,f in files.items()}
    proof=ROOT/'integration/f-ci/nomacro-complete01';path=proof/(PREFIX+'ADMISSION_RAW_V1.zip')
    assert not path.exists() and not path.with_suffix('.json').exists()
    with zipfile.ZipFile(path,'x',compression=zipfile.ZIP_DEFLATED) as z:
        for name,file in sorted(files.items()):z.write(file,name)
    with zipfile.ZipFile(path) as z:
        assert set(z.namelist())==set(members)
        for name,item in members.items():
            raw=z.read(name);assert len(raw)==item['bytes'] and hashlib.sha256(raw).hexdigest()==item['sha256']
    sha=hashlib.sha256(path.read_bytes()).hexdigest()
    q=dict(status='ACTUAL_CANONICAL_SNOW_UNDRAINED_ADMISSION_RAW_SEALED',canonical=a.canonical,candidate=HEAD,
        ordered_parents=[PARENT,HEAD],full_tree=TREE,archive=path.name,bytes=path.stat().st_size,sha256=sha,members=members,
        sealer_source=git('rev-parse','HEAD'),actual_canonical_public_seconds=receipts[-1]['seconds'],
        model_executions=0,neutral_scientific_archives_changed=False,functional_completion='PARTIAL',
        whole_scientific_equivalence='NOT_QUALIFIED',global_counts='UNKNOWN',RC3_changed=False)
    with path.with_suffix('.json').open('x',encoding='utf-8') as f:json.dump(q,f,indent=2);f.write('\n')
    receipt=dict(status='BOUNDED_SNOW_UNDRAINED_ACTUAL_CANONICAL_ADMITTED',pr='https://github.com/abhedwig-cell/SWAP5/pull/1774',
        canonical=a.canonical,candidate=HEAD,ordered_parents=[PARENT,HEAD],full_tree=TREE,registered_public=receipts[-1],
        admission_archive_sha256=sha,ci_terminal=len(checks['checks']),ci_success=sum(c['conclusion']=='success' for c in checks['checks']),
        ci_skipped=sum(c['conclusion']=='skipped' for c in checks['checks']),actual_canonical_admitted=True,
        functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',RC3_changed=False)
    with (proof/(PREFIX+'MERGE_RECEIPT_V1.json')).open('x',encoding='utf-8') as f:json.dump(receipt,f,indent=2);f.write('\n')
    print(q['status'],q['bytes'],sha)


if __name__=='__main__':main()
