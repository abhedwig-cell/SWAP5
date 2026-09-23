program test_rm20_temporal_indicator_decomposition
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, soil_water_temporal_indicator_request_t, soil_water_temporal_indicator_result_t, &
       SW_SOLVE_CONVERGED, SW_TEMPORAL_INDICATOR_AVAILABLE
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX, FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, evaluate_b110_default_mvg_conductivity
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: dt=1.0e-4_real64, h0=-75.0_real64
  real(real64), parameter :: qold=1.0e-6_real64, qnew=-36.0_real64, qbot=1.0e-6_real64
  real(real64), parameter :: budget=1.0e-5_real64
  type(soil_water_parameter_set_t), target :: p
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(b110_dynamic_top_boundary_solver_provider_t), target :: dynamic_top
  type(fixed_flux_top_boundary_provider_t), target :: fixed_top
  type(reference_richards_legacy_solver_t) :: dyn_solver,fix_solver,old_solver
  type(reference_richards_legacy_workspace_t) :: dyn_ws,fix_ws,old_ws
  type(soil_water_solve_request_t) :: dyn_req,fix_req,old_req
  type(soil_water_solve_result_t) :: dyn_res,fix_res,old_res
  type(soil_water_temporal_indicator_request_t) :: ind_req
  type(soil_water_temporal_indicator_result_t) :: dyn_hist,fix_hist,dyn_switch,fix_switch,old_ind,dyn_current
  real(real64), target :: qdra(1,numnod),qssdi(numnod),qrot(numnod)
  real(real64) :: cofgen(24,numnod),heads(numnod),water(numnod),k(numnod),cap(numnod),dkdh(numnod),fixed_k
  real(real64) :: old_right(numnod),switch_right(numnod),current_right(numnod),mass_weight(numnod)
  real(real64) :: delta_q_into_soil
  logical :: ok
  integer :: i

  call configure(p,cofgen)
  call initialize_b110_default_mvg_parameters(hp,cofgen)
  call bind_b110_default_mvg_provider(constitutive,hp,dt)
  heads(1)=h0
  do i=2,numnod
    heads(i)=heads(i-1)+p%node_distance(i)
  end do
  call constitutive%evaluate(heads,water,k,cap,dkdh)
  call evaluate_b110_default_mvg_conductivity(hp,1,heads(1),fixed_k,ok)
  call require(ok,'fixed top K')
  mass_weight=cap*p%dz

  qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64
  call bind_b110_source_sink_provider(source_sink,qdra,qssdi,qrot)
  call bind_b110_dynamic_top_boundary_solver_provider(dynamic_top,p,hp,1,0.0_real64,dt, &
       0.0_real64,36.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64, &
       1.0_real64,1.0_real64,1.0_real64,fixed_k)

  ! Pre-event/no-irrigation trajectory.
  call build_request(old_req,p,heads,water)
  old_req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
  old_req%boundary%top_flux=qold
  old_req%evaluation%top_boundary=>fixed_top
  call old_solver%solve(old_req,old_ws,old_res)
  call require(old_res%status==SW_SOLVE_CONVERGED,'old forcing raw solve')
  old_right=(old_res%candidate_state%pressure_head-old_req%base_state%pressure_head)/dt

  ! Frozen irrigation trajectory, both dynamic and explicit forms.
  call build_request(dyn_req,p,heads,water)
  dyn_req%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER
  dyn_req%evaluation%dynamic_top_boundary=>dynamic_top
  call dyn_solver%solve(dyn_req,dyn_ws,dyn_res)
  call require(dyn_res%status==SW_SOLVE_CONVERGED,'dynamic raw solve')

  call build_request(fix_req,p,heads,water)
  fix_req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
  fix_req%boundary%top_flux=qnew
  fix_req%evaluation%top_boundary=>fixed_top
  call fix_solver%solve(fix_req,fix_ws,fix_res)
  call require(fix_res%status==SW_SOLVE_CONVERGED,'fixed irrigation raw solve')
  call require(maxval(abs(dyn_res%candidate_state%pressure_head-fix_res%candidate_state%pressure_head))==0.0_real64, &
       'RM17 head identity')
  current_right=(dyn_res%candidate_state%pressure_head-dyn_req%base_state%pressure_head)/dt

  ! Exact forcing-switch correction at the accepted origin.
  ! q<0 is inward at the top. The external influx jump therefore is
  ! -(qnew-qold), and only the top control volume receives this instantaneous
  ! boundary contribution at unchanged accepted state.
  switch_right=old_right
  delta_q_into_soil=-(qnew-qold)
  switch_right(1)=switch_right(1)+delta_q_into_soil/mass_weight(1)

  call evaluate_case(dyn_solver,dyn_req,dyn_res,dyn_ws,old_right,dyn_hist)
  call evaluate_case(fix_solver,fix_req,fix_res,fix_ws,old_right,fix_hist)
  call require_equivalent(dyn_hist,fix_hist,'historical predecessor dynamic/fixed')

  call evaluate_case(dyn_solver,dyn_req,dyn_res,dyn_ws,switch_right,dyn_switch)
  call evaluate_case(fix_solver,fix_req,fix_res,fix_ws,switch_right,fix_switch)
  call require_equivalent(dyn_switch,fix_switch,'post-switch predecessor dynamic/fixed')

  ! Control: if predecessor equals the full-step secant derivative, e_raw is zero.
  call evaluate_case(dyn_solver,dyn_req,dyn_res,dyn_ws,current_right,dyn_current)
  call require(dyn_current%head_inf_bound <= 1.0e-12_real64,'current-derivative zero-defect control')

  call evaluate_case(old_solver,old_req,old_res,old_ws,old_right,old_ind)

  write(*,'(A,ES26.17E3)') 'RM20_OLD_RIGHT_INF=',maxval(abs(old_right))
  write(*,'(A,ES26.17E3)') 'RM20_SWITCH_RIGHT_INF=',maxval(abs(switch_right))
  write(*,'(A,ES26.17E3)') 'RM20_CURRENT_RIGHT_INF=',maxval(abs(current_right))
  write(*,'(A,ES26.17E3)') 'RM20_OLD_RIGHT_M=',sqrt(sum(mass_weight*old_right*old_right))
  write(*,'(A,ES26.17E3)') 'RM20_SWITCH_RIGHT_M=',sqrt(sum(mass_weight*switch_right*switch_right))
  write(*,'(A,ES26.17E3)') 'RM20_CURRENT_RIGHT_M=',sqrt(sum(mass_weight*current_right*current_right))
  call print_indicator('NO_IRRIGATION',old_ind)
  call print_indicator('IRR_HISTORICAL_PREDECESSOR',dyn_hist)
  call print_indicator('IRR_POST_SWITCH_PREDECESSOR',dyn_switch)
  call print_indicator('IRR_CURRENT_DERIVATIVE_CONTROL',dyn_current)
  write(*,'(A,ES26.17E3)') 'RM20_HISTORICAL_NORMALIZED=',dyn_hist%head_inf_bound/budget
  write(*,'(A,ES26.17E3)') 'RM20_SWITCH_NORMALIZED=',dyn_switch%head_inf_bound/budget
  write(*,'(A,ES26.17E3)') 'RM20_SWITCH_TO_HISTORICAL_RATIO=',safe_ratio(dyn_switch%head_inf_bound,dyn_hist%head_inf_bound)
  write(*,'(A)') 'RM20_TEMPORAL_DECOMPOSITION=PASS'

