module mod_fmr_macropore_top_input
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  ! PPA-WU05-A9 source-owned interval forcing.  These rates are the typed
  ! equivalents of the B1.11 external macropore top terms QInTopVrtDm and
  ! QInTopLatDm.  This carrier deliberately does not infer them from generic
  ! FMR top_flux or from raw meteorological components.
  type, public :: fmr_macropore_top_input_t
    real(real64), allocatable :: vertical_rate_cm_per_day(:)
    real(real64), allocatable :: lateral_rate_cm_per_day(:)
  contains
    procedure, public :: valid_for_domains => top_input_valid_for_domains
    procedure, public :: total_rate_cm_per_day => top_input_total_rate
  end type fmr_macropore_top_input_t

  public :: initialize_fmr_macropore_top_input

contains

  subroutine initialize_fmr_macropore_top_input(carrier,vertical_rate,lateral_rate,ok)
    type(fmr_macropore_top_input_t),intent(out)::carrier
    real(real64),intent(in)::vertical_rate(:),lateral_rate(:)
    logical,intent(out)::ok
    integer::nd

    carrier=fmr_macropore_top_input_t()
    ok=.false.
    nd=size(vertical_rate)
    if(nd<=0 .or. size(lateral_rate)/=nd)return
    if(.not.all(ieee_is_finite(vertical_rate)) .or. .not.all(ieee_is_finite(lateral_rate)))return
    if(any(vertical_rate<0.0_real64) .or. any(lateral_rate<0.0_real64))return
    carrier%vertical_rate_cm_per_day=vertical_rate
    carrier%lateral_rate_cm_per_day=lateral_rate
    ok=carrier%valid_for_domains(nd)
  end subroutine initialize_fmr_macropore_top_input

  pure logical function top_input_valid_for_domains(self,num_domains) result(ok)
    class(fmr_macropore_top_input_t),intent(in)::self
    integer,intent(in)::num_domains
    ok=num_domains>0
    if(.not.ok)return
    ok=allocated(self%vertical_rate_cm_per_day) .and. allocated(self%lateral_rate_cm_per_day)
    if(.not.ok)return
    ok=size(self%vertical_rate_cm_per_day)==num_domains .and. &
       size(self%lateral_rate_cm_per_day)==num_domains
    if(.not.ok)return
    ok=all(ieee_is_finite(self%vertical_rate_cm_per_day)) .and. &
       all(ieee_is_finite(self%lateral_rate_cm_per_day)) .and. &
       all(self%vertical_rate_cm_per_day>=0.0_real64) .and. &
       all(self%lateral_rate_cm_per_day>=0.0_real64)
  end function top_input_valid_for_domains

  pure real(real64) function top_input_total_rate(self) result(value)
    class(fmr_macropore_top_input_t),intent(in)::self
    value=0.0_real64
    if(.not.allocated(self%vertical_rate_cm_per_day) .or. &
       .not.allocated(self%lateral_rate_cm_per_day))return
    value=sum(self%vertical_rate_cm_per_day)+sum(self%lateral_rate_cm_per_day)
  end function top_input_total_rate

end module mod_fmr_macropore_top_input
