module mod_fmr_legacy_head_bottom_boundary_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: FMR_HBOT5_OK = 0, FMR_HBOT5_INVALID_CONTROL = 1, FMR_HBOT5_INVALID_PROPOSAL = 2

  type, public :: fmr_hbot5_proposal_t
    logical :: available = .false.
    real(real64) :: t0 = 0.0_real64, original_t1 = 0.0_real64
    real(real64) :: legacy_sample_t1900 = 0.0_real64, pressure_head_cm = 0.0_real64
  contains
    procedure :: covers => hbot5_proposal_covers
  end type

  type, public :: fmr_hbot5_control_t
    private
    logical :: initialized = .false.
    real(real64) :: canonical_origin = 0.0_real64, legacy_origin = 0.0_real64
    real(real64) :: simulation_t0 = 0.0_real64, simulation_t1 = 0.0_real64
    real(real64), allocatable :: dates(:), heads(:)
  contains
    procedure :: initialize => hbot5_initialize
    procedure :: ready => hbot5_ready
    procedure :: resolve => hbot5_resolve
  end type

contains

  subroutine hbot5_initialize(self, dates, heads, canonical_origin, legacy_origin, simulation_t0, simulation_t1, status)
    class(fmr_hbot5_control_t), intent(inout) :: self
    real(real64), intent(in) :: dates(:), heads(:), canonical_origin, legacy_origin, simulation_t0, simulation_t1
    integer, intent(out) :: status
    real(real64) :: start1900, end1900
    logical :: covered
    integer :: n
    self%initialized = .false.
    if (allocated(self%dates)) deallocate(self%dates)
    if (allocated(self%heads)) deallocate(self%heads)
    status = FMR_HBOT5_INVALID_CONTROL
    n = size(dates)
    if (n <= 0 .or. size(heads) /= n) return
    if (.not. all(ieee_is_finite(dates)) .or. .not. all(ieee_is_finite(heads))) return
    if (any(heads < -1.0e10_real64) .or. any(heads > 1000.0_real64)) return
    if (n > 1) then
      if (any(dates(2:n) <= dates(1:n-1))) return
    end if
    if (.not. ieee_is_finite(canonical_origin) .or. .not. ieee_is_finite(legacy_origin)) return
    if (.not. ieee_is_finite(simulation_t0) .or. .not. ieee_is_finite(simulation_t1)) return
    if (simulation_t1 <= simulation_t0) return
    start1900 = legacy_origin + (simulation_t0-canonical_origin)
    end1900 = legacy_origin + (simulation_t1-canonical_origin)
    if (.not. ieee_is_finite(start1900) .or. .not. ieee_is_finite(end1900)) return
    covered = any(dates > start1900-1.0e-6_real64 .and. dates < end1900+1.0e-6_real64)
    if (.not. covered) covered = dates(1) < start1900+1.0e-6_real64 .and. dates(n) > end1900-1.0e-6_real64
    if (.not. covered) return
    self%dates = dates
    self%heads = heads
    self%canonical_origin = canonical_origin
    self%legacy_origin = legacy_origin
    self%simulation_t0 = simulation_t0
    self%simulation_t1 = simulation_t1
    self%initialized = .true.
    status = FMR_HBOT5_OK
  end subroutine

  logical function hbot5_ready(self) result(ready)
    class(fmr_hbot5_control_t), intent(in) :: self
    ready = self%initialized
  end function

  subroutine hbot5_resolve(self, t0, t1, proposal, status)
    class(fmr_hbot5_control_t), intent(in) :: self
    real(real64), intent(in) :: t0, t1
    type(fmr_hbot5_proposal_t), intent(out) :: proposal
    integer, intent(out) :: status
    real(real64) :: x, head, slope
    integer :: i, n
    proposal = fmr_hbot5_proposal_t()
    status = FMR_HBOT5_INVALID_CONTROL
    if (.not. self%ready()) return
    status = FMR_HBOT5_INVALID_PROPOSAL
    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1)) return
    if (t1 <= t0 .or. t0 < self%simulation_t0 .or. t1 > self%simulation_t1) return
    x = self%legacy_origin + (t1-self%canonical_origin)
    if (.not. ieee_is_finite(x)) return
    n = size(self%dates)
    head = self%heads(n)
    if (x <= self%dates(1)) then
      head = self%heads(1)
    else
      do i = 2, n
        if (self%dates(i) >= x) then
          slope = (self%heads(i)-self%heads(i-1))/(self%dates(i)-self%dates(i-1))
          head = self%heads(i-1)+(x-self%dates(i-1))*slope
          exit
        end if
      end do
    end if
    if (.not. ieee_is_finite(head)) return
    proposal%t0 = t0
    proposal%original_t1 = t1
    proposal%legacy_sample_t1900 = x
    proposal%pressure_head_cm = head
    proposal%available = .true.
    status = FMR_HBOT5_OK
  end subroutine

  logical function hbot5_proposal_covers(self, t0, t1) result(covers)
    class(fmr_hbot5_proposal_t), intent(in) :: self
    real(real64), intent(in) :: t0, t1
    covers = .false.
    if (.not. self%available) return
    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1)) return
    if (.not. ieee_is_finite(self%pressure_head_cm) .or. .not. ieee_is_finite(self%t0) .or. &
        .not. ieee_is_finite(self%original_t1) .or. .not. ieee_is_finite(self%legacy_sample_t1900)) return
    covers = t1 > t0 .and. t0 >= self%t0 .and. t1 <= self%original_t1
  end function
end module
