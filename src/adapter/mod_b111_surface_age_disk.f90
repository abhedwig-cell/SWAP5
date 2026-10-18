! Candidate sidecar for surface-age amount. S5AJ0001 remains unchanged.
module mod_b111_surface_age_disk
 use, intrinsic :: iso_fortran_env, only: int64,real64
 use mod_b111_surface_age_owner, only: surface_age_owner_t,snapshot_surface_age_owner, &
      reconstruct_surface_age_owner,AGE_OWNER_OK
 implicit none
 private
 character(8),parameter::MAGIC='S5PA0001'
 integer,parameter::RECORD_BYTES=56
 integer,parameter,public::AGE_DISK_OK=0,AGE_DISK_REJECT=1
 public::write_surface_age_disk,read_surface_age_disk
contains
 pure function checksum(identity,revision,time_day,depth_cm,stock_cm_day) result(value)
  integer(int64),intent(in)::identity,revision
  real(real64),intent(in)::time_day,depth_cm,stock_cm_day
  integer(int64)::value
  value=ieor(identity,revision)
  value=ieor(value,transfer(time_day,0_int64))
  value=ieor(value,transfer(depth_cm,0_int64))
  value=ieor(value,transfer(stock_cm_day,0_int64))
  value=ieor(value,int(z'53504130303031',int64))
 end function
 subroutine write_surface_age_disk(path,identity,state,status)
  character(*),intent(in)::path
  integer(int64),intent(in)::identity
  type(surface_age_owner_t),intent(in)::state
  integer,intent(out)::status
  real(real64)::time_day,depth_cm,stock_cm_day
  integer(int64)::revision,check,actual_identity
  integer::unit,io
  logical::ready
  status=AGE_DISK_REJECT
  call snapshot_surface_age_owner(state,time_day,depth_cm,stock_cm_day,revision,ready,actual_identity)
  if(.not.ready.or.identity<=0_int64.or.identity/=actual_identity.or.revision<0_int64)return
  block
    type(surface_age_owner_t)::verified
    integer::code
    call reconstruct_surface_age_owner(identity,revision,time_day,depth_cm,stock_cm_day,verified,code)
    if(code/=AGE_OWNER_OK)return
  end block
  check=checksum(identity,revision,time_day,depth_cm,stock_cm_day)
  open(newunit=unit,file=path,access='stream',form='unformatted',status='replace',action='write',iostat=io)
  if(io/=0)return
  write(unit,iostat=io)MAGIC,identity,revision,time_day,depth_cm,stock_cm_day,check
  close(unit)
  if(io==0)status=AGE_DISK_OK
 end subroutine
 subroutine read_surface_age_disk(path,expected_identity,state,status)
  character(*),intent(in)::path
  integer(int64),intent(in)::expected_identity
  type(surface_age_owner_t),intent(inout)::state
  integer,intent(out)::status
  type(surface_age_owner_t)::candidate
  character(8)::magic_read
  real(real64)::time_day,depth_cm,stock_cm_day,existing_time,existing_depth,existing_stock
  integer(int64)::identity,revision,check,old_revision
  integer::unit,io,nbytes,code
  logical::ready,exists
  status=AGE_DISK_REJECT
  call snapshot_surface_age_owner(state,existing_time,existing_depth,existing_stock,old_revision,ready)
  if(ready.or.expected_identity<=0_int64)return
  inquire(file=path,exist=exists,size=nbytes,iostat=io)
  if(io/=0.or..not.exists)return
  if(nbytes/=RECORD_BYTES)return
  open(newunit=unit,file=path,access='stream',form='unformatted',status='old',action='read',iostat=io)
  if(io/=0)return
  read(unit,iostat=io)magic_read,identity,revision,time_day,depth_cm,stock_cm_day,check
  close(unit)
  if(io/=0)return
  if(magic_read/=MAGIC.or.identity/=expected_identity)return
  if(check/=checksum(identity,revision,time_day,depth_cm,stock_cm_day))return
  call reconstruct_surface_age_owner(identity,revision,time_day,depth_cm,stock_cm_day,candidate,code)
  if(code/=AGE_OWNER_OK)return
  state=candidate
  status=AGE_DISK_OK
 end subroutine
end module
