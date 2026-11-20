"""One coherent portable implicit Snow coupling qualification, without retries."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','build-root','scratch','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    a=p.parse_args();a.output.mkdir();logs=a.output/'commands';logs.mkdir()
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        optimization=a.optimization,steps=[],functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',canonical_admission=False)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def run(label,script,args,cap):
        command=[sys.executable,'-B',str(HERE/script),*map(str,args)];step=dict(label=label,command=command,status='RUNNING');q['steps'].append(step);save()
        start=time.monotonic()
        try:
            with (logs/(label+'.stdout')).open('x') as out,(logs/(label+'.stderr')).open('x') as err:
                result=subprocess.run(command,cwd=ROOT,stdout=out,stderr=err,timeout=cap)
            step['returncode']=result.returncode;result.check_returncode();step['status']='PASS'
        except Exception as error:step.update(status='FAILED_OR_CENSORED',error=repr(error));raise
        finally:step['seconds']=time.monotonic()-start;save()
    common=['--reference-work',a.reference_work]
    try:
        run('source','implicit_snow_source_probe.py',[*common,'--build-root',a.build_root,'--output',a.output/'source-forms','--optimization',a.optimization],900)
        source=json.loads((a.output/'source-forms/RESULT.json').read_text())
        assert len(source['cases'])==9 and all(c['returncode']==0 for c in source['cases'].values())
        run('short','implicit_snow_short.py',[*common,'--source-probe',a.output/'source-forms/RESULT.json','--output',a.output/'short','--optimization',a.optimization],1800)
        for label,cap in (('water-head',600),('cde-groundwater-clock',180),('cde-head-step',1200)):
            run('full-'+label,'implicit_snow_full.py',[*common,'--reuse-case',a.output/'short'/label,'--output',a.output/('full-'+label),'--cap',cap],cap+720)
        for label in source['cases']:
            run('audit-short-'+label,'implicit_snow_forensics.py',[a.output/'short'/label,'--output',a.output/('INDEPENDENT_SHORT_'+label+'.json')],180)
        for label in ('water-head','cde-groundwater-clock','cde-head-step'):
            run('audit-full-'+label,'implicit_snow_forensics.py',[a.output/('full-'+label),'--output',a.output/('INDEPENDENT_FULL_'+label+'.json')],180)
            run('source-controls-'+label,'implicit_snow_source_controls.py',[*common,'--profile',a.output/'short'/label,
                '--scratch',a.scratch/label,'--output',a.output/('source-controls-'+label)],180)
        for label in ('water-head','cde-head-step'):
            run('native-controls-'+label,'implicit_snow_root_controls.py',[*common,'--profile',a.output/'short'/label,'--output',a.output/('native-controls-'+label)],300)
        for label in ('water-head','cde-head-step','cde-groundwater-clock','cde-groundwater-interval'):
            run('transactions-'+label,'implicit_snow_transactions.py',[*common,'--profile',a.output/'short'/label,'--output',a.output/('transactions-'+label)],180)
        q['status']='ACTUAL_PORTABLE_NINE_IMPLICIT_SNOW_COMPOSITIONS_PASS'
    except Exception as error:q.update(status='FAILED_OR_CENSORED',error=repr(error));raise
    finally:save()
    print(q['status'])


if __name__=='__main__':main()
