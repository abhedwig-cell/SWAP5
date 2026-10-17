program test_surface_receipt_gate
 use iso_fortran_env,only:real64
 use mod_b111_surface_receipt_gate
 implicit none
 type(surface_gross_receipt_t)::r
 integer::status
 real(real64)::residual
 r%t0=0d0;r%t1=1d0;r%depth_begin=1d0;r%depth_end=0.6d0
 r%rain=0.2d0;r%irrigation=0.1d0;r%runon=0.1d0
 r%qtop=-0.4d0;r%evaporation=0.2d0;r%runoff=0.2d0
 call check_surface_gross_receipt(r,status,residual)
 if(status/=SURFACE_RECEIPT_MISSING)error stop 'missing rejected'
 r%accepted=.true.;r%gross_available=.true.
 call check_surface_gross_receipt(r,status,residual)
 if(status/=SURFACE_RECEIPT_OK.or.abs(residual)>1d-12)error stop 'balanced'
 r%runoff=0.1d0
 call check_surface_gross_receipt(r,status,residual)
 if(status/=SURFACE_RECEIPT_BALANCE)error stop 'runoff mismatch'
 r%runoff=0.2d0;r%accepted=.false.
 call check_surface_gross_receipt(r,status,residual)
 if(status/=SURFACE_RECEIPT_MISSING)error stop 'unaccepted'
 print '(a)','SURFACE_RECEIPT_GATE=PASS'
end program
