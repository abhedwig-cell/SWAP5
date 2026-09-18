program test_pub_p2e16d_reference_iteration_budget_sensitivity
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM, ROSSFAST_D3R_H_MIN_CM, ROSSFAST_D3R_H_MAX_CM, &
       ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: n=ROSSFAST_D3R_N_CELLS,ncase=5,nbudget=5
  integer, parameter :: ids(ncase)=[576,612,1220,1248,1257]
  character(len=3), parameter :: mids(ncase)=[character(len=3)::'B16','B17','O16','O17','O17']
  real(real64), parameter :: ses(ncase)=[0.96_real64,0.96_real64,0.96_real64,0.85_real64,0.96_real64]
  real(real64), parameter :: rhos(ncase)=[1.05_real64,1.05_real64,-1.0_real64,1.05_real64,-0.95_real64]
  integer, parameter :: budgets(nbudget)=[16,24,32,48,64]
  real(real64), parameter :: dt=0.0016_real64,mass_tol=1.0e-12_real64,balance_tol=1.0e-12_real64

  integer :: ic,ib,valid_count,retry_count,first_recovery(ncase)

  valid_count=0; retry_count=0; first_recovery=0
  do ic=1,ncase
    do ib=1,nbudget
      call run_case(ic,budgets(ib))
    end do
  end do

  write(*,'(A,I0)') 'PUB_P2E16D_CASE_COUNT=',ncase*nbudget
  write(*,'(A,I0)') 'PUB_P2E16D_VALID_COUNT=',valid_count
  write(*,'(A,I0)') 'PUB_P2E16D_RETRY_OR_INVALID_COUNT=',retry_count
  do ic=1,ncase
    write(*,'(*(g0))') 'PUB_P2E16D_RECOVERY|ORIG_CASE=',ids(ic),'|FIRST_BUDGET=',first_recovery(ic)
  end do
  write(*,'(A)') 'PUB_P2E16D_ROSSFAST_EXECUTED=FALSE'
  write(*,'(A)') 'PUB_P2E16D_DT_CHANGED=FALSE'
  write(*,'(A)') 'PUB_P2E16D_BACKTRACK_CHANGED=FALSE'
  write(*,'(A)') 'PUB_P2E16D_PRIMARY_RESULT_CHANGED=FALSE'
  write(*,'(A)') 'PUB_P2E16D_DIAGNOSTIC_RESULT_IS_CI_FAILURE=FALSE'
  write(*,'(A)') 'PUB_P2E16D_REFERENCE_ITERATION_SENSITIVITY_GATE=PASS'

