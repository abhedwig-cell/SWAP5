"""Retain named existing original inputs and one positive CDE configuration."""
import argparse
import hashlib
import json
import re
from pathlib import Path
import subprocess
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as original
from original_output_baseline import assignment

CASES=(('water-explicit-flux-daily',0,0,0,5,False,'daily',1,0,4),
    ('water-implicit-head-clock',0,1,2,8,False,'periodic',3,1,4),
    ('water-implicit-flux-step',0,1,1,5,True,'explicit',3,0,6),
    ('water-explicit-head-interval',0,0,2,8,False,'monthly',1,0,3),
    ('cde-explicit-flux-interval',1,0,0,5,False,'monthly',1,0,4),
    ('cde-implicit-head-clock',1,1,1,8,False,'periodic',3,1,4),
    ('cde-implicit-flux-step',1,1,2,5,True,'explicit',3,0,6),
    ('cde-explicit-head-daily',1,0,1,8,False,'daily',1,0,3),
    ('cde-implicit-head-clock-positive',1,1,1,8,False,'periodic',3,1,4))


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir()
    q=dict(status='ORIGINAL_INPUT_CONFIGURATIONS_NOT_SCIENTIFICALLY_QUALIFIED',cases={},
        source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=original.ROOT,text=True).strip())
    for label,solute,implicit,hys,bottom,step,mode,npd,reset,mean in CASES:
        target=a.output/label
        original.fixture(target,solute,hys,bottom,step,mean,mode,3,reset,npd)
        path=target/'swap.swp';text=path.read_text(encoding='cp1252')
        for key,value in [('SWSNOW',1),('SWDRA',0),('SWKIMPL',implicit),('SWHEA',1),('SWCALT',2)]:text=assignment(text,key,value)
        if label.endswith('-positive'):
            text,count=re.subn(r'(?mi)^([ \t]*CPRE[ \t]*=[ \t]*)0\.0([ \t]*!)',r'\g<1>0.01\2',text)
            assert count==1
        path.write_text(text,encoding='cp1252')
        q['cases'][label]=dict(input_root=str(target),parameters=dict(solute=solute,implicit=implicit,hysteresis=hys,
            bottom=bottom,step=step,mode=mode,npd=npd,reset=reset,kmean=mean),
            inventory={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in target.iterdir() if p.is_file()})
    (a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')


if __name__=='__main__':main()
