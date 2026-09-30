program test_ppa_wu05a4_richards_trajectory
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, soil_water_physical_state_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_ppa_wu05a4_fixed_exchange_provider, only: ppa_wu05a4_fixed_exchange_provider_t
  implicit none

  integer, parameter :: nsteps=6
  real(real64), parameter :: dt=0.05_real64,tol=1.0e-12_real64
  real(real64), parameter :: recharge=0.05_real64,sorp_max=1.0_real64
  real(real64), parameter :: omega=0.5_real64
  integer, parameter :: strict_max=20, practical_max=3
  real(real64), parameter :: strict_tol=1.0e-8_real64, practical_tol=1.0e-3_real64

  type(soil_water_parameter_set_t), target :: params
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t), target :: hyd
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(ppa_wu05a4_fixed_exchange_provider_t), target :: exchange
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(soil_water_solve_request_t) :: request
  type(soil_water_physical_state_t) :: strict_state,practical_state
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: heads(numnod),water(numnod),cond(numnod),cap(numnod),dkdh(numnod)
  real(real64) :: strict_macro,practical_macro,strict_tabs,practical_tabs
  real(real64) :: strict_tref,practical_tref,strict_cum_ex,practical_cum_ex
  real(real64) :: strict_cum_qbot,practical_cum_qbot
  real(real64) :: q_strict,q_practical,amount,last_bottom_flux
  integer :: i,node,step,strict_iters,practical_iters
  logical :: ok

  node=2
  allocate(params%z(numnod),params%dz(numnod),params%node_distance(numnod),cofgen(24,numnod))
  params%parameter_set_id=505406_int64
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

  allocate(exchange%source_rate(numnod),exchange%sink_rate(numnod))
  exchange%source_rate=0.0_real64
  exchange%sink_rate=0.0_real64

  request%parameters=>params
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
  request%evaluation%source_sink=>exchange
  request%evaluation%top_boundary=>top
  request%step_duration=dt

  heads=-50.0_real64
  call hyd%evaluate(heads,water,cond,cap,dkdh)
  call init_state(strict_state,heads,water)
  call init_state(practical_state,heads,water)

  strict_macro=1.0_real64
  practical_macro=1.0_real64
  strict_tabs=0.0_real64; practical_tabs=0.0_real64
  strict_tref=0.0_real64; practical_tref=0.0_real64
  strict_cum_ex=0.0_real64; practical_cum_ex=0.0_real64
  strict_cum_qbot=0.0_real64; practical_cum_qbot=0.0_real64

  do step=1,nsteps
    strict_macro=min(1.2_real64,strict_macro+recharge)
    practical_macro=min(1.2_real64,practical_macro+recharge)

    call coupled_step(strict_state,strict_macro,strict_tabs,strict_tref,strict_max,strict_tol, &
         q_strict,strict_iters,ok)
    if(.not.ok) error stop 'A4 strict trajectory step failed'
    amount=min(q_strict*dt,strict_macro)
    strict_macro=strict_macro-amount
    strict_cum_ex=strict_cum_ex+amount
    strict_cum_qbot=strict_cum_qbot+last_bottom_flux*dt
    call update_history(strict_state%water_content(node),strict_tabs,strict_tref)

    call coupled_step(practical_state,practical_macro,practical_tabs,practical_tref,practical_max,practical_tol, &
         q_practical,practical_iters,ok)
    if(.not.ok) error stop 'A4 practical trajectory step failed'
    amount=min(q_practical*dt,practical_macro)
    practical_macro=practical_macro-amount
    practical_cum_ex=practical_cum_ex+amount
    practical_cum_qbot=practical_cum_qbot+last_bottom_flux*dt
    call update_history(practical_state%water_content(node),practical_tabs,practical_tref)

    write(*,'(*(g0))') 'PPA_WU05A4_TRAJ_STEP|STEP=',step, &
         '|STRICT_Q=',q_strict,'|PRACTICAL_Q=',q_practical, &
         '|STRICT_IT=',strict_iters,'|PRACTICAL_IT=',practical_iters, &
         '|STRICT_THETA=',strict_state%water_content(node), &
         '|PRACTICAL_THETA=',practical_state%water_content(node)
  end do

  write(*,'(*(g0))') 'PPA_WU05A4_TRAJ_SUMMARY|CUM_EXCHANGE_ABS=',abs(practical_cum_ex-strict_cum_ex), &
       '|THETA_MAX_ABS=',maxval(abs(practical_state%water_content-strict_state%water_content)), &
       '|HEAD_MAX_ABS=',maxval(abs(practical_state%pressure_head-strict_state%pressure_head)), &
       '|MACRO_STORAGE_ABS=',abs(practical_macro-strict_macro), &
       '|CUM_QBOT_ABS=',abs(practical_cum_qbot-strict_cum_qbot)
  print '(a)', 'PPA_WU05A4_RICHARDS_TRAJECTORY=PASS'

