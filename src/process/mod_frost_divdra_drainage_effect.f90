module mod_frost_divdra_drainage_effect
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t
  implicit none
  private
  integer, parameter, public :: FROST_DIVDRA_OK=0, FROST_DIVDRA_INVALID=1, FROST_DIVDRA_SMALL_SCALAR=2
  integer, parameter, public :: FROST_DIVDRA_GEOMETRY=3, FROST_DIVDRA_PARTITION=4
  real(real64), parameter :: SMALL=1.e-10_real64, FLOOR_K=1.e-10_real64
  type, public :: frost_divdra_parameters_t
    type(drainage_distribution_parameters_t) :: distribution
    real(real64) :: drain_bottom_cm=0._real64
    logical :: separate_infiltration=.false.
    real(real64) :: surface_water_level_cm=0._real64, infiltration_depth_factor=.5_real64
  end type
  type, public :: frost_divdra_result_t
    logical :: available=.false., low_air=.false., blocked=.false.
    integer :: status=FROST_DIVDRA_INVALID
    real(real64) :: available_air=0._real64, final_scalar=0._real64, final_bottom=0._real64
    real(real64) :: initial_partition_correction=0._real64, final_partition_correction=0._real64
    real(real64), allocatable :: final_nodal_sink(:)
  end type
  public :: compose_single_level_signed_frost_divdra, valid_frost_divdra_parameters
