program test_bofek00_frozen_wet_trajectory
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  implicit none

  integer, parameter :: NSTEPS=24
  real(real64), parameter :: DT=10.0_real64/86400.0_real64
  real(real64), parameter :: TR=0.02_real64, TS=0.427494_real64
  real(real64), parameter :: ALPHA=0.021659_real64, NPAR=1.734737_real64
  real(real64), parameter :: KS=31.225016_real64, LAM=0.98087_real64
  real(real64), parameter :: RAIN=4.0_real64*KS
  real(real64), parameter :: PMAX=KS*DT
  real(real64), parameter :: RR=0.001_real64
  real(real64), parameter :: H0=-3.5900902059398048_real64

  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(b110_dynamic_top_boundary_solver_provider_t), target :: dynamic_top
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(soil_water_physical_state_t) :: state
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: result
  real(real64), target :: drainage(1,numnod), irrigation(numnod), root_sink(numnod)
  real(real64) :: cofgen(24,numnod)
  real(real64) :: theta(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
  real(real64) :: storage0, storage1, infiltration, runoff, ledger, cumulative_runoff
  integer :: step, i

  call configure()
  cumulative_runoff=0.0_real64

  do step=1,NSTEPS
    call constitutive%evaluate(state%pressure_head,theta,conductivity,capacity,dkdh)
    call require(all(ieee_is_finite(conductivity)) .and. conductivity(1)>0.0_real64,'finite K')

    call bind_b110_dynamic_top_boundary_solver_provider(dynamic_top, parameters, hydraulic_parameters, &
         1, state%ponding_depth, DT, RAIN, 0.0_real64, 0.0_real64, 0.0_real64, &
         0.0_real64, 0.0_real64, PMAX, RR, 1.0_real64, conductivity(1))

    request = soil_water_solve_request_t()
    request%parameters => parameters
    request%base_state = state
    request%step_duration = DT
    request%boundary%top_mode = FSI_TOP_MODE_DYNAMIC_PROVIDER
    request%boundary%bottom_mode = 7
    request%physical%macropore_active = .false.
    request%numerical%max_iterations = 32
    request%numerical%max_backtracking = 12
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
    request%evaluation%dynamic_top_boundary => dynamic_top

    storage0=sum(state%water_content*parameters%dz)+state%ponding_depth
    call solver%solve(request,workspace,result)
    call require(result%status==SW_SOLVE_CONVERGED,'fixed step converged')
    call require(all(ieee_is_finite(result%candidate_state%pressure_head)),'finite candidate heads')
    call require(all(ieee_is_finite(result%candidate_state%water_content)),'finite candidate water')

    storage1=sum(result%candidate_state%water_content*parameters%dz)+result%candidate_state%ponding_depth
    infiltration=max(0.0_real64,-result%top_flux)*DT
    runoff=RAIN*DT-(result%candidate_state%ponding_depth-state%ponding_depth)-infiltration
    cumulative_runoff=cumulative_runoff+runoff
    ledger=storage1-storage0-(RAIN*DT-runoff+result%bottom_flux*DT)

    write(*,'(*(g0))') 'BOFEK00_FROZEN|STEP=',step,'|DT=',DT,'|POND=',result%candidate_state%ponding_depth, &
         '|RUNOFF=',runoff,'|CUMRUNOFF=',cumulative_runoff,'|QTOP=',result%top_flux,'|QBOT=',result%bottom_flux, &
         '|MASS_NATIVE=',result%unrounded_mass_balance_residual,'|LEDGER=',ledger, &
         '|NEWTON=',result%diagnostics%nonlinear_iterations,'|BACKTRACK=',result%diagnostics%backtracking_attempts, &
         '|RETRIES=',result%diagnostics%internal_retries
    write(*,'(*(g0,:,","))') 'BOFEK00_HEADS', (result%candidate_state%pressure_head(i),i=1,numnod)

    state=result%candidate_state
  end do
  write(*,'(*(g0))') 'BOFEK00_FROZEN_SUMMARY|STEPS=',NSTEPS,'|CUMRUNOFF=',cumulative_runoff, &
       '|FINAL_POND=',state%ponding_depth
  write(*,'(A)') 'F_PE_BOFEK00_FROZEN_TRAJECTORY=PASS'

contains

  subroutine configure()
    real(real64) :: heads(numnod)
    integer :: k
    parameters%parameter_set_id=23001
    parameters%active_nodes=numnod
    allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
    parameters%z=z
    parameters%dz=dz
    parameters%node_distance=disnod(1:numnod)
    cofgen=0.0_real64
    do k=1,numnod
      cofgen(1,k)=TR;cofgen(2,k)=TS;cofgen(3,k)=KS;cofgen(4,k)=ALPHA;cofgen(5,k)=LAM;cofgen(6,k)=NPAR
      cofgen(7,k)=1.0_real64-1.0_real64/NPAR;cofgen(8,k)=ALPHA;cofgen(9,k)=0.0_real64;cofgen(10,k)=KS
      cofgen(11,k)=0.999_real64;cofgen(12,k)=0.99_real64*KS;cofgen(22,k)=-1.0e6_real64;cofgen(23,k)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,DT)
    heads=H0
    call constitutive%evaluate(heads,theta,conductivity,capacity,dkdh)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads
    state%water_content=theta
    state%ponding_depth=0.0_real64
    state%groundwater_level=-160.0_real64
    drainage=0.0_real64
    irrigation=0.0_real64
    root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)
  end subroutine configure

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)') 'F_PE_BOFEK00_FROZEN_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require
end program test_bofek00_frozen_wet_trajectory
