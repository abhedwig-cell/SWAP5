"""Actual public aquifer output flag, independent warm run and self-contained restart."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time
import zipfile
import output_aquifer_runtime as matrix
from original_output_aquifer import metadata as output_metadata,magic
from original_output_files import compare

m=matrix.m


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','matrix-root','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output=a.output.resolve();a.output.mkdir();cohort=json.loads((a.matrix_root/'RESULT.json').read_text());q=dict(status='RUNNING',profiles={})
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    try:
        for key in ('box-csv3','stiff-hys1-csv0','chemical-interval-csv3'):
            r=cohort['cases'][key];short=Path(r['short_root']);build=Path(r['build_root']);inputs=Path(r['input_root']);project=m.e.load(inputs,original_output=True);m.validate_bundle(build,a.reference_work,project)
            out=a.output/key;out.mkdir();days,cut,end=10,4,10
            command=[sys.executable,'-B',str(matrix.ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',inputs,'--reference-work',a.reference_work,'--build-bundle',build,'--donor-opt','O2','--kernel-opt','O2']
            if project.original_output:command+=['--original-output']
            def call(label,*args):
                t=time.monotonic();r=subprocess.run(list(map(str,[*command,*args])),cwd=matrix.ROOT,capture_output=True,text=True,timeout=90);(out/(label+'.stdout')).write_text(r.stdout);(out/(label+'.stderr')).write_text(r.stderr);assert r.returncode==0,r.stderr
                return dict(returncode=r.returncode,seconds=time.monotonic()-t)
            warm=call('warm','--days',days,'--checkpoint-at',cut,'--output',out/'warm');source=out/f'warm/accepted-column-1-day-{cut}.zip';digest=m.sha(source)
            cold=call('cold','--days',end,'--checkpoint-at',end,'--restart',source,'--restart-day',cut,'--output',out/'cold')
            left=m.rows(out/'warm');right=m.rows(out/'cold');m.check(left);m.check(right);assert m.physical(right)==m.physical(left[cut:end])
            with zipfile.ZipFile(short/f'trajectory/accepted-column-1-day-{end}.zip') as x,zipfile.ZipFile(out/f'cold/accepted-column-1-day-{end}.zip') as y:
                assert y.read('macro.bin')[:8]==magic(project)
                for member in ('result.end','macro.bin'):assert x.read(member)==y.read(member),member
            selected=output_metadata(project) or dict(nprintday=3,flprintdt=False)
            files=compare(out/'warm/original',out/'cold/original',selected,cut,end,project.start_date);assert m.sha(source)==digest
            q['profiles'][key]=dict(warm=warm,cold=cold,cut=cut,end=end,actual_public_flag=True,exact_physical=True,exact_complete_native=True,exact_user_output=files,source_checkpoint_unchanged=True,build_sha256=m.sha(build/'BUILD.json'));save();print(key,'PUBLIC_AQUIFER_OUTPUT_COLD_NATIVE_PASS',flush=True)
        q['status']='THREE_PUBLIC_AQUIFER_OUTPUT_COMPLETE_COLD_NATIVE_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
