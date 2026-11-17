"""Actual original tabulated lateral drainage in its native O0/O2 closure."""
import argparse,hashlib,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();ref=a.reference_work.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);source=ref/'build/swap-selected/drainage.f90';objects=ref/'build/swap-obj';tt=ref/'build/ttutil-obj';driver=ROOT/'tools/solute/drivers/original_tabulated_drainage.f90';prepared=json.loads((ref/'PREPARED.json').read_text());assert sha(source)==prepared['provider_files']['build/swap-selected/drainage.f90'];reports={}
 for opt in ('O0','O2'):
  target=out/opt;target.mkdir();flags=['-'+opt,'-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-ffp-contract=off','-march=x86-64','-mtune=generic','-I',str(objects),'-I',str(tt)]
  commands=[['gfortran',*flags,'-c',str(source),str(driver)],['gfortran','-o',str(target/'table_drain.exe'),*[str(x) for x in sorted(objects.glob('*.o')) if x.name not in ('swap_main.o','drainage.o')],str(target/'drainage.o'),str(target/'original_tabulated_drainage.o'),str(tt/'libttutil.a')],[str(target/'table_drain.exe')]];logs=[]
  for cmd in commands:
   start=time.perf_counter();r=subprocess.run(cmd,cwd=target,capture_output=True,text=True,timeout=90);logs.append(dict(command=cmd,seconds=time.perf_counter()-start,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr));(target/'commands.json').write_text(json.dumps(logs,indent=2)+'\n');assert r.returncode==0,r.stderr
  assert sum(s.startswith('TABLE_DRAIN') for s in logs[-1]['stdout'].splitlines())==15;reports[opt]=dict(records=logs,executable_sha256=sha(target/'table_drain.exe'));print(opt,'ORIGINAL_TABLE_DRAINAGE_15_CASES_PASS',flush=True)
 assert reports['O0']['records'][-1]['stdout']==reports['O2']['records'][-1]['stdout']
 result=dict(status='ACTUAL_ORIGINAL_TABULATED_DRAINAGE_O0_O2_PASS',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),source_sha256=sha(source),driver_sha256=sha(driver),recipe_sha256=sha(Path(__file__)),provider_manifest_sha256=sha(ref/'PREPARED.json'),physical_cases_per_optimization=15,profiles=reports,linked_objects={p.name:sha(p) for p in objects.glob('*.o') if p.name not in ('swap_main.o','drainage.o')},ttutil_sha256=sha(tt/'libttutil.a'),scope='Complete original Drainage/DrainFluxBasic native closure, positive/signed/zero table and no groundwater; actual AFGEN and exact total/last-node partition; component does not qualify coupled SWDIVD1/solute/native model trajectories',science='NOT_QUALIFIED');(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'])
if __name__=='__main__':main()
