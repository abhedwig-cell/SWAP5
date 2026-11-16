program original_pond_schedule
  use MOD_top,only:pondRunoff,q0,k1max,h0max,hsurf
  use MOD_swap_base,only:swdra,swmacro,swpondmx
  use MOD_grid,only:disnod
  use variables,only:dt,t1900,h,pondm1,rsro,rsroexp,pondmxtab,pondmx,pond,runots
  implicit none
  real(8),parameter::clocks(5)=[37256d0,37256.25d0,37256.5d0,37257d0,37258d0]
  real(8),parameter::expected(5)=[.2d0,.35d0,.5d0,.8d0,.1d0]
  real(8)::receipt,top_into_soil
  integer::i
  swdra=1;swmacro=0;swpondmx=1
  pondmxtab=0d0
  pondmxtab(1:6)=[37256d0,.2d0,37257d0,.8d0,37258d0,.1d0]
  dt=.25d0;rsro=.5d0;rsroexp=1d0;disnod(1)=5d0;h(1)=-.4d0
  do i=1,5
    t1900=clocks(i)-dt
    pondm1=1.1d0;q0=2d0;k1max=.3d0;h0max=2d0;pond=2d0;pondmx=-999d0
    call PondRunoff()
    if(abs(pondmx-expected(i))>1d-12)error stop 'Original threshold interpolation failed'
    if(runots<=0d0.or.pond<pondmx.or.hsurf/=pond)error stop 'Original runoff regime not exercised'
    top_into_soil=k1max*((pond-h(1))/disnod(1)+1d0)
    receipt=pond-pondm1-dt*(q0-top_into_soil)+runots
    if(abs(receipt)>1d-12)error stop 'Independent scheduled pond balance failed'
    write(*,'(5ES26.17)')clocks(i),pondmx,pond,runots,receipt
  end do
end program
