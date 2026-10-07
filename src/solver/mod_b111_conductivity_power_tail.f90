module mod_b111_conductivity_power_tail
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, &
       CONSTITUTIVE_DEMAND_CONDUCTIVITY, CONSTITUTIVE_DEMAND_DKDH
  implicit none
  private

  integer, parameter, public :: B111_POWER_OK = 0
  integer, parameter, public :: B111_POWER_INVALID = 1
  real(real64), parameter :: B111_POWER_DRY_GUARD_CM = -1.0e14_real64
  real(real64), parameter :: B111_POWER_DRY_K_CM_PER_DAY = 1.0e-10_real64

  type, extends(constitutive_hydraulics_provider_t), public :: b111_conductivity_power_tail_t
    private
    class(constitutive_hydraulics_provider_t), pointer :: base => null()
    real(real64), allocatable :: h_power(:)
    real(real64), allocatable :: k_power(:)
    real(real64), allocatable :: exponent(:)
  contains
    procedure :: evaluate => power_evaluate
    procedure :: evaluate_demand => power_evaluate_demand
    procedure :: evaluate_water_content_increment => power_storage_increment
    procedure :: supports_point_conductivity => power_supports_point
    procedure :: evaluate_point_conductivity => power_point_conductivity
    procedure, public :: active_nodes => power_active_nodes
  end type b111_conductivity_power_tail_t

  public :: configure_b111_conductivity_power_tail
  public :: bind_b111_conductivity_power_tail

contains

  subroutine configure_b111_conductivity_power_tail(provider, cofgen, status)
    type(b111_conductivity_power_tail_t), intent(inout) :: provider
    real(real64), intent(in) :: cofgen(:,:)
    integer, intent(out) :: status
    integer :: n

    nullify(provider%base)
    if (allocated(provider%h_power)) deallocate(provider%h_power)
    if (allocated(provider%k_power)) deallocate(provider%k_power)
    if (allocated(provider%exponent)) deallocate(provider%exponent)
    status = B111_POWER_INVALID
    n=size(cofgen,2)
    if (n<=0 .or. size(cofgen,1)<33) return
    if (any(.not.ieee_is_finite(cofgen([22,23,33],:)))) return
    if (any(cofgen(22,:)>=0.0_real64) .or. any(cofgen(23,:)<=0.0_real64)) return
    allocate(provider%h_power(n),provider%k_power(n),provider%exponent(n))
    provider%h_power=cofgen(22,:)
    provider%k_power=cofgen(23,:)
    provider%exponent=cofgen(33,:)
    status=B111_POWER_OK
  end subroutine configure_b111_conductivity_power_tail

  subroutine bind_b111_conductivity_power_tail(provider,base,status)
    type(b111_conductivity_power_tail_t), intent(inout) :: provider
    class(constitutive_hydraulics_provider_t), target, intent(in) :: base
    integer,intent(out)::status
    status=B111_POWER_INVALID
    if(.not.allocated(provider%h_power).or..not.allocated(provider%k_power).or. &
       .not.allocated(provider%exponent))return
    provider%base=>base
    status=B111_POWER_OK
  end subroutine bind_b111_conductivity_power_tail

  subroutine power_evaluate(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(b111_conductivity_power_tail_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:)
    real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    integer::i
    call require_ready(self,size(pressure_head))
    call self%base%evaluate(pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    do i=1,size(pressure_head)
      call apply_power(self,i,pressure_head(i),conductivity(i))
      ! SW431-HYD-POWER is qualified first for the existing K0 numerical route.
      dconductivity_dhead(i)=0.0_real64
    end do
  end subroutine power_evaluate

  subroutine power_evaluate_demand(self,pressure_head,demand_mask,water_content,conductivity,capacity,dconductivity_dhead)
    class(b111_conductivity_power_tail_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:)
    integer,intent(in)::demand_mask
    real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    integer::i
    call require_ready(self,size(pressure_head))
    call self%base%evaluate_demand(pressure_head,demand_mask,water_content,conductivity,capacity,dconductivity_dhead)
    if(iand(demand_mask,CONSTITUTIVE_DEMAND_CONDUCTIVITY)/=0)then
      do i=1,size(pressure_head)
        call apply_power(self,i,pressure_head(i),conductivity(i))
      end do
    end if
    if(iand(demand_mask,CONSTITUTIVE_DEMAND_DKDH)/=0)dconductivity_dhead=0.0_real64
  end subroutine power_evaluate_demand

  subroutine power_storage_increment(self,pressure_head,previous_pressure_head,water_content,previous_water_content,increment)
    class(b111_conductivity_power_tail_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:),previous_pressure_head(:),water_content(:),previous_water_content(:)
    real(real64),intent(out)::increment(:)
    call require_ready(self,size(pressure_head))
    call self%base%evaluate_water_content_increment(pressure_head,previous_pressure_head,water_content, &
         previous_water_content,increment)
  end subroutine power_storage_increment

  logical function power_supports_point(self)result(supported)
    class(b111_conductivity_power_tail_t),intent(in)::self
    supported=associated(self%base).and.allocated(self%h_power)
    if(supported)supported=self%base%supports_point_conductivity()
  end function power_supports_point

  subroutine power_point_conductivity(self,node_index,pressure_head,water_content,conductivity,available)
    class(b111_conductivity_power_tail_t),intent(in)::self
    integer,intent(in)::node_index
    real(real64),intent(in)::pressure_head,water_content
    real(real64),intent(out)::conductivity
    logical,intent(out)::available
    call self%base%evaluate_point_conductivity(node_index,pressure_head,water_content,conductivity,available)
    if(.not.available)return
    if(node_index<1.or.node_index>size(self%h_power))then
      available=.false.;conductivity=0.0_real64;return
    end if
    call apply_power(self,node_index,pressure_head,conductivity)
    available=ieee_is_finite(conductivity).and.conductivity>=0.0_real64
  end subroutine power_point_conductivity

  integer function power_active_nodes(self)result(n)
    class(b111_conductivity_power_tail_t),intent(in)::self
    n=0
    if(allocated(self%h_power))n=size(self%h_power)
  end function power_active_nodes

  subroutine apply_power(self,i,h,k)
    class(b111_conductivity_power_tail_t),intent(in)::self
    integer,intent(in)::i
    real(real64),intent(in)::h
    real(real64),intent(inout)::k
    if(h<B111_POWER_DRY_GUARD_CM)then
      k=B111_POWER_DRY_K_CM_PER_DAY
    else if(h<=self%h_power(i))then
      k=self%k_power(i)*(abs(self%h_power(i))/abs(h))**self%exponent(i)
    end if
  end subroutine apply_power

  subroutine require_ready(self,n)
    class(b111_conductivity_power_tail_t),intent(in)::self
    integer,intent(in)::n
    if(.not.associated(self%base))error stop 'B1.11 power-tail provider: base not bound'
    if(.not.allocated(self%h_power).or.size(self%h_power)/=n) &
      error stop 'B1.11 power-tail provider: shape mismatch'
  end subroutine require_ready
end module mod_b111_conductivity_power_tail
