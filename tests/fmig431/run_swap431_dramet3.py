#!/usr/bin/env python3
"""Real source/native contracts first; affected runtime only when selected."""
import argparse,base64,gzip,hashlib,importlib.util,json,re,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('modular',ROOT/'tests/modularity/run_modular_tests.py');M=importlib.util.module_from_spec(spec);spec.loader.exec_module(M)
def sha(b):return hashlib.sha256(b).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);ap.add_argument('--runtime',action='store_true');ap.add_argument('--defaults-only',action='store_true');a=ap.parse_args()
 s=M.Session(a.output);s.share_modules=False
 raw=(ROOT/'reference/swap-4.3.1/b1_11_frost_source/SWAP/drainage.f90').read_bytes()
 assert sha(raw)=='48e4792acd0a129a6939008bd51e82f9fed4668fcf8d28d03da0bc6efe6944cc'
 text=raw.decode();match=re.search(r'^\s*subroutine drainflux_basic\s*\(\).*?^\s*end subroutine drainflux_basic',text,re.M|re.S|re.I);assert match
 src=s.out/'original_drainflux_basic.f90';src.write_bytes(match.group().encode())
 carrier='integration/audits/F-MIG431_LOWER_BOUNDARY_B111_SOURCE.json';member=next(m for m in json.loads((ROOT/carrier).read_text())['members']if m['path']=='SWAP/functions.f90')
 fraw=gzip.decompress(base64.b64decode(member['gzip_base64']));assert sha(fraw)==member['sha256']
 match=re.search(r'^\s*real\(8\) function afgen .*?^\s*end function afgen',fraw.decode(),re.M|re.S|re.I);assert match
 af=s.out/'original_afgen.f90';af.write_bytes(match.group().encode())
 cases={'dramet3_contract':('tests/fmig431/test_swap431_dramet3_contract.f90','DRAMET3_REAL_SOURCE_NATIVE_BINDER=PASS')}
 if a.runtime:
  cases.update({'dramet3_runtime':('tests/fmig431/test_swap431_dramet3_runtime.f90','DRAMET3_REAL_TRIAL_RUNTIME=PASS'),'dislayer_runtime':('tests/fmig431/test_swap431_dislayer_runtime.f90','SW431_DISLAYER_INDEPENDENT_ACTIVE_RUNTIME_CALLSITE PASS'),'signed_runtime':('tests/fmig431/test_swap431_signed_divdra_runtime.f90','SW431_SIGNED_INDEPENDENT_ACTIVE_RUNTIME_CALLSITE PASS')})
 if a.defaults_only:
  cases={name:('tests/fmig431/test_swap431_response_preservation.f90','RESPONSE_DEFAULT_REAL_BINDER=PASS')for name in ['response_baseline','response_current']}
 old_binding=s.out/'baseline_response_binding.f90';old_binding.write_bytes(subprocess.check_output(['git','show','741f8a61b66dc8a91b3e18edfcb8121548b61f64:src/runtime/mod_fmr_drainage_response_binding.f90'],cwd=ROOT))
 runtime=[p for p,_ in cases.values()if p.endswith('_runtime.f90')];prefix=[]
 if runtime:
  ordered,_=M.DEP.strict_closure(ROOT,runtime,[M.STUB,'tests/fmr/mod_fmr04_fixed_top_provider.f90']);prefix=[p for p in M.relative(ordered)if p not in runtime]
  if M.STUB in prefix:prefix+=['src/legacy/b1_10_port/headcalc.f90']
 def plan(case,broad=False):
  if case.endswith('_runtime'):return prefix+[cases[case][0]]
  if case.startswith('response_'):
   ordered,_=M.DEP.strict_closure(ROOT,[cases[case][0]],['tests/frost/mod_ppa_wu05b12_analytic_fixture.f90','tests/frost/mod_ppa_wu05b14_extended_fixture.f90'])
   sources=M.relative(ordered)
   if case=='response_baseline':sources=[str(old_binding.resolve())if p=='src/runtime/mod_fmr_drainage_response_binding.f90'else p for p in sources]
   return sources
  ordered,_=M.DEP.strict_closure(ROOT,[cases[case][0]],['tests/fmig431/dramet3_native_globals.f90']);return M.relative(ordered[:-1])+[str(src.resolve()),str(af.resolve()),cases[case][0]]
 M.plan=plan
 for name,(driver,marker)in cases.items():M.CASES[name]={'driver':driver,'marker':marker,'flags':M.COMMON}
 rows=[]
 try:
  for case in cases:
   s.share_modules=case.endswith('_runtime');pair=[s.execute(case,o)for o in(0,2)];assert pair[0]['stdout_sha256']==pair[1]['stdout_sha256'],case;rows+=pair
   M.write(s.out/'result.json',{'candidate':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'source':{'drainage':sha(raw),'functions':sha(fraw),'extracted_drainflux':sha(src.read_bytes()),'extracted_afgen':sha(af.read_bytes()),'carrier':M.sha(ROOT/carrier)},'results':rows,'events':s.events});print(case+' O0/O2 PASS',flush=True)
  if a.defaults_only:assert len({r['stdout_sha256']for r in rows})==1,'incumbent response arithmetic changed'
 finally:M.write(s.out/'events.json',s.events)
if __name__=='__main__':main()
