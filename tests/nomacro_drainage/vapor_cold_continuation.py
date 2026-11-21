"""Finish only cold windows stopped by a checked Python descriptor transition."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'))
import original_output_matrix as thermal
from vapor_hydraulic_forensics import audit
from vapor_receipt_bridge import receipt_bridge


class Profile:
    def __init__(self,original,continuation):
        self.original=original;self.continuation=continuation
        self.old={v['start'] for v in json.loads((original/'RESULT.json').read_text())['own']}
    def __truediv__(self,name):
        if name=='RESULT.json':return self.continuation/name
        if str(name).startswith('own-') and int(str(name).split('/')[0][4:]) not in self.old:return self.continuation/name
        return self.original/name


def main():
    parser=argparse.ArgumentParser()
    for name in ('reference-work','profile','output'):parser.add_argument('--'+name,type=Path,required=True)
    a=parser.parse_args();a.output.mkdir();q=json.loads((a.profile/'RESULT.json').read_text())
    assert q['status']=='FAILED' and q['error']=="ValueError('Foreign CDE native receipt consistency policy; rebuild without rebinding')"
    assert q['trajectory']['days']==1096 and q['trajectory']['status']=='FULL_PASS'
    build=Path(q['build_root']);m=thermal.m
    project=m.e.load(q['input_root'],original_output=True,time_step_policy='original-adaptive-day-seed-v1')
    q['retained_full_profile']=str(a.profile);q['retained_original_RESULT_sha256']=m.sha(a.profile/'RESULT.json')
    q['continuation_producer']=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    q['status']='RUNNING_COLD_CONTINUATION';q.pop('error')
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    with receipt_bridge(build) as bridge:
        q['receipt_identity_bridge']=bridge
        data=m.rows(a.profile/'trajectory');passed={v['start'] for v in q['own']}
        for start,end in ((2,4),(19,23),(30,34),(199,201),(364,367),(530,532),(1094,1096)):
            if start in passed:continue
            q['own'].append(thermal.own(build,a.reference_work,project,a.profile/'trajectory',data,start,end,a.output/('own-'+str(start))));save()
    q['status']='CANDIDATE_ACTUAL_VAPOR_FAMILY_'+str(q['hydraulic_model'])+'_CDE_FULL_PASS_NOT_ADMITTED';save()
    result=audit(Profile(a.profile,a.output),a.reference_work)
    (a.output/'INDEPENDENT.json').write_text(json.dumps(result,indent=2)+'\n')
    assert m.sha(a.profile/'RESULT.json')==q['retained_original_RESULT_sha256']
    print(result['status'],result['days'],result['cold_windows'],'new_full_periods=0',flush=True)


if __name__=='__main__':main()
