"""Qualify the coherent bounded ordinary Snow drainage-off composition."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('reference-work','build-root','scratch','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();a.output.mkdir();a.build_root.mkdir(parents=True,exist_ok=True);logs=a.output/'commands';logs.mkdir()
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        optimization=a.optimization,steps=[],functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',canonical_admission=False)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
    def run(label,script,args,cap):
        command=[sys.executable,'-B',str(HERE/script),*map(str,args)]
        step=dict(label=label,command=command,status='RUNNING');q['steps'].append(step);save();start=time.monotonic()
        try:
            with (logs/(label+'.stdout')).open('x') as out,(logs/(label+'.stderr')).open('x') as err:
                result=subprocess.run(command,cwd=ROOT,stdout=out,stderr=err,timeout=cap)
            step['returncode']=result.returncode;result.check_returncode();step['status']='PASS'
        except Exception as error:step.update(status='FAILED_OR_CENSORED',error=repr(error));raise
        finally:step['seconds']=time.monotonic()-start;save()
    common=['--reference-work',a.reference_work]
    try:
        run('inputs','snow_undrained_fixture.py',['--output',a.output/'inputs'],60)
        run('cde-component','snow_undrained_cde_positive_component.py',[*common,'--build-root',a.build_root/'component',
            '--output',a.output/'cde-component','--optimization',a.optimization],180)
        from snow_undrained_component_forensics import audit as component_audit
        q['independent_cde_component']=component_audit(a.output/'cde-component',json.loads((a.reference_work/'PREPARED.json').read_text()));save()
        run('source','snow_undrained_source_probe.py',[*common,'--baseline',a.output/'inputs/RESULT.json',
            '--build-root',a.build_root/'models','--output',a.output/'source-forms','--optimization',a.optimization],1800)
        probe=a.output/'source-forms/RESULT.json';assert len(json.loads(probe.read_text())['cases'])==9
        run('short','snow_undrained_campaign.py',[*common,'--source-probe',probe,'--output',a.output/'short'],1800)
        run('full','snow_undrained_campaign.py',[*common,'--source-probe',probe,'--output',a.output/'full','--days',1096,
            '--only-labels','water-explicit-flux-daily','water-implicit-head-clock',
            'cde-explicit-flux-interval','cde-implicit-head-clock-positive'],7200)
        for label in ('water-explicit-flux-daily','cde-implicit-head-clock-positive'):
            profile=a.output/'short'/label
            run('source-controls-'+label,'snow_undrained_source_controls.py',[*common,'--profile',profile,
                '--scratch',a.scratch/label,'--output',a.output/('source-controls-'+label)],300)
            run('native-controls-'+label,'snow_undrained_native_controls.py',[*common,'--profile',profile,
                '--output',a.output/('native-controls-'+label)],300)
            run('transactions-'+label,'implicit_snow_transactions.py',[*common,'--profile',profile,
                '--output',a.output/('transactions-'+label)],180)
        q['status']='ACTUAL_PORTABLE_NINE_SNOW_UNDRAINED_CONFIGURATIONS_AND_BOUNDED_CDE_COMPONENT_PASS'
    except Exception as error:q.update(status='FAILED_OR_CENSORED',error=repr(error));raise
    finally:save()
    print(q['status'])


if __name__=='__main__':main()
