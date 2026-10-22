 subroutine native_output_source_proof(plan0,policy0,base_day,water_fraction)
  type(soil_n_amendment_calendar_t),intent(in)::plan0
  type(crop_senescence_policy_t),intent(in)::policy0
  real(real64),intent(in)::base_day,water_fraction
  type(soil_n_amendment_calendar_t)::plan1,rejected_plan
  type(crop_senescence_policy_t)::policy1,rejected_policy
  type(crop_soil_state_t)::actual,ordinary,rejected
  type(kernel_committed_state_t)::aw,ow
  type(reactive_state_t)::source_soil
  type(wofost81_crop_owner_state_t)::source_crop
  type(reactive_parameters_t)::source_parameters
  type(crop_n_configuration_t)::source_configuration
  type(soil_n_historical_selection_t)::selection
  type(crop_ext_state_t)::diagnostic,guard
  type(crop_ext_row_t),allocatable::rows(:),rejected_rows(:)
  character(10),allocatable::dates(:),rejected_dates(:)
  type(soil_n_material_input_t),allocatable::batch(:)
  type(soil_n_day_environment_t)::environment
  type(senescence_joint_result_t)::r,ordinary_result
  character(512)::line
  character(10)::date
  real(real64)::v(17),g(17),mass
  integer(int64)::identity
  integer::unit,copy_unit,io,code,error_line,day,first_day
  logical::ready,guard_ready,captured
  selection%swcropsnm=1;selection%sw_wofost=1;selection%source_parameters_complete=.true.
  open(newunit=unit,file='source-crop-startup.snm',status='old')
  open(newunit=copy_unit,file='native-output.snm',status='replace')
  do
   read(unit,'(A)',iostat=io)line
   if(io/=0)exit
   if(index(line,'flCropExt =')==1)line='flCropExt = .TrUe.'
   write(copy_unit,'(A)')trim(line)
  end do
  close(unit);close(copy_unit)
  ! Existing startup remains closed to TRUE without an output-aware caller.
  call initialize_historical_crop_soil_owner(selection,sp,cp,crop,9001_int64,9101_int64, &
   base_day,water_fraction,'native-output.snm','1900-12-30',rejected_plan,rejected,rejected_policy,code,error_line)
  call require(code/=0.and..not.rejected%ready().and..not.rejected_plan%ready(),'old TRUE startup remains rejected')
  ! Even a successfully parsed request must not escape a failed physical startup.
  captured=.true.;selection%swcropsnm=0
  call initialize_historical_crop_soil_owner(selection,sp,cp,crop,9001_int64,9101_int64, &
   base_day,water_fraction,'native-output.snm','1900-12-30',rejected_plan,rejected,rejected_policy, &
   code,error_line,extended_output=captured)
  call require(code/=0.and..not.captured,'invalid selection clears captured request')
  selection%swcropsnm=1
  call initialize_crop_ext(99d0,guard,code)
  diagnostic=guard
  call initialize_historical_crop_soil_output_owner(selection,sp,cp,crop,9001_int64,9101_int64, &
   base_day,water_fraction,'source-crop-startup.snm','1900-12-30',rejected_plan,rejected, &
   rejected_policy,diagnostic,rejected_dates,rejected_rows,code,error_line)
  call diagnostic%snapshot(v(1),v(2:9),v(10:17),ready)
  call guard%snapshot(g(1),g(2:9),g(10:17),guard_ready)
  call require(code/=0.and.all(v==g).and..not.rejected%ready().and..not.allocated(rejected_rows) &
   .and..not.allocated(rejected_dates),'disabled startup preserves all caller output authority')
  call initialize_historical_crop_soil_output_owner(selection,sp,cp,crop,9001_int64,9101_int64, &
   base_day,water_fraction,'native-output.snm','1900-12-30',plan1,actual,policy1,diagnostic,dates,rows,code,error_line)
  if(code/=0)print *,'native output startup failed',code,error_line
  call require(code==0.and.actual%ready().and.plan1%ready().and.size(rows)==0,'actual native TRUE startup')
  aw=water;ow=water;ordinary=state
  call write_crop_soil_n_joint_restart_file(trim(endpoint)//'.initial-true',column,cfg%tiles(1)%template, &
   670001_int64,aw,actual,code);call require(code==0,'native TRUE initial bytes')
  call write_crop_soil_n_joint_restart_file(trim(endpoint)//'.initial-false',column,cfg%tiles(1)%template, &
   670001_int64,ow,ordinary,code);call require(code==0,'native FALSE initial bytes')
  call state%configuration(source_configuration,identity)
  call state%snapshot(source_soil,source_crop);call source_soil%configuration(source_parameters,identity)
  first_day=0
  if(trim(mode)=='native-output-resume')then
   aw=kernel_committed_state_t();actual=crop_soil_state_t()
   call read_crop_n_output_generation(trim(path),column,cfg%tiles(1)%template,670001_int64,9001_int64, &
    9101_int64,source_parameters,source_configuration,aw,actual,diagnostic,dates,rows,code)
   call require(code==0.and.size(rows)==0,'native independent-process first-day generation')
   first_day=1
   ! Ordinary reference advances freshly to the same first-day state.
   environment=soil_n_day_environment_t(base_day,base_day+1d0,5d0)
   call run_crop_soil_n_calendar_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters, &
    ow,cfg%tiles(1)%base_forcing,cfg%numerical,ordinary,weather,base_day,base_day+1d0,plan0,split,policy0, &
    ordinary_result,environment)
   call require(ordinary_result%status==JOINT_OK,'ordinary fresh first-day reference')
  end if
  do day=first_day,1
   environment=soil_n_day_environment_t(base_day+real(day,real64),base_day+real(day+1,real64),merge(5d0,30d0,day==0))
   call select_calendar_material_batch(plan1,base_day+real(day,real64),base_day+real(day+1,real64),batch,code)
   call require(code==0,'native material calendar batch')
   date='1900-12-31';if(day==1)date='1901-01-01'
   call run_crop_soil_n_output_day(trim(path),date,day==1,670001_int64,backend,column,cfg%tiles(1)%template, &
    cfg%tiles(1)%parameters,aw,cfg%tiles(1)%base_forcing,cfg%numerical,actual,weather, &
    base_day+real(day,real64),base_day+real(day+1,real64),batch,split,policy1,diagnostic,dates,rows,r,code, &
    environment,trim(endpoint)//'.csv')
   if(code/=0)print *,'native output day failed',day,code,r%status
   call require(code==OUTPUT_DAY_OK,'native output accepted actual Richards day')
   call require(abs(r%senescence%whole_n_residual)<=1d-12.and.abs(r%joint%joint%chemical%whole_n_residual)<=1d-12, &
    'native output hard soil crop pending N balance')
   call require(r%joint%joint%diagnostics%max_abs_step_mass_residual<=HARD_MASS_GATE,'native output hard water balance')
   call run_crop_soil_n_calendar_interval(second,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters, &
    ow,cfg%tiles(1)%base_forcing,cfg%numerical,ordinary,weather,base_day+real(day,real64), &
    base_day+real(day+1,real64),plan0,split,policy0,ordinary_result,environment)
   call require(ordinary_result%status==JOINT_OK,'ordinary FALSE physical day')
   if(day==0)then
    call write_crop_n_output_generation(trim(path)//'.day1',column,cfg%tiles(1)%template, &
     670001_int64,aw,actual,diagnostic,dates,rows,code)
    call require(code==0,'first-day joint native generation saved')
   end if
  end do
  call require(size(rows)==1.and.dates(1)=='1901-01-01','native year-boundary report history')
  call write_crop_soil_n_joint_restart_file(trim(endpoint)//'.true',column,cfg%tiles(1)%template, &
   670001_int64,aw,actual,code);call require(code==0,'native TRUE endpoint')
  call write_crop_soil_n_joint_restart_file(trim(endpoint)//'.false',column,cfg%tiles(1)%template, &
   670001_int64,ow,ordinary,code);call require(code==0,'native FALSE endpoint')
  call write_crop_n_output_generation(trim(endpoint),column,cfg%tiles(1)%template,670001_int64, &
   aw,actual,diagnostic,dates,rows,code);call require(code==0,'native complete endpoint')
  call initialize_historical_crop_soil_output_owner(selection,sp,cp,crop,9001_int64,9101_int64, &
   base_day,water_fraction,'native-output.snm','1900-12-30',plan1,actual,policy1,diagnostic,dates,rows,code,error_line)
  call require(code/=0,'native live-run reinitialization rejected')
  call write_crop_n_output_generation(trim(endpoint)//'.after-rejected-start',column,cfg%tiles(1)%template, &
   670001_int64,aw,actual,diagnostic,dates,rows,code);call require(code==0,'rejected start leaves complete authority')
  print '(A)','NATIVE_TRUE_OUTPUT_ACTUAL_RICHARDS_BALANCE_RESTART=PASS'
 end subroutine
