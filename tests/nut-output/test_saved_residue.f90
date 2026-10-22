program test_saved_residue
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan,ieee_positive_inf
 use mod_soil_n_crop_extended_output
 use mod_crop_ext_saved_residue
 implicit none
 type(crop_ext_state_t)::output,previous,restored
 type(crop_ext_saved_residue_t)::saved,before,copy,empty
 type(crop_ext_row_t)::row,row2
 real(real64)::dm(4),n(4),up(2),v(9),w(9),o(17),x(17),expected(8),ext(8),old(8),bad(9),nan,inf
 integer::code,unit,day,schedule,checks,reports,i
 logical::ready,emit
 character(128)::line,original
 checks=0;reports=0
 nan=ieee_value(0d0,ieee_quiet_nan);inf=ieee_value(0d0,ieee_positive_inf)
 do schedule=1,9,2
  call initialize_crop_ext(0d0,output,code);call require(code==0,'initialize output')
  call restore_crop_ext_saved_residue([0d0,0d0,0d0,0d0,0d0,0d0,0d0,0d0,0d0],saved,code)
  call require(code==0,'initialize saved zeros')
  do day=1,130
   dm=[.123d0,.137d0,.179d0,.233d0]*day;n=dm*[.003d0,.007d0,.011d0,.017d0]
   ! A one-day pulse, followed by fallow zeros, must survive a report boundary
   ! and then contribute exactly once on the following accepted day.
   if(day==64)then
    dm=dm+[731d0,157d0,89d0,41d0];n=dm*.0123d0
   else if(day>64)then
    dm=0d0;n=0d0
   end if
   up=[1.23456789d-7,7.654321d-8]*day
   if(day>64)up=0d0
   emit=mod(day,schedule)==0.or.day==130
   before=saved;previous=output
   call observe_crop_ext_saved_residue(output,saved,real(day-1,real64),real(day,real64),up,dm,n,emit,row,code)
   call require(code==0,'accepted day')
   open(newunit=unit,status='scratch',action='readwrite')
   call original_step(day==1,up,dm,n,emit,unit,expected,ext,old)
   call saved%snapshot(v,ready)
   call require(ready.and.v(1)==day.and.bits(v(2:9),old),'source exact next-day values')
   call output%snapshot(o(1),o(2:9),o(10:17),ready)
   call require(ready.and.o(1)==day.and.bits(o(10:17),ext),'source exact clock extrema')
   if(emit)then
    reports=reports+1
    call require(row%emitted.and.bits(row%values,expected).and.all(o(2:9)==0d0),'source exact report/reset')
    call format_crop_ext_row('2000-01-01',row,line,code)
    rewind(unit);read(unit,'(a)')original
    call require(code==0.and.line==original,'literal formatted original report')
   else
    call require(.not.row%emitted.and.bits(o(2:9),expected),'source exact nonreport totals')
   end if
   close(unit)
   ! Use fresh reconstructed types every day, not just a copied private value.
   call restore_crop_ext(o,restored,code);call require(code==0,'restore output')
   call restore_crop_ext_saved_residue(v,copy,code);call require(code==0,'restore saved')
   call copy%snapshot(w,ready);call require(ready.and.bits(w,v),'exact saved snapshot roundtrip')
   output=restored;saved=copy
   call observe_crop_ext_saved_residue(output,saved,real(day-1,real64),real(day,real64),up,dm,n,emit,row2,code)
   call require(code/=0.and..not.row2%emitted,'duplicate day rejected')
   call unchanged('duplicate does not publish')
  end do
 end do
 do i=1,12
  bad=v
  select case(i)
  case(1);bad(1)=nan
  case(2);bad(1)=inf
  case(3);bad(1)=1d8+1d0
  case(4);bad(2)=-1d0
  case(5);bad(2)=1d6+1d0
  case(6);bad(2)=nan
  case(7);bad(2)=inf
  case(8);bad(6)=-1d0
  case(9);bad(6)=bad(2)+1d0
  case(10);bad(6)=nan
  case(11);bad(6)=inf
  case(12);bad(9)=1d0
  end select
  call restore_crop_ext_saved_residue(bad,saved,code)
  call require(code/=0,'invalid saved state rejected');call unchanged('invalid restore atomic')
 end do
 dm=0d0;n=0d0;up=0d0
 do i=1,9
  select case(i)
  case(1);call observe_crop_ext_saved_residue(output,saved,131d0,132d0,up,dm,n,.true.,row,code)
  case(2);call observe_crop_ext_saved_residue(output,saved,130d0,132d0,up,dm,n,.true.,row,code)
  case(3);call observe_crop_ext_saved_residue(output,saved,130d0,130d0,up,dm,n,.true.,row,code)
  case(4);call observe_crop_ext_saved_residue(output,saved,130d0,nan,up,dm,n,.true.,row,code)
  case(5);dm(1)=nan;call observe_crop_ext_saved_residue(output,saved,130d0,131d0,up,dm,n,.true.,row,code);dm=0d0
  case(6);n(4)=1d0;call observe_crop_ext_saved_residue(output,saved,130d0,131d0,up,dm,n,.true.,row,code);n=0d0
  case(7);up(1)=-1d0;call observe_crop_ext_saved_residue(output,saved,130d0,131d0,up,dm,n,.true.,row,code);up=0d0
  case(8)
   previous=output;call initialize_crop_ext(129d0,output,code)
   call observe_crop_ext_saved_residue(output,saved,130d0,131d0,up,dm,n,.true.,row,code)
   call output%snapshot(x(1),x(2:9),x(10:17),ready)
   call require(x(1)==129d0,'mismatched output remains untouched');output=previous
  case(9);call observe_crop_ext_saved_residue(output,empty,130d0,131d0,up,dm,n,.true.,row,code)
  end select
  call require(code/=0.and..not.row%emitted,'invalid day rejected');call unchanged('invalid day atomic')
 end do
 print '(A,I0,A,I0)','SAVED_RESIDUE_SOURCE_EXACT_PASS checks=',checks,' reports=',reports
