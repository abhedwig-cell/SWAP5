 subroutine save_output_authority(name,w,n,d,dates,rows)
  character(*),intent(in)::name
  type(kernel_committed_state_t),intent(in)::w
  type(crop_soil_state_t),intent(in)::n
  type(crop_ext_state_t),intent(in)::d
  character(10),intent(in)::dates(:)
  type(crop_ext_row_t),intent(in)::rows(:)
  integer::code
  call write_crop_n_output_generation(name,column,cfg%tiles(1)%template,670001_int64,w,n,d,dates,rows,code)
  call require(code==0,'thermal complete output authority saved')
 end subroutine
 logical function diagnostic_equal(a,b)result(equal)
  type(crop_ext_state_t),intent(in)::a,b
  real(real64)::x(17),y(17)
  logical::ax,by
  call a%snapshot(x(1),x(2:9),x(10:17),ax)
  call b%snapshot(y(1),y(2:9),y(10:17),by)
  equal=(ax.eqv.by).and.all(transfer(x,[0_int64],17)==transfer(y,[0_int64],17))
 end function
 subroutine first_output_day()
  type(kernel_committed_state_t)::w
  type(crop_soil_state_t)::n
  type(crop_ext_state_t)::d,manual
  type(crop_ext_row_t)::row
  type(crop_ext_row_t),allocatable::rows(:)
  character(10),allocatable::dates(:)
  type(senescence_joint_result_t)::r
  integer::code
  allocate(dates(0),rows(0));w=initial_water;n=initial_state
  call initialize_crop_ext(0d0,d,code);call require(code==0,'thermal diagnostic initialize')
  call save_output_authority(trim(path)//'.generation.zero',w,n,d,dates,rows)
  call save_output_authority(trim(path)//'.generation',w,n,d,dates,rows)
  call run_crop_soil_n_output_day(trim(path)//'.generation','1900-01-02',.false.,670001_int64,backend,column, &
   cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,cfg%tiles(1)%base_forcing,cfg%numerical,n,weather, &
   0d0,1d0,items,split,policy,d,dates,rows,r,code,environment=env)
  call require(code==OUTPUT_DAY_INVALID,'competing prescribed thermal environment rejected')
  call save_output_authority(trim(path)//'.environment-after',w,n,d,dates,rows)
  call run_crop_soil_n_output_day(trim(path)//'.generation','1900-01-02',.false.,670001_int64,backend,column, &
   cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,cfg%tiles(1)%base_forcing,cfg%numerical,n,weather, &
   0d0,1d0,bad_items,split,policy,d,dates,rows,r,code)
  call require(code/=OUTPUT_DAY_OK,'thermal rejected material does not publish output')
  call save_output_authority(trim(path)//'.material-after',w,n,d,dates,rows)
  call run_crop_soil_n_output_day('missing-thermal-output/generation','1900-01-02',.false.,670001_int64,backend,column, &
   cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,cfg%tiles(1)%base_forcing,cfg%numerical,n,weather, &
   0d0,1d0,items,split,policy,d,dates,rows,r,code)
  call require(code==OUTPUT_DAY_SAVE_FAILED,'thermal late save failure exposed')
  call save_output_authority(trim(path)//'.save-failed-after',w,n,d,dates,rows)
  call run_crop_soil_n_output_day(trim(path)//'.generation','1900-01-02',.false.,670001_int64,backend,column, &
   cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,cfg%tiles(1)%base_forcing,cfg%numerical,n,weather, &
   0d0,1d0,items,split,policy,d,dates,rows,r,code)
  if(code/=0)print *,'thermal output first day',code,r%status
  call require(code==OUTPUT_DAY_OK.and.size(rows)==0,'actual first thermal nonreport generation')
  call require(r%joint%joint%chemical%soil%temperature_used_c==accepted_literal_temperature(w,0d0,1d0), &
   'thermal output uses accepted literal temperature')
  call require(abs(r%senescence%whole_n_residual)<=1d-12,'thermal output whole N gate')
  call require(r%joint%joint%diagnostics%max_abs_step_mass_residual<=HARD_MASS_GATE,'thermal output water gate')
  call initialize_crop_ext(0d0,manual,code)
  call observe_accepted_crop_soil_n_day(manual,initial_water,initial_state,water,state,result, &
   0d0,1d0,.false.,row,code,thermal=.true.)
  call require(code==0.and.diagnostic_equal(d,manual),'thermal automatic and manual diagnostics exact')
  call write_crop_soil_n_joint_restart_file(trim(path)//'.automatic-inner',column,cfg%tiles(1)%template, &
   670001_int64,w,n,code);call require(code==0,'automatic thermal physical first day')
  call write_crop_soil_n_joint_restart_file(trim(path)//'.ordinary-inner',column,cfg%tiles(1)%template, &
   670001_int64,water,state,code);call require(code==0,'ordinary thermal physical first day')
  call run_crop_soil_n_output_day(trim(path)//'.generation','1900-01-02',.false.,670001_int64,backend,column, &
   cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,cfg%tiles(1)%base_forcing,cfg%numerical,n,weather, &
   0d0,1d0,items,split,policy,d,dates,rows,r,code)
  call require(code==OUTPUT_DAY_INVALID,'thermal output replay rejected')
  call save_output_authority(trim(path)//'.replay-after',w,n,d,dates,rows)
  w=initial_water;n=initial_state;call initialize_crop_ext(0d0,d,code)
  call run_crop_soil_n_output_day(trim(path)//'.view-failed','1900-01-02',.false.,670001_int64,backend,column, &
   cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,cfg%tiles(1)%base_forcing,cfg%numerical,n,weather, &
   0d0,1d0,items,split,policy,d,dates,rows,r,code,csv_path='missing-thermal-output/crop.csv')
  call require(code==OUTPUT_DAY_VIEW_FAILED.and.diagnostic_equal(d,manual),'CSV-only failure keeps saved thermal model')
  call save_output_authority(trim(path)//'.view-failed-memory',w,n,d,dates,rows)
  print '(A)','THERMAL_OUTPUT_FIRST_DAY_ATOMICITY=PASS'
 end subroutine
 subroutine output_generation_mode()
  type(crop_ext_state_t)::d
  type(crop_ext_row_t),allocatable::rows(:)
  character(10),allocatable::dates(:)
  type(fmr_b110_physical_parameters_t)::wrong
  type(fmr_template_t)::wrong_template
  integer(int64)::crop_identity
  character(512)::seed,option
  integer::code
  call get_command_argument(5,seed);call get_command_argument(6,option)
  if(trim(mode)=='generation-read')then
   call read_crop_n_output_generation(trim(path),column,cfg%tiles(1)%template,670001_int64,9001_int64, &
    9101_int64,sp,cp,water,state,d,dates,rows,code,cfg%tiles(1)%parameters)
   call require(code==0,'fresh complete thermal output decode')
   call save_output_authority(trim(endpoint),water,state,d,dates,rows)
  else
   call read_crop_n_output_generation(trim(seed),column,cfg%tiles(1)%template,670001_int64,9001_int64, &
    9101_int64,sp,cp,water,state,d,dates,rows,code,cfg%tiles(1)%parameters)
   call require(code==0,'valid seed before rejected thermal decode')
   call save_output_authority(trim(endpoint)//'.before',water,state,d,dates,rows)
   wrong=cfg%tiles(1)%parameters;wrong_template=cfg%tiles(1)%template;crop_identity=9101_int64
   select case(trim(option))
   case('missing-heat')
    call read_crop_n_output_generation(trim(path),column,wrong_template,670001_int64,9001_int64, &
     crop_identity,sp,cp,water,state,d,dates,rows,code)
   case default
    if(trim(option)=='wrong-heat')wrong%z(1)=wrong%z(1)-.01d0
    if(trim(option)=='wrong-crop')crop_identity=9999_int64
    if(trim(option)=='wrong-template')wrong_template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    call read_crop_n_output_generation(trim(path),column,wrong_template,670001_int64,9001_int64, &
     crop_identity,sp,cp,water,state,d,dates,rows,code,wrong)
   end select
   call require(code/=0,'thermal invalid generation and identity rejected')
   call save_output_authority(trim(endpoint)//'.after',water,state,d,dates,rows)
  end if
  print '(A)','THERMAL_OUTPUT_GENERATION_READ_ATOMIC=PASS'
 end subroutine
