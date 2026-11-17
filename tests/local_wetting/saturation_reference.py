"""Bounded independent B0 endpoint-resolution diagnostic, not production repair."""
from pathlib import Path
import argparse,csv,json,shutil,subprocess,time
from run import ROOT,m
def rows(p):return list(csv.DictReader(x for x in p.read_text(encoding='cp1252').splitlines() if x and not x.startswith('*')))
def main():
 p=argparse.ArgumentParser();p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();ref=a.reference_work/'build';nominal=rows(out/'finish-controls/water-surface-history-original431/result_output.csv');candidate=rows(out/'water-surface-history-O2-full/original/result_output.csv');result=dict(kind='DIAGNOSTIC_ORIGINAL431_LATE_TIME_REFINEMENT_NOT_QUALIFIED_REFERENCE',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),tolerances_changed=False,profiles={})
 for label,cap in (('dt004',0.004),('dt0004',0.0004)):
  build=out/('late-reference-'+label+'-build');build.mkdir();source=build/'swap.f90';s=(ref/'swap-selected/swap.f90').read_text(encoding='cp1252');s=s.replace('gwl, gwlm1, dt, t1900','gwl, gwlm1, dt, dtmax, t1900');anchor='         call TimeControl(2)';assert s.count(anchor)==1;s=s.replace(anchor,f'         if(t1900>=37618d0)then\n            dtmax={cap:.17g}d0;dt=min(dt,dtmax)\n         endif\n'+anchor);source.write_text(s,encoding='cp1252')
  flags=['-O2','-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch','-ffp-contract=off','-march=x86-64','-mtune=generic','-I',str(ref/'swap-obj'),'-I',str(ref/'ttutil-obj')];exe=build/'original_late_refinement.exe';commands=[['gfortran',*flags,'-c',str(source)],['gfortran','-o',str(exe),*[str(build/x.name if x.name=='swap.o' else x) for x in sorted((ref/'swap-obj').glob('*.o'))],str(ref/'ttutil-obj/libttutil.a')]]
  for cmd in commands:
   r=subprocess.run(cmd,cwd=build,capture_output=True,text=True,timeout=30);assert r.returncode==0,r.stderr
  folder=out/('late-reference-'+label);shutil.copytree(out/'finish-controls/water-surface-history-literal-input',folder);p=folder/'swap.swp';s=p.read_text(encoding='cp1252');assert 'TEND = 2004-12-31' in s;p.write_text(s.replace('TEND = 2004-12-31','TEND = 2002-12-31'),encoding='cp1252');start=time.perf_counter()
  with (folder/'stdout').open('wb') as log:r=subprocess.run([str(exe),'./swap.swp'],cwd=folder,stdout=log,stderr=subprocess.STDOUT,timeout=20)
  data=rows(folder/'result_output.csv');assert (folder/'swap.ok').exists() and len(data)==366 and data[:363]==nominal[:363]
  result['profiles'][label]=dict(seconds=time.perf_counter()-start,original_own_day0through362_exact=True,source_sha256=m.sha(source),executable_sha256=m.sha(exe),commands=commands,day364=data[364],day364_candidate_minus_refined_GWL_cm=float(candidate[364]['GWL'])-float(data[364]['GWL']))
  (out/'SATURATION_REFERENCE.json').write_text(json.dumps(result,indent=2));print(label,result['profiles'][label]['seconds'],data[364]['GWL'],result['profiles'][label]['day364_candidate_minus_refined_GWL_cm'],flush=True)
if __name__=='__main__':main()
