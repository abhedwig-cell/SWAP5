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
    drivers={'ordinary_multi':'tests/fmig431/test_swap431_multilevel_divdra_runtime.f90',
             'ordinary_inf':'tests/fmig431/test_swap431_inf_split_runtime.f90'}
    ordered,_=M.DEP.strict_closure(ROOT,[original,*drivers.values()],['tests/modularity/low_air_consistent_grid_stubs.f90'])
    prefix=[p for p in M.relative(ordered)if p not in [original,*drivers.values()]]+['src/legacy/b1_10_port/headcalc.f90']
    M.CASES['net01_runtime']={'driver':str(generated),'marker':'NET01_ACTUAL_RUNTIME=PASS','flags':M.COMMON+['-w']}
    M.CASES['ordinary_multi']={'driver':drivers['ordinary_multi'],'marker':'SW431_MULTI_INDEPENDENT_ACTIVE_RUNTIME_CALLSITE PASS','flags':M.COMMON+['-w']}
    M.CASES['ordinary_inf']={'driver':drivers['ordinary_inf'],'marker':'SW431_INF_INDEPENDENT_ACTIVE_RUNTIME_CALLSITE PASS','flags':M.COMMON+['-w']}
    M.plan=lambda case,broad=False:prefix+[str(generated)if case=='net01_runtime'else drivers[case]]
    rows=[]
    try:
        for opt in(0,2):
            for case in ['net01_runtime',*drivers]:
                rows.append(session.execute(case,opt));print(f'{case}_O{opt}=PASS',flush=True)
        for case in ['net01_runtime',*drivers]:
            pair=[r for r in rows if r['case']==case]
            assert pair[0]['stdout_sha256']==pair[1]['stdout_sha256'],'optimization identity '+case
    finally:
        M.write(session.out/'result.json',{'candidate':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
            'fixture':{original:M.sha(ROOT/original),'tests/frost/net01_runtime_body.inc':M.sha(ROOT/'tests/frost/net01_runtime_body.inc')},
            'results':rows,'events':session.events})
if __name__=='__main__':main()
