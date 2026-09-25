program test_ahl27_production_provider_extract
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
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_adaptive_hydraulic_provider, only: b110_adaptive_hydraulic_provider_t, &
       bind_b110_adaptive_hydraulic_provider, b110_adaptive_hydraulic_cache_stats
  implicit none

  real(real64), parameter :: total_dt=0.25_real64, mass_gate=1.0e-12_real64
  real(real64), parameter :: h0=-75.0_real64, hbot=-50.0_real64
  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t), target :: analytical
  type(b110_adaptive_hydraulic_provider_t), target :: lookup, lookup2
  type(b110_source_sink_provider_t), target :: source_sink
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(soil_water_physical_state_t) :: initial_state
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: reference_result, candidate_result
  type(reference_richards_legacy_solver_t) :: solver_ref, solver_candidate
  type(reference_richards_legacy_workspace_t) :: workspace_ref, workspace_candidate
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
  real(real64) :: k0
  character(len=512) :: label
  logical :: valid, hit1, hit2
  integer :: k, builds, hits, misses, entries

  label='selfbuilt'

  parameters%parameter_set_id=404001_int64
  parameters%active_nodes=numnod
  allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
  parameters%z=z; parameters%dz=dz; parameters%node_distance=disnod(1:numnod)

  allocate(cofgen(24,numnod)); cofgen=0.0_real64
  do k=1,numnod
    cofgen(1,k)=0.032_real64; cofgen(2,k)=0.423_real64; cofgen(3,k)=4.75_real64
    cofgen(4,k)=0.0135_real64; cofgen(5,k)=0.365_real64; cofgen(6,k)=1.455_real64
    cofgen(7,k)=1.0_real64-1.0_real64/cofgen(6,k); cofgen(8,k)=cofgen(4,k)
    cofgen(9,k)=0.0_real64; cofgen(10,k)=cofgen(3,k); cofgen(11,k)=0.999_real64
    cofgen(12,k)=0.99_real64*cofgen(3,k); cofgen(22,k)=-1.0e6_real64; cofgen(23,k)=1.0e-12_real64
  end do
  call initialize_b110_default_mvg_parameters(hp,cofgen)
  call bind_b110_default_mvg_provider(analytical,hp,total_dt)

  heads=h0
  call analytical%evaluate(heads,water,conductivity,capacity,dkdh)
  k0=conductivity(1)

  initial_state%active_nodes=numnod
  allocate(initial_state%pressure_head(numnod),initial_state%water_content(numnod))
  initial_state%pressure_head=heads; initial_state%water_content=water
  initial_state%ponding_depth=0.0_real64; initial_state%groundwater_level=-2.0_real64

  allocate(drainage(1,numnod),subsurface(numnod),root_sink(numnod))
  drainage=0.0_real64; subsurface=0.0_real64; root_sink=0.0_real64
  call bind_b110_source_sink_provider(source_sink,drainage,subsurface,root_sink)

  request=soil_water_solve_request_t()
  request%parameters=>parameters
  request%base_state=initial_state
  request%step_duration=total_dt
  request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
  request%boundary%bottom_mode=5
  request%boundary%top_flux=-k0
  request%boundary%top_head=h0
  request%boundary%bottom_flux=0.0_real64
  request%boundary%bottom_head=hbot
  request%physical%macropore_active=.false.
  request%numerical%max_iterations=8
  request%numerical%max_backtracking=4
  request%numerical%conductivity_implicit_mode=0
  request%numerical%conductivity_mean_method=1
  request%numerical%min_step_duration=1.0e-6_real64
  request%numerical%compartment_balance_tolerance=mass_gate
  request%numerical%total_balance_tolerance=mass_gate
  request%numerical%head_abs_tolerance=1.0e-12_real64
  request%numerical%head_rel_tolerance=1.0e-12_real64
  request%numerical%ponding_tolerance=1.0e-12_real64
  request%evaluation%source_sink=>source_sink
  request%evaluation%top_boundary=>top_provider

  request%evaluation%constitutive=>analytical
  call solver_ref%solve(request,workspace_ref,reference_result)
  call require(reference_result%status==SW_SOLVE_CONVERGED,'analytical solve converged')

  call bind_b110_adaptive_hydraulic_provider(lookup,hp,total_dt,valid,hit1)
  call require(valid,'first self-built provider bound')
  call require(.not.hit1,'first bind builds')
  call bind_b110_adaptive_hydraulic_provider(lookup2,hp,total_dt,valid,hit2)
  call require(valid,'second self-built provider bound')
  call require(hit2,'second bind hits cache')
  call b110_adaptive_hydraulic_cache_stats(builds,hits,misses,entries)
  call require(builds==1,'one self-build')
  call require(hits==1,'one cache hit')
  call require(misses==1,'one cache miss')
  call require(entries==1,'one cached entry')
  request%evaluation%constitutive=>lookup
  request%base_state=initial_state
  call solver_candidate%solve(request,workspace_candidate,candidate_result)
  call require(candidate_result%status==SW_SOLVE_CONVERGED,'lookup solve converged')

  call verify_heterogeneous_provider_rejected()
  call report_and_gate(trim(label),reference_result,candidate_result)

