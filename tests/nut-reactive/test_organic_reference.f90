program test_organic_reference
 use wofost_soil_declarations
 implicit none
 real(8)::before,after,residual
 character(32)::mode
 call get_command_argument(1,mode)
 nf=1;dz_WSN=.3d0;dt_WSN=1d0
 FOM_t0(1)=10d0;Bio_t0=5d0;Hum_t0=40d0
 RateconFOM(1)=.04d0;RateconBio=.008d0;RateconHum=.0008d0
 AsfaFOM_Bio(1)=.2d0;AsfaFOM_Hum(1)=.15d0;AsfaBio=.3d0;AsfaHum=.2d0
 NFracFOM(1)=.015d0;NFracBio=.04d0;NFracHum=.02d0
 CFracFOM(1)=.45d0;CFracBio=.45d0;CFracHum=.45d0
 FOM2Bio=0d0;NFOM2Bio=0d0;FOM2Hum=0d0;NFOM2Hum=0d0;FOM_dis=0d0;NFOM_min=0d0
 Bio2Bio=0d0;NBio2Bio=0d0;Bio2Hum=0d0;NBio2Hum=0d0;Bio_dis=0d0;NBio_min=0d0
 Hum2Bio=0d0;NHum2Bio=0d0;Hum2Hum=0d0;NHum2Hum=0d0;Hum_dis=0d0;NHum_min=0d0
 before=dz_WSN*(FOM_t0(1)*NFracFOM(1)+Bio_t0*NFracBio+Hum_t0*NFracHum)
 call wofost_soilorgmatn()
 after=dz_WSN*(FOM_t(1)*NFracFOM(1)+Bio_t*NFracBio+Hum_t*NFracHum)
 residual=after-before+Nminer*dz_WSN
 if(trim(mode)=='legacy')then
   if(abs(residual)<1d-8)error stop 'legacy defect not discriminated'
   print '(A,ES24.16)','ORIGINAL_NMINER_DEFECT_RESIDUAL=',residual
   print '(A)','ORIGINAL_ORGANIC_REFERENCE_DEFECT_WITNESS=PASS'
 else
   if(abs(residual)>1d-12)error stop 'corrected reference fails whole N'
   if(abs(Nminer*dz_WSN-NFOM_min-NBio_min-NHum_min)>1d-12)error stop 'corrected accumulator mismatch'
   print '(A)','CORRECTED_ORGANIC_REFERENCE_WHOLE_N=PASS'
 end if
end program
