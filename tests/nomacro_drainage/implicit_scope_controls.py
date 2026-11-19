"""Actual public CLI refusals for deliberately excluded implicit drainage compositions."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
from calendar_runtime import assignment,ROOT


def inventory(root):return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(root.rglob('*')) if p.is_file()}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('profile','reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--secondary-profile',type=Path,required=True);a=p.parse_args();a.output.mkdir();records=[];original=inventory(a.profile/'input');origin=a.profile/'trajectory/accepted-column-1-day-4.zip';origin_hash=hashlib.sha256(origin.read_bytes()).hexdigest()
    cases=[('compatibility',{'SWCSV':1,'SWRES':0,'SWMONTH':0,'SWODAT':0},False,'Original implicit conductivity requires explicit --original-output daily trial and state qualification'),
           ('AGE',{'SWSOLU':2,'SWHYST':0},True,'Extended drainage AGE retained-age dry-pond closure is not qualified'),
           ('history3',{'SWHYST':3},True,'Unqualified extended drainage hydraulic history'),
           ('secondary-only',{},True,'Implicit secondary-only extended drainage is not qualified: original Newton clock-resolution failure'),
           ('examined-Ksat',{},True,'Original implicit derivative does not implement examined-Ksat interpolation')]
    for label,changes,output,expected in cases:
        directory=a.output/label;directory.mkdir();inputs=directory/'input';shutil.copytree(a.profile/'input',inputs)
        path=inputs/'swap.swp';text=path.read_text(encoding='cp1252')
        for key,value in changes.items():text=assignment(text,key,value)
        if label=='secondary-only':shutil.copyfile(a.secondary_profile/'input/swap.dra',inputs/'swap.dra')
        if label=='examined-Ksat':
            import re
            def examined(match):
                names=match[1].split();rows=[]
                for line in match[2].splitlines():
                    fields=line.split();fields[names.index('KSATEXM')]=str(1.1*float(fields[names.index('KSATFIT')]))
                    rows.append(' '.join(fields))
                return match[1]+'\n'.join(rows)+'\n* End of table'
            text,count=re.subn(r'(?mi)^([ \t]*ORES[ \t]+OSAT[^\r\n]*\n)(.*?)^\* End of table',examined,text,count=1,flags=re.S);assert count==1
        path.write_text(text,encoding='cp1252');before=inventory(inputs);build=a.build_root/label
        command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model','HYBRID_NOMACRO_WATER','--experimental-project',str(inputs),'--reference-work',str(a.reference_work),'--build-only','--output',str(build)]
        if output:command.append('--original-output')
        r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=30)
        (directory/'actual.stdout').write_text(r.stdout);(directory/'actual.stderr').write_text(r.stderr)
        assert r.returncode==2 and expected in r.stderr,(label,r.returncode,r.stderr)
        assert before==inventory(inputs) and not list(build.rglob('*.exe')) and not list(build.rglob('*.f90')) and not list(build.rglob('donor.stdout')) and not list(build.rglob('accepted-*.zip'))
        records.append(dict(label=label,declared_changes=changes,command=command,returncode=r.returncode,expected_refusal=expected,input_sha256=before,no_compiler_source_or_executable=True,no_worker_or_publication=True))
    assert original==inventory(a.profile/'input') and hashlib.sha256(origin.read_bytes()).hexdigest()==origin_hash
    result=dict(status='ACTUAL_FIVE_PUBLIC_EXCLUDED_IMPLICIT_COMPOSITIONS_REFUSED_BEFORE_COMPILER_WORKER_PUBLICATION',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),controls=records,accepted_origin_unchanged=True)
    (a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'],len(records))


if __name__=='__main__':main()
