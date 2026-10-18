program test_surface_age_disk_process
 use, intrinsic :: iso_fortran_env, only: real64,int64
 use mod_b111_surface_age_budget
 use mod_b111_surface_age_owner
 use mod_b111_surface_age_disk
 implicit none
 type(surface_age_owner_t)::state,next
 type(surface_age_request_t)::q
 type(surface_age_receipt_t)::receipt
 integer::status
 integer(int64)::revision
 real(real64)::clock,depth,stock
 logical::valid
 character(20)::mode
 call get_command_argument(1,mode)
 select case(trim(mode))
 case('write')
  call initialize_surface_age_owner(77_int64,0.0_real64,0.5_real64,4.0_real64,state,status)
  if(status/=AGE_OWNER_OK)error stop 'init write'
  call write_surface_age_disk('fresh_surface_age.bin',77_int64,state,status)
  if(status/=AGE_DISK_OK)error stop 'write'
  print *, 'SURFACE_AGE_FRESH_WRITE=PASS'
 case('read')
  call read_surface_age_disk('fresh_surface_age.bin',77_int64,state,status)
  if(status/=AGE_DISK_OK)error stop 'read fresh'
  call snapshot_surface_age_owner(state,clock,depth,stock,revision,valid)
  if(.not.valid.or.abs(stock-2.0_real64)>1.0e-12_real64.or.revision/=0_int64) &
    error stop 'unexpected persisted age stock'
  q%dt_day=0.25_real64
  q%pond_start_cm=0.5_real64
  q%pond_end_cm=0.5_real64
  call advance_surface_age_owner(state,q,next,receipt,status)
  if(status/=AGE_OWNER_OK)error stop 'resume'
  call snapshot_surface_age_owner(next,clock,depth,stock,revision,valid)
  if(revision/=1_int64.or.abs(clock-0.25_real64)>1.0e-12_real64)error stop 'revision'
  if(abs(stock-2.125_real64)>1.0e-12_real64)error stop 'age production after fresh read'
  print *, 'SURFACE_AGE_FRESH_CONTINUATION=PASS'
 case default
  error stop 'unknown process mode'
 end select
end program
