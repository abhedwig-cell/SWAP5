program test_ppa_wu05a22a_rfm_endpoint_release
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_rfm_endpoint_release
  implicit none
  real(real64),parameter::TOL=1.0e-12_real64
  type(rfm_endpoint_release_request_t)::req
  type(rfm_endpoint_release_result_t)::res

  req%step_duration_day=0.1_real64
  req%accepted_storage_cm=[0.5_real64,0.1_real64]
  req%contact_thickness_cm=[20.0_real64,20.0_real64]
  req%exchange_length_cm=[20.0_real64,20.0_real64]
  req%chi_wall=[1.0_real64,1.0_real64]
  req%wall_sorptivity_cm_sqrt_day=[0.2_real64,0.4_real64]
  req%matrix_conductivity_cm_per_day=[0.1_real64,0.001_real64]
  req%macro_to_matrix_head_difference_cm=[50.0_real64,10.0_real64]
  req%accepted_wall_age_day=[0.1_real64,0.0_real64]

  call evaluate_rfm_endpoint_release(req,TOL,res)
  call require(res%valid,'result invalid')
  call require(abs(res%darcy_potential_cm(1)-0.2_real64)<=TOL,'Darcy oracle')
  call require(res%philip_potential_cm(1)<res%darcy_potential_cm(1),'regime oracle')
  call require(abs(res%release_to_matrix_cm(1)-0.2_real64)<=TOL,'endpoint1 release')
  call require(abs(res%candidate_storage_cm(1)-0.3_real64)<=TOL,'endpoint1 storage')
  call require(abs(res%candidate_wall_age_day(1)-0.2_real64)<=TOL,'endpoint1 age')
  call require(abs(res%candidate_wall_sorptivity_cm_sqrt_day(1)-0.2_real64)<=TOL,'endpoint1 S')
  call require(res%philip_potential_cm(2)>0.1_real64,'storage-limit oracle')
  call require(abs(res%release_to_matrix_cm(2)-0.1_real64)<=TOL,'endpoint2 release')
  call require(abs(res%candidate_storage_cm(2))<=TOL,'endpoint2 storage')
  call require(abs(res%candidate_wall_age_day(2))<=TOL,'endpoint2 age reset')
  call require(abs(res%candidate_wall_sorptivity_cm_sqrt_day(2))<=TOL,'endpoint2 S reset')
  call require(abs(res%storage_start_cm-0.6_real64)<=TOL,'start storage')
  call require(abs(res%release_total_cm-0.3_real64)<=TOL,'total release')
  call require(abs(res%storage_end_cm-0.3_real64)<=TOL,'end storage')
  call require(abs(res%mass_residual_cm)<=TOL,'mass closure')

  req%exchange_length_cm(1)=0.0_real64
  call evaluate_rfm_endpoint_release(req,TOL,res)
  call require(.not.res%valid,'invalid ell accepted')
  print '(a)','PPA_WU05A22A_RFM_ENDPOINT_RELEASE=PASS'
contains
  subroutine require(ok,msg)
    logical,intent(in)::ok
    character(*),intent(in)::msg
    if(.not.ok)then
      write(*,'(a,1x,a)')'PPA_WU05A22A_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine
end program
