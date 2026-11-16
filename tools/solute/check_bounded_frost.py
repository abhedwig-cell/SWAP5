"""Actual original/guarded MOD_frost in complete immutable original native closure."""
import argparse,hashlib,json,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'app/hybrid_water'))
from frost_reference import source
from daily_host import NO_MACRO_FP_FLAGS
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();ref=a.reference_work.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 prepared=json.loads((ref/'PREPARED.json').read_text());original=ref/'build/swap-selected/frozencond.f90';assert sha(original)==prepared['provider_files']['build/swap-selected/frozencond.f90'];guarded=source(original.read_bytes())
 objects=ref/'build/swap-obj';ttutil=ref/'build/ttutil-obj';driver=ROOT/'tools/solute/drivers/original_bounded_frost.f90';reports={}
 for opt in ('O0','O2'):
  profiles={}
  for kind,body in [('original',original.read_bytes()),('guarded',guarded)]:
   target=out/(opt+'-'+kind);target.mkdir();generated=target/'frozencond.f90';generated.write_bytes(body)
   flags=['-'+opt,'-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch','-fcheck=all','-ffpe-trap=invalid,zero,overflow',*NO_MACRO_FP_FLAGS,'-I',str(objects),'-I',str(ttutil)]+(['-DGUARDED'] if kind=='guarded' else [])
   commands=[['gfortran',*flags,'-c',str(generated),str(driver)],['gfortran','-o',str(target/'frost.exe'),*[str(o) for o in sorted(objects.glob('*.o')) if o.name not in ('swap_main.o','frozencond.o')],str(target/'frozencond.o'),str(target/'original_bounded_frost.o'),str(ttutil/'libttutil.a')]]
   compilation=[]
   for cmd in commands:
    r=subprocess.run(cmd,cwd=target,capture_output=True,text=True,timeout=120);compilation.append(dict(command=cmd,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr));assert r.returncode==0,r.stderr
   records=[]
   for mode in ['valid','uniform','epsilon','nan','limits','grid','drain-index']:
    r=subprocess.run([str(target/'frost.exe'),mode],capture_output=True,text=True,timeout=15);(target/(mode+'.stdout')).write_text(r.stdout);(target/(mode+'.stderr')).write_text(r.stderr)
    if mode=='valid':assert r.returncode==0 and 'ACTUAL_ORIGINAL_FROST_CASES          24' in r.stdout,(kind,r.stdout,r.stderr)
    elif kind=='guarded':assert r.returncode!=0 and 'UNEXPECTED_INVALID_PHYSICAL_PUBLICATION' not in r.stdout and ('FROST_GEOMETRY_UNAVAILABLE' in r.stderr or 'FROST_DRAIN_GEOMETRY_INVALID' in r.stderr),(mode,r.stdout,r.stderr)
    records.append(dict(mode=mode,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr))
   profiles[kind]=dict(compilation=compilation,records=records,source_sha256=sha(generated),executable_sha256=sha(target/'frost.exe'))
  physical=lambda kind:[s for s in profiles[kind]['records'][0]['stdout'].splitlines() if s.startswith('PHYSICAL')]
  assert len(physical('original'))==24 and physical('original')==physical('guarded')
  profiles['physical_cases_exact_original_guarded']=24;reports[opt]=profiles
  (out/'RESULT.json').write_text(json.dumps(dict(status='PARTIAL_COMPONENT_RECORD',profiles=reports,driver_sha256=sha(driver),recipe_sha256=sha(ROOT/'app/hybrid_water/frost_reference.py'),compiler=prepared['toolchain']['gfortran'],source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),scope='Complete original native closure, 24valid physical cases/opt identical; reporting correction measured separately, original invalid-domain failures retained; no model/macro execution'),indent=2)+'\n')
 assert [s for s in reports['O0']['guarded']['records'][0]['stdout'].splitlines() if s.startswith(('PHYSICAL','REPORT'))]==[s for s in reports['O2']['guarded']['records'][0]['stdout'].splitlines() if s.startswith(('PHYSICAL','REPORT'))]
 q=json.loads((out/'RESULT.json').read_text());q['status']='ACTUAL_ORIGINAL_GUARDED_FROST_COMPONENT_O0_O2_PASS';q['original_reporting_differences']={o:sum(a!=b for a,b in zip([s for s in v['original']['records'][0]['stdout'].splitlines() if s.startswith('REPORT')],[s for s in v['guarded']['records'][0]['stdout'].splitlines() if s.startswith('REPORT')])) for o,v in reports.items()};(out/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 print(q['status'])

if __name__=='__main__':main()
