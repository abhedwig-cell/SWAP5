"""Seal actual admitted groundwater clock receipts separately from neutral science."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[2]
CANONICAL='21e3fcba2604c7546013f961e0bebaea63e5717f'
HEAD='04273b09f87db954d238c11202e2a58abd5413c8'
PARENT='c22d6ec1c5ede56b93d7f38635e38e4c277b3f51'
TREE='a85e5b2cc8a2ce8d9c14e2aeae44f9abc41a1fde'


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--evidence',type=Path,required=True);args=p.parse_args()
    git=lambda *a:subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
    assert git('show','-s','--format=%P',CANONICAL).split()==[PARENT,HEAD]
    assert git('rev-parse',CANONICAL+'^{tree}')==git('rev-parse',HEAD+'^{tree}')==TREE
    labels=['CLEAN_CANDIDATE_PUBLIC_OWNER_V1','COMMITTED_SOURCE_NEGATIVE_V1',
            'COMMITTED_INHERITED_RAW_NEGATIVE_V1','ACTUAL_CANONICAL_PUBLIC_OWNER_V1']
    files={};receipts=[]
    for label in labels:
        stem='GROUNDWATER_CLOCK_'+label;q=json.loads((args.evidence/(stem+'.json')).read_text(encoding='utf-8'));receipts.append(q)
        assert q['before']==q['after'] and q['before']['status']=='' and q['model_executions']==0
        assert len(q['before']['sparse'])==24 and q['before']['sparse'][-1]=='/integration/f-ci/nomacro-complete01/GROUNDWATER_CDE_CLOCK_*'
        assert q['command'][-1]=='tests/hupsel51/verify_successor.py'
        out=(args.evidence/(stem+'.stdout.txt')).read_bytes();err=(args.evidence/(stem+'.stderr.txt')).read_bytes()
        assert (len(out),len(err))==(q['stdout_bytes'],q['stderr_bytes'])
        if q['expected_error']:assert q['returncode']!=0 and q['expected_error'] in err.decode('utf-8')
        else:
            assert q['returncode']==0 and not err and q['before']['tree']==TREE
            assert json.loads(out)['status']=='BOUNDED_GROUNDWATER_CDE_CLOCK_SOURCE_RAW_ADMISSION_PASS'
        for suffix in ('.json','.stdout.txt','.stderr.txt'):files[stem+suffix]=args.evidence/(stem+suffix)
    assert [r['before']['head'] for r in receipts]==[HEAD,'60de63a7a0a6e116e7deb91e6d72b9f09700ca55','a37baf9b902371dc787321ee18a9bf4787771de2',CANONICAL]
    checks=json.loads((args.evidence/'GROUNDWATER_CLOCK_PR1769_TERMINAL_CHECKS_V1.json').read_text())
    assert checks['headRevision']==HEAD and len(checks['checks'])==47 and not checks['hasMore'] and not checks['statuses']
    assert all(c['status']=='completed' and c['conclusion'] in ('success','skipped') for c in checks['checks'])
    for name in ('GROUNDWATER_CLOCK_PR1769_TERMINAL_CHECKS_V1.json','GROUNDWATER_CLOCK_PR1769_PREMERGE_V1.json',
                 'GROUNDWATER_CLOCK_PR1769_ACTUAL_MERGE_API_V1.json','GROUNDWATER_CLOCK_PR1769_ACTUAL_MERGE_TREE_V1.json',
                 'GROUNDWATER_CLOCK_PR1769_TERMINAL_UBUNTU_OWNER_V1.log',
                 'GROUNDWATER_CLOCK_CONTROLS_UBUNTU_O0_JOB_V1.log','GROUNDWATER_CLOCK_CONTROLS_UBUNTU_O2_JOB_V1.log'):
        files[name]=args.evidence/name
    inventory={name:dict(bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for name,p in files.items()}
    path=ROOT/'integration/f-ci/nomacro-complete01/GROUNDWATER_CDE_CLOCK_ADMISSION_RAW_V1.zip';record=path.with_suffix('.json')
    assert not path.exists() and not record.exists()
    with zipfile.ZipFile(path,'x',compression=zipfile.ZIP_DEFLATED) as z:
        for name,p in sorted(files.items()):z.write(p,name)
    q=dict(status='ACTUAL_CANONICAL_GROUNDWATER_CLOCK_ADMISSION_RAW_SEALED',canonical=CANONICAL,candidate=HEAD,full_tree=TREE,
           archive=path.name,bytes=path.stat().st_size,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),members=inventory,
           sealer_source=git('rev-parse','HEAD'),actual_canonical_public_seconds=receipts[-1]['elapsed_seconds'],
           model_executions=0,neutral_scientific_archives_changed=False,functional_completion='PARTIAL',
           whole_scientific_equivalence='NOT_QUALIFIED',global_counts='UNKNOWN',RC3_changed=False)
    with record.open('x',encoding='utf-8') as f:json.dump(q,f,indent=2)
    print(q['status'],q['bytes'],q['sha256'])


if __name__=='__main__':main()
