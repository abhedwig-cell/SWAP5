! POSIX complete-file exporter; caller owns accepted row history and checkpoint.
module mod_crop_ext_csv_file
 use iso_c_binding,only:c_int,c_char,c_null_char
 use mod_soil_n_crop_extended_output
 implicit none
 private
 public::write_crop_ext_csv_file
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
 end interface
contains
 subroutine write_crop_ext_csv_file(path,dates,rows,state,status)
  character(*),intent(in)::path,dates(:)
  type(crop_ext_row_t),intent(in)::rows(:)
  type(crop_ext_state_t),intent(in)::state
  integer,intent(out)::status
  character(128),allocatable::lines(:)
  character(128)::extrema
  character(32)::pid
  character(:),allocatable::temporary
  integer::i,u,io,close_io,code
  status=CROP_EXT_INVALID
  if(len_trim(path)==0.or.len_trim(path)>1024.or.index(path,c_null_char)>0)return
  if(size(dates)/=size(rows))return
  if(size(rows)>1000000)return
  call format_crop_ext_extrema(state,extrema,code);if(code/=0)return
  allocate(lines(size(rows)))
  do i=1,size(rows)
   call format_crop_ext_row(dates(i),rows(i),lines(i),code)
   if(code/=0)return
   if(i>1)then
    if(dates(i)<=dates(i-1))return
   end if
  end do
  write(pid,'(I0)')c_getpid()
  temporary=trim(path)//'.pending-'//trim(pid)
  ! New prevents accidental reuse of another unfinished publication.
  open(newunit=u,file=temporary,status='new',action='write',iostat=io)
  if(io/=0)return
  write(u,'(A)',iostat=io)CROP_EXT_NAMES
  if(io==0)write(u,'(A)',iostat=io)trim(extrema)
  if(io==0)write(u,'(A)',iostat=io)CROP_EXT_COLUMNS
  do i=1,size(rows)
   if(io/=0)exit
   write(u,'(A)',iostat=io)trim(lines(i))
  end do
  if(io/=0)then
   close(u,status='delete',iostat=close_io);return
  end if
  close(u,iostat=io)
  if(io==0)io=c_rename(temporary//c_null_char,trim(path)//c_null_char)
  if(io/=0)then
   open(newunit=u,file=temporary,status='old',iostat=close_io)
   if(close_io==0)close(u,status='delete',iostat=close_io)
   return
  end if
  status=CROP_EXT_OK
 end subroutine
end module
