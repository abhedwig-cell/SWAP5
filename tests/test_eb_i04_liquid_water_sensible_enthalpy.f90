program test_eb_i04_liquid_water_sensible_enthalpy
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_liquid_water_sensible_enthalpy, only: &
       LWSE_OK, LWSE_INVALID_PROPERTIES, LWSE_INVALID_STORAGE_INPUT, &
       liquid_water_sensible_enthalpy_parameters_t, liquid_water_storage_change_t, &
       initialize_liquid_water_sensible_enthalpy_parameters, liquid_water_sensible_storage_j_m2, &
       evaluate_liquid_water_storage_change, evaluate_liquid_water_sensible_transport
  implicit none

  type(liquid_water_sensible_enthalpy_parameters_t) :: reference_zero, reference_five
  type(liquid_water_storage_change_t) :: change_zero, change_five
  integer :: status
  real(real64) :: energy, transport_zero, transport_five, expected_shift
  real(real64), parameter :: tol = 1.0e-9_real64

  ! Reference values are the current source-bound liquid-water constants used
  ! by the admitted restricted soil-temperature implementation.  EB-I04 keeps
  ! them explicit inputs rather than creating a second hidden constant source.
  call initialize_liquid_water_sensible_enthalpy_parameters(1000.0_real64, 4180.0_real64, &
       0.0_real64, reference_zero, status)
  if (status /= LWSE_OK .or. .not. reference_zero%ready()) error stop 'EB-I04 reference-zero properties invalid'

  call liquid_water_sensible_storage_j_m2(2.0_real64, 10.0_real64, reference_zero, energy, status)
  if (status /= LWSE_OK) error stop 'EB-I04 storage evaluation failed'
  if (abs(energy - 836000.0_real64) > tol) error stop 'EB-I04 storage unit conversion mismatch'

  call evaluate_liquid_water_storage_change(10.0_real64, 0.20_real64, 0.22_real64, &
       10.0_real64, 12.0_real64, reference_zero, change_zero, status)
  if (status /= LWSE_OK) error stop 'EB-I04 storage-change evaluation failed'
  if (abs(change_zero%exact_change_j_m2 - 267520.0_real64) > tol) error stop 'EB-I04 exact storage change mismatch'
  if (abs(change_zero%temperature_change_component_j_m2 - 175560.0_real64) > tol) &
       error stop 'EB-I04 temperature component mismatch'
  if (abs(change_zero%water_content_change_component_j_m2 - 91960.0_real64) > tol) &
       error stop 'EB-I04 water-content component mismatch'
  if (abs(change_zero%decomposition_residual_j_m2) > tol) error stop 'EB-I04 storage decomposition not exact'

  call evaluate_liquid_water_sensible_transport(0.50_real64, 12.0_real64, reference_zero, transport_zero, status)
  if (status /= LWSE_OK) error stop 'EB-I04 positive oriented transport failed'
  if (abs(transport_zero - 250800.0_real64) > tol) error stop 'EB-I04 positive transport mismatch'

  call evaluate_liquid_water_sensible_transport(-0.25_real64, 12.0_real64, reference_zero, energy, status)
  if (status /= LWSE_OK) error stop 'EB-I04 negative oriented transport failed'
  if (abs(energy + 125400.0_real64) > tol) error stop 'EB-I04 transport orientation was altered'

  call initialize_liquid_water_sensible_enthalpy_parameters(1000.0_real64, 4180.0_real64, &
       5.0_real64, reference_five, status)
  if (status /= LWSE_OK) error stop 'EB-I04 reference-five properties invalid'

  call evaluate_liquid_water_storage_change(10.0_real64, 0.20_real64, 0.22_real64, &
       10.0_real64, 12.0_real64, reference_five, change_five, status)
  if (status /= LWSE_OK) error stop 'EB-I04 shifted-reference storage failed'
  if (abs(change_five%exact_change_j_m2 - 225720.0_real64) > tol) error stop 'EB-I04 shifted storage mismatch'
  if (abs(change_five%temperature_change_component_j_m2 - change_zero%temperature_change_component_j_m2) > tol) &
       error stop 'EB-I04 temperature component must be reference invariant'
  expected_shift = -41800.0_real64
  if (abs((change_five%exact_change_j_m2 - change_zero%exact_change_j_m2) - expected_shift) > tol) &
       error stop 'EB-I04 storage reference-shift identity failed'
  if (abs((change_five%water_content_change_component_j_m2 - &
       change_zero%water_content_change_component_j_m2) - expected_shift) > tol) &
       error stop 'EB-I04 moisture component reference-shift identity failed'

  call evaluate_liquid_water_sensible_transport(0.50_real64, 12.0_real64, reference_five, transport_five, status)
  if (status /= LWSE_OK) error stop 'EB-I04 shifted-reference transport failed'
  expected_shift = -104500.0_real64
  if (abs((transport_five - transport_zero) - expected_shift) > tol) &
       error stop 'EB-I04 transport reference-shift identity failed'

  call initialize_liquid_water_sensible_enthalpy_parameters(0.0_real64, 4180.0_real64, &
       0.0_real64, reference_zero, status)
  if (status /= LWSE_INVALID_PROPERTIES) error stop 'EB-I04 invalid density accepted'

  call initialize_liquid_water_sensible_enthalpy_parameters(1000.0_real64, 4180.0_real64, &
       0.0_real64, reference_zero, status)
  call liquid_water_sensible_storage_j_m2(-0.1_real64, 10.0_real64, reference_zero, energy, status)
  if (status /= LWSE_INVALID_STORAGE_INPUT) error stop 'EB-I04 negative storage depth accepted'

  print '(a)', 'EB-I04 liquid-water sensible enthalpy: PASS'
end program test_eb_i04_liquid_water_sensible_enthalpy
