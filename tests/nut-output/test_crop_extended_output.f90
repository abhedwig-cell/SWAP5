program test_crop_extended_output
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan,ieee_positive_inf
 use mod_soil_n_crop_extended_output
 implicit none
 type(crop_ext_state_t)::s,copy,empty
 type(crop_ext_row_t)::row,row2
 real(real64)::dm(4),n(4),up(2),expected(8),ext(8),tot(8),clock,before(17),after(17),x(2)
 real(real64)::nan,inf
 character(128)::actual,original,line
 integer::schedule,day,code,code2,unit,i,j,checks,reports
 logical::emit,ready
 checks=0;reports=0
 nan=ieee_value(0d0,ieee_quiet_nan);inf=ieee_value(0d0,ieee_positive_inf)
 do schedule=1,7,2
  call initialize_crop_ext(0d0,s,code);call require(code==0,'initialize')
  do day=1,128
   dm=[.17d0*day,.13d0*day,.19d0*day,.23d0*day]
   n=dm*[.003d0,.007d0,.011d0,.017d0]
   if(day<=4)then
    dm=[0d0,.1d-6,.2d-6,.3d-6]*real(day-1,real64);n=dm*.02d0
   end if
   up=[1.23456789d-7*day,7.654321d-8*day]
   emit=mod(day,schedule)==0.or.day==128
   copy=s
   call observe_crop_ext(s,real(day-1,real64),real(day,real64),up,dm,n,emit,row,code)
   call observe_crop_ext(copy,real(day-1,real64),real(day,real64),up,dm,n,emit,row2,code2)
   call require(code==0.and.code2==0,'consecutive accepted interval')
   call require(identical(s,copy).and.all(transfer(row%values,[0_int64],8)== &
     transfer(row2%values,[0_int64],8)),'complete value continuation')
   open(newunit=unit,status='scratch',action='readwrite')
   call original_step(day==1,up,dm,n,emit,unit,expected,ext)
   call s%snapshot(clock,tot,after(10:17),ready)
   call require(all(transfer(ext,[0_int64],8)==transfer(after(10:17),[0_int64],8)),'original extrema exact')
   if(emit)then
    reports=reports+1
    call require(all(transfer(row%values,[0_int64],8)==transfer(expected,[0_int64],8)),'original row exact')
    call format_crop_ext_row('2000-01-01',row,actual,code)
    rewind(unit);read(unit,'(a)')original
    call require(code==0.and.actual==original,'literal original formatted row exact')
    write(original,'(8e11.4)')ext
    call format_crop_ext_extrema(s,actual,code)
    call require(code==0.and.actual==original,'literal original extrema line exact')
    call require(all(tot==0d0),'report resets interval only')
   else
    call require(.not.row%emitted.and.all(tot==expected),'nonreport accumulation')
   end if
   close(unit)
  end do
 end do
 call initialize_crop_ext(0d0,s,code)
 dm=[1d0,2d0,3d0,4d0];n=dm*.01d0;up=[1d-4,2d-4]
 do i=1,13
  copy=s;x=up
  select case(i)
  case(1);call observe_crop_ext(s,1d0,2d0,up,dm,n,.true.,row,code)
  case(2);call observe_crop_ext(s,-1d0,1d0,up,dm,n,.true.,row,code)
  case(3);call observe_crop_ext(s,0d0,0d0,up,dm,n,.true.,row,code)
  case(4);call observe_crop_ext(s,0d0,nan,up,dm,n,.true.,row,code)
  case(5);x(1)=nan;call observe_crop_ext(s,0d0,1d0,x,dm,n,.true.,row,code)
  case(6);x(1)=inf;call observe_crop_ext(s,0d0,1d0,x,dm,n,.true.,row,code)
  case(7);x(1)=-1d-9;call observe_crop_ext(s,0d0,1d0,x,dm,n,.true.,row,code)
  case(8);x(1)=1d6+1d0;call observe_crop_ext(s,0d0,1d0,x,dm,n,.true.,row,code)
  case(9);dm(1)=-1d0;call observe_crop_ext(s,0d0,1d0,up,dm,n,.true.,row,code);dm(1)=1d0
  case(10);n(1)=2d0;call observe_crop_ext(s,0d0,1d0,up,dm,n,.true.,row,code);n(1)=.01d0
  case(11);dm(1)=inf;call observe_crop_ext(s,0d0,1d0,up,dm,n,.true.,row,code);dm(1)=1d0
  case(12);dm(1)=1d6+1d0;call observe_crop_ext(s,0d0,1d0,up,dm,n,.true.,row,code);dm(1)=1d0
  case(13);n(1)=nan;call observe_crop_ext(s,0d0,1d0,up,dm,n,.true.,row,code);n(1)=.01d0
  end select
  call require(code/=0.and.identical(s,copy).and..not.row%emitted,'invalid atomic observer')
 end do
 call observe_crop_ext(empty,0d0,1d0,up,dm,n,.true.,row,code)
 call require(code/=0,'uninitialized observer rejected')
 call observe_crop_ext(s,0d0,1d0,up,dm,n,.true.,row,code)
 call require(code==0,'accepted positive discriminant')
 copy=s
 call observe_crop_ext(s,0d0,1d0,up,dm,n,.true.,row2,code)
 call require(code/=0.and.identical(s,copy),'duplicate accepted receipt rejected')
 call require(row%values(3)==9d0.and.row%values(6)==1d0,'explicit saved residue discriminant')
 call format_crop_ext_row('bad-date!!',row,line,code);call require(code/=0.and.len_trim(line)==0,'invalid date syntax')
 call format_crop_ext_row('2000-01-01',row,line(:20),code);call require(code/=0,'short row buffer')
 row%values(1)=nan
 call format_crop_ext_row('2000-01-01',row,line,code);call require(code/=0,'nonfinite row')
 call initialize_crop_ext(nan,s,code);call require(code/=0,'nonfinite origin')
 print '(A,I0,A,I0)','CROP_EXT_SOURCE_EXACT_PASS checks=',checks,' reports=',reports
