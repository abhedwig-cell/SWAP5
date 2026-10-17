module mod_b111_linear_table_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  implicit none
  private

  integer, parameter, public :: B111_LINEAR_TABLE_OK = 0
  integer, parameter, public :: B111_LINEAR_TABLE_INVALID = 1
  real(real64), parameter :: HCRIT = -1.0e-2_real64
  real(real64), parameter :: KSMALL = 1.0e-10_real64

  type, public :: b111_linear_table_parameters_t
    integer :: active_nodes = 0
    integer :: n_entries = 0
    real(real64), allocatable :: theta_r(:), theta_s(:), ksat(:), theta_crit(:), c_crit(:)
    real(real64), allocatable :: wc_intercept(:,:), wc_slope(:,:)
    real(real64), allocatable :: cap_intercept(:,:), cap_slope(:,:)
    real(real64), allocatable :: con_intercept(:,:), con_slope(:,:)
  end type b111_linear_table_parameters_t

  type, extends(constitutive_hydraulics_provider_t), public :: b111_linear_table_provider_t
    type(b111_linear_table_parameters_t), pointer, private :: parameters => null()
    real(real64), private :: step_duration = 0.0_real64
  contains
    procedure :: evaluate => linear_eval
    procedure :: supports_point_conductivity => linear_supports_point
    procedure :: evaluate_point_conductivity => linear_point
  end type b111_linear_table_provider_t

  public :: initialize_b111_linear_table_parameters
  public :: bind_b111_linear_table_provider

