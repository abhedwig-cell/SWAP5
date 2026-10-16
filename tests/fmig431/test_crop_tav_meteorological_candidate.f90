program test_crop_tav_meteorological_candidate
 use, intrinsic :: iso_fortran_env, only: real64
 use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan
 use mod_crop_tav_meteorological_candidate
 implicit none
 real(real64) :: tav,nan
 integer :: status
 nan=ieee_value(0.0_real64,ieee_quiet_nan)
 call crop_tav_from_daily_minmax_candidate(-4.0_real64,12.0_real64,tav,status)
 if(status/=CROP_TAV_METEO_OK.or.abs(tav-4.0_real64)>1.e-14_real64) error stop 1
 if(transfer(tav,0_8)/=transfer((12.0_real64-4.0_real64)*0.5_real64,0_8)) error stop 7
 call crop_tav_from_daily_minmax_candidate(12.0_real64,-4.0_real64,tav,status)
 if(status/=CROP_TAV_METEO_INVALID) error stop 2
 call crop_tav_from_daily_minmax_candidate(nan,10.0_real64,tav,status)
 if(status/=CROP_TAV_METEO_INVALID) error stop 3
 call crop_tav_from_uniform_detail_candidate([0.0_real64,4.0_real64,8.0_real64,12.0_real64],tav,status)
 if(status/=CROP_TAV_METEO_OK.or.abs(tav-6.0_real64)>1.e-14_real64) error stop 4
 call crop_tav_from_uniform_detail_candidate([nan,10.0_real64],tav,status)
 if(status/=CROP_TAV_METEO_INVALID) error stop 5
 call crop_tav_from_uniform_detail_candidate([real(real64)::],tav,status)
 if(status/=CROP_TAV_METEO_INVALID) error stop 6
 print '(a)','SW431_CROP_TAV_METEO_CANDIDATE=PASS'
end program
