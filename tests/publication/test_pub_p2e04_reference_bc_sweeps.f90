program test_pub_p2e04_reference_bc_sweeps
  use, intrinsic :: iso_fortran_env, only: real64, real128
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: n = ROSSFAST_D3R_N_CELLS
  integer, parameter :: ntarget = 5
  integer, parameter :: n_iter = 4
  integer, parameter :: n_tol = 7
  character(len=28), parameter :: target_ids(ntarget) = [character(len=28) :: &
       'F1_B01_NOMINAL_COARSE', 'F2_B01_DRYING_HALF1', 'F3_O18_NOMINAL_HALF2', &
       'C1_B12_WETTING_COARSE', 'C2_B01_NOMINAL_COARSE']
  character(len=3), parameter :: material_ids(ntarget) = [character(len=3) :: 'B01','B01','O18','B12','B01']
  real(real64), parameter :: se_values(ntarget) = [0.65_real64,0.65_real64,0.85_real64,0.65_real64,0.85_real64]
  real(real64), parameter :: qtop_factor(ntarget) = [0.010_real64,-0.005_real64,0.010_real64,0.025_real64,0.010_real64]
  real(real64), parameter :: qbot_factor(ntarget) = [-0.004_real64,-0.019_real64,-0.004_real64,0.011_real64,-0.004_real64]
  real(real64), parameter :: target_dt(ntarget) = [0.0004_real64,0.0008_real64,0.0008_real64,0.0004_real64,0.0016_real64]
  logical, parameter :: needs_precursor(ntarget) = [.false.,.false.,.true.,.false.,.false.]
  integer, parameter :: iteration_ladder(n_iter) = [8,16,32,64]
  real(real64), parameter :: total_tol_ladder(n_tol) = [1.0e-12_real64,1.25e-12_real64,1.5e-12_real64, &
       2.0e-12_real64,4.0e-12_real64,8.0e-12_real64,1.6e-11_real64]

  integer :: itarget
  do itarget=1,ntarget
    call run_target(itarget)
  end do
  write(*,'(A)') 'PUB_P2E04_ROSSFAST_SOLVER_EXECUTED=FALSE'
  write(*,'(A)') 'PUB_P2E04_PRODUCTION_TOLERANCE_CHANGED=FALSE'
  write(*,'(A)') 'PUB_P2E04_ROSSFAST_THRESHOLD_FROZEN=FALSE'
  write(*,'(A)') 'PUB_P2E04_STAGE_BC_SWEEPS=PASS'

