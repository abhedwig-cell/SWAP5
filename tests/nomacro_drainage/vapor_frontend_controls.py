"""Keep active vapor bounded and historically ignored layer flags inactive."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
import experimental_project as e
from hydraulic_vapor import describe
from original_output import magic
from original_output_baseline import assignment


def main():
    parser=argparse.ArgumentParser()
    for name in ('evidence','output'):parser.add_argument('--'+name,type=Path,required=True)
    a=parser.parse_args();a.output.mkdir();checks=[]
    def load(path,original=True):return e.load(path,original_output=original,time_step_policy='original-adaptive-day-seed-v1')
    for path in sorted(a.evidence.glob('vapor-native3-*/RESULT.json')):
        q=json.loads(path.read_text())
        if q.get('phase')!='full' or q.get('kind') not in ('water','cde') or 'retained_full_profile' in q:continue
        project=load(q['input_root']);selected=describe(project)
        assert selected['models']==(q['layer_models']*2 if len(q['layer_models'])==1 else q['layer_models']) and selected['SWVAPOR']==q['vapor_flags']
        assert magic(project)==(b'S5HVC003' if q['kind']=='cde' else b'S5HVW003')
        checks.append(dict(role=path.parent.name,status='SUPPORTED_EXACT_INPUT_SCOPE',input_inventory=e.inventory(q['input_root'])))
    assert len(checks)==32
    initial=json.loads((a.evidence/'vapor-native3-8-water-full-O0-v1/RESULT.json').read_text())
    base=Path(initial['input_root'])
    mutations=[('SWVAPOR','2 1'),('SWVAPOR','-1 1'),('SWVAPOR','1'),('SWVAPOR','1 1 1'),('SWVAPOR','.TRUE. 1'),
        ('iHWCKmodel','8 12'),('iHWCKmodel','8 8 8'),('iHWCKmodel','8 X'),
        ('SWKIMPL',1),('SWSNOW',1),('SWFROST',1),('SWHYST',1),('SWDRA',2),('SWBOTB',1),
        ('SWBR',1),('SWMETDETAIL',1),('SWHEA',0),('SWCALT',1),('SWMACRO',1),('SWSOLU',2)]
    for index,(name,value) in enumerate(mutations):
        folder=a.output/('input-refused-'+str(index));shutil.copytree(base,folder)
        path=folder/'swap.swp';path.write_text(assignment(path.read_text(encoding='cp1252'),name,value),encoding='cp1252')
        try:load(folder)
        except ValueError as error:checks.append(dict(role=name+'='+str(value),status='REFUSED_BEFORE_BUILD',diagnostic=str(error),input_inventory=e.inventory(folder)))
        else:raise AssertionError('Unqualified active vapor accepted: '+name+'='+str(value))
    for label,models,flags in (('ignored-model1','1','1 1'),('ignored-model7-layer','7 8','1 0'),('all-vapor-off','8','0 0')):
        folder=a.output/('input-'+label);shutil.copytree(base,folder);path=folder/'swap.swp';text=path.read_text(encoding='cp1252')
        text=assignment(assignment(text,'iHWCKmodel',models),'SWVAPOR',flags);path.write_text(text,encoding='cp1252')
        project=load(folder);assert describe(project) is None and magic(project)==b'S5IOW001'
        checks.append(dict(role=label,status='HISTORICAL_INACTIVE_FLAGS_REMAIN_INACTIVE_HASH_BOUND',input_inventory=e.inventory(folder)))
    try:load(base,False)
    except ValueError as error:checks.append(dict(role='compatibility-output-active-vapor',status='REFUSED_BEFORE_BUILD',diagnostic=str(error)))
    else:raise AssertionError('Unqualified compatibility vapor accepted')
    q=dict(status='ACTUAL_VAPOR_FRONTEND_SUPPORTED_COHORT_BOUNDS_AND_HISTORICAL_INACTIVE_FLAGS_PASS',checks=checks,
        source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        compiler_executions=0,model_executions=0,public_admission=False)
    (a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(q['status'],len(checks))


if __name__=='__main__':main()
