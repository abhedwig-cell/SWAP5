module MOD_grid
  implicit none
  integer, parameter :: numnod=50
  real(8), parameter :: z(numnod)=[ &
    (-0.5d0-dble(i-1),i=1,34), &
    (-35.0d0-2.0d0*dble(i-35),i=35,50) ]
  real(8), parameter :: dz(numnod)=[(1.0d0,i=1,34),(2.0d0,i=35,50)]
  real(8), parameter :: disnod(numnod+1)=[0.5d0,(1.0d0,i=2,34),1.5d0,(2.0d0,i=36,50),1.0d0]
end module MOD_grid

module variables
  implicit none
  real(8) :: qrot(50)=0.0d0
  real(8) :: qdra(1,50)=0.0d0
  real(8) :: qssdi(50)=0.0d0
  real(8) :: qtop=0.0d0
  real(8) :: qbot=0.0d0
  real(8) :: pond=0.0d0
  real(8) :: gwl=-59.98714271d0
  real(8) :: h(50)=0.0d0
  real(8) :: theta(50)=0.0d0
end module variables
