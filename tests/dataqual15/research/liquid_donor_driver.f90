program liquid_donor_driver
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_liquid_water_sensible_enthalpy
 implicit none
 type(liquid_water_sensible_enthalpy_parameters_t)::p
 real(real64)::amount,temp,oracle,energy,total,reverse,nan
 integer::status,io,n
 character(2048)::path
 call get_command_argument(1,path)
 call initialize_liquid_water_sensible_enthalpy_parameters(1000d0,4180d0,0d0,p,status)
 if(status/=LWSE_OK)error stop 'properties'
 open(10,file=trim(path),status='old');n=0;total=0d0
 do
  read(10,*,iostat=io)amount,temp,oracle
  if(io<0)exit
  if(io/=0)error stop 'donor input'
  call evaluate_liquid_water_sensible_transport(amount,temp,p,energy,status)
  if(status/=LWSE_OK.or.abs(energy/1d4-oracle)>1d-12*max(1d0,abs(oracle)))error stop 'actual donor energy'
  call evaluate_liquid_water_sensible_transport(-amount,temp,p,reverse,status)
  if(status/=LWSE_OK.or.reverse/=-energy)error stop 'signed donor orientation'
  total=total+energy/1d4;n=n+1
 end do
 close(10)
 nan=ieee_value(0d0,ieee_quiet_nan)
 call evaluate_liquid_water_sensible_transport(1d0,nan,p,energy,status)
 if(status/=LWSE_INVALID_TRANSPORT_INPUT)error stop 'missing donor accepted'
 call evaluate_liquid_water_sensible_transport(nan,20d0,p,energy,status)
 if(status/=LWSE_INVALID_TRANSPORT_INPUT)error stop 'missing transport accepted'
 write(*,'(a,i0,a,es25.17e3)')'ACTUAL_ENDPOINT_MEAN_DONOR_SCENARIOS=',n,',J_CM2=',total
 write(*,'(a)')'REVERSE_SIGN_AND_UNKNOWN_DONOR_CONTROLS_PASS_FULL_PHYSICAL_ENERGY_OPEN'
end program
