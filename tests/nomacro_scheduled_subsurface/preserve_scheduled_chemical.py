"""Fresh native controls plus exact emitted closure for unchanged admitted cases."""
import argparse
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('scheduled_chem',Path(__file__).with_name('chemical_scheduled.py'))
q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
m=q.m


def main():
    p=argparse.ArgumentParser()
    for name in ('evidence-root','reference-work','pulse-reference','pulse-prior','output'):p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();out=a.output.resolve();out.mkdir();e=a.evidence_root
    specs=[]
    for opt in ('O0','O2'):
        for name,folder,last,windows in [('fixed-point','chemical-fixed-point-full',8,[(2,4),(4,6)]),('scheduled-water','chemical-preserve-water-point',5,[(2,4)])]:
            prior=e/folder;source=e/'chemical-fixed-point-short' if name=='fixed-point' else prior
            specs.append((name+'-'+opt,m.e.load(source/'input'),a.reference_work,source/(opt+'-build'),prior/(opt+'-full'),opt,last,windows))
    for name,project in [('grass',m.h.GRASSGROWTH),('hupsel',m.h.HUPSEL),('salt',m.h.SALTFARM)]:
        prior=e/'chemical-current-named'/name
        specs.append((name,project,a.reference_work,prior/'build',prior/'full','O2',4,[(2,4)]))
    from irrigation_pulse_time import POLICY
    for kind in ('water','chemical'):
        name=kind+'-surface-history';project=m.e.load(a.pulse_prior/'inputs'/name,time_step_policy=POLICY)
        prior=e/'chemical-preserve-pulse'
        specs.append(('pulse-'+kind,project,a.pulse_reference,prior/(name+'-O2-build'),prior/(name+'-O2-prefix201'),'O2',201,[(4,6),(199,201)]))
    result=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),profiles={},
                unchanged_full_periods='NOT_REPEATED_EXACT_EMITTED_SOURCE_PROVIDER_INPUT_AND_FRESH_NATIVE_PREFIX_CONTROLS')
    def save():(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    try:
        for name,project,reference,old,oldfull,opt,last,windows in specs:
            build=out/(name+'-build')
            command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,
                     '--reference-work',str(reference),'--build-only','--kernel-opt',opt,'--output',str(build)]
            if project.input_directory:command+=['--experimental-project',project.input_directory,'--donor-opt',opt,'--experimental-time-step-policy',project.time_step_policy]
            else:command+=['--no-macro-release']
            run=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=180)
            (out/(name+'.log')).write_text(run.stdout+run.stderr);assert run.returncode==0,run.stderr
            meta,_=m.validate_bundle(build,reference,project);prior=json.loads((old/'BUILD.json').read_text())
            generated=lambda path:{f.name:m.sha(f) for f in path.glob('*.f90')}
            assert generated(build)==generated(old),(name,'generated source drift')
            fields=('donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library','kernel_sources','adapter','driver')
            for field in fields:assert meta['identity'][field]==prior['identity'][field],(name,field)
            assert meta['inputs']==prior['inputs'] and 'conserved_scheduled_subsurface_solute' not in meta['identity']
            full=out/(name+'-prefix');cuts={v for window in windows for v in window}
            report,data=m.trajectory(build,reference,project,full,last,cuts,30)
            assert m.physical(data)==m.physical(m.rows(oldfull)[:last])
            assert m.csvlines(full/'original/result_output.csv')==m.csvlines(oldfull/'original/result_output.csv')[:last+2]
            report['own']=[m.own(build,reference,project,full,data,start,end,out/(name+'-own'+str(start))) for start,end in windows]
            result['profiles'][name]=dict(all_generated_sources_exact=True,provider_flags_inputs_exact=True,
                old_full_reference=str(oldfull),physical_csv_prefix_exact=True,exact_current_source_binding=True,prefix=report)
            save();print(name,'EMITTED_CLOSURE_AND_NATIVE_PREFIX_EXACT',flush=True)
        result['status']='SCHEDULED_CHEMICAL_SELECTION_PRESERVES_ADMITTED_CONTEXTS_PASS'
    except Exception as error:result.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
