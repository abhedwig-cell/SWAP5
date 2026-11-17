"""Actual young-water age fixed-input, native and original-reference controls."""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys
import time
import age_runtime as age
from age_reference import fixture as original_fixture

m=age.m
ROOT=age.ROOT
from fixed_irrigation_cases import create


def fixture(path,kind,inline=False,initial=100.):
    create(path,'water-file-'+kind,inline=inline)
    control=path/'swap.swp';text=control.read_text(encoding='cp1252')
    for key,value in dict(SWSOLU=2,SWBR=0,SWSNOW=0,SWMONTH=0,INLIST_CSV="'WATBAL,GWL'").items():
        text,n=re.subn(r'(?mi)^([ \t]*'+key+r'[ \t]*=)[^\r\n!]*',lambda match:match[1]+' '+str(value),text);assert n==1,key
    text+='\nAGEMLTB =\n -10.0 '+repr(initial)+'\n -95.0 '+repr(initial)+'\n* End of table\nNUM_DECIMALS = 12\n'
    # The original age boundary contract is young water, not a chemical IRCONC.
    if inline:text=text.replace('2002-01-05 24.0 20.0','2002-01-05 24.0 0.0')
    else:
        p=path/'fixed-irrigation.irg';body=p.read_text();assert '2002-01-05 24.0 20.0' in body;p.write_text(body.replace('2002-01-05 24.0 20.0','2002-01-05 24.0 0.0'))
    control.write_text(text,encoding='cp1252')
    return path


def main():
    p=argparse.ArgumentParser()
    for name in ('reference-work','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--phase',choices=('short','full'),required=True);a=p.parse_args()
    if a.phase=='short':a.output.mkdir();(a.output/'inputs').mkdir()
    record=a.output/'RESULT.json';q=json.loads(record.read_text()) if record.exists() else dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),profiles={},whole_scientific_equivalence='NOT_QUALIFIED',water_guard_cm=1e-10,chemical_mass_guard_changed=False)
    def save():record.write_text(json.dumps(q,indent=2)+'\n')
    try:
        for kind in ('sprinkler','surface','subsurface','subsurface-interval'):
            inputs=a.output/'inputs'/kind
            if a.phase=='short':fixture(inputs,kind)
            project=m.e.load(inputs)
            for opt in ('O0','O2'):
                name=kind+'-'+opt;build=a.output/(name+'-build');r=q['profiles'].setdefault(name,{})
                if a.phase=='short':
                    cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(inputs),'--reference-work',str(a.reference_work),'--build-only','--donor-opt',opt,'--kernel-opt',opt,'--output',str(build)]
                    t=time.monotonic();run=subprocess.run(cmd,capture_output=True,text=True,timeout=180);(a.output/(name+'-build.log')).write_text(run.stdout+run.stderr);r['build_seconds']=time.monotonic()-t;save();assert run.returncode==0,run.stderr
                    short=a.output/(name+'-short');r['short'],data=m.trajectory(build,a.reference_work,project,short,8,{2,4,6,8},30)
                    r['short']['own']=age.own(build,a.reference_work,project,short,data,4,6,a.output/(name+'-short-own'))
                    r['short']['effluent']=age.output_values(short,data)
                    assert all(row['age_state_cm_day'][5]==0 for row in data),'nonzero age in young-water inputs'
                else:
                    full=a.output/(name+'-full');r['full'],data=m.trajectory(build,a.reference_work,project,full,1096,{2,4,6,199,201,365,367,530,532,1096},90)
                    r['full']['own']=[age.own(build,a.reference_work,project,full,data,s,e,a.output/(name+'-own'+str(s))) for s,e in ((2,4),(4,6),(199,201),(365,367),(530,532))]
                    r['full']['effluent']=age.output_values(full,data)
                    assert all(row['age_state_cm_day'][5]==0 for row in data),'nonzero age in young-water inputs'
                    r['maximum_age_tolerance_fraction']=max(abs(row[key])/row['age_tolerance_cm_day'] for row in data for key in ('age_soil_residual_cm_day','age_pond_residual_cm_day','age_combined_residual_cm_day'))
                    assert r['maximum_age_tolerance_fraction']<=1
                save();print(name,a.phase,'AGE_FIXED_SOURCE_STATE_OUTPUT_PASS',flush=True)
        q['status']='AGE_FIXED_'+a.phase.upper()+'_O0_O2_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
