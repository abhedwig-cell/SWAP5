#!/usr/bin/env python3
"""NET01 actual runtime, reusing unchanged B19 physical fixture procedures."""
import argparse, importlib.util, json, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('modular',ROOT/'tests/modularity/run_modular_tests.py')
M=importlib.util.module_from_spec(spec);spec.loader.exec_module(M)
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);a=ap.parse_args()
    session=M.Session(a.output)
    original='tests/frost/test_ppa_wu05b19_divdra_runtime.f90'
    source=(ROOT/original).read_text();start=source.index('  requested_case=0;');end=source.index('\ncontains\n',start)
    generated=session.out/'net01_runtime.f90'
    generated.write_text(source[:start]+(ROOT/'tests/frost/net01_runtime_body.inc').read_text()+source[end:])
    ordered,_=M.DEP.strict_closure(ROOT,[original],['tests/modularity/low_air_consistent_grid_stubs.f90'])
    prefix=M.relative(ordered[:-1])+['src/legacy/b1_10_port/headcalc.f90']
    M.CASES['net01_runtime']={'driver':str(generated),'marker':'NET01_ACTUAL_RUNTIME=PASS','flags':M.COMMON+['-w']}
    M.plan=lambda case,broad=False:prefix+[str(generated)]
    rows=[]
    try:
        for opt in(0,2):
            rows.append(session.execute('net01_runtime',opt));print(f'NET01_RUNTIME_O{opt}=PASS',flush=True)
        assert rows[0]['stdout_sha256']==rows[1]['stdout_sha256'],'optimization identity'
    finally:
        M.write(session.out/'result.json',{'candidate':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
            'fixture':{original:M.sha(ROOT/original),'tests/frost/net01_runtime_body.inc':M.sha(ROOT/'tests/frost/net01_runtime_body.inc')},
            'results':rows,'events':session.events})
if __name__=='__main__':main()
