program test_pub_gc_e2_terminal_comparator
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_exchange_service_contract, only: groundwater_exchange_checkpoint_t, &
       groundwater_capture_checkpoint, GW_EXCHANGE_OK
  use mod_pub_gc_gw_a, only: pub_gc_gw_a_service_t
  use mod_pub_gc_e2_terminal_comparator, only: pub_gc_e2_comparison_t, pub_gc_e2_compare, &
       PUB_GC_E2_OK, PUB_GC_E2_INVALID_INPUT
  implicit none

  real(real64), parameter :: SY = 0.2_real64
  type(pub_gc_e2_comparison_t) :: equal_case, terminal_only, whole_only, real_e1
  type(pub_gc_gw_a_service_t) :: gw
  type(groundwater_exchange_checkpoint_t) :: checkpoint
  integer :: status
  real(real64) :: nan_value

  call run_case('SYN-EQUAL', 0.2_real64, 0.4_real64, 0.5_real64, equal_case)
  call require(close64(equal_case%q_terminal_cm, 0.2_real64), 'SYN-EQUAL terminal exchange')
  call require(close64(equal_case%interface_residual_terminal_cm, 0.0_real64), 'SYN-EQUAL terminal residual')
  call require(same_bits(equal_case%gw_head_whole_m, equal_case%gw_head_terminal_m), 'SYN-EQUAL groundwater equality')
  write(*,'(a)') 'PUB_GC_E2_SYN_EQUAL_EQUIVALENCE=PASS'

  call run_case('SYN-TERMINAL-ONLY', 0.2_real64, 0.6_real64, 0.5_real64, terminal_only)
  call require(close64(terminal_only%q_terminal_cm, 0.3_real64), 'terminal-only terminal exchange')
  call require(close64(terminal_only%interface_residual_terminal_cm, -0.1_real64), 'terminal-only residual')
  call require(same_bits(terminal_only%gw_head_whole_m, equal_case%gw_head_whole_m), 'terminal-only whole arm unchanged')
  call require(.not. same_bits(terminal_only%gw_head_terminal_m, equal_case%gw_head_terminal_m), 'terminal-only terminal arm changed')
  write(*,'(a)') 'PUB_GC_E2_SYN_TERMINAL_ONLY_SELECTIVITY=PASS'

  call run_case('SYN-WHOLE-ONLY', 0.35_real64, 0.4_real64, 0.5_real64, whole_only)
  call require(close64(whole_only%q_terminal_cm, 0.2_real64), 'whole-only terminal exchange')
  call require(close64(whole_only%interface_residual_terminal_cm, 0.15_real64), 'whole-only residual')
  call require(same_bits(whole_only%gw_head_terminal_m, equal_case%gw_head_terminal_m), 'whole-only terminal arm unchanged')
  call require(.not. same_bits(whole_only%gw_head_whole_m, equal_case%gw_head_whole_m), 'whole-only whole arm changed')
  write(*,'(a)') 'PUB_GC_E2_SYN_WHOLE_ONLY_SELECTIVITY=PASS'

  call run_case('REAL-E1-B', 4.13068016868983270e-2_real64, 1.37689338957496554_real64, 0.03_real64, real_e1)
  call require(close64(real_e1%gw_head_whole_m, real_e1%q_whole_cm*0.01_real64/SY), 'real E1 whole analytic GW-A')
  call require(close64(real_e1%gw_head_terminal_m, real_e1%q_terminal_cm*0.01_real64/SY), 'real E1 terminal analytic GW-A')
  write(*,'(a)') 'PUB_GC_E2_REAL_E1_B_ANALYTIC=PASS'

  call initialize_gw(gw, checkpoint)
  nan_value = ieee_value(0.0_real64, ieee_quiet_nan)
  call pub_gc_e2_compare(gw, checkpoint, 0.2_real64, nan_value, 0.5_real64, equal_case, status)
  call require(status == PUB_GC_E2_INVALID_INPUT .and. .not. equal_case%valid, 'nonfinite terminal fails closed')
  call require(gw%current_revision() == 0_int64, 'nonfinite input did not mutate GW-A')
  write(*,'(a)') 'PUB_GC_E2_NONFINITE_FAIL_CLOSED=PASS'

  write(*,'(a)') 'PUB_GC_E2_COMPARATOR_NO_H2_PRIMARY_INFERENCE=true'
  write(*,'(a)') 'PUB_GC_E2_TERMINAL_COMPARATOR_ORACLE=PASS'

