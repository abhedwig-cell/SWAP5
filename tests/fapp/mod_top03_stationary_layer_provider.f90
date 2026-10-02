! Research factorial: algebraic layer rows retain geometry and K(h), but own no
! changing water storage. This is a diagnostic DAE, not a production material.
module mod_top03_stationary_layer_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t, evaluate_b110_default_mvg_conductivity
  use mod_soil_water_solver_contract, only: CONSTITUTIVE_DEMAND_WATER_CONTENT, CONSTITUTIVE_DEMAND_CONDUCTIVITY, &
       CONSTITUTIVE_DEMAND_CAPACITY, CONSTITUTIVE_DEMAND_DKDH, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, SW_TOP_BOUNDARY_AVAILABLE
  use mod_top03_explicit_layer_provider, only: top03_layer_contact_provider_t
  implicit none
  type, extends(b110_default_mvg_provider_t) :: top03_stationary_hydraulics_t
    integer :: layer_nodes=0
    logical :: zero_layer_storage=.false., saturated_layer_conductivity=.false.
    real(real64), allocatable :: fixed_layer_theta(:)
  contains
    procedure :: evaluate => evaluate_factorial
    procedure :: evaluate_demand => evaluate_factorial_demand
    procedure :: evaluate_point_conductivity => evaluate_factorial_point
  end type
  type, extends(top03_layer_contact_provider_t) :: top03_stationary_top_t
    logical :: saturated_layer_conductivity=.false.
  contains
    procedure :: evaluate => evaluate_factorial_top
  end type
contains
  subroutine evaluate_factorial(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(top03_stationary_hydraulics_t),intent(in) :: self
    real(real64),intent(in) :: pressure_head(:)
    real(real64),intent(out) :: water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    call self%b110_default_mvg_provider_t%evaluate(pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    if(self%zero_layer_storage)then
      water_content(1:self%layer_nodes)=self%fixed_layer_theta
      capacity(1:self%layer_nodes)=0.0_real64
    end if
    if(self%saturated_layer_conductivity)then
      conductivity(1:self%layer_nodes)=self%parameters%cofgen(3,1:self%layer_nodes)
      dconductivity_dhead(1:self%layer_nodes)=0.0_real64
    end if
  end subroutine
  subroutine evaluate_factorial_demand(self,pressure_head,demand_mask,water_content,conductivity,capacity,dconductivity_dhead)
    class(top03_stationary_hydraulics_t),intent(in) :: self
    real(real64),intent(in) :: pressure_head(:)
    integer,intent(in) :: demand_mask
    real(real64),intent(out) :: water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    ! Compute K from physical theta(head) before replacing the diagnostic storage.
    call self%b110_default_mvg_provider_t%evaluate_demand(pressure_head,demand_mask,water_content, &
         conductivity,capacity,dconductivity_dhead)
    if(self%zero_layer_storage)then
      if(iand(demand_mask,CONSTITUTIVE_DEMAND_WATER_CONTENT)/=0)water_content(1:self%layer_nodes)=self%fixed_layer_theta
      if(iand(demand_mask,CONSTITUTIVE_DEMAND_CAPACITY)/=0)capacity(1:self%layer_nodes)=0.0_real64
    end if
    if(self%saturated_layer_conductivity)then
      if(iand(demand_mask,CONSTITUTIVE_DEMAND_CONDUCTIVITY)/=0) &
           conductivity(1:self%layer_nodes)=self%parameters%cofgen(3,1:self%layer_nodes)
      if(iand(demand_mask,CONSTITUTIVE_DEMAND_DKDH)/=0)dconductivity_dhead(1:self%layer_nodes)=0.0_real64
    end if
  end subroutine
  subroutine evaluate_factorial_point(self,node_index,pressure_head,water_content,conductivity,available)
    class(top03_stationary_hydraulics_t),intent(in) :: self
    integer,intent(in) :: node_index
    real(real64),intent(in) :: pressure_head,water_content
    real(real64),intent(out) :: conductivity
    logical,intent(out) :: available
    if(node_index<=self%layer_nodes.and.self%saturated_layer_conductivity)then
      conductivity=self%parameters%cofgen(3,node_index);available=.true.
    else if(node_index<=self%layer_nodes.and.self%zero_layer_storage)then
      call evaluate_b110_default_mvg_conductivity(self%parameters,node_index,pressure_head,conductivity,available)
    else
      call self%b110_default_mvg_provider_t%evaluate_point_conductivity(node_index,pressure_head,water_content, &
           conductivity,available)
    end if
  end subroutine
  subroutine evaluate_factorial_top(self,pressure_head_top,water_content_top,candidate_ponding_depth,requested,result)
    class(top03_stationary_top_t),intent(in) :: self
    real(real64),intent(in) :: pressure_head_top,water_content_top,candidate_ponding_depth
    type(soil_water_boundary_conditions_t),intent(in) :: requested
    type(soil_water_top_boundary_result_t),intent(out) :: result
    call self%top03_layer_contact_provider_t%evaluate(pressure_head_top,water_content_top,candidate_ponding_depth,requested,result)
    if(result%status/=SW_TOP_BOUNDARY_AVAILABLE.or..not.self%saturated_layer_conductivity)return
    result%surface_face_conductivity=self%hydraulics%cofgen(3,1)
    result%actual_top_flux=-result%surface_face_conductivity*((result%surface_head-pressure_head_top)/ &
         self%geometry%node_distance(1)+1.0_real64)
    result%route='top03-saturated-layer-factorial'
  end subroutine
end module
