program test_rational_saturation_storage
 use iso_fortran_env,only:real64,real128
 use mod_b110_default_mvg_provider
 implicit none
 type(b110_default_mvg_parameters_t),target::p,legacy,elastic
 type(b110_default_mvg_provider_t)::provider
 real(real64)::cof(24,8),row(9),h(8),oldh(8),theta(8),oldtheta(8),k(8),cap(8),dk(8),delta(8),reverse(8),raw(8)
 real(real128)::reference,bound,qs,qa,qb,qa1,qb1,scale
 integer::u,i,j,m,cases,losses
 character(1024)::path
 call get_command_argument(1,path);open(newunit=u,file=trim(path),status='old')
 cof=0d0
 do i=1,8
  read(u,*)row
  cof(1,i)=row(1);cof(2,i)=row(2);cof(3,i)=row(6);cof(4,i)=row(3);cof(5,i)=row(5)
  cof(6,i)=row(4);cof(7,i)=1d0-1d0/row(4);cof(9,i)=row(8)
 end do
 close(u)
 call initialize_b110_default_mvg_parameters(p,cof);p%continuous_saturation_conductivity=.true.
 legacy=p;legacy%continuous_saturation_conductivity=.false.
 call initialize_b110_default_mvg_parameters(elastic,cof,enable_elastic_storage=.true.,specific_elastic_storage_input=spread(1d-4,1,8))
 elastic%continuous_saturation_conductivity=.true.;cases=0;losses=0
 do m=1,3
 do j=1,18
  h=-10d0**(-j);oldh=0d0
  if(m==2)oldh=.27754162041806962d0
  if(m==3)oldh=100d0
  call bind_b110_default_mvg_provider(provider,p,1d-9)
  call provider%evaluate(h,theta,k,cap,dk);call provider%evaluate(oldh,oldtheta,k,cap,dk)
  call provider%evaluate_water_content_increment(h,oldh,theta,oldtheta,delta)
  call provider%evaluate_water_content_increment(oldh,h,oldtheta,theta,reverse)
  if(any(delta>=0d0).or.any(reverse/=-delta))error stop 'sign or antisymmetry'
  raw=theta-oldtheta;losses=losses+count(raw==0d0)
  do i=1,8
   ! Independent higher-precision subtraction of literal retention values.
   ! The production implementation uses the factored difference instead.
   qs=real(p%cofgen(2,i),real128);qa=real(h(i),real128);qb=real(oldh(i),real128)
   qa1=qs;qb1=qs
   if(qa<0)qa1=qs+real(p%cofgen(42,i),real128)*qa/(1+real(p%cofgen(41,i),real128)*qa)
   if(qb<0)qb1=qs+real(p%cofgen(42,i),real128)*qb/(1+real(p%cofgen(41,i),real128)*qb)
   reference=qa1-qb1;bound=8*epsilon(qs)*abs(qs)+2e-14_real128*abs(reference)
   if(abs(real(delta(i),real128)-reference)>bound)error stop 'independent real128 reference'
   cases=cases+2
  end do
  call bind_b110_default_mvg_provider(provider,legacy,1d-9)
  call provider%evaluate_water_content_increment(h,oldh,theta,oldtheta,reverse)
  if(any(reverse/=raw))error stop 'default OFF changed'
  call bind_b110_default_mvg_provider(provider,elastic,1d-9)
  call provider%evaluate(h,theta,k,cap,dk);call provider%evaluate(oldh,oldtheta,k,cap,dk)
  call provider%evaluate_water_content_increment(h,oldh,theta,oldtheta,reverse)
  if(any(reverse/=theta-oldtheta))error stop 'elastic crossing changed'
 end do
 end do
 h=1d0;oldh=0d0;call bind_b110_default_mvg_provider(provider,p,1d-9)
 call provider%evaluate(h,theta,k,cap,dk);call provider%evaluate(oldh,oldtheta,k,cap,dk)
 call provider%evaluate_water_content_increment(h,oldh,theta,oldtheta,delta)
 if(any(delta/=0d0))error stop 'saturated zero'
 if(losses<1)error stop 'predecessor cancellation discriminator absent'
 print *, 'RATIONAL_SATURATION_REAL128_PASS',cases,losses
end program
