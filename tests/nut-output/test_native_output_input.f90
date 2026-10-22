program test_native_output_input
 use iso_fortran_env,only:real64
 use mod_soil_n_unified_input
 use mod_soil_n_historical_activation
 use mod_soil_n_amendment_calendar
 implicit none
 type(soil_n_amendment_calendar_t)::plan
 type(soil_n_historical_initial_t)::initial
 type(soil_n_historical_rates_t)::rates
 integer::status,line,expected,mode
 logical::requested
 character(512)::path,arg
 call get_command_argument(1,path);call get_command_argument(2,arg);read(arg,*)expected
 call get_command_argument(3,arg);read(arg,*)mode
 requested=.true.
 if(mode==0)then
  call read_soil_n_snm_keyword_file(trim(path),'1900-12-30',plan,initial,rates,status,line)
 else
  call read_soil_n_unified_export(trim(path),'1900-12-30',plan,initial,rates,status,line,extended_output=requested)
 end if
 if(expected<0)then
  if(status==0.or.plan%ready())error stop 'invalid native output input accepted'
  if(mode/=0.and.requested)error stop 'failed input leaked output request'
  if(any(initial%fom_kg_m3/=0d0).or.initial%hum_kg_m3/=0d0)error stop 'failed input leaked inventory'
 else
  if(status/=0.or..not.plan%ready())then
   print *,status,line;error stop 'valid native output input rejected'
  end if
  if(mode/=0.and.(requested.neqv.(expected==1)))error stop 'wrong output request'
  if(any(initial%fom_kg_m3/=1d0).or.initial%hum_kg_m3/=40d0)error stop 'output changed nutrient input'
 end if
 print '(A)','NATIVE_OUTPUT_REQUEST_CONTRACT=PASS'
end program
