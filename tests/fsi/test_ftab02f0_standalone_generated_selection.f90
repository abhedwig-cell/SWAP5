program test_ftab02f0_standalone_generated_selection
  use, intrinsic :: iso_fortran_env, only: int64, real64, error_unit
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_initialize_worker
  use mod_b110_production_soil_water_task2, only: run_b110_production_task2, &
       configure_b110_standalone_generated_mvg_acceleration, &
       reset_b110_standalone_generated_mvg_acceleration, &
       b110_standalone_generated_mvg_acceleration_enabled, &
       b110_standalone_generated_mvg_cache_ready, &
       b110_standalone_generated_mvg_generation_count_value
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use MOD_swap_base, only: swdra, swfrost, swmacro, swpondmx, swrunon, swsolve
  use MOD_grid, only: numnod
  use MOD_MvG, only: cofgen, swsophy
  use MOD_meteo, only: nraidt, epond, peva, empreva
  use MOD_irrigation, only: nird, qssdi
  use MOD_snow, only: melt
  use MOD_drain, only: qdra
  use MOD_frost, only: rfcp
  use variables, only: h, theta, hm1, thetm1, pond, pondm1, gwl, gwlm1, qtop, qbot, hbot, &
       runon, epd, reva, runots, qrot, dt, swbotb, swkimpl, swkmean, maxit, maxbacktr, &
       fldecdt, pondmx, rsro, rsroexp, k, kmean, numbit, itnumb, dtmin, CritDevBalCp, CritDevBalTot, &
       critdevh2cp, critdevh1cp, critdevponddt
  implicit none

  type(a23bu_worker_context_t) :: worker
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t) :: analytic
  real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
  real(real64) :: initial_h(numnod), initial_theta(numnod)
  real(real64) :: analytical_h(numnod), analytical_theta(numnod)
  integer :: mode
  character(len=32) :: arg

  mode=0
  if (command_argument_count()>=1) then
    call get_command_argument(1,arg)
    if (trim(arg)=='neighbor-negative') mode=1
  end if

  call configure_runtime()
  call configure_hupsel_material(.false.)
  if (mode==1) then
    ! Exact-neighbor falsification: one material coefficient outside the
    ! bounded F-TAB02-G Hupsel authority must never silently fall back.
    cofgen(3,1)=cofgen(3,1)*(1.0_real64+1.0e-8_real64)
    call seed_from_current_parameters(initial_h,initial_theta)
    call reset_b110_standalone_generated_mvg_acceleration()
    call configure_b110_standalone_generated_mvg_acceleration(.true.)
    call run_b110_production_task2()
    write(*,'(A)') 'F_TAB02_F0_NEGATIVE_UNEXPECTED_RETURN'
    error stop 91
  end if

  call seed_from_current_parameters(initial_h,initial_theta)

  ! F0_1: default is disabled and does not materialize generated state.
  call reset_b110_standalone_generated_mvg_acceleration()
  call require(.not. b110_standalone_generated_mvg_acceleration_enabled(),'default generated selection disabled')
  call restore_state(initial_h,initial_theta)
  call run_b110_production_task2()
  call require(.not. b110_standalone_generated_mvg_cache_ready(),'default path owns no generated cache')
  call require(b110_standalone_generated_mvg_generation_count_value()==0,'default path generation count zero')
  analytical_h=h
  analytical_theta=theta
  write(*,'(A)') 'F_TAB02_F0_DEFAULT_ANALYTICAL_NO_GENERATION=PASS'

  ! Explicit-worker path remains analytical even while standalone opt-in is set.
  call reset_b110_standalone_generated_mvg_acceleration()
  call configure_b110_standalone_generated_mvg_acceleration(.true.)
  call a23bu_initialize_worker(worker,numnod,702)
  call restore_state(initial_h,initial_theta)
  call run_b110_production_task2(worker)
  call require(worker%soil_water_trial%typed_attempted,'explicit worker typed route')
  call require(b110_standalone_generated_mvg_generation_count_value()==0,'worker path cannot materialize standalone cache')
  call require(.not. b110_standalone_generated_mvg_cache_ready(),'worker path cannot own standalone cache')
  write(*,'(A)') 'F_TAB02_F0_WORKER_PATH_ANALYTICAL=PASS'

  ! F0_2/F0_3: exact Hupsel opt-in binds generated provider and materializes once.
  call restore_state(initial_h,initial_theta)
  call run_b110_production_task2()
  call require(b110_standalone_generated_mvg_cache_ready(),'generated cache ready')
  call require(b110_standalone_generated_mvg_generation_count_value()==1,'first generation exactly once')
  call require(maxval(abs(h-analytical_h))<5.0e-2_real64,'generated head bounded against analytical')
  call require(maxval(abs(theta-analytical_theta))<2.0e-2_real64,'generated theta bounded against analytical')

  call restore_state(initial_h,initial_theta)
  call run_b110_production_task2()
  call require(b110_standalone_generated_mvg_generation_count_value()==1,'unchanged authority cache reused')
  write(*,'(A)') 'F_TAB02_F0_EXACT_HUPSEL_GENERATED_BIND=PASS'
  write(*,'(A)') 'F_TAB02_F0_SINGLE_GENERATION_REUSE=PASS'

  ! F0_4: a different but still admitted exact Hupsel material authority
  ! invalidates the cache and deterministically rebuilds once.
  call configure_hupsel_material(.true.)
  call seed_from_current_parameters(initial_h,initial_theta)
  call restore_state(initial_h,initial_theta)
  call run_b110_production_task2()
  call require(b110_standalone_generated_mvg_generation_count_value()==2,'exact parameter mutation rebuilds cache')
  call require(b110_standalone_generated_mvg_cache_ready(),'rebuilt cache ready')
  write(*,'(A)') 'F_TAB02_F0_EXACT_PARAMETER_INVALIDATION_REBUILD=PASS'

  call reset_b110_standalone_generated_mvg_acceleration()
  call require(.not. b110_standalone_generated_mvg_acceleration_enabled(),'reset disables standalone generated route')
  call require(.not. b110_standalone_generated_mvg_cache_ready(),'reset releases numerical cache')
  call require(b110_standalone_generated_mvg_generation_count_value()==0,'reset clears qualification counter')
  write(*,'(A)') 'F_TAB02_F0_RESET_RELEASES_NUMERICAL_STATE=PASS'
  write(*,'(A)') 'F-TAB02-F0 STANDALONE SELECTION LIFETIME GATE PASS'

