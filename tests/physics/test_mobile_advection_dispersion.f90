program test_mobile_advection_dispersion
  use, intrinsic :: iso_fortran_env,only:real64
  use, intrinsic :: ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use mod_solute_mobile_salt_state
  use mod_solute_mobile_advection_dispersion
  implicit none
  type(mobile_salt_state_t)::initial,candidate,replay
  type(mobile_dispersion_physics_t)::p,badp
  type(mobile_transport_numerical_t)::num,badnum
  type(mobile_transport_receipt_t)::r
  real(real64),allocatable::drain(:,:),source(:),dz(:),w0(:),w1(:),q(:),root(:),c(:),x(:),exact(:)
  real(real64)::g,err(3),relax(3),expected(2),nan,dx,t,pi,sigma,variance,seasonal(2),closure(2),root_error(2)
  integer::status,n,i,j
  pi=acos(-1.0_real64);nan=ieee_value(0.0_real64,ieee_quiet_nan)
  num%enabled=.true.;num%max_step_day=.1_real64;num%max_substeps=100000
  call setup(2)
  dz=[1.0_real64,2.0_real64];w0=.4_real64;w1=w0;q=.0_real64;root=0.0_real64
  p%molecular_diffusion_cm2_day=1.0_real64
  call init([1.0_real64,0.0_real64])
  g=.4_real64**3.33_real64/.5_real64**2
  call run(.1_real64,0.0_real64,0.0_real64,0.0_real64)
  call req(status==SOLUTE_OK.and.r%substeps==1,'one combined coefficient step')
  call req(maxval(abs(candidate%mass_mg_cm2-[.4_real64-.1_real64*g,.1_real64*g]))<1e-15_real64,'source diffusion sign/coefficient')
  expected(1)=1.0_real64/3.0_real64+2.0_real64/3.0_real64*exp(-g*3.75_real64)
  expected(2)=1.0_real64/3.0_real64-1.0_real64/3.0_real64*exp(-g*3.75_real64)
  do j=1,3
    num%max_step_day=.1_real64/2.0_real64**(j-1)
    call run(1.0_real64,0.0_real64,0.0_real64,0.0_real64)
    call req(status==SOLUTE_OK,'joint analytical diffusion')
    relax(j)=maxval(abs(candidate%concentration_mg_cm3-expected))
    call req(abs(r%balance%closure_error_mg_cm2)<1e-14_real64,'joint analytical balance')
  end do
  call req(relax(2)<.6_real64*relax(1).and.relax(3)<.6_real64*relax(2),'joint timestep refinement')
  ! Uniform C stays uniform when water and salt lose the same root/drain sinks.
  dz=1.0_real64;w0=.4_real64;root=[.01_real64,.02_real64];q=[.03_real64,.02_real64,.01_real64]
  drain(1,:)=[.01_real64,-.01_real64];source=0.0_real64
  w1=w0+.5_real64*(q(:2)-q(2:)+source-sum(drain,dim=1)-root)/dz
  p%dispersivity_cm=.2_real64;num%max_step_day=.01_real64
  call init([2.0_real64,2.0_real64])
  call run(.5_real64,2.0_real64,2.0_real64,1.0_real64)
  call req(status==SOLUTE_OK.and.r%substeps>1,'changing water multiple salt steps')
  call req(maxval(abs(candidate%concentration_mg_cm3-2.0_real64))<1e-13_real64,'uniform changing water concentration')
  call req(maxval(abs(r%root_by_node_mg_cm2-[.01_real64,.02_real64]))<1e-14_real64,'node root receipt')
  call req(abs(r%balance%qdra_signed_out_mg_cm2(1))<1e-14_real64,'signed drainage receipt')
  replay=candidate
  call run(.5_real64,2.0_real64,2.0_real64,1.0_real64)
  call req(all(candidate%mass_mg_cm2==replay%mass_mg_cm2),'exact joint replay')
  call req(all(initial%concentration_mg_cm3==2.0_real64),'committed concentration intact')
  ! Zero-solute source adds liquid only, including subcycling.
  q=0.0_real64;root=0.0_real64;drain=0.0_real64;source=.02_real64;w1=w0+.5_real64*source/dz
  call run(.5_real64,0.0_real64,0.0_real64,1.0_real64)
  call req(status==SOLUTE_OK.and.abs(sum(candidate%mass_mg_cm2)-sum(initial%mass_mg_cm2))<1e-14_real64,'zero-solute source balance')
  call req(all(candidate%concentration_mg_cm3<initial%concentration_mg_cm3),'source dilution')
  ! Reverse boundary flow exports from the top and imports through the bottom.
  q=-.02_real64;source=0.0_real64;w1=w0;p%molecular_diffusion_cm2_day=0.0_real64;p%dispersivity_cm=.1_real64
  call init([1.0_real64,3.0_real64])
  call run(.5_real64,0.0_real64,4.0_real64,0.0_real64)
  call req(status==SOLUTE_OK.and.r%balance%top_output_mg_cm2>0.0_real64.and. &
    abs(r%balance%bottom_input_mg_cm2-.04_real64)<1e-14_real64,'boundary reversal ledger')
  call req(abs(r%balance%closure_error_mg_cm2)<1e-14_real64,'boundary reversal closure')
  ! B1.11 top evaporation removes water but leaves dissolved mass in soil.
  q=0.0_real64;q(1)=-.02_real64;root=0.0_real64;source=0.0_real64;drain=0.0_real64
  w1=w0;w1(1)=w0(1)-.02_real64/dz(1)
  p%dispersivity_cm=0.0_real64;p%molecular_diffusion_cm2_day=0.0_real64
  call init([2.0_real64,2.0_real64])
  call advance_mobile_advection_dispersion(initial,dz,w0,w1,q,root,0.0_real64,0.0_real64,0.0_real64, &
    1.0_real64,p,num,drain,source,2.0_real64,.true.,candidate,r,status,top_outflow_carries_solute=.false.)
  call req(status==SOLUTE_OK.and.r%balance%top_output_mg_cm2==0.0_real64,'vapor no salt receipt')
  call req(all(candidate%mass_mg_cm2==initial%mass_mg_cm2).and. &
    candidate%concentration_mg_cm3(1)>2.0_real64,'vapor concentrates retained salt')
  call run(1.0_real64,0.0_real64,0.0_real64,0.0_real64)
  call req(status==SOLUTE_OK.and.abs(r%balance%top_output_mg_cm2-.04_real64)<1e-14_real64,'declared liquid export carries salt')
  q=-.02_real64;w1=w0
  call init([1.0_real64,3.0_real64])
  num%max_substeps=1
  call run(.5_real64,0.0_real64,4.0_real64,0.0_real64)
  call empty(SOLUTE_TRANSPORT_STEP_LIMIT,'substep exhaustion')
  num%max_substeps=100000
  badp=p;p%face_distance_cm=0.0_real64
  call run(.5_real64,0.0_real64,4.0_real64,0.0_real64)
  call empty(SOLUTE_INVALID,'invalid geometry');p=badp
  badnum=num;num%enabled=.false.
  call run(.5_real64,0.0_real64,4.0_real64,0.0_real64)
  call empty(SOLUTE_INVALID,'disabled policy');num=badnum
  p%molecular_diffusion_cm2_day=nan
  call run(.5_real64,0.0_real64,4.0_real64,0.0_real64)
  call empty(SOLUTE_INVALID,'nonfinite coefficient');p=badp
  w1(1)=w1(1)+.01_real64
  call run(.5_real64,0.0_real64,4.0_real64,0.0_real64)
  call empty(SOLUTE_WATER_CLOSURE,'inconsistent water')
  w1=w0;initial%concentration_mg_cm3(1)=2.0_real64
  call run(.5_real64,0.0_real64,4.0_real64,0.0_real64)
  call empty(SOLUTE_INVALID,'inconsistent concentration authority')
  call setup(1)
  deallocate(drain);allocate(drain(0,1))
  dz=1.0_real64;w0=.4_real64;w1=.2_real64;q=0.0_real64;root=.2_real64;source=0.0_real64
  call init([2.0_real64])
  do j=1,2
    num%max_step_day=.0005_real64/real(j,real64)
    call run(1.0_real64,0.0_real64,0.0_real64,10.0_real64)
    call req(status==SOLUTE_OK.and.r%substeps>1,'TSCF ten positivity with zero drainage levels')
    root_error(j)=abs(candidate%mass_mg_cm2(1)-.8_real64*.5_real64**10)/(.8_real64*.5_real64**10)
  end do
  call req(root_error(2)<.02_real64.and.root_error(2)<.6_real64*root_error(1),'drying root analytical refinement')
  call req(abs(sum(r%root_by_node_mg_cm2)+sum(candidate%mass_mg_cm2)-.8_real64)<1e-13_real64,'TSCF nodewise ledger')
  ! A late unrepresentable drying concentration must clear all prior substeps.
  w1=.1_real64;root=.3_real64;num%max_step_day=.1_real64
  call init([1e308_real64])
  call run(1.0_real64,0.0_real64,0.0_real64,0.0_real64)
  call empty(SOLUTE_INVALID,'late drying concentration overflow')
  ! Mechanical spreading + translation: mesh refinement toward the PDE Gaussian.
  sigma=.5_real64;t=.5_real64;variance=sigma*sigma+2.0_real64*.02_real64*t
  do j=1,3
    n=40*2**(j-1);dx=8.0_real64/real(n,real64)
    call setup(n)
    dz=dx;w0=.4_real64;w1=w0;q=.08_real64;root=0.0_real64;source=0.0_real64;drain=0.0_real64
    p%face_distance_cm=dx;p%dispersivity_cm=.1_real64;p%molecular_diffusion_cm2_day=0.0_real64
    x=[( -4.0_real64+(real(i,real64)-.5_real64)*dx,i=1,n)]
    c=exp(-x*x/(2.0_real64*sigma*sigma))/(sqrt(2.0_real64*pi)*sigma)
    exact=exp(-(x-.2_real64*t)**2/(2.0_real64*variance))/sqrt(2.0_real64*pi*variance)
    call init(c)
    num%max_step_day=.001_real64;num%max_substeps=100000
    call run(t,0.0_real64,0.0_real64,0.0_real64)
    call req(status==SOLUTE_OK,'Gaussian transport')
    err(j)=sum(abs(candidate%concentration_mg_cm3-exact))*dx
    call req(all(candidate%mass_mg_cm2>=0.0_real64),'Gaussian positivity')
    call req(abs(r%balance%closure_error_mg_cm2)<1e-13_real64,'Gaussian ledger')
  end do
  call req(err(2)<.7_real64*err(1).and.err(3)<.7_real64*err(2),'Gaussian mesh convergence')
  call season(.25_real64,seasonal(1),closure(1))
  call season(.125_real64,seasonal(2),closure(2))
  call req(abs(seasonal(1)-seasonal(2))/max(seasonal(2),1e-12_real64)<.01_real64,'365-day time refinement below one percent')
  print '(a,2es23.14)','DRYING_TSCF10_RELATIVE_ERRORS=',root_error
  print '(a,2es23.14)','SEASONAL_FINAL_MASS=',seasonal
  print '(a,2es23.14)','SEASONAL_LEDGER_RESIDUAL=',closure
  print '(a,3es23.14)','JOINT_RELAXATION_ERRORS=',relax
  print '(a,3es23.14)','GAUSSIAN_L1_ERRORS=',err
  print '(a)','PPA_WU05E_ADVECTION_DISPERSION=PASS'
