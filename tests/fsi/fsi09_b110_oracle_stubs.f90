module MOD_arrays
  implicit none
  integer, parameter :: macp=4, maho=4, mcof=50, matabentries=16
end module MOD_arrays

module MOD_grid
  use MOD_arrays, only: maho
  implicit none
  integer, parameter :: numnod=4, numlay=4
  integer :: layer(numnod)=[1,2,3,4]
  integer :: nod1lay(maho)=[1,2,3,4]
end module MOD_grid

module DoublePrec
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  integer, parameter :: dp=real64
end module DoublePrec

module SHPvariables
  implicit none
  integer :: iLayer=1
end module SHPvariables

module MOD_RIA
  use DoublePrec, only: dp
  implicit none
contains
  real(dp) function WCRIA(h)
    real(dp),intent(in)::h
    WCRIA=0.30_dp+0.0_dp*h
  end function WCRIA
  real(dp) function RIAderivative(h)
    real(dp),intent(in)::h
    RIAderivative=0.0_dp+0.0_dp*h
  end function RIAderivative
  subroutine SingleKcomponents(h,t,k)
    real(dp),intent(in)::h,t
    real(dp),intent(out)::k
    k=1.0_dp+0.0_dp*(h+t)
  end subroutine SingleKcomponents
end module MOD_RIA

module MOD_swap_base
  implicit none
  integer :: swhyst=0, swfrost=0, swmacro=0
end module MOD_swap_base

module variables
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_grid, only: numnod, numlay
  implicit none
  integer :: indeks(numnod)=0
  real(real64) :: fhyst(numnod)=1.0_real64
  real(real64) :: dt=0.25_real64
  real(real64) :: ksatfit(numlay)=1.0_real64, thetsl(numlay)=0.45_real64
  logical :: fluseksatexm(numnod)=.false.
  real(real64) :: thetar(numnod)=0.05_real64, thetas(numnod)=0.45_real64
end module variables

module doln
  implicit none
  logical :: do_ln_trans=.false.
end module doln

module WC_K_models_04_11
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_arrays, only: maho,mcof,macp
  implicit none
contains
  real(real64) function functionvalue_04_11(task,node,models,cof,head,wc,temp)
    integer,intent(in)::task,node
    integer,intent(in)::models(maho)
    real(real64),intent(in)::cof(mcof,macp),head
    real(real64),intent(in),optional::wc,temp
    if(task<0 .or. node<1 .or. models(1)<0 .or. cof(1,1)<-huge(cof(1,1)) .or. head>huge(head)) error stop 'bad helper args'
    if(present(wc)) then
      if(wc<-huge(wc)) error stop 'bad wc'
    end if
    if(present(temp)) then
      if(temp<-huge(temp)) error stop 'bad temp'
    end if
    functionvalue_04_11=0.0_real64
  end function functionvalue_04_11
end module WC_K_models_04_11

module MOD_SoilTemperature
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_grid, only: numnod
  implicit none
  real(real64) :: tsoil(numnod)=10.0_real64
end module MOD_SoilTemperature

subroutine EvalTabulatedFunction(task,nentry,c1,c2,c3,node,table,index_table,x,y,z,mode)
  implicit none
  integer,intent(in)::task,nentry,c1,c2,c3,node,mode
  integer,intent(in)::index_table(*)
  real(8),intent(in)::table(*),x
  real(8),intent(out)::y,z
  if(task+nentry+c1+c2+c3+node+mode+index_table(1)<-huge(1)) error stop 'bad tabulated args'
  if(table(1)+x>huge(x)) error stop 'bad table args'
  y=0.0d0; z=0.0d0
end subroutine EvalTabulatedFunction

subroutine swap_error(origin,message)
  implicit none
  character(len=*),intent(in)::origin,message
  write(*,'(A,1X,A)') trim(origin),trim(message)
  error stop 'unexpected B1.10 oracle swap_error'
end subroutine swap_error
