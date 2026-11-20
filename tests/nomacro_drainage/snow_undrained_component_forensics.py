"""Read actual original CDE cell probes without importing a renderer or model."""
import hashlib
import math
from pathlib import Path

from ordinary_pond_evidence import read,digest,require


def audit(root,provider):
    root=Path(root);q=read(root/'RESULT.json');sha=lambda raw:hashlib.sha256(raw).hexdigest()
    require(q['status']=='REAL_ORIGINAL_CDE_POSITIVE_TAIL_LOSS_AND_27_CORRECTED_CELL_CASES_PASS' and
        q['optimization'] in ('O0','O2') and q['model_periods']==0,'Original CDE component incomplete')
    require(q['original_source_sha256']==provider['provider_files']['build/swap-selected/solute.f90'],
        'Actual original CDE source differs')
    for item in q['actual_original_object_closure']:
        require(item['sha256']==provider['provider_files']['build/swap-obj/'+item['name']],
            'Original CDE component object differs')
    require(len(q['executions'])==2,'Actual CDE component denominator differs')
    sources={};observations={};literal={}
    for item in q['executions']:
        mode=item['mode'];require(mode in ('original','corrected') and mode not in sources,'Foreign component mode')
        sources[mode]=(root/(mode+'-'+mode+'.f90')).read_bytes()
        require(sha(sources[mode])==item['actual_source_sha256'] and item['returncode']==0 and not item['stderr'],
            'Actual whole CDE probe source/execution differs')
        exe=next((root/(mode+'-'+mode+s) for s in ('','.exe') if (root/(mode+'-'+mode+s)).is_file()),None)
        require(exe and digest(exe)==item['executable_sha256'],'Actual original CDE probe executable differs')
        compile=read(root/(mode+'-compile.json'));require(len(compile)==2 and all(c['returncode']==0 for c in compile),
            'Actual original CDE component compilation incomplete')
        require(all('-'+q['optimization'] in c['command'] and '-ffp-contract=off' in c['command'] and
            '-fcheck=all' in c['command'] for c in compile),'Actual CDE component compiler profile differs')
        rows=[line.split() for line in item['stdout'].splitlines() if line.startswith('ACTUAL_ORIGINAL_CDE_TINY_CELL ')]
        require(len(rows)==27 and {(int(r[1]),int(r[2])) for r in rows}=={(i,j) for i in range(1,10) for j in range(1,4)},
            'Actual CDE tiny-cell observations differ')
        require(all(len(r)==8 and all(math.isfinite(float(x)) for x in r[3:]) for r in rows),'Nonfinite CDE cell observation')
        observations[mode]=rows;literal[mode]=item['literal_cell_sha256']
    old=b'               if (cmsy(i) < vsmall) then';new=b'               if (cmsy(i) <= 0d0) then'
    require(sources['original'].count(old)==1 and sources['corrected'].count(new)==1 and
        sources['original'].replace(old,new,1)==sources['corrected'],
        'Actual complete CDE probe changes more than the single positive cutoff')
    removed=0
    for before,after in zip(observations['original'],observations['corrected']):
        require(before[:5]==after[:5],'CDE cell input was rebound')
        mass=float(before[3]);value=float(after[5]);roundoff=float(after[6]);concentration=float(after[7])
        if mass>0:
            require(value==mass and roundoff==0 and concentration>0,'Positive CDE mass was lost')
        if 0<mass<1e-15:
            require(float(before[5])==0 and float(before[6])>0,'Original positive-tail deletion not observed');removed+=1
        else:require(before==after,'Original unaffected CDE cell behavior changed')
    require(removed==12,'Original tiny positive-tail denominator differs')
    return dict(status='INDEPENDENT_ACTUAL_ORIGINAL_CDE_COMPONENT_SINGLE_PREDICATE_AND_27_CASES_PASS',
        optimization=q['optimization'],original_positive_tail_deletions=removed,actual_cell_cases=27,
        original_component_receipt_sha256=digest(root/'RESULT.json'),model_executions=0)
