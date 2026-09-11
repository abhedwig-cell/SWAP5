program test_fgc07_temporal_coupling
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: initial_head_cm = -100.0_real64
  real(real64), parameter :: horizon_day = 1.0_real64
  real(real64), parameter :: origin_day = 4100.125_real64
  real(real64), parameter :: hard_swap_mass_gate_cm = 1.0e-10_real64
  real(real64), parameter :: hard_interface_mass_gate_cm = 128.0_real64*epsilon(1.0_real64)
  integer, parameter :: max_correctors = 4

  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(soil_water_physical_state_t) :: initial_state
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: sy, coupling_dt, conductivity0
  integer :: n_internal
  character(len=16) :: scheme

  call read_inputs(sy, coupling_dt, n_internal, scheme)
  call configure_problem(parameters, hydraulic_parameters, constitutive, source_sink, initial_state, &
       drainage, subsurface, root_sink, cofgen, conductivity0)
  call run_trajectory(sy, coupling_dt, n_internal, trim(scheme), conductivity0)

contains

  subroutine read_inputs(storage_coefficient, dtc, nsub, method)
    real(real64), intent(out) :: storage_coefficient, dtc
    integer, intent(out) :: nsub
    character(len=*), intent(out) :: method
    character(len=128) :: arg
    integer :: stat
    if (command_argument_count() /= 4) error stop 'F-GC07 requires Sy DeltaT n_internal scheme'
    call get_command_argument(1,arg); read(arg,*,iostat=stat) storage_coefficient
    if (stat /= 0 .or. storage_coefficient <= 0.0_real64) error stop 'bad Sy'
    call get_command_argument(2,arg); read(arg,*,iostat=stat) dtc
    if (stat /= 0 .or. dtc <= 0.0_real64) error stop 'bad DeltaT'
    call get_command_argument(3,arg); read(arg,*,iostat=stat) nsub
    if (stat /= 0 .or. nsub <= 0) error stop 'bad n_internal'
    call get_command_argument(4,method)
    method = adjustl(method)
    if (trim(method) /= 'PRED' .and. trim(method) /= 'PC1' .and. trim(method) /= 'PC4') then
      error stop 'scheme must be PRED, PC1 or PC4'
    end if
  end subroutine read_inputs

  subroutine configure_problem(p, hp, cp, sp, state, qdra, qssdi, qrot, c, k0)
    type(soil_water_parameter_set_t), target, intent(out) :: p
    type(b110_default_mvg_parameters_t), target, intent(out) :: hp
    type(b110_default_mvg_provider_t), target, intent(out) :: cp
    type(b110_source_sink_provider_t), target, intent(out) :: sp
    type(soil_water_physical_state_t), intent(out) :: state
    real(real64), allocatable, target, intent(out) :: qdra(:,:), qssdi(:), qrot(:)
    real(real64), allocatable, intent(out) :: c(:,:)
    real(real64), intent(out) :: k0
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: k

    p%parameter_set_id = 700701_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)

    allocate(c(24,numnod))
    c = 0.0_real64
    do k = 1, numnod
      c(1,k)=0.032_real64; c(2,k)=0.423_real64; c(3,k)=4.75_real64
      c(4,k)=0.0135_real64; c(5,k)=0.365_real64; c(6,k)=1.455_real64
      c(7,k)=1.0_real64-1.0_real64/c(6,k); c(8,k)=c(4,k)
      c(9,k)=0.0_real64; c(10,k)=c(3,k); c(11,k)=0.999_real64
      c(12,k)=0.99_real64*c(3,k); c(22,k)=-1.0e6_real64; c(23,k)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,c)
    call bind_b110_default_mvg_provider(cp,hp,1.0_real64/128.0_real64)
    heads = initial_head_cm
    call cp%evaluate(heads,water,conductivity,capacity,dkdh)
    call require(all(ieee_is_finite(water)) .and. all(ieee_is_finite(conductivity)), 'finite bootstrap hydraulics')
    call require(all(conductivity > 0.0_real64), 'positive bootstrap conductivity')
    k0 = conductivity(1)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64

    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
    qdra = 0.0_real64
    qssdi = 0.0_real64
    qrot = 0.0_real64
    call bind_b110_source_sink_provider(sp,qdra,qssdi,qrot)
  end subroutine configure_problem

  subroutine run_trajectory(storage_coefficient, dtc, nsub, method, top_k)
    real(real64), intent(in) :: storage_coefficient, dtc, top_k
    integer, intent(in) :: nsub
    character(len=*), intent(in) :: method
    type(soil_water_physical_state_t) :: state, base_state, predictor_state, trial_state
    real(real64) :: hgw, h0, candidate_h, hnext, qvol, accepted_qvol
    real(real64) :: cumulative_qswap, cumulative_qgw_normal
    real(real64) :: max_swap_mass, max_aquifer_mass, max_head_residual, interface_mass_residual
    real(real64) :: trial_mass, aquifer_mass, residual, res_by_iter(0:max_correctors)
    integer :: nwin, w, iter, trials, nonlinear, linear, jacobians, retries
    integer :: t_nl, t_linear, t_jac, t_retry
    logical :: ok

    nwin = nint(horizon_day/dtc)
    call require(nwin > 0, 'positive number of windows')
    call require(abs(real(nwin,real64)*dtc-horizon_day) <= 64.0_real64*epsilon(1.0_real64), &
         'DeltaT divides one-day research horizon')

    state = initial_state
    hgw = initial_head_cm
    cumulative_qswap = 0.0_real64
    cumulative_qgw_normal = 0.0_real64
    max_swap_mass = 0.0_real64
    max_aquifer_mass = 0.0_real64
    max_head_residual = 0.0_real64
    res_by_iter = 0.0_real64
    trials = 0; nonlinear = 0; linear = 0; jacobians = 0; retries = 0

    do w = 1, nwin
      base_state = state
      h0 = hgw

      call swap_trial(base_state,h0,dtc,nsub,top_k,predictor_state,qvol,trial_mass,t_nl,t_linear,t_jac,t_retry,ok)
      call require(ok, 'predictor SWAP trial')
      trials = trials + 1; nonlinear = nonlinear + t_nl; linear = linear + t_linear
      jacobians = jacobians + t_jac; retries = retries + t_retry
      max_swap_mass = max(max_swap_mass,trial_mass)
      hnext = h0 + qvol/storage_coefficient
      aquifer_mass = abs(storage_coefficient*(hnext-h0)-qvol)
      max_aquifer_mass = max(max_aquifer_mass,aquifer_mass)
      residual = h0-hnext
      res_by_iter(0) = max(res_by_iter(0),abs(residual))

      if (trim(method) == 'PRED') then
        state = predictor_state
        hgw = hnext
        accepted_qvol = qvol
        max_head_residual = max(max_head_residual,abs(residual))
      else
        candidate_h = hnext
        do iter = 1, merge(1,max_correctors,trim(method) == 'PC1')
          call swap_trial(base_state,candidate_h,dtc,nsub,top_k,trial_state,qvol,trial_mass, &
               t_nl,t_linear,t_jac,t_retry,ok)
          call require(ok, 'corrector SWAP trial')
          trials = trials + 1; nonlinear = nonlinear + t_nl; linear = linear + t_linear
          jacobians = jacobians + t_jac; retries = retries + t_retry
          max_swap_mass = max(max_swap_mass,trial_mass)
          hnext = h0 + qvol/storage_coefficient
          aquifer_mass = abs(storage_coefficient*(hnext-h0)-qvol)
          max_aquifer_mass = max(max_aquifer_mass,aquifer_mass)
          residual = candidate_h-hnext
          res_by_iter(iter) = max(res_by_iter(iter),abs(residual))
          trial_state%groundwater_level = hnext*0.01_real64
          if (iter < merge(1,max_correctors,trim(method) == 'PC1')) candidate_h = hnext
        end do
        state = trial_state
        hgw = hnext
        accepted_qvol = qvol
        max_head_residual = max(max_head_residual,abs(residual))
      end if

      cumulative_qswap = cumulative_qswap + accepted_qvol
      cumulative_qgw_normal = cumulative_qgw_normal - accepted_qvol
    end do

    interface_mass_residual = cumulative_qswap + cumulative_qgw_normal
    call require(max_swap_mass <= hard_swap_mass_gate_cm, 'hard SWAP mass closure')
    call require(max_aquifer_mass <= hard_interface_mass_gate_cm*max(1.0_real64,abs(cumulative_qswap)), &
         'simple aquifer storage identity')
    call require(abs(interface_mass_residual) <= hard_interface_mass_gate_cm*max(1.0_real64,abs(cumulative_qswap)), &
         'q_SWAP equals negative q_GW cumulatively')

    write(*,'(A,ES24.15E3,A,ES24.15E3,A,I0,A,A,A,ES24.15E3,A,ES24.15E3,A,ES24.15E3,A,ES24.15E3,A,ES24.15E3,A,I0,A,I0,A,I0,A,I0,A,I0,A,ES24.15E3,A,ES24.15E3,A,ES24.15E3,A,ES24.15E3,A,ES24.15E3)') &
         'FGC07_RESULT:SY=',storage_coefficient,':DTC=',dtc,':NINT=',nsub,':SCHEME=',trim(method), &
         ':FINAL_H_CM=',hgw,':CUM_QSWAP_CM=',cumulative_qswap,':MAX_HEAD_RES_CM=',max_head_residual, &
         ':MAX_SWAP_MASS_CM=',max_swap_mass,':INTERFACE_MASS_CM=',interface_mass_residual, &
         ':TRIALS=',trials,':NONLINEAR=',nonlinear,':LINEAR=',linear,':JAC=',jacobians,':RETRIES=',retries, &
         ':R0_CM=',res_by_iter(0),':R1_CM=',res_by_iter(1),':R2_CM=',res_by_iter(2), &
         ':R3_CM=',res_by_iter(3),':R4_CM=',res_by_iter(4)
    write(*,'(A,ES24.15E3,A,ES24.15E3,A,ES24.15E3,A,ES24.15E3)') &
         'FGC07_META:ORIGIN_DAY=',origin_day,':HORIZON_DAY=',horizon_day,':TOP_FLUX_CM_DAY=',-top_k, &
         ':MAX_AQUIFER_MASS_CM=',max_aquifer_mass
    write(*,'(A)') 'FGC07_TEMPORAL_COUPLING_CASE PASS'
  end subroutine run_trajectory

  subroutine swap_trial(base_state,bottom_head,window_dt,nsub,top_k,end_state,qswap_volume,max_mass, &
                        nonlinear,linear,jacobians,retries,ok)
    type(soil_water_physical_state_t), intent(in) :: base_state
    real(real64), intent(in) :: bottom_head, window_dt, top_k
    integer, intent(in) :: nsub
    type(soil_water_physical_state_t), intent(out) :: end_state
    real(real64), intent(out) :: qswap_volume, max_mass
    integer, intent(out) :: nonlinear,linear,jacobians,retries
    logical, intent(out) :: ok
    type(soil_water_physical_state_t) :: local_state
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    real(real64) :: step_dt, storage0, storage1, total_in, total_out, manual_mass
    integer :: j

    ok = .false.
    local_state = base_state
    step_dt = window_dt/real(nsub,real64)
    qswap_volume = 0.0_real64
    max_mass = 0.0_real64
    nonlinear = 0; linear = 0; jacobians = 0; retries = 0

    do j = 1, nsub
      call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,step_dt)
      request = soil_water_solve_request_t()
      request%parameters => parameters
      request%base_state = local_state
      request%step_duration = step_dt
      request%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
      request%boundary%bottom_mode = 5
      request%boundary%top_flux = -top_k
      request%boundary%top_head = local_state%pressure_head(1)
      request%boundary%bottom_flux = 12345.678_real64
      request%boundary%bottom_head = bottom_head
      request%physical%macropore_active = .false.
      request%numerical%max_iterations = 8
      request%numerical%max_backtracking = 4
      request%numerical%conductivity_implicit_mode = 0
      request%numerical%conductivity_mean_method = 1
      request%numerical%min_step_duration = 1.0e-8_real64
      request%numerical%compartment_balance_tolerance = 1.0e-12_real64
      request%numerical%total_balance_tolerance = 1.0e-12_real64
      request%numerical%head_abs_tolerance = 1.0e-12_real64
      request%numerical%head_rel_tolerance = 1.0e-12_real64
      request%numerical%ponding_tolerance = 1.0e-12_real64
      request%evaluation%constitutive => constitutive
      request%evaluation%source_sink => source_sink
      request%evaluation%top_boundary => top_provider

      storage0 = sum(local_state%water_content*parameters%dz)+local_state%ponding_depth
      call solver%solve(request,workspace,result)
      if (result%status /= SW_SOLVE_CONVERGED) return
      storage1 = sum(result%candidate_state%water_content*parameters%dz)+result%candidate_state%ponding_depth
      total_in = max(0.0_real64,-result%top_flux)*step_dt + max(0.0_real64,result%bottom_flux)*step_dt
      total_out = max(0.0_real64,result%top_flux)*step_dt + max(0.0_real64,-result%bottom_flux)*step_dt
      manual_mass = storage1-storage0-(total_in-total_out)
      max_mass = max(max_mass,abs(manual_mass),abs(result%unrounded_mass_balance_residual))
      if (.not. ieee_is_finite(max_mass)) return
      if (max_mass > hard_swap_mass_gate_cm) return
      qswap_volume = qswap_volume - result%bottom_flux*step_dt
      nonlinear = nonlinear + result%diagnostics%nonlinear_iterations
      linear = linear + result%diagnostics%linear_solves
      jacobians = jacobians + result%diagnostics%jacobian_builds
      retries = retries + result%diagnostics%internal_retries
      local_state = result%candidate_state
    end do
    end_state = local_state
    ok = .true.
  end subroutine swap_trial

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FGC07_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fgc07_temporal_coupling
