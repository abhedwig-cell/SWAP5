module mod_drainage_extended_exchange
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  implicit none
  private

  integer, parameter, public :: EXT_DRAIN_OK = 0
  integer, parameter, public :: EXT_DRAIN_INVALID_PARAMETERS = 1
  integer, parameter, public :: EXT_DRAIN_INVALID_HYDRAULIC_VIEW = 2
  integer, parameter, public :: EXT_DRAIN_INVALID_CONTROL = 3
  integer, parameter, public :: EXT_DRAIN_HELD_NEGATIVE_POWER_INTERFLOW = 4

  integer, parameter, public :: EXT_DRAIN_TUBE = 1
  integer, parameter, public :: EXT_DRAIN_OPEN_CHANNEL = 2
  integer, parameter, public :: EXT_DRAIN_TOP_NONE = 0
  integer, parameter, public :: EXT_DRAIN_TOP_SURFACE_RESISTANCE = 1
  integer, parameter, public :: EXT_DRAIN_TOP_POWER_INTERFLOW = 2

  integer, parameter, public :: EXT_DRAIN_BRANCH_NOT_EVALUATED = 0
  integer, parameter, public :: EXT_DRAIN_BRANCH_SUPPRESSED = 1
  integer, parameter, public :: EXT_DRAIN_BRANCH_INACTIVE = 2
  integer, parameter, public :: EXT_DRAIN_BRANCH_POSITIVE = 3
  integer, parameter, public :: EXT_DRAIN_BRANCH_NEGATIVE = 4
  integer, parameter, public :: EXT_DRAIN_BRANCH_GWLINF_CAP = 5
  integer, parameter, public :: EXT_DRAIN_BRANCH_POWER = 6

  real(real64), parameter :: LEGACY_ACTIVE_EPS_CM = 0.001_real64
  real(real64), parameter :: LEGACY_POND_SWITCH_CM = -0.1_real64

  type, public :: extended_drainage_parameters_t
    real(real64) :: zbotdr_cm = 0.0_real64
    integer :: drain_type = EXT_DRAIN_TUBE
    real(real64) :: width_cm = 0.0_real64
    real(real64) :: talud = 1.0_real64
    real(real64) :: spacing_cm = 0.0_real64
    real(real64) :: rdrain_day = 0.0_real64
    real(real64) :: rinfi_day = 0.0_real64
    real(real64) :: rentry_day = 0.0_real64
    real(real64) :: rexit_day = 0.0_real64
    real(real64) :: gwlinf_cm = 0.0_real64
    real(real64) :: pondmx_cm = 0.0_real64
    logical :: highest_level = .false.
    integer :: highest_surface_mode = EXT_DRAIN_TOP_NONE
    real(real64) :: rsurfdeep_day = 0.0_real64
    real(real64) :: rsurfshallow_day = 0.0_real64
    real(real64) :: interflow_coefficient = 0.0_real64
    real(real64) :: interflow_exponent = 0.0_real64
  end type extended_drainage_parameters_t

  type, public :: extended_drainage_control_t
    real(real64) :: resolved_surface_water_head_cm = 0.0_real64
  end type extended_drainage_control_t

  type, public :: extended_drainage_result_t
    real(real64) :: signed_soil_to_surface_rate_cm_day = 0.0_real64
    real(real64) :: resolved_drain_level_cm = 0.0_real64
    real(real64) :: effective_head_difference_cm = 0.0_real64
    logical :: derivative_defined = .false.
    real(real64) :: dq_dgroundwater_level = 0.0_real64
    real(real64) :: dq_dcontrol_head = 0.0_real64
    real(real64) :: dq_dponding_depth = 0.0_real64
  end type extended_drainage_result_t

  type, public :: extended_drainage_diagnostics_t
    integer :: status = EXT_DRAIN_OK
    integer :: branch = EXT_DRAIN_BRANCH_NOT_EVALUATED
    logical :: evaluated = .false.
    logical :: active = .false.
    logical :: suppressed = .false.
    logical :: gwlinf_cap_active = .false.
    logical :: ponding_switch_boundary = .false.
    logical :: activation_boundary = .false.
    logical :: control_head_branch_boundary = .false.
    logical :: sign_resistance_boundary = .false.
    logical :: surface_resistance_boundary = .false.
    logical :: power_activation_boundary = .false.
    logical :: mass_is_authoritative_signed_transfer = .true.
    logical :: persistent_process_state = .false.
  end type extended_drainage_diagnostics_t

  public :: evaluate_extended_drainage_exchange
  public :: validate_extended_drainage_parameters