contains

  subroutine run_case(label, q_whole, q_terminal_flux, duration, result)
    character(len=*), intent(in) :: label
    real(real64), intent(in) :: q_whole, q_terminal_flux, duration
    type(pub_gc_e2_comparison_t), intent(out) :: result
    type(pub_gc_gw_a_service_t) :: local_gw
    type(groundwater_exchange_checkpoint_t) :: local_checkpoint
    integer :: local_status

    call initialize_gw(local_gw, local_checkpoint)
    call pub_gc_e2_compare(local_gw, local_checkpoint, q_whole, q_terminal_flux, duration, result, local_status)
    call require(local_status == PUB_GC_E2_OK .and. result%valid, trim(label)//' comparator success')
    call require(close64(result%q_terminal_cm, q_terminal_flux*duration), trim(label)//' terminal formula')
    call require(close64(result%interface_residual_whole_cm, 0.0_real64), trim(label)//' whole residual zero')
    call require(close64(result%interface_residual_terminal_cm, q_whole-result%q_terminal_cm), &
         trim(label)//' terminal residual identity')
    call require(close64(result%gw_head_whole_m, q_whole*0.01_real64/SY), trim(label)//' whole GW-A analytic')
    call require(close64(result%gw_head_terminal_m, result%q_terminal_cm*0.01_real64/SY), trim(label)//' terminal GW-A analytic')
    call require(local_gw%current_revision() == 0_int64, trim(label)//' no GW-A commit')
    call require(close64(local_gw%accepted_head_m(), 0.0_real64), trim(label)//' accepted GW-A head unchanged')
    call require(close64(local_gw%accepted_time_day(), 0.0_real64), trim(label)//' accepted GW-A time unchanged')
    call emit_case(label, result)
  end subroutine run_case

  subroutine initialize_gw(service, cp)
    type(pub_gc_gw_a_service_t), intent(out) :: service
    type(groundwater_exchange_checkpoint_t), intent(out) :: cp
    integer :: local_status

    call service%initialize(9201_int64, 9301_int64, 0.0_real64, 0.0_real64, 1.0_real64, SY, &
         0.0_real64, 0.0_real64, local_status)
    call require(local_status == GW_EXCHANGE_OK .and. service%is_configured(), 'GW-A initialize')
    call groundwater_capture_checkpoint(service, cp, local_status)
    call require(local_status == GW_EXCHANGE_OK .and. cp%ready(), 'GW-A capture')
    call require(cp%origin_revision() == 0_int64, 'GW-A origin revision zero')
  end subroutine initialize_gw

  subroutine emit_case(label, r)
    character(len=*), intent(in) :: label
    type(pub_gc_e2_comparison_t), intent(in) :: r
    write(*,'(a,"|",a,"|",es26.17e3,"|",es26.17e3,"|",es26.17e3,"|",es26.17e3,"|",es26.17e3,"|",es26.17e3,"|",es26.17e3,"|",es26.17e3)') &
         'PUB_GC_E2_COMPARATOR_ROW', trim(label), r%q_whole_cm, r%q_terminal_flux_cm_per_day, r%duration_days, &
         r%q_terminal_cm, r%interface_residual_terminal_cm, r%gw_head_whole_m, r%gw_head_terminal_m, r%gw_head_difference_m
  end subroutine emit_case

  logical function close64(a,b) result(ok)
    real(real64), intent(in) :: a,b
    real(real64) :: scale
    scale = max(1.0_real64, abs(a), abs(b))
    ok = abs(a-b) <= 128.0_real64*epsilon(1.0_real64)*scale
  end function close64

  logical function same_bits(a,b) result(ok)
    real(real64), intent(in) :: a,b
    ok = transfer(a,0_int64) == transfer(b,0_int64)
  end function same_bits

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,a)') 'PUB_GC_E2_COMPARATOR_FAIL=', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_pub_gc_e2_terminal_comparator
