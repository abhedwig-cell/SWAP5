program test_net01_component
  use, intrinsic::iso_fortran_env,only:real64
  use, intrinsic::ieee_arithmetic,only:ieee_value,ieee_quiet_nan,ieee_positive_inf
  use mod_process_hydraulic_view,only:process_hydraulic_view_t
  use mod_frost_divdra_drainage_effect,only:frost_divdra_parameters_t
  use mod_frost_multilevel_divdra_effect
  implicit none
  type(frost_divdra_parameters_t),allocatable::p(:)
  type(process_hydraulic_view_t)::view
  type(frost_multilevel_divdra_result_t)::result
  integer::id,levels,inf,ios,i,l,node
  real(real64)::gw,frost,air,bottom,raw(3),spacing(3),aniso,factor(8),theta(8),rates(3),final(3,8)
  character(20)::argument
  call get_command_argument(1,argument)
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
    if(trim(argument)=='contracts')then
      call contracts();exit
    end if
    call compose_multilevel_signed_frost_divdra(p,view,factor,node,frost,theta, &
         spread(.5_real64,1,8),raw(:levels),bottom,result)
    if(.not.result%available)then
      print *, 'FAILED',id,result%status
      error stop 'component unavailable'
    end if
    rates=0._real64;final=0._real64;rates(:levels)=result%final_scalar;final(:levels,:)=result%final_nodal_sink
    write(*,'(I0,1X,28(ES26.17E3,1X))')id,rates,((final(l,i),i=1,8),l=1,3),result%final_bottom
  end do
contains
  subroutine contracts()
    type(frost_divdra_parameters_t),allocatable::bad(:)
    type(process_hydraulic_view_t)::v
    type(frost_multilevel_divdra_result_t)::a,b,r
    real(real64),allocatable::q(:),fac(:),water(:),sat(:)
    real(real64)::fb,bot
    integer::k,fn
    call compose_multilevel_signed_frost_divdra(p,view,factor,node,frost,theta,spread(.5_real64,1,8), &
         raw(:levels),bottom,a)
    if(.not.a%available)error stop 'baseline unavailable'
    do k=1,26
      bad=p;v=view;q=raw(:levels);fac=factor;water=theta;sat=spread(.5_real64,1,8);fb=frost;fn=node;bot=bottom
      select case(k)
      case(1);q(1)=ieee_value(0._real64,ieee_quiet_nan)
      case(2);fac(1)=ieee_value(0._real64,ieee_positive_inf)
      case(3);v%groundwater_level=ieee_value(0._real64,ieee_quiet_nan)
      case(4);bot=ieee_value(0._real64,ieee_positive_inf)
      case(5);bad(1)%distribution%dz(1)=0._real64
      case(6);bad(2)%distribution%dz(1)=2._real64
      case(7);bad(2)%distribution%saturated_conductivity(1)=2._real64
      case(8);bad(2)%distribution%horizontal_anisotropy_factor(1)=2._real64
      case(9);bad(2)%distribution%drain_spacing=0._real64
      case(10);deallocate(bad(1)%distribution%dz)
      case(11);bad(2)%drain_bottom_cm=bad(1)%drain_bottom_cm
      case(12);v%active_nodes=7
      case(13);deallocate(v%water_content)
      case(14);water(1)=water(1)-.001_real64
      case(15);sat(1)=2._real64
      case(16);fac(1)=-.1_real64
      case(17);fac(1)=1.1_real64
      case(18);fn=8
      case(19);fb=-9._real64
      case(20);q=q(:levels-1)
      case(21);bad=bad(:1)
      case(22);bad(2)%separate_infiltration=.not.bad(1)%separate_infiltration
      case(23);water(1)=ieee_value(0._real64,ieee_quiet_nan)
      case(24);bad(1)%distribution%zbotcp(1)=-2._real64
      case(25);q(1)=1.e-11_real64
      case(26);q(1)=1.e7_real64
      end select
      call compose_multilevel_signed_frost_divdra(bad,v,fac,fn,fb,water,sat,q,bot,r)
      if(r%available.or.allocated(r%final_nodal_sink).or.allocated(r%final_scalar))error stop 'invalid published'
    end do
    call compose_multilevel_signed_frost_divdra(p,view,factor,node,frost,theta,spread(.5_real64,1,8), &
         raw(:levels),bottom,b)
    if(.not.b%available)error stop 'A/B/A unavailable'
    if(any(a%final_nodal_sink/=b%final_nodal_sink))error stop 'A/B/A changed'
    if(any(theta/=view%water_content))error stop 'input mutation'
    print '(A)','NET01_INVALID_NONMUTATION_ABA_26=PASS'
  end subroutine
end program
