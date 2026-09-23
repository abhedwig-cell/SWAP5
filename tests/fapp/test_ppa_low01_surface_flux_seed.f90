program test_ppa_low01_surface_flux_seed
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_low01_surface_flux_seed
  implicit none
  integer :: i, status
  real(real64) :: rain, irrigation, snow_melt, area_store, runon, evaporation, demand
  real(real64) :: pond, pond_previous, dt, runots, q0, qv1, expected_q0, expected_qv1
  real(real64) :: saved, replay, alternate

  call check(0.3_real64, 0.1_real64, 0.2_real64, 0.25_real64, 0.05_real64, &
      0.04_real64, 0.03_real64, 0.02_real64, 0.01_real64, 0.5_real64, 0.005_real64, &
      'pond delta and runots seed')

  do i = 1, 100000
    rain = real(mod(i*37, 200001)-100000, real64) / 10000.0_real64
    irrigation = real(mod(i*17, 200001)-100000, real64) / 10000.0_real64
    snow_melt = real(mod(i*101, 200001)-100000, real64) / 10000.0_real64
    area_store = real(mod(i*43, 100001), real64) / 100000.0_real64
    runon = real(mod(i*29, 200001)-100000, real64) / 10000.0_real64
    evaporation = real(mod(i*23, 200001)-100000, real64) / 10000.0_real64
    demand = real(mod(i*13, 200001)-100000, real64) / 10000.0_real64
    pond = real(mod(i*11, 200001)-100000, real64) / 10000.0_real64
    pond_previous = real(mod(i*31, 200001)-100000, real64) / 10000.0_real64
    dt = real(mod(i*7, 100000)+1, real64) / 10000.0_real64
    runots = real(mod(i*53, 200001)-100000, real64) / 10000.0_real64
    expected_q0 = (rain+irrigation+snow_melt)*(1.0_real64-area_store)+runon-evaporation-demand
    expected_qv1 = -expected_q0+(pond-pond_previous)/dt+runots/dt
    call evaluate_ppa_low01_surface_flux_seed(rain, irrigation, snow_melt, area_store, runon, &
        evaporation, demand, pond, pond_previous, dt, runots, q0, qv1, status)
    if (status /= PPA_LOW01_SEED_OK .or. transfer(q0, 0_int64) /= transfer(expected_q0, 0_int64) .or. &
        transfer(qv1, 0_int64) /= transfer(expected_qv1, 0_int64)) &
      error stop '100000-vector SWBOTB=1 surface flux seed source oracle mismatch'
  end do

  call evaluate_ppa_low01_surface_flux_seed(0.3_real64, 0.1_real64, 0.2_real64, 0.25_real64, &
      0.05_real64, 0.04_real64, 0.03_real64, 0.02_real64, 0.01_real64, 0.5_real64, 0.005_real64, &
      expected_q0, saved, status)
  call evaluate_ppa_low01_surface_flux_seed(0.3_real64, 0.1_real64, 0.2_real64, 0.25_real64, &
      0.15_real64, 0.04_real64, 0.03_real64, 0.02_real64, 0.01_real64, 0.5_real64, 0.005_real64, &
      expected_q0, alternate, status)
  call evaluate_ppa_low01_surface_flux_seed(0.3_real64, 0.1_real64, 0.2_real64, 0.25_real64, &
      0.05_real64, 0.04_real64, 0.03_real64, 0.02_real64, 0.01_real64, 0.5_real64, 0.005_real64, &
      q0, replay, status)
  if (transfer(saved, 0_int64) /= transfer(replay, 0_int64) .or. &
      transfer(saved, 0_int64) == transfer(alternate, 0_int64)) error stop 'A/B/A replay mismatch'
  call evaluate_ppa_low01_surface_flux_seed(1.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, &
      0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, &
      q0, qv1, status)
  if (status /= PPA_LOW01_SEED_INVALID_INPUT) error stop 'zero timestep accepted'
  call evaluate_ppa_low01_surface_flux_seed(ieee_value(0.0_real64, ieee_quiet_nan), 0.0_real64, &
      0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, &
      1.0_real64, 0.0_real64, q0, qv1, status)
  if (status /= PPA_LOW01_SEED_INVALID_INPUT) error stop 'nonfinite surface input accepted'

  write(*,'(a)') 'PPA_LOW01_SURFACE_Q0_QV1_SOURCE_ORACLE_100000=PASS'
  write(*,'(a)') 'PPA_LOW01_SURFACE_AREA_STORE_AND_POND_DELTA=PASS'
  write(*,'(a)') 'PPA_LOW01_SURFACE_SEED_STATELESS_A_B_A=PASS'
  write(*,'(a)') 'PPA_LOW01_SURFACE_SEED_INVALID_INPUT_FAIL_CLOSED=PASS'

contains

  subroutine check(rainfall, irrigation, meltwater, storage, lateral, evap, ep, &
      pond_now, pond_old, timestep, runoff, label)
    real(real64), intent(in) :: rainfall, irrigation, meltwater, storage, lateral, evap, ep
    real(real64), intent(in) :: pond_now, pond_old, timestep, runoff
    character(len=*), intent(in) :: label
    expected_q0 = (rainfall+irrigation+meltwater)*(1.0_real64-storage)+lateral-evap-ep
    expected_qv1 = -expected_q0+(pond_now-pond_old)/timestep+runoff/timestep
    call evaluate_ppa_low01_surface_flux_seed(rainfall, irrigation, meltwater, storage, lateral, &
        evap, ep, pond_now, pond_old, timestep, runoff, q0, qv1, status)
    if (status /= PPA_LOW01_SEED_OK .or. transfer(q0, 0_int64) /= transfer(expected_q0, 0_int64) .or. &
        transfer(qv1, 0_int64) /= transfer(expected_qv1, 0_int64)) then
      write(*,'(a)') 'failed: '//label
      error stop 1
    end if
  end subroutine check

end program test_ppa_low01_surface_flux_seed
