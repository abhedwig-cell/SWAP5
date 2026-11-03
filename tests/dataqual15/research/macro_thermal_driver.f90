program macro_thermal_driver
 use iso_fortran_env,only:real64
 use mod_macro_liquid_thermal
 use mod_liquid_water_sensible_enthalpy
 implicit none
 type(macro_liquid_thermal_result_t)::r
 type(liquid_water_sensible_enthalpy_parameters_t)::liquid
 real(real64)::w0(1,2),w1(1,2),q(1,3),x(1,2),sink(1,2),t0(1,2),tm0(2),tm1(2),tt0(1),tt1(1),bt(1)
 real(real64)::last,error,expected,stored
 logical::initial(1,2),ma(2),ta(1),ba(1)
 integer::k,steps,status
 real(real64)::matrix_before,matrix_after,macro_before,macro_after
 w0=1d0;w1=1d0;q=1d0;x=0d0;sink=0d0;t0=0d0;tm0=0d0;tm1=0d0;tt0=10d0;tt1=10d0;bt=0d0
 initial=.true.;ma=.true.;ta=.true.;ba=.false.;last=huge(1d0)
 ! Two stirred volumes in series: T2=10*(1-exp(-t)*(1+t)).
 expected=10d0*(1d0-2d0*exp(-1d0))
 do k=0,6
  steps=2**k
  call advance_macro_liquid_thermal(w0,w1,q,x,sink,t0,initial,tm0,tm1,ma,tt0,tt1,ta,bt,bt,ba,1d0,steps,4.18d0,r)
  if(.not.r%produced)error stop 'mixing'
  error=abs(r%temperature_c(1,2)-expected)
  if(k>0.and.error>=last)error stop 'no convergence'
  if(abs(r%residual_j_cm2)>1d-11)error stop 'mixing energy'
  last=error
 end do
 ! Known linear external temperature, no outlet: exact final T=5C, first-order right quadrature.
 w1=2d0;q=0d0;q(1,1)=1d0;w1(1,2)=1d0;tt0=0d0;tt1=20d0;last=huge(1d0)
 do k=0,7
  steps=2**k
  call advance_macro_liquid_thermal(w0,w1,q,x,sink,t0,initial,tm0,tm1,ma,tt0,tt1,ta,bt,bt,ba,1d0,steps,4.18d0,r)
  if(.not.r%produced)error stop 'linear donor'
  error=abs(r%temperature_c(1,1)-5d0)
  if(k>0.and.error>=last)error stop 'donor quadrature convergence'
  last=error
 end do
 ! A dry conduit has zero storage and transfers the supplied donor exactly.
 w0=0d0;w1=0d0;q=1d0;tt0=12d0;tt1=12d0;initial=.false.
 call advance_macro_liquid_thermal(w0,w1,q,x,sink,t0,initial,tm0,tm1,ma,tt0,tt1,ta,bt,bt,ba,1d0,1,4.18d0,r)
 if(.not.r%produced.or.maxval(abs(r%temperature_c-12d0))>1d-12)error stop 'dry conduit'
 if(.not.all(r%temperature_available))error stop 'dry conduit availability'
 q=0d0
 call advance_macro_liquid_thermal(w0,w1,q,x,sink,t0,initial,tm0,tm1,ma,tt0,tt1,ta,bt,bt,ba,1d0,1,4.18d0,r)
 if(.not.r%produced.or.any(r%temperature_available))error stop 'isolated dry invented temperature'
 q=1d0;ta=.false.
 call advance_macro_liquid_thermal(w0,w1,q,x,sink,t0,initial,tm0,tm1,ma,tt0,tt1,ta,bt,bt,ba,1d0,1,4.18d0,r)
 if(r%produced.or.allocated(r%temperature_c))error stop 'missing external donor'
 ta=.true.;w0=1d0;w1=1d0;q=0d0
 call advance_macro_liquid_thermal(w0,w1,q,x,sink,t0,initial,tm0,tm1,ma,tt0,tt1,ta,bt,bt,ba,1d0,1,4.18d0,r)
 if(r%produced)error stop 'missing initial macro temperature'
 initial=.true.;w1(1,1)=2d0
 call advance_macro_liquid_thermal(w0,w1,q,x,sink,t0,initial,tm0,tm1,ma,tt0,tt1,ta,bt,bt,ba,1d0,1,4.18d0,r)
 if(r%produced)error stop 'invalid water ledger'
 ! Closed liquid transfer: use the independent production storage owner on both reservoirs.
 call initialize_liquid_water_sensible_enthalpy_parameters(1000d0,4180d0,0d0,liquid,status)
 if(status/=LWSE_OK)error stop 'liquid properties'
 w0=1d0;w1=1d0;w1(1,1)=.9d0;q=0d0;x=0d0;x(1,1)=.1d0;t0=20d0
 call advance_macro_liquid_thermal(w0,w1,q,x,sink,t0,initial,tm0,tm1,ma,tt0,tt1,ta,bt,bt,ba,1d0,16,4.18d0,r)
 if(.not.r%produced)error stop 'closed donor transfer'
 call liquid_water_sensible_storage_j_m2(1d0,10d0,liquid,matrix_before,status)
 call liquid_water_sensible_storage_j_m2(1d0,20d0,liquid,macro_before,status)
 matrix_after=matrix_before+1d4*r%matrix_energy_j_cm2(1,1)
 call liquid_water_sensible_storage_j_m2(1.1d0,matrix_after/(1.1d0*41800d0),liquid,stored,status)
 if(abs(stored-matrix_after)>1d-9)error stop 'matrix transfer materialization'
 call liquid_water_sensible_storage_j_m2(.9d0,r%temperature_c(1,1),liquid,macro_after,status)
 if(abs(matrix_after+macro_after-matrix_before-macro_before)>1d-9)error stop 'closed independent liquid energy'
 write(*,'(a)')'CLOSED_MATRIX_MACRO_TRANSFER_REAL_LIQUID_STORAGE_OWNER_PASS'
 write(*,'(a)')'MACRO_THERMAL_MIXING_DONOR_TIME_REFINEMENT_DRY_CONDUIT_AND_MISSING_DATA_REFUSALS_PASS'
end program