contains
 logical function identical(a,b)result(ok)
  type(crop_ext_state_t),intent(in)::a,b
  real(real64)::v(17),w(17)
  logical::ra,rb
  call a%snapshot(v(1),v(2:9),v(10:17),ra)
  call b%snapshot(w(1),w(2:9),w(10:17),rb)
  ok=(ra.eqv.rb).and.all(transfer(v,[0_int64],17)==transfer(w,[0_int64],17))
 end function
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then
   print *,'FAIL: ',label
   error stop 1
  end if
  checks=checks+1
 end subroutine
 subroutine original_step(first,uptake,dm,n,report,cropext,values,extrema)
  logical,intent(in)::first,report
  real(real64),intent(in)::uptake(2),dm(4),n(4)
  integer,intent(in)::cropext
  real(real64),intent(out)::values(8),extrema(8)
  real(real64)::t4,pnratio,NH4_upt,NO3_upt,idwlv_1,idwst_1,idwso_1,idwrt_1
  real(real64)::iNLOSSL_1,iNLOSSS_1,iNLOSSO_1,iNLOSSR_1
  real(real64),save::Ntotuptake,Ptotuptake,DMcressur,Ncressurf,Pcressurf,DMcresbott,Ncresbott,Pcresbott
  real(real64),save::nishmi,nishma,niromi,niroma,poshmi,poshma,poromi,poroma
  logical::flCropExt,floutput
  character(10)::date
  character::comma
  if(first)then
   include 'original_initial.inc'
  end if
  t4=1d4;pnratio=.1d0;NH4_upt=uptake(1);NO3_upt=uptake(2)
  idwrt_1=dm(1);idwlv_1=dm(2);idwst_1=dm(3);idwso_1=dm(4)
  iNLOSSR_1=n(1);iNLOSSL_1=n(2);iNLOSSS_1=n(3);iNLOSSO_1=n(4)
  flCropExt=.true.;floutput=report;date='2000-01-01';comma=','
  include 'original_accumulate.inc'
  values=[Ntotuptake,Ptotuptake,DMcressur,Ncressurf,Pcressurf,DMcresbott,Ncresbott,Pcresbott]
  include 'original_report.inc'
  extrema=[nishmi,nishma,niromi,niroma,poshmi,poshma,poromi,poroma]
 end subroutine
end program
