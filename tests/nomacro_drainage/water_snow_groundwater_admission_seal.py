"""Seal the actual water/Snow groundwater canonical observation without altering neutral proof."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[2]
CANONICAL='b546801eaf24a01ee4dc457eb857ef46e6b61c30'
HEAD='54afcc09cb80226fb46a77e169d38e7d0ca2390b'
PARENT='9c447f419d11743efe7464d3c8542ac1bc8fea4a'
TREE='79f3c2d7f962a91d934f5a0a2e95fd649f501ea9'


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--evidence',type=Path,required=True);a=p.parse_args()
    git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
    assert git('show','-s','--format=%P',CANONICAL).split()==[PARENT,HEAD]
    assert git('rev-parse',CANONICAL+'^{tree}')==git('rev-parse',HEAD+'^{tree}')==TREE
    files={};receipts=[]
    labels=('CLEAN_CANDIDATE_PUBLIC_OWNER_V1','COMMITTED_SOURCE_NEGATIVE_V1',
        'COMMITTED_INHERITED_NEGATIVE_V1','ACTUAL_CANONICAL_PUBLIC_OWNER_V1')
    heads=(HEAD,'9d30753ce2b36a7afeadf04102010da03c2a6eba','c0b29dca114bc87665f7402933975b92f52b0bbe',CANONICAL)
    for label,expected in zip(labels,heads):
        stem='WATER_SNOW_GROUNDWATER_'+label;q=json.loads((a.evidence/(stem+'.json')).read_text(encoding='utf-8'));receipts.append(q)
        assert q['before']==q['after'] and q['before']['head']==expected and q['before']['status']=='' and q['model_executions']==0
        assert len(q['before']['sparse'])==28 and q['before']['sparse'][-1]=='/integration/f-ci/nomacro-complete01/WATER_SNOW_GROUNDWATER_*'
        assert q['command'][-1]=='tests/hupsel51/verify_successor.py'
        stdout=(a.evidence/(stem+'.stdout.txt')).read_bytes();stderr=(a.evidence/(stem+'.stderr.txt')).read_bytes()
        assert (len(stdout),len(stderr))==(q['stdout_bytes'],q['stderr_bytes'])
        if q.get('expected_refusal'):assert q['returncode']!=0 and q['expected_refusal'] in stderr.decode('utf-8')
        else:assert q['returncode']==0 and not stderr and q['before']['tree']==TREE and json.loads(stdout)['status']=='BOUNDED_WATER_SNOW_GROUNDWATER_SOURCE_RAW_ADMISSION_PASS'
        for suffix in ('.json','.stdout.txt','.stderr.txt'):files[stem+suffix]=a.evidence/(stem+suffix)
    checks=json.loads((a.evidence/'WATER_SNOW_GROUNDWATER_PR1773_TERMINAL_CHECKS_V1.json').read_text())
    assert checks['headRevision']==HEAD and len(checks['checks'])==47 and not checks['hasMore'] and not checks['statuses']
    assert all(c['status']=='completed' and c['conclusion'] in ('success','skipped') for c in checks['checks'])
    pre=json.loads((a.evidence/'WATER_SNOW_GROUNDWATER_PREMERGE_V1.json').read_text())
    assert pre['ordered_parents']==[PARENT,HEAD] and pre['full_tree']==TREE and git('rev-parse',pre['synthetic']+'^{tree}')==TREE
    for name in ('WATER_SNOW_GROUNDWATER_PR1773_TERMINAL_CHECKS_V1.json','WATER_SNOW_GROUNDWATER_PREMERGE_V1.json',
        'WATER_SNOW_GROUNDWATER_PR1773_PREMERGE_API_V1.json','WATER_SNOW_GROUNDWATER_PR1773_PREMERGE_API_V2.json','WATER_SNOW_GROUNDWATER_PREMERGE_CANONICAL_API_V1.json',
        'WATER_SNOW_GROUNDWATER_PR1773_MERGE_API_V1.json','WATER_SNOW_GROUNDWATER_ACTUAL_MERGE_TREE_API_V1.json',
        'WATER_SNOW_GROUNDWATER_PR1773_MODULAR_FEEDBACK_TERMINAL_V1.log','WATER_SNOW_GROUNDWATER_PR1773_ORIGINAL_READER_TERMINAL_V1.log',
        'water-snow-groundwater-public-observe-v1.py'):files[name]=a.evidence/name
    for role in ('MODULAR_FEEDBACK','ORIGINAL_READER'):
        assert 'BOUNDED_WATER_SNOW_GROUNDWATER_SOURCE_RAW_ADMISSION_PASS' in files[f'WATER_SNOW_GROUNDWATER_PR1773_{role}_TERMINAL_V1.log'].read_text(encoding='utf-8')
    members={n:dict(bytes=f.stat().st_size,sha256=hashlib.sha256(f.read_bytes()).hexdigest()) for n,f in files.items()}
    proof=ROOT/'integration/f-ci/nomacro-complete01';path=proof/'WATER_SNOW_GROUNDWATER_ADMISSION_RAW_V1.zip'
    assert not path.exists() and not path.with_suffix('.json').exists()
    with zipfile.ZipFile(path,'x',compression=zipfile.ZIP_DEFLATED) as z:
        for name,file in sorted(files.items()):z.write(file,name)
    with zipfile.ZipFile(path) as z:
        assert set(z.namelist())==set(members)
        for n,item in members.items():raw=z.read(n);assert len(raw)==item['bytes'] and hashlib.sha256(raw).hexdigest()==item['sha256']
    sha=hashlib.sha256(path.read_bytes()).hexdigest()
    q=dict(status='ACTUAL_CANONICAL_WATER_SNOW_GROUNDWATER_ADMISSION_RAW_SEALED',canonical=CANONICAL,candidate=HEAD,
        ordered_parents=[PARENT,HEAD],full_tree=TREE,archive=path.name,bytes=path.stat().st_size,sha256=sha,members=members,
        sealer_source=git('rev-parse','HEAD'),actual_canonical_public_seconds=receipts[-1]['elapsed_seconds'],
        model_executions=0,neutral_scientific_archives_changed=False,functional_completion='PARTIAL',
        whole_scientific_equivalence='NOT_QUALIFIED',global_counts='UNKNOWN',RC3_changed=False)
    with path.with_suffix('.json').open('x',encoding='utf-8') as f:json.dump(q,f,indent=2);f.write('\n')
    receipt=dict(status='BOUNDED_WATER_SNOW_GROUNDWATER_ACTUAL_CANONICAL_ADMITTED',pr='https://github.com/abhedwig-cell/SWAP5/pull/1773',
        canonical=CANONICAL,candidate=HEAD,ordered_parents=[PARENT,HEAD],full_tree=TREE,
        registered_public=receipts[-1],admission_archive_sha256=sha,ci_terminal=47,ci_success=30,ci_skipped=17,
        actual_canonical_admitted=True,functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',RC3_changed=False)
    with (proof/'WATER_SNOW_GROUNDWATER_MERGE_RECEIPT_V1.json').open('x',encoding='utf-8') as f:json.dump(receipt,f,indent=2);f.write('\n')
    print(q['status'],q['bytes'],sha)


if __name__=='__main__':main()
