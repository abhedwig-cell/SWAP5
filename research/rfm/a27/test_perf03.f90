program test_a27_perf03
 use,intrinsic::iso_fortran_env,only:real64,int64
 use MOD_grid,only:numnod,z
 use mod_b110_default_mvg_provider,only:b110_default_mvg_parameters_t,b110_default_mvg_provider_t,initialize_b110_default_mvg_parameters,bind_b110_default_mvg_provider
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_rfm_surface_sorptivity,only:evaluate_rfm_node_sorptivity
 implicit none
 real(real64),parameter::dts(5)=[.01_real64,.005_real64,.0025_real64,.00125_real64,.000625_real64]
 real(real64),parameter::wts(4)=[-300._real64,-150._real64,-100._real64,-20._real64]
 real(real64)::cof(24,numnod),h(numnod),theta(numnod),k(numnod),cap(numnod),dk(numnod),s(5),kn(5)
 type(b110_default_mvg_parameters_t),target::hp
 type(b110_default_mvg_provider_t)::hyd
 type(process_hydraulic_view_t)::view
 integer::soil,iw,id
 logical::ok,avail
 do soil=1,2
  call init_cof(cof,soil);call initialize_b110_default_mvg_parameters(hp,cof)
  do iw=1,4
   h=wts(iw)-z
   call bind_b110_default_mvg_provider(hyd,hp,dts(1));call hyd%evaluate(h,theta,k,cap,dk)
   view%active_nodes=numnod
   if(allocated(view%pressure_head))deallocate(view%pressure_head,view%water_content)
   allocate(view%pressure_head(numnod),view%water_content(numnod));view%pressure_head=h;view%water_content=theta
   view%ponding_depth=0._real64;view%groundwater_level=wts(iw)
   do id=1,5
    call bind_b110_default_mvg_provider(hyd,hp,dts(id))
    call evaluate_rfm_node_sorptivity(view,hyd,1,64,s(id),ok);if(.not.ok)error stop 'sorptivity'
    call hyd%evaluate_point_conductivity(1,h(1),theta(1),kn(id),avail);if(.not.avail)error stop 'K'
    write(*,'(*(g0,:,","))')'PERF03',soil,wts(iw),dts(id),s(id),kn(id)
   enddo
   write(*,'(*(g0,:,","))')'INVARIANCE',soil,wts(iw),merge(1,0,all(s==s(1))),maxval(abs(s-s(1))), &
        maxval(abs(s-s(1)))/max(abs(s(1)),tiny(1._real64)),merge(1,0,all(kn==kn(1))),maxval(abs(kn-kn(1)))
  enddo
 enddo
 print '(a)','A27_PERF03_EXECUTED=PASS'
contains
 subroutine init_cof(x,soil)
  real(real64),intent(out)::x(:,:);integer,intent(in)::soil
  real(real64)::tr,ts,ks,a,l,n;integer::j
  if(soil==1)then
   tr=.02_real64;ts=.42749391_real64;ks=31.22501566_real64;a=.02165898_real64;l=.98087016_real64;n=1.73473668_real64
  else
   tr=.01_real64;ts=.33670050_real64;ks=17.41850374_real64;a=.03030449_real64;l=.07360004_real64;n=2.88750186_real64
  endif
  x=0._real64
  do j=1,size(x,2)
   x(1,j)=tr;x(2,j)=ts;x(3,j)=ks;x(4,j)=a;x(5,j)=l;x(6,j)=n;x(7,j)=1._real64-1._real64/n;x(8,j)=a
   x(10,j)=ks;x(11,j)=.999_real64;x(12,j)=.99_real64*ks;x(22,j)=-1e6_real64;x(23,j)=1e-12_real64
  enddo
 end subroutine
end program
