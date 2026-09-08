from pathlib import Path
import re
import sys

src = Path(sys.argv[1]).read_text()
out = Path(sys.argv[2])
replacement = r'''subroutine tridag(n, a, b, c, r, u, ierror)
  implicit none
  integer, intent(in) :: n
  real(8), intent(in) :: a(*), b(*), c(*), r(*)
  real(8), intent(out) :: u(*)
  integer, intent(out) :: ierror
  integer :: i
  real(8), allocatable :: gam(:)
  real(8) :: bet
  real(8), parameter :: small = 0.3d-37

  ierror = 0
  if (n <= 0) then
    ierror = 1000
    return
  end if
  allocate(gam(n))
  gam = 0.0d0
  if (abs(b(1)) < small) then
    ierror = 1000
    return
  end if
  bet = b(1)
  u(1) = r(1) / bet
  do i = 2, n
    gam(i) = c(i-1) / bet
    bet = b(i) - a(i) * gam(i)
    if (abs(bet) < small) then
      ierror = 1000 + i
      return
    end if
    u(i) = (r(i) - a(i) * u(i-1)) / bet
  end do
  do i = n-1, 1, -1
    u(i) = u(i) - gam(i+1) * u(i+1)
  end do
end subroutine tridag'''

patched, count = re.subn(
    r"subroutine\s+tridag\s*\(.*?end\s+subroutine\s+tridag",
    replacement,
    src,
    count=1,
    flags=re.IGNORECASE | re.DOTALL,
)
if count != 1:
    raise SystemExit(f"expected exactly one tridag stub, replaced {count}")
out.write_text(patched)
print("F-LMFP04_REAL_TRIDIAG_FIXTURE PASS")
