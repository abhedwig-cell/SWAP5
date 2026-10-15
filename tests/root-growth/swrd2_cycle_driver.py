"""Real Richards/SWRD2 daily driver; retain original scientific assertions."""
from pathlib import Path
from swrd3_cycle_driver import prepare as swrd3

def prepare(root,target,gated=True,scaled=True):
 swrd3(root,target);s=target.read_text()
 def replace(a,b):
  nonlocal s
  assert s.count(a)==1,(s.count(a),a)
  s=s.replace(a,b)
 replace('  implicit none\n','  use mod_crop_root_depth_rate_owner\n  implicit none\n')
 replace('    tc%file_weather_root_depth_mode=3','''    tc%file_weather_root_depth_mode=2
    tc%file_weather_swrd2_parameters%initial_root_depth_cm=10._real64
    tc%file_weather_swrd2_parameters%maximum_root_depth_cm=30._real64
    tc%file_weather_swrd2_parameters%maximum_daily_extension_cm=5._real64
    tc%file_weather_swrd2_parameters%negligible_transpiration=1.e-10_real64
    tc%file_weather_swrd2_parameters%negligible_root_growth=1.e-10_real64
    tc%file_weather_swrd2_parameters%anaerobic_extension_gate_enabled='''+('.true.' if gated else '.false.')+'''
    tc%file_weather_swrd2_parameters%aeration_critical_factor=1._real64
    tc%file_weather_swrd2_parameters%actual_extension_mode='''+('CROP_ROOT_RATE_WATER_SCALED' if scaled else 'CROP_ROOT_RATE_UNSCALED'))
 replace("enable_potential_shadow=.true.,enable_anaerobic_root_growth_gate=.true.,aeration_critical_factor=.4_real64)",
   "enable_potential_shadow=.true.,enable_anaerobic_root_growth_gate=.true.,aeration_critical_factor=.4_real64, &\n        root_depth_parameters=tc%file_weather_swrd2_parameters)")
 replace('bad_tc=tc;bad_tc%file_weather_root_depth_mode=2','bad_tc=tc;bad_tc%file_weather_swrd2_parameters%negligible_transpiration=0._real64')
 replace('bad_tc=tc;bad_tc%file_weather_maximum_root_biomass=0._real64','bad_tc=tc;bad_tc%file_weather_swrd2_parameters%maximum_root_depth_cm=20._real64')
 replace('    real(real64)::potential_bits(2),expected_potential_bits(2)', '''    real(real64)::potential_bits(2),expected_potential_bits(2),literal_actual_depth,literal_potential_depth
    integer::depth_events,depth_suppressed,depth_extended''')
 replace('      maximum_residual=0;total_reduction=0;stress_cases=0','''      maximum_residual=0;total_reduction=0;stress_cases=0
      literal_actual_depth=10._real64;literal_potential_depth=10._real64
      depth_events=0;depth_suppressed=0;depth_extended=0''')
 # Use committed geometry for the independent historical sink, but check every
 # accepted depth update separately against literal source recurrence below.
 replace('    type(crop_root_uptake_input_t)::roots','    type(crop_root_uptake_input_t)::roots\n    type(crop_root_depth_rate_state_t)::depth_owner')
 replace("      call physical%snapshot_owner(owner,ok);call require(ok,'oracle accepted owner')", """      call physical%snapshot_owner(owner,ok);call require(ok,'oracle accepted owner')
      call physical%snapshot_root_depth(depth_owner,ok);call require(ok,'oracle accepted persistent depth')""")
 replace('    rd=min(30._real64,b111_co2_afgen([0._real64,0._real64,2._real64,20._real64,100._real64,30._real64],6,owner%biomass%root_biomass))','    rd=depth_owner%actual_root_depth_cm')
 # Both daily schedules expose the same receipt at these two existing sites.
 anchor="            call require(aggregates%deepest_root_oxygen_factor_available,'actual physical receipt carries deepest oxygen')"
 assert s.count(anchor)==2
 s=s.replace(anchor,anchor+'''
            call literal_depth_receipt(crop_view,tc,literal_actual_depth,literal_potential_depth, &
              depth_events,depth_suppressed,depth_extended)''')
 replace("      call ta%close(st);call require(st==FMR_APP_BOOT_OK,'close rooted physical application')", """      call require(depth_events>=4,'all accepted daily depth events checked')
      call require(literal_potential_depth==30._real64,'potential depth reaches RDM')
      if(tc%file_weather_swrd2_parameters%anaerobic_extension_gate_enabled)then
        call require(depth_suppressed>0,'actual accepted oxygen stops depth independently')
      else
        call require(depth_extended>0,'actual accepted roots extend in physical soil')
      end if
      call ta%close(st);call require(st==FMR_APP_BOOT_OK,'close rooted physical application')""")
 replace("  print '(a)','SWRD3_ACTUAL_RICHARDS_GROWTH_OXYGEN_JOINT_RESTART=PASS'", "  print '(a)','SWRD2_ACTUAL_RICHARDS_DEPTH_OXYGEN_JOINT_RESTART=PASS'")
 helper='''  subroutine literal_depth_receipt(v,c,rd,rdpot,events,blocked,extended)
    type(fmr_wofost_crop_transaction_persistence_t),intent(in)::v
    type(fmr_production_application_config_t),intent(in)::c
    real(real64),intent(inout)::rd,rdpot
    integer,intent(inout)::events,blocked,extended
    real(real64)::rr,old
    logical::allow
    call require(v%root_depth_present.and.v%root_growth_carrier%valid,'same atomic crop/depth receipt')
    if(v%receipt%potential_transpiration_integral>=1.e-10_real64)then
      if(v%root_growth_carrier%potential_gross_root_growth>=1.e-10_real64)rdpot=rdpot+min(30._real64-rdpot,5._real64)
      allow=v%root_growth_carrier%actual_gross_root_growth>=1.e-10_real64
      if(c%file_weather_swrd2_parameters%anaerobic_extension_gate_enabled)then
        if(v%receipt%deepest_root_oxygen_factor_integral<1._real64)then
          allow=.false.;blocked=blocked+1
        end if
      end if
      if(allow)then
        rr=min(30._real64-rd,5._real64)
        if(c%file_weather_swrd2_parameters%actual_extension_mode==CROP_ROOT_RATE_WATER_SCALED) &
          rr=rr*v%receipt%actual_root_uptake_integral/v%receipt%potential_transpiration_integral
        old=rd;rd=rd+rr
        if(rd>old)extended=extended+1
      end if
    end if
    call require(abs(v%root_depth%actual_root_depth_cm-rd)<1.e-12_real64,'literal source actual recurrence')
    call require(abs(v%root_depth%potential_root_depth_cm-rdpot)<1.e-12_real64,'literal source potential recurrence')
    events=events+1
  end subroutine
'''
 replace('\ncontains\n','\ncontains\n'+helper)
 target.write_text(s);return target
