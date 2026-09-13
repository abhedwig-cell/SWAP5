program test_eb_i15_bottom_sensible_energy
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_bottom_thermal_carrier, only: fmr_bottom_thermal_carrier_t, fmr_bottom_thermal_candidate_t
  use mod_liquid_water_sensible_enthalpy, only: liquid_water_sensible_enthalpy_parameters_t, &
       initialize_liquid_water_sensible_enthalpy_parameters, LWSE_OK
  use mod_fmr_bottom_sensible_energy, only: fmr_bottom_sensible_energy_result_t, &
       evaluate_fmr_bottom_sensible_energy, FMR_BOTTOM_ENERGY_COMPLETE, &
       FMR_BOTTOM_ENERGY_INCOMPLETE_EXTERNAL_DONOR, FMR_BOTTOM_ENERGY_INVALID_CANDIDATE, &
       FMR_BOTTOM_ENERGY_INVALID_PROPERTIES
  implicit none

  call verify_local_terminal_quadrature()
  call verify_terminal_temperature_not_start_temperature()
  call verify_exact_zero_without_donor()
  call verify_external_inflow_fails_closed()
  call verify_invalid_inputs_fail_closed()
  call verify_reference_temperature_shift_identity()
  write(*,'(A)') 'EB_I15_BOTTOM_SENSIBLE_ENERGY_GATE PASS'

