"""Execute the real original date-table reader on malformed scheduled input."""
import argparse
import json
from pathlib import Path
import re
import shutil
import age_schedule as s

m=s.m


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','matrix','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();result=dict(status='RUNNING',checks=[])
    def save():(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    try:
        for opt in ('O0','O2'):
            original=a.matrix/('explicit-surface-'+opt);build=original/'build'
            m.validate_bundle(build,a.reference_work,m.e.load(original/'input'))
            for attack in ('missing-date-table','invalid-calendar-day'):
                target=a.output/(opt+'-'+attack);target.mkdir();inputs=target/'input';shutil.copytree(original/'input',inputs)
                path=inputs/'swap.swp';text=path.read_text(encoding='cp1252')
                if attack=='missing-date-table':
                    text,n=re.subn(r'(?mis)^[ \t]*OUTDATINT[ \t]*=.*?^\* End of table[^\r\n]*\r?\n?', '',text,count=1);assert n==1
                else:
                    assert text.count('2002-01-04')==1;text=text.replace('2002-01-04','2002-01-99')
                path.write_text(text,encoding='cp1252');project=m.e.load(inputs);out=target/'run';out.mkdir()
                try:m.bounded(20,lambda:m.h.run(m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),inputs,out,1,runtime=True,model=project.model,project=project))
                except (ValueError,RuntimeError) as error:
                    diagnostic='\n'.join(p.read_text(errors='replace') for pattern in ('swap.err','donor.stderr','donor.stdout') for p in out.rglob(pattern))
                    assert 'Fatal execution error' in diagnostic and any(word in diagnostic.lower() for word in ('outdatint','date','day')),diagnostic
                    assert not list(out.glob('accepted-*.zip'));result['checks'].append(dict(optimization=opt,attack=attack,status='ORIGINAL_READER_REFUSED',diagnostic=diagnostic,error=str(error)));save()
                else:raise AssertionError('Invalid original date table accepted: '+attack)
        result['status']='ACTUAL_ORIGINAL_SCHEDULE_DATE_TABLE_READERS_REFUSED_INVALID_INPUT'
    except Exception as error:result.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
