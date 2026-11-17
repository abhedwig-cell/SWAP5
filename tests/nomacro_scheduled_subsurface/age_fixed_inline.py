"""Real file/inline closure/native comparison and zero-initial-age controls."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time
import zipfile
import age_fixed as f

m=f.m


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','evidence','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();(a.output/'inputs').mkdir();result=dict(status='RUNNING',profiles={},zero_initial={})
    def save():(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    def build_and_run(name,inputs,opt):
        project=m.e.load(inputs);build=a.output/(name+'-build')
        cmd=[sys.executable,'-B',str(f.ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(inputs),'--reference-work',str(a.reference_work),'--build-only','--donor-opt',opt,'--kernel-opt',opt,'--output',str(build)]
        t=time.monotonic();r=subprocess.run(cmd,capture_output=True,text=True,timeout=180);(a.output/(name+'.log')).write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr
        out=a.output/(name+'-short');report,data=m.trajectory(build,a.reference_work,project,out,8,{2,4,6,8},30)
        report['own']=f.age.own(build,a.reference_work,project,out,data,4,6,a.output/(name+'-own'))
        report['effluent']=f.age.output_values(out,data)
        assert abs(data[4]['external_flux_cm'][3]+data[4]['external_flux_cm'][5]-2.4)<1e-11
        assert all(row['age_state_cm_day'][5]==0 for row in data)
        report['build_and_model_seconds']=time.monotonic()-t
        return build,out,data,report
    try:
        for kind in ('sprinkler','surface','subsurface','subsurface-interval'):
            inputs=f.fixture(a.output/'inputs'/kind,kind,inline=True)
            for opt in ('O0','O2'):
                name=kind+'-'+opt;build,out,data,report=build_and_run(name,inputs,opt)
                old=a.evidence/(name+'-build');oldrun=a.evidence/(name+'-short')
                assert {p.name:m.sha(p) for p in build.glob('*.f90')}=={p.name:m.sha(p) for p in old.glob('*.f90')}
                newmeta,_=m.validate_bundle(build,a.reference_work,m.e.load(inputs));oldmeta=json.loads((old/'BUILD.json').read_text())
                for field in ('donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library','kernel_sources','conserved_original_age','original_age_fixed_irrigation'):
                    assert newmeta['identity'][field]==oldmeta['identity'][field],field
                assert m.physical(data)==m.physical(m.rows(oldrun))
                for p in (out/'original').glob('*.csv'):assert m.csvlines(p)==m.csvlines(oldrun/'original'/p.name)
                for day in (2,4,6,8):
                    with zipfile.ZipFile(out/f'accepted-column-1-day-{day}.zip') as new,zipfile.ZipFile(oldrun/f'accepted-column-1-day-{day}.zip') as oldzip:
                        assert all(new.read(p)==oldzip.read(p) for p in ('result.end','macro.bin'))
                result['profiles'][name]=dict(generated_closure_exact=True,physical_all_csv_and_four_native_payloads_exact=True,own=report);save();print(name,'FILE_INLINE_PHYSICAL_NATIVE_EXACT',flush=True)
        inputs=f.fixture(a.output/'inputs'/'zero-surface','surface',initial=0.)
        for opt in ('O0','O2'):
            _,_,_,report=build_and_run('zero-'+opt,inputs,opt);result['zero_initial'][opt]=report;save();print('zero',opt,'ACTIVE_NATIVE_PASS',flush=True)
        result['status']='AGE_FIXED_FILE_INLINE_O0_O2_EXACT_AND_ZERO_AGE_SHORT_NATIVE_PASS'
    except Exception as error:result.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
