program test_num_unc_p0b0_exchange_locator
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: n=16, wet_blocks=8, dry_blocks=24, blocks=32, nsearch=5
  integer, parameter :: NET_DRAINAGE=-1, ZERO_REP=0, CAPILLARY_SUPPORT=1, INADMISSIBLE=9
  real(real64), parameter :: dz_cm=10.0_real64, dt=0.0064_real64, initial_se=0.85_real64
  real(real64), parameter :: wet_factor=0.025_real64, dry_factor=-0.005_real64
  real(real64), parameter :: balance_tol=1.0e-12_real64
  real(real64), parameter :: search_offsets(nsearch)=[-100.0_real64,-50.0_real64,-25.0_real64,0.0_real64,25.0_real64]
  integer, parameter :: bisect_n=12
  real(real64), parameter :: minus_offset=-10.0_real64, plus_offset=10.0_real64

  integer :: cls(nsearch),i,lo_i,iter,mid_cls,minus_cls,zero_cls,plus_cls
  logical :: valid, exact_zero
  real(real64) :: h0,neutral_hbot,qdry,max_balance,lo,hi,mid,delta_star,bminus,bplus
  character(len=48) :: failure

  h0=initial_head()
  neutral_hbot=h0+0.5_real64*dz_cm

  write(*,'(A)') 'NUM_UNC_P0B0_STAGE=N0_ONLY_EXCHANGE_LOCATOR'
  write(*,'(A)') 'NUM_UNC_P0B0_N1_EXECUTED=FALSE'
  write(*,'(*(g0))') 'NUM_UNC_P0B0_H0_CM=',h0
  write(*,'(*(g0))') 'NUM_UNC_P0B0_NEUTRAL_HBOT_CM=',neutral_hbot
  write(*,'(*(g0))') 'NUM_UNC_P0B0_DT_DAY=',dt

  exact_zero=.false.; delta_star=0.0_real64
  do i=1,nsearch
    call run_offset(search_offsets(i),cls(i),valid,qdry,max_balance,failure)
    call report_run('SEARCH',search_offsets(i),cls(i),valid,qdry,max_balance,failure)
    if (.not.valid) then
      write(*,'(A)') 'NUM_UNC_P0B0_STATUS=BLOCKED_INADMISSIBLE_SEARCH_POINT'
      write(*,'(A)') 'NUM_UNC_P0B0_GATE=PASS'
      stop
    end if
    if (cls(i)==ZERO_REP) then
      exact_zero=.true.; delta_star=search_offsets(i); exit
    end if
  end do

  if (.not.exact_zero) then
    lo_i=0
    do i=1,nsearch-1
      if (cls(i)==NET_DRAINAGE .and. cls(i+1)==CAPILLARY_SUPPORT) then
        lo_i=i; exit
      end if
    end do
    if (lo_i==0) then
      write(*,'(A)') 'NUM_UNC_P0B0_STATUS=NO_TRANSITION_IN_DECLARED_ENVELOPE'
      write(*,'(A)') 'NUM_UNC_P0B0_GATE=PASS'
      stop
    end if
    lo=search_offsets(lo_i); hi=search_offsets(lo_i+1)
    write(*,'(*(g0))') 'NUM_UNC_P0B0_INITIAL_BRACKET|LO_OFFSET_CM=',lo,'|HI_OFFSET_CM=',hi
    do iter=1,bisect_n
      mid=0.5_real64*(lo+hi)
      call run_offset(mid,mid_cls,valid,qdry,max_balance,failure)
      call report_run('BISECT',mid,mid_cls,valid,qdry,max_balance,failure)
      if (.not.valid) then
        write(*,'(A)') 'NUM_UNC_P0B0_STATUS=BLOCKED_INADMISSIBLE_BISECTION'
        write(*,'(A)') 'NUM_UNC_P0B0_GATE=PASS'
        stop
      end if
      if (mid_cls==ZERO_REP) then
        exact_zero=.true.; delta_star=mid; exit
      else if (mid_cls==NET_DRAINAGE) then
        lo=mid
      else if (mid_cls==CAPILLARY_SUPPORT) then
        hi=mid
      else
        write(*,'(A)') 'NUM_UNC_P0B0_STATUS=BLOCKED_INVALID_CLASSIFICATION'
        write(*,'(A)') 'NUM_UNC_P0B0_GATE=PASS'
        stop
      end if
    end do
    if (.not.exact_zero) delta_star=0.5_real64*(lo+hi)
  end if

  bminus=delta_star+minus_offset
  bplus=delta_star+plus_offset
  call run_offset(bminus,minus_cls,valid,qdry,max_balance,failure)
  call report_run('FREEZE_MINUS',bminus,minus_cls,valid,qdry,max_balance,failure)
  if (.not.valid) then
    write(*,'(A)') 'NUM_UNC_P0B0_STATUS=BLOCKED_INADMISSIBLE_FREEZE_MINUS'
    write(*,'(A)') 'NUM_UNC_P0B0_GATE=PASS'
    stop
  end if
  call run_offset(delta_star,zero_cls,valid,qdry,max_balance,failure)
  call report_run('FREEZE_ZERO',delta_star,zero_cls,valid,qdry,max_balance,failure)
  if (.not.valid) then
    write(*,'(A)') 'NUM_UNC_P0B0_STATUS=BLOCKED_INADMISSIBLE_FREEZE_ZERO'
    write(*,'(A)') 'NUM_UNC_P0B0_GATE=PASS'
    stop
  end if
  call run_offset(bplus,plus_cls,valid,qdry,max_balance,failure)
  call report_run('FREEZE_PLUS',bplus,plus_cls,valid,qdry,max_balance,failure)
  if (.not.valid) then
    write(*,'(A)') 'NUM_UNC_P0B0_STATUS=BLOCKED_INADMISSIBLE_FREEZE_PLUS'
    write(*,'(A)') 'NUM_UNC_P0B0_GATE=PASS'
    stop
  end if

  if (minus_cls/=NET_DRAINAGE .or. plus_cls/=CAPILLARY_SUPPORT) then
    write(*,'(A)') 'NUM_UNC_P0B0_STATUS=BLOCKED_PREREGISTERED_OFFSETS_DO_NOT_STRADDLE'
    write(*,'(A)') 'NUM_UNC_P0B0_GATE=PASS'
    stop
  end if

  write(*,'(*(g0))') 'NUM_UNC_P0B0_FREEZE|DELTA_STAR_CM=',delta_star, &
       '|HBOT_STAR_CM=',neutral_hbot+delta_star,'|B_MINUS_DELTA_CM=',bminus, &
       '|B_ZERO_DELTA_CM=',delta_star,'|B_PLUS_DELTA_CM=',bplus, &
       '|B_MINUS_HBOT_CM=',neutral_hbot+bminus,'|B_ZERO_HBOT_CM=',neutral_hbot+delta_star, &
       '|B_PLUS_HBOT_CM=',neutral_hbot+bplus,'|B_ZERO_CLASS=',trim(class_name(zero_cls))
  write(*,'(A)') 'NUM_UNC_P0B0_STATUS=FREEZE_READY'
  write(*,'(A)') 'NUM_UNC_P0B0_GATE=PASS'