contains

  subroutine verify_heterogeneous_provider_rejected()
    type(b110_default_mvg_parameters_t),target :: heterogeneous_parameters
    type(b110_adaptive_hydraulic_provider_t) :: heterogeneous_provider
    real(real64),allocatable :: heterogeneous_cofgen(:,:)
    logical :: heterogeneous_ok, heterogeneous_hit
    integer :: before_builds,before_hits,before_misses,before_entries
    integer :: after_builds,after_hits,after_misses,after_entries

    call require(numnod>=2,'heterogeneous provider regression requires at least two nodes')
    allocate(heterogeneous_cofgen(24,numnod))
    heterogeneous_cofgen=cofgen
    heterogeneous_cofgen(3,2)=0.5_real64*heterogeneous_cofgen(3,2)
    heterogeneous_cofgen(10,2)=heterogeneous_cofgen(3,2)
    heterogeneous_cofgen(12,2)=0.99_real64*heterogeneous_cofgen(3,2)
    call initialize_b110_default_mvg_parameters(heterogeneous_parameters,heterogeneous_cofgen)
    call b110_adaptive_hydraulic_cache_stats(before_builds,before_hits,before_misses,before_entries)
    call bind_b110_adaptive_hydraulic_provider(heterogeneous_provider,heterogeneous_parameters,total_dt, &
         heterogeneous_ok,heterogeneous_hit)
    call b110_adaptive_hydraulic_cache_stats(after_builds,after_hits,after_misses,after_entries)
    call require(.not.heterogeneous_ok,'heterogeneous hydraulic profile must fail adaptive bind')
    call require(.not.heterogeneous_hit,'heterogeneous hydraulic profile cannot be a cache hit')
    call require(after_builds==before_builds .and. after_hits==before_hits .and. &
         after_misses==before_misses .and. after_entries==before_entries, &
         'heterogeneous rejection must not touch adaptive cache')
    write(*,'(A)') 'FAHL42_HETEROGENEOUS_PROVIDER_FAIL_CLOSED=PASS'
  end subroutine verify_heterogeneous_provider_rejected

  subroutine report_and_gate(name,ref,cand)
    character(len=*), intent(in) :: name
    type(soil_water_solve_result_t), intent(in) :: ref,cand
    real(real64) :: dh,dw,dtf,dbf,mass
    integer :: diter, dbt
    dh=maxval(abs(cand%candidate_state%pressure_head-ref%candidate_state%pressure_head))
    dw=maxval(abs(cand%candidate_state%water_content-ref%candidate_state%water_content))
    dtf=abs(cand%top_flux-ref%top_flux)
    dbf=abs(cand%bottom_flux-ref%bottom_flux)
    diter=abs(cand%diagnostics%nonlinear_iterations-ref%diagnostics%nonlinear_iterations)
    dbt=abs(cand%diagnostics%backtracking_attempts-ref%diagnostics%backtracking_attempts)
    if (cand%integrated_mass_balance_residual_available) then
      mass=abs(cand%integrated_mass_balance_residual_cm)
    else
      mass=abs(cand%unrounded_mass_balance_residual)
    end if

    ! Measurement only. The preregistered F-AHL04A contract is applied after
    ! all three candidates have executed, so an early baseline failure cannot
    ! hide later candidate evidence and gate values cannot drift in this test.
    write(*,'(A,1X,A,1X,A,ES14.6,1X,A,ES14.6,1X,A,ES14.6,1X,A,ES14.6,1X,A,ES14.6,1X,A,I0,1X,A,I0)') &
         'AHL27_METRIC',trim(name),'MAX_DH_CM=',dh,'MAX_DTHETA=',dw,'DTOP=',dtf,'DBOTTOM=',dbf,'MASS=',mass, &
         'ITER_DELTA=',diter,'BACKTRACK_DELTA=',dbt
    write(*,'(A,1X,A,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,I0)') &
         'AHL27_DIAG',trim(name),'REF_ITER=',ref%diagnostics%nonlinear_iterations, &
         'CAND_ITER=',cand%diagnostics%nonlinear_iterations,'REF_BACKTRACK=',ref%diagnostics%backtracking_attempts, &
         'CAND_BACKTRACK=',cand%diagnostics%backtracking_attempts
    call require(dh<=0.05_real64,'pressure-head gate')
    call require(dw<=1.0e-4_real64,'water-content gate')
    call require(dtf<=1.0e-5_real64,'top-flux gate')
    call require(dbf<=1.0e-5_real64,'bottom-flux gate')
    call require(mass<=mass_gate,'mass gate')
    call require(cand%diagnostics%nonlinear_iterations==ref%diagnostics%nonlinear_iterations,'same nonlinear iterations')
    call require(cand%diagnostics%backtracking_attempts==ref%diagnostics%backtracking_attempts,'same backtracking count')
    write(*,'(A,1X,A,1X,A)') 'AHL27',trim(name),'PASS'
    write(*,'(A,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,I0)') 'AHL27_CACHE_STATS','BUILDS=',builds,'HITS=',hits,'MISSES=',misses,'ENTRIES=',entries
  end subroutine report_and_gate

  subroutine require(condition,message)
    logical,intent(in)::condition
    character(len=*),intent(in)::message
    if(.not.condition) then
      write(*,'(A,1X,A)') 'AHL27_FAIL',trim(message)
      error stop 1
    end if
  end subroutine require

end program test_ahl27_production_provider_extract
