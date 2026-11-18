"""Actual omitted inactive monthly selectors and early invalid output refusals."""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import original_output_matrix as matrix
from original_output import metadata

m=matrix.m


def main():
    p=argparse.ArgumentParser();p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output=a.output.resolve();a.output.mkdir()
    q=dict(status='RUNNING',profiles={},invalid=[])
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    try:
        for case in ('water-monthly','age-perstep-monthly'):
            parent=a.output/case;parent.mkdir();inputs=parent/'input';matrix.fixture(inputs,case);control=inputs/'swap.swp';text=control.read_text(encoding='cp1252')
            for key in ('PERIOD','SWRES','SWODAT','SWCSV','INLIST_CSV','NUM_DECIMALS'):text=re.sub(r'(?mi)^[ \t]*'+key+r'[ \t]*=[^\r\n]*\r?\n','',text)
            control.write_text(text,encoding='cp1252');project=m.e.load(inputs,original_output=True);selected=metadata(project);assert selected['swcsv']==0 and selected['swmonth']==1 and selected['requested_period']==selected['swres']==selected['swodat']==0
            for opt in ('O0','O2'):
                out=parent/opt;command=[sys.executable,'-B',str(matrix.ROOT/'tests/nomacro_scheduled_subsurface/original_output_matrix.py'),'--reference-work',a.reference_work,'--output',out,'--case',case,'--optimization',opt,'--existing-input',inputs]
                r=subprocess.run(list(map(str,command)),capture_output=True,text=True,timeout=180);(parent/(opt+'.stdout')).write_text(r.stdout);(parent/(opt+'.stderr')).write_text(r.stderr);assert r.returncode==0,r.stderr
                result=json.loads((out/'RESULT.json').read_text());assert result['status']=='ORIGINAL_OUTPUT_SHORT_NATIVE_SOURCE_PASS';q['profiles'][case+'-'+opt]=result;save();print(case,opt,'OMITTED_MONTHLY_CONTROLS_NATIVE_PASS',flush=True)
        attacks=[('SWCSV',4),('NPRINTDAY',0),('NPRINTDAY',1441),('NUM_DECIMALS',4),('NUM_DECIMALS',13),('SWMONTH',2),('SWODAT',2),('SWRES',2),('PERIOD',-1),('PERIOD',367),('FLPRINTDT','garbage'),('FLPRINTDT','.TRUE.'),('SWSNOW',1)]
        for i,(key,value) in enumerate(attacks):
            inputs=a.output/('invalid-'+str(i));matrix.fixture(inputs,'water-csv3');p=inputs/'swap.swp';text=p.read_text(encoding='cp1252')
            if key=='FLPRINTDT':
                text+='\nFLPRINTDT = '+str(value)+'\n'
                if value=='.TRUE.':text=matrix.baseline.assignment(text,'SWRES',1)
            else:text=matrix.baseline.assignment(text,key,value)
            p.write_text(text,encoding='cp1252')
            try:metadata(m.e.load(inputs,original_output=True))
            except ValueError as error:q['invalid'].append(dict(key=key,value=value,status='REFUSED',error=str(error)))
            else:raise AssertionError('Invalid original output input accepted: '+key)
        # CDE's private interval stock is deliberately daily-only in this owner.
        for key,value in [('NPRINTDAY',2),('SWMONTH',1),('PERIOD',3)]:
            inputs=a.output/('cde-invalid-'+key);matrix.fixture(inputs,'cde-csv0');p=inputs/'swap.swp';p.write_text(matrix.baseline.assignment(p.read_text(encoding='cp1252'),key,value),encoding='cp1252')
            try:metadata(m.e.load(inputs,original_output=True))
            except ValueError as error:assert 'Original CDE output currently requires daily' in str(error);q['invalid'].append(dict(kind='cde',key=key,value=value,status='REFUSED',error=str(error)))
            else:raise AssertionError('Unowned CDE cadence accepted')
        q['status']='FOUR_ORIGINAL_OMITTED_MONTHLY_CONTROLS_NATIVE_AND_SIXTEEN_INPUT_REFUSALS_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
