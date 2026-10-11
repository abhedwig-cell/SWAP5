#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit('usage: fsi37_make_reference_stubs.py INPUT_STUBS OUTPUT_STUBS')

src = Path(sys.argv[1])
out = Path(sys.argv[2])
text = src.read_text()

# First materialize the exact SWAP 4.3.1 Thomas TRIDAG operation order used by
# the existing F-SI18 scientific replay. This is test-only oracle material.
old_tridag = '''subroutine tridag(n, upper, main, lower, rhs, solution, ierror)
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
new_tridag = '''subroutine tridag(n, upper, main, lower, rhs, solution, ierror)
  ! Test-only reference control. Operation order follows SWAP 4.3.1 tridag.f90.
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
if text.count(old_tridag) != 1:
    raise SystemExit(f'expected exact zero-correction tridag stub once, found {text.count(old_tridag)}')
text = text.replace(old_tridag, new_tridag, 1)

# F-SI04 intentionally used arithmetic hcomean for every method because older
# gates did not qualify conductivity-mean semantics. F-SI37 does. Replace only
# the test stub by the exact SWAP 4.3.1 functions.f90 algebra for methods 1..6.
# Frozen historical evidence used during F-SI37 derivation:
#   SWAP.ZIP sha256 1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151
#   SWAP/functions.f90 sha256 b32dee127747e619cb92965d0473173ec7fd93c56128a0dbd5ebf5942c300527
old_mean = '''real(8) function hcomean(method, kup, klow, dzup, dzlow, node, hup, hlow)
  implicit none
  integer, intent(in) :: method, node
  real(8), intent(in) :: kup, klow, dzup, dzlow, hup, hlow
  if (method < 0 .or. node < 1 .or. dzup <= 0.0d0 .or. dzlow <= 0.0d0 .or. &
      hup > huge(hup) .or. hlow > huge(hlow)) error stop 'invalid hcomean arguments'
  hcomean = 0.5d0*(kup+klow)
end function hcomean
'''
new_mean = '''real(8) function hcomean(method, kup, klow, dzup, dzlow, node, hup, hlow)
  implicit none
  integer, intent(in) :: method, node
  real(8), intent(in) :: kup, klow, dzup, dzlow, hup, hlow
  real(8) :: a1, a2
  if (method < 1 .or. method > 6 .or. node < 0 .or. dzup <= 0.0d0 .or. dzlow <= 0.0d0 .or. &
      hup > huge(hup) .or. hlow > huge(hlow)) error stop 'invalid hcomean arguments'
  select case (method)
  case (1)
    hcomean = 0.5d0*(kup+klow)
  case (2)
    hcomean = (dzup*kup + dzlow*klow)/(dzup+dzlow)
  case (3)
    hcomean = sqrt(kup*klow)
  case (4)
    a1 = dzup/(dzup+dzlow)
    a2 = 1.0d0-a1
    hcomean = kup**a1 * klow**a2
  case (5)
    hcomean = 1.0d0/(0.5d0/kup + 0.5d0/klow)
  case (6)
    a1 = dzup/(dzup+dzlow)
    a2 = 1.0d0-a1
    hcomean = 1.0d0/(a1/kup + a2/klow)
  end select
end function hcomean
'''
if text.count(old_mean) != 1:
    raise SystemExit(f'expected exact F-SI04 arithmetic hcomean stub once, found {text.count(old_mean)}')
text = text.replace(old_mean, new_mean, 1)

out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(text)
print('FSI37_REFERENCE_TRIDAG_CONTROL=PASS')
print('FSI37_REFERENCE_HCOMEAN_METHODS_1_6=PASS')
print('FSI37_REFERENCE_STUBS=TEST_ONLY')
