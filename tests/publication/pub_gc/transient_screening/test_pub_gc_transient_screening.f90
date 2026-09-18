program test_pub_gc_transient_screening
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_pub_gc_transient_trajectory, only: pub_gc_reference_level_result_t, &
       pub_gc_run_transient_reference_level, PUB_GC_REF_TRAJECTORY_OK
  implicit none

  integer :: executed_cases

  executed_cases = 0
  call run_case('TS-WET-5',       0.0_real64,  0.20_real64, [-5.0_real64,-1.0_real64,-1.0_real64])
  call run_case('TS-DRY-1',       0.0_real64,  0.20_real64, [ 1.0_real64,-1.0_real64,-1.0_real64])
  call run_case('TS-REV',         0.0_real64,  0.20_real64, [-5.0_real64, 1.0_real64,-1.0_real64])
  call run_case('TS-GW-UP',       0.05_real64, 0.20_real64, [-1.0_real64,-1.0_real64,-1.0_real64])
  call run_case('TS-GW-DOWN',    -0.05_real64, 0.20_real64, [-1.0_real64,-1.0_real64,-1.0_real64])
  call run_case('TS-LOW-SY-WET',  0.0_real64,  0.05_real64, [-5.0_real64,-1.0_real64,-1.0_real64])

  call require(executed_cases == 6, 'all six screening cases adjudicated')
  write(*,'(a,i0)') 'PUB_GC_TRANSIENT_SCREEN_CASES_ADJUDICATED=', executed_cases
  write(*,'(a)') 'PUB_GC_TRANSIENT_SCREEN_PRIMARY_H2_H3_ELIGIBLE=false'
  write(*,'(a)') 'PUB_GC_TRANSIENT_SCREEN_EXECUTION_VALID=PASS'

