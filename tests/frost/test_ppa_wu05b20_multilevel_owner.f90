program multilevel_owner
  use MOD_arrays
  use MOD_grid
  use MOD_drain
  use MOD_frost
  use variables
  implicit none
  integer :: id,ios,i,first_unfrozen,level
  real(8) :: air,raw(3),aniso,k(8),before(3,8),initial_bottom
  do
    read(*,*,iostat=ios) id,nrlevs,swdivdinf,gwl,zfrostbot,air,initial_bottom,raw,Lspacing,aniso
    if(ios<0)exit
    if(ios/=0)error stop 'invalid case input'
    if(nrlevs<1.or.nrlevs>3)error stop 'invalid level count'
    cofani=aniso;rfcp=1.d0;nodfrostbot=0
    do i=1,numnod
      if(z(i)>=zfrostbot)then
        rfcp(i)=0.d0;nodfrostbot=i
      end if
    end do
    first_unfrozen=nodfrostbot+1
    if(first_unfrozen>numnod)error stop 'unbracketed bottom'
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
    qdra=0.d0;qdrain=raw;qdrtot=sum(raw(:nrlevs))
    qbot=initial_bottom;qbot_nonfrozen=initial_bottom
    call DIVDRA(k,gwl)
    before=qdra
    call FrozenBounds
    write(*,'(I0,1X,52(ES26.17E3,1X))') id, &
      ((before(level,i),i=1,8),level=1,3),qdrain, &
      ((qdra(level,i),i=1,8),level=1,3),qbot
    flush(6)
  end do
end program
