program conservative_heat_driver
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_linear_mixture_sensible_storage,only:initialize_linear_mixture_sensible_storage_parameters,LMSS_OK
 use mod_conservative_soil_heat_trial
 implicit none
 type(conservative_heat_request_t)::r,copy
 type(conservative_heat_result_t)::answer,rebased
 integer::scenario,gauge,i,status,unit
 real(real64)::reference,tbase(3),nan
 character(2048)::path
 call get_command_argument(1,path);open(newunit=unit,file=trim(path),status='replace')
 nan=ieee_value(0d0,ieee_quiet_nan)
 do scenario=1,5
  do gauge=0,1
   reference=5d0*gauge;call setup(scenario,reference)
   copy=r
   call trial_conservative_soil_heat(r,answer)
   if(answer%status/=CH_OK.or..not.answer%produced.or..not.answer%sensible_scope_complete) &
    error stop 'conservative physical trial failed'
   if(answer%full_swap_energy_balance_complete)error stop 'full SWAP energy overclaim'
   if(any(r%theta_start/=copy%theta_start).or.any(r%temperature_start_c/=copy%temperature_start_c)) &
    error stop 'trial changed committed physical inputs'
   if(gauge==0)tbase=answer%temperature_c
   if(maxval(abs(tbase-answer%temperature_c))>3d-14)error stop 'physical temperature depends on energy gauge'
   if(scenario==1.or.scenario==2)then
    if(maxval(abs(answer%temperature_c-10d0))>3d-14)error stop 'isothermal phase replacement not invariant'
   end if
   write(unit,'(a,2(a,i0),6(a,es25.17e3))')'CASE',',',scenario,',',gauge, &
    ',',answer%storage_change_j_cm2,',',answer%external_energy_into_j_cm2,',',answer%residual_j_cm2, &
    ',',answer%root_energy_out_j_cm2,',',answer%water_source_energy_into_j_cm2, &
    ',',answer%gas_source_energy_into_j_cm2
   do i=1,3
    write(unit,'(a,3(a,i0),a,es25.17e3)')'TEMP',',',scenario,',',gauge,',',i,',',answer%temperature_c(i)
   end do
   do i=1,4
    write(unit,'(a,3(a,i0),2(a,es25.17e3))')'FACE',',',scenario,',',gauge,',',i, &
     ',',answer%water_face_energy_j_cm2(i),',',answer%gas_face_energy_j_cm2(i)
   end do
  end do
 end do
 ! Required donor attacks and unavailable heat must produce no candidate.
 call setup(3,0d0);r%water_boundary_available(1)=.false.;call reject(CH_MISSING_DONOR)
 call setup(3,0d0);r%water_boundary_temperature_c(1)=nan;call reject(CH_MISSING_DONOR)
 call setup(4,0d0);r%water_boundary_available(2)=.false.;call reject(CH_MISSING_DONOR)
 call setup(3,0d0);r%gas_boundary_available(2)=.false.;call reject(CH_MISSING_DONOR)
 call setup(3,0d0);r%gas_source_available(1)=.false.;call reject(CH_MISSING_DONOR)
 call setup(3,0d0);r%boundary_heat_available(2)=.false.;call reject(CH_MISSING_HEAT)
 call setup(3,0d0);r%water_face_cm(2)=r%water_face_cm(2)+1d-4;call reject(CH_WATER_BALANCE)
 call setup(3,0d0);r%gas_face_cm(2)=r%gas_face_cm(2)+1d-4;call reject(CH_GAS_BALANCE)
 call setup(3,0d0);r%phase_change_active=.true.;call reject(CH_UNSUPPORTED_PHASE)
 call setup(3,0d0);r%vapor_active=.true.;call reject(CH_UNSUPPORTED_PHASE)
 call setup(3,0d0);r%boundary_heat_into_j_cm2=-1d5;call reject(CH_UNSUPPORTED_PHASE)
 call setup(3,0d0);r%water_source_available(2)=.false.;call reject(CH_MISSING_DONOR)
 call setup(3,0d0);deallocate(r%gas_face_cm);call reject(CH_INVALID)
 call setup(3,0d0);r%root_water_out_cm(1)=-1d-3;call reject(CH_INVALID)
 ! Reverse flow uses the soil-side donor, not an external inflow temperature.
 call setup(4,0d0);r%water_boundary_available(1)=.false.;r%water_boundary_temperature_c(1)=nan
 call trial_conservative_soil_heat(r,answer)
 if(answer%status/=CH_OK)error stop 'outflow incorrectly consumed unavailable external inflow donor'
 call setup(5,0d0)
 r%water_boundary_available=.false.;r%gas_boundary_available=.false.
 r%water_boundary_temperature_c=nan;r%gas_boundary_temperature_c=nan
 r%water_source_temperature_c=nan;r%gas_source_temperature_c=nan
 call trial_conservative_soil_heat(r,answer)
 if(answer%status/=CH_OK)error stop 'exact zero transport incorrectly requires a donor'
 close(unit)
 print '(a)','CONSERVATIVE_WARM_HEAT_TRANSPORT_PASS_FULL_SWAP_ENERGY_OPEN'
