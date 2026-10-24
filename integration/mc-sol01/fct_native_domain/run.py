"""Checked real-interface domain extension and independent finite volumes."""
import argparse,hashlib,importlib.util,itertools,json,os,runpy,stat,subprocess,tempfile,time
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);a=ap.parse_args();out=a.output.resolve();out.mkdir(exist_ok=False,parents=True)
 g=runpy.run_path(str(HERE/'generate.py'));parts=g['sources']()
 text=(HERE.parent/'fct_sinks/process_driver.f90').read_text().split(' startmass=')[0]
 text=text.replace('use mod_research_sink_fct','use mod_research_native_fct').replace(' integer,parameter::n=16',' integer::domain\n integer,parameter::n=16')
 text=text.replace('f%dz_cm=spread(1d0,1,n)','f%dz_cm=spread(1d0,1,n)\n call get_command_argument(6,arg);read(arg,*)domain\n if(domain==1.or.domain==3)f%dz_cm(8)=2d0')
 text=text.replace('call initialize_solute_compartment_state(.26d0*initial**exponent,','call initialize_solute_compartment_state(.26d0*initial**exponent*f%dz_cm,')
 text+=''' f%face_distance_cm=.5d0*(f%dz_cm(:n-1)+f%dz_cm(2:))
 f%face_left_weight=.5d0*f%dz_cm(2:)/f%face_distance_cm
 f%face_right_weight=.5d0*f%dz_cm(:n-1)/f%face_distance_cm
 f%theta=f%theta_previous-dt*(f%root_sink_cm_day+sum(f%qdra_cm_day,dim=1))/f%dz_cm
 if(domain>=2)then
  f%pond_end_cm=.2d0;s%pond_mass=.1d0;f%runoff_depth_cm=.01d0
  f%irrigation_rate_cm_day=.02d0;f%irrigation_c_mg_cm3=.3d0
  f%runon_rate_cm_day=.01d0;f%runon_c_mg_cm3=.4d0
 end if
 call advance_b111_reactive_solute_substep(m,s,f,plain,plain_s,rp,exact_empty_pond_limit=.true.)
 if(rp%status/=0)error stop 'production reference rejected probe'
 call advance_research_native_fct(m,s,f,.false.,test,test_s,rt)
 if(rt%status/=0.or.any(test%mass_mg_cm2/=plain%mass_mg_cm2).or. &
  any(test_s%sorbed_matrix_mass/=plain_s%sorbed_matrix_mass).or.test_s%pond_mass/=plain_s%pond_mass)error stop 'OFF drift'
 call advance_research_native_fct(m,s,f,.true.,next,next_s,r,l1,delta)
 if(r%status/=0)then
  print *,'FAILED',domain,mode,exponent,uptake,r%status;error stop 'extended domain rejected'
 end if
 if(next_s%pond_mass/=plain_s%pond_mass.or.r%pond_to_soil_mg_cm2/=rp%pond_to_soil_mg_cm2.or. &
  r%runoff_output_mg_cm2/=rp%runoff_output_mg_cm2)error stop 'surface owner changed'
 if(abs(r%balance_residual_mg_cm2)>1d-10)error stop 'balance'
 bad=f;bad%qdra_cm_day(1,1)=-.001d0
 call advance_research_native_fct(m,s,bad,.true.,test,test_s,rt)
 if(rt%status==0.or.any(test%mass_mg_cm2/=m%mass_mg_cm2).or. &
  any(test_s%sorbed_matrix_mass/=s%sorbed_matrix_mass).or.test_s%pond_mass/=s%pond_mass)error stop 'rejection changed state'
 call advance_research_native_fct(m,s,f,.true.,test,test_s,rt)
 if(rt%status/=0.or.any(test%mass_mg_cm2/=next%mass_mg_cm2).or. &
  any(test_s%sorbed_matrix_mass/=next_s%sorbed_matrix_mass).or.test_s%pond_mass/=next_s%pond_mass)error stop 'retry drift'
 print *,'PASS',domain,mode,exponent,uptake,l1,r%balance_residual_mg_cm2
 print *,'SURFACE',r%pond_to_soil_mg_cm2,r%runoff_output_mg_cm2,next_s%pond_mass
 do i=1,n
  print *,'CELL',i,f%dz_cm(i),f%theta_previous(i),f%theta(i),initial(i),next%concentration_mg_cm3(i), &
   next%mass_mg_cm2(i),next_s%sorbed_matrix_mass(i),delta(i)
 end do
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
 sha=lambda b:hashlib.sha256(b).hexdigest()
 inputs={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in sources if p.is_relative_to(ROOT)}
 r=dict(baseline=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),closure=list(map(str,sources)),inputs=inputs,events=[],status='RUNNING',max_equation_residual=0.,cases=0)
 profiles={};r['max_O0_O2_difference']=0.
 for opt in ['O0','O2']:
  folder=out/opt;folder.mkdir();exe=folder/'probe'
  commands=[[os.environ['FC'],'-'+opt,'-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(folder),*map(str,sources),'-o',str(exe)]]
  args=list(itertools.product([0,2],[.5,1.,2.],[0.,1.],[0,1,2,3]))
  commands.extend([[str(exe),str(mode),str(exp),str(uptake),'3','4',str(domain)]for mode,exp,uptake,domain in args])
  for cmd in commands:
   if Path(cmd[0])==exe and exe.exists():exe.chmod(exe.stat().st_mode|stat.S_IXUSR)
   t=time.monotonic();cp=subprocess.run(cmd,cwd=folder,capture_output=True,timeout=180)
   event=dict(command=cmd,returncode=cp.returncode,seconds=time.monotonic()-t,stdout=cp.stdout.decode(),stderr=cp.stderr.decode());r['events'].append(event)
   (out/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n');assert cp.returncode==0,event
   if Path(cmd[0])!=exe:continue
   mode=int(cmd[1]);exp=float(cmd[2]);uptake=float(cmd[3]);rows=[l.split() for l in event['stdout'].splitlines() if l.split()[0]=='CELL']
   h,oldtheta,theta,old,c,m,s,delta=np.array([list(map(float,l[2:])) for l in rows]).T
   key=tuple(cmd[1:]);values=np.r_[c,m,s,delta]
   if opt=='O0':profiles[key]=values
   else:
    difference=float(max(abs(values-profiles[key])));assert difference<1e-12
    r['max_O0_O2_difference']=max(r['max_O0_O2_difference'],difference)
   assert min(m)>=0 and min(s)>=0 and max(abs(m-theta*h*c))<1e-12 and max(abs(s-.26*h*c**exp))<1e-12
   q=.15 if mode==2 else 0.;rate=.1*np.minimum(1,theta/.3) if mode==2 else np.zeros(16)
   dist=.5*(h[:-1]+h[1:]);tf=(h[1:]*theta[:-1]+h[:-1]*theta[1:])/(2*dist)
   conduct=(.2*tf**3.33/.423**2+.25*q)/dist if mode==2 else np.zeros(15)
   transfer=float(next(l.split()[1] for l in event['stdout'].splitlines() if l.split()[0]=='SURFACE'))
   faces=np.r_[transfer/.25,q*c[:-1]+conduct*(c[:-1]-c[1:]),q*c[-1]]
   equation=(1+.25*rate)*(m+s)+.25*(uptake*.02+.01)*c-(oldtheta*old+.26*old**exp)*h-delta-.25*(faces[:-1]-faces[1:])
   residual=float(max(abs(equation)));assert residual<1e-11,(cmd,residual)
   r['max_equation_residual']=max(r['max_equation_residual'],residual);r['cases']+=1
 r['status']='PROCESS_EXTENSION_PASS_NOT_NATIVE_ACTIVATION';(out/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({k:v for k,v in r.items() if k not in ['events','closure','inputs']},indent=2))
if __name__=='__main__':main()
