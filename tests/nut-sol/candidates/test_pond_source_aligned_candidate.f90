program test_pond_source_aligned_candidate
 use iso_fortran_env,only:real64
 use mod_b111_pond_source_aligned_candidate
 implicit none
 type(aligned_pond_receipt_t)::r
 call evaluate_aligned_pond(1d0,2d0,1d0,0d0,0d0,0.5d0,0.25d0,0d0,0d0,0d0,0.25d0,r)
 if(r%status/=ALIGNED_OK.or.abs(r%soil_transfer-1d0)>1d-12)error stop 'incumbent evaporation formula'
 if(abs(r%mass_end-1d0)>1d-12)error stop 'retained mass'
 call evaluate_aligned_pond(0d0,3d0,1d0,0d0,0d0,0d0,0d0,0d0,0d0,0d0,0d0,r)
 if(r%status/=ALIGNED_OK.or.abs(r%mass_end-3d0)>1d-12)error stop 'dry retained'
 call evaluate_aligned_pond(1d0,2d0,1d0,0d0,0d0,0.5d0,0.25d0,0d0,0d0,0d0,0.4d0,r)
 if(r%status/=ALIGNED_WATER)error stop 'inconsistent water'
 print '(a)','SOURCE_ALIGNED_POND=PASS'
end program
