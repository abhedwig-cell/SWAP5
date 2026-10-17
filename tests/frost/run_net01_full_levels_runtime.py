#!/usr/bin/env python3
"""Count-complete actual Richards composition, retaining all NET01 assertions."""
import argparse, importlib.util, json, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('modular',ROOT/'tests/modularity/run_modular_tests.py')
M=importlib.util.module_from_spec(spec);spec.loader.exec_module(M)

def body():
    b=(ROOT/'tests/frost/net01_runtime_body.inc').read_text()
    b=b.replace('do levels=2,3','do levels=2,25')
    b=b.replace('-.2_real64*real(j-1,real64)', '-.6_real64*real(j-1,real64)/real(levels-1,real64)')
    b=b.replace('    if(levels==3)f%frost_divdra_scalars_cm_per_day(3)=.002_real64', '''    if(levels>2)f%frost_divdra_scalars_cm_per_day(3:)=.002_real64/real(levels-2,real64)''')
    b=b.replace('do invalid=1,6','do invalid=1,7')
    b=b.replace('        end select\n        call run(badp', '''        case(7)
          deallocate(badp%frost_divdra_levels,badf%frost_divdra_scalars_cm_per_day)
          allocate(badp%frost_divdra_levels(26),badf%frost_divdra_scalars_cm_per_day(26))
          do j=1,26
            badp%frost_divdra_levels(j)=p%frost_divdra_levels(1)
            badp%frost_divdra_levels(j)%drain_bottom_cm=-2._real64-.6_real64*real(j-1,real64)/25._real64
          end do
          badf%frost_divdra_scalars_cm_per_day=.001_real64
        end select
        call run(badp''')
    b=b.replace('case_count==128.and.policy_count>0.and.rejected_count==48',
                'case_count==1536.and.policy_count>0.and.rejected_count==672')
    return b

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);a=ap.parse_args()
    session=M.Session(a.output)
    original='tests/frost/test_ppa_wu05b19_divdra_runtime.f90'
    source=(ROOT/original).read_text();start=source.index('  requested_case=0;');end=source.index('\ncontains\n',start)
    generated=session.out/'full_levels_runtime.f90';generated.write_text(source[:start]+body()+source[end:])
    drivers={'ordinary_multi':'tests/fmig431/test_swap431_multilevel_divdra_runtime.f90',
             'ordinary_inf':'tests/fmig431/test_swap431_inf_split_runtime.f90'}
    ordered,_=M.DEP.strict_closure(ROOT,[original,*drivers.values()],['tests/modularity/low_air_consistent_grid_stubs.f90'])
    prefix=[p for p in M.relative(ordered)if p not in [original,*drivers.values()]]+['src/legacy/b1_10_port/headcalc.f90']
    for case,driver,marker in [('full_levels_runtime',str(generated),'NET01_ACTUAL_RUNTIME=PASS'),
            ('ordinary_multi',drivers['ordinary_multi'],'SW431_MULTI_INDEPENDENT_ACTIVE_RUNTIME_CALLSITE PASS'),
            ('ordinary_inf',drivers['ordinary_inf'],'SW431_INF_INDEPENDENT_ACTIVE_RUNTIME_CALLSITE PASS')]:
        M.CASES[case]={'driver':driver,'marker':marker,'flags':M.COMMON+['-w']}
    M.plan=lambda case,broad=False:prefix+[str(generated)if case=='full_levels_runtime'else drivers[case]]
    rows=[]
    try:
        for opt in (0,2):
            for case in ['full_levels_runtime',*drivers]:
                rows.append(session.execute(case,opt));print(f'{case}_O{opt}=PASS',flush=True)
        for case in ['full_levels_runtime',*drivers]:
            pair=[r for r in rows if r['case']==case]
            assert pair[0]['stdout_sha256']==pair[1]['stdout_sha256'],'optimization identity '+case
    finally:
        M.write(session.out/'result.json',{'candidate':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
            'fixture':{p:M.sha(ROOT/p)for p in [original,'tests/frost/net01_runtime_body.inc',
                'tests/frost/run_net01_full_levels_runtime.py']},'results':rows,'events':session.events})
if __name__=='__main__':main()
