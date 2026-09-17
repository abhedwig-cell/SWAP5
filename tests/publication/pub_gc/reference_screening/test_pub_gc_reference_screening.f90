program test_pub_gc_reference_screening
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_pub_gc_reference_trajectory, only: pub_gc_reference_level_result_t, pub_gc_run_reference_level, &
       PUB_GC_REF_TRAJECTORY_OK
  implicit none

  type(pub_gc_reference_level_result_t) :: l0, l1, l2
  real(real64) :: l01_head, l12_head
  real(real64) :: l01_q, l12_q
  real(real64) :: l12_pressure, l12_water, l12_storage
  integer :: status
  logical :: stable

  call pub_gc_run_reference_level(0.04_real64, 3, l0, status)
  call require(status == PUB_GC_REF_TRAJECTORY_OK .and. l0%completed, 'L0 reference construction')
  call emit_level('L0', l0)

  call pub_gc_run_reference_level(0.02_real64, 6, l1, status)
  call require(status == PUB_GC_REF_TRAJECTORY_OK .and. l1%completed, 'L1 reference construction')
  call emit_level('L1', l1)

  call pub_gc_run_reference_level(0.01_real64, 12, l2, status)
  call require(status == PUB_GC_REF_TRAJECTORY_OK .and. l2%completed, 'L2 reference construction')
  call emit_level('L2', l2)

  l01_head = matched_head_difference(l0, l1, 2)
  l12_head = matched_head_difference(l1, l2, 2)
  l01_q = abs(l0%cumulative_q_whole_cm-l1%cumulative_q_whole_cm)
  l12_q = abs(l1%cumulative_q_whole_cm-l2%cumulative_q_whole_cm)

  call require(size(l1%final_pressure_head_cm)==size(l2%final_pressure_head_cm), 'final pressure-head shape')
  call require(size(l1%final_water_content)==size(l2%final_water_content), 'final water-content shape')
  l12_pressure = maxval(abs(l1%final_pressure_head_cm-l2%final_pressure_head_cm))
  l12_water = maxval(abs(l1%final_water_content-l2%final_water_content))
  l12_storage = abs(l1%final_total_water_storage_cm-l2%final_total_water_storage_cm)

  stable = l12_head <= 1.0e-4_real64 .and. &
           l12_q <= 1.0e-4_real64 .and. &
           l12_pressure <= 1.0e-2_real64 .and. &
           l12_water <= 1.0e-5_real64 .and. &
           l12_storage <= 1.0e-4_real64

  write(*,'(a,es26.17e3)') 'PUB_GC_REF_SCREEN_L0_L1_MAX_MATCHED_GW_HEAD_DIFF_M=',l01_head
  write(*,'(a,es26.17e3)') 'PUB_GC_REF_SCREEN_L1_L2_MAX_MATCHED_GW_HEAD_DIFF_M=',l12_head
  write(*,'(a,es26.17e3)') 'PUB_GC_REF_SCREEN_L0_L1_CUMULATIVE_Q_DIFF_CM=',l01_q
  write(*,'(a,es26.17e3)') 'PUB_GC_REF_SCREEN_L1_L2_CUMULATIVE_Q_DIFF_CM=',l12_q
  write(*,'(a,es26.17e3)') 'PUB_GC_REF_SCREEN_L1_L2_FINAL_MAX_PRESSURE_HEAD_DIFF_CM=',l12_pressure
  write(*,'(a,es26.17e3)') 'PUB_GC_REF_SCREEN_L1_L2_FINAL_MAX_WATER_CONTENT_DIFF=',l12_water
  write(*,'(a,es26.17e3)') 'PUB_GC_REF_SCREEN_L1_L2_FINAL_STORAGE_DIFF_CM=',l12_storage
  if (stable) then
    write(*,'(a)') 'PUB_GC_REF_SCREEN_STABILITY=STABLE'
  else
    write(*,'(a)') 'PUB_GC_REF_SCREEN_STABILITY=UNSTABLE'
  end if
  write(*,'(a)') 'PUB_GC_REF_SCREEN_PRIMARY_H2_H3_ELIGIBLE=false'
  write(*,'(a)') 'PUB_GC_REF_SCREEN_EXECUTION_VALID=PASS'

contains

  subroutine emit_level(label, level)
    character(len=*), intent(in) :: label
    type(pub_gc_reference_level_result_t), intent(in) :: level
    integer :: w
    write(*,'(a,a)') 'PUB_GC_REF_SCREEN_LEVEL=',trim(label)
    write(*,'(a,es26.17e3)') 'PUB_GC_REF_SCREEN_DT_DAY=',level%coupling_window_day
    write(*,'(a,i0)') 'PUB_GC_REF_SCREEN_WINDOWS=',level%number_of_windows
    write(*,'(a,es26.17e3)') 'PUB_GC_REF_SCREEN_CUMULATIVE_Q_CM=',level%cumulative_q_whole_cm
    write(*,'(a,es26.17e3)') 'PUB_GC_REF_SCREEN_TERMINAL_GW_HEAD_M=',level%accepted_gw_head_m(level%number_of_windows)
    write(*,'(a,es26.17e3)') 'PUB_GC_REF_SCREEN_FINAL_STORAGE_CM=',level%final_total_water_storage_cm
    write(*,'(a,i0)') 'PUB_GC_REF_SCREEN_FINAL_SWAP_REVISION=',level%final_swap_revision
    write(*,'(a,i0)') 'PUB_GC_REF_SCREEN_FINAL_GW_REVISION=',level%final_gw_revision
    do w=1,level%number_of_windows
      write(*,'(a,a,"|",i0,"|",es26.17e3,"|",es26.17e3,"|",es26.17e3,"|",i0)') &
           'PUB_GC_REF_SCREEN_WINDOW|',trim(label),w,level%accepted_h_star_m(w), &
           level%accepted_residual_m(w),level%accepted_q_whole_cm(w),level%outer_evaluations(w)
    end do
  end subroutine emit_level

  real(real64) function matched_head_difference(coarse, fine, ratio) result(value)
    type(pub_gc_reference_level_result_t), intent(in) :: coarse, fine
    integer, intent(in) :: ratio
    integer :: i, fine_index
    value = 0.0_real64
    call require(ratio>0, 'positive matched ratio')
    do i=0,coarse%number_of_windows
      fine_index = i*ratio
      call require(fine_index<=fine%number_of_windows, 'matched time available')
      value=max(value,abs(coarse%accepted_gw_head_m(i)-fine%accepted_gw_head_m(fine_index)))
    end do
  end function matched_head_difference

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then
      write(*,'(a)') 'PUB_GC_REF_SCREEN_INFRA_FAIL='//trim(label)
      error stop 5
    end if
  end subroutine require

end program test_pub_gc_reference_screening
