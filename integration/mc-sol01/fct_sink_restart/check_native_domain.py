"""Discriminating real-interface probe before native FCT dispatch promotion."""
import argparse,hashlib,importlib.util,json,os,runpy,stat,subprocess,tempfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);a=ap.parse_args();out=a.output.resolve();out.mkdir(exist_ok=False,parents=True)
 g=runpy.run_path(str(HERE.parent/'fct_sinks/generate.py'));parts=g['sources']();parts.pop('joint_driver.f90')
 text=(HERE.parent/'fct_sinks/process_driver.f90').read_text().split(' startmass=')[0]
 text=text.replace(' integer,parameter::n=16',' integer::domain\n integer,parameter::n=16')
 text=text.replace('f%dz_cm=spread(1d0,1,n)','f%dz_cm=spread(1d0,1,n)\n call get_command_argument(6,arg);read(arg,*)domain\n if(domain==1)f%dz_cm(8)=2d0')
 text=text.replace('call initialize_solute_compartment_state(.26d0*initial**exponent,','call initialize_solute_compartment_state(.26d0*initial**exponent*f%dz_cm,')
 text+=''' f%face_distance_cm=.5d0*(f%dz_cm(:n-1)+f%dz_cm(2:))
 f%face_left_weight=.5d0*f%dz_cm(2:)/f%face_distance_cm
 f%face_right_weight=.5d0*f%dz_cm(:n-1)/f%face_distance_cm
 f%theta=f%theta_previous-dt*(f%root_sink_cm_day+sum(f%qdra_cm_day,dim=1))/f%dz_cm
 if(domain==2)f%pond_end_cm=.1d0
 call advance_b111_reactive_solute_substep(m,s,f,plain,plain_s,rp,exact_empty_pond_limit=.true.)
 if(rp%status/=0)error stop 'production reference rejected probe'
 call advance_research_sink_fct(m,s,f,.true.,next,next_s,r)
 if(domain==0.and.r%status/=0)error stop 'qualified control rejected'
 if(domain>0)then
  if(r%status==0)error stop 'unsupported domain silently admitted'
  if(any(next%mass_mg_cm2/=m%mass_mg_cm2).or.any(next_s%sorbed_matrix_mass/=s%sorbed_matrix_mass))error stop 'rejected state modified'
 end if
 print *, 'NATIVE_DOMAIN_PROBE',domain,rp%status,r%status
end program
'''
 parts['domain_driver.f90']=text.encode()
 for name,b in parts.items():(out/name).write_bytes(b)
 dep=ROOT/'tests/support/augment_bartholomeus_backend_sources.py';spec=importlib.util.spec_from_file_location('deps',dep);deps=importlib.util.module_from_spec(spec);spec.loader.exec_module(deps)
 with tempfile.TemporaryDirectory(dir=ROOT,prefix='.fct-domain-')as tmp:
  lookup={}
  for name,b in parts.items():
   p=Path(tmp)/name;p.write_bytes(b);lookup[p]=out/name
  sources,_=deps.strict_closure(ROOT,[str(Path(tmp)/'domain_driver.f90')],[*map(str,lookup),str(HERE.parent/'fct_reactive/mod_research_composed_fct.f90')])
  sources=[lookup.get(p,p) for p in sources]
 r=dict(baseline=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),closure=list(map(str,sources)),events=[],status='RUNNING')
 for opt in ['O0','O2']:
  folder=out/opt;folder.mkdir();exe=folder/'probe'
  commands=[[os.environ['FC'],'-'+opt,'-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(folder),*map(str,sources),'-o',str(exe)]]
  commands.extend([[str(exe),'0','1','1','1','4',str(i)]for i in [0,1,2]])
  for cmd in commands:
   if Path(cmd[0])==exe and exe.exists():exe.chmod(exe.stat().st_mode|stat.S_IXUSR)
   t=time.monotonic();cp=subprocess.run(cmd,cwd=folder,capture_output=True,timeout=180)
   event=dict(command=cmd,returncode=cp.returncode,seconds=time.monotonic()-t,stdout=cp.stdout.decode(),stderr=cp.stderr.decode());r['events'].append(event)
   (out/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n');assert cp.returncode==0,event
 r['status']='NATIVE_DOMAIN_GAPS_REPRODUCED_O0_O2';(out/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
if __name__=='__main__':main()
