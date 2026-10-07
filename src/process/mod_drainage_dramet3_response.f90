module mod_drainage_dramet3_response
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  implicit none
  private

  integer, parameter, public :: DRAIN_DRAMET3_OK = 0
  integer, parameter, public :: DRAIN_DRAMET3_INVALID_PARAMETERS = 1
  integer, parameter, public :: DRAIN_DRAMET3_INVALID_HYDRAULIC_VIEW = 2
  integer, parameter, public :: DRAIN_DRAMET3_INVALID_TIME = 3

  integer, parameter, public :: DRAIN_DRAMET3_BRANCH_ZERO = 0
  integer, parameter, public :: DRAIN_DRAMET3_BRANCH_DRAINAGE = 1
  integer, parameter, public :: DRAIN_DRAMET3_BRANCH_INFILTRATION = 2
  integer, parameter, public :: DRAIN_DRAMET3_BRANCH_SUPPRESSED = 3
  integer, parameter, public :: DRAIN_DRAMET3_BRANCH_INFILTRATION_CAP = 4

  type, public :: drainage_dramet3_parameters_t
    real(real64) :: zbotdr_cm = 0.0_real64
    real(real64) :: drainage_resistance_day = 0.0_real64
    real(real64) :: infiltration_resistance_day = 0.0_real64
    integer :: allocation_mode = 1
    integer :: drain_type = 1
    logical :: limit_infiltration_head = .false.
    real(real64) :: canonical_origin_time = 0.0_real64
    real(real64) :: legacy_t1900_origin = 0.0_real64
    real(real64), allocatable :: surface_water_time_t1900(:)
    real(real64), allocatable :: surface_water_head_cm(:)
  end type drainage_dramet3_parameters_t

  type, public :: drainage_dramet3_result_t
    real(real64) :: signed_soil_to_drain_rate = 0.0_real64
    logical :: derivative_defined = .false.
    real(real64) :: dq_dgroundwater_level = 0.0_real64
    real(real64) :: resolved_surface_water_head_cm = 0.0_real64
    real(real64) :: resolved_drain_level_cm = 0.0_real64
    real(real64) :: effective_head_difference_cm = 0.0_real64
    real(real64) :: sample_time_t1900 = 0.0_real64
  end type drainage_dramet3_result_t

  type, public :: drainage_dramet3_diagnostics_t
    integer :: status = DRAIN_DRAMET3_OK
    integer :: branch = DRAIN_DRAMET3_BRANCH_ZERO
    logical :: evaluated = .false.
    logical :: drain_bottom_clamp_active = .false.
    logical :: infiltration_head_cap_active = .false.
    logical :: allocation_suppressed = .false.
    logical :: branch_boundary = .false.
    logical :: mass_is_authoritative_signed_transfer = .true.
    logical :: persistent_process_state = .false.
  end type drainage_dramet3_diagnostics_t

  public :: evaluate_drainage_dramet3_response
  public :: valid_drainage_dramet3_parameters

