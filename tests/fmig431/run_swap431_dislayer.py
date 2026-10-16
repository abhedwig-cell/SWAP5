#!/usr/bin/env python3
"""Small real binder first, then only affected real runtime and preservation."""
import argparse,importlib.util,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('modular',ROOT/'tests/modularity/run_modular_tests.py');M=importlib.util.module_from_spec(spec);spec.loader.exec_module(M)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);ap.add_argument('--process-only',action='store_true');a=ap.parse_args()
 cases={'dislayer_contract':('tests/fmig431/test_swap431_dislayer_contract.f90','DISLAYER_CORRECTED_SOURCE_REAL_BINDER_MATRIX=PASS')}
 if not a.process_only:
  cases.update({'dislayer_guards':('tests/fmig431/test_swap431_dislayer_guards.f90','DISLAYER_PREPUBLICATION_GUARDS=PASS'),'inf_contract':('tests/fmig431/test_swap431_inf_split_contract.f90','INF_SPLIT_SOURCE_SHARED_INTEGRAL_LITERAL_BINDER=PASS'),'multilevel_contract':('tests/fmig431/test_swap431_multilevel_divdra_contract.f90','MULTILEVEL_LITERAL_ORIGINAL_BINDER_NEGATIVES=PASS'),'signed_contract':('tests/fmig431/test_swap431_signed_divdra_contract.f90','SIGNED_DIVDRA_LITERAL_B19_SIGNS_NEGATIVES_NONMUTATION=PASS'),'positive_process':('tests/fci/fci32_divdra_admission_smoke.f90','FCI32_DIVDRA_ADMISSION_SMOKE=PASS'),'positive_binder':('tests/fci/fci33_divdra_runtime_admission_smoke.f90','FCI33_DIVDRA_RUNTIME_ADMISSION_SMOKE=PASS')})
  for name,prefix in [('dislayer','DISLAYER'),('inf_split','INF'),('multilevel_divdra','MULTI'),('signed_divdra','SIGNED')]:cases[prefix.lower()+'_runtime']=('tests/fmig431/test_swap431_'+name+'_runtime.f90','SW431_'+prefix+'_INDEPENDENT_ACTIVE_RUNTIME_CALLSITE PASS')
 runtime=[p for p,_ in cases.values()if p.endswith('_runtime.f90')];prefix=None
 if runtime:
  ordered,_=M.DEP.strict_closure(ROOT,runtime,[M.STUB,'tests/fmr/mod_fmr04_fixed_top_provider.f90']);prefix=[p for p in M.relative(ordered)if p not in runtime]
  if M.STUB in prefix:prefix+=['src/legacy/b1_10_port/headcalc.f90']
 def plan(case,broad=False):
  if case.endswith('_runtime'):return prefix+[cases[case][0]]
  ref=None
  if case in ['dislayer_contract','inf_contract']:ref='reference/swap-4.3.1/frost-corrections/FROST-DIVDRA-'+('04'if case=='dislayer_contract'else'03')+'/divdra.f90'
  if case=='multilevel_contract':ref='reference/swap-4.3.1/b1_11_frost_source/SWAP/divdra.f90'
  ordered,_=M.DEP.strict_closure(ROOT,[cases[case][0]],(['tests/frost/test_ppa_wu05b20_multilevel_globals.f90']if ref else[M.STUB]))
  sources=M.relative(ordered[:-1])
  if ref:sources+=[ref]
  if M.STUB in sources:sources+=['src/legacy/b1_10_port/headcalc.f90']
  return sources+[cases[case][0]]
 M.plan=plan
 for name,(driver,marker)in cases.items():M.CASES[name]={'driver':driver,'marker':marker,'flags':M.COMMON}
 s=M.Session(a.output);s.share_modules=False if a.process_only else True;rows=[]
 try:
  for case in cases:
   s.share_modules=case.endswith('_runtime')
   pair=[s.execute(case,o)for o in(0,2)];assert pair[0]['stdout_sha256']==pair[1]['stdout_sha256'],case;rows+=pair
   M.write(s.out/'result.json',{'candidate':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'results':rows,'events':s.events});print(case+' O0/O2 PASS',flush=True)
 finally:M.write(s.out/'events.json',s.events)
if __name__=='__main__':main()
