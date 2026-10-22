 subroutine harvest_save(name,w,n,d,dates,rows)
  character(*),intent(in)::name
  type(kernel_committed_state_t),intent(in)::w
  type(crop_soil_state_t),intent(in)::n
  type(crop_ext_state_t),intent(in)::d
  character(10),intent(in)::dates(:)
  type(crop_ext_row_t),intent(in)::rows(:)
  integer::code
  call write_crop_n_output_generation(name,column,cfg%tiles(1)%template,670001_int64,w,n,d,dates,rows,code)
  call require(code==0,'harvest combined authority snapshot')
 end subroutine
 subroutine harvest_output_proof(prefix,w,n,d,dates,rows)
  character(*),intent(in)::prefix
  type(kernel_committed_state_t),intent(in)::w
  type(crop_soil_state_t),intent(in)::n
  type(crop_ext_state_t),intent(in)::d
  character(10),intent(in)::dates(:)
  type(crop_ext_row_t),intent(in)::rows(:)
  type(crop_soil_state_t)::actual,manual,view_trial
  type(crop_soil_harvest_receipt_t)::r,reference
  type(crop_soil_harvest_observation_t)::observation,absent
  integer::code,phase
  character(1)::tag
  actual=n;manual=n
  call harvest_save(prefix//'.active',w,actual,d,dates,rows)
  call run_crop_soil_n_output_harvest(prefix//'.invalid',0,column,cfg%tiles(1)%template,670001_int64, &
   w,actual,d,dates,rows,r,code)
  call require(code==OUTPUT_DAY_INVALID.and.r%status/=0,'unknown phase rejects')
  call run_crop_soil_n_output_harvest(prefix//'.invalid',2,column,cfg%tiles(1)%template,670001_int64, &
   w,actual,d,dates,rows,r,code)
  call require(code==OUTPUT_DAY_INVALID.and.r%status/=0,'premature incorporation rejects')
  call run_crop_soil_n_output_harvest(prefix//'.invalid',3,column,cfg%tiles(1)%template,670001_int64, &
   w,actual,d,dates,rows,r,code)
  call require(code==OUTPUT_DAY_INVALID.and.r%status/=0,'missing observation rejects')
  call run_crop_soil_n_output_harvest('missing-harvest-output/generation',1,column, &
   cfg%tiles(1)%template,670001_int64,w,actual,d,dates,rows,r,code)
  call require(code==OUTPUT_DAY_SAVE_FAILED.and.r%status/=0,'save failure cannot publish successful harvest receipt')
  call harvest_save(prefix//'.failed-before-stage',w,actual,d,dates,rows)
  do phase=1,3
   tag=achar(48+phase)
   if(phase==1)then
    call harvest_crop_soil_boundary(manual,reference)
   else if(phase==2)then
    call consume_crop_soil_harvest_pending(manual,reference)
   else
    call acknowledge_crop_soil_harvest(manual,observation,reference)
   end if
   call require(reference%status==0.and.abs(reference%residual)<=1d-12,'original phase owner whole N gate')
   if(phase==3)then
    call run_crop_soil_n_output_harvest(prefix//'.invalid',phase,column,cfg%tiles(1)%template,670001_int64, &
     w,actual,d,dates,rows,r,code,observation=absent)
    call require(code==OUTPUT_DAY_INVALID.and.r%status/=0,'unbound observation rejects')
    call harvest_save(prefix//'.unbound-observation-after',w,actual,d,dates,rows)
   end if
   call run_crop_soil_n_output_harvest('missing-harvest-output/generation',phase,column, &
    cfg%tiles(1)%template,670001_int64,w,actual,d,dates,rows,r,code,observation=observation)
   call require(code==OUTPUT_DAY_SAVE_FAILED.and.r%status/=0,'late phase save rejection')
   call harvest_save(prefix//'.before-'//tag,w,actual,d,dates,rows)
   view_trial=actual
   call run_crop_soil_n_output_harvest(prefix//'.phase-'//tag,phase,column,cfg%tiles(1)%template, &
    670001_int64,w,actual,d,dates,rows,r,code,observation=observation,csv_path=prefix//'.csv')
   call require(code==OUTPUT_DAY_OK.and.r%status==0.and.abs(r%residual)<=1d-12,'phase saved then published with hard N gate')
   call harvest_save(prefix//'.memory-'//tag,w,actual,d,dates,rows)
   call write_crop_soil_n_joint_restart_file(prefix//'.manual-'//tag,column,cfg%tiles(1)%template, &
    670001_int64,w,manual,code);call require(code==0,'manual original harvest physical bytes')
   call write_crop_soil_n_joint_restart_file(prefix//'.automatic-'//tag,column,cfg%tiles(1)%template, &
    670001_int64,w,actual,code);call require(code==0,'automatic harvest physical bytes')
   call run_crop_soil_n_output_harvest(prefix//'.view-'//tag,phase,column,cfg%tiles(1)%template, &
    670001_int64,w,view_trial,d,dates,rows,r,code,observation=observation,csv_path='missing-harvest-output/output.csv')
   call require(code==OUTPUT_DAY_VIEW_FAILED.and.r%status==0,'CSV failure retains saved biological phase')
   call harvest_save(prefix//'.view-memory-'//tag,w,view_trial,d,dates,rows)
   if(phase==1)then
    call observe_crop_soil_harvest(actual,observation,code)
    call require(code==0,'detached existing end-status observation')
   end if
   call run_crop_soil_n_output_harvest(prefix//'.invalid',phase,column,cfg%tiles(1)%template,670001_int64, &
    w,actual,d,dates,rows,r,code,observation=observation)
   call require(code==OUTPUT_DAY_INVALID.and.r%status/=0,'phase replay cannot repeat harvest transfer or retirement')
   call harvest_save(prefix//'.replay-'//tag,w,actual,d,dates,rows)
  end do
  print '(A)','HARVEST_GENERATION_STAGE_CONSUME_OBSERVE_RETIRE_ATOMIC_PASS'
 end subroutine
 subroutine harvest_resume_mode()
  type(crop_ext_state_t)::d
  type(crop_ext_row_t),allocatable::rows(:)
  character(10),allocatable::dates(:)
  type(crop_soil_harvest_receipt_t)::r
  type(crop_soil_harvest_observation_t)::o
  character(8)::arg
  integer::code,phase
  call get_command_argument(5,arg);read(arg,*)phase
  call read_crop_n_output_generation(trim(path),column,cfg%tiles(1)%template,670001_int64,9001_int64, &
   9101_int64,sp,cp,water,state,d,dates,rows,code,cfg%tiles(1)%parameters)
  call require(code==0,'fresh process complete harvest phase reconstruction')
  if(phase==0)then
   call harvest_save(trim(endpoint),water,state,d,dates,rows)
  else
   if(phase==3)then
    call observe_crop_soil_harvest(state,o,code);call require(code==0,'fresh explicit end-status observation')
   end if
   call run_crop_soil_n_output_harvest(trim(endpoint),phase,column,cfg%tiles(1)%template,670001_int64, &
    water,state,d,dates,rows,r,code,observation=o)
   call require(code==0.and.r%status==0,'fresh phase progression uses original owner')
  end if
  print '(A)','HARVEST_GENERATION_FRESH_PHASE_PASS'
 end subroutine
