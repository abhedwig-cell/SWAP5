! Bounded SI wrapper of literal B1.11 Fred_T and Fred_W; no persistent state.
module mod_b111_soil_n_organic_rate_environment
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 implicit none
 private
 public::b111_organic_environment_factor
contains
 pure subroutine b111_organic_environment_factor(temp,temp_ref,w0,w1,saturation,critical,factor,status)
   real(real64),intent(in)::temp,temp_ref,w0,w1,saturation,critical
   real(real64),intent(out)::factor
   integer,intent(out)::status
   real(real64)::r1,r2,w,fw,den,a2,a1,a0
   real(real64),parameter::rec=.01d0
   factor=0d0;status=1
   if(.not.all(ieee_is_finite([temp,temp_ref,w0,w1,saturation,critical])))return
   if(min(temp,temp_ref)<-20d0.or.max(temp,temp_ref)>60d0)return
   if(saturation<.01d0.or.saturation>1d0.or.min(w0,w1)<1d-4.or.max(w0,w1)>saturation)return
   if(critical<.05d0.or.critical>.95d0)return
   r1=1d0/(1d0+exp(-.26d0*(temp-17d0)))-1d0/(1d0+exp(-.77d0*(temp-41.9d0)))
   r2=1d0/(1d0+exp(-.26d0*(temp_ref-17d0)))-1d0/(1d0+exp(-.77d0*(temp_ref-41.9d0)))
   if(abs(r2)<=tiny(1d0))return
   w=.5d0*(w0+w1)/saturation
   if(w<=critical)then
     fw=6d0*w**2/(1d0+9d0*w**4)
   else
     den=81d0*critical**10-162d0*critical**9+81d0*critical**8+18d0*critical**6-36d0*critical**5+ &
         18d0*critical**4+critical**2-2d0*critical+1d0
     if(abs(den)<=tiny(1d0))return
     a2=((18d0*critical**4+81d0*critical**8+1d0)*rec-162d0*critical**6+108d0*critical**5+ &
         6d0*critical**2-12d0*critical)/den
     a1=-2d0*critical*(81d0*critical**8*rec-108d0*critical**6+54d0*critical**4+ &
         18d0*critical**4*rec+rec-6d0)/den
     a0=critical**2*(81d0*critical**8*rec-216d0*critical**5+162d0*critical**4+18d0*critical**4*rec+rec-6d0)/den
     fw=a2*w**2+a1*w+a0
   end if
   factor=r1/r2*fw
   if(.not.ieee_is_finite(factor))return
   if(factor<0d0)return
   status=0
 end subroutine
end module
