"""Actual explicit direct soil age source and complete restart pilot."""
import argparse
import json
from pathlib import Path
import struct
import subprocess
import sys
import time
import zipfile
import age_fixed as fixed
from age_runtime import own,output_values
from original_output_baseline import assignment
from age_direct_soil_source import metadata,magic

m=fixed.m;ROOT=fixed.ROOT


def fixture(path,kind,age):
    fixed.fixture(path,kind)
    p=path/'fixed-irrigation.irg';text=p.read_text();anchor='2002-01-05 24.0 0.0'
    assert text.count(anchor)==1
    text=text.replace(anchor,'2002-01-05 24.0 '+str(age),1)
    lines=text.splitlines();event=next(s for s in lines if s.startswith('2002-01-05'))
    fields=event.split();extra=fields.copy();extra[:3]=['2002-01-07','12.0','60.0']
    text=text.replace(event,event+'\n'+' '.join(extra));p.write_text(text)


def main():
    ap=argparse.ArgumentParser()
    for key in ('reference-work','output'):ap.add_argument('--'+key,type=Path,required=True)
    ap.add_argument('--kind',choices=('subsurface','subsurface-interval','surface','sprinkler'),required=True)
    ap.add_argument('--optimization',choices=('O0','O2'),required=True)
    ap.add_argument('--age-day',type=float,default=20.)
    a=ap.parse_args();a.output=a.output.resolve();a.output.mkdir();inputs=a.output/'input';fixture(inputs,a.kind,a.age_day)
    project=m.e.load(inputs,age_direct_soil_source=True);build=a.output/'build'
    q=dict(status='RUNNING',head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),kind=a.kind,optimization=a.optimization,policy=metadata(project),whole_scientific_equivalence='NOT_QUALIFIED',functional_completion='PARTIAL')
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',inputs,'--age-direct-soil-source','--reference-work',a.reference_work,'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',build]
        t=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=ROOT,text=True,capture_output=True,timeout=180)
        (a.output/'build.stdout').write_text(r.stdout);(a.output/'build.stderr').write_text(r.stderr);q['build']=dict(returncode=r.returncode,seconds=time.monotonic()-t);save();assert r.returncode==0,r.stderr
        full=a.output/'trajectory';q['trajectory'],data=m.trajectory(build,a.reference_work,project,full,10,{2,4,6,8,10},60);save()
        index=11 if a.kind.startswith('subsurface') else 5
        amount=data[4]['age_state_cm_day'][index]-data[3]['age_state_cm_day'][index]
        assert abs(amount-2.4*a.age_day)<1e-10,(amount,a.age_day)
        second=data[6]['age_state_cm_day'][index]-data[5]['age_state_cm_day'][index]
        assert abs(second-72.)<1e-10,second
        for row in data:
            assert len(row['age_state_cm_day'])==12 and len(row['age_ledger_cm_day'])==9
            assert abs(row['age_combined_residual_cm_day'])<=row['age_tolerance_cm_day']
        q['events_cm_day']=[amount,second];q['own']=[own(build,a.reference_work,project,full,data,s,e,a.output/('own-'+str(s))) for s,e in ((2,4),(4,8),(6,10))]
        q['output']=output_values(full,data);q['native']={}
        for day in (2,4,8,10):
            with zipfile.ZipFile(full/f'accepted-column-1-day-{day}.zip') as z:
                raw=z.read('macro.bin');assert raw[:8]==magic(project)
                h1,cumulative,h2=struct.unpack('<2id2i',raw[-24:])[:2],struct.unpack_from('<d',raw,-16)[0],struct.unpack_from('<2i',raw,-8)
                assert h1==h2==(1,34) and cumulative==data[day-1]['age_state_cm_day'][11]
                q['native'][str(day)]=dict(codec=raw[:8].decode(),direct_state_bytes=24,actual_cumulative_cm_day=cumulative)
        q['status']='DIRECT_SOIL_AGE_TEN_DAY_VARYING_SOURCE_COMPLETE_NATIVE_OUTPUT_PASS_NOT_ADMITTED'
        print(a.kind,a.optimization,q['status'],flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
