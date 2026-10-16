"""Real daily SWRD3 integration, preserving the original science assertions."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'crop-cycle'))
from oxygen_cycle_driver import prepare as oxygen

def prepare(root,target,enabled=True):
 oxygen(root,target);s=target.read_text()
 def replace(a,b):
  nonlocal s
  assert s.count(a)==1,(s.count(a),a)
  s=s.replace(a,b)
 replace('  implicit none\n','''  use mod_wofost_potential_shadow_state,only:wofost_potential_shadow_state_t
  use mod_crop_root_profile_static,only:materialize_static_root_profile,CROP_ROOT_PROFILE_OK
  implicit none
''')
 replace('    tc%file_weather_maximum_root_depth_cm=30.0_real64','''    tc%file_weather_maximum_root_depth_cm=30.0_real64
    tc%file_weather_root_depth_mode=3
    tc%file_weather_maximum_root_biomass=100.0_real64''')
 replace("    call require(st==WOFOST_RATE_TABLE_OK,'existing DVS root depth parameter table')", """    call require(st==WOFOST_RATE_TABLE_OK,'existing DVS root depth parameter table')
    call construct_wofost_rate_table([0._real64,2._real64,100._real64], &
      [0._real64,20._real64,30._real64],tc%file_weather_root_depth,st)
    call require(st==WOFOST_RATE_TABLE_OK,'explicit source RLWTB for committed WRT')""")
 gate='.true.'if enabled else'.false.'
 replace('      call initialize_crop(cs,cp,cn,leaf_lifespan=40.0_real64);call ck%bind_model(cm)', '''      call initialize_crop(cs,cp,cn,leaf_lifespan=40.0_real64);call ck%bind_model(cm)
      call construct_fmr_wofost_crop_transaction_parameters(bundle,update,0._real64,0._real64,cp,st, &
        enable_potential_shadow=.true.,enable_anaerobic_root_growth_gate='''+gate+''',aeration_critical_factor=.4_real64)
      call require(st==FMR_WOF38_OK,'explicit actual/potential oxygen crop parameters')''')
 replace('    do j=1,2\n      maximum_residual', '''    bad_tc=tc;bad_tc%file_weather_root_depth_mode=2
    call bad_app%initialize(bad_tc,st)
    call require(st/=FMR_APP_BOOT_OK.and..not.bad_app%ready(),'uncomposed persistent SWRD2 refuses')
    bad_tc=tc;bad_tc%file_weather_maximum_root_biomass=0._real64
    call bad_app%initialize(bad_tc,st)
    call require(st/=FMR_APP_BOOT_OK.and..not.bad_app%ready(),'missing WRTMAX refuses')
    do j=1,2
      maximum_residual''')
 # Feed only the actual accepted receipt to the independent daily composition.
 a='aggregates%potential_transpiration=crop_view%receipt%potential_transpiration_integral'
 assert s.count(a)==2
 s=s.replace(a,a+'''\n            aggregates%deepest_root_oxygen_factor_available=crop_view%receipt%deepest_root_oxygen_factor_available
            aggregates%deepest_root_oxygen_factor_integral=crop_view%receipt%deepest_root_oxygen_factor_integral
            call require(aggregates%deepest_root_oxygen_factor_available,'actual physical receipt carries deepest oxygen')''')
 replace('call complete_wofost_one_day_crop_window(window,bundle,update,aggregates,expected,rates,end_diagnostics,st)', '''call complete_wofost_one_day_crop_window(window,bundle,update,aggregates,expected,rates,end_diagnostics,st, &
      suppress_actual_root_growth='''+gate+'''.and.aggregates%deepest_root_oxygen_factor_integral<.4_real64)''')
 # Independent literal AFGEN for the committed biomass, not the new adapter.
 a='''    call owner%derive_dvs_root_uptake_input(config%file_weather_root_depth,config%file_weather_root_density, &
      config%file_weather_maximum_root_depth_cm,config%tiles(1)%parameters%z-config%tiles(1)%parameters%dz*.5_real64,roots,ok,s)
    call require(ok.and.s==WOFOST_CROP_OWNER_OK,'oracle committed root geometry')'''
 b='''    rd=min(30._real64,b111_co2_afgen([0._real64,0._real64,2._real64,20._real64,100._real64,30._real64],6,owner%biomass%root_biomass))
    call materialize_static_root_profile(config%file_weather_root_density, &
      config%tiles(1)%parameters%z-config%tiles(1)%parameters%dz*.5_real64,30._real64,rd, &
      roots%rooted_nodes,roots%cumulative_root_fraction,s)
    call require(s==CROP_ROOT_PROFILE_OK.and.roots%rooted_nodes>0,'literal biomass AFGEN root geometry')'''
 replace(a,b)
 replace('real(real64)::day,tmn,tmx,rain,et,limits(8),sink(numnod),neutral(numnod)', 'real(real64)::day,tmn,tmx,rain,et,limits(8),sink(numnod),neutral(numnod),rd,b111_co2_afgen')
 # Assert source root death independently from the composed crop implementation.
 anchor='''    call require(st==WOFOST_CROP_WINDOW_OK.and.end_diagnostics%candidate_built,'existing same-day phase B accepted-uptake owner')'''
 replace(anchor,anchor+'''
    if('''+gate+'''.and.aggregates%deepest_root_oxygen_factor_integral<.4_real64)then
      call require(abs(expected%biomass%root_biomass-before%biomass%root_biomass*.99_real64)<1.e-12_real64, &
        'actual accepted oxygen suppresses GRRT while literal one-percent root death survives')
      print '(a)','SWRD3_ACTUAL_RICHARDS_ANAEROBIC_ROOT_DEATH=PASS'
    end if''')
 # The complete persisted potential owner must survive all joint restorations.
 replace('    real(real64),allocatable::crop_bits(:),expected_crop_bits(:)', '''    real(real64),allocatable::crop_bits(:),expected_crop_bits(:)
    real(real64)::potential_bits(2),expected_potential_bits(2)''')
 replace('      crop_bits=complete_wofost_owner_values(wo)', '''      call cs%snapshot(ps,ok);call require(ok,'final potential crop carrier')
      select type(ps)
      type is(fmr_wofost_crop_transaction_state_t)
        call export_fmr_wofost_crop_transaction_persistence(ps,crop_view,ok,st)
        call require(ok.and.crop_view%potential_shadow_present,'actual production potential shadow persists')
        potential_bits=[crop_view%potential_shadow%root_biomass(),crop_view%root_growth_carrier%potential_gross_root_growth]
        call require(potential_bits(1)>wo%biomass%root_biomass.and.potential_bits(2)>0._real64,'potential roots continue independently')
      class default
        call require(.false.,'potential physical type')
      end select
      if(j==1)then
        expected_potential_bits=potential_bits
      else
        call require(all(transfer(potential_bits,[0_int64],2)==transfer(expected_potential_bits,[0_int64],2)), &
          'joint restored potential biomass and growth exactly equal uninterrupted')
      end if
      crop_bits=complete_wofost_owner_values(wo)''')
 replace("  print '(a)','CROP_CYCLE_OXYGEN_PHYSICAL_LITERAL_RESTART=PASS'", "  print '(a)','CROP_CYCLE_OXYGEN_PHYSICAL_LITERAL_RESTART=PASS'\n  print '(a)','SWRD3_ACTUAL_RICHARDS_GROWTH_OXYGEN_JOINT_RESTART=PASS'")
 target.write_text(s);return target
