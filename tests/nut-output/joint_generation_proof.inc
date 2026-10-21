 subroutine generation_first_day()
  type(kernel_committed_state_t)::w
  type(crop_soil_state_t)::n
  type(crop_ext_state_t)::d,expected
  type(crop_ext_row_t),allocatable::rows(:)
  character(10),allocatable::dates(:)
  type(crop_ext_row_t)::manual_row
  type(senescence_joint_result_t)::r
  real(real64)::v(17)
  integer::code
  logical::ready
  w=initial_water;n=initial_state
  allocate(rows(0),dates(0))
  call initialize_crop_ext(0d0,d,code);call require(code==0,'joint output initialize')
  call write_crop_n_output_generation(trim(path)//'.generation.zero',column,cfg%tiles(1)%template,670001_int64, &
    w,n,d,dates,rows,code);call require(code==0,'initial zero generation')
  call write_crop_n_output_generation(trim(path)//'.generation',column,cfg%tiles(1)%template,670001_int64, &
    w,n,d,dates,rows,code);call require(code==0,'initial authoritative zero generation')
  ! Physical rejection and failed save both retain the original caller authority.
  call run_crop_soil_n_output_day(trim(path)//'.generation','1900-01-02',.false.,670001_int64,backend,column, &
    cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,cfg%tiles(1)%base_forcing,cfg%numerical,n,weather, &
    0d0,1d0,bad_items,split,policy,d,dates,rows,r,code,env)
  call require(code/=0.and.w%current_revision()==initial_water%current_revision(),'automatic physical rejection')
  call run_crop_soil_n_output_day('missing-output-directory/generation','1900-01-02',.false.,670001_int64,backend,column, &
    cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,cfg%tiles(1)%base_forcing,cfg%numerical,n,weather, &
    0d0,1d0,items,split,policy,d,dates,rows,r,code,env)
  call require(code==OUTPUT_DAY_SAVE_FAILED,'late output save failure exposed')
  call write_crop_n_output_generation(trim(path)//'.failed-save-after',column,cfg%tiles(1)%template,670001_int64, &
    w,n,d,dates,rows,code);call require(code==0,'authority after failed save remains valid')
  call run_crop_soil_n_output_day(trim(path)//'.generation','1900-01-02',.false.,670001_int64,backend,column, &
    cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,cfg%tiles(1)%base_forcing,cfg%numerical,n,weather, &
    0d0,1d0,items,split,policy,d,dates,rows,r,code,env)
  call require(code==OUTPUT_DAY_OK.and.size(rows)==0,'automatic first nonreport generation')
  call initialize_crop_ext(0d0,expected,code)
  call observe_accepted_crop_soil_n_day(expected,initial_water,initial_state,water,state,result, &
    0d0,1d0,.false.,manual_row,code)
  call require(code==0.and.output_identical(d,expected),'automatic diagnostic equals real manual observation')
  call write_crop_soil_n_joint_restart_file(trim(path)//'.automatic-inner',column,cfg%tiles(1)%template,670001_int64,w,n,code)
  call require(code==0,'automatic physical first day export')
  call write_crop_soil_n_joint_restart_file(trim(path)//'.ordinary-inner',column,cfg%tiles(1)%template,670001_int64,water,state,code)
  call require(code==0,'ordinary physical first day export')
  w=initial_water;n=initial_state
  call initialize_crop_ext(0d0,d,code)
  call run_crop_soil_n_output_day(trim(path)//'.view-failed.generation','1900-01-02',.false.,670001_int64,backend,column, &
    cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,cfg%tiles(1)%base_forcing,cfg%numerical,n,weather, &
    0d0,1d0,items,split,policy,d,dates,rows,r,code,env,'missing-output-directory/crop.csv')
  call require(code==OUTPUT_DAY_VIEW_FAILED.and.output_identical(d,expected),'CSV-only failure retains successful model generation')
  call write_crop_n_output_generation(trim(path)//'.view-failed.memory',column,cfg%tiles(1)%template,670001_int64, &
    w,n,d,dates,rows,code);call require(code==0,'CSV-only failure published memory matches saved generation')
  print '(A)','JOINT_OUTPUT_AUTOMATIC_FIRST_DAY_FAILURE_ATOMICITY=PASS'
 end subroutine
 subroutine generation_special_mode()
  type(crop_ext_state_t)::d
  type(crop_ext_row_t),allocatable::rows(:)
  character(10),allocatable::dates(:)
  character(512)::seed,option
  integer(int64)::target_crop
  integer::code
  call get_command_argument(5,seed);call get_command_argument(6,option)
  if(trim(mode)=='generation-read')then
   call read_crop_n_output_generation(trim(path),column,cfg%tiles(1)%template,670001_int64,9001_int64,9101_int64, &
    sp,cp,water,state,d,dates,rows,code)
   call require(code==0,'independent-process complete generation reconstruction')
   call write_crop_n_output_generation(trim(endpoint),column,cfg%tiles(1)%template,670001_int64, &
    water,state,d,dates,rows,code);call require(code==0,'independent complete generation re-export')
   print '(A)','JOINT_OUTPUT_INDEPENDENT_GENERATION_READ=PASS'
  else
   call read_crop_n_output_generation(trim(seed),column,cfg%tiles(1)%template,670001_int64,9001_int64,9101_int64, &
    sp,cp,water,state,d,dates,rows,code);call require(code==0,'negative seed')
   call write_crop_n_output_generation(trim(endpoint)//'.before',column,cfg%tiles(1)%template,670001_int64, &
    water,state,d,dates,rows,code);call require(code==0,'negative seed export')
   target_crop=9101_int64
   if(trim(option)=='wrong-id')target_crop=9999_int64
   call read_crop_n_output_generation(trim(path),column,cfg%tiles(1)%template,670001_int64,9001_int64,target_crop, &
    sp,cp,water,state,d,dates,rows,code);call require(code/=0,'complete invalid generation must reject')
   call write_crop_n_output_generation(trim(endpoint)//'.after',column,cfg%tiles(1)%template,670001_int64, &
    water,state,d,dates,rows,code);call require(code==0,'invalid generation leaves valid old authority')
   print '(A)','JOINT_OUTPUT_GENERATION_ATOMIC_INVALID=PASS'
  end if
 end subroutine
