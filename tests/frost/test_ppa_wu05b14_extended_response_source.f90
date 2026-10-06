program generated_extended_frost_reference
 use iso_fortran_env,only:real64,int64
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_fmr_drainage_response_binding
 use mod_drainage_extended_exchange,only:extended_drainage_parameters_t,EXT_DRAIN_OPEN_CHANNEL,valid_extended_drainage_parameters
 use mod_ppa_wu05b14_extended_fixture
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
 real(real64)::actual(1,4),t(4),proposal(2,4),final(2,4),heads(2),expected,q
 integer::air,depthcase,gwlcase,bsign,cases,configuration,resistancecase,headcase,pondcase,thermalcase
 real(real64),parameter::offsets(12)=[-200.d0,-2.d0,-1.d-10,0.d0,5.d-11,1.d-10,1.d-9,.5d0,1.d0,2.d0,1000.d0,1500.d0]
 real(real64),parameter::resistances(3)=[1.d0,200.d0,1.d5],headvalues(5)=[-5.d0,-3.d0,-1.d0,1000.d0,1001.d0]
 tfroststa=0.d0;tfrostend=-2.d0;hyd%active_nodes=4
 z=[-.5d0,-1.5d0,-2.5d0,-3.5d0];disnod=1.d0;dz=1.d0
 t=[-4.d0,-4.d0,1.d0,1.d0];swdra=1;swdivd=0;swmacro=0;cases=0
 allocate(hyd%pressure_head(4),hyd%water_content(4));hyd%pressure_head=-5.d0;hyd%water_content=.5d0
 do configuration=1,3,2
 do thermalcase=1,3
 t(4)=1.d0
 if(thermalcase==2)t(4)=-1.d0
 if(thermalcase==3)t(4)=-4.d0
 do resistancecase=1,3
 do air=1,2
  theta=.5d0;thetas=.5d0
  if(air==2)theta=.4d0
  do depthcase=1,6
   call FrozenCond(t,-4.d0)
   select case(depthcase)
   case(1);zbotdr=-3.d0
   case(2);zbotdr=-1.5d0
   case(3);zbotdr=-4.d0
   case(4);zbotdr=zfrostbot
   case(5);zbotdr=zfrostbot-1.d-10
   case(6);zbotdr=zfrostbot+1.d-10
   end select
   ! One actual level, zero-padded reference at the same physical depth.
   do headcase=1,6
   heads(2)=zbotdr(2)+.001d0
   if(headcase<=5)heads(2)=headvalues(headcase)
   do gwlcase=1,15
    if(gwlcase<=12)hyd%groundwater_level=heads(2)+offsets(gwlcase)
    if(gwlcase==13)hyd%groundwater_level=-.1d0
    if(gwlcase==14)hyd%groundwater_level=-.1d0-1.d-10
    if(gwlcase==15)hyd%groundwater_level=-.1d0+1.d-10
    do pondcase=1,2
     hyd%ponding_depth=real(pondcase-1,real64)*.2d0
     call setup_b14_levels(configuration,heads,zbotdr(2),params,controls)
     params(1)%extended%rdrain_day=resistances(resistancecase)
     params(1)%extended%rinfi_day=resistances(resistancecase)
     call require(valid_extended_drainage_parameters(params(1)%extended),'active PURE forwarding validation and inactive NaNs')
     call evaluate_fmr_drainage_response_bottom_lumped(params,controls,hyd,actual,diag)
     call require(diag%status==FMR_DRAIN_BIND_OK,'actual signed resolved-head generation')
     expected=independent_rate(params(1)%extended,hyd%groundwater_level,heads(2),hyd%ponding_depth)
     call require(abs(actual(1,4)-expected)<=1.d-12*max(1.d0,abs(expected)),'independent signed/capped/suppressed/control/ponding equation')
     call require(all(actual(:,:3)==0.d0),'single bottom-lumped nodal owner')
     proposal=0.d0;proposal(2,:)=actual(1,:)
     do bsign=-1,1
      q=real(bsign,real64)*.01d0;qbot_nonfrozen=q;qdra=proposal;qdrain=sum(qdra,dim=2)
      call FrozenBounds
      call compose_legacy_bracketed_frost_drainage(t,-4.d0,tfroststa,tfrostend,theta,thetas,dz,rfcp,z,disnod, &
           zbotdr,proposal,q,final,effect)
      call require(effect%available,'generated signed frost composition available')
      call require(effect%low_air_branch.eqv.(air==1),'actual branch parity')
      call require(all(transfer(final,[0_int64],8)==transfer(qdra,[0_int64],8)),'corrected B1 final nodes bit parity')
      call require(transfer(effect%final_bottom_flux,0_int64)==transfer(qbot,0_int64),'corrected B1 qbot bit parity')
      call require(all(effect%drainage%level_rate==qdrain).and.effect%drainage%total_rate==qdrtot,'one final nodal/reporting owner')
      if(air==1)then
       if(zfrostbot<minval(zbotdr))then
        call require(all(final==0.d0).and.effect%bottom_blocked.and.effect%final_bottom_flux==0.d0,'all-cut depth implication')
       else
        call require(.not.effect%bottom_blocked.and.effect%final_bottom_flux==q,'equality/surviving zero/signed rates retain qbot')
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
 end do
 call require(cases==116640,'complete actual signed binding and source matrix')
 print '(A,I0)','PPA_WU05B14_GENERATED_EXTENDED_SOURCE_CASES=',cases
 print '(A)','PPA_WU05B14_EXTENDED_RESPONSE_SOURCE=PASS'
contains
 pure real(real64) function independent_rate(p,g,wl,pond)result(rate)
  type(extended_drainage_parameters_t),intent(in)::p
  real(real64),intent(in)::g,wl,pond
  real(real64)::level,h,res,entry,wet,depth
  rate=0.d0
  if(wl>=p%pondmx_cm.and.g>=p%pondmx_cm)return
  if(g<=p%zbotdr_cm+.001d0.and.wl<=p%zbotdr_cm+.001d0)return
  level=p%zbotdr_cm
  if(wl>p%zbotdr_cm+.001d0)level=wl
  h=g-level
  if(g>-.1d0)h=h+pond
  if(h<0.d0.and.g<p%gwlinf_cm)h=p%gwlinf_cm-level
  res=p%rdrain_day;entry=p%rentry_day
  if(h<=0.d0)then
   res=p%rinfi_day;entry=p%rexit_day
  end if
  if(p%drain_type==EXT_DRAIN_OPEN_CHANNEL)then
   wet=p%width_cm
   if(wl>p%zbotdr_cm+.001d0)then
    depth=wl-p%zbotdr_cm
    wet=wet+2.d0*depth*sqrt(1.d0+1.d0/p%talud**2)
   end if
   res=res+entry*p%spacing_cm/wet
  end if
  rate=h/res
 end function
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then
   print *,label
   error stop 1
  end if
 end subroutine
end program

