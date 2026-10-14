#!/usr/bin/env python3
"""Observe original complete family with stage clocks; never an admission receipt."""
import argparse, hashlib, json, os, pathlib, resource, subprocess, time
ROOT = pathlib.Path(__file__).resolve().parents[2]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 a=argparse.ArgumentParser(description=__doc__);a.add_argument('--build',type=pathlib.Path,required=True);a.add_argument('--output',type=pathlib.Path,required=True);a.add_argument('--repeat',type=int,default=2);args=a.parse_args()
 b=args.build.resolve();out=args.output.resolve();out.mkdir(exist_ok=False,parents=True)
 m=json.loads((b/'RESULTS.json').read_text());flags=m['flags'];assert '-pg' not in flags
 for p,h in m['sources'].items():assert sha(pathlib.Path(p))==h,p
 text=(b/'low_air_driver.f90').read_text();original=text
 text=text.replace('  implicit none\n','  implicit none\n  real(real64) :: phase_sum(6,2)=0._real64\n',1)
 # Only observations are added; the original physical calls and assertions stay exact.
 needle="  subroutine execute_case("
 assert text.count(needle)==1
 split=text.index(needle);prefix=text[:split];body=text[split:]
 body=body.replace('    real(real64) :: t0\n','    real(real64) :: t0,phase_start,phase_end\n    integer :: phase_kind\n',1)
 body=body.replace('    call initialize_parameters(parameters, bottom_mode)',"    phase_kind=1\n    if(duration==1.e-4_real64/65536._real64)phase_kind=2\n    call cpu_time(phase_start)\n    call initialize_parameters(parameters, bottom_mode)",1)
 needles=['    if (use_certificate) then','    call initialize_forcing(forcing, top_flux, bottom_flux, bottom_head)','    template%template_id = 440001_int64','    call backend%initialize(top)','    observation = backend%observation()','  end subroutine execute_case']
 for k,n in enumerate(needles,1):
  assert n in body,n
  code=f'    call cpu_time(phase_end)\n    phase_sum({k},phase_kind)=phase_sum({k},phase_kind)+phase_end-phase_start\n    phase_start=phase_end\n'
  body=body.replace(n,code+n,1)
 text=prefix+body
 terminal="  print '(A)','PPA_WU05B15_LOW_AIR_LOW_AIR_DRAIN_RUNTIME=PASS'"
 assert text.count(terminal)==1
 text=text.replace(terminal,terminal+"\n  print *, 'LOW_AIR_PHASE_ADAPTIVE',phase_sum(:,1)\n  print *, 'LOW_AIR_PHASE_FINE',phase_sum(:,2)")
 objects=[b/f'{i}.o' for i in range(len(m['ordered_sources'])-1)]
 report={'scope':'OBSERVATIONAL_COMPLETE_FAMILY_1_NOT_QUALIFICATION','build_manifest_sha256':sha(b/'RESULTS.json'),'source_sha256':{str(p):sha(p) for p in objects},'labels':['parameter_frost_setup','committed_state','forcing_response_setup','metadata_config','resolved_runtime','observation_snapshot'],'runs':[]}
 for name,s in [('plain',original),('phase',text)]:
  p=out/(name+'.f90');p.write_text(s)
  subprocess.run(['gfortran',*flags,'-J',str(b),'-I',str(b),'-c',str(p),'-o',str(out/(name+'.o'))],check=True)
  subprocess.run(['gfortran',*flags,*map(str,objects),str(out/(name+'.o')),'-o',str(out/name)],check=True)
 for rnd in range(args.repeat):
  for name in (['plain','phase'] if rnd%2==0 else ['phase','plain']):
   start=time.monotonic();before=resource.getrusage(resource.RUSAGE_CHILDREN)
   with (out/f'{rnd}-{name}.stdout').open('w')as so,(out/f'{rnd}-{name}.stderr').open('w')as se:
    cp=subprocess.run([str(out/name),'1'],stdout=so,stderr=se,timeout=120,env={**os.environ,'GFORTRAN_UNBUFFERED_ALL':'y'})
   after=resource.getrusage(resource.RUSAGE_CHILDREN);lines=(out/f'{rnd}-{name}.stdout').read_text().splitlines()
   science='\n'.join(l for l in lines if not l.lstrip().startswith('LOW_AIR_PHASE'))+'\n'
   record={'round':rnd,'name':name,'wall':time.monotonic()-start,'cpu':after.ru_utime+after.ru_stime-before.ru_utime-before.ru_stime,'exit':cp.returncode,'science_sha256':hashlib.sha256(science.encode()).hexdigest(),'phases':[l.strip()for l in lines if l.lstrip().startswith('LOW_AIR_PHASE')]}
   report['runs'].append(record);(out/'RESULTS.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(record),flush=True)
   assert cp.returncode==0 and science.count('_RUNTIME=PASS')==1
 assert len({x['science_sha256']for x in report['runs']})==1
 report['science_identity']=True;(out/'RESULTS.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
