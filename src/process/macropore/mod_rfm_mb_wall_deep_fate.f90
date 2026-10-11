module mod_rfm_mb_wall_deep_fate
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  type, public :: rfm_mb_fate_request_t
    real(real64) :: mb_input_cm=0.0_real64, contact_length_cm=0.0_real64
    real(real64) :: exchange_length_cm=0.0_real64, chi_wall=0.0_real64
    real(real64) :: wall_sorptivity_cm_sqrt_day=0.0_real64
    real(real64) :: matrix_conductivity_cm_per_day=0.0_real64
    real(real64) :: macro_to_matrix_head_difference_cm=0.0_real64
    real(real64) :: wall_age_day=0.0_real64, step_duration_day=0.0_real64
  contains
    procedure, public :: valid => request_valid
  end type

  type, public :: rfm_mb_fate_result_t
    logical :: valid=.false.
    real(real64) :: philip_potential_cm=0.0_real64, darcy_potential_cm=0.0_real64
    real(real64) :: wall_to_matrix_cm=0.0_real64, deep_receipt_cm=0.0_real64
    real(real64) :: mass_residual_cm=0.0_real64
  end type

  public :: evaluate_rfm_mb_wall_deep_fate

contains

  pure logical function request_valid(self) result(ok)
    class(rfm_mb_fate_request_t),intent(in)::self
    ok=ieee_is_finite(self%mb_input_cm).and.self%mb_input_cm>=0.0_real64 .and. &
       ieee_is_finite(self%contact_length_cm).and.self%contact_length_cm>0.0_real64 .and. &
       ieee_is_finite(self%exchange_length_cm).and.self%exchange_length_cm>0.0_real64 .and. &
       ieee_is_finite(self%chi_wall).and.self%chi_wall>=0.0_real64 .and. &
       ieee_is_finite(self%wall_sorptivity_cm_sqrt_day).and.self%wall_sorptivity_cm_sqrt_day>=0.0_real64 .and. &
       ieee_is_finite(self%matrix_conductivity_cm_per_day).and.self%matrix_conductivity_cm_per_day>=0.0_real64 .and. &
       ieee_is_finite(self%macro_to_matrix_head_difference_cm).and.self%macro_to_matrix_head_difference_cm>=0.0_real64 .and. &
       ieee_is_finite(self%wall_age_day).and.self%wall_age_day>=0.0_real64 .and. &
       ieee_is_finite(self%step_duration_day).and.self%step_duration_day>0.0_real64
  end function

  pure subroutine evaluate_rfm_mb_wall_deep_fate(request,tolerance,result)
    type(rfm_mb_fate_request_t),intent(in)::request
    real(real64),intent(in)::tolerance
    type(rfm_mb_fate_result_t),intent(out)::result
    real(real64)::droot,potential
    result=rfm_mb_fate_result_t()
    if(.not.request%valid())return
    if(.not.ieee_is_finite(tolerance).or.tolerance<0.0_real64)return

    droot=sqrt(request%wall_age_day+request%step_duration_day)-sqrt(request%wall_age_day)
    result%philip_potential_cm=request%chi_wall*(4.0_real64/request%exchange_length_cm)* &
      request%wall_sorptivity_cm_sqrt_day*droot*request%contact_length_cm
    result%darcy_potential_cm=8.0_real64*request%matrix_conductivity_cm_per_day* &
      request%macro_to_matrix_head_difference_cm/request%exchange_length_cm**2* &
      request%step_duration_day*request%contact_length_cm

    potential=max(result%philip_potential_cm,result%darcy_potential_cm)
    result%wall_to_matrix_cm=min(request%mb_input_cm,max(0.0_real64,potential))
    result%deep_receipt_cm=request%mb_input_cm-result%wall_to_matrix_cm
    result%mass_residual_cm=request%mb_input_cm-result%wall_to_matrix_cm-result%deep_receipt_cm
    if(abs(result%mass_residual_cm)>tolerance)return
    result%valid=.true.
  end subroutine
end module mod_rfm_mb_wall_deep_fate
