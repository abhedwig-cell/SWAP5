program test_ppa_wu05a4_outer_controller_richards
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
       ppa_wu05a4_coupling_policy_t, ppa_wu05a4_coupled_result_t, &
       PPA_COUPLED_CONVERGED, PPA_COUPLED_PRACTICAL_CAP, PPA_COUPLED_RETRY
  implicit none

  real(real64), parameter :: dt=0.05_real64, tol=1.0e-12_real64
  real(real64), parameter :: strict_q_ref=1.7336720682531963_real64
  real(real64), parameter :: practical_q_ref=1.7693267010703861_real64

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
  type(ppa_wu05a4_coupling_policy_t) :: strict_policy, practical_policy
  type(ppa_wu05a4_coupled_result_t) :: strict_result, practical_result, retry_result
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: heads(numnod), water(numnod), cond(numnod), cap(numnod), dkdh(numnod)
  logical :: ok
  integer :: i

  allocate(params%z(numnod),params%dz(numnod),params%node_distance(numnod),cofgen(24,numnod))
  params%parameter_set_id=505407_int64
  params%active_nodes=numnod
  params%z=z
  params%dz=dz
  params%node_distance=disnod(1:numnod)

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
  if(.not.ok) error stop 'A4 controller-richards macro init'
  macro%icp_bottom_domain = numnod
  macro%volume_domain_cp = 1.2_real64
  macro%water_domain_cp = 0.0_real64
  macro%water_domain_cp(1,2) = 1.05_real64
  macro%dynamic_volume_cp = 0.0_real64

  process%domain_index=1
  process%node_index=2
  process%sorptivity_max=1.0_real64

  strict_policy%max_correctors=50
  strict_policy%exchange_relative_tolerance=1.0e-8_real64
  strict_policy%exchange_floor=1.0e-12_real64
  strict_policy%damping_previous_weight=0.5_real64
  strict_policy%allow_practical_cap=.false.
  strict_policy%combined_mass_tolerance_cm=1.0e-9_real64

  practical_policy=strict_policy
  practical_policy%max_correctors=3
  practical_policy%exchange_relative_tolerance=1.0e-3_real64
  practical_policy%allow_practical_cap=.true.

  call controller%execute(solver,workspace,request,macro,process,strict_policy,strict_result)
  if(strict_result%status/=PPA_COUPLED_CONVERGED) error stop 'A4 controller strict real-Richards failed'
  if(abs(strict_result%exchange_rate(2)-strict_q_ref)>5.0e-6_real64) &
       error stop 'A4 controller strict exchange drift'
  if(abs(strict_result%combined_mass_residual_cm)>1.0e-9_real64) &
       error stop 'A4 controller strict combined mass'

  call controller%execute(solver,workspace,request,macro,process,practical_policy,practical_result)
  if(practical_result%status/=PPA_COUPLED_PRACTICAL_CAP .and. &
       practical_result%status/=PPA_COUPLED_CONVERGED) &
       error stop 'A4 controller practical real-Richards failed'
  if(abs(practical_result%exchange_rate(2)-practical_q_ref)>5.0e-6_real64) &
       error stop 'A4 controller practical exchange drift'
  if(abs(practical_result%combined_mass_residual_cm)>1.0e-9_real64) &
       error stop 'A4 controller practical combined mass'

  ! Real retry propagation: wet/fresh high-sorptivity adversarial case.
  heads=-20.0_real64
  call hyd%evaluate(heads,water,cond,cap,dkdh)
  request%base_state%pressure_head=heads
  request%base_state%water_content=water
  request%boundary%bottom_head=-20.0_real64
  request%step_duration=0.1_real64
  call bind_b110_default_mvg_provider(hyd,hp,0.1_real64)
  process%sorptivity_max=2.0_real64
  macro%water_domain_cp=0.0_real64
  macro%water_domain_cp(1,2)=2.0_real64

  call controller%execute(solver,workspace,request,macro,process,strict_policy,retry_result)
  if(retry_result%status/=PPA_COUPLED_RETRY) error stop 'A4 controller retry not propagated'
  if(.not.retry_result%retry_advised) error stop 'A4 controller retry flag missing'

  write(*,'(*(g0))') 'PPA_WU05A4_CONTROLLER_RICHARDS|STRICT_Q=',strict_result%exchange_rate(2), &
       '|PRACTICAL_Q=',practical_result%exchange_rate(2), &
       '|STRICT_IT=',strict_result%outer_iterations, &
       '|PRACTICAL_IT=',practical_result%outer_iterations
  print '(a)', 'PPA_WU05A4_OUTER_CONTROLLER_RICHARDS=PASS'
end program test_ppa_wu05a4_outer_controller_richards
