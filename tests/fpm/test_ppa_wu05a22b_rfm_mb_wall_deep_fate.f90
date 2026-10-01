program test_ppa_wu05a22b_rfm_mb_wall_deep_fate
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_rfm_mb_wall_deep_fate
  implicit none
  real(real64),parameter::TOL=1.0e-12_real64
  type(rfm_mb_fate_request_t)::req
  type(rfm_mb_fate_result_t)::res

  req%mb_input_cm=0.5_real64
  req%contact_length_cm=80.0_real64
  req%exchange_length_cm=20.0_real64
  req%chi_wall=1.0_real64
  req%wall_sorptivity_cm_sqrt_day=0.1_real64
  req%matrix_conductivity_cm_per_day=0.001_real64
  req%macro_to_matrix_head_difference_cm=10.0_real64
  req%wall_age_day=0.0_real64
  req%step_duration_day=0.1_real64

  call evaluate_rfm_mb_wall_deep_fate(req,TOL,res)
  call require(res%valid,'case1 invalid')
  call require(res%philip_potential_cm>res%darcy_potential_cm,'case1 regime')
  call require(res%wall_to_matrix_cm>0.0_real64.and.res%wall_to_matrix_cm<0.5_real64,'case1 wall range')
  call require(res%deep_receipt_cm>0.0_real64.and.res%deep_receipt_cm<0.5_real64,'case1 deep range')
  call require(abs(0.5_real64-res%wall_to_matrix_cm-res%deep_receipt_cm)<=TOL,'case1 closure')

  req%wall_sorptivity_cm_sqrt_day=2.0_real64
  call evaluate_rfm_mb_wall_deep_fate(req,TOL,res)
  call require(res%valid,'case2 invalid')
  call require(abs(res%wall_to_matrix_cm-0.5_real64)<=TOL,'case2 wall limited')
  call require(abs(res%deep_receipt_cm)<=TOL,'case2 deep zero')
  call require(abs(res%mass_residual_cm)<=TOL,'case2 closure')

  req%exchange_length_cm=0.0_real64
  call evaluate_rfm_mb_wall_deep_fate(req,TOL,res)
  call require(.not.res%valid,'invalid ell accepted')
  print '(a)','PPA_WU05A22B_RFM_MB_WALL_DEEP_FATE=PASS'
contains
  subroutine require(ok,msg)
    logical,intent(in)::ok
    character(*),intent(in)::msg
    if(.not.ok)then
      write(*,'(a,1x,a)')'PPA_WU05A22B_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine
end program
