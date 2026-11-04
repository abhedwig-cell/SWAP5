"""Reversible attempted-call receipts, never serialized physical state."""
import film_refinement_candidate as candidate
SOURCE=candidate.owner.SOURCE
MAIN='app/solute_project/main.f90'

def kernel(body):
 decl='''   public :: write_film_runtime_receipt
   integer(int64),save::obs_calls=0,obs_refinements=0,obs_isolated=0,obs_maxlevel=0,obs_exhausted=0,obs_invalid=0
'''
 writer='''
   subroutine write_film_runtime_receipt(clock)
      real(real64),intent(in)::clock
      integer::u,io
      logical::exists
      inquire(file='film_runtime_receipts.csv',exist=exists)
      open(newunit=u,file='film_runtime_receipts.csv',status='unknown',position='append',action='write',iostat=io)
      if(io/=0)error stop 'private film receipt open'
      if(.not.exists)write(u,'(a)')'time_day,calls,refinements,isolated_pass_events,max_level,exhausted,invalid'
      write(u,'(es25.17e3,6(",",i0))',iostat=io)clock,obs_calls,obs_refinements,obs_isolated,obs_maxlevel,obs_exhausted,obs_invalid
      close(u)
      if(io/=0)error stop 'private film receipt write'
   end subroutine
'''
 changes=[('   use iso_fortran_env, only : real64\n','   use iso_fortran_env, only : real64,int64\n'),
 ('   public :: bartholomeus_waterfilm_mvg_independent\n','   public :: bartholomeus_waterfilm_mvg_independent\n'+decl),
 ('contains\n','contains\n'+writer),
 ('      ok = .false.\n','      ok = .false.\n      obs_calls=obs_calls+1\n'),
 ('                  p%alpha_per_pa,p%gen_n,p%surface_tension_water])))then\n','                  p%alpha_per_pa,p%gen_n,p%surface_tension_water])))then\n         obs_invalid=obs_invalid+1\n'),
 ('      if (matric_potential_pa <= 0.0_real64 .or. p%surface_tension_water <= 0.0_real64) then\n','      if (matric_potential_pa <= 0.0_real64 .or. p%surface_tension_water <= 0.0_real64) then\n         obs_invalid=obs_invalid+1\n'),
 ('         previous = integral\n','         obs_refinements=obs_refinements+1;obs_maxlevel=max(obs_maxlevel,int(level,int64))\n         previous = integral\n'),
 ('         else\n            stable_levels=0\n','         else\n            if(stable_levels==1)obs_isolated=obs_isolated+1\n            stable_levels=0\n'),
 ('      if(.not.converged)then\n','      if(.not.converged)then\n         obs_exhausted=obs_exhausted+1\n')]
 result=body
 for old,new in changes:assert result.count(old)==1;result=result.replace(old,new)
 check=result
 for old,new in reversed(changes):check=check.replace(new,old)
 assert check==body
 return result

def main(source):
 use='  use mod_bartholomeus_waterfilm_independent,only:write_film_runtime_receipt\n'
 anchor="        call require(code==0,'source complete rotation checkpoint')\n"
 line='        call write_film_runtime_receipt(t1)\n'
 assert source.count('  use mod_hupsel_germination\n')==source.count(anchor)==1
 result=source.replace('  use mod_hupsel_germination\n','  use mod_hupsel_germination\n'+use).replace(anchor,anchor+line)
 assert result.replace(use,'').replace(line,'')==source
 return result
