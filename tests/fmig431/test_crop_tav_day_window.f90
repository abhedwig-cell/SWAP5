program test_crop_tav_day_window
 use iso_fortran_env,only:int64,real64
 use mod_crop_tav_day_window
 implicit none
 type(crop_tav_day_window_t)::w,copy
 integer::s,n
 integer(int64)::lin,src,rev
 real(real64)::t,v
 call start_crop_tav_day(w,12_int64,91_int64,4_int64,30.0_real64,31.0_real64,s)
 if(s/=TAV_DAY_OK) error stop 1
 call append_crop_tav_interval_candidate(w,12_int64,91_int64,4_int64,30.0_real64,30.25_real64,10.0_real64,s)
 if(s/=TAV_DAY_OK) error stop 2
 copy=w
 call append_crop_tav_interval_candidate(w,12_int64,91_int64,5_int64,30.5_real64,30.75_real64,15.0_real64,s)
 if(s/=TAV_DAY_GAP) error stop 3
 call append_crop_tav_interval_candidate(w,12_int64,91_int64,5_int64,30.0_real64,30.25_real64,15.0_real64,s)
 if(s/=TAV_DAY_DUPLICATE) error stop 4
 call append_crop_tav_interval_candidate(w,12_int64,92_int64,5_int64,30.25_real64,30.5_real64,15.0_real64,s)
 if(s/=TAV_DAY_MISMATCH) error stop 5
 call append_crop_tav_interval_candidate(w,12_int64,91_int64,6_int64,30.25_real64,30.5_real64,15.0_real64,s)
 if(s/=TAV_DAY_MISMATCH) error stop 6
 call w%snapshot(lin,src,rev,t,n)
 if(lin/=12_int64.or.src/=91_int64.or.rev/=5_int64.or.t/=30.25_real64.or.n/=1) error stop 7
 call read_crop_tav_day_candidate(w,v,s)
 if(s/=TAV_DAY_INVALID) error stop 8
 call append_crop_tav_interval_candidate(w,12_int64,91_int64,5_int64,30.25_real64,30.5_real64,14.0_real64,s)
 if(s/=TAV_DAY_OK) error stop 9
 call append_crop_tav_interval_candidate(w,12_int64,91_int64,6_int64,30.5_real64,31.0_real64,18.0_real64,s)
 if(s/=TAV_DAY_OK.or..not.w%complete()) error stop 10
 call read_crop_tav_day_candidate(w,v,s)
 if(s/=TAV_DAY_OK.or.abs(v-15.0_real64)>1.e-12_real64) error stop 11
 if(copy%complete()) error stop 12
 print '(a)','CROP_TAV_DAY_WINDOW=PASS'
end program
