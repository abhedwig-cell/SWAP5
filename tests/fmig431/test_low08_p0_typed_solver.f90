program test_low08_p0_typed_solver
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan
  use mod_soil_water_solver_contract
  use mod_reference_richards_legacy_binding
  use mod_reference_richards_state_binding
  use mod_b110_default_mvg_provider
  use mod_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider
  implicit none
  integer,parameter::n=8
  real(real64),parameter::critdz=1.e-5_real64,tol=1.e-11_real64
  type(soil_water_parameter_set_t),target::p
  type(b110_default_mvg_parameters_t),target::hp
  type(b110_default_mvg_provider_t),target::hyd
  type(b110_source_sink_provider_t),target::src
  type(fixed_flux_top_boundary_provider_t),target::top
  type(reference_richards_legacy_solver_t)::solver
  type(reference_richards_legacy_workspace_t)::ws,clean
  real(real64)::initial_theta(n)
  type(soil_water_solve_request_t)::r
  type(soil_water_solve_result_t)::a,b,failed
  real(real64)::cof(24,n),theta(n),k(n),cap(n),dk(n),hplate,threshold
  real(real64),target::dra(1,n),irr(n),roots(n)
  integer::i
  call setup()
  hplate=-80._real64
  threshold=critdz-p%node_distance(n)+hplate

  call set_bottom(threshold)
  initial_theta=r%base_state%water_content
  call solver%solve(r,ws,a)
  write(*,'(a,1x,i0,1x,a,1x,i0,1x,es24.16)') 'LOW08_EQUALITY_DIAG',a%status,trim(a%diagnostics%route),a%diagnostics%nonlinear_iterations,maxval(abs(ws%richards%residual))
  call need(a%status==SW_SOLVE_CONVERGED,'equality solve')
  call need(a%bottom_flux==0._real64,'strict equality is inactive')

  call set_bottom(threshold-1.e-4_real64)
  call solver%solve(r,ws,a)
  call need(a%status==SW_SOLVE_CONVERGED,'inactive solve')
  call need(a%bottom_flux==0._real64,'inactive qbot zero')
  call mass(a,'inactive mass')

  call set_bottom(threshold+1.e-4_real64)
  call solver%solve(r,ws,a)
  call need(a%status==SW_SOLVE_CONVERGED,'active solve')
  call need(a%bottom_flux/=0._real64,'active qbot nonzero')
  call mass(a,'active mass')
  call solver%solve(r,clean,b)
  call need(b%status==SW_SOLVE_CONVERGED,'active replay')
  call need(all(a%candidate_state%pressure_head==b%candidate_state%pressure_head),'A/B/A heads')
  call need(a%bottom_flux==b%bottom_flux,'A/B/A qbot')

  ! Force a nonlinear candidate across the selector threshold. The legacy law
  ! must retain the branch selected from base_state for this entire solve.
  call set_bottom(threshold-1.e-6_real64)
  r%boundary%top_flux=-0.01_real64
  call solver%solve(r,ws,a)
  call need(a%status==SW_SOLVE_CONVERGED,'inactive crossing solve')
  call need(a%bottom_flux==0._real64,'inactive branch immutable across Newton candidates')

  call set_bottom(threshold+1.e-6_real64)
  r%boundary%top_flux=0.01_real64
  call solver%solve(r,ws,a)
  call need(a%status==SW_SOLVE_CONVERGED,'active crossing solve')
  call need(a%bottom_flux/=0._real64,'active branch immutable across Newton candidates')

  r%boundary%bottom_flux=1.e-6_real64
  call solver%solve(r,ws,failed);call need(failed%status==SW_SOLVE_FAILED,'nonzero input qbot fail closed')
  r%boundary%bottom_flux=0._real64
  r%boundary%bottom_external_resistance_days=1._real64
  call solver%solve(r,ws,failed);call need(failed%status==SW_SOLVE_FAILED,'mode3 resistance contamination fail closed')
  r%boundary%bottom_external_resistance_days=0._real64
  r%numerical%conductivity_implicit_mode=1
  call solver%solve(r,ws,failed);call need(failed%status==SW_SOLVE_FAILED,'SWKIMPL1 fail closed')
  r%numerical%conductivity_implicit_mode=0
  r%boundary%bottom_head=ieee_value(0._real64,ieee_quiet_nan)
  call solver%solve(r,ws,failed);call need(failed%status==SW_SOLVE_FAILED,'nonfinite hplate fail closed')

  print '(a)', 'LOW08_P0_THRESHOLD_STRICT_INACTIVE=PASS'
  print '(a)', 'LOW08_P0_ACTIVE_INACTIVE_MASS=PASS'
  print '(a)', 'LOW08_P0_SOLVE_ENTRY_ACTIVE_SET_IMMUTABLE=PASS'
  print '(a)', 'LOW08_P0_REPLAY_FAIL_CLOSED=PASS'
