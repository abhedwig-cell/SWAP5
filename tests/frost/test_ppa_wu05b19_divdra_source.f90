program source_parity
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_grid
  use MOD_drain
  use MOD_frost
  use variables
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_frost_divdra_drainage_effect
  use mod_frost_geometry_effect
  use mod_frost_hydraulic_effect
  implicit none
  type(frost_divdra_parameters_t)::p
  type(process_hydraulic_view_t)::view
  type(frost_divdra_result_t)::r
  type(frost_geometry_result_t)::g
  type(frost_hydraulic_parameters_t)::hp
  real(real64)::t(4),f(4),raw,qb,depth,surface,err,max_nodes,max_scalar
  integer::id,inf,route,j,b,d,status,accepted,held
  real(real64),parameter::rates(11)=[-.01_real64,-1.e-6_real64,-5.e-7_real64,-1.e-10_real64,-1.e-11_real64, &
       0._real64,1.e-11_real64,1.e-10_real64,5.e-7_real64,1.e-6_real64,.01_real64]
  real(real64),parameter::bottoms(5)=[-.001_real64,0._real64,.001_real64,-.01_real64+1.e-11_real64,.01_real64-1.e-11_real64]
  real(real64),parameter::depths(3)=[-1._real64,-1.25_real64,-2._real64]
  p%distribution%active_nodes=4;p%distribution%dz=dz;p%distribution%zbotcp=zbotcp
  p%distribution%saturated_conductivity=[4.75_real64,4.75_real64,4.75_real64,4.75_real64]
  p%distribution%horizontal_anisotropy_factor=[1._real64,1._real64,1._real64,1._real64]
  p%distribution%drain_spacing=20._real64;p%surface_water_level_cm=-.25_real64
  view%active_nodes=4;view%pressure_head=[-5._real64,-5._real64,-5._real64,-5._real64]
  view%groundwater_level=-.75_real64;hp%active=.true.;hp%reduction_start_c=0._real64;hp%reduction_end_c=-2._real64
  tfroststa=0._real64;tfrostend=-2._real64;gwl=-.75_real64
  id=0;accepted=0;held=0;max_nodes=0._real64;max_scalar=0._real64
  do inf=0,1
  swdivdinf=inf;p%separate_infiltration=inf==1
  do route=0,1
    t=-.7_real64;surface=-.7_real64;theta=.3_real64
    if(route==1)then
      t=[-4._real64,-4._real64,-1._real64,1._real64];surface=-4._real64;theta=thetas
    end if
    view%water_content=theta
    call FrozenCond(t,surface)
    call evaluate_frost_hydraulic_factor(hp,t,f,status)
    if(status/=0.or.any(f/=rfcp))error stop 'actual FrozenCond factor parity'
    call evaluate_legacy_bracketed_frost_geometry(t,surface,0._real64,-2._real64,z,disnod,g)
    if(.not.g%available.or.g%deepest_node/=nodfrostbot.or.g%bottom_depth_cm/=zfrostbot)error stop 'actual source geometry parity'
    do d=1,3
    p%drain_bottom_cm=depths(d);zbotdr=depths(d)
    do j=1,size(rates)
    raw=rates(j)
    do b=1,size(bottoms)
      qb=bottoms(b);id=id+1
      qdra=0._real64;qdrain=raw;qdrtot=raw;qbot=qb;qbot_nonfrozen=qb
      call DIVDRA(p%distribution%saturated_conductivity,gwl)
      call FrozenBounds
      call compose_single_level_signed_frost_divdra(p,view,f,g%deepest_node,g%bottom_depth_cm,theta,thetas,raw,qb,r)
      if(r%available)then
        accepted=accepted+1;err=maxval(abs(r%final_nodal_sink-qdra(1,:)))
        max_nodes=max(max_nodes,err);max_scalar=max(max_scalar,abs(r%final_scalar-qdrain(1)))
        if(err>1.e-14_real64.or.abs(r%final_scalar-qdrain(1))>1.e-14_real64.or.r%final_bottom/=qbot)error stop 'actual full source owner parity'
        if(abs(sum(r%final_nodal_sink)-r%final_scalar)>1.e-14_real64)error stop 'one nodal scalar closure'
      else
        held=held+1
        if(r%status/=FROST_DIVDRA_SMALL_SCALAR.or.allocated(r%final_nodal_sink))error stop 'unqualified source domain published'
        if(.not.(raw/=0._real64.and.abs(raw)<=1.e-10_real64).and. &
             .not.(route==1.and.d/=1.and.abs(raw+qb)>0._real64.and.abs(raw+qb)<=1.e-10_real64)) &
             error stop 'unexpected held domain'
      end if
      write(*,'(A,I0,A,I0,A,L1)')'B19_SOURCE case=',id,' status=',r%status,' available=',r%available
    end do
    end do
    end do
  end do
  end do
  write(*,'(A,I0,A,I0,A,I0,A,ES24.16,A,ES24.16)')'B19_ACTUAL_SOURCE_PASS cases=',id,' accepted=',accepted, &
       ' held=',held,' max_nodes=',max_nodes,' max_scalar=',max_scalar
end program
