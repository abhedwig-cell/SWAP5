program test_gc_low01a2_live_below_profile
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
  type(soil_water_solve_result_t) :: result(3)
  real(real64), target :: drainage(1,n), irrigation(n), root_sink(n)
  real(real64) :: cofgen(24,n)
  real(real64) :: origin_head(n), origin_water(n), conductivity(n), capacity(n), dkdh(n)
  real(real64) :: storage0, storage1, hbot, ledger_residual(3)
  integer :: i

  call configure_parameters(parameters, cofgen)
  call initialize_b110_default_mvg_parameters(hydraulic_parameters, cofgen)
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, dt)

  origin_head = origin_hphi - z
  call constitutive%evaluate(origin_head, origin_water, conductivity, capacity, dkdh)
  call require(all(ieee_is_finite(origin_water)), 'finite origin water')
  call require(all(ieee_is_finite(conductivity)) .and. all(conductivity > 0.0_real64), 'finite positive origin K')

  drainage = 0.0_real64
  irrigation = 0.0_real64
  root_sink = 0.0_real64
  call bind_b110_source_sink_provider(source_sink, drainage, irrigation, root_sink)

  storage0 = sum(origin_water*dz)

  do i = 1, 3
    call require(trial_hphi(i) < bottom_face, trim(label(i))//' H_phreatic below bottom face')
    hbot = trial_hphi(i) - bottom_face

    request = soil_water_solve_request_t()
    request%parameters => parameters
    request%base_state%active_nodes = n
    allocate(request%base_state%pressure_head(n), request%base_state%water_content(n))
    request%base_state%pressure_head = origin_head
    request%base_state%water_content = origin_water
    request%base_state%ponding_depth = 0.0_real64
    request%base_state%groundwater_level = origin_hphi
    request%step_duration = dt
    request%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
    request%boundary%top_flux = 0.0_real64
    request%boundary%top_head = origin_head(1)
    request%boundary%bottom_mode = 5
    request%boundary%bottom_head = hbot
    request%boundary%bottom_flux = 0.0_real64
    request%physical%macropore_active = .false.
    request%numerical%max_iterations = 24
    request%numerical%max_backtracking = 8
    request%numerical%conductivity_implicit_mode = 0
    request%numerical%conductivity_mean_method = 1
    request%numerical%min_step_duration = 1.0e-12_real64
    request%numerical%compartment_balance_tolerance = 1.0e-10_real64
    request%numerical%total_balance_tolerance = 1.0e-10_real64
    request%numerical%head_abs_tolerance = 1.0e-10_real64
    request%numerical%head_rel_tolerance = 1.0e-10_real64
    request%numerical%ponding_tolerance = 1.0e-10_real64
    request%evaluation%constitutive => constitutive
    request%evaluation%source_sink => source_sink
    request%evaluation%top_boundary => top_provider

    call solver%solve(request, workspace, result(i))
    call require(result(i)%status == SW_SOLVE_CONVERGED, trim(label(i))//' mode5 solve converged')
    call require(.not. result(i)%retry_advised, trim(label(i))//' no retry')
    call require(result(i)%diagnostics%alternative_solver_calls == 0, trim(label(i))//' no alternative solver')
    call require(all(ieee_is_finite(result(i)%candidate_state%pressure_head)), trim(label(i))//' finite heads')
    call require(all(ieee_is_finite(result(i)%candidate_state%water_content)), trim(label(i))//' finite water')
    call require(ieee_is_finite(result(i)%bottom_flux), trim(label(i))//' finite qbot')

    storage1 = sum(result(i)%candidate_state%water_content*dz) + result(i)%candidate_state%ponding_depth
    ledger_residual(i) = storage1-storage0 - (-result(i)%top_flux + result(i)%bottom_flux)*dt
    call require(abs(ledger_residual(i)) <= mass_tol, trim(label(i))//' independent mass closure')

    write(*,'(A,A)') 'GC_LOW01A2_LABEL=', trim(label(i))
    write(*,'(A,ES26.17E3)') 'GC_LOW01A2_HPHI_CM=', trial_hphi(i)
    write(*,'(A,ES26.17E3)') 'GC_LOW01A2_HBOT_CM=', hbot
    write(*,'(A,ES26.17E3)') 'GC_LOW01A2_QBOT_CM_PER_DAY=', result(i)%bottom_flux
    write(*,'(A,ES26.17E3)') 'GC_LOW01A2_STORAGE_CHANGE_CM=', storage1-storage0
    write(*,'(A,ES26.17E3)') 'GC_LOW01A2_LEDGER_RESIDUAL_CM=', ledger_residual(i)
    write(*,'(A,I0)') 'GC_LOW01A2_NONLINEAR_ITERATIONS=', result(i)%diagnostics%nonlinear_iterations

    deallocate(request%base_state%pressure_head, request%base_state%water_content)
  end do

  call require(same_real_bits_array(result(1)%candidate_state%pressure_head, result(3)%candidate_state%pressure_head), &
       'A1/A2 pressure head replay bits')
  call require(same_real_bits_array(result(1)%candidate_state%water_content, result(3)%candidate_state%water_content), &
       'A1/A2 water replay bits')
  call require(same_real_bits(result(1)%bottom_flux, result(3)%bottom_flux), 'A1/A2 qbot replay bits')
  call require(same_real_bits(ledger_residual(1), ledger_residual(3)), 'A1/A2 ledger residual replay bits')
  call require(result(1)%diagnostics%nonlinear_iterations == result(3)%diagnostics%nonlinear_iterations, &
       'A1/A2 nonlinear iteration replay')
  call require(result(1)%diagnostics%linear_solves == result(3)%diagnostics%linear_solves, &
       'A1/A2 linear solve replay')

  call require(.not. same_real_bits(result(1)%bottom_flux, result(2)%bottom_flux) .or. &
       .not. same_real_bits_array(result(1)%candidate_state%pressure_head, result(2)%candidate_state%pressure_head), &
       'B differs from A physical output')

  call require(same_real_bits_array(origin_head, origin_hphi-z), 'immutable origin head retained')
  call require(all(ieee_is_finite(origin_water)), 'immutable origin water retained')

  write(*,'(A)') 'GC_LOW01A2_LIVE_MODE5_REDUCTION=PASS'
  write(*,'(A)') 'GC_LOW01A2_INDEPENDENT_MASS_LEDGER=PASS'
  write(*,'(A)') 'GC_LOW01A2_IMMUTABLE_ORIGIN_REPLAY=PASS'
  write(*,'(A)') 'GC_LOW01A2_NONVACUOUS_PERTURBATION=PASS'
  write(*,'(A)') 'GC_LOW01A2_LIVE_GATE=PASS'

contains

  subroutine configure_parameters(p, c)
    type(soil_water_parameter_set_t), target, intent(out) :: p
    real(real64), intent(out) :: c(24,n)
    integer :: j

    p%parameter_set_id = 101002_int64
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
      write(*,'(A,1X,A)') 'GC_LOW01A2_FAIL', trim(message)
      error stop 1
    end if
  end subroutine require

end program test_gc_low01a2_live_below_profile
