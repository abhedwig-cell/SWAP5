program test_ppa_wu05a26j_ic_storage_geometry
 use,intrinsic::iso_fortran_env,only:real64
 use mod_rfm_ic_storage_geometry
 implicit none
 type(rfm_ic_storage_geometry_result_t)::r,r2
 real(real64),parameter::tol=1e-12_real64
 call derive_rfm_ic_water_column(0.2_real64,0.02_real64,20.0_real64,tol,r)
 if(.not.r%valid)error stop 'valid'
 if(abs(r%water_column_height_cm-10.0_real64)>tol)error stop 'height'
 if(abs(r%storage_reconstructed_cm-0.2_real64)>tol)error stop 'closure'
 call derive_rfm_ic_water_column(0.3_real64,0.02_real64,20.0_real64,tol,r2)
 if(.not.r2%valid.or.r2%water_column_height_cm<=r%water_column_height_cm)error stop 'monotone'
 call derive_rfm_ic_water_column(0.5_real64,0.02_real64,20.0_real64,tol,r2)
 if(r2%valid)error stop 'overflow'
 call derive_rfm_ic_water_column(0.1_real64,0.0_real64,20.0_real64,tol,r2)
 if(r2%valid)error stop 'zero area'
 print '(a)','PPA_WU05A26J_IC_STORAGE_GEOMETRY=PASS'
end program
