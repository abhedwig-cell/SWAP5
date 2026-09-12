program test_eb_i03_phase_flux_view
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, source_sink_provider_t, SW_SOLVE_CONVERGED, SW_SOLVE_RETRY_ADVISED
  use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace
  use mod_soil_water_phase_flux_view, only: soil_water_phase_flux_view_t, SW_FACE_FLUX_POSITIVE_UPWARD
  use mod_reference_richards_phase_flux_binding, only: build_reference_richards_phase_flux_view
  implicit none

  type, extends(source_sink_provider_t) :: dummy_source_sink_t
   contains
     procedure :: evaluate => dummy_source_sink_evaluate
  end type dummy_source_sink_t

  type(soil_water_parameter_set_t), target :: parameters
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: result
  type(reference_richards_workspace_t) :: workspace
  type(soil_water_phase_flux_view_t) :: view
  type(dummy_source_sink_t), target :: source_sink
  logical :: ok
  real(real64), parameter :: tol = 1.0e-14_real64

  parameters%active_nodes = 2
  allocate(parameters%z(2), parameters%dz(2), parameters%node_distance(2))
  parameters%z = [-5.0_real64, -20.0_real64]
  parameters%dz = [10.0_real64, 20.0_real64]
  parameters%node_distance = [5.0_real64, 15.0_real64]

  request%parameters => parameters
  request%step_duration = 2.0_real64
  request%evaluation%source_sink => source_sink
  request%base_state%active_nodes = 2
  allocate(request%base_state%pressure_head(2), request%base_state%water_content(2))
  request%base_state%pressure_head = [-100.0_real64, -80.0_real64]
  request%base_state%water_content = [0.20_real64, 0.30_real64]

  result%status = SW_SOLVE_CONVERGED
  result%candidate_state%active_nodes = 2
  allocate(result%candidate_state%pressure_head(2), result%candidate_state%water_content(2))
  result%candidate_state%pressure_head = [-90.0_real64, -85.0_real64]
  result%candidate_state%water_content = [0.22_real64, 0.29_real64]
  result%top_flux = -0.500_real64
  result%bottom_flux = -0.404_real64

  call initialize_reference_workspace(workspace, 2)
  workspace%sink = [0.010_real64, 0.020_real64]
  workspace%source = [0.000_real64, 0.005_real64]
  workspace%provider_root_sink = [0.030_real64, 0.040_real64]
  workspace%residual = [0.001_real64, -0.002_real64]

  call build_reference_richards_phase_flux_view(request, result, workspace, view, ok)
  if (.not. ok) error stop 'EB-I03 expected available reference flux view'
  if (.not. view%candidate_interval) error stop 'EB-I03 view must remain candidate/trial scoped'
  if (view%sign_convention /= SW_FACE_FLUX_POSITIVE_UPWARD) error stop 'EB-I03 wrong sign convention'
  if (.not. view%liquid_flux_available) error stop 'EB-I03 liquid rate unavailable'
  if (.not. view%liquid_transport_available) error stop 'EB-I03 liquid transport unavailable'
  if (.not. view%continuity_residual_available) error stop 'EB-I03 continuity residual unavailable'
  if (view%vapor_phase_modelled) error stop 'EB-I03 must not invent vapour physics'
  if (view%vapor_flux_available .or. view%vapor_transport_available) error stop 'EB-I03 fake vapour availability'
  if (view%full_physical_phase_coverage) error stop 'EB-I03 must not claim full physical phase coverage'
  if (size(view%liquid_face_flux_cm_day) /= 3) error stop 'EB-I03 face topology mismatch'
  if (maxval(abs(view%liquid_face_flux_cm_day - [-0.500_real64, -0.361_real64, -0.404_real64])) > tol) &
       error stop 'EB-I03 residual-preserving flux replay mismatch'
  if (maxval(abs(view%liquid_face_transport_cm - [-1.000_real64, -0.722_real64, -0.808_real64])) > tol) &
       error stop 'EB-I03 interval transport mismatch'
  if (maxval(abs(view%continuity_residual_cm_day - [0.001_real64, -0.002_real64])) > tol) &
       error stop 'EB-I03 residual was altered or hidden'
  if (abs(view%bottom_flux_consistency_residual_cm_day) > tol) error stop 'EB-I03 bottom flux inconsistency'
  if (abs(view%mass_balance_residual_cm_day + 0.001_real64) > tol) error stop 'EB-I03 residual sum mismatch'

  result%status = SW_SOLVE_RETRY_ADVISED
  call build_reference_richards_phase_flux_view(request, result, workspace, view, ok)
  if (ok) error stop 'EB-I03 retry candidate must fail closed'
  if (view%liquid_flux_available) error stop 'EB-I03 retry leaked candidate flux'
  if (allocated(view%liquid_face_flux_cm_day)) error stop 'EB-I03 retry retained candidate array'

  result%status = SW_SOLVE_CONVERGED
  request%physical%macropore_active = .true.
  call build_reference_richards_phase_flux_view(request, result, workspace, view, ok)
  if (ok) error stop 'EB-I03 macropore route must fail closed'

  request%physical%macropore_active = .false.
  nullify(request%evaluation%source_sink)
  call build_reference_richards_phase_flux_view(request, result, workspace, view, ok)
  if (ok) error stop 'EB-I03 hidden source/sink route must fail closed'

  print '(a)', 'EB-I03 phase flux view: PASS'

contains

  subroutine dummy_source_sink_evaluate(self, pressure_head, water_content, source, sink)
    class(dummy_source_sink_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(in) :: water_content(:)
    real(real64), intent(out) :: source(:)
    real(real64), intent(out) :: sink(:)

    if (size(pressure_head) /= size(water_content)) error stop 'dummy provider shape mismatch'
    if (self%reserved_marker() /= 0) error stop 'dummy provider marker mismatch'
    source = 0.0_real64
    sink = 0.0_real64
  end subroutine dummy_source_sink_evaluate

  integer function reserved_marker(self)
    class(dummy_source_sink_t), intent(in) :: self
    reserved_marker = 0
  end function reserved_marker

end program test_eb_i03_phase_flux_view
