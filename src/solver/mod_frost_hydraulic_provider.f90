module mod_frost_hydraulic_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, &
       CONSTITUTIVE_DEMAND_CONDUCTIVITY, CONSTITUTIVE_DEMAND_DKDH
  use mod_frost_hydraulic_effect, only: FROST_LEGACY_RESIDUAL_K_CM_PER_DAY, &
       apply_frost_hydraulic_conductivity, FROST_EFFECT_OK
  implicit none
  private

  integer, parameter, public :: FROST_PROVIDER_OK = 0
  integer, parameter, public :: FROST_PROVIDER_INVALID_BASE = 1
  integer, parameter, public :: FROST_PROVIDER_INVALID_FACTOR = 2

  type, extends(constitutive_hydraulics_provider_t), public :: frost_constitutive_provider_t
    class(constitutive_hydraulics_provider_t), pointer, private :: base => null()
    real(real64), allocatable, private :: factor(:)
  contains
    procedure :: evaluate => frost_constitutive_evaluate
    procedure :: evaluate_demand => frost_constitutive_evaluate_demand
    procedure :: evaluate_water_content_increment => frost_constitutive_storage_increment
    procedure :: supports_point_conductivity => frost_constitutive_supports_point
    procedure :: evaluate_point_conductivity => frost_constitutive_point_conductivity
    procedure, public :: active_nodes => frost_constitutive_active_nodes
  end type frost_constitutive_provider_t

  public :: bind_frost_constitutive_provider

contains

  subroutine bind_frost_constitutive_provider(provider, base, factor, status)
    type(frost_constitutive_provider_t), intent(inout) :: provider
    class(constitutive_hydraulics_provider_t), target, intent(in) :: base
    real(real64), intent(in) :: factor(:)
    integer, intent(out) :: status
    integer :: i

    status = FROST_PROVIDER_INVALID_BASE
    if (size(factor) <= 0) return
    status = FROST_PROVIDER_INVALID_FACTOR
    do i = 1, size(factor)
      if (.not. ieee_is_finite(factor(i)) .or. factor(i) < 0.0_real64 .or. factor(i) > 1.0_real64) return
    end do
    provider%base => base
    if (allocated(provider%factor)) deallocate(provider%factor)
    provider%factor = factor
    status = FROST_PROVIDER_OK
  end subroutine bind_frost_constitutive_provider

  subroutine frost_constitutive_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(frost_constitutive_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    integer :: status

    call require_bound_shape(self, size(pressure_head))
    call self%base%evaluate(pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    call apply_frost_hydraulic_conductivity(self%factor, conductivity, dconductivity_dhead, status)
    if (status /= FROST_EFFECT_OK) error stop 'frost constitutive provider: invalid hydraulic result'
  end subroutine frost_constitutive_evaluate

  subroutine frost_constitutive_evaluate_demand(self, pressure_head, demand_mask, water_content, conductivity, &
                                                 capacity, dconductivity_dhead)
    class(frost_constitutive_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    integer, intent(in) :: demand_mask
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    integer :: i

    call require_bound_shape(self, size(pressure_head))
    call self%base%evaluate_demand(pressure_head, demand_mask, water_content, conductivity, capacity, &
         dconductivity_dhead)
    if (iand(demand_mask, CONSTITUTIVE_DEMAND_CONDUCTIVITY) /= 0) then
      if (size(conductivity) /= size(self%factor)) error stop 'frost constitutive provider: conductivity shape mismatch'
      do i = 1, size(self%factor)
        if (.not. ieee_is_finite(conductivity(i)) .or. conductivity(i) < 0.0_real64) &
             error stop 'frost constitutive provider: invalid conductivity'
      end do
      conductivity = conductivity*self%factor + FROST_LEGACY_RESIDUAL_K_CM_PER_DAY*(1.0_real64-self%factor)
    end if
    if (iand(demand_mask, CONSTITUTIVE_DEMAND_DKDH) /= 0) then
      if (size(dconductivity_dhead) /= size(self%factor)) &
           error stop 'frost constitutive provider: derivative shape mismatch'
      if (any(.not. ieee_is_finite(dconductivity_dhead))) &
           error stop 'frost constitutive provider: invalid conductivity derivative'
      dconductivity_dhead = dconductivity_dhead*self%factor
    end if
  end subroutine frost_constitutive_evaluate_demand

  subroutine frost_constitutive_storage_increment(self, pressure_head, previous_pressure_head, &
                                                    water_content, previous_water_content, increment)
    class(frost_constitutive_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:), previous_pressure_head(:)
    real(real64), intent(in) :: water_content(:), previous_water_content(:)
    real(real64), intent(out) :: increment(:)

    call require_bound_shape(self, size(pressure_head))
    call self%base%evaluate_water_content_increment(pressure_head, previous_pressure_head, water_content, &
         previous_water_content, increment)
  end subroutine frost_constitutive_storage_increment

  logical function frost_constitutive_supports_point(self) result(supported)
    class(frost_constitutive_provider_t), intent(in) :: self
    supported = associated(self%base) .and. allocated(self%factor)
    if (supported) supported = self%base%supports_point_conductivity()
  end function frost_constitutive_supports_point

  subroutine frost_constitutive_point_conductivity(self, node_index, pressure_head, water_content, conductivity, available)
    class(frost_constitutive_provider_t), intent(in) :: self
    integer, intent(in) :: node_index
    real(real64), intent(in) :: pressure_head, water_content
    real(real64), intent(out) :: conductivity
    logical, intent(out) :: available
    real(real64) :: base_conductivity

    conductivity = 0.0_real64
    available = .false.
    if (.not. self%supports_point_conductivity()) return
    if (node_index < 1 .or. node_index > size(self%factor)) return
    call self%base%evaluate_point_conductivity(node_index, pressure_head, water_content, base_conductivity, available)
    if (.not. available) return
    if (.not. ieee_is_finite(base_conductivity) .or. base_conductivity < 0.0_real64) then
      available = .false.
      return
    end if
    conductivity = base_conductivity*self%factor(node_index) + &
         FROST_LEGACY_RESIDUAL_K_CM_PER_DAY*(1.0_real64-self%factor(node_index))
  end subroutine frost_constitutive_point_conductivity

  integer function frost_constitutive_active_nodes(self) result(n)
    class(frost_constitutive_provider_t), intent(in) :: self
    n = 0
    if (allocated(self%factor)) n = size(self%factor)
  end function frost_constitutive_active_nodes

  subroutine require_bound_shape(self, n)
    class(frost_constitutive_provider_t), intent(in) :: self
    integer, intent(in) :: n
    if (.not. associated(self%base)) error stop 'frost constitutive provider: base is not bound'
    if (.not. allocated(self%factor)) error stop 'frost constitutive provider: factor is not bound'
    if (n /= size(self%factor)) error stop 'frost constitutive provider: active-node shape mismatch'
  end subroutine require_bound_shape

end module mod_frost_hydraulic_provider
