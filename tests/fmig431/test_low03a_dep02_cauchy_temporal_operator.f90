program test_low03a_dep02_cauchy_temporal_operator
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use MOD_grid, only: numnod,z,dz,disnod
  use mod_soil_water_solver_contract
  use mod_reference_richards_legacy_binding
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider
  use mod_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider
  implicit none
  real(real64),parameter::dt=.01_real64,h0=-75._real64,tol=1.e-12_real64
  type(soil_water_parameter_set_t),target::p
  type(b110_default_mvg_parameters_t),target::hp
  type(b110_default_mvg_provider_t),target::hyd
  type(b110_source_sink_provider_t),target::src
  type(fixed_flux_top_boundary_provider_t),target::top
  type(reference_richards_legacy_solver_t)::solver
  type(reference_richards_legacy_workspace_t)::ws
  type(soil_water_solve_request_t)::req
  type(soil_water_solve_result_t)::sol
  type(soil_water_temporal_indicator_request_t)::ir
  type(soil_water_temporal_indicator_result_t)::ind
  real(real64),target::dra(1,numnod),irr(numnod),root(numnod)
  real(real64)::cof(24,numnod),heads(numnod),water(numnod),kb(numnod),cap(numnod),dk(numnod)
  real(real64)::cw(numnod),ck(numnod),cc(numnod),cd(numnod)
  real(real64)::res(2),extra(2),expected,wrong_neumann,wrong_dirichlet,defect,dneumann,ddirichlet
  integer::i,j,k,cases,separated
  logical::half
  call configure()
  cases=0;separated=0
  res=[0._real64,10._real64];extra=[0._real64,1.e-6_real64]
  do i=1,2
    do j=1,2
      do k=0,1
        half=k==0
        if(.not.half.and.res(i)==0._real64)cycle
        call one(res(i),half,extra(j),expected,wrong_neumann,wrong_dirichlet,defect,dneumann,ddirichlet)
        cases=cases+1
        if(abs(defect-dneumann)>1.e3_real64*epsilon(1._real64)*max(1._real64,abs(defect)))separated=separated+1
        if(abs(defect-ddirichlet)>1.e3_real64*epsilon(1._real64)*max(1._real64,abs(defect)))separated=separated+1
      end do
    end do
  end do
  call need(cases==6,'complete matrix')
  call need(separated>0,'oracle distinguishes Cauchy stiffness')
  print '(a,i0)', 'LOW03A_DEP02_CASES=',cases
  print '(a,i0)', 'LOW03A_DEP02_SEPARATIONS=',separated
  print '(a)', 'LOW03A_DEP02_CAUCHY_TEMPORAL_OPERATOR=PASS'
