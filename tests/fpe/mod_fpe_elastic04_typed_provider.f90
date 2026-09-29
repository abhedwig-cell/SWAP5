module mod_fpe_elastic04_typed_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, &
       CONSTITUTIVE_DEMAND_WATER_CONTENT, CONSTITUTIVE_DEMAND_CAPACITY
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       bind_b110_default_mvg_provider
  implicit none
  private

  type, public :: fpe_elastic04_material_config_t
     logical :: elastic_storage_active = .false.
     real(real64), allocatable :: specific_elastic_storage(:)
  end type

  type, extends(constitutive_hydraulics_provider_t), public :: fpe_elastic04_provider_t
     type(b110_default_mvg_parameters_t), pointer :: parameters => null()
     type(fpe_elastic04_material_config_t), pointer :: material => null()
     real(real64) :: step_duration = 0.0_real64
   contains
     procedure :: evaluate => typed_evaluate
     procedure :: evaluate_demand => typed_evaluate_demand
     procedure :: supports_point_conductivity => typed_supports_point_conductivity
     procedure :: evaluate_point_conductivity => typed_evaluate_point_conductivity
  end type

  public :: bind_fpe_elastic04_provider

contains

  subroutine bind_fpe_elastic04_provider(provider, parameters, material, step_duration)
    type(fpe_elastic04_provider_t), intent(out) :: provider
    type(b110_default_mvg_parameters_t), target, intent(in) :: parameters
    type(fpe_elastic04_material_config_t), target, intent(in) :: material
    real(real64), intent(in) :: step_duration
    integer :: n
    n=parameters%active_nodes
    if(n<=0 .or. .not.allocated(parameters%cofgen)) error stop 'ELASTIC04 invalid hydraulic parameters'
    if(step_duration<=0.0_real64) error stop 'ELASTIC04 invalid step duration'
    if(material%elastic_storage_active) then
      if(.not.allocated(material%specific_elastic_storage)) error stop 'ELASTIC04 active without storage vector'
      if(size(material%specific_elastic_storage)/=n) error stop 'ELASTIC04 storage shape mismatch'
      if(any(material%specific_elastic_storage<0.0_real64)) error stop 'ELASTIC04 negative storage'
    end if
    provider%parameters=>parameters
    provider%material=>material
    provider%step_duration=step_duration
  end subroutine

  subroutine typed_evaluate(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(fpe_elastic04_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    type(b110_default_mvg_provider_t)::base
    integer::i
    call require_bound(self)
    call bind_b110_default_mvg_provider(base,self%parameters,self%step_duration)
    call base%evaluate(pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    if(.not.self%material%elastic_storage_active)return
    do i=1,size(pressure_head)
      if(pressure_head(i)>=0.0_real64)then
        water_content(i)=self%parameters%cofgen(2,i)+pressure_head(i)*self%material%specific_elastic_storage(i)
        capacity(i)=self%material%specific_elastic_storage(i)
      end if
    end do
  end subroutine

  subroutine typed_evaluate_demand(self,pressure_head,demand_mask,water_content,conductivity,capacity,dconductivity_dhead)
    class(fpe_elastic04_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    integer,intent(in)::demand_mask
    real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    type(b110_default_mvg_provider_t)::base
    integer::i
    call require_bound(self)
    call bind_b110_default_mvg_provider(base,self%parameters,self%step_duration)
    call base%evaluate_demand(pressure_head,demand_mask,water_content,conductivity,capacity,dconductivity_dhead)
    if(.not.self%material%elastic_storage_active)return
    do i=1,size(pressure_head)
      if(pressure_head(i)>=0.0_real64)then
        if(iand(demand_mask,CONSTITUTIVE_DEMAND_WATER_CONTENT)/=0) &
          water_content(i)=self%parameters%cofgen(2,i)+pressure_head(i)*self%material%specific_elastic_storage(i)
        if(iand(demand_mask,CONSTITUTIVE_DEMAND_CAPACITY)/=0) &
          capacity(i)=self%material%specific_elastic_storage(i)
      end if
    end do
  end subroutine

  logical function typed_supports_point_conductivity(self) result(supported)
    class(fpe_elastic04_provider_t),intent(in)::self
    type(b110_default_mvg_provider_t)::base
    call require_bound(self)
    call bind_b110_default_mvg_provider(base,self%parameters,self%step_duration)
    supported=base%supports_point_conductivity()
  end function

  subroutine typed_evaluate_point_conductivity(self,node_index,pressure_head,water_content,conductivity,available)
    class(fpe_elastic04_provider_t),intent(in)::self
    integer,intent(in)::node_index
    real(real64),intent(in)::pressure_head,water_content
    real(real64),intent(out)::conductivity
    logical,intent(out)::available
    type(b110_default_mvg_provider_t)::base
    call require_bound(self)
    call bind_b110_default_mvg_provider(base,self%parameters,self%step_duration)
    call base%evaluate_point_conductivity(node_index,pressure_head,water_content,conductivity,available)
  end subroutine

  subroutine require_bound(self)
    class(fpe_elastic04_provider_t),intent(in)::self
    if(.not.associated(self%parameters).or..not.associated(self%material)) error stop 'ELASTIC04 unbound provider'
  end subroutine
end module mod_fpe_elastic04_typed_provider
