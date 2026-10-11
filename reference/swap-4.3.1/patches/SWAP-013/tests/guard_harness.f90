program swap013_guard_harness
  implicit none
  integer :: failures
  failures = 0

  call expect_guard(8,  1.0d4,    1.0d6, .false., 'valid model8')
  call expect_guard(9,  1.0d0,    1.0d5, .false., 'valid model9')
  call expect_guard(10, 9.9999d4, 1.0d5, .false., 'valid model10 near upper')
  call expect_guard(11, 1.0d-30,  1.0d5, .false., 'valid model11 positive')
  call expect_guard(8,  0.0d0,    1.0d5, .true.,  'HA zero')
  call expect_guard(8,  1.0d5,    1.0d5, .true.,  'HA equals H0')
  call expect_guard(11, 2.0d5,    1.0d5, .true.,  'HA greater H0')
  call expect_guard(7,  0.0d0,    1.0d5, .false., 'non-PDI model7 unaffected')
  call expect_guard(12, 0.0d0,    1.0d5, .false., 'non-PDI model12 unaffected')

  if (failures /= 0) then
     write(*,'(a,i0)') 'SWAP-013 GUARD FAILURES=', failures
     error stop 2
  end if
  write(*,'(a)') 'SWAP-013_GUARD_HARNESS PASS 9/9'

contains
  logical function rejected(model,ha,h0)
    integer, intent(in) :: model
    real(8), intent(in) :: ha,h0
    rejected = .false.
    if (model >= 8 .and. model <= 11) then
       if (ha <= 0.0d0 .or. ha >= h0) rejected = .true.
    end if
  end function rejected

  subroutine expect_guard(model,ha,h0,expected,label)
    integer, intent(in) :: model
    real(8), intent(in) :: ha,h0
    logical, intent(in) :: expected
    character(*), intent(in) :: label
    logical :: got
    got = rejected(model,ha,h0)
    if (got .neqv. expected) then
       failures = failures + 1
       write(*,'(a,1x,a)') 'FAIL', trim(label)
    end if
  end subroutine expect_guard
end program swap013_guard_harness
