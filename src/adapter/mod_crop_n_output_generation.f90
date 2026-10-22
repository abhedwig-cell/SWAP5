! Same-platform POSIX joint physical/diagnostic/reporting generation.
module mod_crop_n_output_generation
 use iso_fortran_env,only:real64,int64,int32,int8
 use iso_c_binding,only:c_int,c_char,c_null_char
 use mod_soil_n_crop_extended_output
 use mod_crop_soil_n_joint_restart_file
 use mod_kernel_transactions,only:kernel_committed_state_t
 use mod_fmr_runtime_core,only:fmr_logical_column_t,fmr_template_t
 use mod_fmr_serialized_reference_backend,only:fmr_b110_physical_parameters_t
 use mod_crop_soil_n_day,only:crop_soil_state_t
 use mod_crop_soil_n_configuration,only:crop_n_configuration_t
 use mod_b111_soil_n_reactive_owner,only:reactive_state_t,reactive_parameters_t
 use mod_wofost81_crop_owner_state,only:wofost81_crop_owner_state_t
 use mod_soil_n_pool_state,only:soil_n_pool_state_t
 use mod_fmr_crop_soil_n_thermal_application,only:soil_n_thermal_template
 implicit none
 private
 integer,parameter::MAX_BYTES=33554432,MAX_ROWS=100000
 character(8),parameter::MAGIC='S5NO0001'
 public::write_crop_n_output_generation,read_crop_n_output_generation,output_history_valid
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
 logical function output_history_valid(dates,rows)result(ok)
  character(*),intent(in)::dates(:)
  type(crop_ext_row_t),intent(in)::rows(:)
  character(128)::line
  integer::i,code
  ok=.false.
  if(size(dates)/=size(rows).or.size(rows)>MAX_ROWS)return
  if(len(dates)/=10)return
  do i=1,size(rows)
   call format_crop_ext_row(dates(i),rows(i),line,code);if(code/=0)return
   if(i>1)then
    if(dates(i)<=dates(i-1))return
   end if
  end do
  ok=.true.
 end function
 logical function history_matches_output(dates,rows,output)result(ok)
  character(*),intent(in)::dates(:)
  type(crop_ext_row_t),intent(in)::rows(:)
  type(crop_ext_state_t),intent(in)::output
  real(real64)::v(17),e(8),x(8)
  integer::i
  logical::ready
  ok=.false.
  if(.not.output_history_valid(dates,rows))return
  call output%snapshot(v(1),v(2:9),v(10:17),ready);if(.not.ready)return
  e=[1d0,0d0,1d0,0d0,1d0,0d0,1d0,0d0]
  do i=1,size(rows)
   x=rows(i)%values
   if(x(3)>=1d-6)then
    e(1)=min(e(1),x(4)/x(3));e(2)=max(e(2),x(4)/x(3))
    e(5)=min(e(5),x(5)/x(3));e(6)=max(e(6),x(5)/x(3))
   end if
   if(x(6)>=1d-6)then
    e(3)=min(e(3),x(7)/x(6));e(4)=max(e(4),x(7)/x(6))
    e(7)=min(e(7),x(8)/x(6));e(8)=max(e(8),x(8)/x(6))
   end if
  end do
  ok=all(e==v(10:17))
 end function
 logical function clocks_match(water,chemical,output)result(ok)
  type(kernel_committed_state_t),intent(in)::water
  type(crop_soil_state_t),intent(in)::chemical
  type(crop_ext_state_t),intent(in)::output
  type(reactive_state_t)::soil
  type(wofost81_crop_owner_state_t)::crop
  type(soil_n_pool_state_t)::pools
  type(crop_ext_state_t)::probe
  real(real64)::v(17),clock,theta
  integer(int64)::rev
  integer::code
  logical::ready
  ok=.false.
  if(.not.water%ready().or..not.chemical%ready())return
  call output%snapshot(v(1),v(2:9),v(10:17),ready);if(.not.ready)return
  call restore_crop_ext(v,probe,code);if(code/=0)return
  call chemical%snapshot(soil,crop);call soil%snapshot(clock,theta,pools,rev)
  ok=clock==v(1)
 end function
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
 subroutine temporary_paths(path,physical,generation,ok)
  character(*),intent(in)::path
  character(:),allocatable,intent(out)::physical,generation
  logical,intent(out)::ok
  character(32)::pid
  logical::exists
  integer::io
  ok=.false.
  if(len_trim(path)==0.or.len_trim(path)>1024.or.index(path,c_null_char)>0)return
  write(pid,'(I0)')c_getpid()
  physical=trim(path)//'.inner-'//trim(pid);generation=trim(path)//'.pending-'//trim(pid)
  inquire(file=physical,exist=exists,iostat=io);if(io/=0.or.exists)return
  inquire(file=generation,exist=exists,iostat=io);if(io/=0.or.exists)return
  ok=.true.
 end subroutine
 subroutine write_crop_n_output_generation(path,column,template,water_id,water,chemical,output,dates,rows,status)
  character(*),intent(in)::path,dates(:)
  type(fmr_logical_column_t),intent(in)::column
  type(fmr_template_t),intent(in)::template
  integer(int64),intent(in)::water_id
  type(kernel_committed_state_t),intent(in)::water
  type(crop_soil_state_t),intent(in)::chemical
  type(crop_ext_state_t),intent(in)::output
  type(crop_ext_row_t),intent(in)::rows(:)
  integer,intent(out)::status
  integer(int8),allocatable::physical_bytes(:),bytes(:)
  character(:),allocatable::physical,pending
  real(real64)::v(17)
  integer::io,u,n,i,code,fd,ignored,close_io
  integer(int32)::np,nr,crc
  logical::ok,ready
  status=CROP_EXT_INVALID
  if(.not.history_matches_output(dates,rows,output).or..not.clocks_match(water,chemical,output))return
  call temporary_paths(path,physical,pending,ok);if(.not.ok)return
  call write_crop_soil_n_joint_restart_file(physical,column,template,water_id,water,chemical,code)
  if(code/=0)then;call erase(physical);return;end if
  inquire(file=physical,size=n,iostat=io)
  if(io/=0.or.n<1.or.n>MAX_BYTES)then;call erase(physical);return;end if
  allocate(physical_bytes(n));open(newunit=u,file=physical,status='old',access='stream',form='unformatted',iostat=io)
  if(io/=0)then;call erase(physical);return;end if
  read(u,iostat=io)physical_bytes;close(u,status='delete',iostat=close_io)
  if(io==0)io=close_io
  if(io/=0)return
  call output%snapshot(v(1),v(2:9),v(10:17),ready)
  np=n;nr=size(rows)
  open(newunit=u,file=pending,status='new',access='stream',form='unformatted',iostat=io)
  if(io/=0)return
  write(u,iostat=io)MAGIC,np,nr,v,physical_bytes
  do i=1,size(rows)
   if(io/=0)exit
   write(u,iostat=io)dates(i),rows(i)%values
  end do
  close(u,iostat=close_io)
  if(io==0)io=close_io
  if(io/=0)then;call erase(pending);return;end if
  inquire(file=pending,size=n,iostat=io)
  if(io/=0.or.n>MAX_BYTES-4)then;call erase(pending);return;end if
  allocate(bytes(n));open(newunit=u,file=pending,status='old',access='stream',form='unformatted',iostat=io)
  if(io/=0)then;call erase(pending);return;end if
  read(u,iostat=io)bytes
  if(io==0)then
   crc=crc32(bytes);write(u,pos=n+1,iostat=io)crc
  end if
  close(u,iostat=close_io)
  if(io==0)io=close_io
  if(io/=0)then;call erase(pending);return;end if
  fd=c_open(pending//c_null_char,0_c_int)
  if(fd<0)then;call erase(pending);return;end if
  io=c_fsync(fd);ignored=c_close(fd)
  if(io/=0.or.ignored/=0)then;call erase(pending);return;end if
  io=c_rename(pending//c_null_char,trim(path)//c_null_char)
  if(io/=0)then;call erase(pending);return;end if
  status=CROP_EXT_OK
 end subroutine
 subroutine read_crop_n_output_generation(path,column,template,water_id,soil_id,crop_id,p,cp, &
     water,chemical,output,dates,rows,status,heat_parameters)
  character(*),intent(in)::path
  type(fmr_logical_column_t),intent(in)::column
  type(fmr_template_t),intent(in)::template
  integer(int64),intent(in)::water_id,soil_id,crop_id
  type(reactive_parameters_t),intent(in)::p
  type(crop_n_configuration_t),intent(in)::cp
  type(kernel_committed_state_t),intent(inout)::water
  type(crop_soil_state_t),intent(inout)::chemical
  type(crop_ext_state_t),intent(inout)::output
  character(10),allocatable,intent(inout)::dates(:)
  type(crop_ext_row_t),allocatable,intent(inout)::rows(:)
  integer,intent(out)::status
  type(fmr_b110_physical_parameters_t),intent(in),optional::heat_parameters
  type(kernel_committed_state_t)::water_trial
  type(crop_soil_state_t)::chemical_trial
  type(crop_ext_state_t)::output_trial
  character(10),allocatable::date_trial(:)
  type(crop_ext_row_t),allocatable::row_trial(:)
  integer(int8),allocatable::bytes(:),physical_bytes(:)
  character(:),allocatable::physical,pending
  character(8)::tag
  integer(int32)::np,nr,crc
  integer::n,u,io,i,code
  real(real64)::v(17)
  logical::ok
  status=CROP_EXT_INVALID
  ! Heat continuation must bind the persisted certificate to caller parameters.
  if(soil_n_thermal_template(template).and..not.present(heat_parameters))return
  call temporary_paths(path,physical,pending,ok);if(.not.ok)return
  inquire(file=path,size=n,iostat=io);if(io/=0.or.n<156.or.n>MAX_BYTES)return
  status=10
  allocate(bytes(n-4));open(newunit=u,file=path,status='old',access='stream',form='unformatted',iostat=io)
  if(io/=0)return
  read(u,iostat=io)bytes,crc
  if(io/=0)then;close(u);return;end if
  if(crc/=crc32(bytes))then;close(u);return;end if
  status=11
  read(u,pos=1,iostat=io)tag,np,nr,v
  if(io/=0)then;close(u);return;end if
  if(tag/=MAGIC.or.np<1.or.np>MAX_BYTES.or.nr<0.or.nr>MAX_ROWS)then;close(u);return;end if
  if(156_int64+int(np,int64)+74_int64*nr/=n)then;close(u);return;end if
  status=12
  output_trial=output;call restore_crop_ext(v,output_trial,code)
  if(code/=0)then;close(u);return;end if
  allocate(physical_bytes(np),date_trial(nr),row_trial(nr))
  read(u,iostat=io)physical_bytes
  do i=1,nr
   if(io/=0)exit
   read(u,iostat=io)date_trial(i),row_trial(i)%values
   row_trial(i)%emitted=.true.
  end do
  close(u)
  if(io/=0)return
  if(.not.history_matches_output(date_trial,row_trial,output_trial))return
  open(newunit=u,file=physical,status='new',access='stream',form='unformatted',iostat=io)
  if(io/=0)return
  write(u,iostat=io)physical_bytes;close(u)
  if(io/=0)then;call erase(physical);return;end if
  status=13
  water_trial=kernel_committed_state_t();chemical_trial=crop_soil_state_t()
  call read_crop_soil_n_joint_restart_file(physical,column,template,water_id,soil_id,crop_id,p,cp, &
    water_trial,chemical_trial,code,heat_parameters)
  call erase(physical)
  if(code/=0)return
  status=14
  if(.not.clocks_match(water_trial,chemical_trial,output_trial))return
  water=water_trial;chemical=chemical_trial;output=output_trial
  call move_alloc(date_trial,dates);call move_alloc(row_trial,rows)
  status=CROP_EXT_OK
 end subroutine
end module