contains
  subroutine season(maxdt,finalmass,residual)
    real(real64),intent(in)::maxdt
    real(real64),intent(out)::finalmass,residual
    real(real64)::startmass,net,level,cumulative_root
    integer::day
    call setup(20)
    dz=1.0_real64;w0=.3_real64;w1=w0;q=.01_real64
    p%dispersivity_cm=.2_real64;p%molecular_diffusion_cm2_day=.05_real64
    num%max_step_day=maxdt;num%max_substeps=10000
    call init([( .1_real64+.01_real64*real(i-1,real64),i=1,20)])
    startmass=sum(initial%mass_mg_cm2);net=0.0_real64;cumulative_root=0.0_real64
    do day=1,365
      w1=.3_real64+.1_real64*sin(2.0_real64*pi*real(day,real64)/365.0_real64)
      root=max(w0-w1,0.0_real64)*dz;source=max(w1-w0,0.0_real64)*dz
      drain=.0_real64
      ! Alternate prescribed external drainage direction in the seasonal fixture.
      if(mod(day,2)==0)then
        drain=.001_real64;source=source+.001_real64
      else
        drain=-.001_real64;root=root+.001_real64
      end if
      level=.5_real64+.2_real64*cos(2.0_real64*pi*real(day,real64)/365.0_real64)
      call run(1.0_real64,level,.2_real64,.7_real64)
      call req(status==SOLUTE_OK.and.all(candidate%mass_mg_cm2>=0.0_real64),'seasonal positive transport')
      net=net+r%balance%top_input_mg_cm2-r%balance%top_output_mg_cm2+ &
        r%balance%bottom_input_mg_cm2-r%balance%bottom_output_mg_cm2- &
        r%balance%root_uptake_mg_cm2-sum(r%balance%qdra_signed_out_mg_cm2)
      cumulative_root=cumulative_root+r%balance%root_uptake_mg_cm2
      initial=candidate;w0=w1
    end do
    finalmass=sum(initial%mass_mg_cm2);residual=finalmass-startmass-net
    call req(abs(residual)<1e-11_real64.and.cumulative_root>0.0_real64,'seasonal independent salt ledger')
  end subroutine
  subroutine setup(nn)
    integer,intent(in)::nn
    if(allocated(dz))deallocate(dz,w0,w1,q,root,source,drain)
    allocate(dz(nn),w0(nn),w1(nn),q(nn+1),root(nn),source(nn),drain(1,nn))
    p=mobile_dispersion_physics_t()
    allocate(p%dispersivity_cm(nn-1),p%theta_sat_left(nn-1),p%face_distance_cm(nn-1),p%face_left_weight(nn-1),p%face_right_weight(nn-1))
    p%dispersivity_cm=0.0_real64;p%theta_sat_left=.5_real64;p%face_distance_cm=1.0_real64;p%face_left_weight=.5_real64;p%face_right_weight=.5_real64
    drain=0.0_real64;source=0.0_real64
  end subroutine
  subroutine init(cc)
    real(real64),intent(in)::cc(:)
    call initialize_mobile_salt_state(dz,w0,cc,initial,status)
    call req(status==SOLUTE_OK,'initialization')
  end subroutine
  subroutine run(dt,ctop,cbot,tscf)
    real(real64),intent(in)::dt,ctop,cbot,tscf
    call advance_mobile_advection_dispersion(initial,dz,w0,w1,q,root,ctop,cbot,tscf,dt,p,num,drain,source, &
      2.0_real64,.true.,candidate,r,status)
  end subroutine
  subroutine empty(code,label)
    integer,intent(in)::code
    character(*),intent(in)::label
    call req(status==code,label)
    call req(.not.allocated(candidate%mass_mg_cm2).and..not.allocated(r%root_by_node_mg_cm2).and. &
      .not.allocated(r%balance%qdra_signed_out_mg_cm2).and.r%substeps==0,label//' empty outputs')
  end subroutine
  subroutine req(yes,label)
    logical,intent(in)::yes
    character(*),intent(in)::label
    if(.not.yes)then
      print *, 'FAIL ',label,' STATUS ',status
      error stop 1
    end if
  end subroutine
end program
