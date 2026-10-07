module mod_b111_legacy_hydraulic_provider
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  implicit none
  private

  integer, parameter, public :: B111_LEGACY_HYD_OK = 0
  integer, parameter, public :: B111_LEGACY_HYD_INVALID_SHAPE = 1
  integer, parameter, public :: B111_LEGACY_HYD_UNSUPPORTED_MODEL = 2
  integer, parameter, public :: B111_LEGACY_HYD_INVALID_PARAMETERS = 3

  type, extends(constitutive_hydraulics_provider_t), public :: b111_legacy_hydraulic_provider_t
    private
    class(constitutive_hydraulics_provider_t), pointer :: base => null()
    integer, allocatable :: model(:)
    real(real64), allocatable :: cofgen(:,:)
    real(real64) :: step_duration = 0.0_real64
  contains
    procedure :: evaluate => b111_legacy_hydraulic_evaluate
    procedure :: evaluate_water_content_increment => b111_legacy_hydraulic_storage_increment
    procedure :: supports_point_conductivity => b111_legacy_hydraulic_supports_point
    procedure :: evaluate_point_conductivity => b111_legacy_hydraulic_point_conductivity
    procedure, public :: active => b111_legacy_hydraulic_active
  end type b111_legacy_hydraulic_provider_t

  public :: configure_b111_legacy_hydraulic_provider
  public :: bind_b111_legacy_hydraulic_provider

