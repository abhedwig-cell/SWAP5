"""Actual first-day and true terminal-day gifts with cold native continuation."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import direct_soil_age_matrix as matrix
from original_output_baseline import assignment

m=matrix.m


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output=a.output.resolve();a.output.mkdir();q=dict(status='RUNNING',profiles={})
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    try:
        for opt in ('O0','O2'):
            out=a.output/opt;out.mkdir();inputs=out/'input';matrix.fixture(inputs,'subsurface',20.,'daily',1,0);p=inputs/'swap.swp';p.write_text(assignment(p.read_text(encoding='cp1252'),'TEND','2002-01-10'),encoding='cp1252');(inputs/'fixed-irrigation.irg').write_text('IRDATE IRDEPTH IRCONC IRTYPE IRRATE\n2002-01-01 24.0 20.0 2 12.0\n2002-01-10 12.0 60.0 2 12.0\nIR_Z = -30.0\n')
            project=m.e.load(inputs,age_direct_soil_source=True);assert project.last_day==10;build=out/'build';cmd=[sys.executable,'-B',str(matrix.ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(inputs),'--age-direct-soil-source','--reference-work',str(a.reference_work),'--build-only','--donor-opt',opt,'--kernel-opt',opt,'--output',str(build)]
            r=subprocess.run(cmd,cwd=matrix.ROOT,capture_output=True,text=True,timeout=180);(out/'build.stdout').write_text(r.stdout);(out/'build.stderr').write_text(r.stderr);assert r.returncode==0,r.stderr
            full=out/'trajectory';report,data=m.trajectory(build,a.reference_work,project,full,10,{2,4,6,8,10},45)
            assert abs(data[0]['age_state_cm_day'][11]-48.)<=1e-10 and abs(data[-1]['age_state_cm_day'][11]-120.)<=1e-10
            windows=[matrix.own(build,a.reference_work,project,full,data,s,e,out/('own-'+str(s))) for s,e in ((2,4),(4,8),(6,10))]
            q['profiles'][opt]=dict(actual_build=json.loads((build/'BUILD.json').read_text()),trajectory=report,first_day_source_cm_day=data[0]['age_state_cm_day'][11],terminal_cumulative_source_cm_day=data[-1]['age_state_cm_day'][11],own=windows);save();print(opt,'FIRST_AND_TRUE_LAST_DAY_DIRECT_SOIL_AGE_NATIVE_PASS',flush=True)
        q['status']='FIRST_AND_TRUE_TERMINAL_DAY_DIRECT_SOIL_AGE_GIFTS_O0_O2_COMPLETE_NATIVE_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
