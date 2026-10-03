program characterize_bartholomeus_perf03_waterfilm
 use iso_fortran_env,only:real64
 use mod_bartholomeus_waterfilm, only:BartholomeusWaterfilmMvgInput,bartholomeus_waterfilm_mvg_integrand
 implicit none
 type(BartholomeusWaterfilmMvgInput)::p
 real(real64),parameter::heads(7)=[-10._real64,-20._real64,-50._real64,-75._real64,-100._real64,-300._real64,-600._real64]
 real(real64)::mp,a,b,integral,previous,h,x,sum_new,rel
 integer::q,level,n_new,k,evals
 ! Same canonical C3A benchmark MVG construction, 293 K surface tension.
 p%capac_term=(.45_real64-.05_real64)*.01_real64*.01_real64*1.5_real64*(1._real64-1._real64/1.5_real64)
 p%n_minus_1=.5_real64;p%m_plus_1=1._real64+(1._real64-1._real64/1.5_real64)
 p%alpha_per_pa=.0001_real64;p%gen_n=1.5_real64;p%surface_tension_water=.072_real64
 a=1.e-10_real64
 do q=1,size(heads)
  mp=-heads(q)*100._real64;b=mp
  integral=.5_real64*(b-a)*(bartholomeus_waterfilm_mvg_integrand(a,p)+bartholomeus_waterfilm_mvg_integrand(b,p))
  evals=2;rel=huge(1._real64)
  do level=2,24
   previous=integral;n_new=2**(level-2);h=(b-a)/real(2*n_new,real64);sum_new=0
   do k=1,n_new
    x=a+h*real(2*k-1,real64);sum_new=sum_new+bartholomeus_waterfilm_mvg_integrand(x,p)
   enddo
   evals=evals+n_new;integral=.5_real64*previous+h*sum_new
   rel=abs(integral-previous)/max(abs(integral),tiny(1._real64))
   if(rel<=1.e-5_real64)exit
  enddo
  write(*,'(*(g0))')'PERF03_WF|H_CM=',heads(q),'|LEVEL=',level,'|EVALS=',evals,'|REL=',rel,'|INTEGRAL=',integral
 enddo
end program
