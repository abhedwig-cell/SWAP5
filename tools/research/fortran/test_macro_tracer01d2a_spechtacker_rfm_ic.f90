program test_macro_tracer01d2a_spechtacker_rfm_ic
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, evaluate_b110_default_mvg_conductivity
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  use mod_process_hydraulic_view, only: process_hydraulic_view_t, build_process_hydraulic_view
  use mod_rfm_research_adapter, only: rfm_research_parameters_t, rfm_surface_hydraulic_input_t, &
       rfm_surface_activation_result_t, rfm_build_surface_hydraulic_input_from_state, &
       rfm_evaluate_unponded_activation, RFM_RESEARCH_AVAILABLE
  implicit none

  type(soil_water_parameter_set_t), target :: p
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: ws
  type(soil_water_physical_state_t) :: state, next_state
  type(process_hydraulic_view_t) :: view
  type(rfm_research_parameters_t) :: rfm_p
  type(rfm_surface_hydraulic_input_t) :: rfm_in
  type(rfm_surface_activation_result_t) :: activation
  real(real64), allocatable, target :: qdra(:,:), qssdi(:), qrot(:)
  real(real64), allocatable :: c(:,:)
  real(real64) :: theta0(10), heads(10)
  real(real64) :: t, dt_try, dt_base, dt_min, horizon, irrig_end, source_rate
  real(real64) :: matrix_rate, pref_rate, sigma_b
  real(real64) :: tr, ts, alpha_cm, nvg, mvg, ksat_cm_day, lambda
  real(real64) :: last_qtop=0.0_real64, last_qbot=0.0_real64
  integer :: unit, i, accepted, retries
  character(len=256) :: outfile
  character(len=64) :: arg
  logical :: ok, view_ok

  if (numnod /= 10) error stop 'TRACER01-D2A requires 10 nodes'
  call get_command_argument(1, outfile)
  if (len_trim(outfile) == 0) error stop 'missing trajectory output path'
  call get_command_argument(2, arg)
  if (len_trim(arg) == 0) error stop 'missing sigma_B'
  read(arg,*) sigma_b

  tr = 0.04_real64
  ts = 0.40_real64
  alpha_cm = 1.90_real64 / 100.0_real64
  nvg = 1.25_real64
  mvg = 1.0_real64 - 1.0_real64/nvg
  ksat_cm_day = 2.50e-6_real64 * 100.0_real64 * 86400.0_real64
  lambda = 0.5_real64
  source_rate = 11.1_real64 / 10.0_real64 * 24.0_real64
  irrig_end = 2.5_real64 / 24.0_real64
  horizon = 1.0_real64
  dt_base = 120.0_real64 / 86400.0_real64
  dt_min = 1.0_real64 / 86400.0_real64
  theta0 = 0.274_real64

  rfm_p%sigma_b=sigma_b
  rfm_p%f_mb=0.0_real64
  rfm_p%connectivity_p=0.249_real64
  rfm_p%chi_wall=1.0_real64

  call setup_parameters()
  call initialize_state(theta0,state)

  open(newunit=unit,file=trim(outfile),status='replace',action='write')
  write(unit,'(A)') 't0_day,dt_day,source_cm_day,matrix_source_cm_day,pref_source_cm_day,qtop_cm_day,qbot_cm_day,'// &
       'theta0_1,theta0_2,theta0_3,theta0_4,theta0_5,theta0_6,theta0_7,theta0_8,theta0_9,theta0_10,'// &
       'theta1_1,theta1_2,theta1_3,theta1_4,theta1_5,theta1_6,theta1_7,theta1_8,theta1_9,theta1_10'

  t=0.0_real64; accepted=0; retries=0
  do while (t < horizon - 1.0e-14_real64)
     if (abs(t-irrig_end) < 1.0e-12_real64) t=irrig_end
     dt_try=min(dt_base,horizon-t)
     if (t < irrig_end .and. t+dt_try > irrig_end+1.0e-12_real64) dt_try=irrig_end-t

     matrix_rate=0.0_real64; pref_rate=0.0_real64
     if (t < irrig_end) then
        call bind_b110_default_mvg_provider(constitutive,hp,dt_try)
        call build_process_hydraulic_view(state,view,view_ok)
        if (.not.view_ok) error stop 'TRACER01-D2A hydraulic view unavailable'
        call rfm_build_surface_hydraulic_input_from_state(view,constitutive,128,source_rate,t+0.5_real64*dt_try,rfm_in,ok)
        if (.not.ok) error stop 'TRACER01-D2A RFM hydraulic input unavailable'
        call rfm_evaluate_unponded_activation(rfm_p,rfm_in,activation)
        if (activation%status /= RFM_RESEARCH_AVAILABLE) error stop 'TRACER01-D2A activation unavailable'
        matrix_rate=activation%matrix_rate
        pref_rate=activation%preferential_rate
     end if

     do
        call solve_step(state,dt_try,matrix_rate,next_state,ok)
        if (ok) exit
        retries=retries+1
        dt_try=0.5_real64*dt_try
        if (dt_try < dt_min) error stop 'TRACER01-D2A nonconvergence below dt_min'
        if (t < irrig_end) then
           call bind_b110_default_mvg_provider(constitutive,hp,dt_try)
           call build_process_hydraulic_view(state,view,view_ok)
           if (.not.view_ok) error stop 'TRACER01-D2A retry hydraulic view unavailable'
           call rfm_build_surface_hydraulic_input_from_state(view,constitutive,128,source_rate,t+0.5_real64*dt_try,rfm_in,ok)
           if (.not.ok) error stop 'TRACER01-D2A retry RFM input unavailable'
           call rfm_evaluate_unponded_activation(rfm_p,rfm_in,activation)
           if (activation%status /= RFM_RESEARCH_AVAILABLE) error stop 'TRACER01-D2A retry activation unavailable'
           matrix_rate=activation%matrix_rate
           pref_rate=activation%preferential_rate
        end if
     end do

     call write_row(unit,t,dt_try,merge(source_rate,0.0_real64,t<irrig_end),matrix_rate,pref_rate,state,next_state)
     state=next_state
     t=t+dt_try
     accepted=accepted+1
  end do
  close(unit)
  write(*,'(*(g0))') 'TRACER01D2A_PASS|SIGMA_B=',sigma_b,'|ACCEPTED=',accepted,'|RETRIES=',retries,'|T_END=',t

