program test_fsi27_fsi13_fsi16_preservation
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_fsi27_b110_oracle_fixture, only: fsi27_oracle_constitutive_t, fsi27_oracle_source_sink_t, &
       fsi27_oracle_root_sink_t, fsi27_oracle_top_t
  implicit none

  real(real64), parameter :: tol = 1.0e-12_real64
  type(soil_water_parameter_set_t), target :: parameters
  type(fsi27_oracle_constitutive_t), target :: constitutive
  type(fsi27_oracle_source_sink_t), target :: source_sink
  type(fsi27_oracle_root_sink_t), target :: root_sink
  type(fsi27_oracle_top_t), target :: top_boundary
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: ws7, wsm2, ws5eq, ws5pert
  type(soil_water_solve_request_t) :: r7, rm2, r5eq, r5pert
  type(soil_water_solve_result_t) :: o7, om2, o5eq, o5pert
  integer :: failures
  real(real64) :: response5, residual7, residualm2

  failures = 0
  call configure_parameters()
  call make_request(r7, 7, 123.456_real64, -999.0_real64)
  call make_request(rm2, -2, -987.654_real64, 888.0_real64)
  call make_request(r5eq, 5, 314.159_real64, -75.0_real64)
  call make_request(r5pert, 5, -271.828_real64, -74.0_real64)

  call solver%solve(r7, ws7, o7)
  call solver%solve(rm2, wsm2, om2)
  call solver%solve(r5eq, ws5eq, o5eq)
  call solver%solve(r5pert, ws5pert, o5pert)

  call require(o7%status == SW_SOLVE_CONVERGED, 'mode7 converged', failures)
  call require(om2%status == SW_SOLVE_CONVERGED, 'mode-2 free drainage converged', failures)
  call require(o5eq%status == SW_SOLVE_CONVERGED, 'mode5 equilibrium converged', failures)
  call require(o5pert%status == SW_SOLVE_CONVERGED, 'mode5 perturbed converged', failures)

  ! F-SI13 semantics: mode 7 and -2 are the same free-drainage family and
  ! derive qbot=-K_bottom. Prescribed bottom_flux/bottom_head seeds are ignored.
  call require(same_bits(o7%bottom_flux, -1.0_real64), 'mode7 qbot=-K', failures)
  call require(same_bits(om2%bottom_flux, -1.0_real64), 'mode-2 qbot=-K', failures)
  call require(vector_same_bits(o7%candidate_state%pressure_head, r7%base_state%pressure_head), 'mode7 equilibrium head', failures)
  call require(vector_same_bits(om2%candidate_state%pressure_head, rm2%base_state%pressure_head), 'mode-2 equilibrium head', failures)
  call require(vector_same_bits(o7%candidate_state%pressure_head, om2%candidate_state%pressure_head), 'mode7/-2 head identity', failures)
  call require(vector_same_bits(o7%candidate_state%water_content, om2%candidate_state%water_content), 'mode7/-2 theta identity', failures)
  residual7 = sum(ws7%richards%residual(1:numnod))
  residualm2 = sum(wsm2%richards%residual(1:numnod))
  call require(ieee_is_finite(residual7) .and. abs(residual7) <= tol, 'mode7 focused residual', failures)
  call require(ieee_is_finite(residualm2) .and. abs(residualm2) <= tol, 'mode-2 focused residual', failures)

  ! F-SI16 semantics: mode 5 is a prescribed lower-face head, not a prescribed
  ! last-node head and not a prescribed qbot. At equal face/node head, gravity
  ! equilibrium gives qbot=-1. A face-head perturbation must alter the state and
  ! authoritative qbot while the request bottom_flux seed remains irrelevant.
  call require(same_bits(o5eq%bottom_flux, -1.0_real64), 'mode5 equilibrium qbot', failures)
  call require(vector_same_bits(o5eq%candidate_state%pressure_head, r5eq%base_state%pressure_head), 'mode5 equilibrium head', failures)
  call require(ieee_is_finite(o5eq%unrounded_mass_balance_residual) .and. &
       abs(o5eq%unrounded_mass_balance_residual) <= tol, 'mode5 equilibrium residual', failures)
  response5 = maxval(abs(o5pert%candidate_state%pressure_head-r5pert%base_state%pressure_head))
  call require(response5 > 1024.0_real64*epsilon(1.0_real64), 'mode5 physical head response', failures)
  call require(.not. same_bits(o5pert%bottom_flux, r5pert%boundary%bottom_flux), 'mode5 qbot not seed', failures)
  call require(ieee_is_finite(o5pert%unrounded_mass_balance_residual) .and. &
       abs(o5pert%unrounded_mass_balance_residual) <= tol, 'mode5 perturbed residual', failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FSI27_FSI13_FSI16_PRESERVATION FAIL failures=', failures
    error stop 1
  end if

  write(*,'(A,1X,Z16.16)') 'FSI27_PRESERVE_MODE7_QBOT_BITS', transfer(o7%bottom_flux,0_int64)
  write(*,'(A,1X,Z16.16)') 'FSI27_PRESERVE_MODEM2_QBOT_BITS', transfer(om2%bottom_flux,0_int64)
  write(*,'(A,1X,Z16.16)') 'FSI27_PRESERVE_MODE5EQ_QBOT_BITS', transfer(o5eq%bottom_flux,0_int64)
  write(*,'(A,1X,Z16.16)') 'FSI27_PRESERVE_MODE5PERT_QBOT_BITS', transfer(o5pert%bottom_flux,0_int64)
  write(*,'(A,ES26.17E3)') 'FSI27_PRESERVE_MODE5_RESPONSE=', response5
  write(*,'(A)') 'FSI27_FSI13_FREE_DRAINAGE_CURRENT_SOURCE=PASS'
  write(*,'(A)') 'FSI27_FSI16_PRESCRIBED_HEAD_CURRENT_SOURCE=PASS'
  write(*,'(A)') 'FSI27_FSI13_FSI16_PRESERVATION PASS'

contains

  subroutine configure_parameters()
    parameters%parameter_set_id = 271316_int64
    parameters%active_nodes = numnod
    allocate(parameters%z(numnod), parameters%dz(numnod), parameters%node_distance(numnod))
    parameters%z = z
    parameters%dz = dz
    parameters%node_distance = disnod(1:numnod)
  end subroutine configure_parameters

  subroutine make_request(r, mode, bottom_flux_seed, bottom_head)
    type(soil_water_solve_request_t), intent(out) :: r
    integer, intent(in) :: mode
    real(real64), intent(in) :: bottom_flux_seed, bottom_head
    r = soil_water_solve_request_t()
    r%parameters => parameters
    r%base_state%active_nodes = numnod
    allocate(r%base_state%pressure_head(numnod), r%base_state%water_content(numnod))
    r%base_state%pressure_head = -75.0_real64
    r%base_state%water_content = 0.30_real64
    r%base_state%ponding_depth = 0.0_real64
    r%base_state%groundwater_level = -2.0_real64
    r%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
    r%boundary%bottom_mode = mode
    r%boundary%top_flux = -1.0_real64
    r%boundary%top_head = -75.0_real64
    r%boundary%bottom_flux = bottom_flux_seed
    r%boundary%bottom_head = bottom_head
    r%physical%macropore_active = .false.
    r%numerical%max_iterations = 16
    r%numerical%max_backtracking = 8
    r%numerical%conductivity_implicit_mode = 0
    r%numerical%conductivity_mean_method = 1
    r%numerical%min_step_duration = 1.0e-6_real64
    r%numerical%compartment_balance_tolerance = tol
    r%numerical%total_balance_tolerance = tol
    r%numerical%head_abs_tolerance = tol
    r%numerical%head_rel_tolerance = tol
    r%numerical%ponding_tolerance = tol
    r%step_duration = 0.25_real64
    r%evaluation%constitutive => constitutive
    r%evaluation%source_sink => source_sink
    r%evaluation%root_sink => root_sink
    r%evaluation%top_boundary => top_boundary
  end subroutine make_request

  pure logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    same_bits = transfer(a,0_int64) == transfer(b,0_int64)
  end function same_bits

  pure logical function vector_same_bits(a,b)
    real(real64), intent(in) :: a(:),b(:)
    integer :: i
    vector_same_bits = size(a)==size(b)
    if (.not.vector_same_bits) return
    do i=1,size(a)
      if (.not.same_bits(a(i),b(i))) then
        vector_same_bits=.false.
        return
      end if
    end do
  end function vector_same_bits

  subroutine require(condition,label,nfail)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    integer, intent(inout) :: nfail
    if (.not.condition) then
      nfail=nfail+1
      write(*,'(A,1X,A)') 'FSI27_PRESERVATION_FAIL',trim(label)
    end if
  end subroutine require

end program test_fsi27_fsi13_fsi16_preservation