contains

  subroutine run_case(case_id, initial_gw_head_m, sy, factors)
    character(len=*), intent(in) :: case_id
    real(real64), intent(in) :: initial_gw_head_m, sy, factors(3)
    type(pub_gc_reference_level_result_t) :: l0, l1, l2
    integer :: s0, s1, s2
    real(real64) :: l01_head, l12_head, l01_q, l12_q
    real(real64) :: l12_pressure, l12_water, l12_storage
    logical :: stable, resolved

    executed_cases = executed_cases + 1
    write(*,'(a,a)') 'PUB_GC_TRANSIENT_CASE_BEGIN=',trim(case_id)
    write(*,'(a,es26.17e3)') 'PUB_GC_TRANSIENT_INITIAL_GW_HEAD_M=',initial_gw_head_m
    write(*,'(a,es26.17e3)') 'PUB_GC_TRANSIENT_GW_SY=',sy
    write(*,'(a,3(es26.17e3,1x))') 'PUB_GC_TRANSIENT_TOP_FACTORS=',factors

    call pub_gc_run_transient_reference_level(0.04_real64, 6, initial_gw_head_m, sy, factors, l0, s0)
    call pub_gc_run_transient_reference_level(0.02_real64, 12, initial_gw_head_m, sy, factors, l1, s1)
    call pub_gc_run_transient_reference_level(0.01_real64, 24, initial_gw_head_m, sy, factors, l2, s2)

    write(*,'(a,i0)') 'PUB_GC_TRANSIENT_L0_STATUS=',s0
    write(*,'(a,i0)') 'PUB_GC_TRANSIENT_L1_STATUS=',s1
    write(*,'(a,i0)') 'PUB_GC_TRANSIENT_L2_STATUS=',s2

    if (s0 /= PUB_GC_REF_TRAJECTORY_OK .or. s1 /= PUB_GC_REF_TRAJECTORY_OK .or. &
        s2 /= PUB_GC_REF_TRAJECTORY_OK .or. .not. l0%completed .or. .not. l1%completed .or. .not. l2%completed) then
      write(*,'(a)') 'PUB_GC_TRANSIENT_CASE_CLASS=INVALID'
      write(*,'(a,a)') 'PUB_GC_TRANSIENT_CASE_END=',trim(case_id)
      return
    end if

    call emit_level(case_id,'L0',l0)
    call emit_level(case_id,'L1',l1)
    call emit_level(case_id,'L2',l2)

    l01_head = matched_head_difference(l0,l1,2)
    l12_head = matched_head_difference(l1,l2,2)
    l01_q = abs(l0%cumulative_q_whole_cm-l1%cumulative_q_whole_cm)
    l12_q = abs(l1%cumulative_q_whole_cm-l2%cumulative_q_whole_cm)
    call require(size(l1%final_pressure_head_cm)==size(l2%final_pressure_head_cm), trim(case_id)//' head shape')
    call require(size(l1%final_water_content)==size(l2%final_water_content), trim(case_id)//' water shape')
    l12_pressure=maxval(abs(l1%final_pressure_head_cm-l2%final_pressure_head_cm))
    l12_water=maxval(abs(l1%final_water_content-l2%final_water_content))
    l12_storage=abs(l1%final_total_water_storage_cm-l2%final_total_water_storage_cm)

    stable = l12_head <= 1.0e-4_real64 .and. &
             l12_q <= 1.0e-4_real64 .and. &
             l12_pressure <= 1.0e-2_real64 .and. &
             l12_water <= 1.0e-5_real64 .and. &
             l12_storage <= 1.0e-4_real64
    resolved = l2%max_abs_terminal_surrogate_mismatch_cm > 1.0e-8_real64

    write(*,'(a,es26.17e3)') 'PUB_GC_TRANSIENT_L0_L1_MAX_MATCHED_GW_HEAD_DIFF_M=',l01_head
    write(*,'(a,es26.17e3)') 'PUB_GC_TRANSIENT_L1_L2_MAX_MATCHED_GW_HEAD_DIFF_M=',l12_head
    write(*,'(a,es26.17e3)') 'PUB_GC_TRANSIENT_L0_L1_CUMULATIVE_Q_DIFF_CM=',l01_q
    write(*,'(a,es26.17e3)') 'PUB_GC_TRANSIENT_L1_L2_CUMULATIVE_Q_DIFF_CM=',l12_q
    write(*,'(a,es26.17e3)') 'PUB_GC_TRANSIENT_L1_L2_FINAL_MAX_PRESSURE_HEAD_DIFF_CM=',l12_pressure
    write(*,'(a,es26.17e3)') 'PUB_GC_TRANSIENT_L1_L2_FINAL_MAX_WATER_CONTENT_DIFF=',l12_water
    write(*,'(a,es26.17e3)') 'PUB_GC_TRANSIENT_L1_L2_FINAL_STORAGE_DIFF_CM=',l12_storage

    if (stable .and. resolved) then
      write(*,'(a)') 'PUB_GC_TRANSIENT_CASE_CLASS=VALID_STABLE_RESOLVED'
    else if (stable) then
      write(*,'(a)') 'PUB_GC_TRANSIENT_CASE_CLASS=VALID_STABLE_UNRESOLVED'
    else
      write(*,'(a)') 'PUB_GC_TRANSIENT_CASE_CLASS=VALID_UNSTABLE'
    end if
    write(*,'(a,a)') 'PUB_GC_TRANSIENT_CASE_END=',trim(case_id)
  end subroutine run_case

  subroutine emit_level(case_id,label,level)
    character(len=*),intent(in)::case_id,label
    type(pub_gc_reference_level_result_t),intent(in)::level
    integer :: w
    write(*,'(a,a,"|",a)') 'PUB_GC_TRANSIENT_LEVEL=',trim(case_id),trim(label)
    write(*,'(a,es26.17e3)') 'PUB_GC_TRANSIENT_DT_DAY=',level%coupling_window_day
    write(*,'(a,i0)') 'PUB_GC_TRANSIENT_WINDOWS=',level%number_of_windows
    write(*,'(a,es26.17e3)') 'PUB_GC_TRANSIENT_CUMULATIVE_Q_WHOLE_CM=',level%cumulative_q_whole_cm
    write(*,'(a,es26.17e3)') 'PUB_GC_TRANSIENT_GROSS_Q_WHOLE_CM=',level%gross_q_whole_cm
    write(*,'(a,es26.17e3)') 'PUB_GC_TRANSIENT_SUM_ABS_TERMINAL_MISMATCH_CM=',level%sum_abs_terminal_surrogate_mismatch_cm
    write(*,'(a,es26.17e3)') 'PUB_GC_TRANSIENT_MAX_ABS_TERMINAL_MISMATCH_CM=',level%max_abs_terminal_surrogate_mismatch_cm
    write(*,'(a,es26.17e3)') 'PUB_GC_TRANSIENT_TERMINAL_GW_HEAD_M=',level%accepted_gw_head_m(level%number_of_windows)
    write(*,'(a,es26.17e3)') 'PUB_GC_TRANSIENT_FINAL_STORAGE_CM=',level%final_total_water_storage_cm
    do w=1,level%number_of_windows
      write(*,'(a,a,"|",a,"|",i0,"|",6(es26.17e3,"|"),i0)') &
        'PUB_GC_TRANSIENT_WINDOW|',trim(case_id),trim(label),w, &
        level%accepted_h_star_m(w),level%accepted_q_whole_cm(w),level%q_terminal_cm(w), &
        level%terminal_surrogate_mismatch_cm(w),level%paired_gw_head_difference_m(w), &
        level%accepted_residual_m(w),level%outer_evaluations(w)
    end do
  end subroutine emit_level

  real(real64) function matched_head_difference(coarse,fine,ratio) result(value)
    type(pub_gc_reference_level_result_t),intent(in)::coarse,fine
    integer,intent(in)::ratio
    integer :: i,j
    value=0.0_real64
    call require(ratio>0,'positive matched ratio')
    do i=0,coarse%number_of_windows
      j=i*ratio
      call require(j<=fine%number_of_windows,'matched time available')
      value=max(value,abs(coarse%accepted_gw_head_m(i)-fine%accepted_gw_head_m(j)))
    end do
  end function matched_head_difference

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then
      write(*,'(a)') 'PUB_GC_TRANSIENT_SCREEN_INFRA_FAIL='//trim(label)
      error stop 6
    end if
  end subroutine require

end program test_pub_gc_transient_screening
