"""Age-off closure/native preservation against the actual current parent."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import age_fixed as f

m=f.m


def main():
    p=argparse.ArgumentParser()
    for key in ('evidence-root','reference-work','pulse-reference','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();e=a.evidence_root;specs=[]
    for name,source,last,windows in [('fixed-point',e/'chemical-fixed-point-short',8,[(2,4),(4,6)]),('scheduled-water',e/'chemical-preserve-water-point',5,[(2,4)])]:
        key=name+'-O2';old=e/'age-canonical-preservation';specs.append((key,m.e.load(source/'input'),a.reference_work,old/(key+'-build'),old/(key+'-prefix'),last,windows))
    for name,project in [('grass',m.h.GRASSGROWTH),('hupsel',m.h.HUPSEL),('salt',m.h.SALTFARM)]:
        old=e/'age-canonical-preservation';specs.append((name,project,a.reference_work,old/(name+'-build'),old/(name+'-prefix'),4,[(2,4)]))
    for kind in ('point','interval'):
        key='scheduled-chemical-'+kind+'-O2';old=e/'age-canonical-preservation';project=m.e.load(e/('scheduled-chemical-'+kind+'-full')/'input')
        specs.append((key,project,a.reference_work,old/(key+'-build'),old/(key+'-prefix'),8,[(2,4),(4,6)]))
    for kind in ('sorption-decay','stiff-loss'):
        key='aquifer-'+kind;old=e/'age-canonical-preservation';project=m.e.load(e/'aquifer-runtime-inputs'/kind)
        specs.append((key,project,a.reference_work,old/(key+'-build'),old/(key+'-prefix'),8,[(2,4),(4,6)]))
    from irrigation_pulse_time import POLICY as PULSE
    from local_wetting_time import POLICY as WETTING
    for label,parent,policy in [('pulse',e/'age-canonical-pulse',PULSE),('wetting',e/'age-canonical-wetting-v2',WETTING)]:
        for kind in ('water','chemical'):
            name=kind+'-surface-history';key=name+'-O2';project=m.e.load(parent/'inputs'/name,time_step_policy=policy)
            full=parent/(key+('-full' if label=='pulse' else '-prefix365'))
            specs.append((label+'-'+kind,project,a.pulse_reference,parent/(key+'-build'),full,201,[(4,6),(199,201)]))
    result=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),profiles={})
    def save():(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    try:
        for name,project,reference,old,previous,last,windows in specs:
            assert not project.age
            build=a.output/(name+'-build');cmd=[sys.executable,'-B',str(f.ROOT/'tools/solute/run_water.py'),'--model',project.model,'--reference-work',str(reference),'--build-only','--kernel-opt','O2','--output',str(build)]
            if project.input_directory:cmd+=['--experimental-project',project.input_directory,'--donor-opt','O2','--experimental-time-step-policy',project.time_step_policy]
            else:cmd+=['--no-macro-release']
            r=subprocess.run(cmd,capture_output=True,text=True,timeout=180);(a.output/(name+'.log')).write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr
            assert {p.name:m.sha(p) for p in build.glob('*.f90')}=={p.name:m.sha(p) for p in old.glob('*.f90')},name
            meta,_=m.validate_bundle(build,reference,project);prior=json.loads((old/'BUILD.json').read_text())
            for key in ('donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library','kernel_sources','adapter','driver'):assert meta['identity'][key]==prior['identity'][key],(name,key)
            assert meta['inputs']==prior['inputs'] and 'original_age_fixed_irrigation' not in meta['identity']
            out=a.output/(name+'-prefix');coverage,data=m.trajectory(build,reference,project,out,last,{v for w in windows for v in w},30)
            assert m.physical(data)==m.physical(m.rows(previous)[:last])
            assert m.csvlines(out/'original/result_output.csv')==m.csvlines(previous/'original/result_output.csv')[:last+2]
            coverage['own']=[m.own(build,reference,project,out,data,s,t,a.output/(name+'-own'+str(s))) for s,t in windows]
            result['profiles'][name]=dict(generated_provider_inputs_exact=True,physical_csv_exact=True,coverage=coverage);save();print(name,'AGE_FIXED_OFF_SOURCE_NATIVE_EXACT',flush=True)
        result['status']='THIRTEEN_AGE_FIXED_OFF_CURRENT_PARENT_CONTEXTS_SOURCE_NATIVE_EXACT'
    except Exception as error:result.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