contains
  subroutine one(r,include_half,q4,binf,bneumann,bdirichlet,defect,dneumann,ddirichlet)
    real(real64),intent(in)::r,q4
    logical,intent(in)::include_half
    real(real64),intent(out)::binf,bneumann,bdirichlet,defect,dneumann,ddirichlet
    real(real64)::aq,q,stor0,stor1,mres
    integer::n
    n=numnod
    req%base_state%pressure_head=heads;req%base_state%water_content=water
    req%boundary%bottom_mode=3;req%boundary%bottom_flux=q4
    req%boundary%bottom_external_resistance_days=r;req%boundary%bottom_include_half_cell=include_half
    q=1.e-3_real64
    if(include_half)then
      aq=(heads(n)+p%z(n))+(q-q4)*(0.5_real64*p%dz(n)/kb(n)+r)
    else
      aq=(heads(n)+p%z(n))+(q-q4)*r
    end if
    req%boundary%bottom_head=aq;req%boundary%top_flux=-q
    call solver%solve(req,ws,sol)
    call need(sol%status==SW_SOLVE_CONVERGED,'mode3 solve')
    stor0=sum(water*p%dz);stor1=sum(sol%candidate_state%water_content*p%dz)
    mres=stor1-stor0-dt*(sol%bottom_flux-sol%top_flux)
    call need(abs(mres)<=tol,'physical mass')
    ir%previous_right_derivative_available=.true.
    if(allocated(ir%previous_right_derivative))deallocate(ir%previous_right_derivative)
    allocate(ir%previous_right_derivative(n));ir%previous_right_derivative=0._real64
    call solver%evaluate_temporal_indicator(req,sol,ir,ws,ind)
    call need(ind%status==SW_TEMPORAL_INDICATOR_AVAILABLE.and.ind%available,'indicator available')
    call need(ind%additional_full_nonlinear_solves==0.and.ind%additional_tridiagonal_solves==1,'work contract')
    call hyd%evaluate(sol%candidate_state%pressure_head,cw,ck,cc,cd)
    call oracle(r,include_half,ind%current_right_derivative,cc,binf,bneumann,bdirichlet,defect,dneumann,ddirichlet)
    call need(close(ind%head_inf_bound,binf),'independent Cauchy oracle')
    call need(close(ind%defect_m_norm,defect),'independent Cauchy defect norm')
    write(*,'(a,6(1x,es24.16))') 'LOW03A_DEP02_ROW',binf,bneumann,bdirichlet,defect,dneumann,ddirichlet
  end subroutine
  subroutine oracle(r,include_half,deriv,capacity,binf,bneumann,bdirichlet,defect,dneumann,ddirichlet)
    real(real64),intent(in)::r,deriv(:),capacity(:)
    logical,intent(in)::include_half
    real(real64),intent(out)::binf,bneumann,bdirichlet,defect,dneumann,ddirichlet
    real(real64)::mw(numnod),lo(numnod),di(numnod),up(numnod),rhs(numnod),er(numnod)
    real(real64)::x(numnod),xn(numnod),xd(numnod),dn(numnod),dd(numnod),g,raw,dv
    integer::m
    logical::ok
    mw=capacity*p%dz;er=.5_real64*dt*deriv;lo=0;up=0;di=mw/dt
    do m=2,numnod
      g=.5_real64*(kb(m-1)+kb(m))/p%node_distance(m)
      lo(m)=-g;up(m-1)=-g;di(m-1)=di(m-1)+g;di(m)=di(m)+g
    end do
    dn=di;dd=di
    if(include_half)then
      g=1._real64/(.5_real64*p%dz(numnod)/kb(numnod)+r)
    else
      g=1._real64/r
    end if
    di(numnod)=di(numnod)+g
    dd(numnod)=dd(numnod)+kb(numnod)/(.5_real64*p%dz(numnod))
    rhs=(mw/dt)*er
    call thomas(lo,di,up,rhs,x,ok);call need(ok,'oracle cauchy solve')
    call thomas(lo,dn,up,rhs,xn,ok);call need(ok,'oracle neumann solve')
    call thomas(lo,dd,up,rhs,xd,ok);call need(ok,'oracle dirichlet solve')
    raw=sqrt(sum(mw*er*er))
    defect=sqrt(sum(mw*x*x));binf=min(raw,2._real64*defect)/sqrt(minval(mw))
    dneumann=sqrt(sum(mw*xn*xn));bneumann=min(raw,2._real64*dneumann)/sqrt(minval(mw))
    ddirichlet=sqrt(sum(mw*xd*xd));bdirichlet=min(raw,2._real64*ddirichlet)/sqrt(minval(mw))
  end subroutine
  subroutine thomas(lo,di,up,rhs,x,ok)
    real(real64),intent(in)::lo(:),di(:),up(:),rhs(:);real(real64),intent(out)::x(:);logical,intent(out)::ok
    real(real64)::c(size(rhs)),d(size(rhs)),den;integer::m,n
    n=size(rhs);c=0;d=0;x=0;ok=.false.;if(di(1)==0)return
    if(n>1)c(1)=up(1)/di(1);d(1)=rhs(1)/di(1)
    do m=2,n;den=di(m)-lo(m)*c(m-1);if(den==0)return;if(m<n)c(m)=up(m)/den;d(m)=(rhs(m)-lo(m)*d(m-1))/den;end do
    x(n)=d(n);do m=n-1,1,-1;x(m)=d(m)-c(m)*x(m+1);end do;ok=all(ieee_is_finite(x))
  end subroutine
  subroutine configure()
    integer::m
    p%parameter_set_id=390003_int64;p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod));p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod)
    cof=0
    do m=1,numnod
      cof(1,m)=.032;cof(2,m)=.423;cof(3,m)=4.75;cof(4,m)=.0135;cof(5,m)=.365;cof(6,m)=1.455
      cof(7,m)=1-1/cof(6,m);cof(8,m)=cof(4,m);cof(10,m)=cof(3,m);cof(11,m)=.999;cof(12,m)=.99*cof(3,m)
      cof(22,m)=-1.e6;cof(23,m)=1.e-12
    end do
    call initialize_b110_default_mvg_parameters(hp,cof);call bind_b110_default_mvg_provider(hyd,hp,dt)
    heads(1)=h0;do m=2,numnod;heads(m)=heads(m-1)+p%node_distance(m);end do
    call hyd%evaluate(heads,water,kb,cap,dk)
    dra=0;irr=0;root=0;call bind_b110_source_sink_provider(src,dra,irr,root)
    req=soil_water_solve_request_t();req%parameters=>p;req%base_state%active_nodes=numnod
    allocate(req%base_state%pressure_head(numnod),req%base_state%water_content(numnod));req%base_state%pressure_head=heads;req%base_state%water_content=water
    req%step_duration=dt;req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX;req%physical%macropore_active=.false.
    req%numerical%max_iterations=100;req%numerical%max_backtracking=100;req%numerical%conductivity_implicit_mode=0;req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.e-12;req%numerical%compartment_balance_tolerance=tol;req%numerical%total_balance_tolerance=tol
    req%numerical%head_abs_tolerance=tol;req%numerical%head_rel_tolerance=tol;req%numerical%ponding_tolerance=tol
    req%evaluation%constitutive=>hyd;req%evaluation%source_sink=>src;req%evaluation%top_boundary=>top
  end subroutine
  logical function close(a,b);real(real64),intent(in)::a,b;close=abs(a-b)<=32768._real64*epsilon(1._real64)*max(1._real64,abs(a),abs(b));end function
  subroutine need(x,msg);logical,intent(in)::x;character(len=*),intent(in)::msg;if(.not.x)then;print *,'LOW03A_DEP02_FAIL ',trim(msg);error stop 1;end if;end subroutine
end program