contains

  pure logical function same_real_bits(a, b) result(same)
    real(real64), intent(in) :: a, b
    same = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_real_bits

  subroutine validate_extended_drainage_parameters(parameters, ok)
    type(extended_drainage_parameters_t), intent(in) :: parameters
    logical, intent(out) :: ok

    ok = .false.
    if (.not. ieee_is_finite(parameters%zbotdr_cm)) return
    if (parameters%drain_type /= EXT_DRAIN_TUBE .and. parameters%drain_type /= EXT_DRAIN_OPEN_CHANNEL) return
    if (.not. ieee_is_finite(parameters%spacing_cm) .or. parameters%spacing_cm < 100.0_real64 .or. &
        parameters%spacing_cm > 1.0e7_real64) return
    if (.not. ieee_is_finite(parameters%rdrain_day) .or. parameters%rdrain_day < 1.0_real64 .or. &
        parameters%rdrain_day > 1.0e5_real64) return
    if (.not. ieee_is_finite(parameters%rinfi_day) .or. parameters%rinfi_day < 1.0_real64 .or. &
        parameters%rinfi_day > 1.0e5_real64) return
    if (.not. ieee_is_finite(parameters%rentry_day) .or. parameters%rentry_day < 0.0_real64 .or. &
        parameters%rentry_day > 10.0_real64) return
    if (.not. ieee_is_finite(parameters%rexit_day) .or. parameters%rexit_day < 0.0_real64 .or. &
        parameters%rexit_day > 10.0_real64) return
    if (.not. ieee_is_finite(parameters%gwlinf_cm) .or. parameters%gwlinf_cm > parameters%zbotdr_cm) return
    if (.not. ieee_is_finite(parameters%pondmx_cm)) return

    if (parameters%drain_type == EXT_DRAIN_OPEN_CHANNEL) then
      if (.not. ieee_is_finite(parameters%width_cm) .or. parameters%width_cm < 0.0001_real64) return
      if (.not. ieee_is_finite(parameters%talud) .or. parameters%talud < 0.01_real64 .or. &
          parameters%talud > 5.0_real64) return
    end if

    if (parameters%highest_surface_mode < EXT_DRAIN_TOP_NONE .or. &
        parameters%highest_surface_mode > EXT_DRAIN_TOP_POWER_INTERFLOW) return
    if (parameters%highest_level .and. parameters%highest_surface_mode == EXT_DRAIN_TOP_SURFACE_RESISTANCE) then
      if (.not. ieee_is_finite(parameters%rsurfdeep_day) .or. parameters%rsurfdeep_day < 0.001_real64 .or. &
          parameters%rsurfdeep_day > 1000.0_real64) return
      if (.not. ieee_is_finite(parameters%rsurfshallow_day) .or. parameters%rsurfshallow_day < 0.001_real64 .or. &
          parameters%rsurfshallow_day > 1000.0_real64) return
    end if
    if (parameters%highest_level .and. parameters%highest_surface_mode == EXT_DRAIN_TOP_POWER_INTERFLOW) then
      if (.not. ieee_is_finite(parameters%interflow_coefficient) .or. parameters%interflow_coefficient < 0.01_real64 .or. &
          parameters%interflow_coefficient > 10.0_real64) return
      if (.not. ieee_is_finite(parameters%interflow_exponent) .or. parameters%interflow_exponent < 0.1_real64 .or. &
          parameters%interflow_exponent > 1.0_real64) return
    end if
    ok = .true.
  end subroutine validate_extended_drainage_parameters

  subroutine evaluate_extended_drainage_exchange(parameters, hydraulic_view, control, result, diagnostics)
    type(extended_drainage_parameters_t), intent(in) :: parameters
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    type(extended_drainage_control_t), intent(in) :: control
    type(extended_drainage_result_t), intent(out) :: result
    type(extended_drainage_diagnostics_t), intent(out) :: diagnostics

    real(real64) :: gwl, wl, pond, threshold, drain_level, dlevel_dwl
    real(real64) :: depth, root, wet_perimeter, dwet_dwl
    real(real64) :: raw_head, effective_head
    real(real64) :: de_dgwl, de_dwl, de_dpond
    real(real64) :: rd, re, dr_de, denominator, dden_dgwl, dden_dwl, dden_dpond
    real(real64) :: unconstrained_rd, factor
    logical :: ok, branch_boundary

    result = extended_drainage_result_t()
    diagnostics = extended_drainage_diagnostics_t()

    call validate_extended_drainage_parameters(parameters, ok)
    if (.not. ok) then
      diagnostics%status = EXT_DRAIN_INVALID_PARAMETERS
      return
    end if

    gwl = hydraulic_view%groundwater_level
    pond = hydraulic_view%ponding_depth
    wl = control%resolved_surface_water_head_cm
    if (.not. ieee_is_finite(gwl) .or. .not. ieee_is_finite(pond)) then
      diagnostics%status = EXT_DRAIN_INVALID_HYDRAULIC_VIEW
      return
    end if
    if (.not. ieee_is_finite(wl)) then
      diagnostics%status = EXT_DRAIN_INVALID_CONTROL
      return
    end if

    diagnostics%evaluated = .true.
    threshold = parameters%zbotdr_cm + LEGACY_ACTIVE_EPS_CM

    if (.not. (wl < parameters%pondmx_cm .or. gwl < parameters%pondmx_cm)) then
      diagnostics%suppressed = .true.
      diagnostics%branch = EXT_DRAIN_BRANCH_SUPPRESSED
      result%derivative_defined = (.not. same_real_bits(wl, parameters%pondmx_cm) .and. &
                                   .not. same_real_bits(gwl, parameters%pondmx_cm))
      return
    end if

    if (.not. (gwl > threshold .or. wl > threshold)) then
      diagnostics%branch = EXT_DRAIN_BRANCH_INACTIVE
      diagnostics%activation_boundary = (same_real_bits(gwl, threshold) .or. same_real_bits(wl, threshold))
      result%derivative_defined = .not. diagnostics%activation_boundary
      return
    end if
    diagnostics%active = .true.

    diagnostics%control_head_branch_boundary = same_real_bits(wl, threshold)
    if (wl <= threshold) then
      drain_level = parameters%zbotdr_cm
      dlevel_dwl = 0.0_real64
      wet_perimeter = parameters%width_cm
      dwet_dwl = 0.0_real64
    else
      drain_level = wl
      dlevel_dwl = 1.0_real64
      if (parameters%drain_type == EXT_DRAIN_OPEN_CHANNEL) then
        depth = wl - parameters%zbotdr_cm
        root = sqrt(depth * depth + (depth / parameters%talud) ** 2)
        wet_perimeter = parameters%width_cm + 2.0_real64 * root
        dwet_dwl = 2.0_real64 * depth * (1.0_real64 + 1.0_real64 / parameters%talud**2) / root
      else
        wet_perimeter = 0.0_real64
        dwet_dwl = 0.0_real64
      end if
    end if
    result%resolved_drain_level_cm = drain_level

    raw_head = gwl - drain_level
    diagnostics%ponding_switch_boundary = same_real_bits(gwl, LEGACY_POND_SWITCH_CM)
    if (gwl > LEGACY_POND_SWITCH_CM) raw_head = raw_head + pond

    effective_head = raw_head
    de_dgwl = 1.0_real64
    de_dwl = -dlevel_dwl
    if (gwl > LEGACY_POND_SWITCH_CM) then
      de_dpond = 1.0_real64
    else
      de_dpond = 0.0_real64
    end if

    diagnostics%gwlinf_cap_active = (raw_head < 0.0_real64 .and. gwl < parameters%gwlinf_cm)
    if (diagnostics%gwlinf_cap_active) then
      effective_head = parameters%gwlinf_cm - drain_level
      de_dgwl = 0.0_real64
      de_dwl = -dlevel_dwl
      de_dpond = 0.0_real64
      diagnostics%branch = EXT_DRAIN_BRANCH_GWLINF_CAP
    end if
    result%effective_head_difference_cm = effective_head

    branch_boundary = diagnostics%ponding_switch_boundary .or. diagnostics%control_head_branch_boundary
    if (raw_head < 0.0_real64 .and. same_real_bits(gwl, parameters%gwlinf_cm)) branch_boundary = .true.

    if (parameters%highest_level .and. parameters%highest_surface_mode == EXT_DRAIN_TOP_POWER_INTERFLOW) then
      if (effective_head < 0.0_real64) then
        diagnostics%status = EXT_DRAIN_HELD_NEGATIVE_POWER_INTERFLOW
        return
      end if
      diagnostics%branch = EXT_DRAIN_BRANCH_POWER
      diagnostics%power_activation_boundary = same_real_bits(effective_head, 0.0_real64)
      result%signed_soil_to_surface_rate_cm_day = parameters%interflow_coefficient * &
           effective_head**parameters%interflow_exponent
      if (diagnostics%power_activation_boundary) then
        result%derivative_defined = .false.
        return
      end if
      factor = parameters%interflow_coefficient * parameters%interflow_exponent * &
           effective_head**(parameters%interflow_exponent - 1.0_real64)
      result%dq_dgroundwater_level = factor * de_dgwl
      result%dq_dcontrol_head = factor * de_dwl
      result%dq_dponding_depth = factor * de_dpond
      result%derivative_defined = .not. branch_boundary
      return
    end if

    if (effective_head > 0.0_real64) then
      diagnostics%branch = EXT_DRAIN_BRANCH_POSITIVE
      rd = parameters%rdrain_day
      re = parameters%rentry_day
      dr_de = 0.0_real64
      if (parameters%highest_level .and. parameters%highest_surface_mode == EXT_DRAIN_TOP_SURFACE_RESISTANCE) then
        unconstrained_rd = parameters%rsurfdeep_day - effective_head
        diagnostics%surface_resistance_boundary = same_real_bits(unconstrained_rd, parameters%rsurfshallow_day)
        if (unconstrained_rd > parameters%rsurfshallow_day) then
          rd = unconstrained_rd
          dr_de = -1.0_real64
        else
          rd = parameters%rsurfshallow_day
        end if
      end if
    else
      if (.not. diagnostics%gwlinf_cap_active) diagnostics%branch = EXT_DRAIN_BRANCH_NEGATIVE
      rd = parameters%rinfi_day
      re = parameters%rexit_day
      dr_de = 0.0_real64
      diagnostics%sign_resistance_boundary = same_real_bits(effective_head, 0.0_real64)
    end if

    if (parameters%drain_type == EXT_DRAIN_OPEN_CHANNEL) then
      denominator = rd + re * parameters%spacing_cm / wet_perimeter
    else
      denominator = rd
    end if
    if (.not. ieee_is_finite(denominator) .or. denominator <= 0.0_real64) then
      diagnostics%status = EXT_DRAIN_INVALID_PARAMETERS
      result = extended_drainage_result_t()
      return
    end if

    result%signed_soil_to_surface_rate_cm_day = effective_head / denominator

    if (diagnostics%sign_resistance_boundary .or. diagnostics%surface_resistance_boundary) branch_boundary = .true.
    if (branch_boundary) then
      result%derivative_defined = .false.
      return
    end if

    dden_dgwl = dr_de * de_dgwl
    dden_dwl = dr_de * de_dwl
    dden_dpond = dr_de * de_dpond
    if (parameters%drain_type == EXT_DRAIN_OPEN_CHANNEL) then
      dden_dwl = dden_dwl - re * parameters%spacing_cm * dwet_dwl / wet_perimeter**2
    end if

    result%dq_dgroundwater_level = (de_dgwl * denominator - effective_head * dden_dgwl) / denominator**2
    result%dq_dcontrol_head = (de_dwl * denominator - effective_head * dden_dwl) / denominator**2
    result%dq_dponding_depth = (de_dpond * denominator - effective_head * dden_dpond) / denominator**2
    result%derivative_defined = .true.
  end subroutine evaluate_extended_drainage_exchange

end module mod_drainage_extended_exchange
