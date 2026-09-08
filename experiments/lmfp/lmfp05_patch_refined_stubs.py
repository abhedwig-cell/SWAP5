from pathlib import Path
import re
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: lmfp05_patch_refined_stubs.py INPUT_STUBS OUTPUT_STUBS")

src = Path(sys.argv[1]).read_text()
out = Path(sys.argv[2])

arrays_module = r'''module MOD_arrays
  implicit none
  integer, parameter :: macp = 64
  integer, parameter :: mabbc = 4
end module MOD_arrays'''

src, count = re.subn(
    r"module\s+MOD_arrays.*?end\s+module\s+MOD_arrays",
    arrays_module,
    src,
    count=1,
    flags=re.IGNORECASE | re.DOTALL,
)
if count != 1:
    raise SystemExit(f"expected one MOD_arrays module, replaced {count}")

grid_module = r'''module MOD_grid
  implicit none
  integer, parameter :: numnod = 64
  real(8) :: z(numnod) = 0.0d0
  real(8) :: dz(numnod) = 1.0d0
  real(8) :: disnod(numnod+1) = 1.0d0
end module MOD_grid'''

src, count = re.subn(
    r"module\s+MOD_grid.*?end\s+module\s+MOD_grid",
    grid_module,
    src,
    count=1,
    flags=re.IGNORECASE | re.DOTALL,
)
if count != 1:
    raise SystemExit(f"expected one MOD_grid module, replaced {count}")

tridag = r'''subroutine tridag(n, a, b, c, r, u, ierror)
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

src, count = re.subn(
    r"subroutine\s+tridag\s*\(.*?end\s+subroutine\s+tridag",
    tridag,
    src,
    count=1,
    flags=re.IGNORECASE | re.DOTALL,
)
if count != 1:
    raise SystemExit(f"expected one tridag stub, replaced {count}")

hcomean = r'''real(8) function hcomean(method, kup, klow, dzup, dzlow, node, hup, hlow)
  implicit none
  integer, intent(in) :: method, node
  real(8), intent(in) :: kup, klow, dzup, dzlow, hup, hlow
  if (method /= 1) error stop 'F-LMFP05 refined fixture admits SWKMEAN=1 only'
  if (node < 0 .or. dzup <= 0.0d0 .or. dzlow <= 0.0d0 .or. &
      hup > huge(hup) .or. hlow > huge(hlow)) error stop 'invalid hcomean arguments'
  hcomean = 0.5d0*(kup+klow)
end function hcomean'''

src, count = re.subn(
    r"real\(8\)\s+function\s+hcomean\s*\(.*?end\s+function\s+hcomean",
    hcomean,
    src,
    count=1,
    flags=re.IGNORECASE | re.DOTALL,
)
if count != 1:
    raise SystemExit(f"expected one hcomean stub, replaced {count}")

out.write_text(src)
print("F-LMFP05_REFINED_STUB_FIXTURE PASS")
