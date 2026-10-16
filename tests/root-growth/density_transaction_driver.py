"""Extend the existing accepted-window crop driver with real adaptive ownership."""
def prepare(root,target):
 s=(root/'tests/root-growth/test_swrd2_transaction.f90').read_text()
 def replace(a,b):
  nonlocal s
  assert s.count(a)==1,(s.count(a),a)
  s=s.replace(a,b)
 replace('program test_swrd2_transaction','program test_daily_density_transaction')
 replace(' implicit none',' use mod_crop_adaptive_root_profile_owner\n use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan\n implicit none')
 replace(' type(crop_root_depth_rate_parameters_t)::rp',''' type(crop_root_depth_rate_parameters_t)::rp
 type(fmr_wofost_crop_event_identity_persistence_t)::layer_view
 type(fmr_wofost_crop_event_identity_t)::foreign_identity
 type(adaptive_root_profile_configuration_t)::density_config
 type(adaptive_root_profile_state_t)::density_owner
 real(real64)::literal_nodes(6),grnew,grold,rr,total''')
 replace(' call initialize_fmr_wofost_crop_transaction_state(seed,initial,status,enable_potential_shadow=.true.,root_depth_parameters=rp)', ''' density_config%ztop_cm=[0d0,-5d0,-10d0,-15d0,-20d0,-25d0]
 density_config%zbot_cm=density_config%ztop_cm-5d0
 density_config%dz_cm=spread(5d0,1,6)
 density_config%maximum_root_depth_cm=30d0
 density_config%adaptation%growth_adaptation_fraction=1d0
 density_config%adaptation%death_adaptation_fraction=0d0
 call make([0d0,1d0],[1d0,1d0],density_config%initial_density)
 if(profile==3)then
   rp%actual_extension_mode=CROP_ROOT_RATE_DROUGHT_SUPPLY
   rp%minimum_daily_extension_cm=0d0;rp%extent_critical_fraction=.5d0
 end if
 call initialize_fmr_wofost_crop_transaction_state(seed,initial,status,enable_potential_shadow=.true., &
   root_depth_parameters=rp,root_profile_configuration=density_config)''')
 # Keep every existing actual accepted-window test. Only the new driver adds
 # nodal receipts; profile4 remains the original missing-oxygen negative.
 for interval in ('100d0,100.25d0','100.25d0,101d0'):
  replace('call accumulate_wofost_trial_process_rate(trial,'+interval+',1d0,1d0,status,deepest_root_oxygen_factor=oxygen)',
   'call accumulate_wofost_trial_process_rate(trial,'+interval+''',1d0,1d0,status,deepest_root_oxygen_factor=oxygen, &
   rootzone_drought_uptake_factor=.5d0,potential_root_sink=[.6d0,.4d0,0d0,0d0,0d0,0d0], &
   root_sink_reduction=spread(0d0,1,6))''')
 replace('enable_anaerobic_root_growth_gate=enabled,aeration_critical_factor=.4d0,root_depth_parameters=rp)',
   'enable_anaerobic_root_growth_gate=enabled,aeration_critical_factor=.4d0,root_depth_parameters=rp, &\n root_profile_configuration=density_config)')
 anchor=' call require(abs(rnext%actual_root_depth_cm-expected)<1d-12,\'literal accepted water-scaled actual depth\')'
 replace(anchor,''' if(profile==3)expected=10d0+min(5d0,growth%actual_gross_root_growth/2d0)
'''+anchor)
 anchor=" call require(growth%potential_gross_root_growth>0d0.and.shadow%root_biomass()>20d0,'potential remains independent')"
 replace(anchor,anchor+'''
 call physical%snapshot_root_profile(density_owner,available);call require(available,'committed adaptive owner')
 ! Literal B1.11 update_wroot_node followed by finalize_wroot_node, independent
 ! arithmetic; the existing production helper is not used as its own oracle.
 rr=rnext%actual_root_depth_cm-10d0
 grnew=min(2d0*rr,growth%actual_gross_root_growth)
 grold=growth%actual_gross_root_growth-grnew
 literal_nodes=0d0
 literal_nodes(1)=10d0+.6d0*grold
 literal_nodes(2)=10d0+.4d0*grold
 literal_nodes(1:2)=literal_nodes(1:2)-literal_nodes(1:2)/(20d0+grold)*death
 if(rr>0d0)literal_nodes(3)=grnew
 total=sum(literal_nodes)
 literal_nodes=literal_nodes/total*actual%biomass%root_biomass
 call require(maxval(abs(literal_nodes-density_owner%root_biomass_by_node))<1d-11,'literal daily adaptive nodal postimage')
 call require(abs(sum(density_owner%root_biomass_by_node)-actual%biomass%root_biomass)<1d-11,'density projection conserves WRT')
 ''')
 anchor=" call open_wofost_accepted_window(water_checkpoint,101d0,window,status);call require(status==0,'window open')"
 replace(anchor," call layer_controls(water_checkpoint)\n"+anchor)
 anchor=" call identify_wofost_crop_event(token,identity,status);call require(status==0,'public event identity')"
 replace(anchor,anchor+'''
 if(profile/=4)then
   call export_wofost_crop_event_identity_persistence(identity,layer_view,available)
   call require(available,'layer identity exports')
   layer_view%potential_root_sink_integral(1:2)=layer_view%potential_root_sink_integral([2,1])
   call reconstruct_wofost_crop_event_identity_from_persistence(layer_view,foreign_identity,status)
   call require(status==0.and..not.same_wofost_crop_event_identity(identity,foreign_identity),'equal totals with foreign layer identity differ')
   deallocate(layer_view%root_sink_reduction_integral)
   call require(.not.layer_view%ready(),'incomplete layer persistence refuses')
   call reconstruct_wofost_crop_event_identity_from_persistence(layer_view,foreign_identity,status)
   call require(status/=0.and..not.foreign_identity%ready(),'incomplete layer identity restores nothing')
 end if
 ''')
 anchor=" call require(pv%root_depth_present.eqv.rv%root_depth_present,'restart depth presence')"
 replace(anchor,anchor+'''
 call require(pv%root_profile_present.and.rv%root_profile_present,'restart adaptive presence')
 call require(all(pv%root_profile%root_biomass_by_node==rv%root_profile%root_biomass_by_node),'restart nodal bits')
 pv%root_profile%root_biomass_by_node(1)=pv%root_profile%root_biomass_by_node(1)+1d0
 call require(.not.pv%ready(),'foreign density mass refused')
 call reconstruct_fmr_wofost_crop_transaction_from_persistence(pv,next,ok,status)
 call require(.not.ok.and..not.next%ready(),'foreign density restores nothing')
 pv=rv
 ''')
 replace("'PERSISTENT_SWRD2_TRANSACTION_RESTART_PROFILE_'","'DAILY_ADAPTIVE_DENSITY_SUPPLY_TRANSACTION_RESTART_PROFILE_'")
 anchor=" call evaluate_crop_root_depth_rate_candidate(rp,r0,rf,rnext,rdiag,status);call require(status==0,'SWRD2 accepted composition')"
 replace(anchor,''' if(profile==3)then
   rf%deepest_root_biomass_available=.true.;rf%deepest_root_biomass=10d0;rf%deepest_node_top_cm=-5d0
 end if
'''+anchor)
 replace('\ncontains\n','\ncontains\n'+'''
 subroutine layer_controls(checkpoint)
 type(kernel_checkpoint_t),intent(in)::checkpoint
 type(fmr_wofost_trial_contribution_t)::x
 type(adaptive_root_profile_state_t)::raw,final
 real(real64)::nan
 integer::code
 nan=ieee_value(0d0,ieee_quiet_nan)
 call begin_wofost_trial_contribution(checkpoint,101d0,x,code);call require(code==0,'layer trial begin')
 call accumulate_wofost_trial_process_rate(x,100d0,100.5d0,.8d0,1d0,code, &
   potential_root_sink=[.6d0,.4d0],root_sink_reduction=[0d0,0d0])
 call require(code/=0,'inconsistent layer uptake refuses')
 call accumulate_wofost_trial_process_rate(x,100d0,100.5d0,.8d0,1d0,code, &
   potential_root_sink=[nan,.4d0],root_sink_reduction=[.1d0,.1d0])
 call require(code/=0,'nonfinite potential layer refuses')
 call accumulate_wofost_trial_process_rate(x,100d0,100.5d0,1d0,1d0,code, &
   potential_root_sink=[.6d0,.4d0],root_sink_reduction=[-.1d0,.1d0])
 call require(code/=0,'compensated layer outside bounded envelope refuses')
 call accumulate_wofost_trial_process_rate(x,100d0,100.5d0,.8d0,1d0,code,potential_root_sink=[.6d0,.4d0])
 call require(code/=0,'unpaired layer arguments refuse')
 call accumulate_wofost_trial_process_rate(x,100d0,100.5d0,.8d0,1d0,code, &
   potential_root_sink=[.6d0,.4d0],root_sink_reduction=[.1d0,.1d0])
 call require(code==0,'valid layer after rejected prefix')
 call accumulate_wofost_trial_process_rate(x,100.5d0,101d0,.8d0,1d0,code)
 call require(code/=0.and..not.x%complete(),'omitted later layer does not advance')
 call accumulate_wofost_trial_process_rate(x,100.5d0,101d0,.8d0,1d0,code, &
   potential_root_sink=[.6d0,.4d0,0d0],root_sink_reduction=[.1d0,.1d0,0d0])
 call require(code/=0.and..not.x%complete(),'layer shape drift refuses')
 call accumulate_wofost_trial_process_rate(x,100.5d0,101d0,.8d0,1d0,code, &
   potential_root_sink=[.6d0,.4d0],root_sink_reduction=[.1d0,.1d0])
 call require(code==0.and.x%complete(),'valid layer retry keeps original integral')
 raw%root_biomass_by_node=[12d0,12d0]
 call finalize_adaptive_root_profile_candidate(raw,2,10d0,final,code)
 call require(code==0.and.all(final%root_biomass_by_node==5d0),'literal finalizer rescales floor-inflated raw shape')
 call require(all(raw%root_biomass_by_node==12d0),'finalizer leaves raw candidate intact')
 raw%root_biomass_by_node=0d0
 call finalize_adaptive_root_profile_candidate(raw,2,10d0,final,code)
 call require(code/=0,'zero raw shape refuses normalization')
 print '(A)','DAILY_DENSITY_LAYER_IDENTITY_NONFINITE_RETRY_FINALIZATION=PASS'
 end subroutine
 ''')
 target.write_text(s);return target
