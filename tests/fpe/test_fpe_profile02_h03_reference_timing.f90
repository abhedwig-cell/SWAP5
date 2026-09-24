program test_fpe_profile02_h03_reference_timing
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM
  use mod_rossfast_d3r_execution_policy, only: ROSSFAST_D3R_OUTER_HORIZON_DAY
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: n = ROSSFAST_D3R_N_CELLS
  real(real64), parameter :: initial_head_cm = -101.0_real64
  real(real64), parameter :: reference_internal_balance_rate_tol_cm_per_day = 1.0e-12_real64
  type(soil_water_parameter_set_t), target :: parameters
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: result
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(rossfast_d3r_material_t) :: material
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top_boundary
  real(real64), target :: drainage(1,n), irrigation(n), root_sink(n)
  real(real64) :: cofgen(24,n), heads(n), theta0(n), conductivity(n), capacity(n), dkdh(n)
  character(len=64) :: arg
  integer :: calls, warmups, i, provider_status
  integer(int64) :: c0, c1, rate
  logical :: found
  real(real64) :: seconds, checksum

  call get_command_argument(1,arg); read(arg,*) calls
  if (calls <= 0) error stop 'PROFILE02 invalid call count'

  call rossfast_d3r_material_from_id('B01', material, found)
  if (.not. found) error stop 'PROFILE02 B01 unavailable'
  call initialize_parameter_contract(parameters, cofgen, material)
  call initialize_b110_default_mvg_parameters(hydraulic_parameters, cofgen)
  call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, ROSSFAST_D3R_OUTER_HORIZON_DAY)
  heads = initial_head_cm
  call constitutive%evaluate(heads, theta0, conductivity, capacity, dkdh)
  drainage=0.0_real64; irrigation=0.0_real64; root_sink=0.0_real64
  call bind_b110_source_sink_provider(source_sink, drainage, irrigation, root_sink)
  call initialize_common_request(request, parameters, constitutive, source_sink, top_boundary, theta0, conductivity(1))

  warmups=min(100,max(10,calls/100))
  do i=1,warmups
    call solver%solve(request, workspace, result)
    if (result%status /= SW_SOLVE_CONVERGED) error stop 'PROFILE02 warmup solve failed'
  end do

  checksum=0.0_real64
  call system_clock(c0,rate)
  do i=1,calls
    call solver%solve(request, workspace, result)
    if (result%status /= SW_SOLVE_CONVERGED) error stop 'PROFILE02 measured solve failed'
    checksum=checksum + result%candidate_state%pressure_head(1) + result%candidate_state%water_content(n) + &
         real(result%diagnostics%nonlinear_iterations,real64) + 1.0e-3_real64*real(result%diagnostics%constitutive_evaluations,real64)
  end do
  call system_clock(c1)
  seconds=real(c1-c0,real64)/real(rate,real64)

  write(*,'(A,I0,A,ES24.16,A,ES24.16,A,I0,A,I0,A,ES24.16)') &
       'PROFILE02_H03_TIMING,calls=',calls,',seconds=',seconds,',ns_per_solve=', &
       1.0e9_real64*seconds/real(calls,real64),',nonlinear_iterations=',result%diagnostics%nonlinear_iterations, &
       ',constitutive_evaluations=',result%diagnostics%constitutive_evaluations,',checksum=',checksum

contains
  subroutine initialize_parameter_contract(parameter_set, cofgen_out, mat)
    type(soil_water_parameter_set_t), target, intent(out) :: parameter_set
    real(real64), intent(out) :: cofgen_out(24,n)
    type(rossfast_d3r_material_t), intent(in) :: mat
    real(real64) :: m
    integer :: k
    m=1.0_real64-1.0_real64/mat%n
    parameter_set%parameter_set_id=220012
    parameter_set%active_nodes=n
    allocate(parameter_set%z(n),parameter_set%dz(n),parameter_set%node_distance(n))
    do k=1,n
      parameter_set%z(k)=-ROSSFAST_D3R_DZ_CM*(real(k,real64)-0.5_real64)
    end do
    parameter_set%dz=ROSSFAST_D3R_DZ_CM
    parameter_set%node_distance=ROSSFAST_D3R_DZ_CM
    cofgen_out=0.0_real64
    do k=1,n
      cofgen_out(1,k)=mat%theta_r; cofgen_out(2,k)=mat%theta_s
      cofgen_out(3,k)=mat%ksatfit_cm_per_day; cofgen_out(4,k)=mat%alpha_per_cm
      cofgen_out(5,k)=mat%lambda; cofgen_out(6,k)=mat%n; cofgen_out(7,k)=m
      cofgen_out(8,k)=mat%alpha_per_cm; cofgen_out(9,k)=mat%h_enpr_cm
      cofgen_out(10,k)=mat%ksatfit_cm_per_day; cofgen_out(11,k)=0.999_real64
      cofgen_out(12,k)=0.99_real64*mat%ksatfit_cm_per_day
      cofgen_out(22,k)=-1.0e6_real64; cofgen_out(23,k)=1.0e-12_real64
    end do
  end subroutine

  subroutine initialize_common_request(req, parameter_set, hydraulic_provider, source_provider, top_provider, theta, k0)
    type(soil_water_solve_request_t), intent(out) :: req
    type(soil_water_parameter_set_t), target, intent(in) :: parameter_set
    type(b110_default_mvg_provider_t), target, intent(in) :: hydraulic_provider
    type(b110_source_sink_provider_t), target, intent(in) :: source_provider
    type(fixed_flux_top_boundary_provider_t), target, intent(in) :: top_provider
    real(real64), intent(in) :: theta(n), k0
    req%parameters=>parameter_set
    req%base_state%active_nodes=n
    allocate(req%base_state%pressure_head(n),req%base_state%water_content(n))
    req%base_state%pressure_head=initial_head_cm
    req%base_state%water_content=theta
    req%base_state%ponding_depth=0.0_real64
    req%base_state%groundwater_level=-999.0_real64
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%bottom_mode=2
    req%boundary%top_flux=0.01_real64*k0
    req%boundary%top_head=initial_head_cm
    req%boundary%bottom_flux=-0.004_real64*k0
    req%boundary%bottom_head=-999999.0_real64
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=16; req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0; req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-8_real64
    req%numerical%compartment_balance_tolerance=reference_internal_balance_rate_tol_cm_per_day
    req%numerical%total_balance_tolerance=reference_internal_balance_rate_tol_cm_per_day
    req%numerical%head_abs_tolerance=1.0e-12_real64
    req%numerical%head_rel_tolerance=1.0e-12_real64
    req%numerical%ponding_tolerance=1.0e-12_real64
    req%request_interface_sensitivity=.false.
    req%evaluation%constitutive=>hydraulic_provider
    req%evaluation%source_sink=>source_provider
    req%evaluation%top_boundary=>top_provider
    req%step_duration=ROSSFAST_D3R_OUTER_HORIZON_DAY
  end subroutine
end program test_fpe_profile02_h03_reference_timing