contains

  subroutine setup_parameters()
    integer :: k
    p%parameter_set_id=26100103
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),c(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod)
    c=0.0_real64
    do k=1,numnod
       c(1,k)=tr; c(2,k)=ts; c(3,k)=ksat_cm_day; c(4,k)=alpha_cm; c(5,k)=lambda; c(6,k)=nvg; c(7,k)=mvg
       c(8,k)=alpha_cm; c(9,k)=0.0_real64; c(10,k)=ksat_cm_day
       c(11,k)=0.999_real64; c(12,k)=0.99_real64*ksat_cm_day
       c(22,k)=-1.0e6_real64; c(23,k)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,c)
    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
    qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64
    call bind_b110_source_sink_provider(source_sink,qdra,qssdi,qrot)
  end subroutine setup_parameters

  subroutine initialize_state(theta_in,s)
    real(real64),intent(in)::theta_in(:)
    type(soil_water_physical_state_t),intent(out)::s
    integer::k
    real(real64)::se
    s%active_nodes=numnod
    allocate(s%pressure_head(numnod),s%water_content(numnod))
    do k=1,numnod
       se=max(1.0e-8_real64,min(0.999999_real64,(theta_in(k)-tr)/(ts-tr)))
       heads(k)=-((se**(-1.0_real64/mvg)-1.0_real64)**(1.0_real64/nvg))/alpha_cm
    end do
    s%pressure_head=heads; s%water_content=theta_in
    s%ponding_depth=0.0_real64; s%groundwater_level=-999.0_real64
  end subroutine initialize_state

  subroutine solve_step(s0,step_dt,rain_now,s1,success)
    type(soil_water_physical_state_t),intent(in)::s0
    real(real64),intent(in)::step_dt,rain_now
    type(soil_water_physical_state_t),intent(out)::s1
    logical,intent(out)::success
    type(b110_dynamic_top_boundary_solver_provider_t),target::top
    type(soil_water_solve_request_t)::req
    type(soil_water_solve_result_t)::res
    real(real64)::fixed_k
    logical::k_ok
    success=.false.
    call bind_b110_default_mvg_provider(constitutive,hp,step_dt)
    call evaluate_b110_default_mvg_conductivity(hp,1,s0%pressure_head(1),fixed_k,k_ok)
    if (.not.k_ok) return
    call bind_b110_dynamic_top_boundary_solver_provider(top,p,hp,1,s0%ponding_depth,step_dt, &
         rain_now,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.05_real64,0.05_real64,1.0_real64,fixed_k)
    req=soil_water_solve_request_t()
    req%parameters=>p; req%base_state=s0; req%step_duration=step_dt
    req%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER
    req%boundary%bottom_mode=7
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=30; req%numerical%max_backtracking=10
    req%numerical%conductivity_implicit_mode=0; req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=dt_min
    req%numerical%compartment_balance_tolerance=1.0e-10_real64
    req%numerical%total_balance_tolerance=1.0e-10_real64
    req%numerical%head_abs_tolerance=1.0e-8_real64; req%numerical%head_rel_tolerance=1.0e-8_real64
    req%numerical%ponding_tolerance=1.0e-10_real64
    req%evaluation%constitutive=>constitutive; req%evaluation%source_sink=>source_sink
    req%evaluation%dynamic_top_boundary=>top
    call solver%solve(req,ws,res)
    if (res%status /= SW_SOLVE_CONVERGED) return
    s1=res%candidate_state; last_qtop=res%top_flux; last_qbot=res%bottom_flux; success=.true.
  end subroutine solve_step

  subroutine write_row(u,t0,step_dt,source_now,matrix_now,pref_now,s0,s1)
    integer,intent(in)::u
    real(real64),intent(in)::t0,step_dt,source_now,matrix_now,pref_now
    type(soil_water_physical_state_t),intent(in)::s0,s1
    integer::k
    write(u,'(*(g0,:,","))') t0,step_dt,source_now,matrix_now,pref_now,last_qtop,last_qbot, &
         (s0%water_content(k),k=1,numnod),(s1%water_content(k),k=1,numnod)
  end subroutine write_row
end program test_macro_tracer01d2a_spechtacker_rfm_ic
