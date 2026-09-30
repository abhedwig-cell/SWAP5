program test_ppa_wu05a4_richards_predictor_corrector
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
  real(real64), parameter :: macro_water0=0.20_real64

  type(soil_water_parameter_set_t), target :: params
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t), target :: hyd
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(ppa_wu05a4_fixed_exchange_provider_t), target :: exchange
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: predictor,fresh,aged,fresh2,aged2
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: heads(numnod),water(numnod),cond(numnod),cap(numnod),dkdh(numnod)
  real(real64) :: fresh_amount,aged_amount,fresh_rate,aged_rate,fresh_amount2,aged_amount2
  real(real64) :: fresh_rate2,aged_rate2,fresh_rel_change,aged_rel_change
  real(real64) :: matrix0,matrix_fresh,matrix_aged
  real(real64) :: macro_fresh,macro_aged,combined_fresh,combined_aged
  integer :: i,node

  node=2
  allocate(params%z(numnod),params%dz(numnod),params%node_distance(numnod),cofgen(24,numnod))
  params%parameter_set_id=505402_int64
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

  matrix0=sum(request%base_state%water_content*params%dz)

  ! Predictor: no macropore exchange.
  call solver%solve(request,workspace,predictor)
  if(predictor%status/=SW_SOLVE_CONVERGED) error stop 'A4 predictor did not converge'

  fresh_amount=sorptivity_amount(predictor%candidate_state%water_content(node),0.0_real64,0.0_real64)
  aged_amount=sorptivity_amount(predictor%candidate_state%water_content(node),0.5_real64,0.47_real64)
  fresh_amount=min(fresh_amount,macro_water0)
  aged_amount=min(aged_amount,macro_water0)
  fresh_rate=fresh_amount/dt
  aged_rate=aged_amount/dt

  if(fresh_rate<=aged_rate) error stop 'A4 memory ordering lost before Richards corrector'

  ! Fresh corrector.
  exchange%source_rate=0.0_real64
  exchange%source_rate(node)=fresh_rate
  call solver%solve(request,workspace,fresh)
  if(fresh%status/=SW_SOLVE_CONVERGED) error stop 'A4 fresh corrector did not converge'
  matrix_fresh=sum(fresh%candidate_state%water_content*params%dz)
  macro_fresh=macro_water0-fresh_amount
  combined_fresh=(matrix_fresh-matrix0)+(macro_fresh-macro_water0)
  if(abs(combined_fresh-(fresh%bottom_flux-request%boundary%top_flux)*dt)>1.0e-10_real64) &
       error stop 'A4 fresh combined mass mismatch'

  ! Aged corrector.
  exchange%source_rate=0.0_real64
  exchange%source_rate(node)=aged_rate
  call solver%solve(request,workspace,aged)
  if(aged%status/=SW_SOLVE_CONVERGED) error stop 'A4 aged corrector did not converge'
  matrix_aged=sum(aged%candidate_state%water_content*params%dz)
  macro_aged=macro_water0-aged_amount
  combined_aged=(matrix_aged-matrix0)+(macro_aged-macro_water0)
  if(abs(combined_aged-(aged%bottom_flux-request%boundary%top_flux)*dt)>1.0e-10_real64) &
       error stop 'A4 aged combined mass mismatch'

  if((matrix_fresh-matrix0)<=(matrix_aged-matrix0)) error stop 'A4 Richards memory response ordering lost'
  if(abs(fresh%integrated_mass_balance_residual_cm)>1.0e-10_real64) error stop 'A4 fresh solver residual'
  if(abs(aged%integrated_mass_balance_residual_cm)>1.0e-10_real64) error stop 'A4 aged solver residual'

  ! Characterize one additional Picard-like corrector using the first corrector
  ! matrix state but the same accepted macropore history for this physical step.
  fresh_amount2=sorptivity_amount(fresh%candidate_state%water_content(node),0.0_real64,0.0_real64)
  aged_amount2=sorptivity_amount(aged%candidate_state%water_content(node),0.5_real64,0.47_real64)
  fresh_amount2=min(fresh_amount2,macro_water0)
  aged_amount2=min(aged_amount2,macro_water0)
  fresh_rate2=fresh_amount2/dt
  aged_rate2=aged_amount2/dt
  fresh_rel_change=abs(fresh_rate2-fresh_rate)/max(abs(fresh_rate),1.0e-30_real64)
  aged_rel_change=abs(aged_rate2-aged_rate)/max(abs(aged_rate),1.0e-30_real64)

  exchange%source_rate=0.0_real64
  exchange%source_rate(node)=fresh_rate2
  call solver%solve(request,workspace,fresh2)
  if(fresh2%status/=SW_SOLVE_CONVERGED) error stop 'A4 fresh second corrector did not converge'
  exchange%source_rate=0.0_real64
  exchange%source_rate(node)=aged_rate2
  call solver%solve(request,workspace,aged2)
  if(aged2%status/=SW_SOLVE_CONVERGED) error stop 'A4 aged second corrector did not converge'

  if(fresh_rate2>fresh_rate*(1.0_real64+1.0e-10_real64)) &
       error stop 'A4 fresh exchange increased after matrix wetting'
  if(aged_rate2>aged_rate*(1.0_real64+1.0e-10_real64)) &
       error stop 'A4 aged exchange increased after matrix wetting'

  write(*,'(*(g0))') 'PPA_WU05A4_PC_DIAG|FRESH_RATE=',fresh_rate,'|AGED_RATE=',aged_rate, &
       '|FRESH_RATE2=',fresh_rate2,'|AGED_RATE2=',aged_rate2, &
       '|FRESH_REL_CHANGE=',fresh_rel_change,'|AGED_REL_CHANGE=',aged_rel_change, &
       '|FRESH_MATRIX_GAIN=',matrix_fresh-matrix0,'|AGED_MATRIX_GAIN=',matrix_aged-matrix0, &
       '|FRESH_QBOT=',fresh%bottom_flux,'|AGED_QBOT=',aged%bottom_flux
  print '(a)', 'PPA_WU05A4_RICHARDS_PREDICTOR_CORRECTOR=PASS'

contains

  pure real(real64) function sorptivity_amount(theta,tabs,theta_ref) result(amount)
    real(real64),intent(in)::theta,tabs,theta_ref
    real(real64),parameter::theta_s=0.427494_real64,theta_r=0.02_real64
    real(real64),parameter::sorp_max=0.50_real64,sorp_alpha=0.5_real64
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
         (sqrt(tabs+dt)-sqrt(tabs))
    amount=max(0.0_real64,amount)
  end function sorptivity_amount

end program test_ppa_wu05a4_richards_predictor_corrector
