"""Additional real production parameter-identity refusal diagnostic."""
from swrd2_cycle_driver import prepare as base_prepare

def prepare(root,target):
 base_prepare(root,target);s=target.read_text()
 a=s.index('  subroutine test_rooted_weather_production(');b=s.index('\n  end subroutine',a)
 block=s[a:b]
 block=block.replace('type(fmr_wofost_crop_transaction_parameters_t)::cp,bad_cp',
  'type(fmr_wofost_crop_transaction_parameters_t)::cp,bad_cp,foreign_depth_cp\n    type(crop_root_depth_rate_parameters_t)::foreign_depth')
 anchor='          call ta%run_weather_crop_daystart(wr,c,ck,cp,cn,cs,cr,st)'
 assert block.count(anchor)==2
 negative='''          if(d==2)then
            foreign_depth=tc%file_weather_swrd2_parameters
            foreign_depth%initial_root_depth_cm=11._real64
            call construct_fmr_wofost_crop_transaction_parameters(bundle,update,0._real64,0._real64,foreign_depth_cp,st, &
              enable_potential_shadow=.true.,enable_anaerobic_root_growth_gate=.true.,aeration_critical_factor=.4_real64, &
              root_depth_parameters=foreign_depth)
            call require(st==FMR_WOF38_OK,'foreign depth parameters remain independently valid')
            crop_revision=cs%current_revision()
            call ta%run_weather_crop_daystart(wr,c,ck,foreign_depth_cp,cn,cs,cr,st)
            call require(st==FMR_APP_BOOT_CROP_TRANSACTION_FAILED.and.cs%current_revision()==crop_revision, &
              'foreign SWRD2 controls refuse before emergence without publication')
            call cs%snapshot(ps,ok);call require(ok,'foreign-control rejection snapshot')
            select type(ps)
            type is(fmr_wofost_crop_transaction_state_t)
              call ps%snapshot_root_depth(foreign_depth_state,ok)
              call require(ok.and.foreign_depth_state%actual_root_depth_cm==0._real64.and. &
                foreign_depth_state%potential_root_depth_cm==0._real64,'foreign emergence leaves both depths unchanged')
            end select
          end if
'''
 block=block.replace('type(crop_root_depth_rate_parameters_t)::foreign_depth',
  'type(crop_root_depth_rate_parameters_t)::foreign_depth\n    type(crop_root_depth_rate_state_t)::foreign_depth_state')
 block=block.replace(anchor,negative+anchor,1)
 s=s[:a]+block+s[b:]
 target.write_text(s);return target