contains

  subroutine configure_runtime()
    swmacro=0; swdra=1; swpondmx=0; swfrost=0; swrunon=0; swsolve=1
    swsophy=0; swbotb=6; swkimpl=0; swkmean=1
    dt=1.0e-3_real64; dtmin=1.0e-8_real64
    maxit=30; maxbacktr=8
    CritDevBalCp=1.0e-8_real64; CritDevBalTot=1.0e-8_real64
    critdevh2cp=1.0e-8_real64; critdevh1cp=1.0e-8_real64; critdevponddt=1.0e-8_real64
    pondmx=10.0_real64; rsro=0.5_real64; rsroexp=1.0_real64
    qrot=0.0_real64; qdra=0.0_real64; qssdi=0.0_real64; rfcp=1.0_real64
    nraidt=0.0_real64; nird=0.0_real64; melt=0.0_real64
    epond=0.0_real64; peva=0.0_real64; empreva=0.0_real64
    runon=0.0_real64; epd=0.0_real64; reva=0.0_real64; runots=0.0_real64
    pond=0.0_real64; pondm1=0.0_real64; gwl=-2.0_real64; gwlm1=gwl
    qtop=0.0_real64; qbot=0.0_real64; hbot=-100.0_real64
    fldecdt=.false.; numbit=0; itnumb=0; kmean=1.0_real64
  end subroutine configure_runtime

  subroutine configure_hupsel_material(lower)
    logical, intent(in) :: lower
    real(real64) :: ores,osat,ksat,alpha,lexp,npar,ksatexm,m,se,term,kthreshold
    integer :: j
    if (lower) then
      ores=0.02_real64; osat=0.3870640000000001_real64; ksat=22.76176_real64
      alpha=0.016083_real64; lexp=2.4396619999999993_real64; npar=1.524418_real64
      ksatexm=227.61759999999998_real64
    else
      ores=0.02_real64; osat=0.433878_real64; ksat=83.24164_real64
      alpha=0.021645_real64; lexp=7.202077_real64; npar=1.34877_real64
      ksatexm=832.4163_real64
    end if
    m=1.0_real64-1.0_real64/npar
    se=(1.0_real64+abs(alpha*(-2.0_real64))**npar)**(-m)
    term=(1.0_real64-se**(1.0_real64/m))**m
    kthreshold=ksat*se**lexp*(1.0_real64-term)**2
    cofgen=0.0_real64
    do j=1,numnod+1
      cofgen(1,j)=ores; cofgen(2,j)=osat; cofgen(3,j)=ksat
      cofgen(4,j)=alpha; cofgen(5,j)=lexp; cofgen(6,j)=npar
      cofgen(7,j)=m; cofgen(8,j)=alpha; cofgen(9,j)=0.0_real64
      cofgen(10,j)=ksatexm; cofgen(11,j)=se; cofgen(12,j)=kthreshold
      cofgen(13,j)=0.10_real64; cofgen(14,j)=1.50_real64; cofgen(15,j)=0.50_real64
      cofgen(22,j)=-1.0e6_real64; cofgen(23,j)=1.0e-12_real64
    end do
  end subroutine configure_hupsel_material

  subroutine seed_from_current_parameters(head0,theta0)
    real(real64), intent(out) :: head0(:),theta0(:)
    real(real64) :: kval(numnod)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen(:,1:numnod),enable_ksatexm_extension=.true.)
    call bind_b110_default_mvg_provider(analytic,hydraulic_parameters,dt)
    heads=-75.0_real64
    call analytic%evaluate(heads,water,conductivity,capacity,dkdh)
    head0=heads; theta0=water; kval=conductivity
    k=kval
  end subroutine seed_from_current_parameters

  subroutine restore_state(head0,theta0)
    real(real64), intent(in) :: head0(:),theta0(:)
    h=head0; theta=theta0; hm1=h; thetm1=theta
    pond=0.0_real64; pondm1=0.0_real64
    gwl=-2.0_real64; gwlm1=gwl
    qtop=0.0_real64; qbot=0.0_real64; hbot=-100.0_real64
    runon=0.0_real64; epd=0.0_real64; reva=0.0_real64; runots=0.0_real64
    nraidt=0.0_real64; nird=0.0_real64; melt=0.0_real64
    epond=0.0_real64; peva=0.0_real64; empreva=0.0_real64
    qrot=0.0_real64; qdra=0.0_real64; qssdi=0.0_real64; rfcp=1.0_real64
    fldecdt=.false.; numbit=0; itnumb=0; kmean=1.0_real64
  end subroutine restore_state

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(error_unit,'(A,1X,A)') 'F_TAB02_F0_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ftab02f0_standalone_generated_selection
