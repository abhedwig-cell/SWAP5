module mod_fmr_irrigation_material_root_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t,b110_default_mvg_provider_t, &
    bind_b110_default_mvg_provider
  use mod_soil_water_solver_contract, only: CONSTITUTIVE_DEMAND_WATER_CONTENT
  use mod_irrigation_root_zone_summary, only: irrigation_root_zone_parameters_t
  use mod_crop_rotation_calendar, only: crop_calendar_t,CROP_CAL_OK,CROP_CAL_OUTSIDE
  use mod_swap_daily_weather_file_adapter, only: swap_weather_calendar_day,swap_weather_calendar_year
  implicit none
  private
  public :: fmr_build_irrigation_material_root_zone, fmr_resolve_irrigation_management_activation
contains
  ! B1.11 TASK3 period selection consumes the existing immutable crop plan
  ! and accepted Gregorian weather time. This routine owns no calendar/state.
  subroutine fmr_resolve_irrigation_management_activation(calendar,time,startirr,endirr,schedule,window,ok)
    type(crop_calendar_t),intent(in)::calendar
    real(real64),intent(in)::time
    integer,intent(in)::startirr(2),endirr(2) ! source day,month
    logical,intent(in)::schedule
    logical,intent(out)::window,ok
    real(real64),allocatable::starts(:),ends(:)
    real(real64)::t,lower,upper
    integer::year,first_year,last_year,period,st,a,b,i
    logical::active,begins,available
    window=.false.;ok=.false.
    if(.not.ieee_is_finite(time))return
    if(time<1._real64.or.time>=real(swap_weather_calendar_day(9999,12,31),real64)+1._real64)return
    if(.not.schedule)then
      ok=.true.;return
    end if
    call calendar%snapshot_periods(starts,ends,available)
    if(.not.available)return
    ! STARTIRR/ENDIRR are source1900 dates. Do not invent an annual wrap
    ! for same-year crops or silently repair the source leap-year arithmetic.
    a=swap_weather_calendar_day(1900,startirr(2),startirr(1))
    b=swap_weather_calendar_day(1900,endirr(2),endirr(1))
    if(a==0.or.b==0)return
    do i=1,size(starts)
      if(starts(i)<1._real64.or.ends(i)>=real(swap_weather_calendar_day(9999,12,31),real64)+1._real64)return
    end do
    call calendar%select_at(time,period,active,begins,st)
    if(st/=CROP_CAL_OK.and.st/=CROP_CAL_OUTSIDE)return
    ok=.true.
    if(.not.active)return
    first_year=swap_weather_calendar_year(int(starts(period)))
    last_year=swap_weather_calendar_year(int(ends(period)))
    if(last_year>first_year)then
      lower=real(swap_weather_calendar_day(first_year,startirr(2),startirr(1)),real64)
      upper=real(swap_weather_calendar_day(last_year,endirr(2),endirr(1)),real64)
      window=(time-lower)>1.e-3_real64.and.(time-upper)<=1.e-3_real64
    else
      year=swap_weather_calendar_year(int(time))
      t=time-real(swap_weather_calendar_day(year,1,1),real64)
      lower=real(a-swap_weather_calendar_day(1900,1,1),real64)
      upper=real(b-swap_weather_calendar_day(1900,1,1),real64)
      window=(t-lower)>=-1.e-3_real64.and.(t-upper)<=1.e-3_real64
    end if
  end subroutine

  ! Material thresholds follow B1.11 irrigation, not the transpiration-dependent
  ! Feddes threshold. No physical or crop state is mutated or owned here.
  subroutine fmr_build_irrigation_material_root_zone(material,dz,actual_depth,hfc,h3l,h3h,h4,root,ok)
    type(b110_default_mvg_parameters_t),target,intent(in)::material
    real(real64),intent(in)::dz(:),actual_depth,hfc,h3l,h3h,h4
    type(irrigation_root_zone_parameters_t),intent(out)::root
    logical,intent(out)::ok
    type(b110_default_mvg_provider_t)::provider
    type(irrigation_root_zone_parameters_t)::candidate
    real(real64)::heads(size(dz)),theta(size(dz)),k(size(dz)),c(size(dz)),dk(size(dz))
    real(real64)::remaining,values(5),mean_head
    integer::n,i
    root=irrigation_root_zone_parameters_t();ok=.false.;n=size(dz)
    values=[actual_depth,hfc,h3l,h3h,h4]
    if(.not.all(ieee_is_finite(values)))return
    if(n<=0.or.material%active_nodes/=n)return
    if(.not.allocated(material%cofgen))return
    if(size(material%cofgen,1)<42.or.size(material%cofgen,2)/=n)return
    if(.not.all(ieee_is_finite(material%cofgen)))return
    if(.not.all(ieee_is_finite(dz)))return
    if(any(dz<=0._real64))return
    if(.not.ieee_is_finite(sum(dz)))return
    if(actual_depth<=0._real64.or.actual_depth>sum(dz))return
    if(hfc< -500._real64.or.hfc>0._real64)return
    if(h3l< -10000._real64.or.h3l>100._real64.or.h3h< -10000._real64.or.h3h>100._real64)return
    if(h4< -20000._real64.or.h4>100._real64)return
    mean_head=(h3l+h3h)*.5_real64
    if(hfc<mean_head.or.mean_head<h4)return
    ! The managed profile admits only the existing ordinary default material.
    if(material%elastic_storage_active.or.material%conductivity_power_tail_enabled)return
    candidate%active_nodes=n;candidate%node_thickness_cm=dz
    remaining=actual_depth
    do i=1,n
      candidate%rooted_nodes=i
      candidate%last_rooted_fraction=min(1._real64,remaining/dz(i))
      if(remaining<=dz(i))exit
      remaining=remaining-dz(i)
    end do
    call bind_b110_default_mvg_provider(provider,material,1._real64)
    heads=hfc
    call provider%evaluate_demand(heads,CONSTITUTIVE_DEMAND_WATER_CONTENT,theta,k,c,dk)
    candidate%field_capacity_water_content=theta
    heads=mean_head
    call provider%evaluate_demand(heads,CONSTITUTIVE_DEMAND_WATER_CONTENT,theta,k,c,dk)
    candidate%stress_water_content=theta
    heads=h4
    call provider%evaluate_demand(heads,CONSTITUTIVE_DEMAND_WATER_CONTENT,theta,k,c,dk)
    candidate%wilting_water_content=theta
    if(.not.all(ieee_is_finite(candidate%field_capacity_water_content)).or. &
       .not.all(ieee_is_finite(candidate%stress_water_content)).or. &
       .not.all(ieee_is_finite(candidate%wilting_water_content)))return
    if(any(candidate%field_capacity_water_content>1._real64).or. &
       any(candidate%wilting_water_content<0._real64))return
    if(any(candidate%field_capacity_water_content<candidate%stress_water_content).or. &
       any(candidate%stress_water_content<candidate%wilting_water_content))return
    root=candidate;ok=.true.
  end subroutine
end module
