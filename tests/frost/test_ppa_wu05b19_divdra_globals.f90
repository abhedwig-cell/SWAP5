! Source-bound globals only: original FrozenBounds and DIVDRA bodies are unchanged.
module MOD_arrays
  integer,parameter::macp=4,madr=1
end module
module MOD_grid
  integer::numnod=4,layer(4)=1
  real(8)::z(4)=[-.25d0,-.75d0,-1.5d0,-2.5d0]
  real(8)::disnod(4)=[.25d0,.5d0,.75d0,1.d0],dz(4)=[.5d0,.5d0,1.d0,1.d0]
  real(8)::zbotcp(4)=[-.5d0,-1.d0,-2.d0,-3.d0]
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
  real(8)::zbotdr(1)=-3.d0,qdra(1,4)=0.d0,qdrain(1)=0.d0,qdrtot=0.d0
  real(8)::cofani(2)=1.d0,Lspacing(1)=20.d0,FacDpthInf=.5d0,drainl(1)=-.25d0
  real(8)::ztopdislay(1)=0.d0,ftopdislay(1)=0.d0,shape=1.d0,diffl(1)=0.d0
  interface
    module subroutine DIVDRA(ksatcp,gwlev)
      real(8),intent(in)::ksatcp(macp),gwlev
    end subroutine
  end interface
end module
module variables
  real(8)::qbot=0.d0,qbot_nonfrozen=0.d0,gwl=-3.d0
  real(8)::thetas(4)=.423d0,theta(4)=.423d0,ksatexm(2)=4.75d0,ksatfit(2)=4.75d0
  logical::fluseksatexm(4)=.false.
end module
subroutine swap_error(routine,message)
  character(*),intent(in)::routine,message
  print *,routine,message
  error stop 'original source geometry failure'
end subroutine
