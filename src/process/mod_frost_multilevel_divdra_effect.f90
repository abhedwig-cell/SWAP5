module mod_frost_multilevel_divdra_effect
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_frost_divdra_drainage_effect, only: frost_divdra_parameters_t, valid_frost_divdra_parameters
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t, &
       drainage_multilevel_diagnostics_t, distribute_multilevel_signed_divdra, DRAIN_DIST_OK
  use mod_drainage_b19_separate_infiltration_adapter, only: &
       drainage_b19_separate_infiltration_parameters_t, distribute_multilevel_separate_infiltration_b19, DRAIN_B19_INF_OK
  implicit none
  private
  ! Covers both B1.11 MOD_arrays drainage profiles (madr=5 and madr=25).
  integer, parameter, public :: FROST_DIVDRA_MAX_LEVELS=25
  type, public :: frost_multilevel_divdra_result_t
    logical :: available=.false., low_air=.false., net_policy_applied=.false.
    integer :: status=1
    real(real64) :: available_air=0._real64, final_bottom=0._real64
    real(real64), allocatable :: retained_scalar(:), final_scalar(:), final_nodal_sink(:,:)
    logical, allocatable :: blocked(:)
  end type
  public :: compose_multilevel_signed_frost_divdra, valid_multilevel_frost_divdra
