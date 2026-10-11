program test_f_vq88_eb_i22_independent
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_whole_column_sensible_energy_accounting, only: &
       WCSA_OK, WCSA_INVALID_ARGUMENT, WCSA_INCOMPLETE_BOUNDARY, WCSA_REFERENCE_MISMATCH, &
       whole_column_sensible_boundary_t, whole_column_sensible_energy_result_t, &
       evaluate_whole_column_sensible_energy
  implicit none

  real(real64), parameter :: TOL = 1.0e-6_real64
  real(real64) :: solid_capacity
  real(real64) :: dz(1), theta_sat(1), solid(1), theta0(1), theta1(1), t0(1), t1(1)
  type(whole_column_sensible_boundary_t) :: boundary
  type(whole_column_sensible_energy_result_t) :: result
  integer :: status

  solid_capacity = 0.30_real64 * 2.128_real64 + 0.20_real64 * 2.385_real64 + 0.05_real64 * 2.496_real64
  dz = [10.0_real64]
  theta_sat = [0.45_real64]
  solid = [solid_capacity]
  theta0 = [0.20_real64]
  theta1 = [0.20_real64]
  t0 = [10.0_real64]
  t1 = [12.0_real64]

  boundary%top_conductive_available = .true.
  boundary%top_conductive_into_j_m2 = -25000.0_real64
  boundary%top_advective_available = .true.
  boundary%top_advective_into_j_m2 = 500000.0_real64
  boundary%bottom_conductive_available = .true.
  boundary%bottom_conductive_outward_j_m2 = -10000.0_real64
  boundary%bottom_advective_available = .true.
  boundary%bottom_advective_outward_j_m2 = 69699.4_real64
  boundary%mass_carried_reference_available = .true.
  boundary%mass_carried_reference_temperature_c = 0.0_real64

  call evaluate_whole_column_sensible_energy(901_int64, dz, theta_sat, solid, theta0, theta1, t0, t1, &
       4.18_real64, 0.001212_real64, 0.0_real64, boundary, result, status)
  if (status /= WCSA_OK) error stop 'F-VQ88 reversed-orientation case rejected'
  if (abs(result%exact_storage_change_j_m2 - 415300.6_real64) > TOL) &
       error stop 'F-VQ88 fixed-composition storage mismatch'
  if (abs(result%projected_balance%boundary_input_j_m2 - 510000.0_real64) > TOL) &
       error stop 'F-VQ88 inward boundary aggregation mismatch'
  if (abs(result%projected_balance%boundary_output_j_m2 - 94699.4_real64) > TOL) &
       error stop 'F-VQ88 outward boundary aggregation mismatch'
  if (abs(result%projected_balance%residual_j_m2) > TOL) error stop 'F-VQ88 orientation residual mismatch'

  call evaluate_whole_column_sensible_energy(0_int64, dz, theta_sat, solid, theta0, theta1, t0, t1, &
       4.18_real64, 0.001212_real64, 0.0_real64, boundary, result, status)
  if (status /= WCSA_INVALID_ARGUMENT) error stop 'F-VQ88 external component accepted as column'

  boundary%mass_carried_reference_available = .false.
  call evaluate_whole_column_sensible_energy(901_int64, dz, theta_sat, solid, theta0, theta1, t0, t1, &
       4.18_real64, 0.001212_real64, 0.0_real64, boundary, result, status)
  if (status /= WCSA_INCOMPLETE_BOUNDARY) error stop 'F-VQ88 missing gauge metadata accepted'
  if (result%projected_balance%available) error stop 'F-VQ88 residual published without gauge metadata'

  boundary%mass_carried_reference_available = .true.
  boundary%mass_carried_reference_temperature_c = -5.0_real64
  call evaluate_whole_column_sensible_energy(901_int64, dz, theta_sat, solid, theta0, theta1, t0, t1, &
       4.18_real64, 0.001212_real64, 0.0_real64, boundary, result, status)
  if (status /= WCSA_REFERENCE_MISMATCH) error stop 'F-VQ88 mismatched gauge accepted'
  if (result%projected_balance%available) error stop 'F-VQ88 residual published for gauge mismatch'

  ! Independent moisture-only attack: current restricted C(theta_avg)*DeltaT is zero,
  ! while the exact endpoint state changes by the water-for-air composition term.
  boundary%mass_carried_reference_temperature_c = 0.0_real64
  boundary%top_conductive_into_j_m2 = 0.0_real64
  boundary%top_advective_into_j_m2 = 41787.88_real64
  boundary%bottom_conductive_outward_j_m2 = 0.0_real64
  boundary%bottom_advective_outward_j_m2 = 0.0_real64
  theta1 = [0.21_real64]
  t1 = [10.0_real64]
  call evaluate_whole_column_sensible_energy(901_int64, dz, theta_sat, solid, theta0, theta1, t0, t1, &
       4.18_real64, 0.001212_real64, 0.0_real64, boundary, result, status)
  if (status /= WCSA_OK) error stop 'F-VQ88 moisture-only closure rejected'
  if (abs(result%temperature_change_component_j_m2) > TOL) &
       error stop 'F-VQ88 moisture-only temperature component nonzero'
  if (abs(result%composition_change_component_j_m2 - 41787.88_real64) > TOL) &
       error stop 'F-VQ88 moisture-only composition term mismatch'
  if (abs(result%projected_balance%residual_j_m2) > TOL) &
       error stop 'F-VQ88 moisture-only whole-column residual mismatch'
  if (result%full_energy_balance_complete) error stop 'F-VQ88 broadened full-energy claim'

  print '(a)', 'F-VQ88 EB-I22 independent qualification: PASS'
end program test_f_vq88_eb_i22_independent
