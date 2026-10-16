"""Extend the existing accepted-window crop driver with real adaptive ownership."""
def prepare(root,target):
 s=(root/'tests/root-growth/test_swrd2_transaction.f90').read_text()
 def replace(a,b):
  nonlocal s
  assert s.count(a)==1,(s.count(a),a)
  s=s.replace(a,b)
 replace('program test_swrd2_transaction','program test_daily_density_transaction')
 replace(' implicit none',' use mod_crop_adaptive_root_profile_owner\n implicit none')
 replace(' type(crop_root_depth_rate_parameters_t)::rp',''' type(crop_root_depth_rate_parameters_t)::rp
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
 target.write_text(s);return target
