module mod_fpe_nlglob14z47_test_providers
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, source_sink_provider_t, &
       root_sink_provider_t, top_boundary_provider_t, dynamic_top_boundary_provider_t, &
       macropore_exchange_provider_t, soil_water_boundary_conditions_t, soil_water_top_boundary_result_t
  implicit none

  type, extends(constitutive_hydraulics_provider_t) :: z46_constitutive_t
  contains
    procedure :: evaluate => z46_constitutive_evaluate
  end type

  type, extends(source_sink_provider_t) :: z46_source_sink_t
    real(real64) :: source_value = 0.0_real64
  contains
    procedure :: evaluate => z46_source_sink_evaluate
  end type

  type, extends(root_sink_provider_t) :: z46_root_sink_t
  contains
    procedure :: evaluate => z46_root_sink_evaluate
  end type

  type, extends(top_boundary_provider_t) :: z46_top_t
  contains
    procedure :: evaluate => z46_top_evaluate
  end type

  type, extends(dynamic_top_boundary_provider_t) :: z46_dynamic_top_t
  contains
    procedure :: evaluate => z46_dynamic_top_evaluate
  end type

  type, extends(macropore_exchange_provider_t) :: z46_macropore_t
  contains
    procedure :: evaluate => z46_macropore_evaluate
  end type