contains

  subroutine evaluate_case(solver,req,res,ws,previous,indicator)
    type(reference_richards_legacy_solver_t),intent(inout)::solver
    type(soil_water_solve_request_t),intent(in)::req
    type(soil_water_solve_result_t),intent(in)::res
    type(reference_richards_legacy_workspace_t),intent(inout)::ws
    real(real64),intent(in)::previous(:)
    type(soil_water_temporal_indicator_result_t),intent(out)::indicator
    type(soil_water_temporal_indicator_request_t)::ir
    ir%previous_right_derivative_available=.true.
    allocate(ir%previous_right_derivative(size(previous)))
    ir%previous_right_derivative=previous
    call solver%evaluate_temporal_indicator(req,res,ir,ws,indicator)
    call require(indicator%status==SW_TEMPORAL_INDICATOR_AVAILABLE .and. indicator%available,'indicator available')
  end subroutine evaluate_case

  subroutine require_equivalent(a,b,label)
    type(soil_water_temporal_indicator_result_t),intent(in)::a,b
    character(len=*),intent(in)::label
    call require(abs(a%head_inf_bound-b%head_inf_bound)<=1.0e-12_real64,label//' Binf')
    call require(abs(a%raw_m_norm-b%raw_m_norm)<=1.0e-12_real64,label//' raw')
    call require(abs(a%defect_m_norm-b%defect_m_norm)<=1.0e-12_real64,label//' defect')
  end subroutine require_equivalent

  subroutine print_indicator(label,x)
    character(len=*),intent(in)::label
    type(soil_water_temporal_indicator_result_t),intent(in)::x
    write(*,'(A,A,A,ES26.17E3)') 'RM20_',trim(label),'_RAW_M=',x%raw_m_norm
    write(*,'(A,A,A,ES26.17E3)') 'RM20_',trim(label),'_DEFECT_M=',x%defect_m_norm
    write(*,'(A,A,A,ES26.17E3)') 'RM20_',trim(label),'_BOUNDED_M=',x%bounded_m_norm
    write(*,'(A,A,A,ES26.17E3)') 'RM20_',trim(label),'_MIN_M=',x%min_mass_weight
    write(*,'(A,A,A,ES26.17E3)') 'RM20_',trim(label),'_BINF=',x%head_inf_bound
    write(*,'(A,A,A,A)') 'RM20_',trim(label),'_ROUTE=',trim(x%route)
  end subroutine print_indicator

  pure real(real64) function safe_ratio(a,b) result(r)
    real(real64),intent(in)::a,b
    if(abs(b)>tiny(1.0_real64))then
      r=a/b
    else
      r=huge(1.0_real64)
    end if
  end function safe_ratio

  subroutine configure(parameters,c)
    type(soil_water_parameter_set_t),target,intent(out)::parameters
    real(real64),intent(out)::c(24,numnod)
    integer::j
    parameters%parameter_set_id=200020_int64; parameters%active_nodes=numnod
    allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
    parameters%z=z; parameters%dz=dz; parameters%node_distance=disnod(1:numnod)
    c=0.0_real64
    do j=1,numnod
      c(1,j)=0.032_real64; c(2,j)=0.423_real64; c(3,j)=4.75_real64
      c(4,j)=0.0135_real64; c(5,j)=0.365_real64; c(6,j)=1.455_real64
      c(7,j)=1.0_real64-1.0_real64/c(6,j); c(8,j)=c(4,j); c(9,j)=0.0_real64
      c(10,j)=c(3,j); c(11,j)=0.999_real64; c(12,j)=0.99_real64*c(3,j)
      c(22,j)=-1.0e6_real64; c(23,j)=1.0e-12_real64
    end do
  end subroutine configure

  subroutine build_request(r,parameters,h,w)
    type(soil_water_solve_request_t),intent(out)::r
    type(soil_water_parameter_set_t),target,intent(in)::parameters
    real(real64),intent(in)::h(:),w(:)
    r=soil_water_solve_request_t()
    r%parameters=>parameters
    r%base_state%active_nodes=numnod
    allocate(r%base_state%pressure_head(numnod),r%base_state%water_content(numnod))
    r%base_state%pressure_head=h; r%base_state%water_content=w
    r%base_state%ponding_depth=0.0_real64; r%base_state%groundwater_level=-2.0_real64
    r%step_duration=dt
    r%boundary%bottom_mode=2; r%boundary%bottom_flux=qbot; r%boundary%bottom_head=h0; r%boundary%top_head=h0
    r%numerical%max_iterations=16; r%numerical%max_backtracking=8
    r%numerical%conductivity_implicit_mode=0; r%numerical%conductivity_mean_method=1
    r%numerical%min_step_duration=1.0e-8_real64
    r%numerical%compartment_balance_tolerance=1.0e-12_real64
    r%numerical%total_balance_tolerance=1.0e-12_real64
    r%numerical%head_abs_tolerance=1.0e-12_real64; r%numerical%head_rel_tolerance=1.0e-12_real64
    r%numerical%ponding_tolerance=1.0e-12_real64
    r%evaluation%constitutive=>constitutive; r%evaluation%source_sink=>source_sink
  end subroutine build_request

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'RM20_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_rm20_temporal_indicator_decomposition
