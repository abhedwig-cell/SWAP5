  subroutine literal_irrigation_selection(app,crop,config,weather,trigger,depth)
    type(fmr_production_application_bootstrap_t),intent(in)::app
    type(kernel_committed_state_t),intent(in)::crop
    type(fmr_production_application_config_t),intent(in)::config
    type(swap_daily_weather_record_t),intent(in)::weather
    logical,intent(out)::trigger
    real(real64),intent(out)::depth
    type(kernel_committed_state_t)::soil
    class(transaction_state_t),allocatable::cp,sp
    type(crop_root_depth_rate_state_t)::rd
    type(wofost_crop_owner_state_t)::owner
    real(real64)::left,weight,fc,stress,wilt,theta,awlh,awmh,awah,cdef,day,lo,hi,rain,et
    integer::i,st
    logical::ok
    trigger=.false.;depth=0;awlh=0;awmh=0;awah=0;cdef=0
    call crop%snapshot(cp,ok);call require(ok,'literal actual crop snapshot')
    select type(cp)
    type is(fmr_wofost_crop_transaction_state_t)
      call cp%snapshot_owner(owner,ok);call require(ok,'literal actual emerged owner')
      if(.not.owner%crop_emerged)return
      call cp%snapshot_root_depth(rd,ok);call require(ok,'literal accepted actual, not potential, root depth')
    class default
      call require(.false.,'literal owner type')
    end select
    call app%copy_committed_for_crop(1,soil,st);call require(st==FMR_APP_BOOT_OK,'literal actual soil')
    call soil%snapshot(sp,ok);call require(ok,'literal actual theta')
    left=rd%actual_root_depth_cm
    do i=1,config%tiles(1)%parameters%active_nodes
      weight=max(0._real64,min(config%tiles(1)%parameters%dz(i),left))
      left=left-config%tiles(1)%parameters%dz(i)
      fc=literal_irrigation_theta(config%tiles(1)%parameters%cofgen(:,i),config%file_weather_irrigation_field_capacity_head_cm)
      stress=literal_irrigation_theta(config%tiles(1)%parameters%cofgen(:,i), &
        (config%file_weather_root_parameters%hlim3l+config%file_weather_root_parameters%hlim3h)*.5_real64)
      wilt=literal_irrigation_theta(config%tiles(1)%parameters%cofgen(:,i),config%file_weather_root_parameters%hlim4)
      select type(sp)
      type is(fmr_b110_temporal_indicator_state_t)
        theta=sp%water_content(i)
      type is(fmr_b110_physical_state_t)
        theta=sp%water_content(i)
      class default
        call require(.false.,'literal physical soil type')
      end select
      awlh=awlh+(fc-wilt)*weight;awmh=awmh+(stress-wilt)*weight
      awah=awah+(theta-wilt)*weight;cdef=cdef+(fc-theta)*weight
    end do
    select case(config%file_weather_irrigation_sensor%timing_criterion)
    case(2)
      trigger=awah<awlh-min(awlh,config%file_weather_irrigation_depth%tcs2_fraction(1)*(awlh-awmh))
    case(3)
      trigger=awah<awlh-config%file_weather_irrigation_depth%tcs3_fraction(1)*awlh
    case(4)
      trigger=awlh-awah>config%file_weather_irrigation_depth%tcs4_depletion_mm(1)*.1_real64
    end select
    if(.not.trigger)return
    if(config%file_weather_irrigation_depth%depth_criterion==1)then
      call weather%values(day,lo,hi,rain,et,ok);call require(ok,'literal full authentic weather rain')
      rain=rain*.1_real64
      if(rain<=config%file_weather_irrigation_depth%rainfall_threshold_cm)rain=0
      depth=max(0._real64,cdef+config%file_weather_irrigation_depth%dcs1_adjustment_mm(1)*.1_real64-rain)
    else
      depth=config%file_weather_irrigation_depth%dcs2_depth_cm(1)
    end if
    if(config%file_weather_irrigation_depth%depth_limit_enabled)then
      depth=max(depth,config%file_weather_irrigation_depth%minimum_depth_cm)
      depth=min(depth,config%file_weather_irrigation_depth%maximum_depth_cm)
    end if
  end subroutine
  real(real64) function literal_irrigation_theta(c,h)result(theta)
    real(real64),intent(in)::c(:),h
    ! Independent ordinary MvG branch; exercised heads are0,-650,-16000cm.
    theta=c(1)+(c(2)-c(1))/(1._real64+abs(c(4)*h)**c(6))**c(7)
  end function
