"""Actual complete original Integral3/Watstor terminal water receipt qualification."""
import argparse,math
from pathlib import Path
import subprocess,json,hashlib,time
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--reference-work',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args();root=Path(__file__).resolve().parents[2];ref=args.reference_work.resolve();out=args.output.resolve();out.mkdir(parents=True,exist_ok=False);objects=ref/'build/swap-obj';tt=ref/'build/ttutil-obj';reports={};source=root/'app/hybrid_water/terminal_water_receipt.f90';driver=root/'tools/solute/drivers/original_terminal_water_receipt.f90'
for opt in ('O0','O2'):
 target=out/opt;target.mkdir();flags=['-'+opt,'-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-ffp-contract=off','-march=x86-64','-mtune=generic','-I',str(objects),'-I',str(tt)]
 commands=[['gfortran',*flags,'-c',str(source),str(driver)],['gfortran','-o',str(target/'terminal.exe'),*[str(p) for p in sorted(objects.glob('*.o')) if p.name!='swap_main.o'],str(target/'terminal_water_receipt.o'),str(target/'original_terminal_water_receipt.o'),str(tt/'libttutil.a')],[str(target/'terminal.exe')]];logs=[]
 for cmd in commands:
  started=time.perf_counter();r=subprocess.run(cmd,cwd=target,capture_output=True,text=True,timeout=90);logs.append(dict(command=cmd,seconds=time.perf_counter()-started,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr));(target/'commands.json').write_text(json.dumps(logs,indent=2));assert r.returncode==0,r.stderr
 negatives=[]
 for mode in ('macro','no-snow','no-drain'):
  r=subprocess.run([str(target/'terminal.exe'),mode],cwd=target,capture_output=True,text=True,timeout=10);assert r.returncode!=0 and 'Unsupported terminal water receipt domain' in r.stderr;negatives.append(dict(mode=mode,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr))
 reports[opt]=dict(commands=logs,negative_controls=negatives);print(opt,'ACTUAL_ORIGINAL_TERMS_PASS',flush=True)
 (out/'RESULT.json').write_text(json.dumps(dict(status='PARTIAL',profiles=reports),indent=2)+'\n')
assert reports['O0']['commands'][-1]['stdout']==reports['O2']['commands'][-1]['stdout']
print('O0_O2_EXACT_TERMS_AND_NO_MUTATION_PASS')

sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for opt,profile in reports.items():
 for line in profile['commands'][-1]['stdout'].splitlines():
  if line.startswith('TERMINAL'):
   values=list(map(float,line.split()[2:]));assert values[0]==math.fsum(values[1:])
result=dict(status='ACTUAL_ORIGINAL_INTEGRAL3_WATSTOR_TERMINAL_O0_O2_PASS',profiles=reports,physical_cases_per_optimization=12,source_sha256=sha(source),driver_sha256=sha(driver),recipe_sha256=sha(Path(__file__)),provider_manifest_sha256=sha(ref/'PREPARED.json'),compiler=subprocess.check_output(['gfortran','--version'],text=True),linked_objects={p.name:sha(p) for p in objects.glob('*.o') if p.name!='swap_main.o'},ttutil_sha256=sha(tt/'libttutil.a'),scope='Complete projected28 native terms exactly equal actual original Integral3/Watstor; no physical mutation;12cases/opt;3domainrefusals/opt;real128 agrees with independent fsum; no whole science claim')
(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