contains

  subroutine initialize_b111_linear_table_parameters(p, cofgen, wci, wcs, capi, caps, coni, cons, status)
    type(b111_linear_table_parameters_t), intent(out) :: p
    real(real64), intent(in) :: cofgen(:,:), wci(:,:), wcs(:,:), capi(:,:), caps(:,:), coni(:,:), cons(:,:)
    integer, intent(out) :: status
    integer :: n, ne

    status = B111_LINEAR_TABLE_INVALID
    n = size(cofgen,2)
    ne = size(wci,1)
    if (n <= 0 .or. ne < 101 .or. size(cofgen,1) < 27) return
    if (size(wci,2) /= n .or. size(wcs,2) /= n .or. size(capi,2) /= n .or. size(caps,2) /= n .or. &
        size(coni,2) /= n .or. size(cons,2) /= n) return
    if (size(wcs,1) /= ne .or. size(capi,1) /= ne .or. size(caps,1) /= ne .or. &
        size(coni,1) /= ne .or. size(cons,1) /= ne) return
    if (any(.not. ieee_is_finite(cofgen([1,2,3,26,27],:))) .or. any(.not. ieee_is_finite(wci)) .or. &
        any(.not. ieee_is_finite(wcs)) .or. any(.not. ieee_is_finite(capi)) .or. &
        any(.not. ieee_is_finite(caps)) .or. any(.not. ieee_is_finite(coni)) .or. &
        any(.not. ieee_is_finite(cons))) return
    if (any(cofgen(2,:) <= cofgen(1,:)) .or. any(cofgen(3,:) <= 0.0_real64)) return

    p%active_nodes = n
    p%n_entries = ne
    allocate(p%theta_r(n), p%theta_s(n), p%ksat(n), p%theta_crit(n), p%c_crit(n))
    p%theta_r = cofgen(1,:)
    p%theta_s = cofgen(2,:)
    p%ksat = cofgen(3,:)
    p%theta_crit = cofgen(26,:)
    p%c_crit = cofgen(27,:)
    p%wc_intercept = wci
    p%wc_slope = wcs
    p%cap_intercept = capi
    p%cap_slope = caps
    p%con_intercept = coni
    p%con_slope = cons
    status = B111_LINEAR_TABLE_OK
  end subroutine initialize_b111_linear_table_parameters

  subroutine bind_b111_linear_table_provider(provider, p, step_duration, status)
    type(b111_linear_table_provider_t), intent(out) :: provider
    type(b111_linear_table_parameters_t), target, intent(in) :: p
    real(real64), intent(in) :: step_duration
    integer, intent(out) :: status

    status = B111_LINEAR_TABLE_INVALID
    if (p%active_nodes <= 0 .or. p%n_entries < 101 .or. &
        .not. ieee_is_finite(step_duration) .or. step_duration <= 0.0_real64) return
    provider%parameters => p
    provider%step_duration = step_duration
    status = B111_LINEAR_TABLE_OK
  end subroutine bind_b111_linear_table_provider

  subroutine linear_eval(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(b111_linear_table_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    integer :: i

    call require_ready(self,size(pressure_head))
    do i = 1, size(pressure_head)
      call evaluate_one(self,i,pressure_head(i),water_content(i),conductivity(i),capacity(i))
    end do
    dconductivity_dhead = 0.0_real64
  end subroutine linear_eval

  logical function linear_supports_point(self) result(ok)
    class(b111_linear_table_provider_t), intent(in) :: self
    ok = associated(self%parameters)
  end function linear_supports_point

  subroutine linear_point(self, node_index, pressure_head, water_content, conductivity, available)
    class(b111_linear_table_provider_t), intent(in) :: self
    integer, intent(in) :: node_index
    real(real64), intent(in) :: pressure_head, water_content
    real(real64), intent(out) :: conductivity
    logical, intent(out) :: available
    real(real64) :: dummy_theta, dummy_capacity

    conductivity = 0.0_real64
    available = .false.
    if (.not. associated(self%parameters)) return
    if (node_index < 1 .or. node_index > self%parameters%active_nodes) return
    call evaluate_one(self,node_index,pressure_head,dummy_theta,conductivity,dummy_capacity)
    available = ieee_is_finite(conductivity) .and. conductivity >= 0.0_real64
  end subroutine linear_point

  subroutine evaluate_one(self, i, h, theta, k, capacity)
    class(b111_linear_table_provider_t), intent(in) :: self
    integer, intent(in) :: i
    real(real64), intent(in) :: h
    real(real64), intent(out) :: theta, k, capacity
    integer :: j
    real(real64) :: ah, relsat, floor_capacity

    ah = abs(h)
    floor_capacity = self%step_duration*1.0e-7_real64

    if (h >= 0.0_real64) then
      theta = self%parameters%theta_s(i)
      capacity = floor_capacity
      k = self%parameters%ksat(i)
      return
    else if (h > HCRIT) then
      theta = min(self%parameters%theta_crit(i) + self%parameters%c_crit(i)*(h-HCRIT), self%parameters%theta_s(i))
      capacity = max(self%parameters%c_crit(i),floor_capacity)
    else
      j = table_entry(self%parameters%n_entries,h)
      theta = self%parameters%wc_intercept(j,i) + self%parameters%wc_slope(j,i)*ah
      capacity = self%parameters%cap_intercept(j,i) + self%parameters%cap_slope(j,i)*ah
      if (h > -1.0_real64 .and. capacity < floor_capacity) capacity = floor_capacity
    end if

    relsat = (theta-self%parameters%theta_r(i))/(self%parameters%theta_s(i)-self%parameters%theta_r(i))
    if (h < -1.0e14_real64) then
      k = KSMALL
    else if (relsat > 1.0_real64-1.0e-6_real64) then
      k = self%parameters%ksat(i)
    else
      j = table_entry(self%parameters%n_entries,h)
      k = self%parameters%con_intercept(j,i) + self%parameters%con_slope(j,i)*ah
    end if
  end subroutine evaluate_one

  pure integer function table_entry(n_entries, h) result(j)
    integer, intent(in) :: n_entries
    real(real64), intent(in) :: h

    if (h > -1.0_real64) then
      j = min(n_entries,1+int(100.0_real64*abs(h)))
    else
      j = min(n_entries,101+int(100.0_real64*log10(abs(h))))
    end if
  end function table_entry

  subroutine require_ready(self,n)
    class(b111_linear_table_provider_t), intent(in) :: self
    integer, intent(in) :: n
    if (.not. associated(self%parameters) .or. self%parameters%active_nodes /= n) &
      error stop 'B1.11 linear-table provider: shape/binding'
  end subroutine require_ready
end module mod_b111_linear_table_provider