contains
  subroutine set_bottom(hn)
    real(real64),intent(in)::hn
    r%base_state%pressure_head=-100._real64-p%z
    r%base_state%pressure_head(n)=hn
    if(.not.allocated(r%base_state%water_content))allocate(r%base_state%water_content(n))
    call hyd%evaluate(r%base_state%pressure_head,r%base_state%water_content,k,cap,dk)
    r%boundary%bottom_head=hplate;r%boundary%bottom_flux=0
    r%boundary%bottom_external_resistance_days=0;r%boundary%bottom_include_half_cell=.true.
    r%boundary%top_flux=0
  end subroutine
  subroutine mass(x,msg)
    type(soil_water_solve_result_t),intent(in)::x;character(len=*),intent(in)::msg
    real(real64)::v
    v=sum((x%candidate_state%water_content-r%base_state%water_content)*p%dz)-r%step_duration*(x%bottom_flux-x%top_flux)
    call need(abs(v)<=tol,msg)
  end subroutine
  subroutine setup()
    p%active_nodes=n;allocate(p%z(n),p%dz(n),p%node_distance(n))
    do i=1,n;p%z(i)=5._real64-10._real64*i;end do
    p%dz=10;p%node_distance=10;p%node_distance(1)=5
    cof=0;cof(1,:)=.032;cof(2,:)=.423;cof(3,:)=4.75;cof(4,:)=.0135;cof(5,:)=.365;cof(6,:)=1.455
    cof(7,:)=1-1/cof(6,:);cof(8,:)=cof(4,:);cof(10,:)=cof(3,:);cof(11,:)=.999;cof(12,:)=.99*cof(3,:);cof(22,:)=-1.e6;cof(23,:)=1.e-12
    call initialize_b110_default_mvg_parameters(hp,cof);call bind_b110_default_mvg_provider(hyd,hp,.01_real64)
    dra=0;irr=0;roots=0;call bind_b110_source_sink_provider(src,dra,irr,roots)
    r%parameters=>p;r%base_state%active_nodes=n;allocate(r%base_state%pressure_head(n),r%base_state%water_content(n))
    r%base_state%pressure_head=-100._real64-p%z
    call hyd%evaluate(r%base_state%pressure_head,r%base_state%water_content,k,cap,dk)
    r%boundary%bottom_mode=8;r%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX;r%step_duration=.01
    r%numerical%max_iterations=100;r%numerical%max_backtracking=100;r%numerical%conductivity_implicit_mode=0;r%numerical%conductivity_mean_method=1
    r%numerical%head_abs_tolerance=1.e-10;r%numerical%head_rel_tolerance=1.e-10;r%numerical%compartment_balance_tolerance=1.e-10;r%numerical%total_balance_tolerance=1.e-10
    r%evaluation%constitutive=>hyd;r%evaluation%source_sink=>src;r%evaluation%top_boundary=>top
  end subroutine
  subroutine need(x,msg);logical,intent(in)::x;character(len=*),intent(in)::msg;if(.not.x)then;print *,'LOW08_P0_FAIL ',trim(msg);error stop 1;end if;end subroutine
end program
