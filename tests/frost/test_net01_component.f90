program test_net01_component
  use, intrinsic::iso_fortran_env,only:real64
  use mod_process_hydraulic_view,only:process_hydraulic_view_t
  use mod_frost_divdra_drainage_effect,only:frost_divdra_parameters_t
  use mod_frost_multilevel_divdra_effect
  implicit none
  type(frost_divdra_parameters_t),allocatable::p(:)
  type(process_hydraulic_view_t)::view
  type(frost_multilevel_divdra_result_t)::result
  integer::id,levels,inf,ios,i,l,node
  real(real64)::gw,frost,air,bottom,raw(3),spacing(3),aniso,factor(8),theta(8),rates(3),final(3,8)
  do
    read(*,*,iostat=ios)id,levels,inf,gw,frost,air,bottom,raw,spacing,aniso
    if(ios<0)exit
    if(ios/=0)error stop 'invalid input'
    if(allocated(p))deallocate(p)
    allocate(p(levels));factor=1._real64;node=0
    do i=1,8
      if(-(real(i,real64)-.5_real64)>=frost)then
        factor(i)=0._real64;node=i
      end if
    end do
    factor(node+1)=.5_real64;theta=.5_real64
    theta(node+1:)=.5_real64-air/real(8-node,real64)
    do l=1,levels
      p(l)%distribution%active_nodes=8
      p(l)%distribution%dz=spread(1._real64,1,8)
      p(l)%distribution%zbotcp=[(-real(i,real64),i=1,8)]
      p(l)%distribution%saturated_conductivity=[1._real64,4._real64,1._real64,4._real64, &
           1._real64,4._real64,1._real64,4._real64]
      p(l)%distribution%horizontal_anisotropy_factor=spread(aniso,1,8)
      p(l)%distribution%drain_spacing=spacing(l)
      select case(l)
      case(1);p(l)%drain_bottom_cm=-3._real64
      case(2);p(l)%drain_bottom_cm=-4.7_real64
      case(3);p(l)%drain_bottom_cm=-6.3_real64
      end select
      p(l)%separate_infiltration=inf==1;p(l)%surface_water_level_cm=-1._real64
    end do
    view%active_nodes=8;view%groundwater_level=gw;view%ponding_depth=0._real64
    view%pressure_head=spread(-1._real64,1,8);view%water_content=theta
    call compose_multilevel_signed_frost_divdra(p,view,factor,node,frost,theta, &
         spread(.5_real64,1,8),raw(:levels),bottom,result)
    if(.not.result%available)then
      print *, 'FAILED',id,result%status
      error stop 'component unavailable'
    end if
    rates=0._real64;final=0._real64;rates(:levels)=result%final_scalar;final(:levels,:)=result%final_nodal_sink
    write(*,'(I0,1X,28(ES26.17E3,1X))')id,rates,((final(l,i),i=1,8),l=1,3),result%final_bottom
  end do
end program