contains

  subroutine z46_constitutive_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(z46_constitutive_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    water_content = merge(0.45_real64, 0.30_real64, pressure_head >= 0.0_real64)
    conductivity = 1.0_real64
    capacity = 0.0_real64
    dconductivity_dhead = 0.0_real64
    if (.not. same_type_as(self,self)) conductivity = 0.0_real64
  end subroutine z46_constitutive_evaluate

  subroutine z46_source_sink_evaluate(self, pressure_head, water_content, source, sink)
    class(z46_source_sink_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:), water_content(:)
    real(real64), intent(out) :: source(:), sink(:)
    source = 0.0_real64
    sink = 0.0_real64
    if (size(source) > 0) source(1) = self%source_value
    if (size(pressure_head) + size(water_content) < 0) sink = sink
  end subroutine z46_source_sink_evaluate

  subroutine z46_root_sink_evaluate(self, pressure_head, water_content, root_sink)
    class(z46_root_sink_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:), water_content(:)
    real(real64), intent(out) :: root_sink(:)
    root_sink = 0.0_real64
    if (size(pressure_head) + size(water_content) < 0 .or. .not. same_type_as(self,self)) root_sink = 1.0_real64
  end subroutine z46_root_sink_evaluate

  subroutine z46_top_evaluate(self, pressure_head_top, water_content_top, requested, &
                              actual_top_flux, surface_head, runoff_flux)
    class(z46_top_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head_top, water_content_top
    type(soil_water_boundary_conditions_t), intent(in) :: requested
    real(real64), intent(out) :: actual_top_flux, surface_head, runoff_flux
    actual_top_flux = requested%top_flux
    surface_head = 0.0_real64
    runoff_flux = 0.0_real64
    if (pressure_head_top + water_content_top < -huge(1.0_real64) .or. .not. same_type_as(self,self)) &
         actual_top_flux = 0.0_real64
  end subroutine z46_top_evaluate

  subroutine z46_dynamic_top_evaluate(self, pressure_head_top, water_content_top, candidate_ponding_depth, &
                                      requested, result)
    class(z46_dynamic_top_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head_top, water_content_top, candidate_ponding_depth
    type(soil_water_boundary_conditions_t), intent(in) :: requested
    type(soil_water_top_boundary_result_t), intent(out) :: result
    result = soil_water_top_boundary_result_t()
    if (pressure_head_top + water_content_top + candidate_ponding_depth + requested%top_flux < -huge(1.0_real64) .or. &
        .not. same_type_as(self,self)) result = soil_water_top_boundary_result_t()
  end subroutine z46_dynamic_top_evaluate

  subroutine z46_macropore_evaluate(self, pressure_head, exchange_flux, active)
    class(z46_macropore_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: exchange_flux(:)
    logical, intent(out) :: active
    exchange_flux = 0.0_real64
    active = .true.
    if (size(pressure_head) < 0 .or. .not. same_type_as(self,self)) active = .false.
  end subroutine z46_macropore_evaluate

end module mod_fpe_nlglob14z47_test_providers


program test_fpe_nlglob14z47_eligibility
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, SW_SOLVE_FAILED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX, FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_moving_interface_manager, only: moving_interface_active_view_t, moving_interface_manager_diagnostics_t, &
       evaluate_moving_interface_request_eligibility, select_moving_interface_route, &
       MI_MANAGER_ROUTE_FULL_BYPASS, MI_MANAGER_ROUTE_FULL_FALLBACK
  use mod_timestep_numerical_profile, only: timestep_numerical_profile_t, make_moving_interface_manager_profile, &
       TIMESTEP_PROFILE_INVALID
  use mod_fpe_nlglob14z47_test_providers
  implicit none

  type(soil_water_parameter_set_t), target :: p
  type(soil_water_solve_request_t) :: req
  type(z46_constitutive_t), target :: constitutive
  type(z46_source_sink_t), target :: source_sink
  type(z46_root_sink_t), target :: root_sink
  type(z46_top_t), target :: top
  type(z46_dynamic_top_t), target :: dynamic_top
  type(z46_macropore_t), target :: macropore
  type(moving_interface_active_view_t) :: view
  type(moving_interface_manager_diagnostics_t) :: diag
  type(timestep_numerical_profile_t) :: unset_profile, manager_off, manager_on
  logical :: ok, use_reduced
  character(len=96) :: reason

  p%parameter_set_id = 4601_int64
  p%active_nodes = 4
  allocate(p%z(4), p%dz(4), p%node_distance(4))
  p%z = [-10.0_real64,-20.0_real64,-30.0_real64,-40.0_real64]
  p%dz = 10.0_real64
  p%node_distance = 10.0_real64

  req%parameters => p
  req%base_state%active_nodes = 4
  allocate(req%base_state%pressure_head(4), req%base_state%water_content(4))
  req%base_state%pressure_head = [-10.0_real64,-1.0_real64,0.0_real64,10.0_real64]
  req%base_state%water_content = [0.30_real64,0.30_real64,0.45_real64,0.45_real64]
  req%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
  req%boundary%top_flux = -0.01_real64
  req%boundary%bottom_mode = 2
  req%boundary%bottom_flux = 0.0_real64
  req%physical%macropore_active = .false.
  req%request_interface_sensitivity = .false.
  req%evaluation%constitutive => constitutive
  req%evaluation%source_sink => source_sink
  req%evaluation%top_boundary => top

  call expect(.false., 3, 'manager-disabled')
  call expect(.true., 3, 'eligible')
  call expect(.true., 2, 'invalid-tail-geometry')

  req%base_state%pressure_head = [-10.0_real64,-1.0_real64,-1.0_real64,0.0_real64]
  call expect(.true., 4, 'no-reduced-dimension')
  req%base_state%pressure_head = [-10.0_real64,-1.0_real64,0.0_real64,10.0_real64]

  req%boundary%bottom_mode = 7
  call expect(.true., 3, 'unsupported-bottom-boundary')
  req%boundary%bottom_mode = 2

  req%boundary%bottom_flux = 1.0e-6_real64
  call expect(.true., 3, 'nonzero-bottom-flux')
  req%boundary%bottom_flux = 0.0_real64

  req%boundary%top_mode = FSI_TOP_MODE_DYNAMIC_PROVIDER
  call expect(.true., 3, 'unsupported-top-boundary')
  req%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX

  req%physical%macropore_active = .true.
  call expect(.true., 3, 'macropore-active')
  req%physical%macropore_active = .false.

  source_sink%source_value = 1.0e-6_real64
  call expect(.true., 3, 'source-sink-scope-unsupported')
  source_sink%source_value = 0.0_real64

  req%evaluation%root_sink => root_sink
  call expect(.true., 3, 'root-sink-scope-unsupported')
  nullify(req%evaluation%root_sink)

  req%request_interface_sensitivity = .true.
  call expect(.true., 3, 'interface-sensitivity-unsupported')
  req%request_interface_sensitivity = .false.

  nullify(req%evaluation%top_boundary)
  call expect(.true., 3, 'provider-binding-incomplete')
  req%evaluation%top_boundary => top

  req%evaluation%dynamic_top_boundary => dynamic_top
  call expect(.true., 3, 'unsupported-top-boundary')
  nullify(req%evaluation%dynamic_top_boundary)

  req%evaluation%macropore => macropore
  call expect(.true., 3, 'macropore-active')
  nullify(req%evaluation%macropore)

  call evaluate_moving_interface_request_eligibility(.true., req, 3, view, ok, reason)
  call require(ok .and. view%eligible, 'eligible view missing')
  call select_moving_interface_route(SW_SOLVE_FAILED, .false., view, 1_int64, 'forced-reduced-failure', &
       use_reduced, diag)
  call require(.not. use_reduced, 'fallback selected reduced')
  call require(diag%route == MI_MANAGER_ROUTE_FULL_FALLBACK, 'fallback route missing')

  call evaluate_moving_interface_request_eligibility(.false., req, 3, view, ok, reason)
  call select_moving_interface_route(SW_SOLVE_FAILED, .false., view, 0_int64, trim(reason), use_reduced, diag)
  call require(diag%route == MI_MANAGER_ROUTE_FULL_BYPASS, 'bypass route missing')

  call require(unset_profile%kind == TIMESTEP_PROFILE_INVALID, 'unset profile changed')
  call require(.not. unset_profile%execution_ready(), 'unset profile ready')
  manager_off = make_moving_interface_manager_profile('MOVING_INTERFACE_MANAGER')
  call require(.not. manager_off%execution_ready(), 'manager enabled by default')
  manager_on = make_moving_interface_manager_profile('MOVING_INTERFACE_MANAGER', .true.)
  call require(manager_on%execution_ready(), 'explicit manager opt-in not ready')

  write(*,'(a)') 'F_PE_NLGLOB14Z47_RESULT={"aggregate":"QUALIFIED_Z46_EXPLICIT_ELIGIBILITY_GUARD"}'
  write(*,'(a)') 'F_PE_NLGLOB14Z47=PASS'

contains

  subroutine expect(enabled, tail, expected)
    logical, intent(in) :: enabled
    integer, intent(in) :: tail
    character(len=*), intent(in) :: expected
    call evaluate_moving_interface_request_eligibility(enabled, req, tail, view, ok, reason)
    if (trim(expected) == 'eligible') then
       call require(ok .and. view%eligible, 'expected eligible')
    else
       call require(.not. ok, 'expected ineligible')
    end if
    call require(trim(reason) == trim(expected), 'reason mismatch: '//trim(reason)//' /= '//trim(expected))
  end subroutine expect

  subroutine require(cond, msg)
    logical, intent(in) :: cond
    character(len=*), intent(in) :: msg
    if (.not. cond) then
       write(*,'(a,1x,a)') 'F_PE_NLGLOB14Z47_FAIL', trim(msg)
       error stop 1
    end if
  end subroutine require

end program test_fpe_nlglob14z47_eligibility
