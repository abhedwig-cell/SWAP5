#!/usr/bin/env python3
"""Bounded MC-DRAIN01 O0/O2 production contracts and targeted composition.

Uses the existing measured Session and strict provider resolver. No broad suite.
"""
import argparse,importlib.util,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('modular',ROOT/'tests/modularity/run_modular_tests.py')
M=importlib.util.module_from_spec(spec);spec.loader.exec_module(M)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);ap.add_argument('--process-only',action='store_true');ap.add_argument('--guards-only',action='store_true');a=ap.parse_args()
    cases={
      'inf_contract':('tests/fmig431/test_swap431_inf_split_contract.f90','INF_SPLIT_SOURCE_SHARED_INTEGRAL_LITERAL_BINDER=PASS'),
      'multilevel_contract':('tests/fmig431/test_swap431_multilevel_divdra_contract.f90','MULTILEVEL_LITERAL_ORIGINAL_BINDER_NEGATIVES=PASS'),
      'signed_contract':('tests/fmig431/test_swap431_signed_divdra_contract.f90','SIGNED_DIVDRA_LITERAL_B19_SIGNS_NEGATIVES_NONMUTATION=PASS'),
      'positive_process':('tests/fci/fci32_divdra_admission_smoke.f90','FCI32_DIVDRA_ADMISSION_SMOKE=PASS'),
      'positive_binder':('tests/fci/fci33_divdra_runtime_admission_smoke.f90','FCI33_DIVDRA_RUNTIME_ADMISSION_SMOKE=PASS'),
    }
    if not a.process_only:
        cases['inf_runtime']=('tests/fmig431/test_swap431_inf_split_runtime.f90','SW431_INF_INDEPENDENT_ACTIVE_RUNTIME_CALLSITE PASS')
        cases['multilevel_runtime']=('tests/fmig431/test_swap431_multilevel_divdra_runtime.f90','SW431_MULTI_INDEPENDENT_ACTIVE_RUNTIME_CALLSITE PASS')
        cases['signed_runtime']=('tests/fmig431/test_swap431_signed_divdra_runtime.f90','SW431_SIGNED_INDEPENDENT_ACTIVE_RUNTIME_CALLSITE PASS')
    if a.guards_only:
        cases={'inf_guards':('tests/fmig431/test_swap431_inf_split_guards.f90','INF_SPLIT_GUARDS=PASS')}
    runtime_drivers=[v[0]for k,v in cases.items()if k.endswith('_runtime')]
    runtime_prefix=None
    if runtime_drivers:
        ordered,_=M.DEP.strict_closure(ROOT,runtime_drivers,[M.STUB,'tests/fmr/mod_fmr04_fixed_top_provider.f90'])
        runtime_prefix=[p for p in M.relative(ordered)if p not in runtime_drivers]
        if M.STUB in runtime_prefix:runtime_prefix+=['src/legacy/b1_10_port/headcalc.f90']
    # Explicit support closure includes the existing real HeadCalc globals and
    # top provider; these are configuration fixtures, not substitutes for physics.
    def plan(case,broad=False):
        if case.endswith("_runtime"):return runtime_prefix+[cases[case][0]]
        if case=='inf_contract':
            return ['src/solver/mod_soil_water_solver_contract.f90','src/solver/mod_process_hydraulic_view.f90','src/process/mod_drainage_spatial_distribution.f90','src/process/mod_frost_divdra_drainage_effect.f90','src/process/mod_drainage_b19_separate_infiltration_adapter.f90','src/runtime/mod_fmr_divdra_separate_infiltration_binding.f90','tests/frost/test_ppa_wu05b20_multilevel_globals.f90','reference/swap-4.3.1/frost-corrections/FROST-DIVDRA-03/divdra.f90',cases[case][0]]
        if case=='multilevel_contract':
            return ['src/solver/mod_soil_water_solver_contract.f90','src/solver/mod_process_hydraulic_view.f90','src/process/mod_drainage_spatial_distribution.f90','src/runtime/mod_fmr_divdra_runtime_binding.f90','tests/frost/test_ppa_wu05b20_multilevel_globals.f90','reference/swap-4.3.1/b1_11_frost_source/SWAP/divdra.f90',cases[case][0]]
        ordered,_=M.DEP.strict_closure(ROOT,[cases[case][0]],[M.STUB,'tests/fmr/mod_fmr04_fixed_top_provider.f90'])
        sources=M.relative(ordered[:-1])
        if M.STUB in sources:sources+=['src/legacy/b1_10_port/headcalc.f90']
        return sources+[cases[case][0]]
    M.plan=plan
    for name,(driver,marker) in cases.items():M.CASES[name]={'driver':driver,'marker':marker,'flags':M.COMMON}
    session=M.Session(a.output);results=[]
    try:
        for case in cases:
            pair=[session.execute(case,opt) for opt in (0,2)]
            assert pair[0]['stdout_sha256']==pair[1]['stdout_sha256'],case
            results+=pair
            M.write(session.out/'result.json',{'candidate':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'results':results,'events':session.events})
            print(case+' O0/O2 PASS',flush=True)
    finally:
        M.write(session.out/'events.json',session.events)
if __name__=='__main__':main()
