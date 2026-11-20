"""Retain actual clean groundwater clock proof fixture public verification or refusal."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--checkout',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--scratch',type=Path,required=True)
    p.add_argument('--expected-error')
    a=p.parse_args();out=a.output.with_suffix('.stdout.txt');err=a.output.with_suffix('.stderr.txt');receipt=a.output.with_suffix('.json')
    assert not any(p.exists() for p in (out,err,receipt))
    def git(*args):return subprocess.check_output(['git',*args],cwd=a.checkout,text=True).strip()
    def snap():return dict(head=git('rev-parse','HEAD'),tree=git('rev-parse','HEAD^{tree}'),status=git('status','--short','--ignored'),sparse=git('sparse-checkout','list').splitlines())
    before=snap();assert before['status']=='' and len(before['sparse'])==24
    assert before['sparse'][-1]=='/integration/f-ci/nomacro-complete01/GROUNDWATER_CDE_CLOCK_*'
    env=os.environ.copy();env.update(PYTHONDONTWRITEBYTECODE='1',TEMP=str(a.scratch),TMP=str(a.scratch))
    if os.name=='nt':env['PATH']='C:/msys64/ucrt64/bin;'+env['PATH']
    command=[sys.executable,'-B','tests/hupsel51/verify_successor.py'];start=time.monotonic()
    with out.open('w',encoding='utf-8') as o,err.open('w',encoding='utf-8') as e:
        result=subprocess.run(command,cwd=a.checkout,env=env,stdout=o,stderr=e,timeout=1200)
    after=snap();q=dict(command=command,cwd=str(a.checkout),before=before,after=after,
        elapsed_seconds=time.monotonic()-start,returncode=result.returncode,stdout_bytes=out.stat().st_size,
        stderr_bytes=err.stat().st_size,model_executions=0,expected_error=a.expected_error)
    receipt.write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8');print(json.dumps(q),flush=True)
    assert before==after
    if a.expected_error:assert result.returncode!=0 and a.expected_error in err.read_text(encoding='utf-8')
    else:assert result.returncode==0 and json.loads(out.read_text(encoding='utf-8'))['status']=='BOUNDED_GROUNDWATER_CDE_CLOCK_SOURCE_RAW_ADMISSION_PASS'


if __name__=='__main__':main()