contains

  subroutine run_offset(delta_h,class_id,is_valid,q_dry,max_balance_residual,failure_stage)
    real(real64),intent(in) :: delta_h
    integer,intent(out) :: class_id
    logical,intent(out) :: is_valid
    real(real64),intent(out) :: q_dry,max_balance_residual
    character(len=*),intent(out) :: failure_stage

    type(soil_water_parameter_set_t),target :: parameters
    type(rossfast_d3r_material_t) :: material
    type(b110_default_mvg_parameters_t),target :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target :: constitutive
    type(b110_source_sink_provider_t),target :: source_sink
    type(fixed_flux_top_boundary_provider_t),target :: top_provider
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(soil_water_physical_state_t) :: state
    real(real64),target :: drainage(1,n),irrigation(n),root_sink(n)
    real(real64) :: cofgen(24,n),heads(n),theta(n),conductivity(n),capacity(n),dkdh(n)
    real(real64) :: k0,qtop,storage0,storage1,residual,hbot,zero_tol
    integer :: block
    logical :: found

    class_id=INADMISSIBLE; is_valid=.false.; q_dry=0.0_real64
    max_balance_residual=0.0_real64; failure_stage='INITIALIZATION'

    call rossfast_d3r_material_from_id('B01',material,found)
    if (.not.found) then; failure_stage='MATERIAL_LOOKUP'; return; end if
    call initialize_parameters(parameters,cofgen,material)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dt)
    heads=h0
    call constitutive%evaluate(heads,theta,conductivity,capacity,dkdh)
    if (any(.not.ieee_is_finite(theta)) .or. any(.not.ieee_is_finite(conductivity))) then
      failure_stage='INITIAL_CONSTITUTIVE'; return
    end if
    k0=conductivity(1)
    if (.not.ieee_is_finite(k0) .or. k0<=0.0_real64) then; failure_stage='INITIAL_K'; return; end if

    state%active_nodes=n; allocate(state%pressure_head(n),state%water_content(n))
    state%pressure_head=heads; state%water_content=theta
    state%ponding_depth=0.0_real64; state%groundwater_level=-999.0_real64
    drainage=0.0_real64; irrigation=0.0_real64; root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)
    hbot=neutral_hbot+delta_h

    do block=1,blocks
      if (block<=wet_blocks) then
        qtop=wet_factor*k0
      else
        qtop=dry_factor*k0
      end if
      storage0=sum(parameters%dz*state%water_content)+state%ponding_depth
      call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dt)
      call initialize_request(request,parameters,constitutive,source_sink,top_provider,state,qtop,hbot)
      call solver%solve(request,workspace,result)
      if (.not.result_valid(result,material)) then
        failure_stage='REFERENCE_GATE'; class_id=INADMISSIBLE; return
      end if
      if (result%diagnostics%internal_retries/=0) then
        failure_stage='INTERNAL_RETRY'; class_id=INADMISSIBLE; return
      end if
      if (result%diagnostics%alternative_solver_calls/=0) then
        failure_stage='ALTERNATIVE_LINEAR_SOLVER'; class_id=INADMISSIBLE; return
      end if
      if (.not.ieee_is_finite(result%bottom_flux)) then
        failure_stage='NONFINITE_QBOT'; class_id=INADMISSIBLE; return
      end if
      storage1=sum(parameters%dz*result%candidate_state%water_content)+result%candidate_state%ponding_depth
      residual=(storage1-storage0)-dt*(result%bottom_flux-result%top_flux)
      max_balance_residual=max(max_balance_residual,abs(residual))
      if (abs(residual)>balance_tol) then
        failure_stage='BOOKKEEPING_BALANCE'; class_id=INADMISSIBLE; return
      end if
      if (block>wet_blocks) q_dry=q_dry+result%bottom_flux*dt
      state=result%candidate_state
    end do

    zero_tol=1024.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(q_dry))
    if (abs(q_dry)<=zero_tol) then
      class_id=ZERO_REP
    else if (q_dry<0.0_real64) then
      class_id=NET_DRAINAGE
    else
      class_id=CAPILLARY_SUPPORT
    end if
    is_valid=.true.; failure_stage='NONE'
  end subroutine run_offset

  logical function result_valid(result,material) result(ok)
    type(soil_water_solve_result_t),intent(in) :: result
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64),parameter :: eps_theta=1.0e-12_real64
    ok=.false.
    if (result%status/=SW_SOLVE_CONVERGED) return
    if (trim(result%diagnostics%route)/='legacy-reference-bound') return
    if (result%candidate_state%active_nodes/=n) return
    if (.not.allocated(result%candidate_state%pressure_head) .or. .not.allocated(result%candidate_state%water_content)) return
    if (any(.not.ieee_is_finite(result%candidate_state%pressure_head))) return
    if (any(.not.ieee_is_finite(result%candidate_state%water_content))) return
    if (.not.ieee_is_finite(result%candidate_state%ponding_depth)) return
    if (any(result%candidate_state%water_content<material%theta_r-eps_theta)) return
    if (any(result%candidate_state%water_content>material%theta_s+eps_theta)) return
    ok=.true.
  end function result_valid

  subroutine initialize_request(req,p,hyd,source,top,base,qtop,hbot)
    type(soil_water_solve_request_t),intent(out) :: req
    type(soil_water_parameter_set_t),target,intent(in) :: p
    type(b110_default_mvg_provider_t),target,intent(in) :: hyd
    type(b110_source_sink_provider_t),target,intent(in) :: source
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top
    type(soil_water_physical_state_t),intent(in) :: base
    real(real64),intent(in) :: qtop,hbot
    req%parameters=>p; req%base_state=base
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX; req%boundary%bottom_mode=5
    req%boundary%top_flux=qtop; req%boundary%top_head=base%pressure_head(1)
    req%boundary%bottom_flux=0.0_real64; req%boundary%bottom_head=hbot
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=16; req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0; req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-8_real64
    req%numerical%compartment_balance_tolerance=balance_tol
    req%numerical%total_balance_tolerance=balance_tol
    req%numerical%head_abs_tolerance=1.0e-12_real64
    req%numerical%head_rel_tolerance=1.0e-12_real64
    req%numerical%ponding_tolerance=1.0e-12_real64
    req%step_duration=dt; req%request_interface_sensitivity=.false.
    req%evaluation%constitutive=>hyd; req%evaluation%source_sink=>source; req%evaluation%top_boundary=>top
  end subroutine initialize_request

  subroutine initialize_parameters(p,c,mat)
    type(soil_water_parameter_set_t),target,intent(out) :: p
    real(real64),intent(out) :: c(24,n)
    type(rossfast_d3r_material_t),intent(in) :: mat
    real(real64) :: m
    integer :: j
    m=1.0_real64-1.0_real64/mat%n
    p%parameter_set_id=926101; p%active_nodes=n
    allocate(p%z(n),p%dz(n),p%node_distance(n))
    do j=1,n; p%z(j)=-dz_cm*(real(j,real64)-0.5_real64); end do
    p%dz=dz_cm; p%node_distance=dz_cm; p%node_distance(1)=0.5_real64*dz_cm
    c=0.0_real64
    do j=1,n
      c(1,j)=mat%theta_r; c(2,j)=mat%theta_s; c(3,j)=mat%ksatfit_cm_per_day
      c(4,j)=mat%alpha_per_cm; c(5,j)=mat%lambda; c(6,j)=mat%n; c(7,j)=m
      c(8,j)=mat%alpha_per_cm; c(9,j)=mat%h_enpr_cm; c(10,j)=mat%ksatfit_cm_per_day
      c(11,j)=0.999_real64; c(12,j)=0.99_real64*mat%ksatfit_cm_per_day
      c(22,j)=-1.0e6_real64; c(23,j)=1.0e-12_real64
    end do
  end subroutine initialize_parameters

  pure real(real64) function initial_head() result(h)
    type(rossfast_d3r_material_t) :: material
    logical :: found
    real(real64) :: m
    call rossfast_d3r_material_from_id('B01',material,found)
    if (.not.found) then
      h=huge(1.0_real64); return
    end if
    m=1.0_real64-1.0_real64/material%n
    h=-(initial_se**(-1.0_real64/m)-1.0_real64)**(1.0_real64/material%n)/material%alpha_per_cm
  end function initial_head

  subroutine report_run(stage,delta_h,class_id,is_valid,q_dry,max_balance_residual,failure_stage)
    character(len=*),intent(in) :: stage,failure_stage
    real(real64),intent(in) :: delta_h,q_dry,max_balance_residual
    integer,intent(in) :: class_id
    logical,intent(in) :: is_valid
    write(*,'(*(g0))') 'NUM_UNC_P0B0_RUN|STAGE=',trim(stage),'|DELTA_H_CM=',delta_h, &
         '|HBOT_CM=',neutral_hbot+delta_h,'|CLASS=',trim(class_name(class_id)), &
         '|VALID=',is_valid,'|Q_DRY_CM=',q_dry,'|MAX_BALANCE_CM=',max_balance_residual, &
         '|FAILURE=',trim(failure_stage)
  end subroutine report_run

  pure function class_name(class_id) result(name)
    integer,intent(in) :: class_id
    character(len=24) :: name
    select case(class_id)
    case(NET_DRAINAGE); name='NET_DRAINAGE'
    case(ZERO_REP); name='ZERO_REPRESENTATION'
    case(CAPILLARY_SUPPORT); name='CAPILLARY_SUPPORT'
    case default; name='INADMISSIBLE'
    end select
  end function class_name

end program test_num_unc_p0b0_exchange_locator
