program test_crop_b111_preflight_source_order
 use iso_fortran_env,only:real64,int64
 use mod_crop_germination_preflight
 implicit none
 type(crop_germination_candidate_t)::c
 real(real64)::o,a,tbase,tair,dry,wet,head,need,expected,wrong
 integer::st
 o=10.0_real64;a=7.3_real64;tbase=5.3_real64;tair=13.27_real64
 dry=-1000.0_real64;wet=-10.0_real64;head=-10000.0_real64
 need=a*log10(max(1.0_real64,-head))-(-(o-a*log10(-dry)))
 expected=(o/need)*(tair-tbase)
 wrong=(tair-tbase)*o/need
 if(transfer(expected,0_int64)==transfer(wrong,0_int64)) error stop 1
 call propose_crop_germination(2,0.0_real64,o,tbase,20.0_real64,tair,head,dry,wet,a,c,st)
 if(st/=CROP_GERM_OK.or..not.c%valid) error stop 2
 if(transfer(c%next_temperature_sum,0_int64)/=transfer(expected,0_int64)) error stop 3
 print '(a)','CROP_B111_PREFLIGHT_SOURCE_ORDER=PASS'
end program
