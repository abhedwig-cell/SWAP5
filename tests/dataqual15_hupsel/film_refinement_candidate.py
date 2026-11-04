"""Private consecutive-refinement safeguard; no production numerical-policy change."""
import argparse,json,math,subprocess,time,io,tarfile
from pathlib import Path
import film_refinement as owner
f=owner.f
OLD='         if (abs(integral-previous) <= 1.0e-5_real64*max(abs(integral),tiny(1.0_real64))) exit\n'
NEW='''         if (abs(integral-previous) <= 1.0e-5_real64*max(abs(integral),tiny(1.0_real64))) then
            stable_levels=stable_levels+1
         else
            stable_levels=0
         end if
         if(stable_levels>=2)then
            converged=.true.
            exit
         end if
'''
FINITE='''      if(.not.all(ieee_is_finite([matric_potential_pa,p%capac_term,p%n_minus_1,p%m_plus_1, &
                  p%alpha_per_pa,p%gen_n,p%surface_tension_water])))then
         thickness=huge(1.0_real64)
         return
      end if
'''
CAP='''      if(.not.converged)then
         thickness=huge(1.0_real64)
         return
      end if
'''

def candidate(source):
 changes=[('   use iso_fortran_env, only : real64\n','   use iso_fortran_env, only : real64\n   use ieee_arithmetic,only:ieee_is_finite\n'),
 ('      integer :: level\n','      integer :: level,stable_levels\n      logical::converged\n'),
 ('      ok = .false.\n','      ok = .false.\n'+FINITE),
 ('      do level = 2, 24\n','      stable_levels=0;converged=.false.\n      do level = 2, 24\n'),
 (OLD,NEW),('      if (integral <= 0.0_real64) then\n',CAP+'      if (integral <= 0.0_real64) then\n')]
 result=source
 for a,b in changes:assert result.count(a)==1;result=result.replace(a,b)
 restored=result
 for a,b in reversed(changes):restored=restored.replace(b,a)
 assert restored==source and result.count('do level = 2, 24')==1 and '1.0e-5_real64' in result
 return result

def observation(folder,source,cases,raw):
 r=json.loads((folder/'RESULT.json').read_text());assert r['status']=='ACTUAL_O0_O2_REFINEMENT_OBSERVATION_AND_EXACT_FULL_CORPUS_CONTROLS_PASS'
 assert r['source_sha256']==f.sha(source.encode()) and r['input_sha256']==f.sha(raw)
 result={}
 for opt in ('O0','O2'):
  base=folder/(opt+'-plain');watched=folder/(opt+'-observed')
  assert (base/'waterfilm.f90').read_text()==source and (watched/'waterfilm.f90').read_text()==owner.observed(source,cases)
  for path in (base,watched):
   meta=json.loads((path/'BUILD.json').read_text());assert f.sha((path/'compare.exe').read_bytes())==meta['executable_sha256']
   for n,h in meta['source_sha256'].items():assert f.sha((path/n if '/'not in n else f.ROOT/n).read_bytes())==h,n
  stdout=(base/'comparison.stdout').read_bytes();assert stdout==(watched/'comparison.stdout').read_bytes() and f.sha(stdout)==r['builds'][opt]['exact_unobserved_stdout_sha256']
  assert owner.receipts((watched/'comparison.stderr').read_bytes(),cases)==r['builds'][opt]['observations']
  rows=[list(map(float,line.split()))for line in stdout.decode().splitlines()];assert len(rows)==41678
  result[opt]=rows
 return result

def errors(rows,corpus,table):
 values=[]
 for row in rows:
  i,j=int(row[0])-1,int(row[1])-1;fields=corpus[i][j];reference=table[i][j];current=row[8]
  if reference==0:assert current==0;continue
  p=-100*float(fields[11])
  if p>1e7:assert current==1e-8;continue
  assert current>0 and math.isfinite(current)
  sigma=.07275*(1-.002*(float(fields[13])+273-291))
  exact=1/(math.pi*(reference/2+2*sigma/p)**2);measured=1/(math.pi*(current/2+2*sigma/p)**2)
  values.append((abs(measured-exact)/exact,abs(current-reference)/reference,abs(current-reference),i+1,j+1))
 worst=max(values)
 return dict(maximum_relative_integral_error=worst[0],maximum_relative_film_error=max(x[1]for x in values),maximum_absolute_film_error_m=max(x[2]for x in values),maximum_integral_error_case=list(worst[3:]),active_cases=len(values))