contains
  pure logical function valid_multilevel_frost_divdra(p) result(ok)
    type(frost_divdra_parameters_t), intent(in) :: p(:)
    integer :: l
    ok=.false.
    if(size(p)<2.or.size(p)>FROST_DIVDRA_MAX_LEVELS)return
    do l=1,size(p)
      if(.not.valid_frost_divdra_parameters(p(l)))return
      if(l>1)then
        if(p(l)%drain_bottom_cm>=p(l-1)%drain_bottom_cm)return
      end if
      if(p(l)%distribution%active_nodes/=p(1)%distribution%active_nodes)return
      if(any(p(l)%distribution%dz/=p(1)%distribution%dz))return
      if(any(p(l)%distribution%zbotcp/=p(1)%distribution%zbotcp))return
      if(any(p(l)%distribution%saturated_conductivity/=p(1)%distribution%saturated_conductivity))return
      if(any(p(l)%distribution%horizontal_anisotropy_factor/=p(1)%distribution%horizontal_anisotropy_factor))return
      if(p(l)%separate_infiltration.neqv.p(1)%separate_infiltration)return
    end do
    ok=.true.
  end function

  subroutine compose_multilevel_signed_frost_divdra(p,view,factor,frozen_node,frozen_bottom, &
       theta,saturation,raw_scalar,bottom_proposal,result)
    type(frost_divdra_parameters_t), intent(in) :: p(:)
    type(process_hydraulic_view_t), intent(in) :: view
    real(real64), intent(in) :: factor(:),frozen_bottom,theta(:),saturation(:),raw_scalar(:),bottom_proposal
    integer, intent(in) :: frozen_node
    type(frost_multilevel_divdra_result_t), intent(out) :: result
    type(drainage_distribution_parameters_t), allocatable :: distribution(:)
    type(drainage_b19_separate_infiltration_parameters_t), allocatable :: infiltration(:)
    type(process_hydraulic_view_t) :: effective_view
    real(real64), allocatable :: initial(:,:),final(:,:),rates(:),retained(:)
    logical, allocatable :: blocked(:)
    real(real64) :: air,total,absolute,bottom
    integer :: n,l,i,levels,deepest,status
    result=frost_multilevel_divdra_result_t()
    if(.not.valid_multilevel_frost_divdra(p))return
    levels=size(p);n=p(1)%distribution%active_nodes
    if(size(raw_scalar)/=levels.or.size(factor)/=n.or.size(theta)/=n.or.size(saturation)/=n)return
    if(view%active_nodes/=n)return
    if(.not.allocated(view%pressure_head).or..not.allocated(view%water_content))return
    if(size(view%pressure_head)/=n.or.size(view%water_content)/=n)return
    if(any(.not.ieee_is_finite(view%pressure_head)).or.any(.not.ieee_is_finite(view%water_content)))return
    if(any(.not.ieee_is_finite(raw_scalar)).or.any(.not.ieee_is_finite(factor)))return
    if(any(.not.ieee_is_finite(theta)).or.any(.not.ieee_is_finite(saturation)))return
    if(.not.all(ieee_is_finite([frozen_bottom,bottom_proposal,view%groundwater_level,view%ponding_depth])))return
    if(any(abs(raw_scalar)>1.e6_real64).or.abs(bottom_proposal)>1.e6_real64)return
    if(any(factor<0._real64).or.any(factor>1._real64))return
    if(any(theta<0._real64).or.any(theta>1._real64).or.any(saturation<0._real64).or.any(saturation>1._real64))return
    if(any(theta/=view%water_content))return
    if(frozen_node< -1.or.frozen_node>=n)return
    if(frozen_node>0)then
      if(frozen_bottom>=0._real64.or.frozen_bottom<p(1)%distribution%zbotcp(n))return
    end if
    allocate(distribution(levels),infiltration(levels),blocked(levels))
    do l=1,levels
      distribution(l)=p(l)%distribution
      infiltration(l)%drain_level_cm=p(l)%surface_water_level_cm
      infiltration(l)%infiltration_depth_factor=p(l)%infiltration_depth_factor
    end do
    call partition(view,raw_scalar,initial,status)
    if(status/=0)then
      result%status=status;return
    end if
    air=0._real64
    do i=n,1,-1
      air=air+max(0._real64,saturation(i)-theta(i))*distribution(1)%dz(i)
      if(i==1)exit
      if(factor(i-1)<=.01_real64)exit
    end do
    result%available_air=air;result%low_air=frozen_node>1.and.air<.01_real64
    bottom=bottom_proposal;rates=raw_scalar;blocked=.false.
    if(result%low_air)then
      do l=1,levels
        blocked(l)=frozen_bottom<p(l)%drain_bottom_cm
        if(blocked(l))rates(l)=0._real64
      end do
      retained=rates
      total=0._real64;absolute=0._real64
      do l=1,levels
        total=total+rates(l);absolute=absolute+abs(rates(l))
      end do
      if(minval(rates)<-1.e-10_real64.and.maxval(rates)>1.e-10_real64)then
        result%net_policy_applied=.true.
        do l=1,levels
          rates(l)=rates(l)+bottom*abs(rates(l))/absolute
        end do
      else if(abs(total)<1.e-6_real64)then
        deepest=minloc(p%drain_bottom_cm,dim=1)
        if(blocked(deepest))then
          bottom=0._real64
        else
          rates(deepest)=bottom
        end if
      else
        rates=rates*(1._real64+bottom/total)
      end if
      do l=1,levels
        distribution(l)%saturated_conductivity= &
             p(l)%distribution%saturated_conductivity*factor+(1._real64-factor)*1.e-10_real64
      end do
      effective_view=view;effective_view%groundwater_level=min(view%groundwater_level,frozen_bottom)
      call partition(effective_view,rates,final,status)
      if(status/=0)then
        result%status=status;return
      end if
    else
      retained=raw_scalar;final=initial
      do l=1,levels
        final(l,:)=initial(l,:)*factor
        rates(l)=sum(final(l,:))
      end do
    end if
    if(any(.not.ieee_is_finite(final)))return
    do l=1,levels
      if(abs(sum(final(l,:))-rates(l))>1.e-14_real64)return
    end do
    if(result%net_policy_applied)then
      if(abs(bottom-sum(final)+sum(retained))>1.e-14_real64)return
    end if
    result%final_bottom=bottom
    call move_alloc(retained,result%retained_scalar);call move_alloc(rates,result%final_scalar)
    call move_alloc(blocked,result%blocked);call move_alloc(final,result%final_nodal_sink)
    result%available=.true.;result%status=0
  contains
    subroutine partition(hydraulic,scalar,nodal,status)
      type(process_hydraulic_view_t),intent(in)::hydraulic
      real(real64),intent(in)::scalar(:)
      real(real64),allocatable,intent(out)::nodal(:,:)
      integer,intent(out)::status
      type(drainage_multilevel_diagnostics_t)::diagnostics
      if(p(1)%separate_infiltration)then
        call distribute_multilevel_separate_infiltration_b19(distribution,hydraulic,scalar,infiltration,nodal,status)
        if(status/=DRAIN_B19_INF_OK)status=2
      else
        call distribute_multilevel_signed_divdra(distribution,hydraulic,scalar,nodal,diagnostics)
        status=0
        if(diagnostics%status/=DRAIN_DIST_OK.or..not.diagnostics%evaluated)status=2
      end if
    end subroutine
  end subroutine
end module
