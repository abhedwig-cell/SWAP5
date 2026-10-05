program test_mig431_tillage_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_tillage_constitutive_process, only: tillage_vg_parameters_t
  use mod_tillage_water_redistribution, only: TILLAGE_WATER_SIMPLE, TILLAGE_WATER_PROFILE
  use mod_fmr_tillage_hydraulic_binding
  implicit none
  type(tillage_vg_parameters_t) :: vg(2)
  type(tillage_hydraulic_candidate_t) :: candidate
  real(real64) :: reconstructed, se
  integer :: status, i

  vg%theta_residual = 0.05_real64
  vg%theta_saturated = 0.4_real64
  vg%alpha = 0.02_real64
  vg%n = 2.0_real64
  vg%m = 0.5_real64
  call bind_tillage_hydraulic_candidate([0.2_real64,0.3_real64],0.0_real64, &
       [0.2_real64,0.3_real64],[10.0_real64,20.0_real64],vg,TILLAGE_WATER_PROFILE,candidate,status)
  if (status /= TILLAGE_BIND_OK .or. abs(candidate%mass_residual_cm) > 1.e-12_real64) error stop 1
  do i = 1,2
    se = (1.0_real64+(vg(i)%alpha*abs(candidate%pressure_head_cm(i)))**vg(i)%n)**(-vg(i)%m)
    reconstructed = vg(i)%theta_residual+(vg(i)%theta_saturated-vg(i)%theta_residual)*se
    if (abs(reconstructed-candidate%water_content(i)) > 1.e-12_real64) error stop 2
  end do
  call bind_tillage_hydraulic_candidate([0.5_real64,0.3_real64],0.0_real64, &
       [0.3_real64,0.3_real64],[10.0_real64,20.0_real64],vg,TILLAGE_WATER_SIMPLE,candidate,status)
  if (status /= TILLAGE_BIND_OK .or. abs(candidate%mass_residual_cm) > 1.e-12_real64) error stop 3
  if (candidate%pressure_head_cm(1) /= 0.0_real64) error stop 4
  vg(2)%alpha = -1.0_real64
  call bind_tillage_hydraulic_candidate([0.2_real64,0.3_real64],0.0_real64, &
       [0.2_real64,0.3_real64],[10.0_real64,20.0_real64],vg,TILLAGE_WATER_PROFILE,candidate,status)
  if (status /= TILLAGE_BIND_INVALID .or. allocated(candidate%water_content)) error stop 5
  print '(a)', 'F_MIG431_TILLAGE_INVERSE_HEAD_MASS=PASS'
end program
