program test_crop_b111_meteo_loading_candidate
 use iso_fortran_env, only: real64
 use ieee_arithmetic, only: ieee_value,ieee_quiet_nan
 use mod_crop_b111_meteo_loading_candidate
 implicit none
 real(real64):: s(4),e(4),nan,t0,t1
 integer:: types(4),i,j,k,st,n
 logical:: got,expected
 nan=ieee_value(0.0_real64,ieee_quiet_nan)
 n=0
 do i=0,9
  do j=0,9
   do k=0,3
    t0=real(i,real64)*0.75_real64
    t1=t0+real(j,real64)*0.25_real64
    s=[1.0_real64,2.0_real64,3.0_real64,nan]
    e=[1.5_real64,2.7_real64,3.5_real64,nan]
    types=[1,2,k,2]
    call crop_b111_meteo_loading_candidate(t0,t1,s,e,types,3,got,st)
    if(st/=CROP_METEO_LOAD_OK) error stop 1
    expected=.false.
    if(t1>s(2)) then
      if(t1+0.1_real64>s(2).and.t0-0.1_real64<e(2)) expected=.true.
    end if
    if(k==2.and.t1>s(3)) then
      if(t1+0.1_real64>s(3).and.t0-0.1_real64<e(3)) expected=.true.
    end if
    if(got.neqv.expected) error stop 2
    n=n+1
   end do
  end do
 end do
 if(n/=400) error stop 3
 s=[1.0_real64,2.0_real64,3.0_real64,nan]
 e=[1.5_real64,2.7_real64,3.5_real64,nan]
 types=[1,2,1,2]
 call crop_b111_meteo_loading_candidate(1.0_real64,2.4_real64,s,e,types,4,got,st)
 if(st/=CROP_METEO_LOAD_INVALID.or.got) error stop 4
 call crop_b111_meteo_loading_candidate(1.0_real64,2.4_real64,s,e,types,0,got,st)
 if(st/=CROP_METEO_LOAD_OK.or.got) error stop 5
 call crop_b111_meteo_loading_candidate(1.0_real64,2.4_real64,s,e,types,5,got,st)
 if(st/=CROP_METEO_LOAD_INVALID.or.got) error stop 6
 s(2)=0.0_real64
 call crop_b111_meteo_loading_candidate(1.0_real64,2.4_real64,s,e,types,3,got,st)
 if(st/=CROP_METEO_LOAD_INVALID.or.got) error stop 7
 print '(a)','CROP_B111_METEO_LOADING=PASS cases=400'
end program
