module hybrid_groundwater_native_state
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod,dz
  use MOD_swap_base, only: swmacro,swsolu,swhyst,swsnow,swfrost
  use variables, only: swbotb,h,theta,k,kmean,dimoca,gwl,volact
  implicit none
  private
  public :: groundwater_native_checkpoint
contains
  subroutine groundwater_native_checkpoint(unit,restoring)
    integer,intent(in)::unit
    logical,intent(in)::restoring
    integer::expected(9),header(9),witness(9),ios,n
    real(8),allocatable::heads(:),water(:),conductivity(:),interfaces(:),capacity(:)
    real(8)::level,volume
    n=numnod
    if(n<5.or.swmacro/=0.or.swsolu/=1.or.swbotb/=1.or.swhyst/=0.or.swsnow/=0.or.swfrost/=0) &
      error stop 'Invalid prescribed groundwater native domain'
    expected=[1,n,swmacro,swsolu,swbotb,swhyst,swsnow,swfrost,1]
    if(restoring)then
      read(unit,iostat=ios)header,witness
      if(ios/=0)error stop 'Incomplete prescribed groundwater native domain'
      if(any(header/=expected).or.any(witness/=expected))error stop 'Foreign prescribed groundwater native domain'
      allocate(heads(n),water(n),conductivity(n+1),interfaces(n+1),capacity(n))
      read(unit,iostat=ios)heads,water,conductivity,interfaces,capacity,level,volume
      if(ios/=0)error stop 'Incomplete prescribed groundwater hydraulic carry'
      if(.not.all(ieee_is_finite([heads,water,conductivity,interfaces,capacity,level,volume]))) &
        error stop 'Nonfinite prescribed groundwater hydraulic carry'
      if(any(water<0d0).or.any(conductivity<0d0).or.any(interfaces<0d0).or.any(capacity<0d0).or.volume<0d0) &
        error stop 'Invalid prescribed groundwater hydraulic carry'
      if(abs(sum(water*dz(1:n))-volume)>1d-10)error stop 'Unbalanced prescribed groundwater hydraulic carry'
      h(1:n)=heads;theta(1:n)=water;k(1:n+1)=conductivity;kmean(1:n+1)=interfaces
      dimoca(1:n)=capacity;gwl=level;volact=volume
    else
      write(unit)expected,expected
      write(unit)h(1:n),theta(1:n),k(1:n+1),kmean(1:n+1),dimoca(1:n),gwl,volact
    end if
  end subroutine
end module
