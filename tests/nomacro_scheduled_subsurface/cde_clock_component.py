"""Small compiler-portable driver of the actual production receipt interface."""
import argparse, hashlib, json, subprocess, time
from pathlib import Path


def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--optimization',choices=('O0','O2'));a=p.parse_args()
    root=Path(__file__).resolve().parents[2];a.output=a.output.resolve();a.output.mkdir()
    q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),cases={})
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    save()
    try:
        for opt in ([a.optimization] if a.optimization else ['O0','O2']):
            d=a.output/opt;d.mkdir();exe=d/'receipt.exe'
            command=['gfortran','-'+opt,'-fcheck=all','-ffpe-trap=invalid,zero,overflow','-fno-fast-math','-ffp-contract=off','-ffree-line-length-none','-o',str(exe),str(root/'app/hybrid_water/cde_clock_events.f90'),str(Path(__file__).with_name('test_cde_clock_events.f90'))]
            start=time.perf_counter();r=subprocess.run(command,cwd=d,capture_output=True,text=True,timeout=60)
            (d/'compile.stdout').write_text(r.stdout,encoding='utf8');(d/'compile.stderr').write_text(r.stderr,encoding='utf8')
            q['cases'][opt]=dict(command=command,compile_returncode=r.returncode,compile_seconds=time.perf_counter()-start);save();r.check_returncode()
            start=time.perf_counter();r=subprocess.run([str(exe)],cwd=d,capture_output=True,text=True,timeout=10)
            (d/'run.stdout').write_text(r.stdout,encoding='utf8');(d/'run.stderr').write_text(r.stderr,encoding='utf8')
            q['cases'][opt].update(run_returncode=r.returncode,run_seconds=time.perf_counter()-start,executable_sha256=hashlib.sha256(exe.read_bytes()).hexdigest());save();r.check_returncode()
            assert 'ACTUAL_CDE_CLOCK_LOCAL_EVENT_INTERFACE_PASS' in r.stdout
        q['status']='ACTUAL_CDE_CLOCK_LOCAL_EVENT_COMPONENT_PASS';print(q['status'],flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
