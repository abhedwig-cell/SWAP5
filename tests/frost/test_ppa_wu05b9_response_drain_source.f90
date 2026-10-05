program response_frost_source
 use iso_fortran_env,only:real64,int64
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_drainage_process
 use mod_frost_drainage_effect
 use MOD_frost,only:FrozenBounds,rfcp,nodfrostbot
 use MOD_grid,only:dz
 use MOD_drain
 use MOD_swap_base
 use variables
 implicit none
 type(process_hydraulic_view_t)::hyd
 type(drainage_linear_parameters_t)::params
 type(drainage_control_t)::control
 type(drainage_transfer_t)::generated_transfer
 type(drainage_diagnostics_t)::diag
 type(frost_drainage_result_t)::effect
 real(real64)::proposal(2,4),final(2,4),temperature(4),factor(4),expected,q
 integer::regime,gwlcase,bottomsign,l,cases
 cases=0;hyd%active_nodes=4;swdra=1;swdivd=0;swmacro=0
 theta=.4d0;thetas=.5d0
 do regime=1,3
  temperature=1.d0;factor=1.d0;nodfrostbot=-1
  if(regime==2)then
   temperature=-1.d0;factor=.5d0
  else if(regime==3)then
   temperature=-4.d0;factor=0.d0;nodfrostbot=3
  end if
  do gwlcase=1,3
   hyd%groundwater_level=-real(gwlcase,real64)*10.d0
   proposal=0.d0
   do l=1,2
    params%drainage_resistance=real(l,real64)*100.d0
    control%drain_head=-real(l+1,real64)*10.d0
    expected=max(0.d0,hyd%groundwater_level-control%drain_head)/params%drainage_resistance
    call evaluate_single_level_linear_drainage(params,hyd,control,generated_transfer,diag)
    call require(diag%status==DRAINAGE_OK,'admitted linear generator available')
    call require(generated_transfer%soil_to_drain_rate==expected,'independent linear activation formula')
    proposal(l,4)=generated_transfer%soil_to_drain_rate
   end do
   do bottomsign=-1,1
    q=real(bottomsign,real64)*.01d0;qdra=proposal;qdrain=sum(qdra,dim=2)
    rfcp=factor;qbot_nonfrozen=q
    call FrozenBounds
    call compose_legacy_normal_frost_drainage(.true.,temperature,-2.d0,theta,thetas,dz,factor,proposal,final,effect)
    call require(effect%available,'normal composition available')
    call require(all(transfer(final,[0_int64],8)==transfer(qdra,[0_int64],8)),'actual corrected B1 nodal bit parity')
    call require(all(effect%level_rate==qdrain).and.effect%total_rate==qdrtot,'actual source reports follow final nodes')
    call require(qbot==q,'separate bottom owner retained')
    cases=cases+1
   end do
  end do
 end do
 theta=.5d0;temperature=-4.d0;factor=0.d0
 call compose_legacy_normal_frost_drainage(.true.,temperature,-2.d0,theta,thetas,dz,factor,proposal,final,effect)
 call require(.not.effect%available.and.effect%status==FROST_DRAIN_LOW_AIR_UNQUALIFIED,'low air composition unavailable')
 call require(all(final==proposal),'unavailable composition preserves generated proposal')
 print '(A,I0)','PPA_WU05B9_GENERATION_FROST_SOURCE_CASES=',cases
 print '(A)','PPA_WU05B9_RESPONSE_DRAIN_SOURCE=PASS'
contains
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then
   print *,label
   error stop 1
  end if
 end subroutine
end program
