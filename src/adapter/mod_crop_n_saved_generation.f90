! Same-platform POSIX envelope. One atomic publication contains the COMPLETE
! unchanged S5NO0001 generation and its explicitly owned diagnostic memory.
module mod_crop_n_saved_generation
 use iso_fortran_env,only:real64,int64,int32,int8
 use iso_c_binding,only:c_int,c_char,c_null_char
 use mod_crop_n_output_generation
 use mod_crop_ext_saved_residue
 use mod_soil_n_crop_extended_output
 use mod_kernel_transactions,only:kernel_committed_state_t
 use mod_crop_soil_n_day,only:crop_soil_state_t
 use mod_fmr_runtime_core,only:fmr_logical_column_t,fmr_template_t
 use mod_fmr_serialized_reference_backend,only:fmr_b110_physical_parameters_t
 use mod_b111_soil_n_reactive_owner,only:reactive_parameters_t
 use mod_crop_soil_n_configuration,only:crop_n_configuration_t
 use mod_fmr_crop_soil_n_thermal_application,only:soil_n_thermal_template
 implicit none
 private
 integer,parameter::MAX_BYTES=33554432
 character(8),parameter::MAGIC='S5NS0001'
 public::write_crop_n_saved_generation,read_crop_n_saved_generation
 interface
  function c_getpid()bind(C,name='getpid')result(pid)
   import c_int
   integer(c_int)::pid
  end function
  function c_rename(old,new)bind(C,name='rename')result(code)
   import c_int,c_char
   character(c_char),intent(in)::old(*),new(*)
   integer(c_int)::code
  end function
  function c_open(path,flags)bind(C,name='open')result(fd)
   import c_int,c_char
   character(c_char),intent(in)::path(*)
   integer(c_int),value::flags
   integer(c_int)::fd
  end function
  function c_fsync(fd)bind(C,name='fsync')result(code)
   import c_int
   integer(c_int),value::fd
   integer(c_int)::code
  end function
  function c_close(fd)bind(C,name='close')result(code)
   import c_int
   integer(c_int),value::fd
   integer(c_int)::code
  end function
 end interface
