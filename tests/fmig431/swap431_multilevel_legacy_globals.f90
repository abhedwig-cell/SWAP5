module MOD_arrays
  integer,parameter::macp=8,madr=3
end module
module MOD_grid
  integer::numnod=8,layer(8)=[1,2,1,2,1,2,1,2]
  real(8)::z(8)=[-.5d0,-1.5d0,-2.5d0,-3.5d0,-4.5d0,-5.5d0,-6.5d0,-7.5d0]
  real(8)::disnod(8)=1.d0,dz(8)=1.d0
  real(8)::zbotcp(8)=[-1.d0,-2.d0,-3.d0,-4.d0,-5.d0,-6.d0,-7.d0,-8.d0]
end module
module MOD_drain
  use MOD_arrays
  integer::nrlevs=3,swdivd=1,swdivdinf=0,swnrsrf=0,swtopnrsrf=0,swdislay=0,swtopdislay(3)=0,dramet=1
  real(8)::zbotdr(3)=[-2.d0,-4.d0,-6.d0],qdra(3,8)=0.d0,qdrain(3)=0.d0,qdrtot=0.d0
  real(8)::cofani(2)=1.d0,Lspacing(3)=[30.d0,12.d0,5.d0],FacDpthInf=.5d0,drainl(3)=-1.d0
  real(8)::ztopdislay(3)=0.d0,ftopdislay(3)=0.d0,shape=1.d0,diffl(3)=0.d0
  interface
    module subroutine DIVDRA(ksatcp,gwlev)
      real(8),intent(in)::ksatcp(macp),gwlev
    end subroutine
  end interface
end module
subroutine swap_error(routine,message)
  character(*),intent(in)::routine,message
  error stop trim(routine)//':'//trim(message)
end subroutine
