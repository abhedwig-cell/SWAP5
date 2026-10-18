! POSIX same-platform committed snapshot. A single CRC-protected envelope binds
! the unchanged S5AJ0001 and S5PA0001 payloads. Only rename publishes a generation.
module mod_b111_age_snapshot_disk
 use iso_fortran_env,only:int8,int32,int64
 use iso_c_binding,only:c_int,c_char,c_null_char
 use mod_b111_age_triplet_disk
 use mod_age_joint_restart_file,only:write_age_joint_restart_file,crc32
 use mod_b111_surface_age_disk,only:write_surface_age_disk,AGE_DISK_OK
 use mod_fmr_b111_age_joint_application,only:age_joint_states_match,JOINT_OK
 use mod_fmr_runtime_core,only:fmr_logical_column_t,fmr_template_t
 use mod_kernel_transactions,only:kernel_committed_state_t
 use mod_fmr_b111_age_route,only:age_state_t
 use mod_b111_surface_age_owner,only:surface_age_owner_t
 use mod_b111_age_tracer_substep,only:b111_age_tracer_substep_forcing_t
 implicit none
 private
 public::write_age_snapshot_disk,read_age_snapshot_disk
 interface
  integer(c_int) function rename_c(old,new) bind(C,name='rename')
   import c_int,c_char
   character(c_char),intent(in)::old(*),new(*)
  end function
  integer(c_int) function open_c(path,flags) bind(C,name='open')
   import c_int,c_char
   character(c_char),intent(in)::path(*)
   integer(c_int),value::flags
  end function
  integer(c_int) function fsync_c(fd) bind(C,name='fsync')
   import c_int
   integer(c_int),value::fd
  end function
  integer(c_int) function close_c(fd) bind(C,name='close')
   import c_int
   integer(c_int),value::fd
  end function
 end interface
