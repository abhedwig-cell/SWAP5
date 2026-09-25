program test_fahl44_richards_timing
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_grid, only: numnod,z,dz,disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t,soil_water_solve_request_t,soil_water_solve_result_t,SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t,reference_richards_legacy_workspace_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t,b110_default_mvg_provider_t,initialize_b110_default_mvg_parameters,bind_b110_default_mvg_provider
  use mod_b110_adaptive_hydraulic_provider, only: b110_adaptive_hydraulic_provider_t,bind_b110_adaptive_hydraulic_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t,bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none
  integer,parameter::npair=7,nreplay=10000
  real(real64),parameter::dt=0.25_real64,tol=1.0e-12_real64,h0=-75.0_real64,hbot=-50.0_real64
  type(soil_water_parameter_set_t),target::p
  type(b110_default_mvg_parameters_t),target::hp
  type(b110_default_mvg_provider_t),target::analytical
  type(b110_adaptive_hydraulic_provider_t),target::adaptive
  type(b110_source_sink_provider_t),target::ss
  type(fixed_flux_top_boundary_provider_t),target::top
  type(soil_water_solve_request_t)::req
  type(soil_water_solve_result_t)::ra,rb
  type(reference_richards_legacy_solver_t)::sa,sb
  type(reference_richards_legacy_workspace_t)::wa,wb
  real(real64),target::drain(1,numnod),irr(numnod),root(numnod)
  real(real64)::cof(42,numnod),heads(numnod),theta(numnod),k(numnod),cap(numnod),dk(numnod)
  real(real64)::ta(npair),tb(npair),rat(npair),t0,t1,k0,dh,dtheta
  integer::i,r,j
  logical::ok,hit

  call make_cof(cof)
  p%parameter_set_id=944001;p%active_nodes=numnod
  allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod));p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod)
  call initialize_b110_default_mvg_parameters(hp,cof)
  call bind_b110_default_mvg_provider(analytical,hp,dt)
  call bind_b110_adaptive_hydraulic_provider(adaptive,hp,dt,ok,hit);call require(ok,'adaptive bind')
  heads=h0;call analytical%evaluate(heads,theta,k,cap,dk);k0=k(1)
  drain=0.0_real64;irr=0.0_real64;root=0.0_real64;call bind_b110_source_sink_provider(ss,drain,irr,root)
  req%parameters=>p;req%base_state%active_nodes=numnod
  allocate(req%base_state%pressure_head(numnod),req%base_state%water_content(numnod))
  req%base_state%pressure_head=heads;req%base_state%water_content=theta;req%base_state%ponding_depth=0.0_real64;req%base_state%groundwater_level=-2.0_real64
  req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX;req%boundary%bottom_mode=5
  req%boundary%top_flux=-k0;req%boundary%top_head=h0;req%boundary%bottom_flux=0.0_real64;req%boundary%bottom_head=hbot
  req%physical%macropore_active=.false.;req%numerical%max_iterations=16;req%numerical%max_backtracking=8
  req%numerical%conductivity_implicit_mode=0;req%numerical%conductivity_mean_method=1;req%numerical%min_step_duration=1.0e-8_real64
  req%numerical%compartment_balance_tolerance=tol;req%numerical%total_balance_tolerance=tol
  req%numerical%head_abs_tolerance=tol;req%numerical%head_rel_tolerance=tol;req%numerical%ponding_tolerance=tol
  req%step_duration=dt;req%request_interface_sensitivity=.false.;req%evaluation%source_sink=>ss;req%evaluation%top_boundary=>top

  req%evaluation%constitutive=>analytical;call sa%solve(req,wa,ra);call require(ra%status==SW_SOLVE_CONVERGED,'analytical converge')
  req%evaluation%constitutive=>adaptive;call sb%solve(req,wb,rb);call require(rb%status==SW_SOLVE_CONVERGED,'adaptive converge')
  dh=maxval(abs(ra%candidate_state%pressure_head-rb%candidate_state%pressure_head))
  dtheta=maxval(abs(ra%candidate_state%water_content-rb%candidate_state%water_content))
  call require(ra%diagnostics%nonlinear_iterations==rb%diagnostics%nonlinear_iterations,'iteration path')
  call require(ra%diagnostics%backtracking_attempts==rb%diagnostics%backtracking_attempts,'backtrack path')
  call require(dh<=0.05_real64 .and. dtheta<=1.0e-4_real64,'fidelity')
  write(*,'(*(g0))') 'FAHL44_RICHARDS_FIDELITY|DH=',dh,'|DTHETA=',dtheta,'|ITER=',ra%diagnostics%nonlinear_iterations,'|BACKTRACK=',ra%diagnostics%backtracking_attempts,'|REF_DEMAND=',ra%diagnostics%constitutive_candidate_demand_evaluations,'|ADAPT_DEMAND=',rb%diagnostics%constitutive_candidate_demand_evaluations

  do r=1,npair
    if(mod(r,2)==1)then
      call timed(.false.,ta(r));call timed(.true.,tb(r))
    else
      call timed(.true.,tb(r));call timed(.false.,ta(r))
    end if
    rat(r)=tb(r)/ta(r)
    write(*,'(*(g0))') 'FAHL44_RICHARDS_PAIR|PAIR=',r,'|REF=',ta(r),'|ADAPT=',tb(r),'|RATIO=',rat(r)
  end do
  call sortv(rat)
  write(*,'(*(g0))') 'FAHL44_RICHARDS_MEDIAN_RATIO=',rat((npair+1)/2)
  write(*,'(A)') 'FAHL44_RICHARDS_TIMING=PASS'
contains
  subroutine timed(use_adapt,elapsed)
    logical,intent(in)::use_adapt
    real(real64),intent(out)::elapsed
    integer::q
    call cpu_time(t0)
    do q=1,nreplay
      req%base_state%pressure_head=heads;req%base_state%water_content=theta
      if(use_adapt)then;req%evaluation%constitutive=>adaptive;call sb%solve(req,wb,rb)
      else;req%evaluation%constitutive=>analytical;call sa%solve(req,wa,ra);end if
    end do
    call cpu_time(t1);elapsed=(t1-t0)/real(nreplay,real64)
  end subroutine
  subroutine make_cof(c)
    real(real64),intent(out)::c(42,numnod)
    integer::q
    c=0.0_real64
    do q=1,numnod
      c(1,q)=0.032;c(2,q)=0.423;c(3,q)=4.75;c(4,q)=0.0135;c(5,q)=0.365;c(6,q)=1.455;c(7,q)=1.0-1.0/c(6,q);c(8,q)=c(4,q);c(10,q)=c(3,q);c(11,q)=0.999;c(12,q)=0.99*c(3,q);c(22,q)=-1.0e6;c(23,q)=1.0e-12
    end do
  end subroutine
  subroutine sortv(v)
    real(real64),intent(inout)::v(:);real(real64)::x;integer::a,b
    do a=1,size(v)-1;do b=a+1,size(v);if(v(b)<v(a))then;x=v(a);v(a)=v(b);v(b)=x;end if;end do;end do
  end subroutine
  subroutine require(cond,label)
    logical,intent(in)::cond;character(len=*),intent(in)::label
    if(.not.cond)then;write(*,'(A,1X,A)')'FAHL44_FAIL',trim(label);error stop 1;end if
  end subroutine
end program
