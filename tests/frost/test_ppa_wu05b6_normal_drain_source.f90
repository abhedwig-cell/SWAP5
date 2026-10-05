program normal_probe
  use iso_fortran_env,only:real64
  use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use MOD_frost,only:FrozenBounds,nodfrostbot,zfrostbot,rfcp
  use MOD_drain
  use MOD_swap_base
  use MOD_grid,only:dz
  use variables
  use mod_frost_drainage_effect
  implicit none
  real(real64)::proposal(2,4),final(2,4),t(4),f(4),q
  type(frost_drainage_result_t)::r
  type(frost_drainage_config_t)::cfg
  integer::regime,signq,signd,cases
  cases=0
  do regime=1,3
    do signq=-1,1
      do signd=-1,1
        theta=.4d0;thetas=.5d0;swdra=1;swmacro=0;swdivd=0
        t=[-4.d0,-4.d0,1.d0,1.d0];f=[0.d0,.25d0,.75d0,1.d0];nodfrostbot=2
        if(regime==2)then
          t=[-4.d0,1.d0,1.d0,1.d0];theta=.5d0;nodfrostbot=1
        end if
        if(regime==3)then
          t=[1.d0,1.d0,1.d0,-4.d0];nodfrostbot=-1
        end if
        q=real(signq,real64)*.01d0
        proposal(1,:)=[.01d0,-.02d0,.03d0,-.04d0]*real(signd,real64)
        proposal(2,:)=[-.05d0,.06d0,-.07d0,.08d0]*real(signd,real64)
        qdra=proposal;qdrain=sum(qdra,dim=2);qdrtot=sum(qdrain)
        rfcp=f;zfrostbot=-2.d0;qbot_nonfrozen=q
        call FrozenBounds
        call compose_legacy_normal_frost_drainage(.true.,t,-1.d0,theta,thetas,dz,f,proposal,final,r)
        call require(r%available.and.r%status==FROST_DRAIN_OK,'normal branch accepted')
        call require(all(final==qdra),'actual B1 nodal flux parity')
        call require(all(r%level_rate==qdrain).and.r%total_rate==qdrtot,'actual B1 report parity')
        call require(qbot==q,'bottom owner unchanged')
        cases=cases+1
      end do
    end do
  end do
  t=[-4.d0,-4.d0,1.d0,1.d0];theta=.5d0;thetas=.5d0;f=0.d0
  call compose_legacy_normal_frost_drainage(.true.,t,-1.d0,theta,thetas,dz,f,proposal,final,r)
  call require(.not.r%available.and.r%status==FROST_DRAIN_LOW_AIR_UNQUALIFIED,'low air rejects before mutation')
  call require(all(final==proposal),'unqualified branch leaves proposal intact')
  f(2)=2.d0
  call compose_legacy_normal_frost_drainage(.true.,t,-1.d0,theta,thetas,dz,f,proposal,final,r)
  call require(.not.r%available,'invalid factor rejected')
  f=0.d0;theta=0.d0;thetas=.01d0
  call compose_legacy_normal_frost_drainage(.true.,t,-1.d0,theta,thetas,[1.d0,1.d0,1.d0,1.d0],f,proposal,final,r)
  call require(r%available,'air threshold equality admitted')
  thetas=.009d0
  call compose_legacy_normal_frost_drainage(.true.,t,-1.d0,theta,thetas,[1.d0,1.d0,1.d0,1.d0],f,proposal,final,r)
  call require(r%status==FROST_DRAIN_LOW_AIR_UNQUALIFIED,'air below threshold excluded')
  f=ieee_value(0.d0,ieee_quiet_nan)
  call compose_legacy_normal_frost_drainage(.false.,t,-1.d0,theta,thetas,dz,f,proposal,final,r)
  call require(r%available.and.all(final==proposal),'OFF exact copy ignores inactive factor')
  call compose_legacy_normal_frost_drainage(.true.,t,-1.d0,theta,thetas,dz,f,proposal,final,r)
  call require(.not.r%available,'active NaN rejected')
  call require(cfg%valid(),'inactive budget accepted')
  cfg%active=.true.;call require(.not.cfg%valid(),'missing budget rejected')
  cfg%head_budget_cm=1.d-6;cfg%temperature_budget_c=1.d-7
  call require(cfg%valid(),'positive finite numerical budgets')
  proposal=huge(1.d0)
  call compose_legacy_normal_frost_drainage(.false.,t,-1.d0,theta,thetas,dz,f,proposal,final,r)
  call require(.not.r%available,'unrepresentable total rejects without FP overflow')
  print '(A,I0)','PPA_WU05B6_ACTUAL_B1_NORMAL_DRAIN_CASES=',cases
  print '(A)','PPA_WU05B6_NORMAL_DRAIN_SOURCE=PASS'
contains
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(*),intent(in)::label
    if(.not.ok)then
      print *,label
      error stop 1
    end if
  end subroutine
end program
