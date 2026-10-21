program test_humus_timestamp
 use iso_fortran_env,only:real64
 use mod_soil_n_unified_input
 use mod_soil_n_historical_activation
 use mod_soil_n_amendment_calendar
 implicit none
 type(soil_n_amendment_calendar_t)::plan
 type(soil_n_historical_initial_t)::initial
 type(soil_n_historical_rates_t)::rates
 character(512)::path,arg
 real(real64)::expected
 integer::code,line,u,n,ios
 call get_command_argument(1,path);call get_command_argument(2,arg);read(arg,*)expected
 call read_soil_n_snm_keyword_file(trim(path),'1900-12-30',plan,initial,rates,code,line)
 if(expected<0d0)then
  if(code==0.or.plan%ready().or.initial%hum_kg_m3/=0d0)error stop 'non-atomic timestamp rejection'
  open(newunit=u,file=trim(path),status='old');n=0
  do
   read(u,'(A)',iostat=ios)arg
   if(ios/=0)exit
   n=n+1
  end do
  close(u)
  if(line/=n)error stop 'timestamp physical line'
  print '(A)','TIMESTAMP_ATOMIC_INVALID=PASS'
 else
  if(code/=0.or..not.plan%ready())then
   print *,code,line
   error stop 'timestamp rejected'
  end if
  if(abs(rates%hum_exp_start_day-expected)>4d0*spacing(max(1d0,expected)))error stop 'timestamp interpretation'
  if(rates%hum_exp_per_year/=.1d0)error stop 'source rate'
  print '(A,ES26.17)','CLOCK=',rates%hum_exp_start_day
  print '(A)','TIMESTAMP_NATIVE_SOURCE=PASS'
 end if
end program
