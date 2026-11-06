"""Execute the byte-exact original pond runner with the complete private postimage."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time

import pond_thermal_native as native


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    record=native.guard();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    view=native.prepare(out,'candidate',record)
    original=subprocess.check_output(['git','show',record['baseline']+':'+native.RUNNER],cwd=native.ROOT)
    (view/native.RUNNER).write_bytes(original)
    delta=subprocess.check_output(['git','diff','--name-only',record['baseline'],'--','src','app/support/restart_publish.c',native.RUNNER],cwd=view,text=True).splitlines()
    assert delta==[native.SOURCE]
    result=dict(status='RUNNING',baseline=record['baseline'],private_source_sha256=native.sha(view/native.SOURCE),
                original_runner_sha256=native.sha(view/native.RUNNER),events=[],production_admission=False)
    for recipe in ('physical','black-rutter'):
        cmd=[sys.executable,'-B',str(view/native.RUNNER),'--output',str(out/recipe)]
        if recipe=='black-rutter':cmd+=['--black-rutter','--resume-compilation',str(out/'physical')]
        start=time.monotonic();cp=subprocess.run(cmd,cwd=view,capture_output=True,env=dict(os.environ,OMP_NUM_THREADS='1',PYTHONUTF8='1'),timeout=1800)
        for stream in ('stdout','stderr'):(out/(recipe+'.'+stream)).write_bytes(getattr(cp,stream))
        result['events'].append(dict(recipe=recipe,command=cmd,returncode=cp.returncode,seconds=time.monotonic()-start))
        (out/'ORIGINAL_BUILD_RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
        assert cp.returncode==0,cp.stderr[-3000:]
        print(recipe,'actual unmodified original runner O0/O2 PASS',flush=True)
    result['status']='ACTUAL_UNMODIFIED_ORIGINAL_RUNNER_BOTH_RECIPES_PASS'
    (out/'ORIGINAL_BUILD_RESULT.json').write_text(json.dumps(result,indent=2)+'\n');native.guard()


if __name__=='__main__':main()
