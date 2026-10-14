#!/usr/bin/env python3
"""Same-driver bounded instrumentation of selected real native interfaces.

Exclusive buckets contain uninstrumented descendants. Instrumentation overhead
is measured against alternating plain runs; output is observational, not admission.
"""
import argparse,hashlib,json,os,pathlib,resource,subprocess,time
ROOT=pathlib.Path(__file__).resolve().parents[2]
TARGETS={'mod_fmr_serialized_reference_backend.f90','mod_reference_richards_legacy_binding.f90','headcalc.f90','mod_b110_default_mvg_provider.f90','mod_reference_linear_solver.f90'}
CALLBACK=r'''
#include <stdint.h>
#include <stdio.h>
#include <time.h>
#include <stdlib.h>
typedef struct { void *fn; uint64_t start, child; } Frame;
typedef struct { void *fn; uint64_t calls, inclusive, exclusive; } Row;
static Frame frames[1024]; static Row rows[4096]; static unsigned depth, used;
static uint64_t now(void) {struct timespec t; if(clock_gettime(CLOCK_THREAD_CPUTIME_ID,&t))abort();return (uint64_t)t.tv_sec*1000000000+t.tv_nsec;}
void __cyg_profile_func_enter(void *fn, void *caller) { (void)caller; if(depth==1024)abort();frames[depth++]=(Frame){fn,now(),0}; }
void __cyg_profile_func_exit(void *fn, void *caller) {
 (void)caller; uint64_t end=now();if(!depth)abort();Frame f=frames[--depth];if(f.fn!=fn)abort();uint64_t duration=end-f.start;
 unsigned i;for(i=0;i<used;i++)if(rows[i].fn==fn)break;if(i==used){if(used==4096)abort();rows[used++].fn=fn;}
 rows[i].calls++;rows[i].inclusive+=duration;rows[i].exclusive+=duration-f.child;if(depth)frames[depth-1].child+=duration;
}
static void finish(void) {if(depth)abort();for(unsigned i=0;i<used;i++)fprintf(stderr,"LOW_AIR_NATIVE %p %llu %llu %llu\n",rows[i].fn,(unsigned long long)rows[i].calls,(unsigned long long)rows[i].inclusive,(unsigned long long)rows[i].exclusive);}
__attribute__((constructor)) static void setup(void) {atexit(finish);}
'''
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 a=argparse.ArgumentParser(description=__doc__);a.add_argument('--build',type=pathlib.Path,required=True);a.add_argument('--output',type=pathlib.Path,required=True);a.add_argument('--bounded-fine',type=int,choices=[1024,4096]);args=a.parse_args()
 b=args.build.resolve();out=args.output.resolve();out.mkdir(parents=True,exist_ok=False);m=json.loads((b/'RESULTS.json').read_text());flags=m['flags']
 for p,h in m['sources'].items():assert sha(pathlib.Path(p))==h,p
 objects=[b/f'{i}.o'for i in range(len(m['ordered_sources']))];prof=list(objects)
 if args.bounded_fine:
  text=(b/'low_air_driver.f90').read_text()
  needle='      call execute_case(2,0._real64,q,-999999._real64,1.e-4_real64,.false.,.true.,'
  assert text.count(needle)==2
  text=text.replace(needle,needle.replace('1.e-4_real64','1.e-7_real64'))
  assert text.count('      do i=1,65536')==1
  text=text.replace('      do i=1,65536',f'      do i=1,{args.bounded_fine}')
  needle='      call copy_soil_temperature_profile(final%soil_temperature,tf,status)'
  assert text.count(needle)==1
  text=text.replace(needle,"      print *, 'LOW_AIR_BOUNDED_FINE_OBSERVATION_COMPLETE'\n      stop\n"+needle)
  p=out/'bounded_driver.f90';p.write_text(text);obj=out/'bounded_driver.o'
  subprocess.run(['gfortran',*flags,'-J',str(b),'-I',str(b),'-c',str(p),'-o',str(obj)],check=True)
  objects[-1]=obj;prof[-1]=obj

 (out/'callback.c').write_text(CALLBACK);subprocess.run(['gcc','-O2','-c',str(out/'callback.c'),'-o',str(out/'callback.o')],check=True)
 for i,s in enumerate(m['ordered_sources']):
  p=pathlib.Path(s)
  if p.name in TARGETS:
   obj=out/f'{i}.o';subprocess.run(['gfortran',*flags,'-finstrument-functions','-J',str(b),'-I',str(b),'-c',str(p),'-o',str(obj)],check=True);prof[i]=obj
 for name,objs in [('plain',objects),('native',prof+[out/'callback.o'])]:subprocess.run(['gfortran',*flags,'-no-pie',*map(str,objs),'-o',str(out/name)],check=True)
 nm=subprocess.check_output(['nm','-n',str(out/'native')],text=True);(out/'symbols.txt').write_text(nm)
 symbols={int(l.split()[0],16):l.split()[2]for l in nm.splitlines()if len(l.split())==3 and l.split()[1]in ['t','T']}
 report={'scope':'OBSERVATIONAL_BOUNDED_FINE_NOT_QUALIFICATION' if args.bounded_fine else 'OBSERVATIONAL_NATIVE_COMPLETE_FAMILY_1_NOT_QUALIFICATION','bounded_fine_steps':args.bounded_fine,'target_sources':sorted(TARGETS),'build_manifest_sha256':sha(b/'RESULTS.json'),'runs':[]}
 for rnd in range(2):
  for name in (['plain','native'] if rnd==0 else ['native','plain']):
   start=time.monotonic();before=resource.getrusage(resource.RUSAGE_CHILDREN)
   with (out/f'{rnd}-{name}.stdout').open('w')as so,(out/f'{rnd}-{name}.stderr').open('w')as se:cp=subprocess.run([str(out/name),'1'],stdout=so,stderr=se,timeout=180,env={**os.environ,'GFORTRAN_UNBUFFERED_ALL':'y'})
   after=resource.getrusage(resource.RUSAGE_CHILDREN)
   rows=[]
   for l in (out/f'{rnd}-{name}.stderr').read_text().splitlines():
    if l.startswith('LOW_AIR_NATIVE '):
     _,addr,calls,inc,exc=l.split();rows.append({'symbol':symbols.get(int(addr,16),'UNKNOWN_'+addr),'calls':int(calls),'inclusive_cpu':int(inc)/1e9,'exclusive_bucket_cpu':int(exc)/1e9})
   rec={'name':name,'round':rnd,'exit':cp.returncode,'wall':time.monotonic()-start,'cpu':after.ru_utime+after.ru_stime-before.ru_utime-before.ru_stime,'stdout_sha256':sha(out/f'{rnd}-{name}.stdout'),'rows':sorted(rows,key=lambda r:-r['exclusive_bucket_cpu'])}
   report['runs'].append(rec);(out/'RESULTS.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in rec.items()if k!='rows'}),flush=True);assert cp.returncode==0
 assert len({r['stdout_sha256']for r in report['runs']})==1
 report['science_identity']=True;(out/'RESULTS.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
