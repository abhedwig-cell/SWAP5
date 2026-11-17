"""Preserve admitted pulse compositions across the bounded chemical correction."""
import argparse
import difflib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('pulse',ROOT/'tests/irrigation_pulse/run.py')
pulse=importlib.util.module_from_spec(spec);spec.loader.exec_module(pulse)
m=pulse.m


def main():
    p=argparse.ArgumentParser()
    for name in ('reference-work','prior','output'):p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();out=a.output.resolve();out.mkdir()
    result=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),profiles={})
    def save():(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    save()
    try:
        for kind in ('water','chemical'):
            key=kind+'-surface-history';project=m.e.load(a.prior/'inputs'/key,time_step_policy=pulse.POLICY)
            for opt in ('O0','O2'):
                name=key+'-'+opt;build=out/(name+'-build');old=a.prior/(name+'-build')
                command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',m.e.MODEL,
                         '--experimental-project',str(project.input_directory),'--experimental-time-step-policy',pulse.POLICY,
                         '--reference-work',str(a.reference_work),'--build-only','--kernel-opt',opt,'--donor-opt',opt,'--output',str(build)]
                run=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=180)
                (out/(name+'.log')).write_text(run.stdout+run.stderr);assert run.returncode==0,run.stderr
                meta,_=m.validate_bundle(build,a.reference_work,project);prior=json.loads((old/'BUILD.json').read_text())
                current={path.name:m.sha(path) for path in build.glob('*.f90')}
                previous={path.name:m.sha(path) for path in old.glob('*.f90')}
                changed={path for path in current.keys()|previous.keys() if current.get(path)!=previous.get(path)}
                expected={'solute.f90','irrigation.f90','mod_subsurface_solute_source.f90'} if kind=='chemical' else set()
                assert changed==expected,(name,changed)
                for path in sorted(changed-{'mod_subsurface_solute_source.f90'}):
                    diff=''.join(difflib.unified_diff((old/path).read_text().splitlines(True),(build/path).read_text().splitlines(True),fromfile='admitted/'+path,tofile='corrected/'+path))
                    (out/(name+'-'+path+'.diff')).write_text(diff)
                closure=('donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library',
                         'kernel_sources','adapter','driver','lower_boundary_receipt','scheduled_pond_history','time_step_policy')
                for field in closure:assert meta['identity'].get(field)==prior['identity'].get(field),field
                assert meta['inputs']==prior['inputs']
                full=out/(name+'-prefix201');report,data=m.trajectory(build,a.reference_work,project,full,201,{4,6,199,201},30)
                assert m.physical(data)==m.physical(m.rows(a.prior/(name+'-full'))[:201])
                assert m.csvlines(full/'original/result_output.csv')==m.csvlines(a.prior/(name+'-full/original/result_output.csv'))[:203]
                report['own']=[m.own(build,a.reference_work,project,full,data,start,end,out/(name+'-own'+str(start))) for start,end in ((4,6),(199,201))]
                result['profiles'][name]=dict(changed_generated=sorted(changed),unchanged_provider_closure=list(closure),
                    inputs_exact=True,physical_csv_prefix_exact=True,days=201,prefix=report,
                    corrected_source_policy=meta['identity'].get('conserved_subsurface_solute'))
                save();print(name,'ACTUAL_PULSE_PREFIX_NATIVE_PASS',flush=True)
        result['status']='CORRECTED_CHEMICAL_SOURCE_PRESERVES_PULSE_PHYSICAL_CSV_NATIVE_PASS'
    except Exception as error:result.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
