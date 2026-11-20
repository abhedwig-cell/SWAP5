"""One coherent original portable qualification for water Snow groundwater."""
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
    for key in ('reference-work','build-root','scratch','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();a.output.mkdir();logs=a.output/'commands';logs.mkdir()
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        optimization=a.optimization,steps=[],functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',canonical_admission=False)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def run(label,script,args,cap):
        command=[sys.executable,'-B',str(HERE/script),*map(str,args)];step=dict(label=label,command=command,status='RUNNING');q['steps'].append(step);save();start=time.monotonic()
        try:
            with (logs/(label+'.stdout')).open('x') as out,(logs/(label+'.stderr')).open('x') as err:
                result=subprocess.run(command,cwd=ROOT,stdout=out,stderr=err,timeout=cap)
            step['returncode']=result.returncode;result.check_returncode();step['status']='PASS'
        except Exception as error:step.update(status='FAILED_OR_CENSORED',error=repr(error));raise
        finally:step['seconds']=time.monotonic()-start;save()
    common=['--reference-work',a.reference_work]
    try:
        run('source','water_snow_groundwater_source_probe.py',[*common,'--build-root',a.build_root,'--output',a.output/'source-forms','--optimization',a.optimization],900)
        probe=a.output/'source-forms/RESULT.json';cases=json.loads(probe.read_text())['cases'];assert len(cases)==9 and all(c['returncode']==0 for c in cases.values())
        for label in cases:
            profile=a.output/('short-'+label)
            run('short-'+label,'water_snow_groundwater_period.py',[*common,'--source-probe',probe,'--label',label,'--output',profile],360)
            run('audit-short-'+label,'water_snow_groundwater_forensics.py',[profile,'--output',a.output/('INDEPENDENT_SHORT_'+label+'.json')],180)
        for label,cap in (('explicit-h2-clock',600),('implicit-h1-step-reset',1200)):
            profile=a.output/('full-'+label)
            run('full-'+label,'water_snow_groundwater_period.py',[*common,'--source-probe',probe,'--label',label,'--days',1096,'--cap',cap,'--output',profile],cap+720)
            run('audit-full-'+label,'water_snow_groundwater_forensics.py',[profile,'--output',a.output/('INDEPENDENT_FULL_'+label+'.json')],180)
        for label in ('explicit-h0-daily','implicit-h1-step-reset'):
            profile=a.output/('short-'+label)
            run('source-controls-'+label,'water_snow_groundwater_source_controls.py',[*common,'--profile',profile,
                '--scratch',a.scratch/label,'--output',a.output/('source-controls-'+label)],240)
            run('native-controls-'+label,'water_snow_groundwater_native_controls.py',[*common,'--profile',profile,
                '--output',a.output/('native-controls-'+label)],300)
            run('transactions-'+label,'implicit_snow_transactions.py',[*common,'--profile',profile,
                '--output',a.output/('transactions-'+label)],180)
        q['status']='ACTUAL_PORTABLE_NINE_WATER_SNOW_GROUNDWATER_COMPOSITIONS_PASS'
    except Exception as error:q.update(status='FAILED_OR_CENSORED',error=repr(error));raise
    finally:save()
    print(q['status'])


if __name__=='__main__':main()
