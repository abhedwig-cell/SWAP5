! MC-SOL01-SURFACE-AGE01: isolated Reference-only candidate.
! Age stock has units cm*day, fluxes and depths cm; no persistent owner yet.
module mod_b111_surface_age_budget
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: SURFACE_AGE_OK=0, SURFACE_AGE_INVALID=1, SURFACE_AGE_BALANCE=2
  type, public :: surface_age_request_t
    real(real64) :: dt_day=0.0_real64
    real(real64) :: pond_start_cm=0.0_real64, pond_end_cm=0.0_real64
    real(real64) :: pond_age_stock_cm_day=0.0_real64
    real(real64) :: rain_depth_cm=0.0_real64, irrigation_depth_cm=0.0_real64
    real(real64) :: runon_depth_cm=0.0_real64
    real(real64) :: rain_age_day=0.0_real64, irrigation_age_day=0.0_real64
    real(real64) :: runon_age_day=0.0_real64
    real(real64) :: infiltration_depth_cm=0.0_real64
    real(real64) :: runoff_depth_cm=0.0_real64, evaporation_depth_cm=0.0_real64
  end type
  type, public :: surface_age_receipt_t
    integer :: status=SURFACE_AGE_INVALID
    real(real64) :: pond_end_stock_cm_day=0.0_real64
    real(real64) :: infiltration_age_export_cm_day=0.0_real64
    real(real64) :: runoff_age_export_cm_day=0.0_real64
    real(real64) :: external_age_input_cm_day=0.0_real64
    real(real64) :: age_production_cm_day=0.0_real64
    real(real64) :: residual_cm_day=0.0_real64
    real(real64) :: mixed_age_day=0.0_real64
  end type
  public :: advance_surface_age_budget
contains
  pure subroutine advance_surface_age_budget(q,r)
    type(surface_age_request_t), intent(in) :: q
    type(surface_age_receipt_t), intent(out) :: r
    real(real64) :: scale, depth_total, gross, loss, residual_water, available
    r=surface_age_receipt_t()
    if (.not.all(ieee_is_finite([q%dt_day,q%pond_start_cm,q%pond_end_cm, &
        q%pond_age_stock_cm_day,q%rain_depth_cm,q%irrigation_depth_cm, &
        q%runon_depth_cm,q%rain_age_day,q%irrigation_age_day,q%runon_age_day, &
        q%infiltration_depth_cm,q%runoff_depth_cm,q%evaporation_depth_cm]))) return
    if (q%dt_day<=0.0_real64.or.q%dt_day>1.0e3_real64) return
    if (min(q%pond_start_cm,q%pond_end_cm,q%pond_age_stock_cm_day, &
        q%rain_depth_cm,q%irrigation_depth_cm,q%runon_depth_cm, &
        q%rain_age_day,q%irrigation_age_day,q%runon_age_day, &
        q%infiltration_depth_cm,q%runoff_depth_cm,q%evaporation_depth_cm)<0.0_real64) return
    if (max(q%pond_start_cm,q%pond_end_cm,q%rain_depth_cm,q%irrigation_depth_cm, &
        q%runon_depth_cm,q%infiltration_depth_cm,q%runoff_depth_cm, &
        q%evaporation_depth_cm)>1.0e6_real64) return
    if (q%pond_age_stock_cm_day>1.0e12_real64.or. &
        max(q%rain_age_day,q%irrigation_age_day,q%runon_age_day)>1.0e6_real64) return
    if (q%pond_start_cm==0.0_real64.and.q%pond_age_stock_cm_day/=0.0_real64) return
    gross=q%rain_depth_cm+q%irrigation_depth_cm+q%runon_depth_cm
    loss=q%infiltration_depth_cm+q%runoff_depth_cm+q%evaporation_depth_cm
    scale=max(1.0_real64,q%pond_start_cm,q%pond_end_cm,gross,loss)
    residual_water=q%pond_end_cm-q%pond_start_cm-gross+loss
    if (abs(residual_water)>1.0e-10_real64*scale) then
      r%status=SURFACE_AGE_BALANCE
      return
    end if
    ! Midpoint exposure is the stated first-order-in-time source approximation.
    ! New external water supplies its explicitly given incoming age.
    r%age_production_cm_day=0.5_real64*(q%pond_start_cm+q%pond_end_cm)*q%dt_day
    r%external_age_input_cm_day=q%rain_depth_cm*q%rain_age_day+ &
        q%irrigation_depth_cm*q%irrigation_age_day+q%runon_depth_cm*q%runon_age_day
    available=q%pond_age_stock_cm_day+r%external_age_input_cm_day+r%age_production_cm_day
    depth_total=q%pond_end_cm+q%infiltration_depth_cm+q%runoff_depth_cm
    if (depth_total<=0.0_real64) then
      if (available>1.0e-10_real64) return
      r%status=SURFACE_AGE_OK
      return
    end if
    r%mixed_age_day=available/depth_total
    r%pond_end_stock_cm_day=q%pond_end_cm*r%mixed_age_day
    r%infiltration_age_export_cm_day=q%infiltration_depth_cm*r%mixed_age_day
    r%runoff_age_export_cm_day=q%runoff_depth_cm*r%mixed_age_day
    r%residual_cm_day=r%pond_end_stock_cm_day+ &
        r%infiltration_age_export_cm_day+r%runoff_age_export_cm_day-available
    scale=max(1.0_real64,available)
    if (.not.ieee_is_finite(r%mixed_age_day).or..not.ieee_is_finite(r%residual_cm_day)) return
    if (abs(r%residual_cm_day)>8192.0_real64*epsilon(1.0_real64)*scale) then
      r=surface_age_receipt_t()
      r%status=SURFACE_AGE_BALANCE
      return
    end if
    r%status=SURFACE_AGE_OK
  end subroutine
end module mod_b111_surface_age_budget
