program test_daily_demand_source
use iso_fortran_env,only:real64
use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
use mod_reference_et_demand_process
use b111_daily_demand_oracle
implicit none
type(daily_atmospheric_demand_parameters_t)::p,other
type(traditional_pm_weather_t)::w
type(traditional_pm_daily_result_t)::r
type(reference_et_demand_diagnostics_t)::d
type(reference_et_demand_canopy_view_t)::cv
type(reference_et_demand_result_t)::rr
real(real64)::actual(9),expected(9),off(3),on(3),factor,cover,ref
integer::a,b,c,e,f,g,h,count,st,witness
logical::emerged
p%mode=0
p%site%latitude_degrees=52.d0;p%site%altitude_m=10.d0
p%site%wind_measurement_height_m=10.d0;p%site%humidity_measurement_height_m=1.5d0
p%site%angstrom_a=0.25d0;p%site%angstrom_b=0.5d0
p%canopy%crop_height_cm=25.d0;p%canopy%lai=2.d0;p%canopy%albedo=0.23d0
p%canopy%dry_canopy_resistance_s_m=70.d0;p%canopy%wet_canopy_resistance_s_m=0.d0
count=0;witness=0
! Complete literal daily branch with independent site/weather/selector vectors.

do a=1,4
 w%day_of_year=20+90*(a-1);w%radiation_j_m2_d=3.6d6*a
 w%minimum_air_temperature_c=2.d0*a;w%maximum_air_temperature_c=10.d0+2.d0*a
 w%vapour_pressure_kpa=0.5d0*a;w%wind_speed_m_s=0.5d0*a
 do b=0,1
  p%canopy%crop_emerged=b==1
  do c=0,1
   p%canopy%use_crop_height_for_aerodynamics=c==1
   do e=0,4
    p%canopy%vegetation_cover_fraction=0.25d0*e
    do f=0,1
     p%soil_factor_enabled=f==1
     do g=0,2
      p%soil_factor=0.5d0*g;p%crop_factor=1.3d0;p%pond_factor=0.9d0
      do h=1,2
       p%canopy%co2_transpiration_factor=0.7d0*h
       call set_oracle(p,w)
       call ETpot()
       expected=[es0,et0,ew0,ep0,peva,epond,ptra_dry,ptra_wet,eintc]
       call evaluate_traditional_pm_daily(w,p,r,d)
       call require(d%status==0.and.d%result_produced,'traditional valid input')
       actual=[r%es0_mm_per_day,r%et0_mm_per_day,r%ew0_mm_per_day,r%ep0_mm_per_day, &
        r%potential_soil_evaporation_cm_per_day,r%potential_pond_evaporation_cm_per_day, &
        r%potential_transpiration_dry_cm_per_day,r%potential_transpiration_wet_cm_per_day, &
        r%interception_evaporation_capacity_cm_per_day]
       call require(all(abs(actual-expected)<=1.d-12),'literal traditional PM/ETpot equality')
       count=count+1
      end do
     end do
    end do
   end do
  end do
 end do
