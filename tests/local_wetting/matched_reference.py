"""Additional numerical-policy diagnostic, separate from unmodified B0 comparisons."""
from pathlib import Path
import argparse,csv,json,shutil,subprocess,time,hashlib
from run import ROOT,m
import local_wetting_time as policy
def rows(p):return list(csv.DictReader(s for s in p.read_text(encoding='cp1252').splitlines() if s and not s.startswith('*')))
def main():
 p=argparse.ArgumentParser();p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();build=out/'matched-reference-build';build.mkdir();ref=a.reference_work/'build';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
 src=build/'timecontrol.f90';src.write_bytes(policy.source((ref/'swap-selected/timecontrol.f90').read_bytes()));flags=['-O2','-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch','-ffp-contract=off','-march=x86-64','-mtune=generic','-I',str(ref/'swap-obj'),'-I',str(ref/'ttutil-obj')];exe=build/'original_with_explicit_wetting_policy.exe'
 commands=[['gfortran',*flags,'-c',str(src)],['gfortran','-o',str(exe),*[str(build/x.name if x.name=='timecontrol.o' else x) for x in sorted((ref/'swap-obj').glob('*.o'))],str(ref/'ttutil-obj/libttutil.a')]]
 for cmd in commands:
  r=subprocess.run(cmd,cwd=build,capture_output=True,text=True,timeout=30);assert r.returncode==0,r.stderr
 result=dict(kind='DIAGNOSTIC_ORIGINAL431_WITH_EXPLICIT_MATCHED_NUMERICAL_POLICY_NOT_B0',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),policy=policy.metadata((ref/'swap-selected/timecontrol.f90').read_bytes()),commands=commands,executable_sha256=sha(exe),provider_manifest_sha256=sha(a.reference_work/'PREPARED.json'),tolerances_changed=False,science='NOT_QUALIFIED',cases={})
 for key in ('water-surface-history','chemical-surface-history'):
  literal=out/'finish-controls'/(key+'-literal-input');folder=out/(key+'-matched-reference');shutil.copytree(literal,folder);start=time.perf_counter()
  with (folder/'stdout').open('wb') as log:r=subprocess.run([str(exe),'./swap.swp'],cwd=folder,stdout=log,stderr=subprocess.STDOUT,timeout=20)
  actual=rows(folder/'result_output.csv');candidate=rows(out/(key+'-O2-full/original/result_output.csv'));assert (folder/'swap.ok').exists() and len(actual)==len(candidate)==1097
  inventory={x.name:sha(x) for x in literal.iterdir() if x.is_file()};assert all(sha(folder/n)==h for n,h in inventory.items())
  fields=('GWL','WTOT','TACT','S_STOT');result['cases'][key]=dict(seconds=time.perf_counter()-start,returncode=r.returncode,rows=len(actual),literal_inputs=inventory,maximum_numeric_csv_differences={k:max(abs(float(x[k])-float(y[k])) for x,y in zip(candidate,actual)) for k in fields if k in actual[0]},day5_GWL_difference_cm=float(candidate[5]['GWL'])-float(actual[5]['GWL']),day215_GWL_difference_cm=float(candidate[215]['GWL'])-float(actual[215]['GWL']))
  (out/'MATCHED_REFERENCE.json').write_text(json.dumps(result,indent=2));print(key,result['cases'][key],flush=True)
if __name__=='__main__':main()
