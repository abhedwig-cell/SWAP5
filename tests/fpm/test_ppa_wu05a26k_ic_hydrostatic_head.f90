program test_ppa_wu05a26k_ic_hydrostatic_head
 use,intrinsic::iso_fortran_env,only:real64
 use mod_rfm_ic_hydrostatic_head
 implicit none
 type(rfm_ic_hydrostatic_head_result_t)::r
 real(real64),parameter::tol=1e-12_real64
 ! Endpoint segment 80..100 cm; 10 cm stored column gives water level at 90 cm.
 ! Matrix node at 95 cm is 5 cm below water level, hence h_mp=+5 cm.
 call derive_rfm_ic_hydrostatic_head(100.0_real64,20.0_real64,10.0_real64,95.0_real64,-30.0_real64,r)
 if(.not.r%valid)error stop 'valid'
 if(abs(r%water_level_depth_cm-90.0_real64)>tol)error stop 'level'
 if(abs(r%macropore_pressure_head_cm-5.0_real64)>tol)error stop 'hmp'
 if(abs(r%macro_to_matrix_head_difference_cm-35.0_real64)>tol)error stop 'dh'
 call derive_rfm_ic_hydrostatic_head(100.0_real64,20.0_real64,10.0_real64,70.0_real64,-30.0_real64,r)
 if(r%valid)error stop 'node outside segment'
 print '(a)','PPA_WU05A26K_IC_HYDROSTATIC_HEAD=PASS'
end program
