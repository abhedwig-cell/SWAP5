module mod_fpe_elastic05_legacy_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, &
       CONSTITUTIVE_DEMAND_WATER_CONTENT, CONSTITUTIVE_DEMAND_CAPACITY
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       bind_b110_default_mvg_provider
  implicit none
  private

  type, extends(constitutive_hydraulics_provider_t), public :: fpe_elastic05_legacy_provider_t
     type(b110_default_mvg_parameters_t), pointer :: parameters => null()
     real(real64) :: step_duration = 0.0_real64
   contains
     procedure :: evaluate => elastic_evaluate
     procedure :: evaluate_demand => elastic_evaluate_demand
     procedure :: supports_point_conductivity => elastic_supports_point_conductivity
     procedure :: evaluate_point_conductivity => elastic_evaluate_point_conductivity
  end type fpe_elastic05_legacy_provider_t
  public :: bind_fpe_elastic05_legacy_provider
contains
  subroutine bind_fpe_elastic05_legacy_provider(provider, parameters, step_duration)
    type(fpe_elastic05_legacy_provider_t), intent(out) :: provider
    type(b110_default_mvg_parameters_t), target, intent(in) :: parameters
    real(real64), intent(in) :: step_duration
    if (parameters%active_nodes <= 0 .or. .not.allocated(parameters%cofgen)) error stop 'F-PE-ELASTIC05 legacy: invalid parameter set'
    if (size(parameters%cofgen,1) < 24) error stop 'F-PE-ELASTIC05 legacy: ELAS row 24 unavailable'
    if (any(parameters%cofgen(24,:) < 0.0_real64)) error stop 'F-PE-ELASTIC05 legacy: ELAS must be nonnegative'
    if (step_duration <= 0.0_real64) error stop 'F-PE-ELASTIC05 legacy: step_duration must be positive'
    provider%parameters => parameters
    provider%step_duration = step_duration
  end subroutine

  subroutine elastic_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(fpe_elastic05_legacy_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    type(b110_default_mvg_provider_t) :: base
    integer :: i
    call require_bound(self)
    call bind_b110_default_mvg_provider(base,self%parameters,self%step_duration)
    call base%evaluate(pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    do i=1,size(pressure_head)
      if (pressure_head(i) >= 0.0_real64) then
        water_content(i)=self%parameters%cofgen(2,i)+pressure_head(i)*self%parameters%cofgen(24,i)
        capacity(i)=self%parameters%cofgen(24,i)
      end if
    end do
  end subroutine

  subroutine elastic_evaluate_demand(self,pressure_head,demand_mask,water_content,conductivity,capacity,dconductivity_dhead)
    class(fpe_elastic05_legacy_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    integer, intent(in) :: demand_mask
    real(real64), intent(out) :: water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    type(b110_default_mvg_provider_t) :: base
    integer :: i
    call require_bound(self)
    call bind_b110_default_mvg_provider(base,self%parameters,self%step_duration)
    call base%evaluate_demand(pressure_head,demand_mask,water_content,conductivity,capacity,dconductivity_dhead)
    do i=1,size(pressure_head)
      if (pressure_head(i) >= 0.0_real64) then
        if (iand(demand_mask,CONSTITUTIVE_DEMAND_WATER_CONTENT)/=0) &
             water_content(i)=self%parameters%cofgen(2,i)+pressure_head(i)*self%parameters%cofgen(24,i)
        if (iand(demand_mask,CONSTITUTIVE_DEMAND_CAPACITY)/=0) capacity(i)=self%parameters%cofgen(24,i)
      end if
    end do
  end subroutine

  logical function elastic_supports_point_conductivity(self) result(supported)
    class(fpe_elastic05_legacy_provider_t), intent(in) :: self
    type(b110_default_mvg_provider_t) :: base
    call require_bound(self)
    call bind_b110_default_mvg_provider(base,self%parameters,self%step_duration)
    supported=base%supports_point_conductivity()
  end function

  subroutine elastic_evaluate_point_conductivity(self,node_index,pressure_head,water_content,conductivity,available)
    class(fpe_elastic05_legacy_provider_t), intent(in) :: self
    integer, intent(in) :: node_index
    real(real64), intent(in) :: pressure_head,water_content
    real(real64), intent(out) :: conductivity
    logical, intent(out) :: available
    type(b110_default_mvg_provider_t) :: base
    call require_bound(self)
    call bind_b110_default_mvg_provider(base,self%parameters,self%step_duration)
    call base%evaluate_point_conductivity(node_index,pressure_head,water_content,conductivity,available)
  end subroutine

  subroutine require_bound(self)
    class(fpe_elastic05_legacy_provider_t), intent(in) :: self
    if (.not.associated(self%parameters)) error stop 'F-PE-ELASTIC05 legacy: parameters not bound'
    if (self%step_duration <= 0.0_real64) error stop 'F-PE-ELASTIC05 legacy: invalid step_duration'
  end subroutine
end module mod_fpe_elastic05_legacy_provider
