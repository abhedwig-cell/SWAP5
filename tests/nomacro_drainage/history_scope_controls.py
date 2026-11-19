"""Actual public CLI refusals for deliberately excluded history compositions."""
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
    a=p.parse_args();a.output.mkdir();records=[];original=inventory(a.profile/'input')
    cases=[('compatibility',{'SWCSV':1},False,'Extended drainage hydraulic history requires explicit original-output state'),
           ('AGE',{'SWSOLU':2,'SWHYST':0},True,'Extended drainage AGE retained-age dry-pond closure is not qualified'),
           ('history3',{'SWHYST':3},True,'Unqualified extended drainage hydraulic history'),
           ('implicit',{'SWKIMPL':1},True,'Unqualified extended drainage process composition')]
    for label,changes,output,expected in cases:
        directory=a.output/label;directory.mkdir();inputs=directory/'input';shutil.copytree(a.profile/'input',inputs)
        path=inputs/'swap.swp';text=path.read_text(encoding='cp1252')
        for key,value in changes.items():text=assignment(text,key,value)
        path.write_text(text,encoding='cp1252');before=inventory(inputs);build=a.build_root/label
        command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model','HYBRID_NOMACRO_WATER','--experimental-project',str(inputs),'--reference-work',str(a.reference_work),'--build-only','--output',str(build)]
        if output:command.append('--original-output')
        r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=30)
        (directory/'actual.stdout').write_text(r.stdout);(directory/'actual.stderr').write_text(r.stderr)
        assert r.returncode==2 and expected in r.stderr,(label,r.returncode,r.stderr)
        assert before==inventory(inputs) and not list(build.rglob('*.exe')) and not list(build.rglob('*.f90')) and not list(build.rglob('donor.stdout')) and not list(build.rglob('accepted-*.zip'))
        records.append(dict(label=label,declared_changes=changes,command=command,returncode=r.returncode,expected_refusal=expected,input_sha256=before,no_compiler_source_or_executable=True,no_worker_or_publication=True))
    assert original==inventory(a.profile/'input')
    result=dict(status='ACTUAL_PUBLIC_EXCLUDED_HISTORY_COMPOSITIONS_REFUSED_BEFORE_COMPILER_WORKER_PUBLICATION',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),controls=records,accepted_origin_unchanged=True)
    (a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'],len(records))


if __name__=='__main__':main()
