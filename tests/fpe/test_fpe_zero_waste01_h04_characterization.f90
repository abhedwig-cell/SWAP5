program test_fpe_zero_waste01_h04_characterization
  use, intrinsic :: iso_fortran_env, only: real64
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

  real(real64), parameter :: h0=-75.0_real64, duration=0.25_real64
  real(real64), parameter :: hard_mass_gate=1.0e-12_real64
  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(soil_water_physical_state_t) :: initial_state
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: result
  real(real64), allocatable, target :: qdra(:,:), qssdi(:), qrot(:)
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: heads(numnod), theta(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
  real(real64) :: k0, flux_multiplier
  integer :: bottom_mode, k
  character(len=64) :: arg

  call get_command_argument(1,arg)
  read(arg,*) bottom_mode
  call get_command_argument(2,arg)
  read(arg,*) flux_multiplier

  parameters%parameter_set_id=404001
  parameters%active_nodes=numnod
  allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
  parameters%z=z
  parameters%dz=dz
  parameters%node_distance=disnod(1:numnod)

  allocate(cofgen(24,numnod))
  cofgen=0.0_real64
  do k=1,numnod
    cofgen(1,k)=0.032_real64
    cofgen(2,k)=0.423_real64
    cofgen(3,k)=4.75_real64
    cofgen(4,k)=0.0135_real64
    cofgen(5,k)=0.365_real64
    cofgen(6,k)=1.455_real64
    cofgen(7,k)=1.0_real64-1.0_real64/cofgen(6,k)
    cofgen(8,k)=cofgen(4,k)
    cofgen(9,k)=0.0_real64
    cofgen(10,k)=cofgen(3,k)
    cofgen(11,k)=0.999_real64
    cofgen(12,k)=0.99_real64*cofgen(3,k)
    cofgen(22,k)=-1.0e6_real64
    cofgen(23,k)=1.0e-12_real64
  end do
  call initialize_b110_default_mvg_parameters(hydraulic,cofgen)
  call bind_b110_default_mvg_provider(constitutive,hydraulic,duration)

  heads=h0
  call constitutive%evaluate(heads,theta,conductivity,capacity,dkdh)
  k0=conductivity(1)

  initial_state%active_nodes=numnod
  allocate(initial_state%pressure_head(numnod),initial_state%water_content(numnod))
  initial_state%pressure_head=heads
  initial_state%water_content=theta
  initial_state%ponding_depth=0.0_real64
  initial_state%groundwater_level=-2.0_real64

  allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
  qdra=0.0_real64
  qssdi=0.0_real64
  qrot=0.0_real64
  call bind_b110_source_sink_provider(source_sink,qdra,qssdi,qrot)

  request=soil_water_solve_request_t()
  request%parameters=>parameters
  request%base_state=initial_state
  request%step_duration=duration
  request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
  request%boundary%bottom_mode=bottom_mode
  request%boundary%top_flux=flux_multiplier*(-k0)
  request%boundary%top_head=h0
  request%boundary%bottom_flux=-k0
  request%boundary%bottom_head=h0
  request%physical%macropore_active=.false.
  request%numerical%max_iterations=16
  request%numerical%max_backtracking=8
  request%numerical%conductivity_implicit_mode=0
  request%numerical%conductivity_mean_method=1
  request%numerical%min_step_duration=1.0e-8_real64
  request%numerical%compartment_balance_tolerance=hard_mass_gate
  request%numerical%total_balance_tolerance=hard_mass_gate
  request%numerical%head_abs_tolerance=hard_mass_gate
  request%numerical%head_rel_tolerance=hard_mass_gate
  request%numerical%ponding_tolerance=hard_mass_gate
  request%evaluation%constitutive=>constitutive
  request%evaluation%source_sink=>source_sink
  request%evaluation%top_boundary=>top_provider

  call solver%solve(request,workspace,result)

  write(*,'(A,I0,A,F8.3,A,I0,A,L1,A,I0,A,I0,A,I0,A,I0,A,I0,A,I0,A,ES18.9)') &
       'H04_CASE,bottom_mode=',bottom_mode,',flux_multiplier=',flux_multiplier,',status=',result%status, &
       ',converged=',result%status==SW_SOLVE_CONVERGED, &
       ',iterations=',result%diagnostics%nonlinear_iterations, &
       ',evals=',result%diagnostics%constitutive_evaluations, &
       ',initial=',result%diagnostics%constitutive_initial_full_evaluations, &
       ',candidate=',result%diagnostics%constitutive_candidate_full_evaluations, &
       ',terminal=',result%diagnostics%constitutive_candidate_terminal_evaluations, &
       ',capacity_reuse=',result%diagnostics%constitutive_candidate_capacity_reuses, &
       ',mass=',result%unrounded_mass_balance_residual

  if (result%diagnostics%constitutive_evaluations /= &
      result%diagnostics%constitutive_initial_full_evaluations + &
      result%diagnostics%constitutive_candidate_full_evaluations) error stop 'H04 counter partition mismatch'
  if (result%diagnostics%constitutive_candidate_terminal_evaluations > &
      result%diagnostics%constitutive_candidate_full_evaluations) error stop 'H04 terminal count invalid'
  if (result%diagnostics%constitutive_candidate_capacity_reuses > &
      result%diagnostics%constitutive_candidate_full_evaluations) error stop 'H04 reuse count invalid'
end program test_fpe_zero_waste01_h04_characterization
