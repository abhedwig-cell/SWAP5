module mod_fpe_timeint13_predicted_k_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, &
       CONSTITUTIVE_DEMAND_CONDUCTIVITY, CONSTITUTIVE_DEMAND_DKDH
  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t
  implicit none
  private

  type, extends(constitutive_hydraulics_provider_t), public :: fpe_timeint13_predicted_k_provider_t
    type(b110_default_mvg_provider_t), pointer :: base => null()
    real(real64), allocatable :: predicted_k(:)
  contains
    procedure :: evaluate => timeint13_evaluate
    procedure :: evaluate_demand => timeint13_evaluate_demand
    procedure :: supports_point_conductivity => timeint13_supports_point
    procedure :: evaluate_point_conductivity => timeint13_evaluate_point
  end type

  public :: bind_fpe_timeint13_predicted_k_provider

contains

  subroutine bind_fpe_timeint13_predicted_k_provider(provider, base, predicted_k)
    type(fpe_timeint13_predicted_k_provider_t), intent(out) :: provider
    type(b110_default_mvg_provider_t), target, intent(in) :: base
    real(real64), intent(in) :: predicted_k(:)
    provider%base => base
    if (size(predicted_k) <= 0) error stop 'TIMEINT13 predicted-K provider: empty vector'
    if (any(.not. ieee_is_finite(predicted_k)) .or. any(predicted_k <= 0.0_real64)) &
         error stop 'TIMEINT13 predicted-K provider: invalid conductivity'
    allocate(provider%predicted_k(size(predicted_k)))
    provider%predicted_k = predicted_k
  end subroutine

  subroutine timeint13_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(fpe_timeint13_predicted_k_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)

    call require_bound(self, size(pressure_head))
    call self%base%evaluate(pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    conductivity = self%predicted_k
    dconductivity_dhead = 0.0_real64
  end subroutine

  subroutine timeint13_evaluate_demand(self, pressure_head, demand_mask, water_content, conductivity, capacity, &
                                       dconductivity_dhead)
    class(fpe_timeint13_predicted_k_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    integer, intent(in) :: demand_mask
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)

    call require_bound(self, size(pressure_head))
    call self%base%evaluate_demand(pressure_head, demand_mask, water_content, conductivity, capacity, dconductivity_dhead)
    if (iand(demand_mask, CONSTITUTIVE_DEMAND_CONDUCTIVITY) /= 0) conductivity = self%predicted_k
    if (iand(demand_mask, CONSTITUTIVE_DEMAND_DKDH) /= 0) dconductivity_dhead = 0.0_real64
  end subroutine

  logical function timeint13_supports_point(self) result(supported)
    class(fpe_timeint13_predicted_k_provider_t), intent(in) :: self
    supported = associated(self%base) .and. allocated(self%predicted_k)
  end function

  subroutine timeint13_evaluate_point(self, node_index, pressure_head, water_content, conductivity, available)
    class(fpe_timeint13_predicted_k_provider_t), intent(in) :: self
    integer, intent(in) :: node_index
    real(real64), intent(in) :: pressure_head, water_content
    real(real64), intent(out) :: conductivity
    logical, intent(out) :: available

    conductivity = 0.0_real64
    available = .false.
    if (.not. associated(self%base) .or. .not. allocated(self%predicted_k)) return
    if (node_index < 1 .or. node_index > size(self%predicted_k)) return
    if (.not. ieee_is_finite(pressure_head) .or. .not. ieee_is_finite(water_content)) return
    conductivity = self%predicted_k(node_index)
    available = ieee_is_finite(conductivity) .and. conductivity > 0.0_real64
  end subroutine

  subroutine require_bound(self, n)
    class(fpe_timeint13_predicted_k_provider_t), intent(in) :: self
    integer, intent(in) :: n
    if (.not. associated(self%base)) error stop 'TIMEINT13 predicted-K provider: base not bound'
    if (.not. allocated(self%predicted_k)) error stop 'TIMEINT13 predicted-K provider: K not bound'
    if (size(self%predicted_k) /= n) error stop 'TIMEINT13 predicted-K provider: shape mismatch'
  end subroutine

end module mod_fpe_timeint13_predicted_k_provider
