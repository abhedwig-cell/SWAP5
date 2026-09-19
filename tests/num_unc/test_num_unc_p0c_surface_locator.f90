program test_num_unc_p0c_surface_locator
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, soil_water_top_boundary_result_t, &
       SW_SOLVE_CONVERGED, SW_TOP_BOUNDARY_AVAILABLE
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, &
       evaluate_b110_default_mvg_conductivity
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  implicit none

  integer, parameter :: n = ROSSFAST_D3R_N_CELLS
  integer, parameter :: CLASS_NO_PONDING=0, CLASS_PONDING=1, CLASS_INADMISSIBLE=2
  integer, parameter :: search_count=5, pulse_blocks=8, post_blocks=8, total_blocks=16
  real(real64), parameter :: dt_n0=0.0064_real64
  real(real64), parameter :: initial_se=0.85_real64
  real(real64), parameter :: mass_tol_cm=1.0e-12_real64
  real(real64), parameter :: pond_event_cm=1.0e-10_real64
  real(real64), parameter :: ponding_max_cm=10.0_real64
  real(real64), parameter :: runoff_resistance_day=1.0_real64
  real(real64), parameter :: runoff_exponent=1.0_real64
  integer, parameter :: bisection_max=12
  real(real64), parameter :: bisection_relative_width=1.0e-3_real64
  real(real64), parameter :: search_values(search_count) = [0.25_real64,0.5_real64,1.0_real64,2.0_real64,4.0_real64]
  real(real64), parameter :: pulse_fraction(pulse_blocks) = [0.25_real64,0.5_real64,0.75_real64, &
       1.0_real64,1.0_real64,1.0_real64,1.0_real64,1.0_real64]

  integer :: classes(search_count), i, lo_i, iter, mid_class, minus_class, zero_class, plus_class
  logical :: valid
  real(real64) :: maxpond, maxmass, lo, hi, mid, relwidth, cminus, cplus
  integer :: switch_block
  character(len=48) :: failure

  write(*,'(A)') 'NUM_UNC_P0C_STAGE=C0_N0_ONLY'
  write(*,'(A)') 'NUM_UNC_P0C_N1_EXECUTED=FALSE'
  write(*,'(*(g0))') 'NUM_UNC_P0C_DT_DAY=',dt_n0
  write(*,'(*(g0))') 'NUM_UNC_P0C_INITIAL_SE=',initial_se
  write(*,'(A)') 'NUM_UNC_P0C_ROOT_UPTAKE=OFF'
  write(*,'(A)') 'NUM_UNC_P0C_BOTTOM_BOUNDARY=PRESCRIBED_ZERO_FLUX'

  classes=CLASS_INADMISSIBLE
  do i=1,search_count
    call run_multiplier(search_values(i),classes(i),valid,maxpond,maxmass,switch_block,failure)
    call report_run('SEARCH',search_values(i),classes(i),valid,maxpond,maxmass,switch_block,failure)
    if (.not.valid) then
      write(*,'(A)') 'NUM_UNC_P0C_LOCATOR_STATUS=BLOCKED_INADMISSIBLE_SEARCH_POINT'
      write(*,'(A)') 'NUM_UNC_P0C_LOCATOR_GATE=PASS'
      stop
    end if
  end do

  lo_i=0
  do i=1,search_count-1
    if (classes(i)==CLASS_NO_PONDING .and. classes(i+1)==CLASS_PONDING) then
      lo_i=i
      exit
    end if
  end do
  if (lo_i==0) then
    write(*,'(A)') 'NUM_UNC_P0C_LOCATOR_STATUS=NO_TRANSITION_IN_DECLARED_ENVELOPE'
    write(*,'(A)') 'NUM_UNC_P0C_LOCATOR_GATE=PASS'
    stop
  end if

  lo=search_values(lo_i); hi=search_values(lo_i+1)
  write(*,'(*(g0))') 'NUM_UNC_P0C_INITIAL_BRACKET|LO=',lo,'|HI=',hi

  do iter=1,bisection_max
    relwidth=(hi-lo)/max(0.5_real64*(hi+lo),tiny(1.0_real64))
    if (relwidth<=bisection_relative_width) exit
    mid=0.5_real64*(lo+hi)
    call run_multiplier(mid,mid_class,valid,maxpond,maxmass,switch_block,failure)
    call report_run('BISECT',mid,mid_class,valid,maxpond,maxmass,switch_block,failure)
    if (.not.valid) then
      write(*,'(A)') 'NUM_UNC_P0C_LOCATOR_STATUS=BLOCKED_INADMISSIBLE_BISECTION'
      write(*,'(A)') 'NUM_UNC_P0C_LOCATOR_GATE=PASS'
      stop
    end if
    if (mid_class==CLASS_NO_PONDING) then
      lo=mid
    else if (mid_class==CLASS_PONDING) then
      hi=mid
    else
      write(*,'(A)') 'NUM_UNC_P0C_LOCATOR_STATUS=BLOCKED_INVALID_CLASSIFICATION'
      write(*,'(A)') 'NUM_UNC_P0C_LOCATOR_GATE=PASS'
      stop
    end if
  end do

  mid=0.5_real64*(lo+hi)
  cminus=0.90_real64*mid
  cplus=1.10_real64*mid

  call run_multiplier(cminus,minus_class,valid,maxpond,maxmass,switch_block,failure)
  call report_run('FREEZE_MINUS',cminus,minus_class,valid,maxpond,maxmass,switch_block,failure)
  if (.not.valid) then
    write(*,'(A)') 'NUM_UNC_P0C_LOCATOR_STATUS=BLOCKED_INADMISSIBLE_FREEZE_MINUS'
    write(*,'(A)') 'NUM_UNC_P0C_LOCATOR_GATE=PASS'
    stop
  end if
  call run_multiplier(mid,zero_class,valid,maxpond,maxmass,switch_block,failure)
  call report_run('FREEZE_ZERO',mid,zero_class,valid,maxpond,maxmass,switch_block,failure)
  if (.not.valid) then
    write(*,'(A)') 'NUM_UNC_P0C_LOCATOR_STATUS=BLOCKED_INADMISSIBLE_FREEZE_ZERO'
    write(*,'(A)') 'NUM_UNC_P0C_LOCATOR_GATE=PASS'
    stop
  end if
  call run_multiplier(cplus,plus_class,valid,maxpond,maxmass,switch_block,failure)
  call report_run('FREEZE_PLUS',cplus,plus_class,valid,maxpond,maxmass,switch_block,failure)
  if (.not.valid) then
    write(*,'(A)') 'NUM_UNC_P0C_LOCATOR_STATUS=BLOCKED_INADMISSIBLE_FREEZE_PLUS'
    write(*,'(A)') 'NUM_UNC_P0C_LOCATOR_GATE=PASS'
    stop
  end if

  if (minus_class/=CLASS_NO_PONDING .or. plus_class/=CLASS_PONDING) then
    write(*,'(A)') 'NUM_UNC_P0C_LOCATOR_STATUS=BLOCKED_PREREGISTERED_OFFSETS_DO_NOT_STRADDLE'
    write(*,'(A)') 'NUM_UNC_P0C_LOCATOR_GATE=PASS'
    stop
  end if

  write(*,'(*(g0))') 'NUM_UNC_P0C_FREEZE|BRACKET_LO=',lo,'|BRACKET_HI=',hi, &
       '|TRANSITION_MULTIPLIER=',mid,'|C_MINUS=',cminus,'|C_ZERO=',mid,'|C_PLUS=',cplus, &
       '|C_ZERO_CLASS=',trim(class_name(zero_class))
  write(*,'(A)') 'NUM_UNC_P0C_LOCATOR_STATUS=FREEZE_READY'
  write(*,'(A)') 'NUM_UNC_P0C_LOCATOR_GATE=PASS'

