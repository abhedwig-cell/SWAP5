 ! Compose the existing immutable calendar and accepted-temperature output owners.
 subroutine thermal_calendar_proof()
  type(soil_n_amendment_calendar_t)::plan,invalid_plan
  type(b111_soil_n_material_t)::definitions(3)
  type(soil_n_material_input_t),allocatable::batch(:)
  type(kernel_committed_state_t)::aw,mw,before_water
  type(crop_soil_state_t)::ac,mc,before_soil
  type(crop_ext_state_t)::d,manual
  type(crop_ext_row_t)::row
  type(crop_ext_row_t),allocatable::rows(:),manual_rows(:)
  character(10),allocatable::dates(:),manual_dates(:)
  type(senescence_joint_result_t)::r,mr
  type(fmr_b110_physical_forcing_t)::forcing,bad_forcing
  character(512)::argument
  character(10)::date
  character(1)::tag
  real(real64)::tbegin,tend
  integer::code,schedule,day,start_day
  logical::ready,report
  definitions(1)=items(1)%material;definitions(2)=items(1)%material;definitions(3)=items(2)%material
  definitions%application_kg_m2=0d0
  call create_soil_n_amendment_calendar(0d0,[0d0,2d0,2d0],[10d0,20d0,30d0],definitions,plan,code)
  call require(code==N_CALENDAR_OK,'thermal calendar construction')
  call get_command_argument(5,argument);read(argument,*)schedule
  allocate(rows(0),dates(0));start_day=0
  if(trim(mode)=='calendar-new')then
   aw=initial_water;ac=initial_state
   call initialize_crop_ext(0d0,d,code);call require(code==0,'calendar diagnostic initialize')
  else
   call read_crop_n_output_generation(trim(path),column,cfg%tiles(1)%template,670001_int64,9001_int64, &
    9101_int64,sp,cp,aw,ac,d,dates,rows,code,cfg%tiles(1)%parameters)
   call require(code==0,'calendar fresh complete heat reconstruction')
  end if
  if(trim(mode)/='calendar-new')then
   block
    real(real64)::v(17)
    call d%snapshot(v(1),v(2:9),v(10:17),ready)
    call require(ready.and.v(1)==anint(v(1)),'calendar resumed accepted day clock')
    start_day=int(v(1))
   end block
  end if
  mw=aw;mc=ac;manual=d;manual_dates=dates;manual_rows=rows
  if(trim(mode)=='calendar-roundtrip')then
   call save_output_authority(trim(endpoint),aw,ac,d,dates,rows)
   return
  end if
  call save_output_authority(trim(endpoint)//'.initial',aw,ac,d,dates,rows)
  do day=start_day,2
   tag=achar(48+day);tbegin=real(day,real64);tend=tbegin+1d0
   date='1900-12-31';if(day==1)date='1901-01-01'
   if(day==2)date='1901-01-02'
   report=day==2.or.(schedule==1.and.day==1)
   forcing=cfg%tiles(1)%base_forcing
   forcing%soil_temperature%prescribed_surface_temperature_c=10d0+10d0*day
   call select_calendar_material_batch(plan,tbegin,tend,batch,code)
   call require(code==0.and.size(batch)==merge(1,merge(0,2,day==1),day==0),'calendar gift empty simultaneous census')
   if(day==2)then
    call require(batch(1)%material%application_kg_m2==20d0*1d-4.and. &
     batch(2)%material%application_kg_m2==30d0*1d-4,'ordered calendar kg per hectare conversion')
   end if
   call save_output_authority(trim(endpoint)//'.before-'//tag,aw,ac,d,dates,rows)
   call run_crop_soil_n_calendar_output_day(trim(endpoint),date,report,670001_int64,backend,column, &
    cfg%tiles(1)%template,cfg%tiles(1)%parameters,aw,forcing,cfg%numerical,ac,weather, &
    tbegin,tend,invalid_plan,split,policy,d,dates,rows,r,code)
   call require(code==OUTPUT_DAY_INVALID,'invalid heat calendar rejects')
   call run_crop_soil_n_calendar_output_day(trim(endpoint),date,report,670001_int64,backend,column, &
    cfg%tiles(1)%template,cfg%tiles(1)%parameters,aw,forcing,cfg%numerical,ac,weather, &
    tbegin+.5d0,tend+.5d0,plan,split,policy,d,dates,rows,r,code)
   call require(code==OUTPUT_DAY_INVALID,'off-grid heat calendar rejects')
   call run_crop_soil_n_calendar_output_day(trim(endpoint),date,report,670001_int64,backend,column, &
    cfg%tiles(1)%template,cfg%tiles(1)%parameters,aw,forcing,cfg%numerical,ac,weather, &
    tbegin,tend,plan,split,policy,d,dates,rows,r,code,environment=env)
   call require(code==OUTPUT_DAY_INVALID,'calendar cannot override accepted soil temperature')
   bad_forcing=forcing;bad_forcing%root_extraction_sink=-1d0
   call run_crop_soil_n_calendar_output_day(trim(endpoint),date,report,670001_int64,backend,column, &
    cfg%tiles(1)%template,cfg%tiles(1)%parameters,aw,bad_forcing,cfg%numerical,ac,weather, &
    tbegin,tend,plan,split,policy,d,dates,rows,r,code)
   call require(code/=OUTPUT_DAY_OK,'calendar water rejection retains gift')
   call run_crop_soil_n_calendar_output_day('missing-thermal-calendar/generation',date,report,670001_int64, &
    backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,aw,forcing,cfg%numerical,ac,weather, &
    tbegin,tend,plan,split,policy,d,dates,rows,r,code)
   call require(code==OUTPUT_DAY_SAVE_FAILED,'calendar late save failure retains gift')
   call save_output_authority(trim(endpoint)//'.after-'//tag,aw,ac,d,dates,rows)
   before_water=mw;before_soil=mc
   call run_crop_soil_n_thermal_interval(second,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters, &
    mw,forcing,cfg%numerical,mc,weather,tbegin,tend,batch,split,policy,mr)
   call require(mr%status==JOINT_OK,'ordinary thermal calendar physical day')
   call observe_accepted_crop_soil_n_day(manual,before_water,before_soil,mw,mc,mr,tbegin,tend, &
    report,row,code,thermal=.true.)
   call require(code==0,'independent thermal calendar diagnostic')
   if(report)then
    manual_dates=[character(10)::manual_dates,date];manual_rows=[manual_rows,row]
   end if
   call run_crop_soil_n_calendar_output_day(trim(endpoint),date,report,670001_int64,backend,column, &
    cfg%tiles(1)%template,cfg%tiles(1)%parameters,aw,forcing,cfg%numerical,ac,weather, &
    tbegin,tend,plan,split,policy,d,dates,rows,r,code,csv_path=trim(endpoint)//'.csv')
   if(code/=0)print *,'calendar accepted',day,code,r%status
   call require(code==OUTPUT_DAY_OK.and.diagnostic_equal(d,manual),'accepted thermal calendar diagnostic equality')
   call require(r%joint%joint%chemical%soil%temperature_used_c==accepted_literal_temperature(aw,tbegin,tend), &
    'calendar uses accepted literal soil temperature')
   call require(abs(r%senescence%whole_n_residual)<=1d-12,'calendar hard whole nitrogen gate')
   call require(r%joint%joint%diagnostics%max_abs_step_mass_residual<=HARD_MASS_GATE,'calendar hard water gate')
   call save_output_authority(trim(endpoint)//'.day-'//tag,aw,ac,d,dates,rows)
   call save_output_authority(trim(endpoint)//'.manual-'//tag,mw,mc,manual,manual_dates,manual_rows)
   call run_crop_soil_n_calendar_output_day(trim(endpoint),date,report,670001_int64,backend,column, &
    cfg%tiles(1)%template,cfg%tiles(1)%parameters,aw,forcing,cfg%numerical,ac,weather, &
    tbegin,tend,plan,split,policy,d,dates,rows,r,code)
   call require(code==OUTPUT_DAY_INVALID,'accepted calendar day cannot apply gifts twice')
   call save_output_authority(trim(endpoint)//'.replay-'//tag,aw,ac,d,dates,rows)
  end do
  call write_crop_soil_n_joint_restart_file(trim(endpoint)//'.physical',column,cfg%tiles(1)%template, &
   670001_int64,aw,ac,code);call require(code==0,'calendar physical endpoint')
  call require(size(rows)==merge(2,1,schedule==1),'thermal calendar report schedule')
  print '(A)','THERMAL_CALENDAR_OUTPUT=PASS'
 end subroutine