contains

  subroutine init_state(state,h,w)
    type(soil_water_physical_state_t),intent(out)::state
    real(real64),intent(in)::h(:),w(:)
    state%active_nodes=size(h)
    allocate(state%pressure_head(size(h)),state%water_content(size(w)))
    state%pressure_head=h
    state%water_content=w
    state%ponding_depth=0.0_real64
    state%groundwater_level=-2.0_real64
  end subroutine init_state

  subroutine coupled_step(state,macro_water,tabs,tref,max_outer,outer_tol,q_final,iters,ok)
    type(soil_water_physical_state_t),intent(inout)::state
    real(real64),intent(in)::macro_water,tabs,tref,outer_tol
    integer,intent(in)::max_outer
    real(real64),intent(out)::q_final
    integer,intent(out)::iters
    logical,intent(out)::ok
    type(soil_water_solve_result_t)::predictor,result
    real(real64)::theta_iter,raw_rate,rate,prev_rate,rel
    integer::iter

    ok=.false.
    request%base_state=state
    exchange%source_rate=0.0_real64
    call solver%solve(request,workspace,predictor)
    if(predictor%status/=SW_SOLVE_CONVERGED)return

    theta_iter=predictor%candidate_state%water_content(node)
    prev_rate=-1.0_real64
    rate=0.0_real64
    do iter=1,max_outer
      raw_rate=min(sorptivity_amount(theta_iter,tabs,tref),macro_water)/dt
      if(prev_rate<0.0_real64)then
        rate=raw_rate
      else
        rate=omega*prev_rate+(1.0_real64-omega)*raw_rate
      end if
      exchange%source_rate=0.0_real64
      exchange%source_rate(node)=rate
      call solver%solve(request,workspace,result)
      if(result%status/=SW_SOLVE_CONVERGED)return

      if(prev_rate>0.0_real64)then
        rel=abs(rate-prev_rate)/max(abs(prev_rate),1.0e-30_real64)
      else
        rel=huge(1.0_real64)
      end if
      theta_iter=result%candidate_state%water_content(node)
      if(prev_rate>0.0_real64 .and. rel<outer_tol)exit
      prev_rate=rate
    end do

    state=result%candidate_state
    last_bottom_flux=result%bottom_flux
    q_final=rate
    iters=iter
    ok=.true.
  end subroutine coupled_step

  pure real(real64) function sorptivity_amount(theta,tabs,tref) result(amount)
    real(real64),intent(in)::theta,tabs,tref
    real(real64),parameter::theta_s=0.427494_real64,theta_r=0.02_real64
    real(real64)::deficit,sorp,active,ref
    deficit=max(0.0_real64,theta_s-theta)
    if(deficit<1.0e-8_real64)then
      amount=0.0_real64; return
    end if
    if(tabs<1.0e-8_real64)then
      ref=theta_s
      sorp=sorp_max*(deficit/(theta_s-theta_r))**0.5_real64
      active=sorp
    else if(tref-theta>1.0e-8_real64)then
      ref=tref
      active=sorp_max*((ref-theta)/(theta_s-theta_r))**0.5_real64
    else
      active=0.0_real64
    end if
    amount=active*0.08_real64*(4.0_real64*0.95_real64*10.0_real64/4.0_real64)* &
         (sqrt(tabs+dt)-sqrt(tabs))
    amount=max(0.0_real64,amount)
  end function sorptivity_amount

  subroutine update_history(theta_before,tabs,tref)
    real(real64),intent(in)::theta_before
    real(real64),intent(inout)::tabs,tref
    real(real64),parameter::theta_s=0.427494_real64,theta_r=0.02_real64
    real(real64)::deficit,sorp,ref
    deficit=max(0.0_real64,theta_s-theta_before)
    if(deficit<1.0e-8_real64)then
      tabs=0.0_real64; tref=0.0_real64; return
    end if
    if(tabs<1.0e-8_real64)then
      sorp=sorp_max*(deficit/(theta_s-theta_r))**0.5_real64
      ref=theta_s
    else if(tref>theta_before)then
      sorp=sorp_max*((tref-theta_before)/(theta_s-theta_r))**0.5_real64
      ref=tref
    else
      tabs=0.0_real64; tref=0.0_real64; return
    end if
    tref=ref+0.95_real64*0.08_real64*(4.0_real64/4.0_real64)*sorp*(sqrt(tabs+dt)-sqrt(tabs))
    tabs=tabs+dt
  end subroutine update_history

end program test_ppa_wu05a4_richards_trajectory
