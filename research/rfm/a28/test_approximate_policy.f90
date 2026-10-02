program test_a28_approximate_policy
 use,intrinsic::iso_fortran_env,only:real64
 use MOD_grid,only:numnod
 use mod_b110_default_mvg_provider,only:b110_default_mvg_parameters_t,b110_default_mvg_provider_t,initialize_b110_default_mvg_parameters,bind_b110_default_mvg_provider
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_rfm_surface_sorptivity,only:evaluate_rfm_node_sorptivity
 use mod_rfm_runtime_configuration,only:rfm_runtime_configuration_t,RFM_SORPTIVITY_POLICY_EXACT,RFM_SORPTIVITY_POLICY_PERF07_V1
 implicit none
 real(real64),parameter::hs(17)=[-2000._real64,-1000._real64,-500._real64,-400._real64,-350._real64,-300._real64,-250._real64,-200._real64,-150._real64,-100._real64,-75._real64,-50._real64,-30._real64,-20._real64,-10._real64,-3._real64,-1._real64]
 real(real64)::cof(24,numnod),h(numnod),t(numnod),k(numnod),cap(numnod),dk(numnod),s64,sa,rel,maxrel
 real(real64)::wcr,wcs,alpha,npar,lambda,ks
 type(b110_default_mvg_parameters_t),target::hp
 type(b110_default_mvg_provider_t)::hyd
 type(process_hydraulic_view_t)::view
 type(rfm_runtime_configuration_t)::cfg
 integer::u,ios,year,unitid,i,p,count
 character(len=3)::soil
 character(len=1024)::filename,header
 logical::ok
 call get_command_argument(1,filename)
 if(len_trim(filename)==0)error stop 'catalog path required'
 call contract_gate(cfg)
 open(newunit=u,file=trim(filename),status='old',action='read');read(u,'(a)')header
 maxrel=0._real64;count=0
 do
  read(u,*,iostat=ios)year,unitid,soil,wcr,wcs,alpha,npar,lambda,ks
  if(ios<0)exit
  if(ios/=0)error stop 'catalog parse'
  if(year/=2018)error stop 'catalog year'
  count=count+1
  call init_cof(cof,wcr,wcs,alpha,npar,lambda,ks)
  call initialize_b110_default_mvg_parameters(hp,cof);call bind_b110_default_mvg_provider(hyd,hp,.01_real64)
  do i=1,size(hs)
   h=hs(i);call hyd%evaluate(h,t,k,cap,dk)
   view%active_nodes=numnod
   if(allocated(view%pressure_head))deallocate(view%pressure_head,view%water_content)
   allocate(view%pressure_head(numnod),view%water_content(numnod));view%pressure_head=h;view%water_content=t
   view%ponding_depth=0._real64;view%groundwater_level=-150._real64
   p=cfg%sorptivity_panels_for_head(hs(i));if(p<=0)error stop 'policy selection'
   call evaluate_rfm_node_sorptivity(view,hyd,1,64,s64,ok);if(.not.ok)error stop '64'
   call evaluate_rfm_node_sorptivity(view,hyd,1,p,sa,ok);if(.not.ok)error stop 'approx'
   rel=abs(sa-s64)/max(abs(s64),1e-10_real64);maxrel=max(maxrel,rel)
   write(*,'(*(g0,:,","))')'A28',soil,hs(i),p,s64,sa,rel
  end do
 end do
 close(u)
 if(count/=36)error stop 'catalog count'
 write(*,'(*(g0,:,","))')'MAXREL',maxrel
 if(maxrel>0.01_real64)error stop 'one percent gate'
 print '(a)','A28_APPROXIMATE_POLICY_Q1_Q2=PASS'
contains
 subroutine contract_gate(c)
  type(rfm_runtime_configuration_t),intent(inout)::c
  if(c%sorptivity_policy/=RFM_SORPTIVITY_POLICY_EXACT)error stop 'default not exact'
  c%enabled=.true.;c%sigma_b=1;c%f_mb=0;c%connectivity_p=1;c%z_ah_cm=0;c%z_ic_cm=10;c%chi_wall=0
  c%exchange_length_cm=1;c%mb_contact_length_cm=1;c%sorptivity_panels=64;c%mb_wall_node_index=1
  allocate(c%endpoint_depth_cm(1),c%endpoint_contact_thickness_cm(1),c%endpoint_area_fraction(1),c%endpoint_node_index(1))
  c%endpoint_depth_cm=10;c%endpoint_contact_thickness_cm=10;c%endpoint_area_fraction=1;c%endpoint_node_index=1
  if(.not.c%valid())error stop 'exact config invalid'
  if(c%sorptivity_panels_for_head(-20._real64)/=64)error stop 'exact changed'
  c%sorptivity_policy=RFM_SORPTIVITY_POLICY_PERF07_V1
  if(.not.c%valid())error stop 'approx config invalid'
  if(c%sorptivity_panels_for_head(-301._real64)/=64.or.c%sorptivity_panels_for_head(-300._real64)/=32.or. &
     c%sorptivity_panels_for_head(-100._real64)/=16.or.c%sorptivity_panels_for_head(-30._real64)/=8)error stop 'policy boundary'
  c%sorptivity_panels=32;if(c%valid())error stop 'approx ceiling accepted'
  c%sorptivity_panels=64;c%sorptivity_policy=99;if(c%valid())error stop 'unknown policy accepted'
  c%sorptivity_policy=RFM_SORPTIVITY_POLICY_PERF07_V1
 end subroutine
 subroutine init_cof(x,tr,ts,a,n,l,ksat)
  real(real64),intent(out)::x(:,:);real(real64),intent(in)::tr,ts,a,n,l,ksat;integer::q
  x=0._real64
  do q=1,size(x,2)
   x(1,q)=tr;x(2,q)=ts;x(3,q)=ksat;x(4,q)=a;x(5,q)=l;x(6,q)=n;x(7,q)=1._real64-1._real64/n
   x(8,q)=a;x(10,q)=ksat;x(11,q)=.999_real64;x(12,q)=.99_real64*ksat;x(22,q)=-1e6_real64;x(23,q)=1e-12_real64
  end do
 end subroutine
end program
