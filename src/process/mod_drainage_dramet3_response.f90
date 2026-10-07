module mod_drainage_dramet3_response
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  implicit none
  private

  integer, parameter, public :: DRAMET3_OK=0
  integer, parameter, public :: DRAMET3_INVALID_PARAMETERS=1
  integer, parameter, public :: DRAMET3_INVALID_HYDRAULIC_VIEW=2
  integer, parameter, public :: DRAMET3_INVALID_CONTROL=3

  integer, parameter, public :: DRAMET3_ALLOCATE_BOTH=1
  integer, parameter, public :: DRAMET3_SUPPRESS_DRAINAGE=2
  integer, parameter, public :: DRAMET3_SUPPRESS_INFILTRATION=3
  integer, parameter, public :: DRAMET3_DRAIN_TUBE=1
  integer, parameter, public :: DRAMET3_OPEN_CHANNEL=2

  type, public :: drainage_dramet3_parameters_t
    real(real64) :: drain_bottom_cm=0.0_real64
    real(real64) :: drainage_resistance_day=0.0_real64
    real(real64) :: infiltration_resistance_day=0.0_real64
    integer :: allocation_mode=DRAMET3_ALLOCATE_BOTH
    integer :: drain_type=DRAMET3_DRAIN_TUBE
    logical :: limit_channel_infiltration=.false.
    real(real64), allocatable :: owltab_time_t1900(:)
    real(real64), allocatable :: owltab_level_cm(:)
  end type

  type, public :: drainage_dramet3_control_t
    real(real64) :: sample_time_t1900=0.0_real64
  end type

  type, public :: drainage_dramet3_result_t
    real(real64) :: signed_soil_to_drain_rate=0.0_real64
    real(real64) :: resolved_drain_level_cm=0.0_real64
    real(real64) :: raw_head_difference_cm=0.0_real64
    real(real64) :: effective_head_difference_cm=0.0_real64
    logical :: derivative_defined=.false.
    real(real64) :: dq_dgroundwater_level=0.0_real64
  end type

  type, public :: drainage_dramet3_diagnostics_t
    integer :: status=DRAMET3_OK
    logical :: evaluated=.false.
    logical :: table_clamped_lower=.false.
    logical :: table_clamped_upper=.false.
    logical :: at_table_knot=.false.
    logical :: drain_bottom_clamp_active=.false.
    logical :: drainage_suppressed=.false.
    logical :: infiltration_suppressed=.false.
    logical :: infiltration_head_limit_active=.false.
    logical :: sign_boundary=.false.
    logical :: infiltration_limit_boundary=.false.
    integer :: table_segment=0
    logical :: mass_is_authoritative_signed_transfer=.true.
    logical :: persistent_process_state=.false.
  end type

  public :: evaluate_drainage_dramet3_response
  public :: valid_drainage_dramet3_parameters