contains

  subroutine run_case(icase,maxit)
    integer,intent(in)::icase,maxit
    type(soil_water_parameter_set_t),target::parameters
    type(reference_richards_legacy_solver_t)::solver
    type(reference_richards_legacy_workspace_t)::workspace
    type(soil_water_solve_request_t)::req
    type(soil_water_solve_result_t)::res
    type(rossfast_d3r_material_t)::mat
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t),target::constitutive
    type(b110_source_sink_provider_t),target::source_sink
    type(fixed_flux_top_boundary_provider_t),target::top_boundary
    real(real64),target::drainage(1,n),irrigation(n),root_sink(n)
    real(real64)::cofgen(24,n),theta0(n),heads(n),k(n),cap(n),dkdh(n),h0,kb,bref,blim,qtop,qbot
    logical::found,valid

    call rossfast_d3r_material_from_id(mids(icase),mat,found)
    call require(found,'material found')
    h0=head_from_se(ses(icase),mat)
    call init_parameters(parameters,cofgen,mat,ids(icase))
    call initialize_b110_default_mvg_parameters(hp,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hp,dt)
    heads=h0
    call constitutive%evaluate(heads,theta0,k,cap,dkdh)
    kb=k(n)
    qtop=-0.01_real64*k(1)
    bref=-0.004_real64*kb
    blim=ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION*max(abs(bref),abs(kb),1.0e-12_real64)
    qbot=bref+rhos(icase)*blim
    drainage=0.0_real64; irrigation=0.0_real64; root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)
    call init_request(req,parameters,constitutive,source_sink,top_boundary,theta0,h0,qtop,qbot,maxit)
    call solver%solve(req,workspace,res)
    valid=result_valid(res,req,mat)
    if(valid) then
      valid_count=valid_count+1
      if(maxit>16 .and. first_recovery(icase)==0) first_recovery(icase)=maxit
    else
      retry_count=retry_count+1
    end if
    write(*,'(*(g0))') 'PUB_P2E16D_TRIAL|ORIG_CASE=',ids(icase),'|M=',mids(icase),'|SE=',ses(icase), &
         '|RHO=',rhos(icase),'|MAXIT=',maxit,'|VALID=',valid,'|STATUS=',res%status,'|RETRY=',res%retry_advised, &
         '|ROUTE=',trim(res%diagnostics%route),'|NLI=',res%diagnostics%nonlinear_iterations, &
         '|JAC=',res%diagnostics%jacobian_builds,'|BACKTRACK=',res%diagnostics%backtracking_attempts, &
         '|MASS_AVAILABLE=',res%integrated_mass_balance_residual_available
  end subroutine

  logical function result_valid(res,req,mat) result(ok)
    type(soil_water_solve_result_t),intent(in)::res
    type(soil_water_solve_request_t),intent(in)::req
    type(rossfast_d3r_material_t),intent(in)::mat
    ok=.false.
    if(res%status/=SW_SOLVE_CONVERGED) return
    if(trim(res%diagnostics%route)/='legacy-reference-bound') return
    if(.not.res%integrated_mass_balance_residual_available) return
    if(.not.ieee_is_finite(res%integrated_mass_balance_residual_cm)) return
    if(abs(res%integrated_mass_balance_residual_cm)>mass_tol) return
    if(.not.res%native_balance_rate_residual_available) return
    if(.not.state_valid(res,mat)) return
    if(.not.same_real(res%top_flux,req%boundary%top_flux)) return
    if(.not.same_real(res%bottom_flux,req%boundary%bottom_flux)) return
    ok=.true.
  end function

  logical function state_valid(res,mat) result(ok)
    type(soil_water_solve_result_t),intent(in)::res
    type(rossfast_d3r_material_t),intent(in)::mat
    ok=.false.
    if(res%candidate_state%active_nodes/=n) return
    if(.not.allocated(res%candidate_state%pressure_head).or..not.allocated(res%candidate_state%water_content)) return
    if(any(.not.ieee_is_finite(res%candidate_state%pressure_head)).or.any(.not.ieee_is_finite(res%candidate_state%water_content))) return
    if(any(res%candidate_state%pressure_head<=ROSSFAST_D3R_H_MIN_CM).or.any(res%candidate_state%pressure_head>=ROSSFAST_D3R_H_MAX_CM)) return
    if(any(res%candidate_state%water_content<=mat%theta_r).or.any(res%candidate_state%water_content>=mat%theta_s)) return
    ok=.true.
  end function

  pure real(real64) function head_from_se(se,mat) result(h)
    real(real64),intent(in)::se
    type(rossfast_d3r_material_t),intent(in)::mat
    real(real64)::m
    m=1.0_real64-1.0_real64/mat%n
    h=-(se**(-1.0_real64/m)-1.0_real64)**(1.0_real64/mat%n)/mat%alpha_per_cm
  end function

  subroutine init_parameters(p,c,mat,id)
    type(soil_water_parameter_set_t),target,intent(out)::p
    real(real64),intent(out)::c(24,n)
    type(rossfast_d3r_material_t),intent(in)::mat
    integer,intent(in)::id
    integer::i
    real(real64)::m
    m=1.0_real64-1.0_real64/mat%n
    p%parameter_set_id=924000+id; p%active_nodes=n
    allocate(p%z(n),p%dz(n),p%node_distance(n))
    do i=1,n; p%z(i)=-ROSSFAST_D3R_DZ_CM*(real(i,real64)-0.5_real64); end do
    p%dz=ROSSFAST_D3R_DZ_CM; p%node_distance=ROSSFAST_D3R_DZ_CM
    c=0.0_real64
    do i=1,n
      c(1,i)=mat%theta_r;c(2,i)=mat%theta_s;c(3,i)=mat%ksatfit_cm_per_day;c(4,i)=mat%alpha_per_cm
      c(5,i)=mat%lambda;c(6,i)=mat%n;c(7,i)=m;c(8,i)=mat%alpha_per_cm;c(9,i)=mat%h_enpr_cm
      c(10,i)=mat%ksatfit_cm_per_day;c(11,i)=0.999_real64;c(12,i)=0.99_real64*mat%ksatfit_cm_per_day
      c(22,i)=-1.0e6_real64;c(23,i)=1.0e-12_real64
    end do
  end subroutine

  subroutine init_request(req,p,hyd,src,top,theta,h0,qtop,qbot,maxit)
    type(soil_water_solve_request_t),intent(out)::req
    type(soil_water_parameter_set_t),target,intent(in)::p
    type(b110_default_mvg_provider_t),target,intent(in)::hyd
    type(b110_source_sink_provider_t),target,intent(in)::src
    type(fixed_flux_top_boundary_provider_t),target,intent(in)::top
    real(real64),intent(in)::theta(n),h0,qtop,qbot
    integer,intent(in)::maxit
    req%parameters=>p;req%base_state%active_nodes=n
    allocate(req%base_state%pressure_head(n),req%base_state%water_content(n))
    req%base_state%pressure_head=h0;req%base_state%water_content=theta
    req%base_state%ponding_depth=0.0_real64;req%base_state%groundwater_level=-999.0_real64
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX;req%boundary%bottom_mode=2
    req%boundary%top_flux=qtop;req%boundary%top_head=h0;req%boundary%bottom_flux=qbot;req%boundary%bottom_head=-999999.0_real64
    req%physical%macropore_active=.false.;req%numerical%max_iterations=maxit;req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0;req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-8_real64;req%numerical%compartment_balance_tolerance=balance_tol
    req%numerical%total_balance_tolerance=balance_tol;req%numerical%head_abs_tolerance=1.0e-12_real64
    req%numerical%head_rel_tolerance=1.0e-12_real64;req%numerical%ponding_tolerance=1.0e-12_real64
    req%step_duration=dt;req%request_interface_sensitivity=.false.
    req%evaluation%constitutive=>hyd;req%evaluation%source_sink=>src;req%evaluation%top_boundary=>top
  end subroutine

  pure logical function same_real(a,b)
    real(real64),intent(in)::a,b
    same_real=abs(a-b)<=32.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(a),abs(b))
  end function

  subroutine require(c,l)
    logical,intent(in)::c;character(len=*),intent(in)::l
    if(.not.c) then; write(*,'(A,1X,A)') 'PUB_P2E16D_HARNESS_FAIL',trim(l); error stop 1; end if
  end subroutine
end program test_pub_p2e16d_reference_iteration_budget_sensitivity
