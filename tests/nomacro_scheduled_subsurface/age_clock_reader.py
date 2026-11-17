"""Actual monthly original reader with omitted inactive entries and strict005 input."""
import argparse
from datetime import date,timedelta
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import zipfile
import age_clock as c
import age_schedule as schedule

m=c.m


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','preserved','matrix-O0','matrix-O2','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();q=dict(status='RUNNING',omissions={},invalid=[])
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    try:
        for opt in ('O0','O2'):
            base=a.preserved/('monthly-plain-'+opt+'-build');old=json.loads((base/'BUILD.json').read_text())
            previous=a.preserved/('monthly-plain-'+opt+'-prefix368');before=m.rows(previous)[:35]
            for omitted in (('PERIOD',),('PERIOD','SWRES'),('SWODAT',),('PERIOD','SWRES','SWODAT')):
                name=opt+'-omit-'+'-'.join(omitted);out=a.output/name;out.mkdir()
                inputs=out/'input';shutil.copytree(a.preserved/'prior'/('monthly-plain-'+opt)/'input',inputs)
                path=inputs/'swap.swp';text=path.read_text(encoding='cp1252')
                for key in omitted:
                    text,count=re.subn(r'(?mi)^[ \t]*'+key+r'[ \t]*=[^\r\n]*(?:\r?\n|$)','',text);assert count==1
                path.write_text(text,encoding='cp1252');project=m.e.load(inputs);build=out/'build'
                cmd=[sys.executable,'-B',str(schedule.c.f.ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(inputs),'--reference-work',str(a.reference_work),'--build-only','--donor-opt',opt,'--kernel-opt',opt,'--output',str(build)]
                r=subprocess.run(cmd,capture_output=True,text=True,timeout=180);(out/'build.log').write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr
                meta,_=m.validate_bundle(build,a.reference_work,project)
                for key in ('donor_generated','donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library','kernel_sources','conserved_original_age'):
                    assert meta['identity'][key]==old['identity'][key],key
                full=out/'warm';result,data=m.trajectory(build,a.reference_work,project,full,35,{4,8,30,34,35},45)
                assert m.physical(data)==m.physical(before)
                last=str(date.fromisoformat(project.start_date)+timedelta(days=34))
                for csv in (full/'original').glob('*.csv'):
                    assert c.c.records(csv)==[line for line in c.c.records(previous/'original'/csv.name) if line[:10]<=last]
                for day in (4,8):
                    with zipfile.ZipFile(full/f'accepted-column-1-day-{day}.zip') as new,zipfile.ZipFile(previous/f'accepted-column-1-day-{day}.zip') as oldzip:
                        assert all(new.read(key)==oldzip.read(key) for key in ('result.end','macro.bin'))
                result['own']=schedule.own(build,a.reference_work,project,full,data,30,34,out/'own')
                q['omissions'][name]=dict(omitted=list(omitted),generated_provider_exact=True,physical35days_all_csv_two_native_exact=True,codec='S5AGE004',coverage=result);save();print(name,'ACTUAL_MONTHLY_READER_INACTIVE_ENTRIES_PASS',flush=True)
            original=getattr(a,'matrix_'+opt)/('subdaily2-plain-'+opt)/'input'
            for attack in ('per-step-output','missing-active-reset','frequency-zero','frequency-above-domain','ambiguous-frequency'):
                out=a.output/(opt+'-'+attack);shutil.copytree(original,out);path=out/'swap.swp';text=path.read_text(encoding='cp1252')
                if attack=='per-step-output':text+='\nFLPRINTDT = .TRUE.\n'
                elif attack=='missing-active-reset':text,count=re.subn(r'(?mi)^[ \t]*SWRES[ \t]*=[^\r\n]*(?:\r?\n|$)','',text);assert count==1
                elif attack=='ambiguous-frequency':text+='\nNPRINTDAY = 2\n'
                else:
                    value='0' if attack=='frequency-zero' else '1441'
                    text,count=re.subn(r'(?mi)^([ \t]*NPRINTDAY[ \t]*=)[^\r\n!]*',lambda match:match[1]+' '+value,text);assert count==1
                path.write_text(text,encoding='cp1252')
                try:
                    project=m.e.load(out)
                    import age_output_clock
                    age_output_clock.selection(project)
                except ValueError as error:q['invalid'].append(dict(optimization=opt,attack=attack,status='REFUSED',error=str(error)));save()
                else:raise AssertionError('Unsupported active clock input accepted: '+attack)
        q['status']='EIGHT_ACTUAL_MONTHLY_INACTIVE_OMISSIONS_AND_TEN_CLOCK_INPUT_REFUSALS_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