contains

  subroutine make_parameters(reference_temperature_c, parameters)
    real(real64), intent(in) :: reference_temperature_c
    type(liquid_water_sensible_enthalpy_parameters_t), intent(out) :: parameters
    integer :: status

    call initialize_liquid_water_sensible_enthalpy_parameters(1000.0_real64, 4180.0_real64, &
         reference_temperature_c, parameters, status)
    call require(status == LWSE_OK .and. parameters%ready(), 'energy parameters ready')
  end subroutine make_parameters

  subroutine verify_local_terminal_quadrature()
    type(fmr_bottom_thermal_carrier_t) :: carrier
    type(fmr_bottom_thermal_candidate_t) :: candidate
    type(liquid_water_sensible_enthalpy_parameters_t) :: parameters
    type(fmr_bottom_sensible_energy_result_t) :: result
    real(real64) :: total, subtotal, expected, forbidden_aggregate
    logical :: ok, available
    integer :: n, nlocal, nzero, nexternal

    call make_parameters(5.0_real64, parameters)
    call carrier%initialize(4, ok)
    call require(ok, 'local carrier initialize')
    call carrier%append_local(0.0_real64, 1.0_real64, 0.30_real64, 10.0_real64, 12.0_real64, ok)
    call require(ok, 'local sample one append')
    call carrier%append_local(1.0_real64, 2.0_real64, 0.20_real64, 12.0_real64, 20.0_real64, ok)
    call require(ok, 'local sample two append')
    call carrier%materialize_candidate(0.0_real64, 2.0_real64, candidate, ok)
    call require(ok .and. candidate%ready(), 'local candidate materialized')

    call evaluate_fmr_bottom_sensible_energy(candidate, parameters, result)
    call require(result%status() == FMR_BOTTOM_ENERGY_COMPLETE .and. result%complete(), 'local result complete')
    call result%total_energy(total, available)
    call require(available, 'local total available')
    expected = 0.01_real64 * 1000.0_real64 * 4180.0_real64 * &
         (0.30_real64*(12.0_real64-5.0_real64) + 0.20_real64*(20.0_real64-5.0_real64))
    call require(close(total, expected, 1.0e-10_real64), 'sample-wise terminal energy exact algebra')

    forbidden_aggregate = 0.01_real64 * 1000.0_real64 * 4180.0_real64 * &
         (0.30_real64+0.20_real64) * (20.0_real64-5.0_real64)
    call require(abs(total-forbidden_aggregate) > 1.0_real64, 'aggregate-final-temperature shortcut rejected adversarially')

    call result%local_outward_subtotal(subtotal, available)
    call require(available .and. close(subtotal, total, 1.0e-12_real64), 'complete local subtotal equals total')
    call result%counts(n, nlocal, nzero, nexternal)
    call require(n == 2 .and. nlocal == 2 .and. nzero == 0 .and. nexternal == 0, 'local counts exact')
    write(*,'(A)') 'EB_I15_LOCAL_TERMINAL_QUADRATURE=PASS'
  end subroutine verify_local_terminal_quadrature

  subroutine verify_terminal_temperature_not_start_temperature()
    type(fmr_bottom_thermal_carrier_t) :: carrier_a, carrier_b
    type(fmr_bottom_thermal_candidate_t) :: candidate_a, candidate_b
    type(liquid_water_sensible_enthalpy_parameters_t) :: parameters
    type(fmr_bottom_sensible_energy_result_t) :: result_a, result_b
    real(real64) :: energy_a, energy_b
    logical :: ok, available_a, available_b

    call make_parameters(0.0_real64, parameters)
    call carrier_a%initialize(1, ok)
    call require(ok, 'terminal A initialize')
    call carrier_a%append_local(0.0_real64, 1.0_real64, 0.40_real64, -100.0_real64, 15.0_real64, ok)
    call require(ok, 'terminal A append')
    call carrier_a%materialize_candidate(0.0_real64, 1.0_real64, candidate_a, ok)
    call require(ok, 'terminal A materialize')

    call carrier_b%initialize(1, ok)
    call require(ok, 'terminal B initialize')
    call carrier_b%append_local(0.0_real64, 1.0_real64, 0.40_real64, 100.0_real64, 15.0_real64, ok)
    call require(ok, 'terminal B append')
    call carrier_b%materialize_candidate(0.0_real64, 1.0_real64, candidate_b, ok)
    call require(ok, 'terminal B materialize')

    call evaluate_fmr_bottom_sensible_energy(candidate_a, parameters, result_a)
    call evaluate_fmr_bottom_sensible_energy(candidate_b, parameters, result_b)
    call result_a%total_energy(energy_a, available_a)
    call result_b%total_energy(energy_b, available_b)
    call require(available_a .and. available_b .and. same_bits(energy_a, energy_b), &
         'start temperature cannot affect frozen terminal rule')
    write(*,'(A)') 'EB_I15_TERMINAL_NOT_START_TEMPERATURE=PASS'
  end subroutine verify_terminal_temperature_not_start_temperature

  subroutine verify_exact_zero_without_donor()
    type(fmr_bottom_thermal_carrier_t) :: carrier
    type(fmr_bottom_thermal_candidate_t) :: candidate
    type(liquid_water_sensible_enthalpy_parameters_t) :: parameters
    type(fmr_bottom_sensible_energy_result_t) :: result
    real(real64) :: total
    logical :: ok, available
    integer :: n, nlocal, nzero, nexternal

    call make_parameters(-273.15_real64, parameters)
    call carrier%initialize(1, ok)
    call require(ok, 'zero carrier initialize')
    call carrier%append_zero(2.0_real64, 3.0_real64, ok)
    call require(ok, 'zero sample append')
    call carrier%materialize_candidate(2.0_real64, 3.0_real64, candidate, ok)
    call require(ok, 'zero candidate materialize')

    call evaluate_fmr_bottom_sensible_energy(candidate, parameters, result)
    call result%total_energy(total, available)
    call require(result%status() == FMR_BOTTOM_ENERGY_COMPLETE .and. result%complete(), 'zero result complete')
    call require(available .and. total == 0.0_real64, 'zero energy exact')
    call result%counts(n, nlocal, nzero, nexternal)
    call require(n == 1 .and. nlocal == 0 .and. nzero == 1 .and. nexternal == 0, 'zero counts exact')
    write(*,'(A)') 'EB_I15_EXACT_ZERO_NO_DONOR=PASS'
  end subroutine verify_exact_zero_without_donor

  subroutine verify_external_inflow_fails_closed()
    type(fmr_bottom_thermal_carrier_t) :: carrier
    type(fmr_bottom_thermal_candidate_t) :: candidate
    type(liquid_water_sensible_enthalpy_parameters_t) :: parameters
    type(fmr_bottom_sensible_energy_result_t) :: result
    real(real64) :: total, subtotal, expected_local
    logical :: ok, total_available, subtotal_available
    integer :: n, nlocal, nzero, nexternal

    call make_parameters(5.0_real64, parameters)
    call carrier%initialize(2, ok)
    call require(ok, 'external carrier initialize')
    call carrier%append_local(0.0_real64, 0.5_real64, 0.10_real64, 8.0_real64, 10.0_real64, ok)
    call require(ok, 'external fixture local append')
    call carrier%append_external_incomplete(0.5_real64, 1.0_real64, -0.20_real64, ok)
    call require(ok, 'external fixture inward append')
    call carrier%materialize_candidate(0.0_real64, 1.0_real64, candidate, ok)
    call require(ok .and. candidate%ready() .and. .not. candidate%thermal_complete(), 'mixed candidate materialized incomplete')

    call evaluate_fmr_bottom_sensible_energy(candidate, parameters, result)
    call require(result%status() == FMR_BOTTOM_ENERGY_INCOMPLETE_EXTERNAL_DONOR .and. .not. result%complete(), &
         'external donor omission is explicit incomplete status')
    call result%total_energy(total, total_available)
    call require(.not. total_available .and. total == 0.0_real64, 'incomplete total unavailable rather than zero-energy claim')
    call result%local_outward_subtotal(subtotal, subtotal_available)
    expected_local = 0.01_real64 * 1000.0_real64 * 4180.0_real64 * 0.10_real64 * (10.0_real64-5.0_real64)
    call require(subtotal_available .and. close(subtotal, expected_local, 1.0e-10_real64), 'local subtotal diagnostic retained')
    call result%counts(n, nlocal, nzero, nexternal)
    call require(n == 2 .and. nlocal == 1 .and. nzero == 0 .and. nexternal == 1, 'external incomplete count exact')
    write(*,'(A)') 'EB_I15_EXTERNAL_INFLOW_FAIL_CLOSED=PASS'
  end subroutine verify_external_inflow_fails_closed

  subroutine verify_invalid_inputs_fail_closed()
    type(fmr_bottom_thermal_carrier_t) :: carrier
    type(fmr_bottom_thermal_candidate_t) :: candidate, empty_candidate
    type(liquid_water_sensible_enthalpy_parameters_t) :: parameters, invalid_parameters
    type(fmr_bottom_sensible_energy_result_t) :: result
    real(real64) :: total
    logical :: ok, available

    call make_parameters(0.0_real64, parameters)
    call evaluate_fmr_bottom_sensible_energy(empty_candidate, parameters, result)
    call require(result%status() == FMR_BOTTOM_ENERGY_INVALID_CANDIDATE .and. .not. result%complete(), &
         'unready candidate rejected')
    call result%total_energy(total, available)
    call require(.not. available, 'invalid candidate exposes no total')

    call carrier%initialize(1, ok)
    call require(ok, 'invalid properties carrier initialize')
    call carrier%append_local(0.0_real64, 1.0_real64, 0.10_real64, 9.0_real64, 10.0_real64, ok)
    call require(ok, 'invalid properties sample append')
    call carrier%materialize_candidate(0.0_real64, 1.0_real64, candidate, ok)
    call require(ok, 'invalid properties candidate materialize')
    call evaluate_fmr_bottom_sensible_energy(candidate, invalid_parameters, result)
    call require(result%status() == FMR_BOTTOM_ENERGY_INVALID_PROPERTIES .and. .not. result%complete(), &
         'uninitialized properties rejected')
    call result%total_energy(total, available)
    call require(.not. available, 'invalid properties expose no total')
    write(*,'(A)') 'EB_I15_INVALID_INPUTS_FAIL_CLOSED=PASS'
  end subroutine verify_invalid_inputs_fail_closed

  subroutine verify_reference_temperature_shift_identity()
    type(fmr_bottom_thermal_carrier_t) :: carrier
    type(fmr_bottom_thermal_candidate_t) :: candidate
    type(liquid_water_sensible_enthalpy_parameters_t) :: parameters_a, parameters_b
    type(fmr_bottom_sensible_energy_result_t) :: result_a, result_b
    real(real64) :: energy_a, energy_b, expected_shift, delta_ref, qsum
    logical :: ok, available_a, available_b

    call make_parameters(5.0_real64, parameters_a)
    delta_ref = 7.25_real64
    call make_parameters(5.0_real64 + delta_ref, parameters_b)
    call carrier%initialize(2, ok)
    call require(ok, 'reference shift carrier initialize')
    call carrier%append_local(0.0_real64, 1.0_real64, 0.30_real64, 10.0_real64, 12.0_real64, ok)
    call require(ok, 'reference shift sample one append')
    call carrier%append_local(1.0_real64, 2.0_real64, 0.20_real64, 12.0_real64, 20.0_real64, ok)
    call require(ok, 'reference shift sample two append')
    call carrier%materialize_candidate(0.0_real64, 2.0_real64, candidate, ok)
    call require(ok, 'reference shift candidate materialize')

    call evaluate_fmr_bottom_sensible_energy(candidate, parameters_a, result_a)
    call evaluate_fmr_bottom_sensible_energy(candidate, parameters_b, result_b)
    call result_a%total_energy(energy_a, available_a)
    call result_b%total_energy(energy_b, available_b)
    qsum = 0.50_real64
    expected_shift = -0.01_real64 * 1000.0_real64 * 4180.0_real64 * delta_ref * qsum
    call require(available_a .and. available_b, 'reference shift totals available')
    call require(close(energy_b-energy_a, expected_shift, 1.0e-9_real64), 'reference shift identity')
    write(*,'(A)') 'EB_I15_REFERENCE_SHIFT_IDENTITY=PASS'
  end subroutine verify_reference_temperature_shift_identity

  logical function close(a, b, tolerance) result(ok)
    real(real64), intent(in) :: a, b, tolerance
    ok = abs(a-b) <= tolerance * max(1.0_real64, abs(a), abs(b))
  end function close

  logical function same_bits(a, b) result(ok)
    use, intrinsic :: iso_fortran_env, only: int64
    real(real64), intent(in) :: a, b
    integer(int64) :: ia, ib
    ia = transfer(a, ia)
    ib = transfer(b, ib)
    ok = ia == ib
  end function same_bits

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'EB_I15_TEST_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_eb_i15_bottom_sensible_energy
