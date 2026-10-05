program generated_empirical_frost_reference
 use iso_fortran_env,only:real64,int64
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_fmr_drainage_response_binding
 use mod_ppa_wu05b13_empirical_fixture
 use MOD_frost,only:FrozenCond,FrozenBounds,tfroststa,tfrostend,rfcp,zfrostbot
 use MOD_grid
 use MOD_drain
 use MOD_swap_base
 use variables
 use mod_frost_low_air_drainage_effect
 implicit none
 type(process_hydraulic_view_t)::hyd
 type(fmr_drainage_response_level_parameters_t),allocatable::params(:)
 type(fmr_drainage_response_level_control_t),allocatable::controls(:)
 type(fmr_drainage_response_diagnostics_t)::diag
 type(frost_low_air_drainage_result_t)::effect
 real(real64),allocatable::actual(:,:)
 real(real64)::t(4),proposal(2,4),final(2,4),heads(2),expected,q
 integer::air,depthcase,gwlcase,scalecase,bsign,cases,configuration,coefficientcase,headcase,n
 real(real64),parameter::offsets(9)=[-2.d0,-1.d-10,0.d0,5.d-11,1.d-10,1.d-9,.5d0,1.d0,2.d0]
 real(real64),parameter::coefficients(3)=[.01d0,1.d0,10.d0],headvalues(3)=[-5.d0,-3.d0,-1.d0]
 real(real64),parameter::linear_rates(4)=[-.005d0,0.d0,.005d0,.05d0]
 tfroststa=0.d0;tfrostend=-2.d0;hyd%active_nodes=4
 z=[-.5d0,-1.5d0,-2.5d0,-3.5d0];disnod=1.d0;dz=1.d0
 t=[-4.d0,-4.d0,1.d0,1.d0];swdra=1;swdivd=0;swmacro=0;cases=0
 allocate(hyd%pressure_head(4),hyd%water_content(4))
 hyd%pressure_head=-5.d0;hyd%water_content=.5d0
 do configuration=1,6
 n=b13_level_count(configuration)
 if(allocated(actual))deallocate(actual)
 allocate(actual(n,4))
 do coefficientcase=1,3
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
   ! The literal reference stub has two levels. A single actual level is
   ! padded by zero at the same physical depth, preserving every frost and
   ! bottom branch while testing the actual one-level binding separately.
   if(n==1)zbotdr(1)=zbotdr(2)
   do headcase=1,3
   do gwlcase=1,9
    heads(2)=headvalues(headcase);hyd%groundwater_level=heads(2)+offsets(gwlcase)
    do scalecase=1,4
     if(n==1.and.scalecase/=2)cycle
     heads(1)=hyd%groundwater_level-linear_rates(scalecase)*200.d0
     call setup_b13_levels(configuration,heads,params,controls)
     params(n)%empirical%coefficient=coefficients(coefficientcase)
     call evaluate_fmr_drainage_response_bottom_lumped(params,controls,hyd,actual,diag)
     call require(diag%status==FMR_DRAIN_BIND_OK,'actual immutable trial-start/control generation')
     expected=b13_empirical_rate_oracle(coefficients(coefficientcase),b13_exponent(configuration), &
          hyd%groundwater_level,heads(2))
     call require(abs(actual(n,4)-expected)<=1.d-14,'independent interflow power/activation equation')
     if(n==2)call require(abs(actual(1,4)-(hyd%groundwater_level-heads(1))/200.d0)<=1.d-14,'independent signed linear equation')
     call require(all(actual(:,:3)==0.d0),'single bottom-lumped nodal owner')
     proposal=0.d0;proposal(3-n:2,:)=actual
     do bsign=-1,1
      q=real(bsign,real64)*.01d0;qbot_nonfrozen=q;qdra=proposal;qdrain=sum(qdra,dim=2)
      call FrozenBounds
      call compose_legacy_bracketed_frost_drainage(t,-4.d0,tfroststa,tfrostend,theta,thetas,dz,rfcp,z,disnod, &
           zbotdr,proposal,q,final,effect)
      call require(effect%available,'generated empirical frost composition available')
      call require(effect%low_air_branch.eqv.(air==1),'actual branch parity')
      call require(all(transfer(final,[0_int64],8)==transfer(qdra,[0_int64],8)),'corrected B1 final nodes bit parity')
      call require(transfer(effect%final_bottom_flux,0_int64)==transfer(qbot,0_int64),'corrected B1 qbot bit parity')
      call require(all(effect%drainage%level_rate==qdrain).and.effect%drainage%total_rate==qdrtot,'one final nodal/reporting owner')
      if(air==1)then
       if(zfrostbot<minval(zbotdr))then
        call require(all(final==0.d0).and.effect%bottom_blocked.and.effect%final_bottom_flux==0.d0,'all-cut depth implication')
       else
        call require(.not.effect%bottom_blocked.and.effect%final_bottom_flux==q,'surviving zero/signed rates retain qbot')
       end if
      end if
      cases=cases+1
     end do
    end do
   end do
   end do
  end do
 end do
 end do
 end do
 call require(cases==29160,'complete declared actual binding and source matrix')
 print '(A,I0)','PPA_WU05B13_GENERATED_EMPIRICAL_SOURCE_CASES=',cases
 print '(A)','PPA_WU05B13_EMPIRICAL_RESPONSE_SOURCE=PASS'
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