contains
 subroutine remove_file(path)
  character(*),intent(in)::path
  integer::u,io
  open(newunit=u,file=path,status='old',iostat=io)
  if(io==0)close(u,status='delete',iostat=io)
 end subroutine
 subroutine load_bytes(path,bytes,code)
  character(*),intent(in)::path
  integer(int8),allocatable,intent(out)::bytes(:)
  integer,intent(out)::code
  integer::n,u,io
  code=1
  inquire(file=path,size=n,iostat=io)
  if(io/=0.or.n<12.or.n>10485800)return
  allocate(bytes(n))
  open(newunit=u,file=path,access='stream',form='unformatted',status='old',iostat=io)
  if(io/=0)return
  read(u,iostat=io)bytes
  close(u)
  if(io==0)code=0
 end subroutine
 subroutine save_bytes(path,bytes,code)
  character(*),intent(in)::path
  integer(int8),intent(in)::bytes(:)
  integer,intent(out)::code
  integer::u,io
  open(newunit=u,file=path,access='stream',form='unformatted',status='new',iostat=io)
  code=1
  if(io/=0)return
  write(u,iostat=io)bytes
  close(u)
  if(io==0)code=0
 end subroutine
 integer function synchronize(path) result(code)
  character(*),intent(in)::path
  integer(c_int)::fd,rc
  code=1
  fd=open_c(path//c_null_char,0_c_int)
  if(fd<0)return
  rc=fsync_c(fd)
  code=rc
  rc=close_c(fd)
  if(rc/=0)code=1
 end function
 subroutine write_age_snapshot_disk(path,column,template,water_id,surface_id,water,soil,surface,status)
  character(*),intent(in)::path
  type(fmr_logical_column_t),intent(in)::column
  type(fmr_template_t),intent(in)::template
  integer(int64),intent(in)::water_id,surface_id
  type(kernel_committed_state_t),intent(in)::water
  type(age_state_t),intent(in)::soil
  type(surface_age_owner_t),intent(in)::surface
  integer,intent(out)::status
  integer(int8),allocatable::a(:),b(:),body(:)
  integer::u,io,code,n,slash
  integer(c_int)::rc
  logical::block_open
  character(:),allocatable::tmp,parent
  status=1
  if(.not.age_joint_states_match(water,soil,surface))return
  tmp=path//'.pending'
  ! Exclusive creation is the writer lock; a crash residue is fail-closed.
  open(newunit=u,file=tmp,access='stream',form='unformatted',status='new',iostat=io)
  if(io/=0)return
  writing:block
   call write_age_joint_restart_file(tmp//'.water',column,template,water_id,water,soil,code,surface)
   if(code/=JOINT_OK)exit writing
   call write_surface_age_disk(tmp//'.surface',surface_id,surface,code)
   if(code/=AGE_DISK_OK)exit writing
   call load_bytes(tmp//'.water',a,code)
   if(code/=0)exit writing
   call load_bytes(tmp//'.surface',b,code)
   if(code/=0)exit writing
   write(u,iostat=io)'S5AT0001',int(size(a),int32),int(size(b),int32),a,b
   if(io/=0)exit writing
   close(u,iostat=io)
   if(io/=0)exit writing
   call load_bytes(tmp,body,code)
   if(code/=0)exit writing
   n=size(body)
   open(newunit=u,file=tmp,access='stream',form='unformatted',status='old',iostat=io)
   if(io/=0)exit writing
   write(u,pos=n+1,iostat=io)crc32(body)
   close(u,iostat=code)
   if(io/=0.or.code/=0)exit writing
   if(synchronize(tmp)/=0)exit writing
   rc=rename_c(tmp//c_null_char,path//c_null_char)
   if(rc/=0)exit writing
   slash=index(path,'/',back=.true.);parent='.'
   if(slash==1)parent='/'
   if(slash>1)parent=path(:slash-1)
   ! File data before rename, directory entry after rename, for power-loss durability.
   if(synchronize(parent)/=0)exit writing
   status=0
  end block writing
  ! A NEW open may still be live if an earlier write failed.
  inquire(unit=u,opened=block_open)
  if(block_open)close(u,iostat=io)
  call remove_file(tmp//'.water');call remove_file(tmp//'.surface');call remove_file(tmp)
 end subroutine
 subroutine read_age_snapshot_disk(path,column,template,water_id,soil_id,surface_id,p,water,soil,surface,status)
  character(*),intent(in)::path
  type(fmr_logical_column_t),intent(in)::column
  type(fmr_template_t),intent(in)::template
  integer(int64),intent(in)::water_id,soil_id,surface_id
  type(b111_age_tracer_substep_forcing_t),intent(in)::p
  type(kernel_committed_state_t),intent(inout)::water
  type(age_state_t),intent(inout)::soil
  type(surface_age_owner_t),intent(inout)::surface
  integer,intent(out)::status
  integer(int8),allocatable::bytes(:)
  integer(int32)::na,nb,checksum
  character(8)::magic
  character(:),allocatable::tmp
  integer::u,io,code,n
  status=1
  call load_bytes(path,bytes,code)
  if(code/=0)return
  n=size(bytes)
  if(n<76)return
  magic=transfer(bytes(:8),magic)
  na=transfer(bytes(9:12),na);nb=transfer(bytes(13:16),nb)
  if(magic/='S5AT0001'.or.na<12.or.na>10485760.or.nb/=56)return
  if(n/=20+na+nb)return
  checksum=transfer(bytes(n-3:n),checksum)
  if(crc32(bytes(:n-4))/=checksum)return
  tmp=path//'.reading'
  open(newunit=u,file=tmp,status='new',iostat=io)
  if(io/=0)return
  close(u)
  decoding:block
   call save_bytes(tmp//'.water',bytes(17:16+na),code)
   if(code/=0)exit decoding
   call save_bytes(tmp//'.surface',bytes(17+na:n-4),code)
   if(code/=0)exit decoding
   call restore_age_triplet_disk(tmp//'.water',tmp//'.surface',column,template,water_id,soil_id,surface_id,p, &
      water,soil,surface,code)
   if(code==TRIPLET_DISK_OK)status=0
  end block decoding
  call remove_file(tmp//'.water');call remove_file(tmp//'.surface');call remove_file(tmp)
 end subroutine
end module