contains
  pure logical function valid_frost_divdra_parameters(p) result(ok)
    type(frost_divdra_parameters_t), intent(in) :: p
    ok=valid_parameters(p)
  end function valid_frost_divdra_parameters

  pure logical function valid_parameters(p) result(ok)
    type(frost_divdra_parameters_t), intent(in) :: p
    integer :: n,i
    real(real64) :: depth
    ok=.false.;n=p%distribution%active_nodes
    if(n<2)return
    if(.not.allocated(p%distribution%dz))return
    if(.not.allocated(p%distribution%zbotcp))return
    if(.not.allocated(p%distribution%saturated_conductivity))return
    if(.not.allocated(p%distribution%horizontal_anisotropy_factor))return
    if(size(p%distribution%dz)/=n.or.size(p%distribution%zbotcp)/=n)return
    if(size(p%distribution%saturated_conductivity)/=n.or.size(p%distribution%horizontal_anisotropy_factor)/=n)return
    if(any(.not.ieee_is_finite(p%distribution%dz)))return
    if(any(.not.ieee_is_finite(p%distribution%zbotcp)))return
    if(any(.not.ieee_is_finite(p%distribution%saturated_conductivity)))return
    if(any(.not.ieee_is_finite(p%distribution%horizontal_anisotropy_factor)))return
    if(.not.all(ieee_is_finite([p%distribution%drain_spacing,p%drain_bottom_cm, &
         p%surface_water_level_cm,p%infiltration_depth_factor])))return
    if(any(p%distribution%dz<1.e-6_real64).or.any(p%distribution%dz>1.e6_real64))return
    if(any(p%distribution%saturated_conductivity<FLOOR_K).or.any(p%distribution%saturated_conductivity>1.e6_real64))return
    if(any(p%distribution%horizontal_anisotropy_factor<1.e-6_real64).or. &
         any(p%distribution%horizontal_anisotropy_factor>1.e6_real64))return
    if(p%distribution%drain_spacing<1.e-6_real64.or.p%distribution%drain_spacing>1.e6_real64)return
    depth=0._real64
    do i=1,n
      if(depth>1.e6_real64-p%distribution%dz(i))return
      depth=depth+p%distribution%dz(i)
      if(abs(p%distribution%zbotcp(i)+depth)>64._real64*epsilon(depth)*max(1._real64,depth))return
    end do
    if(p%drain_bottom_cm>=0._real64.or.p%drain_bottom_cm< -depth)return
    if(p%infiltration_depth_factor<0._real64.or.p%infiltration_depth_factor>1._real64)return
    if(p%surface_water_level_cm>0._real64.or.p%surface_water_level_cm< -depth)return
    ok=.true.
  end function

  pure integer function level_node(p,depth) result(node)
    type(frost_divdra_parameters_t), intent(in) :: p
    real(real64), intent(in) :: depth
    integer :: i
    node=0
    do i=1,p%distribution%active_nodes
      if(depth<=-p%distribution%zbotcp(i)+SMALL)then
        ! The original shallower-compartment offset can give negative thickness.
        if(depth> -p%distribution%zbotcp(i))return
        node=i;return
      end if
    end do
  end function

  pure real(real64) function transmissivity(p,k,a,b) result(total)
    type(frost_divdra_parameters_t), intent(in) :: p
    real(real64), intent(in) :: k(:),a,b
    real(real64) :: top,bottom,overlap
    integer :: i
    total=0._real64;top=0._real64
    do i=1,size(k)
      bottom=-p%distribution%zbotcp(i)
      overlap=max(0._real64,min(b,bottom)-max(a,top))
      total=total+k(i)*overlap;top=bottom
    end do
  end function

  pure subroutine partition(p,k,groundwater,scalar,nodal,correction,status)
    type(frost_divdra_parameters_t), intent(in) :: p
    real(real64), intent(in) :: k(:),groundwater,scalar
    real(real64), allocatable, intent(out) :: nodal(:)
    real(real64), intent(out) :: correction
    integer, intent(out) :: status
    real(real64), allocatable :: kh(:),inverse_k(:),raw(:)
    real(real64) :: water,profile,thickness,kd_h,kd_v,fac,span,finish,total,uns,sat
    real(real64) :: surface,top,bottom,a,b,c,d,amount,raw_sum
    integer :: n,i,water_node,surface_node,last
    status=FROST_DIVDRA_INVALID;correction=0._real64;n=size(k)
    if(.not.all(ieee_is_finite([groundwater,scalar])))return
    if(abs(scalar)>1.e6_real64)return
    if(any(.not.ieee_is_finite(k)))return
    if(any(k<FLOOR_K).or.any(k>1.e6_real64))return
    water=-min(groundwater,0._real64);profile=-p%distribution%zbotcp(n)
    if(water>=profile)return
    water_node=level_node(p,water)
    if(water_node==0)then
      status=FROST_DIVDRA_GEOMETRY;return
    end if
    if(scalar/=0._real64.and.abs(scalar)<=SMALL)then
      status=FROST_DIVDRA_SMALL_SCALAR;return
    end if
    allocate(raw(n));raw=0._real64
    if(scalar==0._real64)then
      call move_alloc(raw,nodal);status=FROST_DIVDRA_OK;return
    end if
    allocate(kh(n),inverse_k(n));kh=k*p%distribution%horizontal_anisotropy_factor;inverse_k=1._real64/k
    thickness=profile-water
    kd_h=transmissivity(p,kh,water,profile);kd_v=transmissivity(p,inverse_k,water,profile)
    if(kd_h<=0._real64.or.kd_v<=0._real64)return
    fac=sqrt((thickness/kd_v)/(kd_h/thickness));span=.25_real64*p%distribution%drain_spacing*fac
    if(p%separate_infiltration.and.scalar< -SMALL)then
      span=span*max(p%infiltration_depth_factor,(-p%distribution%zbotcp(water_node)-water)/span)
    end if
    finish=min(profile,water+span)
    if(level_node(p,finish)==0.or.finish<=water)then
      status=FROST_DIVDRA_GEOMETRY;return
    end if
    if(p%separate_infiltration.and.scalar< -SMALL)then
      surface=-p%surface_water_level_cm;surface_node=level_node(p,surface)
      if(surface_node==0.or.surface_node>=water_node)then
        status=FROST_DIVDRA_GEOMETRY;return
      end if
      uns=transmissivity(p,kh,surface,water);sat=transmissivity(p,kh,water,finish);total=uns+sat
      if(uns<=0._real64.or.sat<=0._real64.or.total<=0._real64)return
      top=0._real64
      do i=1,n
        bottom=-p%distribution%zbotcp(i);amount=0._real64
        a=max(surface,top);b=min(water,bottom)
        if(b>a)then
          c=transmissivity(p,kh,surface,a);d=transmissivity(p,kh,surface,b)
          ! FROST-DIVDRA-02: retain every positive unsaturated transmissivity.
          amount=scalar/total*(d*d-c*c)/uns
        end if
        a=max(water,top);b=min(finish,bottom)
        if(b>a)then
          c=transmissivity(p,kh,b,finish);d=transmissivity(p,kh,a,finish)
          amount=amount+scalar/total*(d*d-c*c)/sat
        end if
        raw(i)=amount;top=bottom
      end do
    else
      total=transmissivity(p,kh,water,finish)
      if(total<=0._real64)return
      top=0._real64
      do i=1,n
        bottom=-p%distribution%zbotcp(i)
        raw(i)=scalar*kh(i)*max(0._real64,min(finish,bottom)-max(water,top))/total
        top=bottom
      end do
    end if
    if(any(.not.ieee_is_finite(raw)))return
    raw_sum=sum(raw);last=0
    do i=1,n
      if(raw(i)/=0._real64)last=i
    end do
    if(last==0)then
      status=FROST_DIVDRA_PARTITION;return
    end if
    raw(last)=scalar-sum(raw(:last-1));correction=scalar-raw_sum
    if(abs(correction)>1.e-14_real64)then
      status=FROST_DIVDRA_PARTITION;return
    end if
    call move_alloc(raw,nodal);status=FROST_DIVDRA_OK
  end subroutine

  pure subroutine compose_single_level_signed_frost_divdra(p,view,factor,frozen_node,frozen_bottom, &
       theta,saturation,raw_scalar,bottom_proposal,result)
    type(frost_divdra_parameters_t), intent(in) :: p
    type(process_hydraulic_view_t), intent(in) :: view
    real(real64), intent(in) :: factor(:),frozen_bottom,theta(:),saturation(:),raw_scalar,bottom_proposal
    integer, intent(in) :: frozen_node
    type(frost_divdra_result_t), intent(out) :: result
    real(real64), allocatable :: initial(:),final(:),conductivity(:)
    real(real64) :: air,scalar,bottom,gwl,correction
    integer :: n,i,status
    result=frost_divdra_result_t()
    if(.not.valid_parameters(p))return
    n=p%distribution%active_nodes
    if(view%active_nodes/=n)return
    if(.not.allocated(view%pressure_head).or..not.allocated(view%water_content))return
    if(size(view%pressure_head)/=n.or.size(view%water_content)/=n)return
    if(any(.not.ieee_is_finite(view%pressure_head)).or.any(.not.ieee_is_finite(view%water_content)))return
    if(size(factor)/=n.or.size(theta)/=n.or.size(saturation)/=n)return
    if(any(.not.ieee_is_finite(factor)).or.any(.not.ieee_is_finite(theta)))return
    if(any(.not.ieee_is_finite(saturation)))return
    if(.not.all(ieee_is_finite([frozen_bottom,raw_scalar,bottom_proposal,view%groundwater_level,view%ponding_depth])))return
    if(any(factor<0._real64).or.any(factor>1._real64))return
    if(any(theta<0._real64).or.any(theta>1._real64).or.any(saturation<0._real64).or.any(saturation>1._real64))return
    if(any(theta/=view%water_content))return
    if(frozen_node< -1.or.frozen_node>=n)return
    if(frozen_node>0)then
      if(frozen_bottom>=0._real64.or.frozen_bottom< p%distribution%zbotcp(n))return
    end if
    if(abs(bottom_proposal)>1.e6_real64)return
    call partition(p,p%distribution%saturated_conductivity,view%groundwater_level,raw_scalar, &
         initial,correction,status)
    if(status/=FROST_DIVDRA_OK)then
      result%status=status;return
    end if
    result%initial_partition_correction=correction
    air=0._real64
    do i=n,1,-1
      air=air+max(0._real64,saturation(i)-theta(i))*p%distribution%dz(i)
      if(i==1)exit
      if(factor(i-1)<=.01_real64)exit
    end do
    result%available_air=air;result%low_air=frozen_node>1.and.air<.01_real64
    bottom=bottom_proposal
    if(result%low_air)then
      result%blocked=frozen_bottom<p%drain_bottom_cm
      scalar=raw_scalar
      if(result%blocked)scalar=0._real64
      if(abs(scalar)<1.e-6_real64)then
        if(result%blocked)then
          bottom=0._real64
        else
          scalar=bottom
        end if
      else
        scalar=scalar*(1._real64+bottom/scalar)
      end if
      allocate(conductivity(n));conductivity=p%distribution%saturated_conductivity*factor+(1._real64-factor)*FLOOR_K
      gwl=min(view%groundwater_level,frozen_bottom)
      call partition(p,conductivity,gwl,scalar,final,correction,status)
      if(status/=FROST_DIVDRA_OK)then
        result%status=status;return
      end if
      result%final_partition_correction=correction
    else
      allocate(final(n));final=initial*factor;scalar=sum(final)
    end if
    result%final_scalar=scalar;result%final_bottom=bottom
    call move_alloc(final,result%final_nodal_sink)
    result%available=.true.;result%status=FROST_DIVDRA_OK
  end subroutine
end module
