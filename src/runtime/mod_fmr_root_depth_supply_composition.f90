module mod_fmr_root_depth_supply_composition
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_crop_root_depth_rate_owner, only: crop_root_depth_rate_parameters_t, crop_root_depth_rate_state_t, &
       crop_root_depth_rate_daily_forcing_t, crop_root_depth_rate_diagnostics_t, &
       evaluate_crop_root_depth_rate_candidate, CROP_ROOT_RATE_OK, CROP_ROOT_RATE_UNSCALED
  use mod_crop_adaptive_root_profile_owner, only: adaptive_root_profile_state_t, ADAPTIVE_ROOT_PROFILE_OK
  use mod_crop_root_extension_supply_limit, only: root_extension_supply_result_t, &
       limit_root_extension_by_drought_and_supply, ROOT_SUPPLY_OK
  implicit none
  private

  integer, parameter, public :: FMR_ROOT_SUPPLY_OK=0
  integer, parameter, public :: FMR_ROOT_SUPPLY_INVALID_PARAMETERS=1
  integer, parameter, public :: FMR_ROOT_SUPPLY_INVALID_PROFILE=2
  integer, parameter, public :: FMR_ROOT_SUPPLY_MISSING_DROUGHT=3
  integer, parameter, public :: FMR_ROOT_SUPPLY_BASE_ERROR=4
  integer, parameter, public :: FMR_ROOT_SUPPLY_LIMIT_ERROR=5
  integer, parameter, public :: FMR_ROOT_SUPPLY_INVALID_RESULT=6

  type, public :: fmr_root_supply_parameters_t
    real(real64) :: minimum_extension_cm=0.0_real64 ! RRIMIN
    real(real64) :: drought_extension_threshold=1.0_real64 ! EXTENTCRIT
    real(real64) :: negligible_extension_cm=0.0_real64 ! SMALL
  contains
    procedure, public :: ready=>fmr_root_supply_parameters_ready
  end type

  type, public :: fmr_root_supply_diagnostics_t
    type(crop_root_depth_rate_diagnostics_t) :: base
    type(root_extension_supply_result_t) :: supply
    integer :: deepest_rooted_node=0
    logical :: supply_evaluated=.false.
  end type

  public :: evaluate_swrd2_supply_limited_candidate

