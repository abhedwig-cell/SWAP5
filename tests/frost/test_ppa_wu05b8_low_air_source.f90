program low_air_reference
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan,ieee_positive_inf,ieee_negative_inf
 use MOD_frost,only:FrozenCond,FrozenBounds,tfroststa,tfrostend,rfcp,nodfrostbot,zfrosttop,zfrostbot,frost_geometry_valid
 use MOD_grid
 use MOD_drain
 use MOD_swap_base
 use variables
 use mod_frost_geometry_effect
 use mod_frost_low_air_drainage_effect
 implicit none
 real(real64)::t(4),proposal(2,4),final(2,4),top,q
 type(frost_low_air_drainage_result_t)::r
 type(frost_geometry_result_t)::g
 type(frost_low_air_drainage_config_t)::cfg
 integer::profile,grid,sgn,regime,depthcase,dsign,cases,geometry_cases
 tfroststa=0.d0;tfrostend=-2.d0;cases=0;geometry_cases=0
 do grid=1,2
  z=[-.5d0,-1.5d0,-2.5d0,-3.5d0];disnod=1.d0;dz=1.d0
  if(grid==2)then
   z=[-.3d0,-1.1d0,-2.4d0,-4.d0];disnod=[.3d0,.8d0,1.3d0,1.6d0];dz=[.6d0,1.d0,1.6d0,1.6d0]
  end if
  do profile=1,8
   select case(profile)
   case(1);t=[1.d0,2.d0,3.d0,4.d0]
   case(2);t=[1.d0,2.d0,3.d0,-4.d0]
   case(3);t=[-4.d0,1.d0,2.d0,3.d0]
   case(4);t=[-4.d0,-3.d0,1.d0,2.d0]
   case(5);t=[1.d0,-4.d0,1.d0,2.d0]
   case(6);t=[-4.d0,1.d0,-4.d0,1.d0]
   case(7);t=[1.d0,-2.d0,1.d0,2.d0]
   case(8);t=[-2.d0,-2.d0,1.d0,2.d0]
   end select
   do sgn=-1,1
    top=real(sgn,8)*4.d0
    call FrozenCond(t,top)
    call evaluate_legacy_bracketed_frost_geometry(t,top,tfroststa,tfrostend,z,disnod,g)
    call require(g%available.eqv.frost_geometry_valid,'reference geometry availability')
    call require(g%available,'valid geometry accepted')
    call require(g%deepest_node==nodfrostbot,'deepest index parity')
    call require(transfer(g%bottom_depth_cm,0_int64)==transfer(zfrostbot,0_int64),'bottom depth bit identity')
    call require(transfer(g%top_depth_cm,0_int64)==transfer(zfrosttop,0_int64),'top depth bit identity')
    geometry_cases=geometry_cases+1
   end do
  end do
 end do
 z=[-.5d0,-1.5d0,-2.5d0,-3.5d0];disnod=1.d0;dz=1.d0
 t=[-4.d0,-4.d0,1.d0,1.d0];swdra=1;swdivd=0;swmacro=0
 do regime=1,2
  theta=.5d0;thetas=.5d0
  if(regime==2)theta=.4d0
  do depthcase=1,6
   do sgn=-1,1
    do dsign=-1,1
     call FrozenCond(t,-4.d0)
     select case(depthcase)
     case(1);zbotdr=[-1.d0,-3.d0]
     case(2);zbotdr=[-1.d0,-1.5d0]
     case(3);zbotdr=[-3.d0,-4.d0]
     case(4);zbotdr=[zfrostbot,zfrostbot-1.d0]
     case(5);zbotdr=[-3.d0,-3.d0]
     case(6);zbotdr=[-3.d0,-4.d0]
     end select
     proposal=0.d0;proposal(1,2)=real(dsign,8)*.02d0;proposal(2,4)=real(dsign,8)*.1d0
     if(depthcase==6)proposal(2,4)=-proposal(1,2)
     q=real(sgn,8)*.01d0;qbot_nonfrozen=q;qdra=proposal;qdrain=sum(qdra,dim=2)
     call FrozenBounds
     call compose_legacy_bracketed_frost_drainage(t,-4.d0,tfroststa,tfrostend,theta,thetas,dz,rfcp,z,disnod, &
          zbotdr,proposal,q,final,r)
     call require(r%available,'valid ordinary branch available')
     call require(r%low_air_branch.eqv.(regime==1),'branch parity')
     call require(all(transfer(final,[0_int64],8)==transfer(qdra,[0_int64],8)),'final nodal flux bit identity')
     call require(transfer(r%final_bottom_flux,0_int64)==transfer(qbot,0_int64),'final bottom flux bit identity')
     call require(all(r%drainage%level_rate==qdrain).and.r%drainage%total_rate==qdrtot,'derived report parity')
     call require(abs(r%drainage%total_rate-sum(final))<1.d-14,'single nodal reporting owner')
     cases=cases+1
    end do
   end do
  end do
 end do
 theta=.5d0;t=-4.d0
 call compose_legacy_bracketed_frost_drainage(t,-4.d0,tfroststa,tfrostend,theta,thetas,dz,rfcp,z,disnod,zbotdr, &
      proposal,q,final,r)
 call require(.not.r%available.and.all(final==proposal),'uniform invalid front leaves proposal intact')
 t=[1.d0,-2.d0+9.999d-7,-2.d0+1.0001d-6,1.d0]
 call evaluate_legacy_bracketed_frost_geometry(t,-4.d0,tfroststa,tfrostend,z,disnod,g)
 call require(.not.g%available,'epsilon unbracketed front rejected')
 t=[-4.d0,-4.d0,1.d0,1.d0];zbotdr=[0.d0,1.d0]
 call compose_legacy_bracketed_frost_drainage(t,-4.d0,tfroststa,tfrostend,theta,thetas,dz,rfcp,z,disnod,zbotdr, &
      proposal,q,final,r)
 call require(.not.r%available.and.all(final==proposal),'invalid drain depths leave proposal intact')
 do profile=1,3
  zbotdr=[-1.d0,-3.d0]
  select case(profile)
  case(1);zbotdr(1)=ieee_value(0.d0,ieee_quiet_nan)
  case(2);zbotdr(1)=ieee_value(0.d0,ieee_positive_inf)
  case(3);zbotdr(1)=ieee_value(0.d0,ieee_negative_inf)
  end select
  cfg%active=.true.;cfg%drain_depth_cm=zbotdr
  call require(.not.cfg%valid(),'nonfinite depth config unavailable')
  call compose_legacy_bracketed_frost_drainage(t,-4.d0,tfroststa,tfrostend,theta,thetas,dz,rfcp,z,disnod,zbotdr, &
       proposal,q,final,r)
  call require(.not.r%available.and.all(final==proposal),'nonfinite drain depth rejected without trapped comparison')
 end do
 print '(A)','PPA_WU05B8_NONFINITE_DRAIN_DEPTH_CASES=3'
 print '(A,I0)','PPA_WU05B8_GUARDED_GEOMETRY_CASES=',geometry_cases
 print '(A,I0)','PPA_WU05B8_SIGNED_BRANCH_PHYSICAL_CASES=',cases
 print '(A)','PPA_WU05B8_BRACKETED_LOW_AIR_SOURCE=PASS'
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
