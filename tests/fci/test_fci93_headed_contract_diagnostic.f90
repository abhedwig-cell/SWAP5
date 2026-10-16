program test_fci93_headed_contract_diagnostic
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, SW_TOP_BOUNDARY_AVAILABLE
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  implicit none
  type(soil_water_parameter_set_t), target :: geometry
  type(b110_default_mvg_parameters_t), target :: hydraulics
  real(real64) :: cofgen(24,2)
  integer :: node
  geometry%parameter_set_id=930011_int64
  geometry%active_nodes=2
  allocate(geometry%z(2),geometry%dz(2),geometry%node_distance(2))
  geometry%z=[-5.0_real64,-15.0_real64]
  geometry%dz=10.0_real64
  geometry%node_distance=10.0_real64
  cofgen=0.0_real64
  do node=1,2
    cofgen(1,node)=0.032_real64; cofgen(2,node)=0.423_real64
    cofgen(3,node)=4.75_real64; cofgen(4,node)=0.0135_real64
    cofgen(5,node)=0.365_real64; cofgen(6,node)=1.455_real64
    cofgen(7,node)=1.0_real64-1.0_real64/cofgen(6,node)
    cofgen(8,node)=cofgen(4,node); cofgen(10,node)=cofgen(3,node)
    cofgen(11,node)=0.999_real64; cofgen(12,node)=0.99_real64*cofgen(3,node)
    cofgen(22,node)=-1.0e6_real64; cofgen(23,node)=1.0e-12_real64
  end do
  call initialize_b110_default_mvg_parameters(hydraulics,cofgen)
  call probe('ponded-head',2.0_real64,10.0_real64)
  call probe('ponded-head-linear-runoff',3.0_real64,0.1_real64)
  write(*,'(A)') 'FCI93_HEADED_BINDING_DIAGNOSIS=REPRODUCED_NOT_PRODUCTION_QUALIFICATION'
contains
  subroutine probe(route,previous_pond,pondmax)
    character(len=*), intent(in) :: route
    real(real64), intent(in) :: previous_pond,pondmax
    type(b110_dynamic_top_boundary_solver_provider_t) :: unbound,fixed
    type(soil_water_boundary_conditions_t) :: boundary
    type(soil_water_top_boundary_result_t) :: a,b,plus,minus
    real(real64) :: fd
    real(real64), parameter :: head=2.0_real64, eps=1.0e-5_real64
    call bind_b110_dynamic_top_boundary_solver_provider(unbound,geometry,hydraulics,1,previous_pond, &
         0.005_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,pondmax,0.5_real64,1.0_real64)
    call bind_b110_dynamic_top_boundary_solver_provider(fixed,geometry,hydraulics,1,previous_pond, &
         0.005_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,pondmax,0.5_real64,1.0_real64, &
         fixed_top_node_conductivity=4.75_real64)
    boundary=soil_water_boundary_conditions_t()
    call unbound%evaluate(head,0.423_real64,previous_pond,boundary,a)
    call fixed%evaluate(head,0.423_real64,previous_pond,boundary,b)
    call require(a%status==SW_TOP_BOUNDARY_AVAILABLE.and.b%status==SW_TOP_BOUNDARY_AVAILABLE,'provider status')
    call require(trim(a%route)==route.and.trim(b%route)==route,'paired route')
    call require(.not.a%surface_head_derivative_available,'nonfixed binding lacks receipt')
    call require(b%surface_head_derivative_available,'fixed binding has receipt')
    call require(a%surface_head==b%surface_head,'identical saturated physical head')
    call require(a%actual_top_flux==b%actual_top_flux,'identical saturated physical flux')
    call unbound%evaluate(head+eps,0.423_real64,previous_pond,boundary,plus)
    call unbound%evaluate(head-eps,0.423_real64,previous_pond,boundary,minus)
    call require(trim(plus%route)==route.and.trim(minus%route)==route,'perturbation stays on branch')
    fd=(plus%surface_head-minus%surface_head)/(2.0_real64*eps)
    call require(fd>0.0_real64,'missing derivative is not zero')
    call require(abs(fd-b%surface_head_dpressure_head_top)<1.0e-10_real64,'saturated paired derivative identity')
    write(*,'(*(g0))') 'FCI93_BINDING_PROBE|ROUTE=',route,'|NONFIXED_RECEIPT=',a%surface_head_derivative_available, &
         '|FIXED_RECEIPT=',b%surface_head_derivative_available,'|FD=',fd,'|FIXED_ANALYTIC=',b%surface_head_dpressure_head_top
  end subroutine probe
  subroutine require(condition,message)
    logical,intent(in)::condition
    character(len=*),intent(in)::message
    if(.not.condition)then
      write(*,'(A)') 'FCI93_DIAGNOSTIC_FAIL '//message
      error stop 93
    end if
  end subroutine require
end program test_fci93_headed_contract_diagnostic
