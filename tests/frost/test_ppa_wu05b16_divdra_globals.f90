! Source-bound globals only: original FrozenBounds and DIVDRA bodies are unchanged.
module MOD_arrays
  integer,parameter::macp=8,madr=1
end module
module MOD_grid
  integer::numnod=8,layer(8)=[1,2,1,2,1,2,1,2]
  real(8)::z(8)=[-.5d0,-1.5d0,-2.5d0,-3.5d0,-4.5d0,-5.5d0,-6.5d0,-7.5d0]
  real(8)::disnod(8)=1.d0,dz(8)=1.d0
  real(8)::zbotcp(8)=[-1.d0,-2.d0,-3.d0,-4.d0,-5.d0,-6.d0,-7.d0,-8.d0]
end module
module MOD_swap_base
  integer::swfrost=1,swdra=1,swmacro=0
end module
module MOD_MvG
  real(8),parameter::hconode_vsmall=1.d-10
end module
module MOD_drain
  use MOD_arrays
  integer::nrlevs=1,swdivd=1,swdivdinf=0,swnrsrf=0,swtopnrsrf=0,swdislay=0,swtopdislay(1)=0,dramet=1
  real(8)::zbotdr(1)=-3.d0,qdra(1,8)=0.d0,qdrain(1)=0.d0,qdrtot=0.d0
  real(8)::cofani(2)=1.d0,Lspacing(1)=20.d0,FacDpthInf=.5d0,drainl(1)=-1.d0
  real(8)::ztopdislay(1)=0.d0,ftopdislay(1)=0.d0,shape=1.d0,diffl(1)=0.d0
  interface
    module subroutine DIVDRA(ksatcp,gwlev)
      real(8),intent(in)::ksatcp(macp),gwlev
    end subroutine
  end interface
end module
module variables
  real(8)::qbot=0.d0,qbot_nonfrozen=0.d0,gwl=-3.d0
  real(8)::thetas(8)=.5d0,theta(8)=.5d0,ksatexm(2)=[1.d0,2.d0],ksatfit(2)=[3.d0,4.d0]
  logical::fluseksatexm(8)=[.true.,.false.,.true.,.false.,.true.,.false.,.true.,.false.]
end module
subroutine swap_error(routine,message)
  character(*),intent(in)::routine,message
  print *,routine,message
  error stop 'original source geometry failure'
end subroutine
