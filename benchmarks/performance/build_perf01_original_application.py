"""Build the complete original B1.11 application, without replacement physics."""
import argparse,hashlib,json,os,subprocess,sys,time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--opt',choices=['O0','O2'],default='O2')
    a=ap.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    start=time.perf_counter();providers=out/'providers'
    command=[sys.executable,'-B',str(ROOT/'tools/performance/build_swap431_perf01.py'),'--output',str(providers),'--opt',a.opt]
    r=subprocess.run(command,cwd=ROOT,capture_output=True)
    (out/'providers.stdout').write_bytes(r.stdout);(out/'providers.stderr').write_bytes(r.stderr)
    r.check_returncode()
    meta=json.loads((providers/'INPUTS.json').read_text())
    fc=os.environ.get('FC','gfortran');flags=meta['flags']
    source=providers/'selected/swap_main.f90';obj=out/'swap_main.o'
    commands=[
        [fc,*flags,'-ffree-line-length-none','-I',str(providers/'swobj'),'-I',str(providers/'ttobj'),'-c',str(source),'-o',str(obj)],
        [fc,*flags,str(obj),*map(str,sorted((providers/'swobj').glob('*.o'))),str(providers/'ttobj/libttutil.a'),'-o',str(out/'swap431')]]
    for i,cmd in enumerate(commands):
        r=subprocess.run(cmd,cwd=out,capture_output=True)
        (out/f'{i}.stdout').write_bytes(r.stdout);(out/f'{i}.stderr').write_bytes(r.stderr)
        r.check_returncode()
    result=dict(status='COMPLETE_ORIGINAL_APPLICATION_BUILT',compiler=subprocess.check_output([fc,'--version'],text=True),
        original_provider_build=meta,commands=commands,compile_link_wall_seconds=time.perf_counter()-start,
        source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
        executable_sha256=hashlib.sha256((out/'swap431').read_bytes()).hexdigest(),
        original_normal_exit_code=100,physics_replaced=False)
    (out/'BUILD.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items()if k not in ['original_provider_build','commands']}))
if __name__=='__main__':main()
