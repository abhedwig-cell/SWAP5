"""Compile and execute the real stateless prescribed-groundwater receipt."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time

ROOT=Path(__file__).resolve().parents[2]


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--optimization',choices=('O0','O2'),required=True)
    args=parser.parse_args()
    output=args.output.resolve();output.mkdir()
    sources=[ROOT/'src/process/mod_prescribed_groundwater_reaction.f90',
             Path(__file__).with_name('groundwater_reaction_driver.f90')]
    record=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                production_sha256=hashlib.sha256(sources[0].read_bytes()).hexdigest(),
                driver_sha256=hashlib.sha256(sources[1].read_bytes()).hexdigest(),
                optimization=args.optimization,compile_link_closure=[str(p.relative_to(ROOT)) for p in sources],
                compiler=subprocess.check_output(['gfortran','--version'],text=True).splitlines()[0])
    try:
        executable=output/('reaction.exe' if __import__('os').name=='nt' else 'reaction')
        command=['gfortran','-'+args.optimization,'-Wall','-Wextra','-fcheck=all','-fimplicit-none',
                 *map(str,sources),'-o',str(executable)]
        start=time.perf_counter()
        compiled=subprocess.run(command,cwd=output,capture_output=True,text=True)
        record['compile_link_seconds']=time.perf_counter()-start
        (output/'compile.log').write_text(compiled.stdout+compiled.stderr,encoding='utf8')
        compiled.check_returncode()
        start=time.perf_counter()
        run=subprocess.run([str(executable)],cwd=output,capture_output=True,text=True)
        record.update(native_seconds=time.perf_counter()-start,stdout=run.stdout,stderr=run.stderr)
        run.check_returncode()
        assert 'PRESCRIBED_GROUNDWATER_REACTION_CONTRACT_PASS' in run.stdout
        record['status']='REAL_PRESCRIBED_GROUNDWATER_REACTION_COMPONENT_PASS'
        print(json.dumps(record,indent=2))
    except Exception as error:
        record.update(status='FAILED',error=repr(error));raise
    finally:(output/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf8')


if __name__=='__main__':main()