def fault_controls(out,source,fields,compiler,opt):
 out.mkdir();c=list(map(float,fields));n=c[26];m=c[27];alpha=c[24]*.01;cap=(c[22]-c[21])*alpha*n*m;sigma=.07275*(1-.002*(c[13]+273-291));p=-100*c[11]
 vals=','.join(format(x,'.17e')+'_real64'for x in [cap,n-1,m+1,alpha,n,sigma])
 driver='''program probe
 use iso_fortran_env,only:real64
 use ieee_arithmetic
 use mod_bartholomeus_waterfilm
 use mod_bartholomeus_waterfilm_independent
 implicit none
 type(BartholomeusWaterfilmMvgInput)::p
 real(real64)::x,y
 logical::ok
 character(32)::mode
 p=BartholomeusWaterfilmMvgInput(VALUES)
 x=PRESSURE
 call get_command_argument(1,mode)
 select case(trim(mode))
 case('nan-head');x=ieee_value(0d0,ieee_quiet_nan)
 case('inf-head');x=ieee_value(0d0,ieee_positive_inf)
 case('nan-alpha');p%alpha_per_pa=ieee_value(0d0,ieee_quiet_nan)
 case('inf-sigma');p%surface_tension_water=ieee_value(0d0,ieee_negative_inf)
 case('zero-head');x=0d0
 case('dry');x=1.0000001e7_real64
 end select
 y=bartholomeus_waterfilm_mvg_independent(x,p,ok)
 write(*,'(l1,1x,es25.17e3)')ok,y
end program
'''.replace('VALUES',vals).replace('PRESSURE',format(p,'.17e')+'_real64')
 (out/'probe.f90').write_text(driver,encoding='utf-8');records=[]
 variants={'candidate':source,'candidate-cap2':source.replace('do level = 2, 24','do level = 2, 2'),'incumbent-cap2':(f.ROOT/owner.SOURCE).read_text().replace('do level = 2, 24','do level = 2, 2')}
 for name,body in variants.items():
  folder=out/name;folder.mkdir();(folder/'waterfilm.f90').write_text(body,encoding='utf-8');exe=folder/'probe.exe'
  cmd=[compiler,'-'+opt,'-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(folder),'-I'+str(folder),str(f.ROOT/'src/physics/oxygen/mod_bartholomeus_waterfilm.f90'),str(folder/'waterfilm.f90'),str(out/'probe.f90'),'-o',str(exe)]
  r=subprocess.run(cmd,cwd=folder,capture_output=True,timeout=180);(folder/'compile.stderr').write_bytes(r.stderr);assert r.returncode==0,r.stderr.decode(errors='replace')[-1000:]
  modes=['ordinary','nan-head','inf-head','nan-alpha','inf-sigma','zero-head','dry']if name=='candidate'else['ordinary']
  for mode in modes:
   r=subprocess.run([str(exe),mode],cwd=folder,capture_output=True,timeout=30);(folder/(mode+'.stdout')).write_bytes(r.stdout);(folder/(mode+'.stderr')).write_bytes(r.stderr);assert r.returncode==0
   words=r.stdout.decode().split();ok=words[0]=='T';value=float(words[1]);assert math.isfinite(value)
   expected=(name=='incumbent-cap2')or(name=='candidate'and mode in ('ordinary','dry'))
   assert ok==expected,(name,mode,words)
   if mode=='dry':assert value==1e-8
   records.append(dict(variant=name,mode=mode,ok=ok,returned=value))
 return records

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--observation',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',default='gfortran');a=p.parse_args();out=a.output.resolve();out.mkdir()
 scope,raw,corpus,table=owner.load();cases=owner.selected(corpus);source=(f.ROOT/owner.SOURCE).read_text();body=candidate(source);base=observation(a.observation.resolve(),source,cases,raw);frame=out/'original_factor_inputs.dat';frame.write_bytes(raw)
 record=json.loads((f.BASE/'FILM_ACCURACY_WINDOWS_20261104.json').read_text())
 with tarfile.open(fileobj=io.BytesIO((f.BASE/record['archive']).read_bytes()))as t:oracle={opt:[list(map(float,line.split()))for line in t.extractfile(opt+'/certified.stdout').read().decode().splitlines()]for opt in ('O0','O2')}
 report=dict(status='PRIVATE_REFINEMENT_CANDIDATE_MEASUREMENT_PENDING',source_sha256=f.sha(source.encode()),candidate_sha256=f.sha(body.encode()),input_sha256=f.sha(raw),production_admission=False,whole_scientific_admission=False,reference_trajectory_accuracy_qualified=False,builds={})
 for opt in ('O0','O2'):
  folder=out/opt;exe=owner.build(folder,body,scope,a.compiler,opt);_,stderr,rows,seconds=owner.run(exe,frame,folder);assert not stderr
  assert all(x[:5]==y[:5]and x[6:8]==y[6:8]for x,y in zip(rows,base[opt])),'original physics side changed'
  before=errors(base[opt],corpus,table);after=errors(rows,corpus,table)
  factor=max(abs(x[5]-y[4])for x,y in zip(rows,oracle[opt]))
  probes=fault_controls(out/(opt+'-faults'),body,corpus[1247][12],a.compiler,opt)
  report['builds'][opt]=dict(before=before,after=after,certified_original_factor_maximum=factor,fault_controls=probes,seconds=seconds)
  (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
  assert before['maximum_relative_integral_error']>1e-5 and after['maximum_relative_integral_error']<=1e-5
  assert factor<=1e-4
 report['status']='PRIVATE_TWO_SUCCESSIVE_REFINEMENTS_COMPLETE_CORPUS_AND_FAIL_CLOSED_CONTROLS_PASS'
 (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({opt:(r['before'],r['after'],r['certified_original_factor_maximum'])for opt,r in report['builds'].items()}))
if __name__=='__main__':main()
