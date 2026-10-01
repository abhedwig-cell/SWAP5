module ppa_wu05a16_test_providers
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, source_sink_provider_t, &
       top_boundary_provider_t, macropore_exchange_provider_t, soil_water_boundary_conditions_t
  implicit none
  private

  integer, public :: macro_calls=0
  real(real64), public :: first_head=0.0_real64, last_head=0.0_real64
  real(real64), public :: first_water=0.0_real64, last_water=0.0_real64

  type, extends(constitutive_hydraulics_provider_t), public :: linear_hydraulics_t
    real(real64) :: theta_intercept=0.40_real64
    real(real64) :: capacity_value=0.02_real64
    real(real64) :: conductivity_value=1.0_real64
  contains
    procedure :: evaluate => linear_hydraulics_evaluate
  end type linear_hydraulics_t

  type, extends(source_sink_provider_t), public :: zero_source_sink_t
  contains
    procedure :: evaluate => zero_source_sink_evaluate
  end type zero_source_sink_t

  type, extends(top_boundary_provider_t), public :: requested_flux_top_t
  contains
    procedure :: evaluate => requested_flux_top_evaluate
  end type requested_flux_top_t

  type, extends(macropore_exchange_provider_t), public :: linear_macropore_t
    logical :: enabled=.false.
    real(real64) :: lambda_per_day=0.20_real64
    real(real64) :: capacity_value=0.02_real64
    real(real64), allocatable :: dz(:)
  contains
    procedure :: evaluate_rate => linear_macropore_rate_evaluate
    procedure :: evaluate_derivative => linear_macropore_derivative_evaluate
  end type linear_macropore_t

  public :: reset_macro_trace

