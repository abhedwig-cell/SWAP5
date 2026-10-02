program test_a27_perf06_panels
 use,intrinsic::iso_fortran_env,only:real64,int64
 use MOD_grid,only:numnod,z
 use mod_b110_default_mvg_provider,only:b110_default_mvg_parameters_t,b110_default_mvg_provider_t,initialize_b110_default_mvg_parameters,bind_b110_default_mvg_provider
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_rfm_surface_sorptivity,only:evaluate_rfm_node_sorptivity
 implicit none
 integer,parameter::panels(4)=[64,32,16,8],NREP=5000
 real(real64),parameter::heads(9)=[-10000._real64,-3000._real64,-1000._real64,-300._real64,-100._real64,-30._real64,-10._real64,-3._real64,-1._real64]
 real(real64)::cof(24,numnod),h(numnod),t(numnod),k(numnod),c(numnod),d(numnod),s(4),sec,sumv
 type(b110_default_mvg_parameters_t),target::hp
 type(b110_default_mvg_provider_t)::hyd
 type(process_hydraulic_view_t)::view
 integer::soil,ih,ip,j
 integer(int64)::c0,c1,rate
 logical::ok
 do soil=1,2
  call init_cof(cof,soil);call initialize_b110_default_mvg_parameters(hp,cof);call bind_b110_default_mvg_provider(hyd,hp,.01_real64)
  do ih=1,size(heads)
   h=heads(ih);call hyd%evaluate(h,t,k,c,d)
   view%active_nodes=numnod
   if(allocated(view%pressure_head))deallocate(view%pressure_head,view%water_content)
   allocate(view%pressure_head(numnod),view%water_content(numnod));view%pressure_head=h;view%water_content=t;view%ponding_depth=0._real64;view%groundwater_level=-150._real64
   do ip=1,4
    call evaluate_rfm_node_sorptivity(view,hyd,1,panels(ip),s(ip),ok);if(.not.ok)error stop 's'
   enddo
   do ip=1,4
    write(*,'(*(g0,:,","))')'S',soil,heads(ih),panels(ip),s(ip),abs(s(ip)-s(1)),abs(s(ip)-s(1))/max(abs(s(1)),1e-10_real64)
   enddo
  enddo
  do ip=1,4
   h=-100._real64;call hyd%evaluate(h,t,k,c,d);view%pressure_head=h;view%water_content=t
   sumv=0._real64;call system_clock(c0,rate)
   do j=1,NREP
    call evaluate_rfm_node_sorptivity(view,hyd,1,panels(ip),s(ip),ok);if(.not.ok)error stop 'time';sumv=sumv+s(ip)
   enddo
   call system_clock(c1);sec=real(c1-c0,real64)/real(rate,real64)
   write(*,'(*(g0,:,","))')'TIME',soil,panels(ip),NREP,sec,sumv
  enddo
 enddo
 print '(a)','A27_PERF06_STAGE1=PASS'
contains
 subroutine init_cof(x,soil)
  real(real64),intent(out)::x(:,:);integer,intent(in)::soil;real(real64)::tr,ts,ks,a,l,n;integer::q
  if(soil==1)then;tr=.02_real64;ts=.42749391_real64;ks=31.22501566_real64;a=.02165898_real64;l=.98087016_real64;n=1.73473668_real64
  else;tr=.01_real64;ts=.33670050_real64;ks=17.41850374_real64;a=.03030449_real64;l=.07360004_real64;n=2.88750186_real64;endif
  x=0._real64
  do q=1,size(x,2);x(1,q)=tr;x(2,q)=ts;x(3,q)=ks;x(4,q)=a;x(5,q)=l;x(6,q)=n;x(7,q)=1._real64-1._real64/n;x(8,q)=a;x(10,q)=ks;x(11,q)=.999_real64;x(12,q)=.99_real64*ks;x(22,q)=-1e6_real64;x(23,q)=1e-12_real64;enddo
 end subroutine
end program
