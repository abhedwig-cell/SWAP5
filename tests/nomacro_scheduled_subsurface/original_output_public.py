"""Actual public original-output flag, self-contained checkpoint and continuation."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time
import zipfile
import original_output_matrix as matrix
from original_output_files import compare

m=matrix.m


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--short-prefix',required=True);p.add_argument('--full-root',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output=a.output.resolve();a.output.mkdir()
    q=dict(status='RUNNING',profiles={})
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    try:
        for case in ('water-nprint3','cde-solbal-csv3','age-perstep-monthly'):
            short=Path(a.short_prefix+case+'-O2');build=short/'build';inputs=short/'input';project=m.e.load(inputs,original_output=True);meta,_=m.validate_bundle(build,a.reference_work,project)
            out=a.output/case;out.mkdir();days,cut,end=(35,30,34) if 'monthly' in case else (10,4,9)
            command=[sys.executable,'-B',str(matrix.ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',inputs,'--original-output','--reference-work',a.reference_work,'--build-bundle',build,'--donor-opt','O2','--kernel-opt','O2']
            def call(label,*args):
                start=time.monotonic();r=subprocess.run(list(map(str,[*command,*args])),cwd=matrix.ROOT,capture_output=True,text=True,timeout=90)
                (out/(label+'.stdout')).write_text(r.stdout);(out/(label+'.stderr')).write_text(r.stderr);assert r.returncode==0,r.stderr
                return dict(returncode=r.returncode,seconds=time.monotonic()-start)
            warm=call('warm','--days',days,'--checkpoint-at',cut,'--output',out/'warm');source=out/f'warm/accepted-column-1-day-{cut}.zip';digest=m.sha(source)
            cold=call('cold','--days',end,'--checkpoint-at',end,'--restart',source,'--restart-day',cut,'--output',out/'cold')
            left=m.rows(out/'warm');right=m.rows(out/'cold');m.check(left);m.check(right);assert m.physical(right)==m.physical(left[cut:end])
            full=short/'trajectory'
            with zipfile.ZipFile(full/f'accepted-column-1-day-{end}.zip') as x,zipfile.ZipFile(out/f'cold/accepted-column-1-day-{end}.zip') as y:
                assert all(x.read(n)==y.read(n) for n in ('result.end','macro.bin'))
            from original_output import selection
            files=compare(out/'warm/original',out/'cold/original',selection(project),cut,end,project.start_date)
            assert m.sha(source)==digest
            q['profiles'][case]=dict(warm=warm,cold=cold,cut=cut,end=end,source_checkpoint_sha256=digest,actual_public_flag=True,exact_physical=True,exact_complete_native=True,exact_original_user_output=files,build_sha256=m.sha(build/'BUILD.json'));save();print(case,'PUBLIC_ORIGINAL_OUTPUT_NATIVE_PASS',flush=True)
        q['status']='THREE_PUBLIC_ORIGINAL_OUTPUT_FLAG_AND_COMPLETE_COLD_NATIVE_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