contains

  pure logical function valid_drainage_dramet3_parameters(p) result(ok)
    type(drainage_dramet3_parameters_t),intent(in)::p
    integer::i,n
    ok=.false.
    if(.not.ieee_is_finite(p%drain_bottom_cm))return
    if(.not.ieee_is_finite(p%drainage_resistance_day).or.p%drainage_resistance_day<=0.0_real64)return
    if(.not.ieee_is_finite(p%infiltration_resistance_day).or.p%infiltration_resistance_day<=0.0_real64)return
    if(p%allocation_mode<DRAMET3_ALLOCATE_BOTH.or.p%allocation_mode>DRAMET3_SUPPRESS_INFILTRATION)return
    if(p%drain_type/=DRAMET3_DRAIN_TUBE.and.p%drain_type/=DRAMET3_OPEN_CHANNEL)return
    if(.not.allocated(p%owltab_time_t1900).or..not.allocated(p%owltab_level_cm))return
    n=size(p%owltab_time_t1900)
    if(n<1.or.size(p%owltab_level_cm)/=n)return
    if(any(.not.ieee_is_finite(p%owltab_time_t1900)).or.any(.not.ieee_is_finite(p%owltab_level_cm)))return
    do i=2,n
      if(.not.(p%owltab_time_t1900(i)>p%owltab_time_t1900(i-1)))return
    end do
    ok=.true.
  end function

  subroutine evaluate_drainage_dramet3_response(p,view,control,result,diagnostics)
    type(drainage_dramet3_parameters_t),intent(in)::p
    type(process_hydraulic_view_t),intent(in)::view
    type(drainage_dramet3_control_t),intent(in)::control
    type(drainage_dramet3_result_t),intent(out)::result
    type(drainage_dramet3_diagnostics_t),intent(out)::diagnostics
    real(real64)::drain_level,diffl,effective,cap,slope
    integer::i,n

    result=drainage_dramet3_result_t()
    diagnostics=drainage_dramet3_diagnostics_t()
    if(.not.valid_drainage_dramet3_parameters(p))then
      diagnostics%status=DRAMET3_INVALID_PARAMETERS
      return
    end if
    if(.not.ieee_is_finite(view%groundwater_level))then
      diagnostics%status=DRAMET3_INVALID_HYDRAULIC_VIEW
      return
    end if
    if(.not.ieee_is_finite(control%sample_time_t1900))then
      diagnostics%status=DRAMET3_INVALID_CONTROL
      return
    end if

    diagnostics%evaluated=.true.
    n=size(p%owltab_time_t1900)
    if(n==1)then
      drain_level=p%owltab_level_cm(1)
      diagnostics%table_clamped_lower=.true.
      diagnostics%table_clamped_upper=.true.
    else if(control%sample_time_t1900<p%owltab_time_t1900(1))then
      drain_level=p%owltab_level_cm(1)
      diagnostics%table_clamped_lower=.true.
    else if(control%sample_time_t1900>p%owltab_time_t1900(n))then
      drain_level=p%owltab_level_cm(n)
      diagnostics%table_clamped_upper=.true.
    else if(.not.(control%sample_time_t1900>p%owltab_time_t1900(1)))then
      drain_level=p%owltab_level_cm(1)
      diagnostics%at_table_knot=.true.
    else
      drain_level=p%owltab_level_cm(n)
      do i=2,n
        if(control%sample_time_t1900<p%owltab_time_t1900(i))then
          slope=(p%owltab_level_cm(i)-p%owltab_level_cm(i-1))/ &
               (p%owltab_time_t1900(i)-p%owltab_time_t1900(i-1))
          drain_level=p%owltab_level_cm(i-1)+(control%sample_time_t1900-p%owltab_time_t1900(i-1))*slope
          diagnostics%table_segment=i-1
          exit
        end if
        if(.not.(control%sample_time_t1900>p%owltab_time_t1900(i)))then
          drain_level=p%owltab_level_cm(i)
          diagnostics%at_table_knot=.true.
          diagnostics%table_segment=i-1
          exit
        end if
      end do
    end if

    if(drain_level<p%drain_bottom_cm)then
      drain_level=p%drain_bottom_cm
      diagnostics%drain_bottom_clamp_active=.true.
    end if
    result%resolved_drain_level_cm=drain_level
    diffl=view%groundwater_level-drain_level
    result%raw_head_difference_cm=diffl
    effective=diffl
    diagnostics%sign_boundary=.not.(diffl<0.0_real64).and..not.(diffl>0.0_real64)

    if(.not.(diffl<0.0_real64))then
      if(p%allocation_mode==DRAMET3_SUPPRESS_DRAINAGE)then
        diagnostics%drainage_suppressed=.true.
        result%derivative_defined=.true.
        return
      end if
      result%signed_soil_to_drain_rate=effective/p%drainage_resistance_day
      result%effective_head_difference_cm=effective
      result%dq_dgroundwater_level=1.0_real64/p%drainage_resistance_day
      result%derivative_defined=.not.diagnostics%sign_boundary
      return
    end if

    if(p%drain_type==DRAMET3_OPEN_CHANNEL.and.p%limit_channel_infiltration)then
      cap=p%drain_bottom_cm-drain_level
      diagnostics%infiltration_limit_boundary=.not.(diffl<cap).and..not.(diffl>cap)
      if(diffl<cap)then
        effective=cap
        diagnostics%infiltration_head_limit_active=.true.
      end if
    end if
    result%effective_head_difference_cm=effective

    if(p%allocation_mode==DRAMET3_SUPPRESS_INFILTRATION.or..not.(p%drain_bottom_cm<drain_level))then
      diagnostics%infiltration_suppressed=.true.
      result%derivative_defined=.true.
      return
    end if

    result%signed_soil_to_drain_rate=effective/p%infiltration_resistance_day
    if(diagnostics%infiltration_head_limit_active)then
      result%dq_dgroundwater_level=0.0_real64
    else
      result%dq_dgroundwater_level=1.0_real64/p%infiltration_resistance_day
    end if
    result%derivative_defined=.not.diagnostics%infiltration_limit_boundary
  end subroutine
end module