contains
 function crc32(bytes)result(crc)
  integer(int8),intent(in)::bytes(:)
  integer(int32)::crc
  integer::i,j
  crc=not(0_int32)
  do i=1,size(bytes)
   crc=ieor(crc,iand(int(bytes(i),int32),int(z'FF',int32)))
   do j=1,8
    if(btest(crc,0))then
     crc=ieor(shiftr(crc,1),int(z'EDB88320',int32))
    else
     crc=shiftr(crc,1)
    end if
   end do
  end do
  crc=not(crc)
 end function
 subroutine erase(path)
  character(*),intent(in)::path
  integer::u,io
  open(newunit=u,file=path,status='old',access='stream',form='unformatted',iostat=io)
  if(io==0)close(u,status='delete',iostat=io)
 end subroutine
 subroutine paths(path,inner,pending,ok)
  character(*),intent(in)::path
  character(:),allocatable,intent(out)::inner,pending
  logical,intent(out)::ok
  character(32)::pid
  logical::exists
  integer::io
  ok=.false.
  if(len_trim(path)==0.or.len_trim(path)>1000.or.index(path,c_null_char)>0)return
  write(pid,'(I0)')c_getpid()
  inner=trim(path)//'.saved-inner-'//trim(pid);pending=trim(path)//'.saved-pending-'//trim(pid)
  inquire(file=inner,exist=exists,iostat=io);if(io/=0.or.exists)return
  inquire(file=pending,exist=exists,iostat=io);if(io/=0.or.exists)return
  ok=.true.
 end subroutine
 logical function aligned(output,saved)result(ok)
  type(crop_ext_state_t),intent(in)::output
  type(crop_ext_saved_residue_t),intent(in)::saved
  real(real64)::o(17),v(9)
  logical::ready
  ok=.false.
  call output%snapshot(o(1),o(2:9),o(10:17),ready);if(.not.ready)return
  call saved%snapshot(v,ready);if(.not.ready)return
  ok=o(1)==v(1)
 end function
 subroutine write_crop_n_saved_generation(path,column,template,water_id,water,chemical,output,saved,dates,rows,status)
  character(*),intent(in)::path,dates(:)
  type(fmr_logical_column_t),intent(in)::column
  type(fmr_template_t),intent(in)::template
  integer(int64),intent(in)::water_id
  type(kernel_committed_state_t),intent(in)::water
  type(crop_soil_state_t),intent(in)::chemical
  type(crop_ext_state_t),intent(in)::output
  type(crop_ext_saved_residue_t),intent(in)::saved
  type(crop_ext_row_t),intent(in)::rows(:)
  integer,intent(out)::status
  integer(int8),allocatable::bytes(:),payload(:)
  character(:),allocatable::inner,pending
  real(real64)::v(9)
  integer(int32)::np,crc
  integer::n,u,io,code,close_io,fd,ignored
  logical::ok,ready
  status=CROP_EXT_INVALID
  if(.not.aligned(output,saved))return
  call paths(path,inner,pending,ok);if(.not.ok)return
  call write_crop_n_output_generation(inner,column,template,water_id,water,chemical,output,dates,rows,code)
  if(code/=0)then;call erase(inner);return;end if
  inquire(file=inner,size=n,iostat=io)
  if(io/=0.or.n<156.or.n>MAX_BYTES-88)then;call erase(inner);return;end if
  allocate(payload(n))
  open(newunit=u,file=inner,status='old',access='stream',form='unformatted',iostat=io)
  if(io/=0)then;call erase(inner);return;end if
  read(u,iostat=io)payload;close(u,status='delete',iostat=close_io)
  if(io/=0.or.close_io/=0)return
  call saved%snapshot(v,ready);np=n
  open(newunit=u,file=pending,status='new',access='stream',form='unformatted',iostat=io)
  if(io/=0)return
  write(u,iostat=io)MAGIC,np,v,payload
  close(u,iostat=close_io)
  if(io/=0.or.close_io/=0)then;call erase(pending);return;end if
  allocate(bytes(84+n))
  open(newunit=u,file=pending,status='old',access='stream',form='unformatted',iostat=io)
  if(io/=0)then;call erase(pending);return;end if
  read(u,iostat=io)bytes
  if(io==0)then
   crc=crc32(bytes);write(u,pos=size(bytes)+1,iostat=io)crc
  end if
  close(u,iostat=close_io)
  if(io/=0.or.close_io/=0)then;call erase(pending);return;end if
  fd=c_open(pending//c_null_char,0_c_int)
  if(fd<0)then;call erase(pending);return;end if
  io=c_fsync(fd);ignored=c_close(fd)
  if(io/=0.or.ignored/=0)then;call erase(pending);return;end if
  io=c_rename(pending//c_null_char,trim(path)//c_null_char)
  if(io/=0)then;call erase(pending);return;end if
  status=CROP_EXT_OK
 end subroutine
 subroutine read_crop_n_saved_generation(path,column,template,water_id,soil_id,crop_id,p,cp, &
   water,chemical,output,saved,dates,rows,status,heat_parameters)
  character(*),intent(in)::path
  type(fmr_logical_column_t),intent(in)::column
  type(fmr_template_t),intent(in)::template
  integer(int64),intent(in)::water_id,soil_id,crop_id
  type(reactive_parameters_t),intent(in)::p
  type(crop_n_configuration_t),intent(in)::cp
  type(kernel_committed_state_t),intent(inout)::water
  type(crop_soil_state_t),intent(inout)::chemical
  type(crop_ext_state_t),intent(inout)::output
  type(crop_ext_saved_residue_t),intent(inout)::saved
  character(10),allocatable,intent(inout)::dates(:)
  type(crop_ext_row_t),allocatable,intent(inout)::rows(:)
  integer,intent(out)::status
  type(fmr_b110_physical_parameters_t),optional,intent(in)::heat_parameters
  type(kernel_committed_state_t)::wt
  type(crop_soil_state_t)::ct
  type(crop_ext_state_t)::ot
  type(crop_ext_saved_residue_t)::st
  character(10),allocatable::dt(:)
  type(crop_ext_row_t),allocatable::rt(:)
  integer(int8),allocatable::bytes(:),payload(:)
  character(:),allocatable::inner,pending
  character(8)::tag
  real(real64)::v(9)
  integer(int32)::np,crc
  integer::n,u,io,code,close_io
  logical::ok
  status=CROP_EXT_INVALID
  if(soil_n_thermal_template(template).and..not.present(heat_parameters))return
  call paths(path,inner,pending,ok);if(.not.ok)return
  inquire(file=path,size=n,iostat=io);if(io/=0.or.n<244.or.n>MAX_BYTES)return
  allocate(bytes(n-4))
  open(newunit=u,file=path,status='old',access='stream',form='unformatted',iostat=io)
  if(io/=0)return
  read(u,iostat=io)bytes,crc
  if(io/=0)then;close(u);return;end if
  if(crc/=crc32(bytes))then;close(u);return;end if
  read(u,pos=1,iostat=io)tag,np,v
  if(io/=0)then;close(u);return;end if
  if(tag/=MAGIC.or.np<156.or.int(np,int64)+88_int64/=int(n,int64))then;close(u);return;end if
  call restore_crop_ext_saved_residue(v,st,code)
  if(code/=0)then;close(u);return;end if
  allocate(payload(np));read(u,iostat=io)payload;close(u,iostat=close_io)
  if(io/=0.or.close_io/=0)return
  open(newunit=u,file=inner,status='new',access='stream',form='unformatted',iostat=io)
  if(io/=0)return
  write(u,iostat=io)payload;close(u,iostat=close_io)
  if(io/=0.or.close_io/=0)then;call erase(inner);return;end if
  call read_crop_n_output_generation(inner,column,template,water_id,soil_id,crop_id,p,cp,wt,ct,ot,dt,rt,code,heat_parameters)
  call erase(inner)
  if(code/=0.or..not.aligned(ot,st))return
  water=wt;chemical=ct;output=ot;saved=st
  call move_alloc(dt,dates);call move_alloc(rt,rows);status=CROP_EXT_OK
 end subroutine
end module
