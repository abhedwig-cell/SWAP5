program test_crop_ext_csv
 use iso_fortran_env,only:real64
 use mod_soil_n_crop_extended_output
 use mod_crop_ext_csv_file
 implicit none
 type(crop_ext_state_t)::state
 type(crop_ext_row_t)::rows(3),bad(3)
 character(10)::dates(3)=['2000-01-01','2000-01-02','2000-01-03'],wrong(3)
 character(128)::line,expected,original(6)
 integer::code,i,u,io
 call initialize_crop_ext(0d0,state,code);call require(code==0)
 do i=1,3
  call observe_crop_ext(state,real(i-1,real64),real(i,real64),[1d-6,2d-6]*i, &
    [1d0,2d0,3d0,4d0]*i,[.01d0,.02d0,.03d0,.04d0]*i,.true.,rows(i),code)
  call require(code==0)
 end do
 call write_crop_ext_csv_file('crop.csv',dates,rows,state,code);call require(code==0)
 open(newunit=u,file='crop.csv',status='old')
 do i=1,6
  read(u,'(A)',iostat=io)original(i);call require(io==0)
 end do
 read(u,'(A)',iostat=io)line;call require(io<0);close(u)
 call require(original(1)==CROP_EXT_NAMES.and.original(3)==CROP_EXT_COLUMNS)
 call format_crop_ext_extrema(state,expected,code);call require(original(2)==expected)
 do i=1,3
  call format_crop_ext_row(dates(i),rows(i),expected,code);call require(original(i+3)==expected)
 end do
 bad=rows;bad(2)%emitted=.false.
 call write_crop_ext_csv_file('crop.csv',dates,bad,state,code);call require(code/=0)
 wrong=dates;wrong(2)=wrong(1)
 call write_crop_ext_csv_file('crop.csv',wrong,rows,state,code);call require(code/=0)
 call write_crop_ext_csv_file('absent/directory/crop.csv',dates,rows,state,code);call require(code/=0)
 open(newunit=u,file='crop.csv',status='old')
 do i=1,6
  read(u,'(A)')line;call require(line==original(i))
 end do
 close(u)
 ! A later complete generation replaces a prior generation, with no append.
 call write_crop_ext_csv_file('crop.csv',dates,rows,state,code);call require(code==0)
 print '(A)','CROP_EXT_COMPLETE_CSV_AND_ATOMIC_REJECTION_PASS'
contains
 subroutine require(ok)
  logical,intent(in)::ok
  if(.not.ok)error stop 'CSV check failed'
 end subroutine
end program