contains

  subroutine run_target(index)
    integer, intent(in) :: index
    type(soil_water_parameter_set_t), target :: parameters
    type(rossfast_d3r_material_t) :: material
    type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
    type(b110_default_mvg_provider_t), target :: constitutive
    type(b110_source_sink_provider_t), target :: source_sink
    type(fixed_flux_top_boundary_provider_t), target :: top_boundary
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result, precursor_result
    type(soil_water_physical_state_t) :: fixed_base, stage_c_reference
    real(real64), target :: drainage(1,n), irrigation(n), root_sink(n)
    real(real64) :: cofgen(24,n), heads(n), theta0(n), conductivity(n), capacity(n), dkdh(n)
    real(real64) :: h0, k0, qtop, qbot
    real(real64) :: sum_forward, sum_reverse, sum_high, max_abs_residual
    real(real64) :: dh_inf, dtheta_inf, dstorage
    integer :: balance_flags, head_flags, i, j
    integer :: stage_b_status(n_iter)
    logical :: found, reference_saved, iteration_resolvable

    call rossfast_d3r_material_from_id(material_ids(index),material,found)
    call require(found,'target material authority')
    h0=head_from_effective_saturation(se_values(index),material)
    call initialize_parameter_contract(parameters,cofgen,material,index)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,target_dt(index))
    heads=h0
    call constitutive%evaluate(heads,theta0,conductivity,capacity,dkdh)
    call require(all(ieee_is_finite(theta0)) .and. all(ieee_is_finite(conductivity)) .and. all(conductivity>0.0_real64), &
         'target initial constitutive state')
    k0=conductivity(1); qtop=qtop_factor(index)*k0; qbot=qbot_factor(index)*k0
    drainage=0.0_real64; irrigation=0.0_real64; root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)
    call make_uniform_base(fixed_base,h0,theta0)

    if (needs_precursor(index)) then
      call initialize_request(request,parameters,constitutive,source_sink,top_boundary,fixed_base,qtop,qbot, &
           target_dt(index),16,1.0e-12_real64)
      call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,target_dt(index))
      call solver%solve(request,workspace,precursor_result)
      call require(precursor_result%status==SW_SOLVE_CONVERGED .and. &
           trim(precursor_result%diagnostics%route)=='legacy-reference-bound','fixed F3 precursor convergence')
      fixed_base=precursor_result%candidate_state
      write(*,'(A,A,A,ES26.17E3)') 'PUB_P2E04_FIXED_PRECURSOR|TARGET=',trim(target_ids(index)), &
           '|MASS=',precursor_result%unrounded_mass_balance_residual
    end if

    write(*,'(A,A)') 'PUB_P2E04_TARGET_BEGIN=',trim(target_ids(index))

    stage_b_status=0
    do i=1,n_iter
      call initialize_request(request,parameters,constitutive,source_sink,top_boundary,fixed_base,qtop,qbot, &
           target_dt(index),iteration_ladder(i),1.0e-12_real64)
      call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,target_dt(index))
      call solver%solve(request,workspace,result)
      stage_b_status(i)=result%status
      call residual_diagnostics(workspace,sum_forward,sum_reverse,sum_high,max_abs_residual,balance_flags,head_flags)
      write(*,'(A,A,A,I0,A,I0,A,A,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,I0,A,I0,A,I0,A,I0)') &
           'PUB_P2E04_STAGE_B|TARGET=',trim(target_ids(index)),'|MAXIT=',iteration_ladder(i),'|STATUS=',result%status, &
           '|ROUTE=',trim(result%diagnostics%route),'|SUM_FWD=',sum_forward,'|SUM_REV=',sum_reverse,'|SUM_HP=',sum_high, &
           '|MAXABS=',max_abs_residual,'|BAL=',balance_flags,'|HEAD=',head_flags,'|ITER=',result%diagnostics%nonlinear_iterations, &
           '|BACKTRACK=',result%diagnostics%backtracking_attempts
    end do
    iteration_resolvable = stage_b_status(2)/=SW_SOLVE_CONVERGED .and. &
         (stage_b_status(3)==SW_SOLVE_CONVERGED .or. stage_b_status(4)==SW_SOLVE_CONVERGED)
    write(*,'(A,A,A,L1)') 'PUB_P2E04_STAGE_B_ITERATION_RESOLVABLE|TARGET=',trim(target_ids(index)), &
         '|VALUE=',iteration_resolvable

    reference_saved=.false.
    do j=1,n_tol
      call initialize_request(request,parameters,constitutive,source_sink,top_boundary,fixed_base,qtop,qbot, &
           target_dt(index),16,total_tol_ladder(j))
      call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,target_dt(index))
      call solver%solve(request,workspace,result)
      call residual_diagnostics(workspace,sum_forward,sum_reverse,sum_high,max_abs_residual,balance_flags,head_flags)
      dh_inf=huge(0.0_real64); dtheta_inf=huge(0.0_real64); dstorage=huge(0.0_real64)
      if (result%status==SW_SOLVE_CONVERGED) then
        if (.not.reference_saved) then
          stage_c_reference=result%candidate_state
          reference_saved=.true.
          dh_inf=0.0_real64; dtheta_inf=0.0_real64; dstorage=0.0_real64
        else
          dh_inf=maxval(abs(result%candidate_state%pressure_head-stage_c_reference%pressure_head))
          dtheta_inf=maxval(abs(result%candidate_state%water_content-stage_c_reference%water_content))
          dstorage=abs(storage(parameters,result%candidate_state)-storage(parameters,stage_c_reference))
        end if
      end if
      write(*,'(A,A,A,ES26.17E3,A,I0,A,A,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,I0,A,I0,A,I0,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3)') &
           'PUB_P2E04_STAGE_C|TARGET=',trim(target_ids(index)),'|TOTAL_TOL=',total_tol_ladder(j),'|STATUS=',result%status, &
           '|ROUTE=',trim(result%diagnostics%route),'|SUM_FWD=',sum_forward,'|SUM_REV=',sum_reverse,'|SUM_HP=',sum_high, &
           '|MAXABS=',max_abs_residual,'|BAL=',balance_flags,'|HEAD=',head_flags,'|ITER=',result%diagnostics%nonlinear_iterations, &
           '|D_H_INF=',dh_inf,'|D_THETA_INF=',dtheta_inf,'|D_STORAGE=',dstorage
    end do
    write(*,'(A,A,A,L1)') 'PUB_P2E04_STAGE_C_ANY_ACCEPTED|TARGET=',trim(target_ids(index)),'|VALUE=',reference_saved
  end subroutine run_target

  subroutine residual_diagnostics(workspace,sum_forward,sum_reverse,sum_high,max_abs,balance_flags,head_flags)
    type(reference_richards_legacy_workspace_t),intent(in) :: workspace
    real(real64),intent(out) :: sum_forward,sum_reverse,sum_high,max_abs
    integer,intent(out) :: balance_flags,head_flags
    real(real128) :: hp
    integer :: i
    sum_forward=huge(0.0_real64); sum_reverse=huge(0.0_real64); sum_high=huge(0.0_real64); max_abs=huge(0.0_real64)
    balance_flags=-1; head_flags=-1
    if (.not.allocated(workspace%richards%residual)) return
    sum_forward=sum(workspace%richards%residual)
    sum_reverse=0.0_real64
    hp=0.0_real128
    do i=size(workspace%richards%residual),1,-1
      sum_reverse=sum_reverse+workspace%richards%residual(i)
    end do
    do i=1,size(workspace%richards%residual)
      hp=hp+real(workspace%richards%residual(i),real128)
    end do
    sum_high=real(hp,real64)
    max_abs=maxval(abs(workspace%richards%residual))
    if (allocated(workspace%richards%nonconverged_balance)) balance_flags=count(workspace%richards%nonconverged_balance)
    if (allocated(workspace%richards%nonconverged_head)) head_flags=count(workspace%richards%nonconverged_head)
  end subroutine residual_diagnostics

  real(real64) function storage(parameters,state) result(value)
    type(soil_water_parameter_set_t),intent(in) :: parameters
    type(soil_water_physical_state_t),intent(in) :: state
    value=sum(parameters%dz*state%water_content)+state%ponding_depth
  end function storage

  subroutine make_uniform_base(state,h0,theta0)
    type(soil_water_physical_state_t),intent(out) :: state
    real(real64),intent(in) :: h0,theta0(n)
    state%active_nodes=n
    allocate(state%pressure_head(n),state%water_content(n))
    state%pressure_head=h0; state%water_content=theta0
    state%ponding_depth=0.0_real64; state%groundwater_level=-999.0_real64
  end subroutine make_uniform_base

  pure real(real64) function head_from_effective_saturation(se,material) result(head_cm)
    real(real64),intent(in) :: se
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64) :: m
    m=1.0_real64-1.0_real64/material%n
    head_cm=-(se**(-1.0_real64/m)-1.0_real64)**(1.0_real64/material%n)/material%alpha_per_cm
  end function head_from_effective_saturation

  subroutine initialize_parameter_contract(parameter_set,cofgen_out,mat,index)
    type(soil_water_parameter_set_t),target,intent(out) :: parameter_set
    real(real64),intent(out) :: cofgen_out(24,n)
    type(rossfast_d3r_material_t),intent(in) :: mat
    integer,intent(in) :: index
    real(real64) :: m
    integer :: i
    m=1.0_real64-1.0_real64/mat%n
    parameter_set%parameter_set_id=920410+index; parameter_set%active_nodes=n
    allocate(parameter_set%z(n),parameter_set%dz(n),parameter_set%node_distance(n))
    do i=1,n; parameter_set%z(i)=-ROSSFAST_D3R_DZ_CM*(real(i,real64)-0.5_real64); end do
    parameter_set%dz=ROSSFAST_D3R_DZ_CM; parameter_set%node_distance=ROSSFAST_D3R_DZ_CM
    cofgen_out=0.0_real64
    do i=1,n
      cofgen_out(1,i)=mat%theta_r; cofgen_out(2,i)=mat%theta_s; cofgen_out(3,i)=mat%ksatfit_cm_per_day
      cofgen_out(4,i)=mat%alpha_per_cm; cofgen_out(5,i)=mat%lambda; cofgen_out(6,i)=mat%n; cofgen_out(7,i)=m
      cofgen_out(8,i)=mat%alpha_per_cm; cofgen_out(9,i)=mat%h_enpr_cm; cofgen_out(10,i)=mat%ksatfit_cm_per_day
      cofgen_out(11,i)=0.999_real64; cofgen_out(12,i)=0.99_real64*mat%ksatfit_cm_per_day
      cofgen_out(22,i)=-1.0e6_real64; cofgen_out(23,i)=1.0e-12_real64
    end do
  end subroutine initialize_parameter_contract

  subroutine initialize_request(req,parameter_set,hydraulic_provider,source_provider,top_provider,base,qtop,qbot,dt,maxit,total_tol)
    type(soil_water_solve_request_t),intent(out) :: req
    type(soil_water_parameter_set_t),target,intent(in) :: parameter_set
    type(b110_default_mvg_provider_t),target,intent(in) :: hydraulic_provider
    type(b110_source_sink_provider_t),target,intent(in) :: source_provider
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top_provider
    type(soil_water_physical_state_t),intent(in) :: base
    real(real64),intent(in) :: qtop,qbot,dt,total_tol
    integer,intent(in) :: maxit
    req%parameters=>parameter_set; req%base_state=base
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX; req%boundary%bottom_mode=2
    req%boundary%top_flux=qtop; req%boundary%top_head=base%pressure_head(1); req%boundary%bottom_flux=qbot
    req%boundary%bottom_head=-999999.0_real64
    req%physical%macropore_active=.false.; req%numerical%max_iterations=maxit; req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0; req%numerical%conductivity_mean_method=1; req%numerical%min_step_duration=1.0e-8_real64
    req%numerical%compartment_balance_tolerance=1.0e-12_real64; req%numerical%total_balance_tolerance=total_tol
    req%numerical%head_abs_tolerance=1.0e-12_real64; req%numerical%head_rel_tolerance=1.0e-12_real64; req%numerical%ponding_tolerance=1.0e-12_real64
    req%step_duration=dt; req%request_interface_sensitivity=.false.
    req%evaluation%constitutive=>hydraulic_provider; req%evaluation%source_sink=>source_provider; req%evaluation%top_boundary=>top_provider
  end subroutine initialize_request

  subroutine require(condition,label)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: label
    if (.not.condition) then; write(*,'(A,1X,A)') 'PUB_P2E04_FAIL',trim(label); error stop 1; end if
  end subroutine require
end program test_pub_p2e04_reference_bc_sweeps
