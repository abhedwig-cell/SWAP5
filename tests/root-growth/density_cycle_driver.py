"""Actual Richards daily density and supply; retain predecessor assertions."""
from swrd2_cycle_driver import prepare as swrd2

def prepare(root,target,supply=False):
 swrd2(root,target,False,False);s=target.read_text()
 def replace(a,b):
  nonlocal s
  assert s.count(a)==1,(s.count(a),a)
  s=s.replace(a,b)
 replace('  implicit none\n','  use mod_crop_adaptive_root_profile_owner\n  implicit none\n')
 anchor="    call require(st==WOFOST_RATE_TABLE_OK,'existing cumulative root density table')"
 replace(anchor,anchor+'''
    tc%file_weather_adaptive_root_profile=.true.
    tc%file_weather_root_profile%initial_density=tc%file_weather_root_density
    tc%file_weather_root_profile%maximum_root_depth_cm=30._real64
    tc%file_weather_root_profile%ztop_cm=tc%tiles(1)%parameters%z+.5_real64*tc%tiles(1)%parameters%dz
    tc%file_weather_root_profile%zbot_cm=tc%tiles(1)%parameters%z-.5_real64*tc%tiles(1)%parameters%dz
    tc%file_weather_root_profile%dz_cm=tc%tiles(1)%parameters%dz
    tc%file_weather_root_profile%adaptation%growth_adaptation_fraction=.8_real64
    tc%file_weather_root_profile%adaptation%death_adaptation_fraction=.6_real64
    tc%file_weather_root_profile%adaptation%minimum_root_biomass_per_cm=.001_real64
    tc%file_weather_root_profile%adaptation%specific_root_length_m_per_kg=100._real64
'''+('''    tc%file_weather_swrd2_parameters%actual_extension_mode=CROP_ROOT_RATE_DROUGHT_SUPPLY
    tc%file_weather_swrd2_parameters%minimum_daily_extension_cm=1._real64
    tc%file_weather_swrd2_parameters%extent_critical_fraction=.5_real64
''' if supply else ''))
 replace('root_depth_parameters=tc%file_weather_swrd2_parameters)',
   'root_depth_parameters=tc%file_weather_swrd2_parameters,root_profile_configuration=tc%file_weather_root_profile)')
 replace('    type(crop_root_depth_rate_state_t)::depth_owner', '''    type(crop_root_depth_rate_state_t)::depth_owner
    type(adaptive_root_profile_state_t)::profile_owner
    integer::i''')
 replace("      call physical%snapshot_root_depth(depth_owner,ok);call require(ok,'oracle accepted persistent depth')", """      call physical%snapshot_root_depth(depth_owner,ok);call require(ok,'oracle accepted persistent depth')
      if(owner%crop_emerged)then
        call physical%snapshot_root_profile(profile_owner,ok);call require(ok,'oracle committed adaptive density')
      end if""")
 anchor='''    call materialize_static_root_profile(config%file_weather_root_density, &
      config%tiles(1)%parameters%z-config%tiles(1)%parameters%dz*.5_real64,30._real64,rd, &
      roots%rooted_nodes,roots%cumulative_root_fraction,s)
    call require(s==CROP_ROOT_PROFILE_OK.and.roots%rooted_nodes>0,'literal biomass AFGEN root geometry')'''
 replace(anchor,'''    roots%rooted_nodes=0
    do i=1,numnod
      if(config%file_weather_root_profile%zbot_cm(i)+rd<1e-8_real64)then
        roots%rooted_nodes=i;exit
      end if
    end do
    call require(roots%rooted_nodes>0,'literal adaptive rooted support')
    allocate(roots%cumulative_root_fraction(roots%rooted_nodes+1))
    roots%cumulative_root_fraction(1)=0._real64
    do i=1,roots%rooted_nodes
      roots%cumulative_root_fraction(i+1)=sum(profile_owner%root_biomass_by_node(:i))/ &
        sum(profile_owner%root_biomass_by_node(:roots%rooted_nodes))
    end do''')
 replace('    integer::depth_events,depth_suppressed,depth_extended','''    integer::depth_events,depth_suppressed,depth_extended
    real(real64)::literal_nodes(numnod),old_density_depth
    real(real64)::expected_pot(numnod),expected_red(numnod),day_pot(numnod),day_red(numnod)''')
 replace('subroutine oxygen_segment_oracle(app,crop,config,record,rate,unstressed)',
   'subroutine oxygen_segment_oracle(app,crop,config,record,rate,unstressed,layer_potential,layer_reduction)')
 replace('    real(real64),intent(out)::rate,unstressed','''    real(real64),intent(out)::rate,unstressed
    real(real64),intent(out)::layer_potential(numnod),layer_reduction(numnod)''')
 replace('    rate=0;unstressed=0','    rate=0;unstressed=0;layer_potential=0;layer_reduction=0')
 replace('    rate=sum(sink);unstressed=sum(neutral)', '''    rate=sum(sink);unstressed=sum(neutral)
    do i=1,roots%rooted_nodes
      layer_potential(i)=(roots%cumulative_root_fraction(i+1)-roots%cumulative_root_fraction(i))*er%potential_transpiration_cm_per_day
    end do
    layer_reduction=layer_potential-sink''')
 replace('          if(wet)call oxygen_segment_oracle(ta,cs,tc,wr,expected_rate,neutral_rate)', '''          if(wet)then
            call oxygen_segment_oracle(ta,cs,tc,wr,expected_rate,neutral_rate,expected_pot,expected_red)
            day_pot=day_pot+expected_pot/64._real64;day_red=day_red+expected_red/64._real64
          end if''')
 replace('        uptake=0.0_real64','        uptake=0.0_real64;day_pot=0._real64;day_red=0._real64')
 anchor="          if(d==2) call require(weight==10.0_real64.and.wo%development_stage==0.0_real64,'emergence initializes TDWI without previous-day phantom growth')"
 replace(anchor,anchor+'''
          if(d==2)then
            call literal_density_initial(crop_view,tc,literal_nodes)
          end if''')
 anchor='''            call literal_depth_receipt(crop_view,tc,literal_actual_depth,literal_potential_depth, &
              depth_events,depth_suppressed,depth_extended)'''
 assert s.count(anchor)==2
 s=s.replace(anchor,'''            old_density_depth=literal_actual_depth
            call literal_depth_receipt(crop_view,tc,literal_actual_depth,literal_potential_depth, &
              depth_events,depth_suppressed,depth_extended,literal_nodes)
            call literal_density_receipt(crop_view,tc,before_owner,old_density_depth,literal_nodes,day_pot,day_red)''')
 replace('subroutine literal_depth_receipt(v,c,rd,rdpot,events,blocked,extended)',
   'subroutine literal_depth_receipt(v,c,rd,rdpot,events,blocked,extended,nodes)')
 replace('    real(real64)::rr,old','    real(real64)::rr,old,needed\n    real(real64),intent(in)::nodes(:)\n    integer::deepest')
 anchor='''        old=rd;rd=rd+rr'''
 replace(anchor,'''        if(c%file_weather_swrd2_parameters%actual_extension_mode==CROP_ROOT_RATE_DROUGHT_SUPPLY)then
          deepest=literal_rooted(c,rd)
          rr=max(min(rr,1._real64),rr*min(1._real64,(1._real64-v%receipt%rootzone_drought_uptake_factor_integral)/.5_real64))
          needed=nodes(deepest)/(rd+c%file_weather_root_profile%ztop_cm(deepest))*rr
          if(needed>v%root_growth_carrier%actual_gross_root_growth)rr=rr*v%root_growth_carrier%actual_gross_root_growth/needed
        end if
'''+anchor)
 replace('      crop_bits=complete_wofost_owner_values(wo)', '''      call require(crop_view%root_profile_present,'joint continuation retains adaptive owner')
      call require(maxval(abs(crop_view%root_profile%root_biomass_by_node-literal_nodes))<1e-11_real64,'joint continuation retains literal density')
      crop_bits=complete_wofost_owner_values(wo)''')
 replace("  print '(a)','SWRD2_ACTUAL_RICHARDS_DEPTH_OXYGEN_JOINT_RESTART=PASS'",
   "  print '(a)','SWRD2_ACTUAL_RICHARDS_DEPTH_OXYGEN_JOINT_RESTART=PASS'\n  print '(a)','DAILY_DENSITY_ACTUAL_RICHARDS_SOURCE_RESTART=PASS'")
 helper='''
  integer function literal_rooted(c,rd)result(n)
    type(fmr_production_application_config_t),intent(in)::c
    real(real64),intent(in)::rd
    integer::i
    n=0
    do i=1,numnod
      if(c%file_weather_root_profile%zbot_cm(i)+rd<1e-8_real64)then
        n=i;return
      end if
    end do
  end function
  subroutine literal_density_initial(v,c,nodes)
    type(fmr_wofost_crop_transaction_persistence_t),intent(in)::v
    type(fmr_production_application_config_t),intent(in)::c
    real(real64),intent(out)::nodes(:)
    integer::n
    n=literal_rooted(c,10._real64);nodes=0._real64
    nodes(:n)=c%file_weather_root_profile%dz_cm(:n)/sum(c%file_weather_root_profile%dz_cm(:n))*v%owner%biomass%root_biomass
    call require(v%root_profile_present,'real emergence initializes adaptive density')
    call require(maxval(abs(nodes-v%root_profile%root_biomass_by_node))<1e-12_real64,'literal uniform RDCTB emergence')
  end subroutine
  subroutine literal_density_receipt(v,c,before,rdold,nodes,expected_pot,expected_red)
    type(fmr_wofost_crop_transaction_persistence_t),intent(in)::v
    type(fmr_production_application_config_t),intent(in)::c
    type(wofost_crop_owner_state_t),intent(in)::before
    real(real64),intent(in)::rdold
    real(real64),intent(in)::expected_pot(:),expected_red(:)
    real(real64),intent(inout)::nodes(:)
    real(real64)::g,death,newg,oldg,rr,actual,reduced,weight,frac,mass,minimum
    real(real64),allocatable::pot(:),red(:)
    integer::oldn,newn,i
    call require(v%root_profile_present,'accepted event has adaptive owner')
    call require(allocated(v%receipt%potential_root_sink_integral),'actual accepted layer receipt')
    pot=v%receipt%potential_root_sink_integral;red=v%receipt%root_sink_reduction_integral
    call require(maxval(abs(pot-expected_pot))<1e-12_real64,'accepted potential per layer equals independent literal sink')
    call require(maxval(abs(red-expected_red))<1e-12_real64,'accepted reduction per layer equals independent literal sink')
    call require(abs(sum(pot-red)-v%receipt%actual_root_uptake_integral)<1e-12_real64,'layer receipt matches actual water')
    oldn=literal_rooted(c,rdold);newn=literal_rooted(c,v%root_depth%actual_root_depth_cm)
    rr=v%root_depth%actual_root_depth_cm-rdold
    g=v%root_growth_carrier%actual_gross_root_growth
    death=before%biomass%root_biomass+g-v%owner%biomass%root_biomass
    newg=min(nodes(oldn)/(rdold+c%file_weather_root_profile%ztop_cm(oldn))*rr,g);oldg=g-newg
    actual=sum(pot(:newn)-max(0._real64,red(:newn)));reduced=sum(max(0._real64,red(:newn)))
    do i=1,oldn
      weight=nodes(i)/before%biomass%root_biomass
      if(actual>0._real64)weight=.2_real64*weight+.8_real64*max(0._real64,pot(i)-max(0._real64,red(i)))/actual
      if(g>0._real64)nodes(i)=nodes(i)+weight*oldg
      if(death>0._real64)then
        weight=nodes(i)/(before%biomass%root_biomass+oldg)
        if(reduced>0._real64)weight=.4_real64*weight+.6_real64*max(0._real64,red(i))/reduced
        minimum=min(c%file_weather_root_profile%dz_cm(i),rdold+c%file_weather_root_profile%ztop_cm(i))*.001_real64
        nodes(i)=max(minimum,nodes(i)-weight*death)
      end if
    end do
    if(rr>0._real64)then
      do i=oldn,newn
        frac=0._real64
        if(rdold+c%file_weather_root_profile%zbot_cm(i)<0._real64)frac= &
          (min(c%file_weather_root_profile%dz_cm(i),v%root_depth%actual_root_depth_cm+c%file_weather_root_profile%ztop_cm(i))- &
          max(0._real64,rdold+c%file_weather_root_profile%ztop_cm(i)))/rr
        nodes(i)=nodes(i)+frac*newg
      end do
    end if
    mass=sum(nodes(:newn));nodes=nodes/mass*v%owner%biomass%root_biomass
    call require(maxval(abs(nodes-v%root_profile%root_biomass_by_node))<1e-11_real64,'literal B111 adaptive shape and WRT finalization')
  end subroutine
'''
 replace('\ncontains\n','\ncontains\n'+helper)
 target.write_text(s);return target
