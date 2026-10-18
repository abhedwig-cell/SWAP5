program test_surface_age_disk
 use iso_fortran_env, only: real64,int64,int8
 use mod_b111_surface_age_owner
 use mod_b111_surface_age_disk
 implicit none
 type(surface_age_owner_t)::state,restored,unchanged
 type(surface_age_request_t)::q
 type(surface_age_receipt_t)::receipt
 real(real64)::t,d,stock
 integer(int64)::rev
 integer::code,u,io
 integer(int8)::byte
 logical::valid
 character(*),parameter::file='surface_age_test.bin'
 call initialize_surface_age_owner(987_int64,0.0_real64,1.0_real64,3.0_real64,state,code)
 if(code/=AGE_OWNER_OK)error stop 'init'
 call write_surface_age_disk(file,986_int64,state,code)
 if(code==AGE_DISK_OK)error stop 'writer accepted wrong identity'
 call write_surface_age_disk(file,987_int64,state,code)
 if(code/=AGE_DISK_OK)error stop 'write'
 call read_surface_age_disk(file,988_int64,restored,code)
 if(code==AGE_DISK_OK)error stop 'wrong id'
 call read_surface_age_disk(file,987_int64,restored,code)
 if(code/=AGE_DISK_OK)error stop 'read'
 call snapshot_surface_age_owner(restored,t,d,stock,rev,valid)
 if(.not.valid.or.abs(stock-3.0_real64)>1.0e-12_real64.or.rev/=0_int64)error stop 'restored stock'
 unchanged=restored
 call read_surface_age_disk(file,987_int64,restored,code)
 if(code==AGE_DISK_OK)error stop 'overwrite accepted'
 q%dt_day=0.1_real64
 q%pond_start_cm=1.0_real64
 q%pond_end_cm=1.0_real64
 call advance_surface_age_owner(restored,q,state,receipt,code)
 if(code/=AGE_OWNER_OK)error stop 'continuation'
 call snapshot_surface_age_owner(state,t,d,stock,rev,valid)
 if(rev/=1_int64.or.stock<=3.0_real64)error stop 'ageing after restart'
 ! Mutate the final payload byte. Checksum must reject without target mutation.
 open(newunit=u,file=file,access='stream',form='unformatted',action='readwrite',status='old',iostat=io)
 if(io/=0)error stop 'open corruption'
 read(u,pos=56,iostat=io)byte
 if(io/=0)error stop 'read corruption'
 byte=ieor(byte,1_int8)
 write(u,pos=56,iostat=io)byte
 close(u)
 call read_surface_age_disk(file,987_int64,unchanged,code)
 if(code==AGE_DISK_OK)error stop 'corrupted disk accepted'
 call snapshot_surface_age_owner(unchanged,t,d,stock,rev,valid)
 if(.not.valid.or.abs(stock-3.0_real64)>1.0e-12_real64)error stop 'corruption changed target'
 open(newunit=u,file=file,status='old',iostat=io)
 if(io==0)close(u,status='delete')
 print *, 'MC_SOL01_SURFACE_AGE_DISK=PASS'
end program
