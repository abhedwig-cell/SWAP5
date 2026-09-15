program test_eb_i22_whole_column_sensible_energy_accounting
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_whole_column_sensible_energy_accounting, only: &
       WCSA_OK, WCSA_STORAGE_FAILURE, WCSA_INCOMPLETE_BOUNDARY, &
       whole_column_sensible_boundary_t, whole_column_sensible_energy_result_t, &
       evaluate_whole_column_sensible_energy
  implicit none

  integer(int64), parameter :: COLUMN_ID = 101_int64
  real(real64), parameter :: TOL = 1.0e-6_real64
  real(real64) :: solid_capacity
  real(real64) :: dz(2), theta_sat(2), solid(2), theta0(2), theta1(2), t0(2), t1(2)
  type(whole_column_sensible_boundary_t) :: boundary
  type(whole_column_sensible_energy_result_t) :: result
  integer :: status

  solid_capacity = 0.30_real64 * 2.128_real64 + 0.20_real64 * 2.385_real64 + 0.05_real64 * 2.496_real64
  dz = [10.0_real64, 20.0_real64]
  theta_sat = [0.45_real64, 0.45_real64]
  solid = [solid_capacity, solid_capacity]
  theta0 = [0.20_real64, 0.30_real64]
  theta1 = [0.22_real64, 0.30_real64]
  t0 = [10.0_real64, 8.0_real64]
  t1 = [12.0_real64, 9.0_real64]

  ! Net sensible boundary input is exactly 1,014,467.872 J/m2:
  ! 1,200,000 top conductive input, 50,000 top advective output,
  ! 25,000 bottom conductive output and 110,532.128 bottom advective output.
  boundary%top_conductive_available = .true.
  boundary%top_conductive_into_j_m2 = 1200000.0_real64
  boundary%top_advective_available = .true.
  boundary%top_advective_into_j_m2 = -50000.0_real64
  boundary%bottom_conductive_available = .true.
  boundary%bottom_conductive_outward_j_m2 = 25000.0_real64
  boundary%bottom_advective_available = .true.
  boundary%bottom_advective_outward_j_m2 = 110532.128_real64

  call evaluate_whole_column_sensible_energy(COLUMN_ID, dz, theta_sat, solid, theta0, theta1, t0, t1, &
       4.18_real64, 0.001212_real64, 0.0_real64, boundary, result, status)

  if (status /= WCSA_OK) error stop 'EB-I22 complete sensible accounting rejected'
  if (.not. result%storage_complete) error stop 'EB-I22 storage completeness missing'
  if (.not. result%sensible_boundary_complete) error stop 'EB-I22 boundary completeness missing'
  if (.not. result%sensible_scope_complete) error stop 'EB-I22 sensible scope not complete'
  if (result%full_energy_balance_complete) error stop 'EB-I22 must not claim full energy balance'
  if (result%node_count /= 2) error stop 'EB-I22 node count mismatch'

  if (abs(result%exact_storage_change_j_m2 - 1014467.872_real64) > TOL) &
       error stop 'EB-I22 exact whole-column storage change mismatch'
  if (abs(result%temperature_change_component_j_m2 - 922534.536_real64) > TOL) &
       error stop 'EB-I22 temperature storage component mismatch'
  if (abs(result%composition_change_component_j_m2 - 91933.336_real64) > TOL) &
       error stop 'EB-I22 composition storage component mismatch'
  if (abs(result%storage_decomposition_residual_j_m2) > TOL) &
       error stop 'EB-I22 storage decomposition not exact'

  if (.not. result%projected_balance%available) error stop 'EB-I22 projected balance unavailable'
  if (abs(result%projected_balance%boundary_input_j_m2 - 1200000.0_real64) > TOL) &
       error stop 'EB-I22 boundary input orientation mismatch'
  if (abs(result%projected_balance%boundary_output_j_m2 - 185532.128_real64) > TOL) &
       error stop 'EB-I22 boundary output orientation mismatch'
  if (abs(result%projected_balance%delta_storage_j_m2 - 1014467.872_real64) > TOL) &
       error stop 'EB-I22 projected storage mismatch'
  if (abs(result%projected_balance%residual_j_m2) > TOL) &
       error stop 'EB-I22 closed sensible residual mismatch'

  ! Missing top mass-carried sensible energy must not be interpreted as zero.
  boundary%top_advective_available = .false.
  call evaluate_whole_column_sensible_energy(COLUMN_ID, dz, theta_sat, solid, theta0, theta1, t0, t1, &
       4.18_real64, 0.001212_real64, 0.0_real64, boundary, result, status)
  if (status /= WCSA_INCOMPLETE_BOUNDARY) error stop 'EB-I22 incomplete boundary did not fail closed'
  if (.not. result%storage_complete) error stop 'EB-I22 lost valid storage evidence on incomplete boundary'
  if (result%sensible_scope_complete) error stop 'EB-I22 incomplete boundary marked complete'
  if (result%projected_balance%available) error stop 'EB-I22 residual published with missing boundary term'

  ! Storage must also fail closed outside the qualified physical theta domain.
  boundary%top_advective_available = .true.
  theta1(1) = 0.46_real64
  call evaluate_whole_column_sensible_energy(COLUMN_ID, dz, theta_sat, solid, theta0, theta1, t0, t1, &
       4.18_real64, 0.001212_real64, 0.0_real64, boundary, result, status)
  if (status /= WCSA_STORAGE_FAILURE) error stop 'EB-I22 theta above saturation accepted'
  if (result%storage_complete) error stop 'EB-I22 invalid storage marked complete'

  print '(a)', 'EB-I22 whole-column sensible-energy accounting: PASS'
end program test_eb_i22_whole_column_sensible_energy_accounting
