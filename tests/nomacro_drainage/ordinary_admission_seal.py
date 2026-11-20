"""Seal actual ordinary canonical admission without changing neutral science."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[2]
CANONICAL='c22d6ec1c5ede56b93d7f38635e38e4c277b3f51'
HEAD='0fc5c51840dcb7ba1c2c82d5184041c9abec3ef8'
TREE='1d5fa7c449fd788bc10d67ba06ad176d59cbfbce'


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--evidence',type=Path,required=True);a=p.parse_args()
    proof=ROOT/'integration/f-ci/nomacro-complete01'
    git=lambda *v:subprocess.check_output(['git',*v],cwd=ROOT,text=True).strip()
    assert git('show','-s','--format=%P',CANONICAL).split()==['d785e2c3c415122b8e391d3979f1fbceb81ce5b5',HEAD]
    assert git('rev-parse',CANONICAL+'^{tree}')==git('rev-parse',HEAD+'^{tree}')==TREE
    labels=['ORDINARY_CLEAN_CANDIDATE_PUBLIC_OWNER_V1','ORDINARY_CLEAN_CANDIDATE_PUBLIC_OWNER_V2',
            'ORDINARY_ACTUAL_COMMITTED_SOURCE_NEGATIVE_V1','ORDINARY_ACTUAL_COMMITTED_INHERITED_RAW_NEGATIVE_V1',
            'ORDINARY_CLEAN_CANDIDATE_PUBLIC_OWNER_V3','ORDINARY_PROJECTION_ACTUAL_COMMITTED_SOURCE_NEGATIVE_V1',
            'ORDINARY_PROJECTION_ACTUAL_COMMITTED_INHERITED_RAW_NEGATIVE_V1','ORDINARY_ACTUAL_CANONICAL_PUBLIC_OWNER_V1']
    files={}
    for index,label in enumerate(labels):
        q=json.loads((a.evidence/(label+'.json')).read_text(encoding='utf-8'))
        assert q['before']==q['after'] and q['before']['status']=='' and q['model_executions']==0
        assert q['command'][-1]=='tests/hupsel51/verify_successor.py'
        stdout=(a.evidence/(label+'.stdout.txt')).read_bytes();stderr=(a.evidence/(label+'.stderr.txt')).read_bytes()
        assert len(stdout)==q['stdout_bytes'] and len(stderr)==q['stderr_bytes']
        if index==0:
            assert len(q['before']['sparse'])==22 and q['returncode']!=0 and b'FileNotFoundError' in stderr
        else:
            assert len(q['before']['sparse'])==23
            if q['expected_error']:assert q['returncode']!=0 and q['expected_error'] in stderr.decode('utf-8')
            else:assert q['returncode']==0 and not stderr and json.loads(stdout)['status']=='BOUNDED_ORDINARY_IMPLICIT_POND_SOURCE_RAW_ADMISSION_PASS'
        for suffix in ('.json','.stdout.txt','.stderr.txt'):files[label+suffix]=a.evidence/(label+suffix)
    actual=json.loads((a.evidence/(labels[-1]+'.json')).read_text());assert actual['before']['head']==CANONICAL and actual['before']['tree']==TREE
    checks=json.loads((a.evidence/'ORDINARY_PR1768_TERMINAL_CHECKS_V1.json').read_text())
    assert checks['headRevision']==HEAD and len(checks['checks'])==48 and not checks['hasMore']
    assert all(c['status']=='completed' and c['conclusion'] in ('success','skipped') for c in checks['checks'])
    for name in ('ORDINARY_PR1768_TERMINAL_CHECKS_V1.json','ORDINARY_PR1768_PREMERGE_IDENTITY_V1.json',
                 'ORDINARY_PR1768_ACTUAL_MERGE_IDENTITY_V1.json','ORDINARY_PR1768_INITIAL_WORKFLOW_PROJECTION_FAILURE_V1.log',
                 'ORDINARY_PR1768_TERMINAL_UBUNTU_JOB_V1.log'):
        files[name]=a.evidence/name
    inventory={n:dict(bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for n,p in files.items()}
    path=proof/'ORDINARY_IMPLICIT_POND_ADMISSION_RAW_V1.zip';record=path.with_suffix('.json');assert not path.exists() and not record.exists()
    with zipfile.ZipFile(path,'x',compression=zipfile.ZIP_DEFLATED) as z:
        for name,file in sorted(files.items()):z.write(file,name)
    q=dict(status='ACTUAL_CANONICAL_ORDINARY_ADMISSION_RAW_SEALED',canonical=CANONICAL,candidate=HEAD,full_tree=TREE,
           archive=path.name,bytes=path.stat().st_size,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),members=inventory,
           sealer_source=git('rev-parse','HEAD'),actual_canonical_public_seconds=actual['elapsed_seconds'],
           model_executions=0,neutral_scientific_archives_changed=False,functional_completion='PARTIAL',
           whole_scientific_equivalence='NOT_QUALIFIED',global_counts='UNKNOWN',RC3_changed=False)
    record.write_text(json.dumps(q,indent=2)+'\n');print(q['status'],q['bytes'],q['sha256'])


if __name__=='__main__':main()
