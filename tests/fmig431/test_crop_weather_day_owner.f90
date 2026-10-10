program test_weather_day_owner
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_crop_weather_day_owner
 implicit none
 type(weather_day_owner_t)::w,w2
 integer::s
 integer(int64)::source,epoch,revision
 real(real64)::day,tmin,tmax,tav,nan,paired_min,paired_max
 logical::yes
 nan=ieee_value(0.0_real64,ieee_quiet_nan)
 call initialize_weather_day_owner(w,2_int64,7_int64,s)
 if(s/=WEATHER_DAY_OK) error stop 1
 call ingest_weather_day(w,2_int64,7_int64,12.0_real64,-4.0_real64,12.0_real64,s)
 if(s/=WEATHER_DAY_OK) error stop 2
 call w%read_day(2_int64,7_int64,1_int64,12.0_real64,tav,s)
 if(s/=WEATHER_DAY_OK.or.tav/=4.0_real64) error stop 3
 call w%read_day(2_int64,7_int64,1_int64,12.0_real64,tav,s,paired_min,paired_max)
 if(s/=WEATHER_DAY_OK.or.paired_min/=-4.0_real64.or.paired_max/=12.0_real64) error stop 31
 if(tav/=(paired_max+paired_min)*0.5_real64) error stop 32
 call w%read_day(2_int64,7_int64,0_int64,12.0_real64,tav,s,paired_min,paired_max)
 if(s/=WEATHER_DAY_STALE.or.tav/=0.0_real64.or.paired_min/=0.0_real64.or.paired_max/=0.0_real64) error stop 33
 call ingest_weather_day(w,2_int64,7_int64,12.0_real64,-4.0_real64,12.0_real64,s)
 if(s/=WEATHER_DAY_DUPLICATE) error stop 4
 call ingest_weather_day(w,2_int64,7_int64,12.0_real64,-3.0_real64,12.0_real64,s)
 if(s/=WEATHER_DAY_CONFLICT) error stop 15
 call w%snapshot(source,epoch,revision,day,tmin,tmax,yes)
 if(.not.yes.or.revision/=1_int64.or.tmin/=-4.0_real64) error stop 16
 call w%read_day(2_int64,7_int64,1_int64,12.0_real64,tav,s)
 if(s/=WEATHER_DAY_OK.or.tav/=4.0_real64) error stop 17
 call ingest_weather_day(w,2_int64,7_int64,12.0_real64,-4.0_real64,13.0_real64,s)
 if(s/=WEATHER_DAY_CONFLICT) error stop 18
 call ingest_weather_day(w,2_int64,7_int64,12.0_real64,-4.0_real64,12.0_real64,s)
 if(s/=WEATHER_DAY_DUPLICATE) error stop 19
 call ingest_weather_day(w,3_int64,7_int64,13.0_real64,-4.0_real64,12.0_real64,s)
 if(s/=WEATHER_DAY_SOURCE) error stop 5
 call ingest_weather_day(w,2_int64,7_int64,14.0_real64,-4.0_real64,12.0_real64,s)
 if(s/=WEATHER_DAY_STALE) error stop 6
 call ingest_weather_day(w,2_int64,7_int64,13.0_real64,nan,12.0_real64,s)
 if(s/=WEATHER_DAY_INVALID) error stop 7
 call w%snapshot(source,epoch,revision,day,tmin,tmax,yes)
 if(.not.yes.or.revision/=1_int64.or.day/=12.0_real64) error stop 8
 call reconstruct_weather_day_owner(w2,source,epoch,revision,day,tmin,tmax,s)
 if(s/=WEATHER_DAY_OK) error stop 9
 call w2%read_day(source,epoch,revision,day,tav,s)
 if(s/=WEATHER_DAY_OK.or.tav/=4.0_real64) error stop 10
 call ingest_weather_day(w2,source,epoch,day,-3.0_real64,tmax,s)
 if(s/=WEATHER_DAY_CONFLICT) error stop 20
 call w2%read_day(source,epoch,revision,day,tav,s)
 if(s/=WEATHER_DAY_OK.or.tav/=4.0_real64) error stop 21
 call w2%read_day(source,epoch,0_int64,day,tav,s)
 if(s/=WEATHER_DAY_STALE) error stop 11
 call ingest_weather_day(w,source,epoch,13.0_real64,2.0_real64,20.0_real64,s)
 if(s/=WEATHER_DAY_OK) error stop 12
 call w%read_day(source,epoch,2_int64,13.0_real64,tav,s)
 if(s/=WEATHER_DAY_OK.or.tav/=11.0_real64) error stop 13
 call w%read_day(source,epoch,1_int64,12.0_real64,tav,s)
 if(s/=WEATHER_DAY_STALE.or.tav/=0.0_real64) error stop 14
 ! Accepted next-day replay is idempotent: identical values cannot advance
 ! revision; changed values on the same day must fail without mutation.
 call ingest_weather_day(w,source,epoch,13.0_real64,2.0_real64,20.0_real64,s)
 if(s/=WEATHER_DAY_DUPLICATE) error stop 22
 call w%snapshot(source,epoch,revision,day,tmin,tmax,yes)
 if(.not.yes.or.revision/=2_int64.or.day/=13.0_real64) error stop 23
 call ingest_weather_day(w,source,epoch,13.0_real64,2.0_real64,19.0_real64,s)
 if(s/=WEATHER_DAY_CONFLICT) error stop 24
 call w%read_day(source,epoch,2_int64,13.0_real64,tav,s)
 if(s/=WEATHER_DAY_OK.or.tav/=11.0_real64) error stop 25
 ! Restart must retain the day/revision identity, not silently advance
 ! when the producer replays its last already-consumed weather day.
 call reconstruct_weather_day_owner(w2,source,epoch,revision,day,tmin,tmax,s)
 if(s/=WEATHER_DAY_OK) error stop 26
 call ingest_weather_day(w2,source,epoch,day,tmin,tmax,s)
 if(s/=WEATHER_DAY_DUPLICATE) error stop 27
 call w2%read_day(source,epoch,revision,day,tav,s)
 if(s/=WEATHER_DAY_OK.or.tav/=11.0_real64) error stop 28
 call ingest_weather_day(w2,source,epoch,14.0_real64,4.0_real64,16.0_real64,s)
 if(s/=WEATHER_DAY_OK) error stop 29
 call w2%read_day(source,epoch,3_int64,14.0_real64,tav,s)
 if(s/=WEATHER_DAY_OK.or.tav/=10.0_real64) error stop 30
 call w2%read_day(source,epoch,3_int64,14.0_real64,tav,s,paired_min,paired_max)
 if(s/=WEATHER_DAY_OK.or.paired_min/=4.0_real64.or.paired_max/=16.0_real64) error stop 34
 print '(a)','CROP_WEATHER_DAY_OWNER=PASS'
end program
