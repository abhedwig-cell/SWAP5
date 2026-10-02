program test_a27_perf07
 use,intrinsic::iso_fortran_env,only:real64
 use MOD_grid,only:numnod
 use mod_b110_default_mvg_provider,only:b110_default_mvg_parameters_t,b110_default_mvg_provider_t,initialize_b110_default_mvg_parameters,bind_b110_default_mvg_provider
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_rfm_surface_sorptivity,only:evaluate_rfm_node_sorptivity
 implicit none
 real(real64),parameter::hs(15)=[-500._real64,-400._real64,-350._real64,-300._real64,-250._real64,-200._real64,-150._real64,-100._real64,-75._real64,-50._real64,-30._real64,-20._real64,-10._real64,-3._real64,-1._real64]
 real(real64)::cof(24,numnod),h(numnod),t(numnod),k(numnod),c(numnod),d(numnod),s64,sa,rel,maxrel
 type(b110_default_mvg_parameters_t),target::hp
 type(b110_default_mvg_provider_t)::hyd
 type(process_hydraulic_view_t)::view
 integer::soil,i,p
 logical::ok
 maxrel=0._real64
 do soil=1,2
  call init_cof(cof,soil);call initialize_b110_default_mvg_parameters(hp,cof);call bind_b110_default_mvg_provider(hyd,hp,.01_real64)
  do i=1,size(hs)
   h=hs(i);call hyd%evaluate(h,t,k,c,d)
   view%active_nodes=numnod
   if(allocated(view%pressure_head))deallocate(view%pressure_head,view%water_content)
   allocate(view%pressure_head(numnod),view%water_content(numnod));view%pressure_head=h;view%water_content=t
   view%ponding_depth=0._real64;view%groundwater_level=-150._real64
   p=adaptive_panels(hs(i))
   call evaluate_rfm_node_sorptivity(view,hyd,1,64,s64,ok);if(.not.ok)error stop '64'
   call evaluate_rfm_node_sorptivity(view,hyd,1,p,sa,ok);if(.not.ok)error stop 'adaptive'
   rel=abs(sa-s64)/max(abs(s64),1e-10_real64);maxrel=max(maxrel,rel)
   write(*,'(*(g0,:,","))')'ADAPT',soil,hs(i),p,s64,sa,rel
  enddo
 enddo
 write(*,'(*(g0,:,","))')'MAXREL',maxrel
 if(maxrel>0.01_real64)error stop 'adaptive 1 percent gate'
 print '(a)','A27_PERF07_STAGE1=PASS'
contains
 integer function adaptive_panels(hh) result(p)
  real(real64),intent(in)::hh
  if(hh<(-300._real64))then;p=64
  else if(hh<(-100._real64))then;p=32
  else if(hh<(-30._real64))then;p=16
  else;p=8
  endif
 end function
 subroutine init_cof(x,soil)
  real(real64),intent(out)::x(:,:);integer,intent(in)::soil;real(real64)::tr,ts,ks,a,l,n;integer::q
  if(soil==1)then;tr=.02_real64;ts=.42749391_real64;ks=31.22501566_real64;a=.02165898_real64;l=.98087016_real64;n=1.73473668_real64
  else;tr=.01_real64;ts=.33670050_real64;ks=17.41850374_real64;a=.03030449_real64;l=.07360004_real64;n=2.88750186_real64;endif
  x=0._real64
  do q=1,size(x,2);x(1,q)=tr;x(2,q)=ts;x(3,q)=ks;x(4,q)=a;x(5,q)=l;x(6,q)=n;x(7,q)=1._real64-1._real64/n;x(8,q)=a;x(10,q)=ks;x(11,q)=.999_real64;x(12,q)=.99_real64*ks;x(22,q)=-1e6_real64;x(23,q)=1e-12_real64;enddo
 end subroutine
end program
