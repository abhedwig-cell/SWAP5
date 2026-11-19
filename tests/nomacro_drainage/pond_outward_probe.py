"""Literal original/corrected PondRunoff component qualification, no model copy."""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
from original_pond_budget import render
from extended_drainage import outward_pond_source

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--provider',type=Path,required=True)
    p.add_argument('--build-root',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--optimization',choices=['O0','O2'],required=True)
    a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
    original=a.provider/'build/swap-src/SWAP/boundtop.f90'
    text=original.read_text(encoding='cp1252')
    visibility='public :: pondrunoff, q0, FlRunoff, ftoph, hsurf'
    assert text.count(visibility)==1
    reports=[]
    for mode in ('original','corrected'):
        out=a.build_root/mode;out.mkdir(parents=True,exist_ok=False)
        src=out/'boundtop.f90'
        body=text if mode=='original' else outward_pond_source(render(text))
        src.write_text(body.replace(visibility,visibility+', h0max, k1max',1),encoding='cp1252')
        provider=a.provider/'build/swap-obj'
        flags=['gfortran','-'+a.optimization,'-ffp-contract=off','-march=x86-64','-mtune=generic','-ffree-line-length-none','-I',str(out),'-I',str(provider),'-J',str(out)]
        commands=[flags+['-c',str(src),'-o',str(out/'boundtop.o')]]
        objects=[out/'boundtop.o' if f.name=='boundtop.o' else f for f in sorted(provider.glob('*.o')) if f.name!='swap_main.o']
        driver=ROOT/'tests/nomacro_drainage/test_original_pond_outward.f90'
        exe=out/'probe.exe'
        commands.append(flags+[str(driver),*map(str,objects),str(a.provider/'build/ttutil-obj/libttutil.a'),'-o',str(exe)])
        compile_logs=[]
        for command in commands:
            r=subprocess.run(command,cwd=out,capture_output=True,text=True)
            compile_logs.append(dict(command=command,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr))
            if r.returncode:
                (a.output/(mode+'-compile.json')).write_text(json.dumps(compile_logs,indent=2),encoding='utf8')
                raise RuntimeError(r.stderr)
        r=subprocess.run([str(exe),mode],cwd=out,capture_output=True,text=True)
        for f in (src,exe):
            (a.output/(mode+'-'+f.name)).write_bytes(f.read_bytes())
        report=dict(mode=mode,optimization=a.optimization,source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),original_source_sha256=sha(original),driver_sha256=sha(driver),rendered_source_sha256=sha(src),executable_sha256=sha(exe),objects={str(f):sha(f) for f in objects},compile=compile_logs,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr)
        (a.output/(mode+'.json')).write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
        print(mode,r.returncode,r.stdout,flush=True)
        assert r.returncode==0
        reports.append(report)
    (a.output/'PASS.json').write_text(json.dumps(dict(status='ACTUAL_ORIGINAL_DEFECT_AND_BOUNDED_CORRECTION_PASS',optimization=a.optimization,reports=[r['mode'] for r in reports]),indent=2)+'\n',encoding='utf8')

if __name__=='__main__':main()
