"""Real original complete MOD_top numerical chain-rule component, no model copy."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(ROOT/'tools/solute')]
import user_prepare
from original_pond_budget import render
from extended_drainage import outward_pond_source
from extended_pond import render as original_extended_pond
from extended_implicit_pond import render as implicit_pond


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('provider','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args()
    a.build_root.mkdir(parents=True);a.output.mkdir();user_prepare.validate(a.provider)
    original=a.provider/'build/swap-src/SWAP/boundtop.f90';objects=a.provider/'build/swap-obj'
    source=a.build_root/'boundtop.f90';before=original_extended_pond(outward_pond_source(render(original.read_text(encoding='cp1252'))))
    visibility='public :: pondrunoff, q0, FlRunoff, ftoph, hsurf';assert before.count(visibility)==1
    source.write_text(implicit_pond(before).replace(visibility,visibility+', h0max, k1max',1),encoding='cp1252')
    flags=['gfortran','-'+a.optimization,'-ffp-contract=off','-march=x86-64','-mtune=generic','-ffree-line-length-none','-fcheck=all','-I',str(a.build_root),'-I',str(objects),'-J',str(a.build_root)]
    actual=[a.build_root/'boundtop.o' if f.name=='boundtop.o' else f for f in sorted(objects.glob('*.o')) if f.name!='swap_main.o']
    driver=Path(__file__).with_name('test_extended_implicit_pond.f90');exe=a.build_root/'probe.exe'
    commands=[flags+['-c',str(source),'-o',str(a.build_root/'boundtop.o')],flags+[str(driver),*map(str,actual),str(a.provider/'build/ttutil-obj/libttutil.a'),'-o',str(exe)]]
    compile=[]
    for i,command in enumerate(commands):
        r=subprocess.run(command,cwd=a.build_root,capture_output=True,text=True,timeout=60)
        compile.append(dict(command=command,returncode=r.returncode));(a.output/f'compile-{i}.stdout').write_text(r.stdout);(a.output/f'compile-{i}.stderr').write_text(r.stderr);r.check_returncode()
    r=subprocess.run([str(exe)],cwd=a.build_root,capture_output=True,text=True,timeout=30)
    (a.output/'actual.stdout').write_text(r.stdout);(a.output/'actual.stderr').write_text(r.stderr)
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),optimization=a.optimization,original_source_sha256=sha(original),actual_source_sha256=sha(source),driver_sha256=sha(driver),executable_sha256=sha(exe),original_objects={f.name:sha(f) for f in actual if f.parent==objects},compile=compile,actual_returncode=r.returncode,controlled_K_variation='Declared linear perturbation isolates conductivity/pond derivative interface; not an original Mualem full-model claim',physical_body='Complete real original MOD_top with qualified existing root renderer; unchanged explicit tangent and separately emitted implicit tangent; actual original object closure and TTUTIL')
    if r.returncode==0 and 'ACTUAL_ORIGINAL_IMPLICIT_EXTENDED_POND_CHAIN_RULE_PASS 40' in r.stdout:q['status']='ACTUAL_ORIGINAL_IMPLICIT_EXTENDED_POND_DERIVATIVE_AND_NONMUTATION_PASS'
    else:q['status']='FAILED'
    for path in (source,exe):(a.output/path.name).write_bytes(path.read_bytes())
    (a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');r.check_returncode();assert q['status']!='FAILED';print(q['status'],a.optimization)


if __name__=='__main__':main()
