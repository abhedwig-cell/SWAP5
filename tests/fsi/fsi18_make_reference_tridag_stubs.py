#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit('usage: fsi18_make_reference_tridag_stubs.py INPUT_STUBS OUTPUT_STUBS')

src = Path(sys.argv[1])
out = Path(sys.argv[2])
text = src.read_text()

old = '''subroutine tridag(n, upper, main, lower, rhs, solution, ierror)
  implicit none
  integer, intent(in) :: n
  real(8), intent(in) :: upper(*), main(*), lower(*), rhs(*)
  real(8), intent(out) :: solution(*)
  integer, intent(out) :: ierror
  integer :: i
  if (n <= 0 .or. upper(1) > huge(upper(1)) .or. main(1) > huge(main(1)) .or. &
      lower(1) > huge(lower(1)) .or. rhs(1) > huge(rhs(1))) error stop 'invalid tridag arguments'
  do i = 1, n
    solution(i) = 0.0d0
  end do
  ierror = 0
end subroutine tridag
'''

new = '''subroutine tridag(n, upper, main, lower, rhs, solution, ierror)
  ! Test-only reference control. This is the Thomas operation order used by
  ! SWAP 4.3.1 tridag.f90 (VersionID 341, 2017-09-29), adapted only to the
  ! existing F-SI test-stub argument names and automatic scratch sizing.
  implicit none
  integer, intent(in) :: n
  real(8), intent(in) :: upper(*), main(*), lower(*), rhs(*)
  real(8), intent(out) :: solution(*)
  integer, intent(out) :: ierror
  real(8), parameter :: small = 0.3d-37
  real(8) :: gam(n), bet
  integer :: i

  if (n <= 0 .or. upper(1) > huge(upper(1)) .or. main(1) > huge(main(1)) .or. &
      lower(1) > huge(lower(1)) .or. rhs(1) > huge(rhs(1))) error stop 'invalid tridag arguments'
  ierror = 0
  if (abs(main(1)) < small) then
    ierror = 1000
    return
  end if
  bet = main(1)
  solution(1) = rhs(1) / bet
  do i = 2, n
    gam(i) = lower(i-1) / bet
    bet = main(i) - upper(i) * gam(i)
    if (abs(bet) < small) then
      ierror = 1000 + i
      return
    end if
    solution(i) = (rhs(i) - upper(i) * solution(i-1)) / bet
  end do
  do i = n-1, 1, -1
    solution(i) = solution(i) - gam(i+1) * solution(i+1)
  end do
end subroutine tridag
'''

count = text.count(old)
if count != 1:
    raise SystemExit(f'expected exact zero-correction tridag stub once, found {count}')
text = text.replace(old, new, 1)
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(text)
print('FSI18_ZERO_CORRECTION_TRIDAG_REPLACED=PASS')
print('FSI18_REFERENCE_TRIDAG_CONTROL=TEST_ONLY')
print('FSI18_REFERENCE_TRIDAG_OPERATION_ORDER=SWAP_4_3_1_THOMAS')
