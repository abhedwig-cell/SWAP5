! Diagnostic reproducer: this proves an open dependency, not TCS6 qualification.
program weather_domain
 use iso_fortran_env,only:real64,int64
 use mod_swap_daily_weather_file_adapter
 use mod_wofost_prepare_assimilation
 use mod_wofost_one_day_rate_state_view
 use mod_wofost_rate_parameters
 use mod_wofost_rate_table
 implicit none
 type(swap_daily_weather_record_t)::record
 type(wofost_rate_parameter_bundle_t)::bundle
 type(wofost_one_day_rate_state_view_t)::view
 type(wofost_prepare_assimilation_forcing_t)::forcing
 type(wofost_prepare_assimilation_result_t)::result
 character(1024)::path
 character(24)::mode
 integer::st,iday,i
 real(real64)::rad,solar(6),values(7)
 logical::ok
 call get_command_argument(1,path)
 call read_swap_daily_weather_file(trim(path),1999,1,29,record,st)
 call require(st==SWAP_WEATHER_FILE_OK,'actual existing weather adapter accepts29Jan1999')
 call record%growth_values(52._real64,iday,rad,solar,ok)
 call require(ok.and.rad==5267700._real64,'actual source5267.7kJ ->5267700J')
 call make_bundle(bundle)
 view%actual_leaf_area_index=.14_real64
 forcing%global_radiation=rad;forcing%daylength_hours=solar(1)
 forcing%sine_solar_height_offset=solar(3);forcing%sine_solar_height_amplitude=solar(4)
 forcing%diffuse_irradiation_perpendicular=solar(5);forcing%daily_effective_solar_height=solar(6)
 call get_command_argument(2,mode)
 do i=1,7
  values=[0._real64,1._real64,5.e6_real64,5267700._real64,5.e9_real64,-1._real64,5.e9_real64+1._real64]
  forcing%global_radiation=values(i)
  call prepare_wofost_actual_assimilation(view,bundle,forcing,result,st)
  if(i<=3.or.(trim(mode)=='corrected'.and.i<=5))then
   call require(st==WOFOST_PREPARE_ASSIMILATION_OK,'source-unit admitted radiation')
   call require(result%actual_pgass>=0._real64,'finite nonnegative production assimilation')
   if(i<=3)write(*,'(a,i0,1x,z16.16)')'ORIGINAL_DOMAIN_BITS=',i,transfer(result%actual_pgass,0_int64)
  else
   call require(st==WOFOST_PREPARE_ASSIMILATION_INVALID_FORCING,'outside declared source/input domain')
  end if
  call require(forcing%global_radiation==values(i),'production input nonmutation')
 end do
 print '(a)','TCS6_SHARED_CROP_SOURCE_UNIT_DOMAIN=PASS'

contains
! INSERT_EXISTING_HELPERS
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then
   print *,label
   error stop 1
  end if
 end subroutine
end program
