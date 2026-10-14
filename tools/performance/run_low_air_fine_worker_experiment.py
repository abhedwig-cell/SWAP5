#!/usr/bin/env python3
"""Alternating original full family A/B, sole delta is fine workspace lifetime."""
import argparse,hashlib,json,os,pathlib,resource,subprocess,time
from low_air_fine_worker_recipe import reuse_fine_workspace
ROOT=pathlib.Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 a=argparse.ArgumentParser(description=__doc__);a.add_argument('--build',type=pathlib.Path,required=True);a.add_argument('--output',type=pathlib.Path,required=True);args=a.parse_args();b=args.build.resolve();out=args.output.resolve();out.mkdir(parents=True,exist_ok=False);m=json.loads((b/'RESULTS.json').read_text());flags=m['flags']
 for p,h in m['sources'].items():assert sha(pathlib.Path(p))==h,p
 objects=[b/f'{i}.o'for i in range(len(m['ordered_sources'])-1)]
 original=(b/'low_air_driver.f90').read_text();report={'scope':'COMPLETE_ORIGINAL_FAMILY_1_FINE_WORKER_AB_NOT_FULL_ADMISSION','build_sha256':sha(b/'RESULTS.json'),'objects':{str(p):sha(p)for p in objects},'runs':[]}
 for name,text in [('fresh',original),('workspace',reuse_fine_workspace(original))]:
  src=out/(name+'.f90');src.write_text(text)
  subprocess.run(['gfortran',*flags,'-J',str(b),'-I',str(b),'-c',str(src),'-o',str(out/(name+'.o'))],check=True)
  subprocess.run(['gfortran',*flags,*map(str,objects),str(out/(name+'.o')),'-o',str(out/name)],check=True)
 for rnd in range(2):
  for name in (['fresh','workspace']if rnd==0 else ['workspace','fresh']):
   start=time.monotonic();before=resource.getrusage(resource.RUSAGE_CHILDREN)
   with (out/f'{rnd}-{name}.stdout').open('w')as so,(out/f'{rnd}-{name}.stderr').open('w')as se:cp=subprocess.run([str(out/name),'1'],stdout=so,stderr=se,timeout=120,env={**os.environ,'GFORTRAN_UNBUFFERED_ALL':'y'})
   after=resource.getrusage(resource.RUSAGE_CHILDREN);r={'round':rnd,'name':name,'wall':time.monotonic()-start,'cpu':after.ru_utime+after.ru_stime-before.ru_utime-before.ru_stime,'exit':cp.returncode,'stdout_sha256':sha(out/f'{rnd}-{name}.stdout')};report['runs'].append(r);(out/'RESULTS.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(r),flush=True);assert cp.returncode==0
 assert len({r['stdout_sha256']for r in report['runs']})==1
 report['all_original_assertions_and_stdout_identical']=True;(out/'RESULTS.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