contains

  subroutine reset_macro_trace()
    macro_calls=0
    first_head=0.0_real64
    last_head=0.0_real64
    first_water=0.0_real64
    last_water=0.0_real64
  end subroutine reset_macro_trace

  subroutine linear_hydraulics_evaluate(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(linear_hydraulics_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:)
    real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    water_content=self%theta_intercept+self%capacity_value*pressure_head
    conductivity=self%conductivity_value
    capacity=self%capacity_value
    dconductivity_dhead=0.0_real64
  end subroutine linear_hydraulics_evaluate

  subroutine zero_source_sink_evaluate(self,pressure_head,water_content,source,sink)
    class(zero_source_sink_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:),water_content(:)
    real(real64),intent(out)::source(:),sink(:)
    if(size(water_content)/=size(pressure_head))error stop 'A16 source shape'
    source=0.0_real64
    sink=0.0_real64
    if(.not.same_type_as(self,self))error stop 'A16 impossible source type'
  end subroutine zero_source_sink_evaluate

  subroutine requested_flux_top_evaluate(self,pressure_head_top,water_content_top,requested,actual_top_flux,surface_head,runoff_flux)
    class(requested_flux_top_t),intent(in)::self
    real(real64),intent(in)::pressure_head_top,water_content_top
    type(soil_water_boundary_conditions_t),intent(in)::requested
    real(real64),intent(out)::actual_top_flux,surface_head,runoff_flux
    actual_top_flux=requested%top_flux
    surface_head=0.0_real64
    runoff_flux=0.0_real64
    if(pressure_head_top>huge(pressure_head_top) .or. water_content_top>huge(water_content_top)) &
         error stop 'A16 impossible top state'
    if(.not.same_type_as(self,self))error stop 'A16 impossible top type'
  end subroutine requested_flux_top_evaluate

  subroutine linear_macropore_rate_evaluate(self,pressure_head,water_content,exchange_flux,active)
    class(linear_macropore_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:),water_content(:)
    real(real64),intent(out)::exchange_flux(:)
    logical,intent(out)::active
    integer::n

    n=size(pressure_head)
    if(size(water_content)/=n .or. size(exchange_flux)/=n)error stop 'A16 macropore rate shape'
    if(.not.allocated(self%dz) .or. size(self%dz)/=n)error stop 'A16 macropore dz'

    macro_calls=macro_calls+1
    if(macro_calls==1)then
      first_head=pressure_head(1)
      first_water=water_content(1)
    end if
    last_head=pressure_head(1)
    last_water=water_content(1)

    active=self%enabled
    if(.not.active)then
      exchange_flux=0.0_real64
      return
    end if
    exchange_flux=self%lambda_per_day*self%capacity_value*self%dz*pressure_head
  end subroutine linear_macropore_rate_evaluate

  subroutine linear_macropore_derivative_evaluate(self,pressure_head,water_content,capacity,dexchange_dhead, &
                                                   derivative_available,active)
    class(linear_macropore_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:),water_content(:),capacity(:)
    real(real64),intent(out)::dexchange_dhead(:)
    logical,intent(out)::derivative_available,active
    integer::n

    n=size(pressure_head)
    if(size(water_content)/=n .or. size(capacity)/=n .or. size(dexchange_dhead)/=n) &
         error stop 'A16 macropore derivative shape'
    if(.not.allocated(self%dz) .or. size(self%dz)/=n)error stop 'A16 macropore derivative dz'
    if(maxval(abs(capacity-self%capacity_value))>1.0e-14_real64)error stop 'A16 current capacity mismatch'

    active=self%enabled
    derivative_available=.true.
    if(.not.active)then
      dexchange_dhead=0.0_real64
      return
    end if
    dexchange_dhead=self%lambda_per_day*capacity*self%dz
  end subroutine linear_macropore_derivative_evaluate

end module ppa_wu05a16_test_providers

program test_ppa_wu05a16_inner_callback
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod,z,dz,disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t,soil_water_physical_state_t, &
       soil_water_solve_request_t,soil_water_solve_result_t,SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t,reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use ppa_wu05a16_test_providers
  implicit none

  real(real64),parameter::dt=0.25_real64,h0=-1.0_real64,lambda=0.20_real64,tol=2.0e-11_real64
  type(soil_water_parameter_set_t),target::parameters
  type(linear_hydraulics_t),target::hydraulics
  type(zero_source_sink_t),target::source_sink
  type(requested_flux_top_t),target::top_provider
  type(linear_macropore_t),target::macro_provider
  type(reference_richards_legacy_solver_t)::solver
  type(reference_richards_legacy_workspace_t)::workspace_baseline,workspace_inactive,workspace_active
  type(soil_water_physical_state_t)::initial
  type(soil_water_solve_request_t)::request_baseline,request_inactive,request_active
  type(soil_water_solve_result_t)::baseline,inactive,active
  real(real64)::expected_h
  integer::i

  parameters%parameter_set_id=1601_int64
  parameters%active_nodes=numnod
  allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
  parameters%z=z
  parameters%dz=dz
  parameters%node_distance=disnod(1:numnod)

  initial%active_nodes=numnod
  allocate(initial%pressure_head(numnod),initial%water_content(numnod))
  initial%pressure_head=h0
  initial%water_content=hydraulics%theta_intercept+hydraulics%capacity_value*h0
  initial%ponding_depth=0.0_real64
  initial%groundwater_level=-2.0_real64

  request_baseline=soil_water_solve_request_t()
  request_baseline%parameters=>parameters
  request_baseline%base_state=initial
  request_baseline%step_duration=dt
  request_baseline%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
  request_baseline%boundary%bottom_mode=7
  request_baseline%boundary%top_flux=-hydraulics%conductivity_value
  request_baseline%physical%macropore_active=.false.
  request_baseline%numerical%max_iterations=8
  request_baseline%numerical%max_backtracking=4
  request_baseline%numerical%conductivity_implicit_mode=0
  request_baseline%numerical%conductivity_mean_method=1
  request_baseline%numerical%min_step_duration=1.0e-8_real64
  request_baseline%numerical%compartment_balance_tolerance=1.0e-12_real64
  request_baseline%numerical%total_balance_tolerance=1.0e-12_real64
  request_baseline%numerical%head_abs_tolerance=1.0e-12_real64
  request_baseline%numerical%head_rel_tolerance=1.0e-12_real64
  request_baseline%numerical%ponding_tolerance=1.0e-12_real64
  request_baseline%evaluation%constitutive=>hydraulics
  request_baseline%evaluation%source_sink=>source_sink
  request_baseline%evaluation%top_boundary=>top_provider

  call solver%solve(request_baseline,workspace_baseline,baseline)
  call require(baseline%status==SW_SOLVE_CONVERGED,'baseline converged')
  call require(maxval(abs(baseline%candidate_state%pressure_head-h0))<tol,'baseline steady state')

  allocate(macro_provider%dz(numnod))
  macro_provider%dz=dz
  macro_provider%lambda_per_day=lambda
  macro_provider%capacity_value=hydraulics%capacity_value

  request_inactive=request_baseline
  request_inactive%physical%macropore_active=.true.
  request_inactive%evaluation%macropore=>macro_provider
  macro_provider%enabled=.false.
  call reset_macro_trace()
  call solver%solve(request_inactive,workspace_inactive,inactive)
  call require(inactive%status==SW_SOLVE_CONVERGED,'inactive provider converged')
  call require(macro_calls>=1,'inactive provider invoked')
  do i=1,numnod
    call require(transfer(inactive%candidate_state%pressure_head(i),0_int64)== &
         transfer(baseline%candidate_state%pressure_head(i),0_int64),'inactive pressure preservation')
    call require(transfer(inactive%candidate_state%water_content(i),0_int64)== &
         transfer(baseline%candidate_state%water_content(i),0_int64),'inactive water preservation')
  end do
  call require(transfer(inactive%top_flux,0_int64)==transfer(baseline%top_flux,0_int64),'inactive top flux preservation')
  call require(transfer(inactive%bottom_flux,0_int64)==transfer(baseline%bottom_flux,0_int64),'inactive bottom flux preservation')

  request_active=request_baseline
  request_active%physical%macropore_active=.true.
  request_active%evaluation%macropore=>macro_provider
  macro_provider%enabled=.true.
  call reset_macro_trace()
  call solver%solve(request_active,workspace_active,active)
  call require(active%status==SW_SOLVE_CONVERGED,'active provider converged')
  call require(macro_calls>=2,'provider called on multiple residual iterates')
  call require(abs(last_head-first_head)>1.0e-10_real64,'provider sees changing pressure iterate')
  call require(abs(last_water-first_water)>1.0e-12_real64,'provider sees changing water iterate')

  expected_h=h0/(1.0_real64-lambda*dt)
  call require(maxval(abs(active%candidate_state%pressure_head-expected_h))<tol,'analytic active head')
  call require(active%diagnostics%nonlinear_iterations>=1 .and. &
       active%diagnostics%nonlinear_iterations<=2,'exact derivative bounded Newton iterations')
  call require(abs(active%integrated_mass_balance_residual_cm)<1.0e-12_real64,'active integrated mass residual')

  write(*,'(*(g0))') 'PPA_WU05A16_CALLBACK_TRACE|CALLS=',macro_calls,'|FIRST_H=',first_head, &
       '|LAST_H=',last_head,'|EXPECTED_H=',expected_h, &
       '|NONLINEAR_IT=',active%diagnostics%nonlinear_iterations
  print '(a)', 'PPA_WU05A16_INACTIVE_PRESERVATION=PASS'
  print '(a)', 'PPA_WU05A16_CURRENT_ITERATE_CALLBACK=PASS'
  print '(a)', 'PPA_WU05A16_RESIDUAL_JACOBIAN_ANALYTIC=PASS'
  print '(a)', 'PPA_WU05A16_INNER_CALLBACK_GATE=PASS'

contains
  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(a,1x,a)') 'PPA_WU05A16_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ppa_wu05a16_inner_callback
