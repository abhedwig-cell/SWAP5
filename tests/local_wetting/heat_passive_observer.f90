! Allocation-free numerical conduction observation around an unchanged object.
! Missing physical energy carriers remain explicitly outside this observation.
recursive subroutine wrapped_temperature(task) bind(C,name='__wrap___mod_soiltemperature_MOD_soiltemperature')
 use iso_c_binding,only:c_int
 use mod_arrays,only:macp
 use mod_soiltemperature,only:tsoil,heacon,heacap,tetop,swtopbhea,swbotbhea
 use mod_grid,only:numnod,dz,disnod
 use mod_snow,only:ssnow
 use variables,only:t1900,dt
 use mod_swap_base,only:swcalt
 implicit none
 integer(c_int),intent(in)::task
 real(8)::old(macp),face(macp+1),residual(macp),cell,global
 integer::i
 integer,save::unit=0
 logical,save::configured=.false.,enabled=.false.
 character(len=8)::selection
 interface
  subroutine original_temperature(t) bind(C,name='__real___mod_soiltemperature_MOD_soiltemperature')
   import c_int
   integer(c_int),intent(in)::t
  end subroutine
 end interface
 if(.not.configured)then
  call get_environment_variable('SWAP5_HEAT_OBSERVE',selection)
  enabled=trim(selection)=='1';configured=.true.
 end if
 if(enabled.and.task==2.and.swcalt/=1)old(1:numnod)=tsoil(1:numnod)
 call original_temperature(task)
 if(.not.enabled.or.task/=2.or.swcalt==1)return
 if(swtopbhea/=1.or.swbotbhea/=1.or.abs(ssnow)>1d-10)error stop 'Unsupported heat audit profile'
 face(1)=dt*heacon(1)*(tetop-tsoil(1))/disnod(1)
 do i=2,numnod
  face(i)=dt*heacon(i)*(tsoil(i-1)-tsoil(i))/disnod(i)
 end do
 face(numnod+1)=0d0
 residual(1:numnod)=dz(1:numnod)*heacap(1:numnod)*(tsoil(1:numnod)-old(1:numnod)) &
                  -(face(1:numnod)-face(2:numnod+1))
 cell=maxval(abs(residual(1:numnod)))
 global=sum(dz(1:numnod)*heacap(1:numnod)*(tsoil(1:numnod)-old(1:numnod)))-(face(1)-face(numnod+1))
 if(unit==0)then
  open(newunit=unit,file='conduction.bin',status='new',access='stream',form='unformatted',action='write')
  write(unit)'S5HEAT01'
 endif
 write(unit)t1900,dt,numnod,cell,global
end subroutine
