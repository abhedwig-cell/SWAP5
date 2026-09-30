program test_ppa_wu05a4_richards_exchange
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_ppa_wu05a4_fixed_exchange_provider, only: ppa_wu05a4_fixed_exchange_provider_t
  implicit none

  real(real64), parameter :: dt=1.0e-3_real64
  real(real64), parameter :: tol=1.0e-12_real64
  type(soil_water_parameter_set_t), target :: params
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t), target :: hyd
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(ppa_wu05a4_fixed_exchange_provider_t), target :: exchange
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: result
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: heads(numnod),water(numnod),cond(numnod),cap(numnod),dkdh(numnod)
  real(real64) :: storage0,storage1,expected_exchange,expected_storage_change
  integer :: i

  allocate(params%z(numnod),params%dz(numnod),params%node_distance(numnod),cofgen(24,numnod))
  params%parameter_set_id=505401_int64
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

  heads=-100.0_real64
  call hyd%evaluate(heads,water,cond,cap,dkdh)

  allocate(exchange%source_rate(numnod),exchange%sink_rate(numnod))
  exchange%source_rate=0.0_real64
  exchange%sink_rate=0.0_real64
  exchange%source_rate(2)=0.08_real64
  expected_exchange=sum(exchange%source_rate)*dt

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
  request%boundary%bottom_head=-100.0_real64
  request%physical%macropore_active=.false.
  request%numerical%max_iterations=48
  request%numerical%max_backtracking=16
  request%numerical%conductivity_implicit_mode=0
  request%numerical%conductivity_mean_method=1
  request%numerical%min_step_duration=1.0e-12_real64
  request%numerical%compartment_balance_tolerance=tol
  request%numerical%total_balance_tolerance=tol
  request%numerical%head_abs_tolerance=tol
  request%numerical%head_rel_tolerance=tol
  request%numerical%ponding_tolerance=tol
  request%evaluation%constitutive=>hyd
  request%evaluation%source_sink=>exchange
  request%evaluation%top_boundary=>top
  request%step_duration=dt

  storage0=sum(request%base_state%water_content*params%dz)
  call solver%solve(request,workspace,result)
  if(result%status/=SW_SOLVE_CONVERGED) error stop 'A4 Richards exchange solve did not converge'
  storage1=sum(result%candidate_state%water_content*params%dz)
  expected_storage_change=(result%bottom_flux-request%boundary%top_flux+ &
       sum(exchange%source_rate)-sum(exchange%sink_rate))*dt

  write(*,'(*(g0))') 'PPA_WU05A4_RICHARDS_DIAG|DSTORAGE=',storage1-storage0, &
       '|EXCHANGE=',expected_exchange,'|BOTTOM_FLUX=',result%bottom_flux, &
       '|EXPECTED_DSTORAGE=',expected_storage_change, &
       '|SOLVER_RESIDUAL=',result%integrated_mass_balance_residual_cm

  if(abs((storage1-storage0)-expected_storage_change)>1.0e-10_real64) &
       error stop 'A4 Richards exchange full storage balance mismatch'
  if(.not.result%integrated_mass_balance_residual_available) &
       error stop 'A4 Richards exchange mass residual unavailable'
  if(abs(result%integrated_mass_balance_residual_cm)>1.0e-10_real64) &
       error stop 'A4 Richards exchange solver mass residual too large'

  print '(a)', 'PPA_WU05A4_RICHARDS_FIXED_EXCHANGE=PASS'
end program test_ppa_wu05a4_richards_exchange
