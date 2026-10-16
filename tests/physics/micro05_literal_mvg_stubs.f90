module parameters
 real(8),parameter::pi=3.1415926535897932384626433832795d0
end module
module MOD_arrays
 integer,parameter::macp=4,maho=2,mcof=42,matabentries=2
end module
module MOD_grid
 integer,parameter::numnod=4,numlay=2
 integer::layer(4)=[1,1,2,2],nod1lay(2)=[1,3]
 real(8)::dz(4)=[10d0,10d0,10d0,10d0]
end module
module DoublePrec
 integer,parameter::dp=kind(1d0)
end module
module SHPvariables
 integer::iLayer=1
end module
module doln
 logical::do_ln_trans=.false.
end module
module MOD_swap_base
 integer::swfrost=0,swmacro=0,swhyst=0
 integer,parameter::unit_log=6,unit_err=6
 logical::fl_do_not_read_crpfile=.true.
end module
module MOD_SoilTemperature
 real(8)::tsoil(4)=20d0
end module
module variables
 real(8)::dt=1d0,ksatfit(2)=[4.75d0,5.25d0],thetsl(2),thetar(4),thetas(4),fhyst(4)
 real(8)::h(4),t1900=0d0
 character(10)::date='2000-01-01'
 integer::indeks(4)=[-1,-1,-1,-1]
 logical::fluseksatexm(4)=.false.
end module
module plant_interface
 integer::unit_crp=10,sw_oxygen=0
 character(80)::crpfilnam='unused'
end module
module MOD_re_global
 real(8)::hroot(4),mroot(4),mflux(4)
end module
module MOD_RIA
 use DoublePrec,only:dp
 contains
 real(dp) function WCRIA(h)
 real(dp)::h
 WCRIA=0d0
 end function
 real(dp) function RIAderivative(h)
 real(dp)::h
 RIAderivative=0d0
 end function
 real(dp) function RIAKDerivativeFromState(h,a,b,c,d)
 real(dp)::h,a,b,c,d
 RIAKDerivativeFromState=0d0
 end function
 logical function RIAStencilCrossesBoundary(h,d)
 real(dp)::h,d
 RIAStencilCrossesBoundary=.false.
 end function
 subroutine SingleKcomponents(h,t,k,a,b,c,d)
 real(dp)::h,t,k
 real(dp),optional::a,b,c,d
 k=0d0
 if(present(a))a=0d0
 if(present(b))b=0d0
 if(present(c))c=0d0
 if(present(d))d=0d0
 end subroutine
end module
module WC_K_models_04_11
 contains
 real(8) function functionvalue_04_11(kind,node,models,cofgen,head,wc,temp)
 integer::kind,node,models(:)
 real(8)::cofgen(:,:),head
 real(8),optional::wc,temp
 functionvalue_04_11=0d0
 end function
 real(8) function derivativevalue_04_11(node,models,cofgen,head,theta,temp,dimocap)
 integer::node,models(:)
 real(8)::cofgen(:,:),head,theta,temp,dimocap
 derivativevalue_04_11=0d0
 end function
 real(8) function NoVap(a,b)
 real(8)::a,b
 NoVap=0d0
 end function
end module
subroutine EvalTabulatedFunction(a,b,c,d,e,f,g,h,i,j,k,l)
 integer::a,b,c,d,e,f,h(:,:),l
 real(8)::g(:,:,:),i,j,k
 i=0d0;j=0d0
end subroutine
subroutine swap_error(where,message)
 character(*),intent(in)::where,message
 print *,where,message
 error stop 99
end subroutine
subroutine swap_warning(where,message)
 character(*),intent(in)::where,message
 print *,where,message
end subroutine
subroutine rdinit(unit_in,unit_err,name)
 integer,intent(in)::unit_in,unit_err
 character(*),intent(in)::name
 error stop 98
end subroutine
logical function rdinqr(name)
 character(*),intent(in)::name
 rdinqr=.false.
end function
subroutine rdsdor(name,lower,upper,value)
 character(*),intent(in)::name
 real(8),intent(in)::lower,upper
 real(8),intent(out)::value
 error stop 97
end subroutine
subroutine rdsinr(name,lower,upper,value)
 character(*),intent(in)::name
 integer,intent(in)::lower,upper
 integer,intent(out)::value
 error stop 96
end subroutine
