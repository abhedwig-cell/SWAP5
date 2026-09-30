program test_ppa_wu05a4_richards_stabilization
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

  real(real64), parameter :: tol=1.0e-12_real64,macro_water=2.0_real64
  real(real64), parameter :: wet_dts(6)=[0.1_real64,0.05_real64,0.02_real64,0.01_real64,0.005_real64,0.001_real64]
  integer, parameter :: nit=10
  type(soil_water_parameter_set_t), target :: params
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t), target :: hyd
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(ppa_wu05a4_fixed_exchange_provider_t), target :: exchange
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: predictor,result
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: heads(numnod),water(numnod),cond(numnod),cap(numnod),dkdh(numnod)
  real(real64) :: dt,amount,raw_rate,rate,prev_rate,rel_change,theta_iter
  real(real64) :: matrix0,matrix1,macro1,combined
  integer :: i,node,k,iter,wet_successes,dry_failures

  node=2
  wet_successes=0
  dry_failures=0

  allocate(params%z(numnod),params%dz(numnod),params%node_distance(numnod),cofgen(24,numnod))
  params%parameter_set_id=505405_int64
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

  allocate(exchange%source_rate(numnod),exchange%sink_rate(numnod))
  exchange%source_rate=0.0_real64
  exchange%sink_rate=0.0_real64

  request%parameters=>params
  request%base_state%active_nodes=numnod
  allocate(request%base_state%pressure_head(numnod),request%base_state%water_content(numnod))
  request%base_state%ponding_depth=0.0_real64
  request%base_state%groundwater_level=-2.0_real64
  request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
  request%boundary%bottom_mode=7
  request%boundary%top_flux=0.0_real64
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
  request%evaluation%source_sink=>exchange
  request%evaluation%top_boundary=>top

  ! Wet/fresh timestep sweep.
  do k=1,size(wet_dts)
    dt=wet_dts(k)
    call bind_b110_default_mvg_provider(hyd,hp,dt)
    heads=-20.0_real64
    call hyd%evaluate(heads,water,cond,cap,dkdh)
    request%base_state%pressure_head=heads
    request%base_state%water_content=water
    request%boundary%bottom_head=-20.0_real64
    request%step_duration=dt
    exchange%source_rate=0.0_real64

    call solver%solve(request,workspace,predictor)
    if(predictor%status/=SW_SOLVE_CONVERGED)then
      write(*,'(*(g0))') 'PPA_WU05A4_DT_FAIL|DT=',dt,'|STAGE=predictor|STATUS=',predictor%status
      cycle
    end if

    amount=sorptivity_amount(predictor%candidate_state%water_content(node),0.0_real64,0.0_real64,dt)
    amount=min(amount,macro_water)
    rate=amount/dt
    exchange%source_rate=0.0_real64
    exchange%source_rate(node)=rate
    call solver%solve(request,workspace,result)
    write(*,'(*(g0))') 'PPA_WU05A4_DT_SWEEP|DT=',dt,'|RATE=',rate,'|STATUS=',result%status, &
         '|RETRY=',result%retry_advised,'|NONLINEAR=',result%diagnostics%nonlinear_iterations, &
         '|BACKTRACK=',result%diagnostics%backtracking_attempts
    if(result%status==SW_SOLVE_CONVERGED) wet_successes=wet_successes+1
  end do

  ! Dry/fresh under-relaxed outer coupling.
  dt=0.1_real64
  call bind_b110_default_mvg_provider(hyd,hp,dt)
  heads=-200.0_real64
  call hyd%evaluate(heads,water,cond,cap,dkdh)
  request%base_state%pressure_head=heads
  request%base_state%water_content=water
  request%boundary%bottom_head=-200.0_real64
  request%step_duration=dt
  exchange%source_rate=0.0_real64
  matrix0=sum(water*params%dz)

  call solver%solve(request,workspace,predictor)
  if(predictor%status/=SW_SOLVE_CONVERGED) error stop 'A4 damping predictor failed'
  theta_iter=predictor%candidate_state%water_content(node)
  prev_rate=-1.0_real64

  do iter=1,nit
    amount=sorptivity_amount(theta_iter,0.0_real64,0.0_real64,dt)
    amount=min(amount,macro_water)
    raw_rate=amount/dt
    if(prev_rate<0.0_real64)then
      rate=raw_rate
    else
      rate=0.5_real64*prev_rate+0.5_real64*raw_rate
    end if

    exchange%source_rate=0.0_real64
    exchange%source_rate(node)=rate
    call solver%solve(request,workspace,result)
    if(result%status/=SW_SOLVE_CONVERGED)then
      dry_failures=dry_failures+1
      write(*,'(*(g0))') 'PPA_WU05A4_DAMP_FAIL|ITER=',iter,'|RAW=',raw_rate,'|RATE=',rate, &
           '|STATUS=',result%status,'|RETRY=',result%retry_advised
      exit
    end if

    matrix1=sum(result%candidate_state%water_content*params%dz)
    macro1=macro_water-rate*dt
    combined=(matrix1-matrix0)+(macro1-macro_water)
    if(abs(combined-(result%bottom_flux-request%boundary%top_flux)*dt)>1.0e-9_real64) &
         error stop 'A4 damped combined mass mismatch'

    if(prev_rate>0.0_real64)then
      rel_change=abs(rate-prev_rate)/max(abs(prev_rate),1.0e-30_real64)
    else
      rel_change=-1.0_real64
    end if
    write(*,'(*(g0))') 'PPA_WU05A4_DAMPED|ITER=',iter,'|RAW=',raw_rate,'|RATE=',rate, &
         '|REL_CHANGE=',rel_change,'|THETA=',result%candidate_state%water_content(node), &
         '|QBOT=',result%bottom_flux

    prev_rate=rate
    theta_iter=result%candidate_state%water_content(node)
  end do

  write(*,'(*(g0))') 'PPA_WU05A4_STAB_SUMMARY|WET_SUCCESSES=',wet_successes,'|DRY_FAILURES=',dry_failures
  print '(a)', 'PPA_WU05A4_RICHARDS_STABILIZATION_CHARACTERIZATION=PASS'

contains

  pure real(real64) function sorptivity_amount(theta,tabs,theta_ref,local_dt) result(amount)
    real(real64),intent(in)::theta,tabs,theta_ref,local_dt
    real(real64),parameter::theta_s=0.427494_real64,theta_r=0.02_real64
    real(real64),parameter::sorp_max=2.0_real64,sorp_alpha=0.5_real64
    real(real64)::deficit,sorp,active,ref
    deficit=max(0.0_real64,theta_s-theta)
    if(deficit<1.0e-8_real64)then
      amount=0.0_real64
      return
    end if
    if(tabs<1.0e-8_real64)then
      ref=theta_s
      sorp=sorp_max*(deficit/(theta_s-theta_r))**sorp_alpha
      active=sorp
    else if(theta_ref-theta>1.0e-8_real64)then
      ref=theta_ref
      active=sorp_max*((ref-theta)/(theta_s-theta_r))**sorp_alpha
    else
      active=0.0_real64
    end if
    amount=active*0.08_real64*(4.0_real64*0.95_real64*10.0_real64/4.0_real64)* &
         (sqrt(tabs+local_dt)-sqrt(tabs))
    amount=max(0.0_real64,amount)
  end function sorptivity_amount

end program test_ppa_wu05a4_richards_stabilization
