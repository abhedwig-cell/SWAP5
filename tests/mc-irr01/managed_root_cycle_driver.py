"""Compose managed delivery with the actual qualified daily adaptive-root driver."""
import sys
from pathlib import Path

def prepare(root,target,criterion=7,nodes=1):
 sys.path[:0]=[str(root/'tests/root-growth'),str(root/'tests/crop-cycle'),str(root/'tests/crop-co2')]
 from density_cycle_driver import prepare as density
 density(root,target,True);s=target.read_text()
 def replace(a,b):
  nonlocal s
  assert s.count(a)==1,(s.count(a),a)
  s=s.replace(a,b)
 replace('  implicit none\n','  use mod_fmr_irrigation_allocation_binding\n  use, intrinsic :: ieee_arithmetic\n  implicit none\n')
 replace('    type(fmr_production_application_config_t)::tc,bad_tc','''    type(fmr_production_application_config_t)::tc,bad_tc
    type(fmr_irrigation_allocation_t)::allocation
    type(fmr_allocated_irrigation_state_t)::irrigation
    integer::selected_day
    real(real64)::delivered_amount''')
 anchor='    tc%tiles(1)%parameters%root_extraction_active=.true.'
 replace(anchor,f'''    call configure_managed_sensor(tc,{criterion},{nodes})
    ! Separate new compound-weather envelope:0.04cm capped gift per node,
    ! provider0.5 after cap; zero configured rate retains literal one-day rule.
    tc%file_weather_irrigation_depth%maximum_depth_cm=.04_real64
    tc%file_weather_irrigation_sensor%irr_rate_cm_per_day=0._real64
    tc%tiles(1)%base_forcing%drainage_flux_by_level=0._real64
    tc%tiles(1)%base_forcing%subsurface_irrigation_source=0._real64
'''+anchor)
 anchor='      do d=0,6'
 replace(anchor,anchor+'''
        allocation=fmr_irrigation_allocation_t(source_id=41_int64,revision=int(d,int64), &
          valid_t0=real(d,real64),valid_t1=real(d+1,real64),fraction=.5_real64)''')
 replace('forcing_config,canopy,rr,st,crop_committed=cs)', 'forcing_config,canopy,rr,st,crop_committed=cs,irrigation_allocation=allocation)')
 anchor='      prior_uptake=uptake;prior_wr=wr'
 assert s.count(anchor)==1
 replace(anchor,'''      call ta%snapshot_weather_irrigation(irrigation,selected_day,delivered_amount,st)
      call require(st==FMR_APP_BOOT_OK,'actual rooted joint management owner')
      if(wo%crop_emerged)then
        call require(irrigation%receipt%present.and.irrigation%receipt%allocation%revision==int(d,int64), &
          'fresh provider required and frozen independently each actual crop day')
        call require(.not.irrigation%management%event%active_event,'literal one-day event ends at midnight')
        call require(delivered_amount>0._real64,'positive irrigation with actual root uptake and crop growth')
      end if
'''+anchor)
 replace("  print '(a)','DAILY_DENSITY_ACTUAL_RICHARDS_SOURCE_RESTART=PASS'", "  print '(a)','DAILY_DENSITY_ACTUAL_RICHARDS_SOURCE_RESTART=PASS'\n  print '(a)','MC_IRR01_MANAGED_ADAPTIVE_ROOTED_DAILY_SOURCE_RESTART=PASS'")
 replace('\ncontains\n','\ncontains\n'+(root/'tests/mc-irr01/test_managed_weather_application.inc').read_text())
 target.write_text(s);return target
