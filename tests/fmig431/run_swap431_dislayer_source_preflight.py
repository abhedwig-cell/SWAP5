#!/usr/bin/env python3
"""Run actual legacy/corrected DIVDRA and existing production transform only.

A diagnostic PASS reproduces the source defect. It is not physical admission.
"""
import argparse,importlib.util,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('modular',ROOT/'tests/modularity/run_modular_tests.py')
M=importlib.util.module_from_spec(spec);spec.loader.exec_module(M)
DRIVER='tests/fmig431/test_swap431_dislayer_source_preflight.f90'
REFERENCES={'b111':'reference/swap-4.3.1/b1_11_frost_source/SWAP/divdra.f90','b20_admitted03':'reference/swap-4.3.1/frost-corrections/FROST-DIVDRA-03/divdra.f90'}
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);a=ap.parse_args()
 def plan(case,broad=False):return ['tests/frost/test_ppa_wu05b20_multilevel_globals.f90',REFERENCES[case],'src/process/mod_drainage_discharge_layer_transform.f90',DRIVER]
 M.plan=plan
 for case in REFERENCES:M.CASES[case]={'driver':DRIVER,'marker':'DISLAYER_SOURCE_AND_EXISTING_CANDIDATE_NONCONSERVATION_REPRODUCED=PASS','flags':M.COMMON}
 session=M.Session(a.output);session.share_modules=False;rows=[] # native submodule needs .smod; no prefix reuse
 try:
  for case in REFERENCES:
   pair=[session.execute(case,opt)for opt in(0,2)]
   assert pair[0]['stdout_sha256']==pair[1]['stdout_sha256']
   rows+=pair
  assert len({r['stdout_sha256']for r in rows})==1
  M.write(session.out/'result.json',{'candidate':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'results':rows,'events':session.events,'diagnostic':'SOURCE_DEFECT_REPRODUCED','qualified':False,'admitted':False,'ledger_rows_closed':[]})
  print('DISLAYER_B111_AND_ADMITTED03_ORIGINAL_SOURCE_CANDIDATE_O0_O2_COUNTEREXAMPLE=PASS')
 finally:M.write(session.out/'events.json',session.events)
if __name__=='__main__':main()
