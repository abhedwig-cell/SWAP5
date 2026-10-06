program probe
  use MOD_arrays
  use MOD_grid
  use MOD_drain
  use MOD_frost
  use variables
  implicit none
  integer::id,ios,i,first_unfrozen
  real(8)::air,raw,spacing,aniso,k(8),before(8),before_level,initial_bottom
  do
    read(*,*,iostat=ios)id,swdivdinf,gwl,zfrostbot,air,raw,initial_bottom,spacing,aniso
    if(ios<0)exit
    if(ios/=0)error stop 'invalid case input'
    cofani=aniso;Lspacing=spacing
    rfcp=1.d0;nodfrostbot=0
    do i=1,numnod
      if(z(i)>=zfrostbot)then
        rfcp(i)=0.d0;nodfrostbot=i
      end if
    end do
    first_unfrozen=nodfrostbot+1
    rfcp(first_unfrozen)=.5d0
    theta=thetas
    theta(first_unfrozen:numnod)=.5d0-air/real(numnod-nodfrostbot,8)
    do i=1,numnod
      if(fluseksatexm(i))then
        k(i)=ksatexm(layer(i))
      else
        k(i)=ksatfit(layer(i))
      end if
    end do
    qdra=0.d0;qdrain=raw;qdrtot=raw;qbot=initial_bottom;qbot_nonfrozen=initial_bottom
    call DIVDRA(k,gwl)
    before=qdra(1,:);before_level=qdrain(1)
    call FrozenBounds
    write(*,'(I0,1X,19(ES26.17E3,1X))')id,before_level,before,qdrain(1),qdra(1,:),qbot
  end do
end program