contains

  subroutine configure_b111_legacy_hydraulic_provider(provider, cofgen, model, status)
    type(b111_legacy_hydraulic_provider_t), intent(inout) :: provider
    real(real64), intent(in) :: cofgen(:,:)
    integer, intent(in) :: model(:)
    integer, intent(out) :: status
    integer :: i, n

    nullify(provider%base)
    provider%step_duration = 0.0_real64
    if (allocated(provider%model)) deallocate(provider%model)
    if (allocated(provider%cofgen)) deallocate(provider%cofgen)

    status = B111_LEGACY_HYD_INVALID_SHAPE
    n = size(model)
    if (n <= 0 .or. size(cofgen,2) /= n .or. size(cofgen,1) < 17) return
    if (any(model < 1) .or. any(model > 3)) then
      status = B111_LEGACY_HYD_UNSUPPORTED_MODEL
      return
    end if
    if (.not. all(ieee_is_finite(cofgen))) then
      status = B111_LEGACY_HYD_INVALID_PARAMETERS
      return
    end if

    do i = 1, n
      if (model(i) == 2 .or. model(i) == 3) then
        if (cofgen(2,i) <= cofgen(1,i) .or. cofgen(3,i) <= 0.0_real64 .or. cofgen(4,i) <= 0.0_real64) then
          status = B111_LEGACY_HYD_INVALID_PARAMETERS
          return
        end if
      end if
      if (model(i) == 3) then
        if (cofgen(6,i) <= 1.0_real64 .or. cofgen(13,i) <= 0.0_real64 .or. cofgen(14,i) <= 1.0_real64 .or. &
            cofgen(16,i) <= 0.0_real64 .or. cofgen(16,i) >= 1.0_real64) then
          status = B111_LEGACY_HYD_INVALID_PARAMETERS
          return
        end if
      end if
    end do

    allocate(provider%model(n), provider%cofgen(size(cofgen,1),n))
    provider%model = model
    provider%cofgen = cofgen
    status = B111_LEGACY_HYD_OK
  end subroutine configure_b111_legacy_hydraulic_provider

  subroutine bind_b111_legacy_hydraulic_provider(provider, base, step_duration, status)
    type(b111_legacy_hydraulic_provider_t), intent(inout) :: provider
    class(constitutive_hydraulics_provider_t), target, intent(in) :: base
    real(real64), intent(in) :: step_duration
    integer, intent(out) :: status

    status = B111_LEGACY_HYD_INVALID_SHAPE
    if (.not. allocated(provider%model) .or. .not. allocated(provider%cofgen)) return
    if (size(provider%model) /= size(provider%cofgen,2)) return
    if (.not. ieee_is_finite(step_duration) .or. step_duration <= 0.0_real64) return
    provider%base => base
    provider%step_duration = step_duration
    status = B111_LEGACY_HYD_OK
  end subroutine bind_b111_legacy_hydraulic_provider

  subroutine b111_legacy_hydraulic_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(b111_legacy_hydraulic_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    integer :: i, n
    real(real64) :: floor_capacity

    call require_ready(self, size(pressure_head))
    call self%base%evaluate(pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    n = size(pressure_head)
    floor_capacity = self%step_duration*1.0e-7_real64
    do i = 1, n
      select case (self%model(i))
      case (1)
        cycle
      case (2)
        call evaluate_model2(self%cofgen(:,i), pressure_head(i), water_content(i), conductivity(i), capacity(i))
      case (3)
        call evaluate_model3(self%cofgen(:,i), pressure_head(i), water_content(i), conductivity(i), capacity(i))
      case default
        error stop 'B1.11 legacy hydraulic provider: unsupported configured model'
      end select
      if (pressure_head(i) > -1.0_real64 .and. capacity(i) < floor_capacity) capacity(i) = floor_capacity
      dconductivity_dhead(i) = 0.0_real64
    end do
  end subroutine b111_legacy_hydraulic_evaluate

  subroutine b111_legacy_hydraulic_storage_increment(self, pressure_head, previous_pressure_head, &
                                                       water_content, previous_water_content, increment)
    class(b111_legacy_hydraulic_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:), previous_pressure_head(:)
    real(real64), intent(in) :: water_content(:), previous_water_content(:)
    real(real64), intent(out) :: increment(:)
    integer :: i

    call require_ready(self, size(pressure_head))
    if (size(previous_pressure_head) /= size(pressure_head) .or. size(water_content) /= size(pressure_head) .or. &
        size(previous_water_content) /= size(pressure_head) .or. size(increment) /= size(pressure_head)) &
      error stop 'B1.11 legacy hydraulic provider: storage increment shape mismatch'
    call self%base%evaluate_water_content_increment(pressure_head, previous_pressure_head, water_content, &
         previous_water_content, increment)
    do i = 1, size(increment)
      if (self%model(i) /= 1) increment(i) = water_content(i)-previous_water_content(i)
    end do
  end subroutine b111_legacy_hydraulic_storage_increment

  logical function b111_legacy_hydraulic_supports_point(self) result(supported)
    class(b111_legacy_hydraulic_provider_t), intent(in) :: self
    supported = associated(self%base) .and. allocated(self%model) .and. allocated(self%cofgen)
    if (supported) supported = self%base%supports_point_conductivity()
  end function b111_legacy_hydraulic_supports_point

  subroutine b111_legacy_hydraulic_point_conductivity(self, node_index, pressure_head, water_content, conductivity, available)
    class(b111_legacy_hydraulic_provider_t), intent(in) :: self
    integer, intent(in) :: node_index
    real(real64), intent(in) :: pressure_head, water_content
    real(real64), intent(out) :: conductivity
    logical, intent(out) :: available
    real(real64) :: relsat

    conductivity = 0.0_real64
    available = .false.
    if (.not. associated(self%base) .or. .not. allocated(self%model) .or. .not. allocated(self%cofgen)) return
    if (node_index < 1 .or. node_index > size(self%model)) return
    if (.not. ieee_is_finite(pressure_head) .or. .not. ieee_is_finite(water_content)) return
    select case (self%model(node_index))
    case (1)
      call self%base%evaluate_point_conductivity(node_index, pressure_head, water_content, conductivity, available)
    case (2)
      relsat = (water_content-self%cofgen(1,node_index)) / &
           (self%cofgen(2,node_index)-self%cofgen(1,node_index))
      conductivity = self%cofgen(3,node_index)*relsat
      available = ieee_is_finite(conductivity) .and. conductivity >= 0.0_real64
    case (3)
      call model3_conductivity(self%cofgen(:,node_index), pressure_head, water_content, conductivity)
      available = ieee_is_finite(conductivity) .and. conductivity >= 0.0_real64
    end select
  end subroutine b111_legacy_hydraulic_point_conductivity

  logical function b111_legacy_hydraulic_active(self) result(active)
    class(b111_legacy_hydraulic_provider_t), intent(in) :: self
    active = allocated(self%model)
    if (active) active = any(self%model /= 1)
  end function b111_legacy_hydraulic_active

  subroutine require_ready(self, n)
    class(b111_legacy_hydraulic_provider_t), intent(in) :: self
    integer, intent(in) :: n
    if (.not. associated(self%base)) error stop 'B1.11 legacy hydraulic provider: base not bound'
    if (.not. allocated(self%model) .or. .not. allocated(self%cofgen)) &
      error stop 'B1.11 legacy hydraulic provider: configuration missing'
    if (size(self%model) /= n .or. size(self%cofgen,2) /= n) &
      error stop 'B1.11 legacy hydraulic provider: active-node shape mismatch'
  end subroutine require_ready

  pure subroutine evaluate_model2(c, h, theta, conductivity, capacity)
    real(real64), intent(in) :: c(:), h
    real(real64), intent(out) :: theta, conductivity, capacity
    real(real64) :: relsat

    theta = max(1.0000001_real64*c(1), c(1)+(c(2)-c(1))*exp(c(4)*h))
    capacity = c(4)*(c(2)-c(1))*exp(c(4)*h)
    relsat = (theta-c(1))/(c(2)-c(1))
    conductivity = c(3)*relsat
  end subroutine evaluate_model2

  pure subroutine evaluate_model3(c, h, theta, conductivity, capacity)
    real(real64), intent(in) :: c(:), h
    real(real64), intent(out) :: theta, conductivity, capacity
    real(real64) :: s1, s2, term1, term2, relsat, omega2

    omega2 = 1.0_real64-c(16)
    if (h < 0.0_real64) then
      s1 = (1.0_real64+abs(c(4)*h)**c(6))**(-c(7))
      s2 = (1.0_real64+abs(c(13)*h)**c(14))**(-c(15))
      relsat = c(16)*s1+omega2*s2
      theta = c(1)+(c(2)-c(1))*relsat
      capacity = (c(2)-c(1)) * ( &
           c(16)*c(4)*c(6)*c(7)*(abs(c(4)*h)**(c(6)-1.0_real64)) * &
             (1.0_real64+abs(c(4)*h)**c(6))**(-1.0_real64-c(7)) + &
           omega2*c(13)*c(14)*c(15)*(abs(c(13)*h)**(c(14)-1.0_real64)) * &
             (1.0_real64+abs(c(13)*h)**c(14))**(-1.0_real64-c(15)) )
    else
      theta = c(2)
      capacity = 0.0_real64
      relsat = 1.0_real64
      s1 = 1.0_real64
      s2 = 1.0_real64
    end if

    call model3_conductivity(c, h, theta, conductivity)
  end subroutine evaluate_model3

  pure subroutine model3_conductivity(c, h, theta, conductivity)
    real(real64), intent(in) :: c(:), h, theta
    real(real64), intent(out) :: conductivity
    real(real64) :: s1, s2, term1, term2, relsat, omega2

    omega2 = 1.0_real64-c(16)
    relsat = (theta-c(1))/(c(2)-c(1))
    if (relsat < 1.0_real64) then
      s1 = (1.0_real64+abs(c(4)*h)**c(6))**(-c(7))
      s2 = (1.0_real64+abs(c(13)*h)**c(14))**(-c(15))
      term1 = c(16)*c(4)*(1.0_real64-s1**(1.0_real64/c(7)))**c(7)
      term2 = omega2*c(13)*(1.0_real64-s2**(1.0_real64/c(15)))**c(15)
      conductivity = c(3)*(c(16)*s1+omega2*s2)**c(5) * &
           (1.0_real64-(term1+term2)/(c(16)*c(4)+omega2*c(13)))**2
    else
      conductivity = c(3)
    end if
  end subroutine model3_conductivity

end module mod_b111_legacy_hydraulic_provider
