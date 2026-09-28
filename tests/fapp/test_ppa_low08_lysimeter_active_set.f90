program test_ppa_low08_lysimeter_active_set
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_low08_lysimeter_active_set
  implicit none
  integer :: i, task, sw_k_impl, status
  logical :: prior, active, writes_gradient, writes_hbot, expected_active, expected_write
  real(real64) :: head, crit, spacing, plate, conductivity, dkdh
  real(real64) :: gradient, hbot, residual, jacobian, expected_gradient, expected_residual, expected_jacobian
  real(real64) :: saved, replay, alternate

  call check(1, 0, .false., 8, 7.0_real64, 10.0_real64, 2.0_real64, -1.0_real64, 4.0_real64, 0.0_real64, &
      .false., 'strict threshold inactive')
  call check(1, 0, .false., 8, 7.0001_real64, 10.0_real64, 2.0_real64, -1.0_real64, 4.0_real64, 0.0_real64, &
      .true., 'above threshold active')
  call check(2, 1, .true., 8, -50.0_real64, 10.0_real64, 2.0_real64, -1.0_real64, 4.0_real64, -0.25_real64, &
      .true., 'task two retains prior active set')
  call check(2, 0, .false., 8, 50.0_real64, 10.0_real64, 2.0_real64, -1.0_real64, 4.0_real64, 0.0_real64, &
      .false., 'task two retains prior inactive set')

  do i = 1, 100000
    task = 1 + mod(i, 2)
    sw_k_impl = mod(i+1, 2)
    prior = mod(i/2, 2) == 1
    head = real(mod(i*7919, 200001)-100000, real64) / 1000.0_real64
    crit = real(mod(i*37, 40001)-20000, real64) / 1000.0_real64
    spacing = real(mod(i*17, 100000)+1, real64) / 1000.0_real64
    plate = -real(mod(i*101, 100001), real64) / 100.0_real64
    conductivity = real(mod(i*43, 100001), real64) / 100000.0_real64
    dkdh = real(mod(i*31, 20001)-10000, real64) / 100000.0_real64
    if (task == 1) then
      expected_active = head > crit - spacing + plate
    else
      expected_active = prior
    end if
    expected_write = expected_active
    expected_gradient = 0.0_real64
    expected_residual = 0.0_real64
    expected_jacobian = 0.0_real64
    if (expected_active) then
      expected_gradient = (head - plate) / spacing + 1.0_real64
      expected_residual = conductivity * expected_gradient
      expected_jacobian = conductivity / spacing
      if (sw_k_impl == 1) expected_jacobian = expected_jacobian + 0.5_real64*dkdh*expected_gradient
    end if
    call evaluate_ppa_low08_lysimeter_active_set(task, 8, sw_k_impl, prior, head, crit, spacing, plate, &
        conductivity, dkdh, active, writes_gradient, gradient, writes_hbot, hbot, residual, jacobian, status)
    if (status /= PPA_LOW08_ACTIVE_OK .or. (active .neqv. expected_active) .or. &
        (writes_gradient .neqv. expected_write) .or. (writes_hbot .neqv. expected_write) .or. &
        transfer(gradient, 0_int64) /= transfer(expected_gradient, 0_int64) .or. &
        transfer(residual, 0_int64) /= transfer(expected_residual, 0_int64) .or. &
        transfer(jacobian, 0_int64) /= transfer(expected_jacobian, 0_int64)) &
      error stop '100000-vector lysimeter active-set source oracle mismatch'
  end do

  call evaluate_ppa_low08_lysimeter_active_set(1, 8, 0, .false., 11.0_real64, 10.0_real64, &
      2.0_real64, -1.0_real64, 4.0_real64, 0.0_real64, active, writes_gradient, gradient, writes_hbot, &
      hbot, residual, jacobian, status)
  saved = residual
  call evaluate_ppa_low08_lysimeter_active_set(1, 8, 0, .false., 12.0_real64, 10.0_real64, &
      2.0_real64, -1.0_real64, 4.0_real64, 0.0_real64, active, writes_gradient, gradient, writes_hbot, &
      hbot, alternate, jacobian, status)
  call evaluate_ppa_low08_lysimeter_active_set(1, 8, 0, .false., 11.0_real64, 10.0_real64, &
      2.0_real64, -1.0_real64, 4.0_real64, 0.0_real64, active, writes_gradient, gradient, writes_hbot, &
      hbot, replay, jacobian, status)
  if (transfer(saved, 0_int64) /= transfer(replay, 0_int64) .or. &
      transfer(saved, 0_int64) == transfer(alternate, 0_int64)) error stop 'A/B/A replay mismatch'

  call evaluate_ppa_low08_lysimeter_active_set(1, 8, 0, .false., &
      ieee_value(0.0_real64, ieee_quiet_nan), 10.0_real64, 2.0_real64, -1.0_real64, 4.0_real64, &
      0.0_real64, active, writes_gradient, gradient, writes_hbot, hbot, residual, jacobian, status)
  if (status /= PPA_LOW08_ACTIVE_INVALID_INPUT) error stop 'nonfinite head accepted'

  write(*,'(a)') 'PPA_LOW08_LYSIMETER_ACTIVE_SET_SOURCE_ORACLE_100000=PASS'
  write(*,'(a)') 'PPA_LOW08_LYSIMETER_STRICT_THRESHOLD_AND_TASK_REPLAY=PASS'
  write(*,'(a)') 'PPA_LOW08_LYSIMETER_GRADIENT_RESIDUAL_JACOBIAN=PASS'
  write(*,'(a)') 'PPA_LOW08_LYSIMETER_STATELESS_A_B_A_AND_INVALID=PASS'

contains

  subroutine check(which_task, sw_k, old_active, mode, h, critical, distance, plate_head, kbot, derivative, &
                   want_active, label)
    integer, intent(in) :: which_task, sw_k, mode
    logical, intent(in) :: old_active, want_active
    real(real64), intent(in) :: h, critical, distance, plate_head, kbot, derivative
    character(len=*), intent(in) :: label
    call evaluate_ppa_low08_lysimeter_active_set(which_task, mode, sw_k, old_active, h, critical, &
        distance, plate_head, kbot, derivative, active, writes_gradient, gradient, writes_hbot, &
        hbot, residual, jacobian, status)
    if (status /= PPA_LOW08_ACTIVE_OK .or. (active .neqv. want_active)) then
      write(*,'(a)') 'failed: '//label
      error stop 1
    end if
    if (want_active) then
      expected_gradient = (h-plate_head)/distance + 1.0_real64
      expected_residual = kbot*expected_gradient
      expected_jacobian = kbot/distance
      if (sw_k == 1) expected_jacobian = expected_jacobian + 0.5_real64*derivative*expected_gradient
      if (.not. writes_gradient .or. .not. writes_hbot .or. &
          abs(gradient-expected_gradient) > 16.0_real64*epsilon(expected_gradient) .or. &
          abs(hbot-plate_head) > 16.0_real64*epsilon(plate_head) .or. &
          abs(residual-expected_residual) > 16.0_real64*epsilon(expected_residual) .or. &
          abs(jacobian-expected_jacobian) > 16.0_real64*epsilon(expected_jacobian)) error stop 1
    else if (writes_gradient .or. writes_hbot .or. transfer(residual, 0_int64) /= 0_int64 .or. &
             transfer(jacobian, 0_int64) /= 0_int64) then
      error stop 'inactive lysimeter branch published active terms'
    end if
  end subroutine check

end program test_ppa_low08_lysimeter_active_set
