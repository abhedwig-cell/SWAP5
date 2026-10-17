module parameters
 implicit none
 real(8),parameter::pi=3.1415926535897932384626433832795d0
end module
module MOD_swap_base
 implicit none
 integer::swmacro=0
end module
module MOD_swap_mp
 implicit none
 integer::numlevrapdra=0,swdrrap=0
 real(8)::zdrabas=0d0
end module
module variables
 implicit none
 real(8)::gwl=0d0,t1900=0d0,dt=0d0
end module
module MOD_drain
 implicit none
 integer::dramet=3,nrlevs=3,swnrsrf=0,swliminf=0,ipos=1
 integer::nowltab(3)=3,swdtyp(3)=1,swallo(3)=1
 real(8)::qdrtab(50)=0d0,zbotdr(3)=-100d0,lspacing(3)=1000d0,qdrain(3)=0d0,diffl(3)=0d0
 real(8)::owltab(3,6)=0d0,drainl(3)=0d0,drares(3)=100d0,infres(3)=200d0
 real(8)::shape=1d0,basegw=-200d0,khtop=1d0,entres=0d0,wetper=1d0,zintf=-100d0
 real(8)::khbot=1d0,kvtop=1d0,kvbot=1d0,geofac=1d0,cofintfl=1d0,expintfl=1d0
end module
subroutine swap_error(location,message)
 implicit none
 character(*),intent(in)::location,message
 print *,location,message
 error stop 'unexpected native source failure'
end subroutine
