program generated_low_air_reference
 use iso_fortran_env,only:real64,int64
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_fmr_drainage_response_binding
 use mod_ppa_wu05b12_analytic_fixture
 use MOD_frost,only:FrozenCond,FrozenBounds,tfroststa,tfrostend,rfcp,zfrostbot
 use MOD_grid
 use MOD_drain
 use MOD_swap_base
 use variables
 use mod_frost_low_air_drainage_effect
 implicit none
 type(process_hydraulic_view_t)::hyd
 type(fmr_drainage_response_level_parameters_t)::params(2)
 type(fmr_drainage_response_level_control_t)::controls(2)
 type(fmr_drainage_response_diagnostics_t)::diag
 type(frost_low_air_drainage_result_t)::effect
 real(real64)::t(4),proposal(2,4),final(2,4),expected,q,scale
 integer::air,depthcase,gwlcase,scalecase,bsign,l,cases,family,status
 real(real64)::depth
 real(real64),parameter::offsets(9)=[-2.d0,-1.d-10,0.d0,5.d-11,1.d-10,1.d-9,.5d0,1.d0,2.d0]
 tfroststa=0.d0;tfrostend=-2.d0;hyd%active_nodes=4
 z=[-.5d0,-1.5d0,-2.5d0,-3.5d0];disnod=1.d0;dz=1.d0
 t=[-4.d0,-4.d0,1.d0,1.d0];swdra=1;swdivd=0;swmacro=0;cases=0
 allocate(hyd%pressure_head(4),hyd%water_content(4))
 hyd%pressure_head=-5.d0;hyd%water_content=.5d0
 do family=1,5
 do air=1,2
  theta=.5d0;thetas=.5d0
  if(air==2)theta=.4d0
  do depthcase=1,4
   call FrozenCond(t,-4.d0)
   select case(depthcase)
   case(1);zbotdr=[-1.d0,-3.d0]
   case(2);zbotdr=[-1.d0,-1.5d0]
   case(3);zbotdr=[-3.d0,-4.d0]
   case(4);zbotdr=[zfrostbot,zfrostbot-1.d0]
   end select
   do gwlcase=1,9
    hyd%groundwater_level=zbotdr(1)+offsets(gwlcase)
    do scalecase=1,4
     scale=1.d0
     if(scalecase==1)scale=1.d-6
     if(scalecase==2)scale=1.d-4
     if(scalecase==4)scale=0.d0
     call setup_b12_analytic_level(params(1),family,zbotdr(1),status)
     call require(status==0,'actual analytic physical preparation')
     params(2)%variant=FMR_DRAIN_VARIANT_TABULATED
     params(2)%tabulated%groundwater_depth=[20.d0]
     params(2)%tabulated%signed_exchange_rate=[-.005d0*scale]
     call evaluate_fmr_drainage_response_bottom_lumped(params,controls,hyd,proposal,diag)
     call require(diag%status==FMR_DRAIN_BIND_OK,'actual immutable trial-start generation')
     expected=b12_analytic_rate_oracle(family,hyd%groundwater_level,zbotdr(1))
     call require(abs(proposal(1,4)-expected)<=1.d-14,'independent analytic equation/cutoff')
     call require(proposal(2,4)==-.005d0*scale.and.all(proposal(:,:3)==0.d0),'signed TAB and bottom-lumped owner')
     do bsign=-1,1
      q=real(bsign,real64)*.01d0;qbot_nonfrozen=q;qdra=proposal;qdrain=sum(qdra,dim=2)
      call FrozenBounds
      call compose_legacy_bracketed_frost_drainage(t,-4.d0,tfroststa,tfrostend,theta,thetas,dz,rfcp,z,disnod, &
           zbotdr,proposal,q,final,effect)
      call require(effect%available,'generated low-air composition available')
      call require(effect%low_air_branch.eqv.(air==1),'actual branch parity')
      call require(all(transfer(final,[0_int64],8)==transfer(qdra,[0_int64],8)),'corrected B1 final nodes bit parity')
      call require(transfer(effect%final_bottom_flux,0_int64)==transfer(qbot,0_int64),'corrected B1 qbot bit parity')
      call require(all(effect%drainage%level_rate==qdrain).and.effect%drainage%total_rate==qdrtot,'single final nodal owner')
      if(air==1)then
       if(zfrostbot<minval(zbotdr))then
        call require(all(final==0.d0).and.effect%bottom_blocked.and.effect%final_bottom_flux==0.d0,'all-cut depth implication')
       else
        call require(.not.effect%bottom_blocked.and.effect%final_bottom_flux==q,'tiny surviving rates retain qbot')
       end if
      end if
      cases=cases+1
     end do
    end do
   end do
  end do
 end do
 end do
 print '(A,I0)','PPA_WU05B12_GENERATED_LOW_AIR_SOURCE_CASES=',cases
 print '(A)','PPA_WU05B12_LOW_AIR_RESPONSE_SOURCE=PASS'
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