end do
! Distinguish CFBS branch base selection from multiplying ordinary wet-soil PM.
p%canopy%crop_emerged=.true.;p%canopy%use_crop_height_for_aerodynamics=.false.
p%canopy%vegetation_cover_fraction=0.5d0;p%soil_factor=1.d0;p%soil_factor_enabled=.false.
call evaluate_traditional_pm_daily(w,p,r,d);off=[r%es0_mm_per_day,r%et0_mm_per_day,r%ep0_mm_per_day]
p%soil_factor_enabled=.true.;call evaluate_traditional_pm_daily(w,p,r,d)
on=[r%es0_mm_per_day,r%et0_mm_per_day,r%ep0_mm_per_day]
call require(abs(off(1)-on(1))>1.d-5.and.off(2)==on(2).and.off(3)==on(3),'CFBS base-selection witness')
witness=witness+1
! Reference branch: soil alone changes; validate against actual ETpot too.
p%mode=1;cv%crop_emerged=.true.;cv%vegetation_cover_fraction=0.5d0
cv%crop_factor=1.3d0;cv%co2_transpiration_factor=0.9d0
ref=3.d0
p%soil_factor_enabled=.false.;call evaluate_daily_atmospheric_demand(p,w,ref,cv,rr,st)
off=[rr%potential_soil_evaporation_cm_per_day,rr%potential_transpiration_cm_per_day,rr%potential_pond_evaporation_cm_per_day]
p%soil_factor_enabled=.true.;p%soil_factor=0.5d0
call evaluate_daily_atmospheric_demand(p,w,ref,cv,rr,st)
on=[rr%potential_soil_evaporation_cm_per_day,rr%potential_transpiration_cm_per_day,rr%potential_pond_evaporation_cm_per_day]
call require(st==0.and.on(1)==0.5d0*off(1).and.on(2)==off(2).and.on(3)==off(3),'reference CFBS soil-only witness')
call set_oracle(p,w);swetr=1;etr=ref;vcover=cv%vegetation_cover_fraction;cf=cv%crop_factor;fco2tra=cv%co2_transpiration_factor
call ETpot();call require(all(abs(on-[peva,ptra_dry,epond])<=1.d-12),'literal reference CFBS')
witness=witness+1
other=p;call require(other%same_input(p),'configuration identity')
other%soil_factor=0.6d0;call require(.not.other%same_input(p),'changed factor identity')
other=p;other%site%altitude_m=ieee_value(0.d0,ieee_quiet_nan)
call require(.not.other%ready(),'nonfinite immutable unused configuration')
p%mode=0;p%site%wind_measurement_height_m=0.09d0
call require(.not.p%ready(),'source wind measurement lower bound')
p%site%wind_measurement_height_m=10.d0
p%mode=99;call require(.not.p%ready(),'unknown selector')
p%mode=0;p%soil_factor=-1.d0;call require(.not.p%ready(),'negative factor')
p%soil_factor=ieee_value(0.d0,ieee_quiet_nan);call require(.not.p%ready(),'nan factor')
p%soil_factor=1.d0;w%minimum_air_temperature_c=-237.3d0
call evaluate_traditional_pm_daily(w,p,r,d);call require(d%status/=0.and..not.d%result_produced,'invalid temperature domain')
print '(a,i0,a,i0)','MC_MET01_LITERAL_DAILY_DEMAND_CASES=',count,' WITNESSES=',witness
contains
subroutine set_oracle(pp,ww)
 type(daily_atmospheric_demand_parameters_t),intent(in)::pp
 type(traditional_pm_weather_t),intent(in)::ww
 swetr=0;swdivide=0;swmetdetail=0;n_metdetail=1;i_metdetail=1
 swcf=1;if(pp%canopy%use_crop_height_for_aerodynamics) swcf=2
 swcfbs=0;if(pp%soil_factor_enabled) swcfbs=1
 fl_cropemergence=pp%canopy%crop_emerged;cfbs=pp%soil_factor;cf=pp%crop_factor;cfevappond=pp%pond_factor
 fco2tra=pp%canopy%co2_transpiration_factor;vcover=pp%canopy%vegetation_cover_fraction
 daynr=ww%day_of_year;rad=ww%radiation_j_m2_d;tmn=ww%minimum_air_temperature_c;tmx=ww%maximum_air_temperature_c
 tav=(tmx+tmn)*0.5d0;hum=ww%vapour_pressure_kpa;win=ww%wind_speed_m_s
 lat=pp%site%latitude_degrees;alt=pp%site%altitude_m;altw=pp%site%wind_measurement_height_m
 alth=pp%site%humidity_measurement_height_m;fwind=pp%site%wind_function_factor
 angstroma=pp%site%angstrom_a;angstromb=pp%site%angstrom_b;long=0.d0;long_tz=0.d0
 ch=pp%canopy%crop_height_cm;lai=pp%canopy%lai;albedo=pp%canopy%albedo
 rsc=pp%canopy%dry_canopy_resistance_s_m;rsw=pp%canopy%wet_canopy_resistance_s_m;rsoil=0.d0
end subroutine
subroutine require(ok,label)
 logical,intent(in)::ok
 character(*),intent(in)::label
 if(.not.ok) then
 print *,label;error stop 1
 end if
end subroutine
end program
