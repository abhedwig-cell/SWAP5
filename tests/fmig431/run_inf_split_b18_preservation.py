#!/usr/bin/env python3
"""Fresh unchanged B18 native drivers and its original scientific assertions.

Historical whole-file pins are not relabelled as current. This candidate records
its actual hashes and additionally reconstructs the unchanged default B19 body.
"""
import argparse,ast,gzip,hashlib,importlib.util,json,subprocess,textwrap
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
SPEC=importlib.util.spec_from_file_location('session',ROOT/'tests/modularity/run_modular_tests.py')
M=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(M)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);a=ap.parse_args();session=M.Session(a.output)
 status=json.loads((ROOT/'integration/audits/PPA_WU05B17_REF_STATUS.json').read_text());e=status['evidence'];raw=(ROOT/e['path']).read_bytes()
 assert status['qualified'] and status['admitted'] and hashlib.sha256(raw).hexdigest()==e['sha256']
 record=json.loads(gzip.decompress(raw));inputs=record['manifest']['actual/cases.txt']['content']
 common=['src/solver/mod_soil_water_solver_contract.f90','src/solver/mod_process_hydraulic_view.f90','src/process/mod_drainage_spatial_distribution.f90','src/process/mod_frost_divdra_drainage_effect.f90']
 reference=['tests/frost/test_ppa_wu05b16_divdra_globals.f90','reference/swap-4.3.1/frost-corrections/FROST-DIVDRA-02/divdra.f90','reference/swap-4.3.1/b1_11_frost_source/SWAP/frozencond.f90','tests/frost/test_ppa_wu05b16_divdra_owner.f90']
 build=session.out;results=[]
 for variant,files in [('reference',reference),('typed',common+reference[:-1]+['tests/frost/test_ppa_wu05b18_divdra_component.f90'])]:
  for opt in (0,2):
   d=build/variant/f'o{opt}';d.mkdir(parents=True)
   flags=['-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow',f'-O{opt}']
   _,ce=session.command([session.compiler,*flags,'-J',str(d),'-I',str(d),*[str(ROOT/f)for f in files],'-o',str(d/'test')],d,'b18-compile-link')
   output,ne=session.command([str(d/'test')],d,'b18-native',input_bytes=inputs.encode());(d/'output.txt').write_bytes(output)
   results.append({'variant':variant,'optimization':opt,'flags':flags,'inputs':{f:M.sha(ROOT/f)for f in files},'source_count':len(files),'compile_link_seconds':ce['wall_seconds'],'native_seconds':ne['wall_seconds'],'stdout_sha256':hashlib.sha256(output).hexdigest(),'executable_sha256':M.sha(d/'test')})
  assert (build/variant/'o0/output.txt').read_bytes()==(build/variant/'o2/output.txt').read_bytes()
 # Execute the original native comparison assertions verbatim, including all
 # 4536 comparisons, 3240 accepted/1296 tiny holds, original mass thresholds,
 # 32 invalid cases and two exact/just-beyond-offset geometry cases.
 path=ROOT/'tests/frost/run_ppa_wu05b18_divdra_component.py';source=path.read_text()
 start=source.index("    assert (build/'reference/o0/output.txt').read_text()==record[")
 end=source.index('    result=dict(',start)
 assertions=textwrap.dedent(source[start:end]);scope={'build':build,'record':record,'inputs':inputs}
 exec(compile(assertions,str(path),'exec'),scope)
 result={'case':'B18_UNCHANGED_DEFAULT_PRODUCTION_PRESERVATION','status':'PASS','results':results,'events':session.events,'compiler_identity':session.identity,'original_assertions_sha256':hashlib.sha256(assertions.encode()).hexdigest(),'original_runner_sha256':M.sha(path),'original_reference_evidence':e,'accepted':scope['accepted'],'held':scope['held'],'max_nodes':scope['max_nodes'],'max_scalar':scope['max_scalar'],'max_closure':scope['max_closure'],'max_correction':scope['max_correction']}
 M.write(build/'result.json',result);print('INF_SPLIT_B18_ORIGINAL_4536_ASSERTIONS_O0_O2=PASS',flush=True)
if __name__=='__main__':main()
