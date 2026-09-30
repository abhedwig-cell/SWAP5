program test_ppa_wu05a2_macropore_state
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_macropore_continuation_state, only: macropore_continuation_state_t, &
       copy_macropore_continuation_state
  implicit none

  type(macropore_continuation_state_t) :: accepted, candidate, retry, restored
  logical :: ok

  call accepted%initialize(2, 3, ok)
  call expect(ok .and. accepted%ready(), 'accepted initialize')

  accepted%icp_bottom_domain = [2, 3]
  accepted%sorptivity = reshape([1,2,3,4,5,6]*1.0_real64,[2,3])
  accepted%theta_sorption_ref = accepted%sorptivity + 10.0_real64
  accepted%absorption_time = accepted%sorptivity + 20.0_real64
  accepted%volume_domain_cp = accepted%sorptivity + 30.0_real64
  accepted%water_domain_cp = accepted%sorptivity + 40.0_real64
  accepted%dynamic_volume_cp = [0.1_real64,0.2_real64,0.3_real64]

  call copy_macropore_continuation_state(accepted, candidate, ok)
  call expect(ok .and. candidate%same_values(accepted), 'candidate clone')

  candidate%icp_bottom_domain(1) = 1
  candidate%sorptivity(1,1) = -101.0_real64
  candidate%theta_sorption_ref(1,1) = -102.0_real64
  candidate%absorption_time(1,1) = -103.0_real64
  candidate%volume_domain_cp(1,1) = -104.0_real64
  candidate%water_domain_cp(1,1) = -105.0_real64
  candidate%dynamic_volume_cp(1) = -106.0_real64

  call expect(accepted%icp_bottom_domain(1) == 2, 'accepted bottom isolated')
  call expect(accepted%sorptivity(1,1) /= candidate%sorptivity(1,1), 'accepted sorptivity isolated')
  call expect(accepted%theta_sorption_ref(1,1) /= candidate%theta_sorption_ref(1,1), 'accepted theta isolated')
  call expect(accepted%absorption_time(1,1) /= candidate%absorption_time(1,1), 'accepted time isolated')
  call expect(accepted%volume_domain_cp(1,1) /= candidate%volume_domain_cp(1,1), 'accepted volume isolated')
  call expect(accepted%water_domain_cp(1,1) /= candidate%water_domain_cp(1,1), 'accepted water isolated')
  call expect(accepted%dynamic_volume_cp(1) /= candidate%dynamic_volume_cp(1), 'accepted dynamic volume isolated')

  ! Reject: throw candidate away, then retry from the unchanged accepted state.
  call candidate%clear()
  call copy_macropore_continuation_state(accepted, retry, ok)
  call expect(ok .and. retry%same_values(accepted), 'retry starts from accepted')
  call expect(retry%dynamic_volume_cp(1) == 0.1_real64, 'rejected history absent')

  ! Accept: atomically deep-copy a fully prepared candidate.
  retry%sorptivity = retry%sorptivity + 0.5_real64
  retry%dynamic_volume_cp = retry%dynamic_volume_cp + 0.05_real64
  call copy_macropore_continuation_state(retry, accepted, ok)
  call expect(ok .and. accepted%same_values(retry), 'accept all seven fields')

  ! Serialization-neutral restart round trip: decoded physical state is a deep copy.
  call copy_macropore_continuation_state(accepted, restored, ok)
  call expect(ok .and. restored%same_values(accepted), 'restart round trip')
  restored%water_domain_cp(1,1) = restored%water_domain_cp(1,1) + 1.0_real64
  call expect(restored%water_domain_cp(1,1) /= accepted%water_domain_cp(1,1), 'restart copy isolated')

  call expect(accepted%payload_bytes() > 0, 'payload accounting')

  print '(a)', 'PPA_WU05A2_TYPE_SHAPE=PASS'
  print '(a)', 'PPA_WU05A2_CANDIDATE_ISOLATION=PASS'
  print '(a)', 'PPA_WU05A2_REJECT_RETRY=PASS'
  print '(a)', 'PPA_WU05A2_ACCEPT_ATOMIC_SEVEN_FIELD_COPY=PASS'
  print '(a)', 'PPA_WU05A2_RESTART_ROUNDTRIP=PASS'
  print '(a)', 'PPA_WU05A2_MACROPORE_STATE_TEST PASS'

contains
  subroutine expect(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,1x,a)') 'PPA_WU05A2_ASSERT_FAIL', trim(label)
      error stop 52
    end if
  end subroutine expect
end program test_ppa_wu05a2_macropore_state