contains
 subroutine setup(case_id,ref)
  integer,intent(in)::case_id
  real(real64),intent(in)::ref
  integer::j,local_status
  r=conservative_heat_request_t()
  allocate(r%material(3))
  do j=1,3
   call initialize_linear_mixture_sensible_storage_parameters(.45d0,1.2d0,4.18d0,.001212d0, &
    ref,r%material(j),local_status)
   if(local_status/=LMSS_OK)error stop 'production stock parameter initialization'
  end do
  r%dz_cm=[1d0,2d0,3d0];r%theta_start=[.2d0,.25d0,.3d0]
  r%temperature_start_c=[10d0,10d0,10d0]
  r%water_face_cm=[.01d0,.008d0,.006d0,.004d0]
  if(case_id==4)r%water_face_cm=-r%water_face_cm
  r%gas_face_cm=-r%water_face_cm
  r%root_water_out_cm=[.001d0,.002d0,.001d0]
  r%water_external_cm=[0d0,.003d0,0d0]
  r%gas_external_cm=r%root_water_out_cm-r%water_external_cm
  if(case_id==2)then
   r%water_face_cm=0d0;r%gas_face_cm=0d0;r%water_external_cm=0d0
   r%gas_external_cm=r%root_water_out_cm
  end if
  if(case_id==5)then
   r%water_face_cm=0d0;r%gas_face_cm=0d0;r%root_water_out_cm=0d0
   r%water_external_cm=0d0;r%gas_external_cm=0d0
   r%temperature_start_c=[5d0,10d0,20d0]
  end if
  r%theta_end=r%theta_start+(r%water_face_cm(:3)-r%water_face_cm(2:)+ &
   r%water_external_cm-r%root_water_out_cm)/r%dz_cm
  r%water_boundary_temperature_c=[10d0,10d0];r%gas_boundary_temperature_c=[10d0,10d0]
  r%water_source_temperature_c=[10d0,10d0,10d0];r%gas_source_temperature_c=[10d0,10d0,10d0]
  r%water_boundary_available=.true.;r%gas_boundary_available=.true.
  r%water_source_available=[.true.,.true.,.true.];r%gas_source_available=[.true.,.true.,.true.]
  r%internal_conductance_j_cm2_k=[.4d0,.2d0]
  r%boundary_heat_available=.true.;r%boundary_heat_into_j_cm2=0d0
  if(case_id==3.or.case_id==4)then
   r%water_boundary_temperature_c=[20d0,30d0];r%gas_boundary_temperature_c=[8d0,7d0]
   r%water_source_temperature_c=[12d0,15d0,18d0];r%gas_source_temperature_c=[6d0,7d0,8d0]
   r%boundary_heat_into_j_cm2=[.1d0,-.03d0]
  end if
 end subroutine
 subroutine reject(expected)
  integer,intent(in)::expected
  call trial_conservative_soil_heat(r,answer)
  if(answer%status/=expected.or.answer%produced.or.allocated(answer%temperature_c)) &
   error stop 'invalid physical trial published candidate or wrong refusal'
  write(unit,'(a,a,i0)')'REFUSAL',',',expected
 end subroutine
end program