contains

  logical function fmr_root_supply_parameters_ready(self) result(ready)
    class(fmr_root_supply_parameters_t),intent(in)::self
    ready=.false.
    if(.not.ieee_is_finite(self%minimum_extension_cm).or.self%minimum_extension_cm<0.0_real64)return
    if(.not.ieee_is_finite(self%drought_extension_threshold).or. &
         self%drought_extension_threshold<=0.0_real64.or.self%drought_extension_threshold>1.0_real64)return
    if(.not.ieee_is_finite(self%negligible_extension_cm).or.self%negligible_extension_cm<0.0_real64)return
    ready=.true.
  end function

  subroutine evaluate_swrd2_supply_limited_candidate(rate_parameters,supply_parameters,committed_depth, &
       forcing,adaptive_profile,ztopcp_cm,zbotcp_cm,candidate,diagnostics,status)
    type(crop_root_depth_rate_parameters_t),intent(in)::rate_parameters
    type(fmr_root_supply_parameters_t),intent(in)::supply_parameters
    type(crop_root_depth_rate_state_t),intent(in)::committed_depth
    type(crop_root_depth_rate_daily_forcing_t),intent(in)::forcing
    type(adaptive_root_profile_state_t),intent(in)::adaptive_profile
    real(real64),intent(in)::ztopcp_cm(:),zbotcp_cm(:)
    type(crop_root_depth_rate_state_t),intent(out)::candidate
    type(fmr_root_supply_diagnostics_t),intent(out)::diagnostics
    integer,intent(out)::status

    type(crop_root_depth_rate_state_t)::base_candidate
    integer::base_status,node,supply_status
    real(real64)::proposed_extension

    candidate=committed_depth
    diagnostics=fmr_root_supply_diagnostics_t()
    status=FMR_ROOT_SUPPLY_INVALID_PARAMETERS
    if(.not.rate_parameters%ready().or..not.supply_parameters%ready())return
    ! SWDMI2RD=2 is a separate source branch from SWDMI2RD=1. The base owner
    ! must therefore expose the unscaled RRI-limited RR to this composition.
    if(rate_parameters%actual_extension_mode/=CROP_ROOT_RATE_UNSCALED)return

    status=FMR_ROOT_SUPPLY_INVALID_PROFILE
    if(adaptive_profile%validate()/=ADAPTIVE_ROOT_PROFILE_OK)return
    if(size(ztopcp_cm)/=size(adaptive_profile%root_biomass_by_node).or. &
         size(zbotcp_cm)/=size(adaptive_profile%root_biomass_by_node))return
    if(any(.not.ieee_is_finite(ztopcp_cm)).or.any(.not.ieee_is_finite(zbotcp_cm)))return

    call evaluate_crop_root_depth_rate_candidate(rate_parameters,committed_depth,forcing,base_candidate, &
         diagnostics%base,base_status)
    if(base_status/=CROP_ROOT_RATE_OK.or..not.diagnostics%base%candidate_built)then
      status=FMR_ROOT_SUPPLY_BASE_ERROR
      return
    end if

    candidate=base_candidate
    if(.not.diagnostics%base%actual_extension_allowed .or. diagnostics%base%actual_extension_before_scaling_cm<=0.0_real64)then
      status=FMR_ROOT_SUPPLY_OK
      return
    end if

    status=FMR_ROOT_SUPPLY_MISSING_DROUGHT
    if(.not.forcing%rootzone_drought_uptake_factor_available)return

    node=deepest_rooted_node(committed_depth%actual_root_depth_cm,zbotcp_cm)
    if(node<=0.or.node>size(adaptive_profile%root_biomass_by_node))then
      status=FMR_ROOT_SUPPLY_INVALID_PROFILE
      return
    end if
    diagnostics%deepest_rooted_node=node
    proposed_extension=diagnostics%base%actual_extension_before_scaling_cm

    call limit_root_extension_by_drought_and_supply(proposed_extension,supply_parameters%minimum_extension_cm, &
         forcing%rootzone_drought_uptake_factor_integral,supply_parameters%drought_extension_threshold, &
         adaptive_profile%root_biomass_by_node(node),committed_depth%actual_root_depth_cm,ztopcp_cm(node), &
         forcing%actual_root_growth,supply_parameters%negligible_extension_cm,diagnostics%supply,supply_status)
    if(supply_status/=ROOT_SUPPLY_OK)then
      status=FMR_ROOT_SUPPLY_LIMIT_ERROR
      return
    end if
    diagnostics%supply_evaluated=.true.

    candidate%actual_root_depth_cm=committed_depth%actual_root_depth_cm+diagnostics%supply%extension_cm
    if(candidate%validate()/=CROP_ROOT_RATE_OK.or. &
         candidate%actual_root_depth_cm>candidate%potential_root_depth_cm+ &
         256.0_real64*epsilon(1.0_real64)*max(1.0_real64,candidate%potential_root_depth_cm))then
      candidate=committed_depth
      status=FMR_ROOT_SUPPLY_INVALID_RESULT
      return
    end if
    status=FMR_ROOT_SUPPLY_OK
  end subroutine evaluate_swrd2_supply_limited_candidate

  integer function deepest_rooted_node(root_depth_cm,zbotcp_cm) result(node)
    real(real64),intent(in)::root_depth_cm,zbotcp_cm(:)
    integer::i
    node=0
    if(.not.ieee_is_finite(root_depth_cm).or.root_depth_cm<=0.0_real64)return
    do i=1,size(zbotcp_cm)
      if(zbotcp_cm(i)<(-root_depth_cm+1.0e-8_real64))then
        node=i
        return
      end if
    end do
  end function deepest_rooted_node

end module mod_fmr_root_depth_supply_composition
