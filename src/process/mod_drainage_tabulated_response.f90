module mod_drainage_tabulated_response
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  implicit none
  private

  integer, parameter, public :: DRAIN_TAB_OK = 0
  integer, parameter, public :: DRAIN_TAB_INVALID_PARAMETERS = 1
  integer, parameter, public :: DRAIN_TAB_INVALID_HYDRAULIC_VIEW = 2
  integer, parameter, public :: DRAIN_TAB_UNSUPPORTED_LEGACY_DEGENERATE = 3

  type, public :: drainage_tabulated_parameters_t
    real(real64), allocatable :: groundwater_depth(:)
    real(real64), allocatable :: signed_exchange_rate(:)
  end type drainage_tabulated_parameters_t

  type, public :: drainage_tabulated_result_t
    real(real64) :: signed_soil_to_drain_rate = 0.0_real64
    logical :: derivative_defined = .false.
    real(real64) :: dq_dgroundwater_level = 0.0_real64
  end type drainage_tabulated_result_t

  type, public :: drainage_tabulated_diagnostics_t
    integer :: status = DRAIN_TAB_OK
    logical :: evaluated = .false.
    logical :: clamped_lower = .false.
    logical :: clamped_upper = .false.
    logical :: at_table_knot = .false.
    integer :: segment_index = 0
    real(real64) :: groundwater_level = 0.0_real64
    real(real64) :: groundwater_depth = 0.0_real64
    logical :: mass_is_authoritative_external_transfer = .true.
    logical :: persistent_process_state = .false.
  end type drainage_tabulated_diagnostics_t

  public :: evaluate_tabulated_drainage_response

contains

  subroutine evaluate_tabulated_drainage_response(parameters, hydraulic_view, response, diagnostics)
    type(drainage_tabulated_parameters_t), intent(in) :: parameters
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    type(drainage_tabulated_result_t), intent(out) :: response
    type(drainage_tabulated_diagnostics_t), intent(out) :: diagnostics

    real(real64) :: depth, slope
    integer :: i, n

    response = drainage_tabulated_result_t()
    diagnostics = drainage_tabulated_diagnostics_t()

    if (.not. valid_parameters(parameters)) then
      diagnostics%status = DRAIN_TAB_INVALID_PARAMETERS
      return
    end if

    if (.not. ieee_is_finite(hydraulic_view%groundwater_level)) then
      diagnostics%status = DRAIN_TAB_INVALID_HYDRAULIC_VIEW
      return
    end if

    diagnostics%groundwater_level = hydraulic_view%groundwater_level
    depth = abs(hydraulic_view%groundwater_level)
    diagnostics%groundwater_depth = depth
    n = size(parameters%groundwater_depth)

    ! B1.10 accepts a one-element DRAMET=1 input array. When that single
    ! groundwater-depth knot is zero, the legacy fixed qdrtab storage leaves
    ! the remaining x entries at zero. AFGEN then returns the supplied value
    ! only at depth zero and eventually falls through to qdrtab(50)=0 for any
    ! positive depth. That storage-dependent artifact is not a normalized
    ! response law. Reject the representation explicitly rather than silently
    ! turning it into a constant process law or importing qdrtab padding here.
    if (n == 1 .and. .not. (parameters%groundwater_depth(1) > 0.0_real64)) then
      diagnostics%status = DRAIN_TAB_UNSUPPORTED_LEGACY_DEGENERATE
      return
    end if

    diagnostics%evaluated = .true.

    if (n == 1) then
      response%signed_soil_to_drain_rate = parameters%signed_exchange_rate(1)
      response%derivative_defined = .true.
      response%dq_dgroundwater_level = 0.0_real64
      diagnostics%clamped_lower = .true.
      diagnostics%clamped_upper = .true.
      return
    end if

    if (depth < parameters%groundwater_depth(1)) then
      response%signed_soil_to_drain_rate = parameters%signed_exchange_rate(1)
      response%derivative_defined = .true.
      response%dq_dgroundwater_level = 0.0_real64
      diagnostics%clamped_lower = .true.
      return
    end if

    if (depth > parameters%groundwater_depth(n)) then
      response%signed_soil_to_drain_rate = parameters%signed_exchange_rate(n)
      response%derivative_defined = .true.
      response%dq_dgroundwater_level = 0.0_real64
      diagnostics%clamped_upper = .true.
      return
    end if

    if (.not. (depth > parameters%groundwater_depth(1))) then
      response%signed_soil_to_drain_rate = parameters%signed_exchange_rate(1)
      diagnostics%at_table_knot = .true.
      return
    end if

    do i = 2, n
      if (depth < parameters%groundwater_depth(i)) then
        slope = (parameters%signed_exchange_rate(i) - parameters%signed_exchange_rate(i-1)) / &
             (parameters%groundwater_depth(i) - parameters%groundwater_depth(i-1))
        response%signed_soil_to_drain_rate = parameters%signed_exchange_rate(i-1) + &
             (depth - parameters%groundwater_depth(i-1)) * slope
        if (hydraulic_view%groundwater_level > 0.0_real64) then
          response%dq_dgroundwater_level = slope
        else
          response%dq_dgroundwater_level = -slope
        end if
        response%derivative_defined = .true.
        diagnostics%segment_index = i - 1
        return
      end if

      if (.not. (depth > parameters%groundwater_depth(i))) then
        response%signed_soil_to_drain_rate = parameters%signed_exchange_rate(i)
        diagnostics%at_table_knot = .true.
        diagnostics%segment_index = i - 1
        return
      end if
    end do

    diagnostics%status = DRAIN_TAB_INVALID_PARAMETERS
    diagnostics%evaluated = .false.
    response = drainage_tabulated_result_t()
  end subroutine evaluate_tabulated_drainage_response

  logical function valid_parameters(parameters) result(valid)
    type(drainage_tabulated_parameters_t), intent(in) :: parameters
    integer :: i, n

    valid = .false.
    if (.not. allocated(parameters%groundwater_depth)) return
    if (.not. allocated(parameters%signed_exchange_rate)) return
    n = size(parameters%groundwater_depth)
    if (n < 1) return
    if (size(parameters%signed_exchange_rate) /= n) return
    if (any(.not. ieee_is_finite(parameters%groundwater_depth))) return
    if (any(.not. ieee_is_finite(parameters%signed_exchange_rate))) return
    if (any(parameters%groundwater_depth < 0.0_real64)) return

    do i = 2, n
      if (.not. (parameters%groundwater_depth(i) > parameters%groundwater_depth(i-1))) return
    end do
    valid = .true.
  end function valid_parameters

end module mod_drainage_tabulated_response
