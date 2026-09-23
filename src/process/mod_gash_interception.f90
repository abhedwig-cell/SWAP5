module mod_gash_interception
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_vonhhbraden_interception, only: vonhhbraden_source_window_t, VONHHBRADEN_AVAILABLE, VONHHBRADEN_INVALID_INPUT
  implicit none
  private
  type, public :: gash_parameters_t
    real(real64) :: free_throughfall = 0.0_real64
    real(real64) :: stemflow = 0.0_real64
    real(real64) :: canopy_storage_cm = 0.0_real64
    real(real64) :: average_evaporation = 0.0_real64
    real(real64) :: average_precipitation = 0.0_real64
  end type
  public :: evaluate_gash_source_window
contains
  pure subroutine evaluate_gash_source_window(parameters, source, aggregate_cm_per_day, status)
    type(gash_parameters_t), intent(in) :: parameters
    type(vonhhbraden_source_window_t), intent(in) :: source
    real(real64), intent(out) :: aggregate_cm_per_day
    integer, intent(out) :: status
    real(real64) :: c, rpd, scanopy, avevap, psatcan
    aggregate_cm_per_day=0.0_real64; status=VONHHBRADEN_INVALID_INPUT
    if (.not. valid(parameters,source)) return
    rpd=source%gross_rain_cm_per_day
    if (source%sprinkling_is_intercepted) rpd=rpd+source%sprinkling_irrigation_cm_per_day
    if (source%leaf_area_index<1.e-3_real64 .or. rpd<1.e-5_real64 .or. source%snow_present) then
      status=VONHHBRADEN_AVAILABLE; return
    end if
    c=1.0_real64-parameters%free_throughfall-parameters%stemflow
    scanopy=parameters%canopy_storage_cm/c; avevap=parameters%average_evaporation/c
    if (1.0_real64-avevap/parameters%average_precipitation>1.e-4_real64) then
      psatcan=-parameters%average_precipitation*scanopy/avevap*log(1.0_real64-avevap/parameters%average_precipitation)
    else
      psatcan=parameters%average_precipitation*scanopy/avevap
    end if
    if (rpd<psatcan) then
      aggregate_cm_per_day=c*rpd
    else
      aggregate_cm_per_day=c*(psatcan+avevap*c/parameters%average_precipitation*(rpd-psatcan))
    end if
    status=VONHHBRADEN_AVAILABLE
  end subroutine
  pure logical function valid(p,s) result(ok)
    type(gash_parameters_t),intent(in)::p; type(vonhhbraden_source_window_t),intent(in)::s
    ok=.false.
    if (.not.ieee_is_finite(p%free_throughfall).or..not.ieee_is_finite(p%stemflow).or.&
        .not.ieee_is_finite(p%canopy_storage_cm).or..not.ieee_is_finite(p%average_evaporation).or.&
        .not.ieee_is_finite(p%average_precipitation).or..not.ieee_is_finite(s%gross_rain_cm_per_day).or.&
        .not.ieee_is_finite(s%sprinkling_irrigation_cm_per_day).or..not.ieee_is_finite(s%leaf_area_index)) return
    if (p%free_throughfall<0.0_real64.or.p%free_throughfall>1.0_real64.or.&
        p%stemflow<0.0_real64.or.p%stemflow>1.0_real64) return
    if (p%free_throughfall>=1.0_real64.or.p%stemflow>=1.0_real64) return
    if (p%free_throughfall>=1.0_real64-p%stemflow) return
    if (p%canopy_storage_cm<0.0_real64.or.p%canopy_storage_cm>10.0_real64.or.&
        p%average_evaporation<=0.0_real64.or.p%average_evaporation>10.0_real64.or.&
        p%average_precipitation<=0.0_real64.or.p%average_precipitation>100.0_real64) return
    if (s%gross_rain_cm_per_day<0.0_real64.or.s%sprinkling_irrigation_cm_per_day<0.0_real64.or.&
        s%leaf_area_index<0.0_real64) return
    if (s%sprinkling_is_intercepted) then
      if (s%gross_rain_cm_per_day>huge(1.0_real64)-s%sprinkling_irrigation_cm_per_day) return
    end if
    ok=.true.
  end function
end module
