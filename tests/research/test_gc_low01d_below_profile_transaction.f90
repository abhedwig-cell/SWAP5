program test_gc_low01d_below_profile_transaction
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_gc_low01_trial_transaction, only: gc_low01_candidate_t, gc_low01_accepted_state_t, &
       gc_low01_initialize_accepted, gc_low01_build_below_profile_candidate, &
       gc_low01_reject_candidate, gc_low01_accept_candidate, &
       GC_LOW01_BRANCH_BELOW_BOTTOM_NODE, GC_LOW01_QBOT_ROUTE_MODE5_MATERIALIZED
  implicit none

  integer, parameter :: n = 4
  real(real64), parameter :: dt = 1.0e-4_real64
  real(real64), parameter :: mass_tol = 1.0e-10_real64
  real(real64), parameter :: z(n) = [-25.0_real64, -75.0_real64, -150.0_real64, -250.0_real64]
  real(real64), parameter :: dz(n) = [50.0_real64, 50.0_real64, 100.0_real64, 100.0_real64]
  real(real64), parameter :: node_distance(n) = [25.0_real64, 50.0_real64, 75.0_real64, 100.0_real64]
  real(real64), parameter :: bottom_face = -300.0_real64
  real(real64), parameter :: origin_hphi = -350.0_real64
  real(real64), parameter :: trial_hphi(3) = [-350.0_real64, -349.9_real64, -350.0_real64]
  character(len=2), parameter :: label(3) = ['A1','B ','A2']

  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: result
  type(gc_low01_accepted_state_t) :: accepted, frozen_origin
  type(gc_low01_candidate_t) :: candidate
  real(real64), target :: drainage(1,n), irrigation(n), root_sink(n)
  real(real64) :: cofgen(24,n)
  real(real64) :: origin_head(n), origin_water(n), conductivity(n), capacity(n), dkdh(n)
  real(real64), allocatable :: a1_head(:), a1_water(:)
  real(real64) :: a1_qbot, a1_mass_residual
  integer :: a1_nonlinear_iterations, a1_linear_solves
  real(real64) :: storage0, storage1, ledger_residual, hbot
  logical :: b_nonvacuous
  integer :: i

  call configure_parameters(parameters, cofgen)
  call initialize_b110_default_mvg_parameters(hydraulic_parameters, cofgen)
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, dt)

  origin_head = origin_hphi - z
  call constitutive%evaluate(origin_head, origin_water, conductivity, capacity, dkdh)
  call require(all(ieee_is_finite(origin_water)), 'finite origin water')
  call require(all(ieee_is_finite(conductivity)) .and. all(conductivity > 0.0_real64), 'finite origin K')

  drainage = 0.0_real64
  irrigation = 0.0_real64
  root_sink = 0.0_real64
  call bind_b110_source_sink_provider(source_sink, drainage, irrigation, root_sink)

  call gc_low01_initialize_accepted(accepted, origin_head, origin_water, 0.0_real64, origin_hphi)
  call copy_accepted(accepted, frozen_origin)
  storage0 = sum(origin_water*dz)
  b_nonvacuous = .false.

  do i = 1, 3
    call require(same_accepted_bits(accepted, frozen_origin), trim(label(i))//' trial starts at immutable accepted origin')

    hbot = trial_hphi(i) - bottom_face
    call build_request_from_accepted(accepted, trial_hphi(i), hbot, request)
    call solver%solve(request, workspace, result)

    call require(result%status == SW_SOLVE_CONVERGED, trim(label(i))//' mode5 solve converged')
    call require(.not. result%retry_advised, trim(label(i))//' no retry')
    call require(result%diagnostics%alternative_solver_calls == 0, trim(label(i))//' no alternative solver')
    call require(all(ieee_is_finite(result%candidate_state%pressure_head)), trim(label(i))//' finite heads')
    call require(all(ieee_is_finite(result%candidate_state%water_content)), trim(label(i))//' finite water')
    call require(ieee_is_finite(result%bottom_flux), trim(label(i))//' finite qbot')

    storage1 = sum(result%candidate_state%water_content*dz) + result%candidate_state%ponding_depth
    ledger_residual = storage1-storage0 - (-result%top_flux + result%bottom_flux)*dt
    call require(abs(ledger_residual) <= mass_tol, trim(label(i))//' independent mass closure')

    call gc_low01_build_below_profile_candidate(candidate, trial_hphi(i), bottom_face, result%bottom_flux, &
         ledger_residual, result%candidate_state%pressure_head, result%candidate_state%water_content, &
         result%candidate_state%ponding_depth, result%candidate_state%groundwater_level, &
         result%diagnostics%nonlinear_iterations, result%diagnostics%linear_solves, &
         result%diagnostics%alternative_solver_calls, result%retry_advised)

    call verify_candidate_contract(candidate, trial_hphi(i), hbot, trim(label(i)))

    write(*,'(A,A)') 'GC_LOW01D_LABEL=', trim(label(i))
    write(*,'(A,ES26.17E3)') 'GC_LOW01D_HPHI_CM=', trial_hphi(i)
    write(*,'(A,ES26.17E3)') 'GC_LOW01D_HBOT_CM=', candidate%hbot_cm
    write(*,'(A,ES26.17E3)') 'GC_LOW01D_QBOT_CM_PER_DAY=', candidate%qbot_cm_per_day
    write(*,'(A,ES26.17E3)') 'GC_LOW01D_MASS_RESIDUAL_CM=', candidate%integrated_mass_residual_cm
    write(*,'(A,I0)') 'GC_LOW01D_ACCEPTED_REVISION_BEFORE_DISPOSITION=', accepted%revision
    write(*,'(A,ES26.17E3)') 'GC_LOW01D_ACCEPTED_MASS_BEFORE_DISPOSITION_CM=', accepted%accepted_interface_mass_cm

    select case (i)
    case (1)
       allocate(a1_head(n), a1_water(n))
       a1_head = candidate%pressure_head_cm
       a1_water = candidate%water_content
       a1_qbot = candidate%qbot_cm_per_day
       a1_mass_residual = candidate%integrated_mass_residual_cm
       a1_nonlinear_iterations = candidate%nonlinear_iterations
       a1_linear_solves = candidate%linear_solves

       call gc_low01_reject_candidate(candidate)
       call require(.not. candidate%available, 'A1 candidate cleared on rejection')
       call require(same_accepted_bits(accepted, frozen_origin), 'A1 rejection preserves accepted origin')
       call require(accepted%revision == 0_int64, 'A1 rejection revision')
       call require(same_real_bits(accepted%accepted_interface_mass_cm, 0.0_real64), 'A1 rejection mass')

    case (2)
       b_nonvacuous = .not. same_real_bits(a1_qbot, candidate%qbot_cm_per_day) .or. &
            .not. same_real_bits_array(a1_head, candidate%pressure_head_cm)
       call require(b_nonvacuous, 'B differs from A1')

       call gc_low01_reject_candidate(candidate)
       call require(.not. candidate%available, 'B candidate cleared on rejection')
       call require(same_accepted_bits(accepted, frozen_origin), 'B rejection preserves accepted origin')
       call require(accepted%revision == 0_int64, 'B rejection revision')
       call require(same_real_bits(accepted%accepted_interface_mass_cm, 0.0_real64), 'B rejection mass')

    case (3)
       call require(same_real_bits_array(a1_head, candidate%pressure_head_cm), 'A1/A2 pressure head replay')
       call require(same_real_bits_array(a1_water, candidate%water_content), 'A1/A2 water replay')
       call require(same_real_bits(a1_qbot, candidate%qbot_cm_per_day), 'A1/A2 qbot replay')
       call require(same_real_bits(a1_mass_residual, candidate%integrated_mass_residual_cm), 'A1/A2 mass replay')
       call require(a1_nonlinear_iterations == candidate%nonlinear_iterations, 'A1/A2 nonlinear iterations')
       call require(a1_linear_solves == candidate%linear_solves, 'A1/A2 linear solves')

       call gc_low01_accept_candidate(accepted, candidate, dt)
       call require(.not. candidate%available, 'A2 candidate cleared after acceptance')
       call require(accepted%revision == 1_int64, 'A2 advances revision once')
       call require(same_real_bits(accepted%accepted_interface_mass_cm, a1_qbot*dt), 'A2 publishes qbot*dt once')
       call require(same_real_bits_array(accepted%pressure_head_cm, a1_head), 'A2 publishes candidate heads')
       call require(same_real_bits_array(accepted%water_content, a1_water), 'A2 publishes candidate water')
    end select

    if (allocated(request%base_state%pressure_head)) deallocate(request%base_state%pressure_head)
    if (allocated(request%base_state%water_content)) deallocate(request%base_state%water_content)
  end do

  call require(b_nonvacuous, 'B nonvacuous final')
  call require(accepted%revision == 1_int64, 'one accepted revision total')
  call require(same_real_bits(accepted%accepted_interface_mass_cm, a1_qbot*dt), 'rejected mass excluded')

  write(*,'(A,I0)') 'GC_LOW01D_FINAL_REVISION=', accepted%revision
  write(*,'(A,ES26.17E3)') 'GC_LOW01D_FINAL_ACCEPTED_INTERFACE_MASS_CM=', accepted%accepted_interface_mass_cm
  write(*,'(A)') 'GC_LOW01D_REJECTED_TRIAL_ISOLATION=PASS'
  write(*,'(A)') 'GC_LOW01D_A_B_A_REPLAY=PASS'
  write(*,'(A)') 'GC_LOW01D_SINGLE_PUBLICATION=PASS'
  write(*,'(A)') 'GC_LOW01D_TYPED_CANDIDATE_CONTRACT=PASS'
  write(*,'(A)') 'GC_LOW01D_LIVE_GATE=PASS'

contains

  subroutine configure_parameters(p, c)
    type(soil_water_parameter_set_t), target, intent(out) :: p
    real(real64), intent(out) :: c(24,n)
    integer :: j

    p%parameter_set_id = 101004_int64
    p%active_nodes = n
    allocate(p%z(n), p%dz(n), p%node_distance(n))
    p%z = z
    p%dz = dz
    p%node_distance = node_distance

    c = 0.0_real64
    do j = 1, n
      c(1,j)=0.032_real64; c(2,j)=0.423_real64; c(3,j)=4.75_real64
      c(4,j)=0.0135_real64; c(5,j)=0.365_real64; c(6,j)=1.455_real64
      c(7,j)=1.0_real64-1.0_real64/c(6,j); c(8,j)=c(4,j)
      c(9,j)=0.0_real64; c(10,j)=c(3,j); c(11,j)=0.999_real64
      c(12,j)=0.99_real64*c(3,j); c(22,j)=-1.0e6_real64; c(23,j)=1.0e-12_real64
    end do
  end subroutine configure_parameters

  subroutine build_request_from_accepted(a, hphi, bottom_head, req)
    type(gc_low01_accepted_state_t), intent(in) :: a
    real(real64), intent(in) :: hphi, bottom_head
    type(soil_water_solve_request_t), intent(out) :: req

    req = soil_water_solve_request_t()
    req%parameters => parameters
    req%base_state%active_nodes = n
    allocate(req%base_state%pressure_head(n), req%base_state%water_content(n))
    req%base_state%pressure_head = a%pressure_head_cm
    req%base_state%water_content = a%water_content
    req%base_state%ponding_depth = a%ponding_depth_cm
    req%base_state%groundwater_level = a%solver_groundwater_level_compat_cm
    req%step_duration = dt
    req%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%top_flux = 0.0_real64
    req%boundary%top_head = a%pressure_head_cm(1)
    req%boundary%bottom_mode = 5
    req%boundary%bottom_head = bottom_head
    req%boundary%bottom_flux = 0.0_real64
    req%physical%macropore_active = .false.
    req%numerical%max_iterations = 24
    req%numerical%max_backtracking = 8
    req%numerical%conductivity_implicit_mode = 0
    req%numerical%conductivity_mean_method = 1
    req%numerical%min_step_duration = 1.0e-12_real64
    req%numerical%compartment_balance_tolerance = 1.0e-10_real64
    req%numerical%total_balance_tolerance = 1.0e-10_real64
    req%numerical%head_abs_tolerance = 1.0e-10_real64
    req%numerical%head_rel_tolerance = 1.0e-10_real64
    req%numerical%ponding_tolerance = 1.0e-10_real64
    req%evaluation%constitutive => constitutive
    req%evaluation%source_sink => source_sink
    req%evaluation%top_boundary => top_provider

    ! hphi is deliberately not written into req%base_state%groundwater_level.
    ! It is the LOW01 control coordinate, while this mode-5 substrate preserves
    ! the solver compatibility state from the immutable accepted origin.
    call require(hphi < bottom_face, 'trial H_phreatic remains below profile')
  end subroutine build_request_from_accepted

  subroutine verify_candidate_contract(cand, hphi, expected_hbot, name)
    type(gc_low01_candidate_t), intent(in) :: cand
    real(real64), intent(in) :: hphi, expected_hbot
    character(len=*), intent(in) :: name

    call require(cand%available, name//' candidate available')
    call require(same_real_bits(cand%requested_hphreatic_cm, hphi), name//' requested Hphi')
    call require(same_real_bits(cand%effective_hphreatic_cm, hphi), name//' effective Hphi')
    call require(cand%branch_id == GC_LOW01_BRANCH_BELOW_BOTTOM_NODE, name//' branch')
    call require(cand%active_nodes == n, name//' active nodes')
    call require(cand%fllowgwl_equivalent, name//' fllow equivalent')
    call require(same_real_bits(cand%hbot_cm, expected_hbot), name//' hbot')
    call require(trim(cand%qbot_materialization_route) == GC_LOW01_QBOT_ROUTE_MODE5_MATERIALIZED, name//' qbot route')
    call require(.not. cand%derived_profile_gwl_available, name//' derived GWL unavailable')
    call require(cand%alternative_solver_calls == 0, name//' no alternative solver')
    call require(.not. cand%retry_advised, name//' no retry')
    call require(abs(cand%integrated_mass_residual_cm) <= mass_tol, name//' candidate mass')
  end subroutine verify_candidate_contract

  subroutine copy_accepted(source, target)
    type(gc_low01_accepted_state_t), intent(in) :: source
    type(gc_low01_accepted_state_t), intent(out) :: target

    target%revision = source%revision
    target%accepted_interface_mass_cm = source%accepted_interface_mass_cm
    allocate(target%pressure_head_cm(size(source%pressure_head_cm)), target%water_content(size(source%water_content))
    target%pressure_head_cm = source%pressure_head_cm
    target%water_content = source%water_content
    target%ponding_depth_cm = source%ponding_depth_cm
    target%solver_groundwater_level_compat_cm = source%solver_groundwater_level_compat_cm
  end subroutine copy_accepted

  logical function same_accepted_bits(a, b) result(ok)
    type(gc_low01_accepted_state_t), intent(in) :: a, b

    ok = .false.
    if (a%revision /= b%revision) return
    if (.not. same_real_bits(a%accepted_interface_mass_cm, b%accepted_interface_mass_cm)) return
    if (.not. same_real_bits_array(a%pressure_head_cm, b%pressure_head_cm)) return
    if (.not. same_real_bits_array(a%water_content, b%water_content)) return
    if (.not. same_real_bits(a%ponding_depth_cm, b%ponding_depth_cm)) return
    if (.not. same_real_bits(a%solver_groundwater_level_compat_cm, b%solver_groundwater_level_compat_cm)) return
    ok = .true.
  end function same_accepted_bits

  logical function same_real_bits(a,b) result(ok)
    real(real64), intent(in) :: a,b
    ok = transfer(a,0_int64) == transfer(b,0_int64)
  end function same_real_bits

  logical function same_real_bits_array(a,b) result(ok)
    real(real64), intent(in) :: a(:),b(:)
    integer :: j
    ok = size(a) == size(b)
    if (.not. ok) return
    do j = 1, size(a)
      if (.not. same_real_bits(a(j),b(j))) then
        ok = .false.
        return
      end if
    end do
  end function same_real_bits_array

  subroutine require(condition,message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(A,1X,A)') 'GC_LOW01D_FAIL', trim(message)
      error stop 1
    end if
  end subroutine require

end program test_gc_low01d_below_profile_transaction
