module mod_fpe_elastic01_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, &
       CONSTITUTIVE_DEMAND_WATER_CONTENT, CONSTITUTIVE_DEMAND_CONDUCTIVITY, &
       CONSTITUTIVE_DEMAND_CAPACITY, CONSTITUTIVE_DEMAND_DKDH
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       bind_b110_default_mvg_provider
  implicit none
  private

  type, extends(constitutive_hydraulics_provider_t), public :: fpe_elastic01_provider_t
     type(b110_default_mvg_parameters_t), pointer :: parameters => null()
     real(real64) :: step_duration = 0.0_real64
     real(real64) :: regularization_coefficient = 0.0_real64
   contains
     procedure :: evaluate => elastic_evaluate
     procedure :: evaluate_demand => elastic_evaluate_demand
     procedure :: supports_point_conductivity => elastic_supports_point_conductivity
     procedure :: evaluate_point_conductivity => elastic_evaluate_point_conductivity
  end type fpe_elastic01_provider_t

  public :: bind_fpe_elastic01_provider

contains

  subroutine bind_fpe_elastic01_provider(provider, parameters, step_duration, coefficient)
    type(fpe_elastic01_provider_t), intent(out) :: provider
    type(b110_default_mvg_parameters_t), target, intent(in) :: parameters
    real(real64), intent(in) :: step_duration, coefficient
    if (parameters%active_nodes <= 0 .or. .not. allocated(parameters%cofgen)) &
         error stop 'F-PE-ELASTIC01: invalid parameter set'
    if (step_duration <= 0.0_real64) error stop 'F-PE-ELASTIC01: step_duration must be positive'
    if (coefficient < 0.0_real64) error stop 'F-PE-ELASTIC01: coefficient must be nonnegative'
    provider%parameters => parameters
    provider%step_duration = step_duration
    provider%regularization_coefficient = coefficient
  end subroutine bind_fpe_elastic01_provider

  subroutine elastic_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(fpe_elastic01_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    type(b110_default_mvg_provider_t) :: base
    integer :: i
    call require_bound(self)
    call bind_b110_default_mvg_provider(base, self%parameters, self%step_duration)
    call base%evaluate(pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    do i=1,size(pressure_head)
      capacity(i)=regularized_capacity(self%parameters%cofgen(:,i), pressure_head(i), &
           self%step_duration, self%regularization_coefficient)
    end do
  end subroutine elastic_evaluate

  subroutine elastic_evaluate_demand(self, pressure_head, demand_mask, water_content, conductivity, capacity, dconductivity_dhead)
    class(fpe_elastic01_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    integer, intent(in) :: demand_mask
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    type(b110_default_mvg_provider_t) :: base
    integer :: i
    call require_bound(self)
    call bind_b110_default_mvg_provider(base, self%parameters, self%step_duration)
    call base%evaluate_demand(pressure_head, demand_mask, water_content, conductivity, capacity, dconductivity_dhead)
    if (iand(demand_mask, CONSTITUTIVE_DEMAND_CAPACITY) /= 0) then
      do i=1,size(pressure_head)
        capacity(i)=regularized_capacity(self%parameters%cofgen(:,i), pressure_head(i), &
             self%step_duration, self%regularization_coefficient)
      end do
    end if
  end subroutine elastic_evaluate_demand

  logical function elastic_supports_point_conductivity(self) result(supported)
    class(fpe_elastic01_provider_t), intent(in) :: self
    type(b110_default_mvg_provider_t) :: base
    call require_bound(self)
    call bind_b110_default_mvg_provider(base, self%parameters, self%step_duration)
    supported=base%supports_point_conductivity()
  end function elastic_supports_point_conductivity

  subroutine elastic_evaluate_point_conductivity(self, node_index, pressure_head, water_content, conductivity, available)
    class(fpe_elastic01_provider_t), intent(in) :: self
    integer, intent(in) :: node_index
    real(real64), intent(in) :: pressure_head, water_content
    real(real64), intent(out) :: conductivity
    logical, intent(out) :: available
    type(b110_default_mvg_provider_t) :: base
    call require_bound(self)
    call bind_b110_default_mvg_provider(base, self%parameters, self%step_duration)
    call base%evaluate_point_conductivity(node_index, pressure_head, water_content, conductivity, available)
  end subroutine elastic_evaluate_point_conductivity

  subroutine require_bound(self)
    class(fpe_elastic01_provider_t), intent(in) :: self
    if (.not. associated(self%parameters)) error stop 'F-PE-ELASTIC01: parameters not bound'
    if (self%step_duration <= 0.0_real64) error stop 'F-PE-ELASTIC01: invalid step_duration'
  end subroutine require_bound

  pure real(real64) function regularized_capacity(c, head, step_duration, coefficient) result(capacity)
    real(real64), intent(in) :: c(:), head, step_duration, coefficient
    real(real64) :: alphah, h105, term1, term2, raw
    if (head >= 0.0_real64) then
      raw=0.0_real64
    else
      alphah=abs(c(4)*head)
      if (c(9) > -1.0e-2_real64) then
        if (head > -1.0e-2_real64) then
          raw=c(27)
        else
          term1=alphah**c(30)
          term2=c(25)/((1.0_real64+term1*alphah)**c(31))
          raw=c(29)*term2*term1
        end if
      else
        h105=1.05_real64*c(9)
        if (head >= h105) then
          raw=c(42)/((1.0_real64+c(41)*head)**2)
        else
          term1=alphah**c(30)
          term2=(1.0_real64+term1*alphah)**c(31)
          term2=c(25)/term2
          raw=c(29)*term2*term1/c(28)
        end if
      end if
    end if
    capacity=raw
    if (head > -1.0_real64) capacity=max(capacity,step_duration*coefficient)
  end function regularized_capacity

end module mod_fpe_elastic01_provider
