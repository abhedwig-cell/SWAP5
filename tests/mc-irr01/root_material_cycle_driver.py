"""Extend the existing real rooted weather driver, retaining all owner assertions."""
from managed_root_cycle_driver import prepare as managed

def prepare(root,target,criterion=7,nodes=1):
 managed(root,target,criterion,nodes);s=target.read_text()
 def replace(a,b):
  nonlocal s
  assert s.count(a)==1,(s.count(a),a)
  s=s.replace(a,b)
 replace('    real(real64)::delivered_amount','''    real(real64)::delivered_amount,prior_delivered,expected_gift,deficit,rooted_dz,theta_fc,root_depth
    integer::material_positive,material_zero
    logical::material_trigger
    type(kernel_committed_state_t)::irrigation_soil
    class(transaction_state_t),allocatable::irrigation_physical''')
 anchor='    tc%file_weather_irrigation_depth%maximum_depth_cm=.04_real64'
 replace(anchor,anchor+f'''
    tc%file_weather_irrigation_depth%depth_criterion=1
    tc%file_weather_irrigation_depth%dcs1_knot_count=2
    tc%file_weather_irrigation_depth%dcs1_dvs(1:2)=[0._real64,2._real64]
    tc%file_weather_irrigation_depth%dcs1_adjustment_mm(1:2)=0._real64
    tc%file_weather_irrigation_depth%rainfall_threshold_cm=.05_real64
    tc%file_weather_irrigation_field_capacity_head_cm={('0.' if criterion==7 else '-100.0')}_real64''')
 anchor='      do d=0,6'
 replace(anchor,'''      material_positive=0;material_zero=0
'''+anchor)
 anchor='        uptake=0.0_real64;day_pot=0._real64;day_red=0._real64'
 replace(anchor,'''        call ta%snapshot_weather_irrigation(irrigation,selected_day,prior_delivered,st)
        call require(st==FMR_APP_BOOT_OK,'accepted daily irrigation origin')
        expected_gift=0._real64;deficit=0._real64;material_trigger=.false.
        if(wo%crop_emerged)then
          call require(crop_view%root_depth_present,'DCS1 uses actual committed root depth')
          root_depth=crop_view%root_depth%actual_root_depth_cm
          call ta%copy_committed_for_crop(1,irrigation_soil,st)
          call require(st==FMR_APP_BOOT_OK,'DCS1 accepted physical origin')
          call irrigation_soil%snapshot(irrigation_physical,ok)
          call require(ok,'DCS1 physical origin snapshot')
          select type(irrigation_physical)
          class is(fmr_b110_physical_state_t)
            if(tc%file_weather_irrigation_sensor%timing_criterion==7)then
              material_trigger=irrigation_physical%pressure_head(2)<=-1._real64
            else
              material_trigger=irrigation_physical%water_content(2)<=1._real64
            end if
            do i=1,numnod
              call require(tc%tiles(1)%parameters%cofgen(9,i)==0._real64,'independent analytic oracle on declared MvG branch')
              if(tc%file_weather_irrigation_field_capacity_head_cm==0._real64)then
                theta_fc=tc%tiles(1)%parameters%cofgen(2,i)
              else
                theta_fc=tc%tiles(1)%parameters%cofgen(1,i)+ &
                  (tc%tiles(1)%parameters%cofgen(2,i)-tc%tiles(1)%parameters%cofgen(1,i))/ &
                  (1._real64+abs(tc%tiles(1)%parameters%cofgen(4,i)* &
                  tc%file_weather_irrigation_field_capacity_head_cm)**tc%tiles(1)%parameters%cofgen(6,i))** &
                  tc%tiles(1)%parameters%cofgen(7,i)
              end if
              rooted_dz=max(0._real64,min(tc%tiles(1)%parameters%dz(i), &
                root_depth+tc%tiles(1)%parameters%z(i)+.5_real64*tc%tiles(1)%parameters%dz(i)))
              deficit=deficit+(theta_fc-irrigation_physical%water_content(i))*rooted_dz
            end do
          class default
            call require(.false.,'DCS1 actual Richards owner')
          end select
          call wr%values(wd,tmn,tmx,rain,etref,ok)
          call require(ok,'DCS1 authenticated full-day rain')
          expected_gift=deficit
          if(.1_real64*rain>tc%file_weather_irrigation_depth%rainfall_threshold_cm)expected_gift=expected_gift-.1_real64*rain
          expected_gift=min(.04_real64,max(0._real64,expected_gift))
          expected_gift=expected_gift*allocation%fraction
          if(.not.material_trigger)expected_gift=0._real64
          if(expected_gift>0._real64)then
            material_positive=material_positive+1
          else
            material_zero=material_zero+1
          end if
        end if
'''+anchor)
 a='''      if(wo%crop_emerged)then
        call require(irrigation%receipt%present.and.irrigation%receipt%allocation%revision==int(d,int64), &
          'fresh provider required and frozen independently each actual crop day')
        call require(.not.irrigation%management%event%active_event,'literal one-day event ends at midnight')
        call require(delivered_amount>0._real64,'positive irrigation with actual root uptake and crop growth')
      end if'''
 replace(a,f'''      if(abs(delivered_amount-prior_delivered-real({nodes},real64)*expected_gift)>=1.e-12_real64) &
        write(*,*)'MATERIAL_GIFT_DIAGNOSTIC=',d,material_trigger,root_depth,deficit,expected_gift,delivered_amount-prior_delivered
      call require(abs(delivered_amount-prior_delivered-real({nodes},real64)*expected_gift)<1.e-12_real64, &
        'independent accepted material/partial-root/whole-day-rain/cap/allocation/spatial gift')
      if(expected_gift>0._real64)then
        call require(irrigation%receipt%present.and.irrigation%receipt%allocation%revision==int(d,int64), &
          'fresh allocation bound once to positive DCS1 gift')
      end if
      call require(.not.irrigation%management%event%active_event,'DCS1 frozen one-day event completes')
      write(*,'(a,3(i0,1x),2(es24.16,1x))')'MATERIAL_DAILY_GIFT=',j,d,{criterion},expected_gift,delivered_amount-prior_delivered''')
 anchor="      call require(depth_events>=4,'all accepted daily depth events checked')"
 replace(anchor,("      call require(material_positive>0,'actual positive uncopied material-derived gift')\n" if criterion==7 else "      call require(material_zero>0,'actual rain or wet-soil zero-gift branch')\n")+anchor)
 anchor="  print '(a)','MC_IRR01_MANAGED_ADAPTIVE_ROOTED_DAILY_SOURCE_RESTART=PASS'"
 replace(anchor,anchor+"\n  print '(a)','MC_IRR01_MATERIAL_DCS1_ACCEPTED_ROOT_RAIN_MASS_RESTART=PASS'")
 target.write_text(s);return target
