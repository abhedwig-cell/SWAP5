program fvq115
 use, intrinsic::iso_fortran_env,only:real64
 use mod_pmdirect_swetr0_process
 use mod_rutter_interception_process
 implicit none
 type(pmdirect_swetr0_weather_t)::w;type(pmdirect_swetr0_site_t)::s;type(pmdirect_swetr0_canopy_t)::c
 type(pmdirect_swetr0_daily_result_t)::dr;type(pmdirect_swetr0_diagnostics_t)::dd
 type(rutter_state_t)::rs;type(rutter_interval_input_t)::ri;type(rutter_interval_result_t)::rr;type(rutter_diagnostics_t)::rd
 real(real64),parameter::tol=1d-12
 ! Independent frozen exact-legacy observation: potato, 2003-08-15, SWCF=2.
 w%day_of_year=227;w%radiation_j_m2_d=20370000d0;w%minimum_air_temperature_c=9.1d0;w%maximum_air_temperature_c=23.2d0
 w%vapour_pressure_kpa=1.1493d0;w%wind_speed_m_s=4.17d0;w%gross_rain_cm_d=0d0
 s%latitude_degrees=52d0;s%altitude_m=10d0;s%wind_measurement_height_m=10d0;s%humidity_measurement_height_m=1.5d0
 s%angstrom_a=0.25d0;s%angstrom_b=0.5d0;s%wind_function_factor=1d0;s%soil_surface_resistance_s_m=600d0
 c%crop_emerged=.true.;c%use_crop_height_for_aerodynamics=.true.;c%crop_height_cm=67.904761904761884d0
 c%lai=3.8691959409102386d0;c%vegetation_cover_fraction=0.94508105761722561d0;c%albedo=0.19d0
 c%dry_canopy_resistance_s_m=205.8d0;c%wet_canopy_resistance_s_m=0d0;c%co2_transpiration_factor=1d0
 call evaluate_pmdirect_swetr0_daily(w,s,c,dr,dd)
 if(dd%status/=PMDIRECT_SWETR0_OK) error stop 1
 if(abs(dr%potential_transpiration_dry_cm_per_day-0.36989155956560815d0)>tol) error stop 2
 if(abs(dr%potential_transpiration_wet_cm_per_day-0.11806407365914319d0)>tol) error stop 3
 if(abs(dr%potential_soil_evaporation_cm_per_day-0.021039381230798154d0)>tol) error stop 4
 ! Independent frozen exact-legacy observation: grass, 2004-10-15, full Rutter reservoir.
 rs%canopy_storage_cm=0.063714499249828235d0
 ri%gross_rain_cm_per_day=0.47d0;ri%vegetation_cover_fraction=0.63562099391997362d0
 ri%canopy_storage_capacity_cm=0.063714499249828235d0;ri%interception_evaporation_capacity_cm_per_day=0.052357843735008791d0
 ri%potential_transpiration_dry_cm_per_day=0.0818009159111939d0;ri%potential_transpiration_wet_cm_per_day=0.03749398442638522d0
 ri%interval_days=0.04d0
 call evaluate_rutter_interval(rs,ri,rr,rd)
 if(rd%status/=RUTTER_OK) error stop 5
 if(abs(rr%interception_rate_cm_per_day-0.052357843735008791d0)>tol) error stop 6
 if(abs(rr%net_rain_cm_per_day-0.41764215626499124d0)>tol) error stop 7
 if(abs(rr%potential_transpiration_cm_per_day-0.03749398442638522d0)>tol) error stop 8
 print '(A)','F-VQ115_PASS'
end program
