program swap431_perf01_column
  use iso_fortran_env,only:real64,int64,error_unit
  use MOD_grid
  use variables
  use MOD_MvG,only:cofgen,calc_cofgen_extra,set_cofgen_pointers,watcon,swsophy,iHWCKmodel,sw_use_elas, &
    fl_use_tables,fl_use_kh_power
  use MOD_swap_base,only:swmacro,swhyst,swrunon,swpondmx
  use MOD_meteo,only:nraidt,peva,empreva,epond
  use MOD_irrigation,only:nird,qssdi
  use MOD_snow,only:melt
  use MOD_frost,only:rfcp
  use MOD_drain,only:qdra,nrlevs
  use MOD_top,only:boundtop,ftoph
  use MOD_swap_mp,only:frarmtrx,armpss
  implicit none
  integer::case_id,i,steps,retries,nl,attempts,u
  integer(int64)::tick,finish,dtick,c0,c1,rate
  real(real64)::horizon,simtime,initial_head,storage0,storage1,mass,maxmass,inc,out,cumin,cumout,cpu0,cpu1,corecpu,corewall
  character(len=64)::arg
  call get_command_argument(1,arg);read(arg,*)horizon
  call get_command_argument(2,arg);read(arg,*)case_id
  numnod=50;numlay=1;nsublay=1;layer=1;indeks=-1;fhyst=1.0_real64
  dz=2.0_real64;disnod=2.0_real64;disnod(1)=1.0_real64;disnod(numnod+1)=1.0_real64
  do i=1,numnod
    z(i)=-1.0_real64-2.0_real64*real(i-1,real64)
  end do
  swmacro=0;swhyst=0;swrunon=0;swpondmx=0;swsophy=0;sw_use_elas=0
  fl_use_tables=.false.;fl_use_kh_power=.false.;iHWCKmodel=1;fluseksatexm=.false.
  frarmtrx=1.0_real64;armpss=0.0_real64;rfcp=1.0_real64
  cofgen=0.0_real64
  do i=1,numnod
    cofgen(1,i)=.032_real64;cofgen(2,i)=.423_real64;cofgen(3,i)=4.75_real64
    if(case_id==8.and.i>25)cofgen(3,i)=2.5_real64
    cofgen(4,i)=.0135_real64;cofgen(5,i)=.365_real64;cofgen(6,i)=1.455_real64
    cofgen(7,i)=1.0_real64-1.0_real64/cofgen(6,i);cofgen(8,i)=cofgen(4,i)
    cofgen(10,i)=cofgen(3,i);cofgen(11,i)=.999_real64;cofgen(12,i)=.99_real64*cofgen(3,i)
    cofgen(22,i)=-1.e6_real64;cofgen(23,i)=1.e-12_real64
  end do
  call set_cofgen_pointers();call calc_cofgen_extra(numnod)
  initial_head=-75.0_real64
  if(case_id==3)initial_head=-500.0_real64
  if(case_id==4)initial_head=-10.0_real64
  h=initial_head
  do i=1,numnod
    theta(i)=watcon(i,h(i))
  end do
  ksatfit=4.75_real64;ksatexm=4.75_real64
  swkimpl=0;swkmean=1;maxit=80;maxbacktr=20;dtmin=1.e-6_real64
  CritDevBalCp=1.e-12_real64;CritDevBalTot=1.e-12_real64
  critdevh2cp=1.e-12_real64;critdevh1cp=1.e-12_real64;critdevponddt=1.e-12_real64
  fldtmin=.false.;fldaystart=.true.;dt=.005_real64;swbotb=2;qbot=-.05_real64
  qrot=0.0_real64;qdra=0.0_real64;qssdi=0.0_real64;nrlevs=1
  if(case_id==2)qrot(1:20)=.05_real64/20.0_real64
  if(case_id==6)qdra(1,20:40)=.02_real64/21.0_real64
  hbot=-10.0_real64;gwlinp=-10.0_real64;gwl=-2.0_real64;gwlm1=gwl
  if(case_id==4)swbotb=5
  pond=0.0_real64;pondm1=0.0_real64;pondmx=0.0_real64;runon=0.0_real64
  reva=0.0_real64;epd=0.0_real64;peva=0.0_real64;empreva=0.0_real64;epond=0.0_real64
  nird=0.0_real64;melt=0.0_real64;nraidt=.1_real64
  call boundtop(1)
  tick=0;finish=nint(horizon*1.e6_real64,int64);steps=0;attempts=0;retries=0;nl=0
  corecpu=0.0_real64;corewall=0.0_real64;maxmass=0.0_real64;cumin=0.0_real64;cumout=0.0_real64
  open(newunit=u,file='legacy_trajectory.bin',access='stream',form='unformatted',status='replace')
  do while(tick<finish)
    simtime=real(tick,real64)*1.e-6_real64;t1900=simtime
    dtick=min(5000_int64,finish-tick);dt=real(dtick,real64)*1.e-6_real64
    nraidt=.1_real64+.08_real64*sin(6.283185307179586_real64*simtime)
    if(case_id==3)nraidt=.01_real64
    if(case_id==5.and.mod(simtime,1.0_real64)<.1_real64)nraidt=5.0_real64
    if(case_id==7)nraidt=.05_real64
    hm1=h;thetm1=theta;pondm1=pond;gwlm1=gwl;dtold=dt
    storage0=sum(theta(1:numnod)*dz(1:numnod))+pond
    do
      call cpu_time(cpu0);call system_clock(c0,rate)
      call headcalc()
      call system_clock(c1);call cpu_time(cpu1)
      corecpu=corecpu+cpu1-cpu0;corewall=corewall+real(c1-c0,real64)/real(rate,real64)
      attempts=attempts+1;nl=nl+numbit
      if(.not.fldecdt)exit
      retries=retries+1;dtick=dtick/2;dt=real(dtick,real64)*1.e-6_real64
      if(dt<dtmin)error stop 'legacy retry floor'
    end do
    if(ftoph)error stop 'legacy top switched away from matched fixed flux'
    if(swbotb==5)qbot=-kmean(numnod+1)*((h(numnod)-hbot)/disnod(numnod+1)+1.0_real64)
    storage1=sum(theta(1:numnod)*dz(1:numnod))+pond
    inc=(max(0.0_real64,-qtop)+max(0.0_real64,qbot))*dt
    out=(max(0.0_real64,qtop)+max(0.0_real64,-qbot)+sum(qrot(1:numnod))+sum(qdra(:,1:numnod)))*dt
    mass=storage1-storage0-inc+out;maxmass=max(maxmass,abs(mass));cumin=cumin+inc;cumout=cumout+out
    if(abs(mass)>1.e-12_real64)error stop 'legacy independent mass'
    steps=steps+1;tick=tick+dtick
    write(u)steps,dt,numbit,retries,mass,h(1:numnod),theta(1:numnod),pond,gwl,qtop,qbot, &
      sum(qrot(1:numnod))*dt,sum(qdra(:,1:numnod))*dt
  end do
  close(u)
  print '(*(g0))','LEGACY_AUDIT|STEPS=',steps,'|ATTEMPTS=',attempts,'|RETRIES=',retries,'|NL=',nl, &
    '|MAX_MASS=',maxmass,'|IN=',cumin,'|OUT=',cumout
  write(error_unit,'(A,ES24.16,A,ES24.16)')'RICHARDS_SOLVER_TIME CPU=',corecpu,' WALL=',corewall
end program