contains

  logical function valid_drainage_dramet3_parameters(p) result(ok)
    type(drainage_dramet3_parameters_t), intent(in) :: p
    integer :: i, n
    ok=.false.
    if(.not.ieee_is_finite(p%zbotdr_cm) .or. p%zbotdr_cm < -1.0e4_real64 .or. p%zbotdr_cm > 0.0_real64)return
    if(.not.ieee_is_finite(p%drainage_resistance_day) .or. p%drainage_resistance_day < 1.0_real64)return
    if(.not.ieee_is_finite(p%infiltration_resistance_day) .or. p%infiltration_resistance_day < 0.0_real64)return
    if(p%allocation_mode < 1 .or. p%allocation_mode > 3)return
    if(p%drain_type < 1 .or. p%drain_type > 2)return
    if(.not.ieee_is_finite(p%canonical_origin_time) .or. .not.ieee_is_finite(p%legacy_t1900_origin))return
    if(.not.allocated(p%surface_water_time_t1900) .or. .not.allocated(p%surface_water_head_cm))return
    n=size(p%surface_water_time_t1900)
    if(n<=0 .or. size(p%surface_water_head_cm)/=n)return
    if(any(.not.ieee_is_finite(p%surface_water_time_t1900)) .or. any(.not.ieee_is_finite(p%surface_water_head_cm)))return
    do i=2,n
      if(p%surface_water_time_t1900(i)<=p%surface_water_time_t1900(i-1))return
    end do
    ok=.true.
  end function valid_drainage_dramet3_parameters

  subroutine evaluate_drainage_dramet3_response(p, hydraulic_view, canonical_time, result, diagnostics)
    type(drainage_dramet3_parameters_t), intent(in) :: p
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    real(real64), intent(in) :: canonical_time
    type(drainage_dramet3_result_t), intent(out) :: result
    type(drainage_dramet3_diagnostics_t), intent(out) :: diagnostics
    real(real64) :: legacy_time, water_head, drain_level, diffl, cap

    result=drainage_dramet3_result_t()
    diagnostics=drainage_dramet3_diagnostics_t()
    if(.not.valid_drainage_dramet3_parameters(p))then
      diagnostics%status=DRAIN_DRAMET3_INVALID_PARAMETERS;return
    end if
    if(.not.ieee_is_finite(hydraulic_view%groundwater_level))then
      diagnostics%status=DRAIN_DRAMET3_INVALID_HYDRAULIC_VIEW;return
    end if
    if(.not.ieee_is_finite(canonical_time))then
      diagnostics%status=DRAIN_DRAMET3_INVALID_TIME;return
    end if
    legacy_time=p%legacy_t1900_origin+(canonical_time-p%canonical_origin_time)
    if(.not.ieee_is_finite(legacy_time))then
      diagnostics%status=DRAIN_DRAMET3_INVALID_TIME;return
    end if
    water_head=afgen_pairs(p%surface_water_time_t1900,p%surface_water_head_cm,legacy_time)
    drain_level=max(water_head,p%zbotdr_cm)
    diffl=hydraulic_view%groundwater_level-drain_level
    result%sample_time_t1900=legacy_time
    result%resolved_surface_water_head_cm=water_head
    result%resolved_drain_level_cm=drain_level
    diagnostics%drain_bottom_clamp_active=water_head<p%zbotdr_cm
    diagnostics%evaluated=.true.

    if(diffl>=0.0_real64)then
      result%effective_head_difference_cm=diffl
      diagnostics%branch_boundary=(diffl==0.0_real64)
      if(p%allocation_mode==2)then
        diagnostics%allocation_suppressed=.true.
        diagnostics%branch=DRAIN_DRAMET3_BRANCH_SUPPRESSED
        result%derivative_defined=.not.diagnostics%branch_boundary
        return
      end if
      diagnostics%branch=DRAIN_DRAMET3_BRANCH_DRAINAGE
      result%signed_soil_to_drain_rate=diffl/p%drainage_resistance_day
      result%dq_dgroundwater_level=1.0_real64/p%drainage_resistance_day
      result%derivative_defined=.not.diagnostics%branch_boundary
      return
    end if

    if(p%drain_type==2 .and. p%limit_infiltration_head)then
      cap=p%zbotdr_cm-drain_level
      if(diffl<cap)then
        diffl=cap
        diagnostics%infiltration_head_cap_active=.true.
      end if
    end if
    result%effective_head_difference_cm=diffl
    if(p%allocation_mode==3 .or. p%zbotdr_cm>=drain_level)then
      diagnostics%allocation_suppressed=.true.
      diagnostics%branch=DRAIN_DRAMET3_BRANCH_SUPPRESSED
      result%derivative_defined=.true.
      return
    end if
    if(p%infiltration_resistance_day<=0.0_real64)then
      diagnostics%status=DRAIN_DRAMET3_INVALID_PARAMETERS
      result=drainage_dramet3_result_t()
      return
    end if
    if(diagnostics%infiltration_head_cap_active)then
      diagnostics%branch=DRAIN_DRAMET3_BRANCH_INFILTRATION_CAP
      result%dq_dgroundwater_level=0.0_real64
    else
      diagnostics%branch=DRAIN_DRAMET3_BRANCH_INFILTRATION
      result%dq_dgroundwater_level=1.0_real64/p%infiltration_resistance_day
    end if
    result%signed_soil_to_drain_rate=diffl/p%infiltration_resistance_day
    result%derivative_defined=.true.
  end subroutine evaluate_drainage_dramet3_response

  pure real(real64) function afgen_pairs(x_table,y_table,x) result(value)
    real(real64), intent(in) :: x_table(:),y_table(:),x
    real(real64) :: slope
    integer :: i
    if(x<=x_table(1).or.size(x_table)==1)then
      value=y_table(1);return
    end if
    do i=2,size(x_table)
      if(x<=x_table(i))then
        slope=(y_table(i)-y_table(i-1))/(x_table(i)-x_table(i-1))
        value=y_table(i-1)+(x-x_table(i-1))*slope
        return
      end if
    end do
    value=y_table(size(y_table))
  end function afgen_pairs
end module mod_drainage_dramet3_response
