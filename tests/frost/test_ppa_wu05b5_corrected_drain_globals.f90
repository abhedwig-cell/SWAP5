module MOD_arrays
  integer,parameter::macp=4,madr=2
end module
module MOD_grid
  integer::numnod=4,layer(4)=1
  real(8)::z(4)=[-.5d0,-1.5d0,-2.5d0,-3.5d0],disnod(4)=1.d0,dz(4)=1.d0
end module
module MOD_swap_base
  integer::swfrost=1,swdra=1,swmacro=0
end module
module MOD_MvG
  real(8),parameter::hconode_vsmall=1.d-10
end module
module MOD_drain
  integer::nrlevs=2,swdivd=0
  real(8)::zbotdr(2)=[-1.d0,-3.d0],qdra(2,4)=0.d0,qdrain(2)=0.d0,qdrtot=0.d0
contains
  subroutine divdra(k,gwl)
    real(8),intent(in)::k(4),gwl
    if(size(k)>0.or.gwl==gwl)error stop 'SWDIVD=1 outside corrected source probe'
  end subroutine
end module
module variables
  real(8)::qbot=0.d0,qbot_nonfrozen=-.01d0,gwl=-3.d0
  real(8)::thetas(4)=.5d0,theta(4)=.5d0,ksatexm(4)=1.d0,ksatfit(4)=1.d0
  logical::fluseksatexm(4)=.false.
end module