contains
 logical function bits(a,b)
  real(real64),intent(in)::a(:),b(:)
  bits=all(transfer(a,[0_int64],size(a))==transfer(b,[0_int64],size(b)))
 end function
 subroutine unchanged(label)
  character(*),intent(in)::label
  call saved%snapshot(w,ready);call require(ready.and.bits(w,v),label//' saved')
  call output%snapshot(x(1),x(2:9),x(10:17),ready);call require(ready.and.bits(x,o),label//' output')
 end subroutine
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then
   print *,'FAIL ',label;error stop 1
  end if
  checks=checks+1
 end subroutine
 subroutine original_step(first,uptake,dm,n,report,cropext,values,extrema,saved_values)
  logical,intent(in)::first,report
  real(real64),intent(in)::uptake(2),dm(4),n(4)
  integer,intent(in)::cropext
  real(real64),intent(out)::values(8),extrema(8),saved_values(8)
  real(real64)::t4,pnratio,NH4_upt,NO3_upt,idwlv,idwst,idwso,idwrt,iNLOSSL,iNLOSSS,iNLOSSO,iNLOSSR
  real(real64),save::idwlv_1,idwst_1,idwso_1,idwrt_1,iNLOSSL_1,iNLOSSS_1,iNLOSSO_1,iNLOSSR_1
  real(real64),save::Ntotuptake,Ptotuptake,DMcressur,Ncressurf,Pcressurf,DMcresbott,Ncresbott,Pcresbott
  real(real64),save::nishmi,nishma,niromi,niroma,poshmi,poshma,poromi,poroma
  logical::flCropExt,floutput
  character(10)::date
  character::comma
  if(first)then
   include 'original_initial.inc'
   idwrt_1=0d0;idwlv_1=0d0;idwst_1=0d0;idwso_1=0d0
   iNLOSSR_1=0d0;iNLOSSL_1=0d0;iNLOSSS_1=0d0;iNLOSSO_1=0d0
  end if
  t4=1d4;pnratio=.1d0;NH4_upt=uptake(1);NO3_upt=uptake(2)
  idwrt=dm(1);idwlv=dm(2);idwst=dm(3);idwso=dm(4)
  iNLOSSR=n(1);iNLOSSL=n(2);iNLOSSS=n(3);iNLOSSO=n(4)
  flCropExt=.true.;floutput=report;date='2000-01-01';comma=','
  include 'original_accumulate.inc'
  include 'original_saved.inc'
  values=[Ntotuptake,Ptotuptake,DMcressur,Ncressurf,Pcressurf,DMcresbott,Ncresbott,Pcresbott]
  saved_values=[idwrt_1,idwlv_1,idwst_1,idwso_1,iNLOSSR_1,iNLOSSL_1,iNLOSSS_1,iNLOSSO_1]
  include 'original_report.inc'
  extrema=[nishmi,nishma,niromi,niroma,poshmi,poshma,poromi,poroma]
 end subroutine
end program
