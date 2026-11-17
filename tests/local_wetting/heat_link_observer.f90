! Observe a complete original heat call without recompiling its numerical unit.
! GNU --wrap changes only the external call destination; original temperature.o
! remains byte-identical. All model imports are read-only in this observer.
subroutine wrapped_temperature(task) bind(C,name='__wrap___mod_soiltemperature_MOD_soiltemperature')
 use iso_c_binding,only:c_int
 use mod_soiltemperature,only:tsoil,heacon,heacap,tetop,fquartz,fclay,forg,swtopbhea,swbotbhea
 use mod_grid,only:numnod,dz,disnod,layer
 use mod_snow,only:ssnow
 use variables,only:theta,thetm1,thetas,t1900,dt
 use mod_swap_base,only:swcalt
 use mod_hybrid_heat_accounting,only:observe_original_heat
 implicit none
 integer(c_int),intent(in)::task
 real(8)::old(numnod),face(numnod+1),solid(numnod)
 integer::i
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
 if(enabled.and.task==2.and.swcalt/=1)old=tsoil(1:numnod)
 call original_temperature(task)
 if(.not.enabled.or.task/=2.or.swcalt==1)return
 if(swtopbhea/=1.or.swbotbhea/=1.or.abs(ssnow)>1d-10)error stop 'Unsupported heat audit profile'
 face(1)=dt*heacon(1)*(tetop-tsoil(1))/disnod(1)
 do i=2,numnod
  face(i)=dt*heacon(i)*(tsoil(i-1)-tsoil(i))/disnod(i)
 end do
 face(numnod+1)=0d0
 solid=(fquartz(layer(1:numnod))*(2660d0*800d0)+ &
        fclay(layer(1:numnod))*(2650d0*900d0)+forg(layer(1:numnod))*(1300d0*1920d0))*1d-6
 call observe_original_heat(numnod,t1900,dt,dz(1:numnod),thetas(1:numnod), &
      thetm1(1:numnod),theta(1:numnod),old,tsoil(1:numnod),heacap(1:numnod),solid,face,detailed=.false.)
end subroutine
