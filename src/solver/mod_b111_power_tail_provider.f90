module mod_b111_power_tail_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  implicit none
  private

  integer, parameter, public :: B111_POWER_OK = 0
  integer, parameter, public :: B111_POWER_INVALID = 1

  type, extends(constitutive_hydraulics_provider_t), public :: b111_power_tail_provider_t
    class(constitutive_hydraulics_provider_t), pointer, private :: base => null()
    logical, allocatable, private :: active(:)
    real(real64), allocatable, private :: h_power(:), k_power(:), exponent(:)
  contains
    procedure :: evaluate => power_evaluate
    procedure :: supports_point_conductivity => power_supports_point
    procedure :: evaluate_point_conductivity => power_point
    procedure, public :: enabled => power_enabled
  end type

  public :: configure_b111_power_tail_provider
  public :: bind_b111_power_tail_provider

contains

  subroutine configure_b111_power_tail_provider(provider, active, cofgen, status)
    type(b111_power_tail_provider_t), intent(inout) :: provider
    logical, intent(in) :: active(:)
    real(real64), intent(in) :: cofgen(:,:)
    integer, intent(out) :: status
    integer :: i, n

    nullify(provider%base)
    if (allocated(provider%active)) deallocate(provider%active,provider%h_power,provider%k_power,provider%exponent)
    status=B111_POWER_INVALID
    n=size(active)
    if (n<=0 .or. size(cofgen,1)<33 .or. size(cofgen,2)/=n) return
    allocate(provider%active(n),provider%h_power(n),provider%k_power(n),provider%exponent(n))
    provider%active=active
    provider%h_power=cofgen(22,:)
    provider%k_power=cofgen(23,:)
    provider%exponent=cofgen(33,:)
    do i=1,n
      if (.not.provider%active(i)) cycle
      if (.not.ieee_is_finite(provider%h_power(i)) .or. provider%h_power(i)>=0.0_real64 .or. &
          .not.ieee_is_finite(provider%k_power(i)) .or. provider%k_power(i)<=0.0_real64 .or. &
          .not.ieee_is_finite(provider%exponent(i)) .or. provider%exponent(i)<=0.0_real64) return
    end do
    status=B111_POWER_OK
  end subroutine

  subroutine bind_b111_power_tail_provider(provider,base,status)
    type(b111_power_tail_provider_t),intent(inout)::provider
    class(constitutive_hydraulics_provider_t),target,intent(in)::base
    integer,intent(out)::status
    status=B111_POWER_INVALID
    if (.not.allocated(provider%active)) return
    provider%base=>base
    status=B111_POWER_OK
  end subroutine

  subroutine power_evaluate(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(b111_power_tail_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:)
    real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    integer::i
    if (.not.associated(self%base) .or. .not.allocated(self%active)) error stop 'B1.11 power tail: not bound'
    if (size(pressure_head)/=size(self%active)) error stop 'B1.11 power tail: shape mismatch'
    call self%base%evaluate(pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    do i=1,size(self%active)
      if (self%active(i) .and. pressure_head(i)<=self%h_power(i)) then
        conductivity(i)=self%k_power(i)*(abs(self%h_power(i))/abs(pressure_head(i)))**self%exponent(i)
        dconductivity_dhead(i)=conductivity(i)*self%exponent(i)/abs(pressure_head(i))
      end if
    end do
  end subroutine

  logical function power_supports_point(self) result(ok)
    class(b111_power_tail_provider_t),intent(in)::self
    ok=associated(self%base) .and. allocated(self%active)
    if(ok) ok=self%base%supports_point_conductivity()
  end function

  subroutine power_point(self,node_index,pressure_head,water_content,conductivity,available)
    class(b111_power_tail_provider_t),intent(in)::self
    integer,intent(in)::node_index
    real(real64),intent(in)::pressure_head,water_content
    real(real64),intent(out)::conductivity
    logical,intent(out)::available
    conductivity=0.0_real64;available=.false.
    if(.not.associated(self%base) .or. .not.allocated(self%active)) return
    if(node_index<1 .or. node_index>size(self%active)) return
    call self%base%evaluate_point_conductivity(node_index,pressure_head,water_content,conductivity,available)
    if(.not.available) return
    if(self%active(node_index) .and. pressure_head<=self%h_power(node_index)) then
      conductivity=self%k_power(node_index)*(abs(self%h_power(node_index))/abs(pressure_head))**self%exponent(node_index)
      available=ieee_is_finite(conductivity) .and. conductivity>=0.0_real64
    end if
  end subroutine

  logical function power_enabled(self) result(on)
    class(b111_power_tail_provider_t),intent(in)::self
    on=allocated(self%active)
    if(on) on=any(self%active)
  end function
end module
