program test_ppa_wu05a4_controller_crack_rapid_trajectory
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_macropore_continuation_state, only: macropore_continuation_state_t
  use mod_ppa_wu05a4_r2_macropore_process, only: ppa_wu05a4_r2_process_t
  use mod_ppa_wu05a4_outer_coupling_controller, only: ppa_wu05a4_outer_coupling_controller_t, &
       ppa_wu05a4_coupling_policy_t, ppa_wu05a4_coupled_result_t, PPA_COUPLED_CONVERGED
  implicit none

  integer, parameter :: nsteps=4
  real(real64), parameter :: dt=0.05_real64, tol=1.0e-12_real64

  type(soil_water_parameter_set_t), target :: params
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t), target :: hyd
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(soil_water_solve_request_t) :: request
  type(macropore_continuation_state_t) :: macro
  type(ppa_wu05a4_r2_process_t) :: process
  type(ppa_wu05a4_outer_coupling_controller_t) :: controller
  type(ppa_wu05a4_coupling_policy_t) :: policy
  type(ppa_wu05a4_coupled_result_t) :: result
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: heads(numnod),water(numnod),cond(numnod),cap(numnod),dkdh(numnod)
  real(real64) :: cumulative_external,initial_total,final_total,boundary_total
  logical :: ok
  integer :: i,step

  allocate(params%z(numnod),params%dz(numnod),params%node_distance(numnod),cofgen(24,numnod))
  params%parameter_set_id=505409_int64
  params%active_nodes=numnod
  params%z=z; params%dz=dz; params%node_distance=disnod(1:numnod)

  cofgen=0.0_real64
  do i=1,numnod
    cofgen(1,i)=0.02_real64; cofgen(2,i)=0.427494_real64; cofgen(3,i)=31.225016_real64
    cofgen(4,i)=0.021659_real64; cofgen(5,i)=0.98087_real64; cofgen(6,i)=1.734737_real64
    cofgen(7,i)=1.0_real64-1.0_real64/cofgen(6,i); cofgen(8,i)=cofgen(4,i)
    cofgen(10,i)=cofgen(3,i); cofgen(11,i)=0.999_real64; cofgen(12,i)=0.99_real64*cofgen(3,i)
    cofgen(22,i)=-1.0e6_real64; cofgen(23,i)=1.0e-12_real64
  end do
  call initialize_b110_default_mvg_parameters(hp,cofgen)
  call bind_b110_default_mvg_provider(hyd,hp,dt)

  heads=-50.0_real64
  call hyd%evaluate(heads,water,cond,cap,dkdh)

  request%parameters=>params
  request%base_state%active_nodes=numnod
  allocate(request%base_state%pressure_head(numnod),request%base_state%water_content(numnod))
  request%base_state%pressure_head=heads
  request%base_state%water_content=water
  request%base_state%ponding_depth=0.0_real64
  request%base_state%groundwater_level=-2.0_real64
  request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
  request%boundary%bottom_mode=7
  request%boundary%top_flux=0.0_real64
  request%boundary%bottom_head=-50.0_real64
  request%physical%macropore_active=.false.
  request%numerical%max_iterations=64
  request%numerical%max_backtracking=24
  request%numerical%conductivity_implicit_mode=0
  request%numerical%conductivity_mean_method=1
  request%numerical%min_step_duration=1.0e-12_real64
  request%numerical%compartment_balance_tolerance=tol
  request%numerical%total_balance_tolerance=tol
  request%numerical%head_abs_tolerance=tol
  request%numerical%head_rel_tolerance=tol
  request%numerical%ponding_tolerance=tol
  request%evaluation%constitutive=>hyd
  request%evaluation%top_boundary=>top
  request%step_duration=dt

  call macro%initialize(1,numnod,ok)
  if(.not.ok) error stop 'A4 crack/rapid trajectory macro init'
  macro%icp_bottom_domain=numnod
  macro%volume_domain_cp=0.0_real64
  macro%volume_domain_cp(1,2)=0.5_real64
  macro%water_domain_cp=0.0_real64
  macro%water_domain_cp(1,2)=0.5_real64
  macro%dynamic_volume_cp=0.0_real64
  macro%dynamic_volume_cp(2)=0.08_real64

  process%domain_index=1
  process%node_index=2
  process%sorptivity_max=0.4_real64
  process%crack_history_enabled=.true.
  process%crack_theta_threshold=0.30_real64
  process%crack_geometry_factor=3.0_real64
  process%crack_shrinkage_relative=0.05_real64
  process%matrix_fraction=0.92_real64
  process%rapid_drainage_enabled=.true.
  process%rapid_domain_bottom_cm=-100.0_real64
  process%rapid_drain_level_cm=-95.0_real64
  process%rapid_resistance_day=20.0_real64
  process%rapid_area_exponent=3.0_real64
  process%rapid_saturated_fraction=1.0_real64
  process%rapid_volume_under_drain_cm=0.0_real64
  process%rapid_reduction_factor=1.0_real64
  process%compartment_thickness_cm=10.0_real64

  policy%max_correctors=50
  policy%exchange_relative_tolerance=1.0e-8_real64
  policy%exchange_floor=1.0e-12_real64
  policy%damping_previous_weight=0.5_real64
  policy%allow_practical_cap=.false.
  policy%combined_mass_tolerance_cm=1.0e-9_real64

  initial_total=sum(request%base_state%water_content*params%dz)+sum(macro%water_domain_cp)
  cumulative_external=0.0_real64
  boundary_total=0.0_real64

  do step=1,nsteps
    call controller%execute(solver,workspace,request,macro,process,policy,result)
    if(result%status/=PPA_COUPLED_CONVERGED) error stop 'A4 crack/rapid trajectory controller'

    cumulative_external=cumulative_external+result%macropore_external_outflow_cm
    boundary_total=boundary_total+(result%bottom_flux-result%top_flux)*dt

    request%base_state=result%matrix_candidate
    macro=result%macropore_candidate

    if(abs(result%combined_mass_residual_cm)>1.0e-9_real64) error stop 'A4 crack/rapid step mass'

    write(*,'(*(g0))') 'PPA_WU05A4_CRACK_RAPID_TRAJ|STEP=',step, &
         '|CRACK=',macro%dynamic_volume_cp(2), &
         '|MACRO_WATER=',macro%water_domain_cp(1,2), &
         '|RAPID_OUT=',result%macropore_external_outflow_cm, &
         '|THETA=',request%base_state%water_content(2)
  end do

  final_total=sum(request%base_state%water_content*params%dz)+sum(macro%water_domain_cp)
  if(abs((final_total-initial_total)+cumulative_external-boundary_total)>5.0e-9_real64) &
       error stop 'A4 crack/rapid cumulative mass mismatch'
  if(macro%dynamic_volume_cp(2)<=0.0_real64) error stop 'A4 crack history vanished unexpectedly'
  if(cumulative_external<=0.0_real64) error stop 'A4 rapid drainage did not accumulate'
  if(macro%water_domain_cp(1,2)>=0.5_real64) error stop 'A4 rapid/absorption did not reduce macro storage'

  write(*,'(*(g0))') 'PPA_WU05A4_CRACK_RAPID_TRAJ_SUMMARY|CUM_RAPID=',cumulative_external, &
       '|FINAL_CRACK=',macro%dynamic_volume_cp(2), &
       '|FINAL_MACRO_WATER=',macro%water_domain_cp(1,2), &
       '|CUM_MASS_RES=',(final_total-initial_total)+cumulative_external-boundary_total
  print '(a)', 'PPA_WU05A4_CONTROLLER_CRACK_RAPID_TRAJECTORY=PASS'
end program test_ppa_wu05a4_controller_crack_rapid_trajectory
