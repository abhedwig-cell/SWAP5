program component
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan
  use mod_frost_divdra_drainage_effect
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  implicit none
  type(frost_divdra_parameters_t) :: p,invalid
  type(process_hydraulic_view_t) :: view,bad_view
  type(frost_divdra_result_t) :: r
  real(real64) :: gw,frost,air,raw,qbot,spacing,aniso,factor(8),theta(8),sat(8),nodes(8)
  integer :: id,inf,ios,i,nf,j,negative_count
  p%distribution%active_nodes=8
  allocate(p%distribution%dz(8),p%distribution%zbotcp(8),p%distribution%saturated_conductivity(8), &
       p%distribution%horizontal_anisotropy_factor(8))
  p%distribution%dz=1._real64;p%distribution%zbotcp=[(-real(i,real64),i=1,8)]
  p%distribution%saturated_conductivity=[1._real64,4._real64,1._real64,4._real64,1._real64,4._real64,1._real64,4._real64]
  p%drain_bottom_cm=-3._real64;p%surface_water_level_cm=-1._real64
  view%active_nodes=8;allocate(view%pressure_head(8),view%water_content(8));sat=.5_real64
  do
    read(*,*,iostat=ios)id,inf,gw,frost,air,raw,qbot,spacing,aniso
    if(ios<0)exit
    if(ios/=0)error stop 'invalid input'
    p%separate_infiltration=inf==1;p%distribution%drain_spacing=spacing
    p%distribution%horizontal_anisotropy_factor=aniso
    view%groundwater_level=gw;view%pressure_head=[(gw+real(i,real64)-.5_real64,i=1,8)]
    factor=1._real64;nf=0
    do i=1,8
      if(-(real(i,real64)-.5_real64)>=frost)then
        factor(i)=0._real64;nf=i
      end if
    end do
    factor(nf+1)=.5_real64;theta=sat;theta(nf+1:8)=.5_real64-air/real(8-nf,real64)
    view%water_content=theta
    call compose_single_level_signed_frost_divdra(p,view,factor,nf,frost,theta,sat,raw,qbot,r)
    nodes=0._real64
    if(r%available)then
      if(.not.allocated(r%final_nodal_sink))error stop 'available without nodes'
      nodes=r%final_nodal_sink
    else
      if(allocated(r%final_nodal_sink))error stop 'unavailable published nodes'
    end if
    write(*,'(3(I0,1X),13(ES26.17E3,1X),2(I0,1X))')id,r%status,merge(1,0,r%available), &
         r%final_scalar,nodes,r%final_bottom,r%initial_partition_correction,r%final_partition_correction,r%available_air, &
         merge(1,0,r%low_air),merge(1,0,r%blocked)
  end do
  ! Each invalid call retains immutable inputs and publishes no final vector.
  p%separate_infiltration=.false.;p%distribution%drain_spacing=20._real64
  p%distribution%horizontal_anisotropy_factor=1._real64;view%groundwater_level=-1.5_real64
  factor=1._real64;theta=.4_real64;view%water_content=theta;nf=-1;frost=0._real64
  negative_count=0
  do j=1,24
    invalid=p;bad_view=view;nodes=factor
    select case(j)
    case(1);invalid%distribution%active_nodes=0
    case(2);deallocate(invalid%distribution%dz)
    case(3);invalid%distribution%dz(1)=0._real64
    case(4);invalid%distribution%zbotcp(2)=-2.1_real64
    case(5);invalid%distribution%saturated_conductivity(1)=0._real64
    case(6);invalid%distribution%horizontal_anisotropy_factor(1)=0._real64
    case(7);invalid%distribution%drain_spacing=0._real64
    case(8);invalid%drain_bottom_cm=0._real64
    case(9);invalid%infiltration_depth_factor=2._real64
    case(10);invalid%surface_water_level_cm=1._real64
    case(11);bad_view%active_nodes=7
    case(12);deallocate(bad_view%pressure_head)
    case(13);bad_view%water_content(1)=.3_real64
    case(14);bad_view%groundwater_level=-8._real64
    case(15);bad_view%groundwater_level=-2._real64-5.e-11_real64
    case(16);bad_view%groundwater_level=ieee_value(0._real64,ieee_quiet_nan)
    case(17);invalid%distribution%dz(1)=ieee_value(0._real64,ieee_quiet_nan)
    case(18);nodes(1)=ieee_value(0._real64,ieee_quiet_nan)
    case(19);nodes(1)=-.1_real64
    case(20);nodes(1)=1.1_real64
    case(21);invalid%distribution%saturated_conductivity(1)=1.e7_real64
    case(22);invalid%distribution%horizontal_anisotropy_factor(1)=1.e7_real64
    case(23);invalid%distribution%drain_spacing=1.e7_real64
    case(24);invalid%drain_bottom_cm=-9._real64
    end select
    call compose_single_level_signed_frost_divdra(invalid,bad_view,nodes,nf,frost,theta,sat,.1_real64,-.01_real64,r)
    if(r%available.or.allocated(r%final_nodal_sink))error stop 'invalid-domain publication'
    if(any(theta/=.4_real64).or.any(view%water_content/=theta).or.view%groundwater_level/=-1.5_real64)error stop 'input mutated'
    negative_count=negative_count+1
  end do
  invalid=p;invalid%separate_infiltration=.true.;invalid%surface_water_level_cm=-1.25_real64
  call compose_single_level_signed_frost_divdra(invalid,view,factor,nf,frost,theta,sat,-.1_real64,0._real64,r)
  if(r%available.or.allocated(r%final_nodal_sink))error stop 'same-compartment publication'
  negative_count=negative_count+1
  call compose_single_level_signed_frost_divdra(p,view,factor,nf,frost,theta(:7),sat,.1_real64,0._real64,r)
  if(r%available.or.allocated(r%final_nodal_sink))error stop 'shape publication'
  negative_count=negative_count+1
  call compose_single_level_signed_frost_divdra(p,view,factor,8,-7.5_real64,theta,sat,.1_real64,0._real64,r)
  if(r%available.or.allocated(r%final_nodal_sink))error stop 'last-node frozen publication'
  negative_count=negative_count+1
  write(*,'(A,I0)')'B18_INVALID_DOMAIN_UNAVAILABLE_CASES=',negative_count
end program