contains

  subroutine run_multiplier(multiplier,class_id,is_valid,max_pond,max_mass,switch_at,failure_stage)
    real(real64),intent(in) :: multiplier
    integer,intent(out) :: class_id,switch_at
    logical,intent(out) :: is_valid
    real(real64),intent(out) :: max_pond,max_mass
    character(len=*),intent(out) :: failure_stage

    type(soil_water_parameter_set_t),target :: parameters
    type(rossfast_d3r_material_t) :: material
    type(b110_default_mvg_parameters_t),target :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target :: constitutive
    type(b110_source_sink_provider_t),target :: source_sink
    type(b110_dynamic_top_boundary_solver_provider_t),target :: dynamic_top
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(soil_water_top_boundary_result_t) :: top_result
    type(soil_water_physical_state_t) :: state
    real(real64),target :: drainage(1,n),irrigation(n),root_sink(n)
    real(real64) :: cofgen(24,n),heads(n),theta(n),conductivity(n),capacity(n),dkdh(n)
    real(real64) :: h0,precip,ktop
    integer :: block
    logical :: found,k_ok

    class_id=CLASS_INADMISSIBLE; is_valid=.false.; max_pond=0.0_real64
    max_mass=0.0_real64; switch_at=0; failure_stage='INITIALIZATION'

    call rossfast_d3r_material_from_id('B01',material,found)
    if (.not.found) then
      failure_stage='MATERIAL_LOOKUP'; return
    end if
    call initialize_parameter_contract(parameters,cofgen,material)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dt_n0)

    h0=head_from_effective_saturation(initial_se,material)
    heads=h0
    call constitutive%evaluate(heads,theta,conductivity,capacity,dkdh)
    if (any(.not.ieee_is_finite(theta)) .or. any(.not.ieee_is_finite(conductivity))) then
      failure_stage='INITIAL_CONSTITUTIVE'; return
    end if

    state%active_nodes=n
    allocate(state%pressure_head(n),state%water_content(n))
    state%pressure_head=heads
    state%water_content=theta
    state%ponding_depth=0.0_real64
    state%groundwater_level=-999.0_real64

    drainage=0.0_real64; irrigation=0.0_real64; root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)

    class_id=CLASS_NO_PONDING
    do block=1,total_blocks
      if (block<=pulse_blocks) then
        precip=multiplier*material%ksatfit_cm_per_day*pulse_fraction(block)
      else
        precip=0.0_real64
      end if

      call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dt_n0)
      call evaluate_b110_default_mvg_conductivity(hydraulic_parameters,1,state%pressure_head(1),ktop,k_ok)
      if (.not.k_ok) then
        failure_stage='START_TOP_CONDUCTIVITY'; class_id=CLASS_INADMISSIBLE; return
      end if
      call bind_b110_dynamic_top_boundary_solver_provider(dynamic_top,parameters,hydraulic_parameters, &
           1,state%ponding_depth,dt_n0,precip,0.0_real64,0.0_real64,0.0_real64, &
           0.0_real64,0.0_real64,ponding_max_cm,runoff_resistance_day,runoff_exponent, &
           fixed_top_node_conductivity=ktop)

      call initialize_request(request,parameters,constitutive,source_sink,dynamic_top,state,dt_n0)
      call solver%solve(request,workspace,result)
      if (.not.result_valid(result,material)) then
        failure_stage='REFERENCE_GATE'; class_id=CLASS_INADMISSIBLE; return
      end if
      if (result%diagnostics%internal_retries/=0) then
        failure_stage='INTERNAL_RETRY'; class_id=CLASS_INADMISSIBLE; return
      end if
      if (result%diagnostics%alternative_solver_calls/=0) then
        failure_stage='ALTERNATIVE_LINEAR_SOLVER'; class_id=CLASS_INADMISSIBLE; return
      end if

      call dynamic_top%evaluate(result%candidate_state%pressure_head(1), &
           result%candidate_state%water_content(1),result%candidate_state%ponding_depth, &
           request%boundary,top_result)
      if (top_result%status/=SW_TOP_BOUNDARY_AVAILABLE) then
        failure_stage='FINAL_TOP_DIAGNOSTIC'; class_id=CLASS_INADMISSIBLE; return
      end if
      if (abs(top_result%runoff_depth)>0.0_real64) then
        failure_stage='RUNOFF_NONZERO'; class_id=CLASS_INADMISSIBLE; return
      end if

      max_mass=max(max_mass,abs(result%integrated_mass_balance_residual_cm))
      max_pond=max(max_pond,result%candidate_state%ponding_depth)
      if (result%candidate_state%ponding_depth>pond_event_cm) then
        class_id=CLASS_PONDING
        if (switch_at==0) switch_at=block
      end if
      state=result%candidate_state
    end do

    is_valid=.true.; failure_stage='NONE'
  end subroutine run_multiplier

  logical function result_valid(result,material) result(ok)
    type(soil_water_solve_result_t),intent(in) :: result
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64),parameter :: theta_eps=1.0e-12_real64
    ok=.false.
    if (result%status/=SW_SOLVE_CONVERGED) return
    if (trim(result%diagnostics%route)/='legacy-reference-bound') return
    if (.not.result%integrated_mass_balance_residual_available) return
    if (.not.ieee_is_finite(result%integrated_mass_balance_residual_cm)) return
    if (abs(result%integrated_mass_balance_residual_cm)>mass_tol_cm) return
    if (.not.result%native_balance_rate_residual_available) return
    if (.not.ieee_is_finite(result%native_balance_rate_residual_cm_per_day)) return
    if (result%candidate_state%active_nodes/=n) return
    if (.not.allocated(result%candidate_state%pressure_head) .or. .not.allocated(result%candidate_state%water_content)) return
    if (any(.not.ieee_is_finite(result%candidate_state%pressure_head))) return
    if (any(.not.ieee_is_finite(result%candidate_state%water_content))) return
    if (.not.ieee_is_finite(result%candidate_state%ponding_depth)) return
    if (result%candidate_state%ponding_depth<0.0_real64) return
    if (any(result%candidate_state%water_content<material%theta_r-theta_eps)) return
    if (any(result%candidate_state%water_content>material%theta_s+theta_eps)) return
    ok=.true.
  end function result_valid

  subroutine initialize_request(req,parameter_set,hydraulic_provider,source_provider,top_provider,base_state,dt)
    type(soil_water_solve_request_t),intent(out) :: req
    type(soil_water_parameter_set_t),target,intent(in) :: parameter_set
    type(b110_default_mvg_provider_t),target,intent(in) :: hydraulic_provider
    type(b110_source_sink_provider_t),target,intent(in) :: source_provider
    type(b110_dynamic_top_boundary_solver_provider_t),target,intent(in) :: top_provider
    type(soil_water_physical_state_t),intent(in) :: base_state
    real(real64),intent(in) :: dt

    req%parameters=>parameter_set
    req%base_state=base_state
    req%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER
    req%boundary%bottom_mode=2
    req%boundary%top_flux=0.0_real64
    req%boundary%top_head=base_state%pressure_head(1)
    req%boundary%bottom_flux=0.0_real64
    req%boundary%bottom_head=-999999.0_real64
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=16
    req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0
    req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-8_real64
    req%numerical%compartment_balance_tolerance=mass_tol_cm
    req%numerical%total_balance_tolerance=mass_tol_cm
    req%numerical%head_abs_tolerance=1.0e-12_real64
    req%numerical%head_rel_tolerance=1.0e-12_real64
    req%numerical%ponding_tolerance=1.0e-12_real64
    req%step_duration=dt
    req%request_interface_sensitivity=.false.
    req%evaluation%constitutive=>hydraulic_provider
    req%evaluation%source_sink=>source_provider
    req%evaluation%dynamic_top_boundary=>top_provider
  end subroutine initialize_request

  subroutine initialize_parameter_contract(parameter_set,cofgen_out,mat)
    type(soil_water_parameter_set_t),target,intent(out) :: parameter_set
    real(real64),intent(out) :: cofgen_out(24,n)
    type(rossfast_d3r_material_t),intent(in) :: mat
    real(real64) :: m
    integer :: j
    m=1.0_real64-1.0_real64/mat%n
    parameter_set%parameter_set_id=926001
    parameter_set%active_nodes=n
    allocate(parameter_set%z(n),parameter_set%dz(n),parameter_set%node_distance(n))
    do j=1,n
      parameter_set%z(j)=-ROSSFAST_D3R_DZ_CM*(real(j,real64)-0.5_real64)
    end do
    parameter_set%dz=ROSSFAST_D3R_DZ_CM
    parameter_set%node_distance=ROSSFAST_D3R_DZ_CM
    parameter_set%node_distance(1)=0.5_real64*ROSSFAST_D3R_DZ_CM
    cofgen_out=0.0_real64
    do j=1,n
      cofgen_out(1,j)=mat%theta_r
      cofgen_out(2,j)=mat%theta_s
      cofgen_out(3,j)=mat%ksatfit_cm_per_day
      cofgen_out(4,j)=mat%alpha_per_cm
      cofgen_out(5,j)=mat%lambda
      cofgen_out(6,j)=mat%n
      cofgen_out(7,j)=m
      cofgen_out(8,j)=mat%alpha_per_cm
      cofgen_out(9,j)=mat%h_enpr_cm
      cofgen_out(10,j)=mat%ksatfit_cm_per_day
      cofgen_out(11,j)=0.999_real64
      cofgen_out(12,j)=0.99_real64*mat%ksatfit_cm_per_day
      cofgen_out(22,j)=-1.0e6_real64
      cofgen_out(23,j)=1.0e-12_real64
    end do
  end subroutine initialize_parameter_contract

  pure real(real64) function head_from_effective_saturation(se,material) result(head_cm)
    real(real64),intent(in) :: se
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64) :: m
    m=1.0_real64-1.0_real64/material%n
    head_cm=-(se**(-1.0_real64/m)-1.0_real64)**(1.0_real64/material%n)/material%alpha_per_cm
  end function head_from_effective_saturation

  subroutine report_run(stage,multiplier,class_id,is_valid,max_pond,max_mass,switch_at,failure_stage)
    character(len=*),intent(in) :: stage,failure_stage
    real(real64),intent(in) :: multiplier,max_pond,max_mass
    integer,intent(in) :: class_id,switch_at
    logical,intent(in) :: is_valid
    write(*,'(*(g0))') 'NUM_UNC_P0C_RUN|STAGE=',trim(stage),'|MULT=',multiplier, &
         '|CLASS=',trim(class_name(class_id)),'|VALID=',is_valid,'|MAX_POND_CM=',max_pond, &
         '|MAX_MASS_CM=',max_mass,'|SWITCH_BLOCK=',switch_at,'|FAILURE=',trim(failure_stage)
  end subroutine report_run

  pure function class_name(class_id) result(name)
    integer,intent(in) :: class_id
    character(len=16) :: name
    select case(class_id)
    case(CLASS_NO_PONDING); name='NO_PONDING'
    case(CLASS_PONDING); name='PONDING'
    case default; name='INADMISSIBLE'
    end select
  end function class_name

end program test_num_unc_p0c_surface_locator
