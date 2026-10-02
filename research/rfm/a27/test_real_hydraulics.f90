program test_a27_real_hydraulics
 use,intrinsic::iso_fortran_env,only:real64,error_unit
 use mod_ppa_wu05a6_saturated_exchange_rate
 use mod_b110_default_mvg_provider
 implicit none
 type(b110_default_mvg_parameters_t),target::p
 type(b110_default_mvg_provider_t)::hyd
 real(real64)::c(24,1),h(1),theta(1),k(1),cap(1),dk(1),tp(1),tm(1),tmpk(1),tmpc(1),tmpdk(1)
 real(real64)::wcr,wcs,alpha,npar,lambda,ks,dt,eps,deriv,physical_d
 real(real64),parameter::heads(9)=[-2000._real64,-200._real64,-20._real64,-1._real64,-.1_real64,-.02_real64,0._real64,1._real64,5._real64]
 real(real64),parameter::steps(4)=[.1_real64,.01_real64,.001_real64,.0001_real64]
 integer::u,ios,year,unitid,i,j,count
 character(len=3)::code
 character(len=1024)::filename,header,mode
 type(saturated_exchange_request_t)::sq
 type(saturated_exchange_result_t)::sr
 real(real64),parameter::satheads(4)=[0._real64,1._real64,5._real64,9._real64]
 call get_command_argument(1,filename)
 call get_command_argument(2,mode)
 open(newunit=u,file=trim(filename),status='old',action='read');read(u,'(a)')header
 if(trim(mode)=='darcy')then
  print '(a)','code,dt_day,matrix_head_cm,theta,K_cm_day,actual_macro_to_matrix_rate_cm_day,analytic_rate_cm_day'
 else
 print '(a)','code,ks_catalog_cm_day,dt_day,head_cm,theta,K_cm_day,provider_C_cm_inv,retention_derivative_cm_inv,provider_K_over_C_cm2_day,physical_D_cm2_day,physical_D_defined'
 endif
 count=0
 do
  read(u,*,iostat=ios)year,unitid,code,wcr,wcs,alpha,npar,lambda,ks
  if(ios<0)exit
  if(ios/=0)error stop 'catalog parse'
  if(year/=2018)error stop 'catalog year'
  count=count+1;c=0
  c(1,1)=wcr;c(2,1)=wcs;c(3,1)=ks;c(4,1)=alpha;c(5,1)=lambda;c(6,1)=npar
  c(7,1)=1-1/npar;c(8,1)=alpha;c(10,1)=ks;c(11,1)=.999_real64;c(12,1)=.99_real64*ks
  c(22,1)=-1e6_real64;c(23,1)=1e-12_real64
  call initialize_b110_default_mvg_parameters(p,c)
  do j=1,4
   dt=steps(j);call bind_b110_default_mvg_provider(hyd,p,dt)
   if(trim(mode)=='darcy')then
    sq%num_domains=1;sq%num_nodes=1;sq%matrix_top_saturated_node=1;sq%matrix_bottom_saturated_node=1
    sq%matrix_partial_top_active=.false.;sq%step_duration=dt
    sq%bottom_domain=[1];sq%top_macro_saturated_node=[1];sq%macro_saturated_fraction=[1._real64]
    sq%macro_reference_level=[5._real64];sq%z=[0._real64];sq%dz=[1._real64]
    sq%ksat_horizontal=[ks];sq%diameter=[10._real64]
    if(allocated(sq%domain_fraction))deallocate(sq%domain_fraction,sq%cdarcy)
    allocate(sq%domain_fraction(1,1),sq%cdarcy(1,1));sq%domain_fraction=1;sq%cdarcy=ks/10
    do i=1,4
     h=satheads(i);call hyd%evaluate(h,theta,k,cap,dk);sq%matrix_head=h
     call evaluate_saturated_exchange(sq,sr);if(.not.sr%valid)error stop 'saturated exchange invalid'
     if(abs(sr%qexc_to_matrix_rate_cm_per_day(1,1)-ks*(5-h(1))/10)>1e-10_real64*max(1._real64,ks))error stop 'signed Darcy algebra'
     print '(a,6(",",es24.16))',code,dt,h(1),theta(1),k(1),sr%qexc_to_matrix_rate_cm_per_day(1,1),ks*(5-h(1))/10
    enddo
    cycle
   endif
   do i=1,9
    h=heads(i);call hyd%evaluate(h,theta,k,cap,dk)
    if(theta(1)<wcr.or.theta(1)>wcs.or.k(1)<0.or.k(1)>ks.or.cap(1)<=0)error stop 'constitutive bounds'
    if(h(1)<0)then
     eps=max(1e-7_real64,abs(h(1))*1e-5_real64)
     call hyd%evaluate(h+eps,tp,tmpk,tmpc,tmpdk)
     call hyd%evaluate(h-eps,tm,tmpk,tmpc,tmpdk)
     deriv=(tp(1)-tm(1))/(2*eps)
     if(deriv<=0)error stop 'unsaturated inverse absent at sample'
     physical_d=k(1)/deriv
    else
     deriv=0;physical_d=-1
     if(theta(1)/=wcs.or.k(1)/=ks)error stop 'saturated source plateau'
    endif
    print '(a,",",9(es24.16,","),i0)',code,ks,dt,h(1),theta(1),k(1),cap(1),deriv,k(1)/cap(1),physical_d,merge(1,0,deriv>0)
   enddo
  enddo
 enddo
 close(u);if(count/=36)error stop 'catalog count'
 write(error_unit,'(a)')'A27_REAL_SOURCE_BOUNDS_AND_PLATEAU=PASS'
end program
