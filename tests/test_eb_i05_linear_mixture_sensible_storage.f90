program test_eb_i05_linear_mixture_sensible_storage
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_linear_mixture_sensible_storage, only: &
       LMSS_OK, LMSS_INVALID_PROPERTIES, LMSS_INVALID_STATE, &
       linear_mixture_sensible_storage_parameters_t, linear_mixture_sensible_storage_change_t, &
       initialize_linear_mixture_sensible_storage_parameters, evaluate_mixture_heat_capacity, &
       evaluate_sensible_storage, evaluate_sensible_storage_change
  implicit none

  type(linear_mixture_sensible_storage_parameters_t) :: p0, p5
  type(linear_mixture_sensible_storage_change_t) :: c0, c5, moisture_only
  integer :: status
  logical :: ready
  real(real64) :: solid_capacity, capacity, energy, expected_shift, pure_liquid_composition, air_displacement
  real(real64), parameter :: tol = 1.0e-6_real64

  ! Current admitted restricted-soil-temperature source values, supplied here
  ! as test inputs rather than duplicated as production constants.
  solid_capacity = 0.30_real64 * 2.128_real64 + 0.20_real64 * 2.385_real64 + 0.05_real64 * 2.496_real64

  call initialize_linear_mixture_sensible_storage_parameters(0.45_real64, solid_capacity, 4.18_real64, &
       0.001212_real64, 0.0_real64, p0, status)
  if (status /= LMSS_OK) error stop 'EB-I05 canonical properties rejected'
  ready = p0%ready()
  if (.not. ready) error stop 'EB-I05 canonical properties not ready'

  call evaluate_mixture_heat_capacity(0.20_real64, p0, capacity, status)
  if (status /= LMSS_OK) error stop 'EB-I05 capacity evaluation failed'
  if (abs(capacity - 2.076503_real64) > tol) error stop 'EB-I05 start capacity mismatch'

  call evaluate_sensible_storage(10.0_real64, 0.20_real64, 10.0_real64, p0, energy, status)
  if (status /= LMSS_OK) error stop 'EB-I05 storage evaluation failed'
  if (abs(energy - 2076503.0_real64) > tol) error stop 'EB-I05 start storage mismatch'

  call evaluate_sensible_storage_change(10.0_real64, 0.20_real64, 0.22_real64, &
       10.0_real64, 12.0_real64, p0, c0, status)
  if (status /= LMSS_OK) error stop 'EB-I05 storage change failed'
  if (abs(c0%capacity_end_j_cm3_k - 2.16007876_real64) > tol) error stop 'EB-I05 end capacity mismatch'
  if (abs(c0%capacity_average_j_cm3_k - 2.11829088_real64) > tol) error stop 'EB-I05 average capacity mismatch'
  if (abs(c0%exact_change_j_m2 - 515591.512_real64) > tol) error stop 'EB-I05 exact change mismatch'
  if (abs(c0%temperature_change_component_j_m2 - 423658.176_real64) > tol) &
       error stop 'EB-I05 average-capacity temperature term mismatch'
  if (abs(c0%composition_change_component_j_m2 - 91933.336_real64) > tol) &
       error stop 'EB-I05 composition term mismatch'
  if (abs(c0%decomposition_residual_j_m2) > tol) error stop 'EB-I05 decomposition not exact'

  ! The current C(theta_avg)*DeltaT bookkeeping equals only the first term.
  ! The exact missing composition term is liquid replacement minus displaced air.
  pure_liquid_composition = 1.0e4_real64 * 10.0_real64 * 4.18_real64 * 11.0_real64 * 0.02_real64
  air_displacement = 1.0e4_real64 * 10.0_real64 * 0.001212_real64 * 11.0_real64 * 0.02_real64
  if (abs(pure_liquid_composition - 91960.0_real64) > tol) error stop 'EB-I05 pure-liquid reference mismatch'
  if (abs(air_displacement - 26.664_real64) > tol) error stop 'EB-I05 air displacement mismatch'
  if (abs(c0%composition_change_component_j_m2 - (pure_liquid_composition - air_displacement)) > tol) &
       error stop 'EB-I05 water-for-air replacement identity failed'

  call evaluate_sensible_storage_change(10.0_real64, 0.20_real64, 0.22_real64, &
       10.0_real64, 10.0_real64, p0, moisture_only, status)
  if (status /= LMSS_OK) error stop 'EB-I05 moisture-only change failed'
  if (abs(moisture_only%temperature_change_component_j_m2) > tol) &
       error stop 'EB-I05 moisture-only temperature term must vanish'
  if (abs(moisture_only%exact_change_j_m2 - moisture_only%composition_change_component_j_m2) > tol) &
       error stop 'EB-I05 moisture-only storage not attributed to composition'

  call initialize_linear_mixture_sensible_storage_parameters(0.45_real64, solid_capacity, 4.18_real64, &
       0.001212_real64, 5.0_real64, p5, status)
  if (status /= LMSS_OK) error stop 'EB-I05 shifted-reference properties rejected'
  call evaluate_sensible_storage_change(10.0_real64, 0.20_real64, 0.22_real64, &
       10.0_real64, 12.0_real64, p5, c5, status)
  if (status /= LMSS_OK) error stop 'EB-I05 shifted-reference change failed'
  expected_shift = -41787.88_real64
  if (abs((c5%exact_change_j_m2 - c0%exact_change_j_m2) - expected_shift) > tol) &
       error stop 'EB-I05 reference-shift identity failed'
  if (abs(c5%temperature_change_component_j_m2 - c0%temperature_change_component_j_m2) > tol) &
       error stop 'EB-I05 temperature component must be reference invariant'
  if (abs((c5%composition_change_component_j_m2 - c0%composition_change_component_j_m2) - expected_shift) > tol) &
       error stop 'EB-I05 composition reference-shift identity failed'

  call initialize_linear_mixture_sensible_storage_parameters(0.0_real64, solid_capacity, 4.18_real64, &
       0.001212_real64, 0.0_real64, p0, status)
  if (status /= LMSS_INVALID_PROPERTIES) error stop 'EB-I05 invalid porosity accepted'

  call initialize_linear_mixture_sensible_storage_parameters(0.45_real64, solid_capacity, 4.18_real64, &
       0.001212_real64, 0.0_real64, p0, status)
  call evaluate_sensible_storage(10.0_real64, 0.46_real64, 10.0_real64, p0, energy, status)
  if (status /= LMSS_INVALID_STATE) error stop 'EB-I05 theta above saturation accepted'

  print '(a)', 'EB-I05 linear-mixture sensible storage: PASS'
end program test_eb_i05_linear_mixture_sensible_storage
