! Explicit bounded management-table export input; no accepted physical state.
module mod_soil_n_amendment_input
 use iso_fortran_env,only:real64,iostat_end,iostat_eor
 use ieee_arithmetic,only:ieee_is_finite
 use mod_b111_soil_n_addition,only:b111_soil_n_material_t
 use mod_soil_n_amendment_calendar,only:soil_n_amendment_calendar_t,create_soil_n_amendment_calendar
 implicit none
 private
 integer,parameter,public::N_INPUT_OK=0,N_INPUT_INVALID=1,N_INPUT_IO=2
 integer,parameter::WIDTH=2048,MAX_LINES=4096
 public::read_soil_n_amendment_tables,parse_soil_n_amendment_tables,parse_soil_n_date
contains
 pure elemental function lower(s)result(v)
  character(*),intent(in)::s
  character(len(s))::v
  integer::i,k
  v=s
  do i=1,len(s)
   k=iachar(s(i:i));if(k>=65.and.k<=90)v(i:i)=achar(k+32)
  end do
 end function
 pure subroutine parse_soil_n_date(s,day,status)
  character(*),intent(in)::s
  real(real64),intent(out)::day
  integer,intent(out)::status
  integer::year,month,date,i,j,y,days,ios,md(12)
  character(9)::digits
  character(36),parameter::months='janfebmaraprmayjunjulaugsepoctnovdec'
  day=0d0;status=N_INPUT_INVALID
  if(len_trim(s)==10)then
   if(s(5:5)/='-'.or.s(8:8)/='-')return
   digits=s(1:4)//s(6:7)//s(9:10)//'0'
   do i=1,8
    if(index('0123456789',digits(i:i))==0)return
   end do
   read(s(1:4),'(I4)',iostat=ios)year;if(ios/=0)return
   read(s(6:7),'(I2)',iostat=ios)month;if(ios/=0)return
   read(s(9:10),'(I2)',iostat=ios)date;if(ios/=0)return
  else if(len_trim(s)==11)then
   if(s(3:3)/='-'.or.s(7:7)/='-')return
   digits=s(1:2)//s(8:11)//'000'
   do i=1,6
    if(index('0123456789',digits(i:i))==0)return
   end do
   month=0
   do j=1,12
    if(lower(s(4:6))==months(3*j-2:3*j))month=j
   end do
   read(s(1:2),'(I2)',iostat=ios)date;if(ios/=0)return
   read(s(8:11),'(I4)',iostat=ios)year;if(ios/=0)return
  else
   return
  end if
  if(year<1900.or.year>9999.or.month<1.or.month>12)return
  md=[31,28,31,30,31,30,31,31,30,31,30,31]
  if(mod(year,4)==0.and.(mod(year,100)/=0.or.mod(year,400)==0))md(2)=29
  if(date<1.or.date>md(month))return
  y=year-1
  days=365*(year-1900)+(y/4-1899/4)-(y/100-1899/100)+(y/400-1899/400)
  if(month>1)days=days+sum(md(:month-1))
  day=real(days+date-1,real64);status=N_INPUT_OK
 end subroutine
 subroutine tokens(line,words,quoted,n,ok)
  character(*),intent(in)::line
  character(256),intent(out)::words(8)
  logical,intent(out)::quoted(8),ok
  integer,intent(out)::n
  integer::i,j,k,l
  character::q,c
  logical::after_comma
  words='';quoted=.false.;n=0;ok=.false.;i=1;l=len_trim(line);after_comma=.false.
  if(l>=WIDTH)return
  if(l>0)then
   if(line(1:1)=='*')then;ok=.true.;return;end if
  end if
  do while(i<=l)
   c=line(i:i)
   if(c==' '.or.c==achar(9))then;i=i+1;cycle;end if
   if(c=='!')exit
   if(c==','.or.n==8)return
   n=n+1;after_comma=.false.;j=0
   if(c==achar(39).or.c=='"')then
    quoted(n)=.true.;q=c;i=i+1;k=i
    do while(i<=l)
     if(line(i:i)==q)exit
     if(iachar(line(i:i))<32.or.iachar(line(i:i))>126)return
     i=i+1
    end do
    if(i>l)return
    j=i-k;if(j>256)return
    words(n)=line(k:i-1);i=i+1
   else
    k=i
    do while(i<=l)
     c=line(i:i)
     if(c==' '.or.c==achar(9).or.c==','.or.c=='!')exit
     if(iachar(c)<33.or.iachar(c)>126)return
     i=i+1
    end do
    j=i-k;if(j>256)return
    words(n)=line(k:i-1)
   end if
   if(i<=l)then
    c=line(i:i)
    if(c/=' '.and.c/=achar(9).and.c/=','.and.c/='!')return
   end if
   do while(i<=l)
    c=line(i:i);if(c/=' '.and.c/=achar(9))exit
    i=i+1
   end do
   if(i<=l)then
    if(line(i:i)==',')then;after_comma=.true.;i=i+1;end if
   end if
  end do
  if(after_comma)return
  ok=.true.
 end subroutine
 logical function number(s,v)result(ok)
  character(*),intent(in)::s
  real(real64),intent(out)::v
  integer::i,n,nd,ne,ios
  v=0d0;ok=.false.;n=len_trim(s);i=1;nd=0;ne=0
  if(n==0.or.n>40)return
  if(s(i:i)=='+'.or.s(i:i)=='-')i=i+1
  do while(i<=n)
   if(index('0123456789',s(i:i))==0)exit
   nd=nd+1;i=i+1
  end do
  if(i<=n)then
   if(s(i:i)=='.')then
    i=i+1
    do while(i<=n)
     if(index('0123456789',s(i:i))==0)exit
     nd=nd+1;i=i+1
    end do
   end if
  end if
  if(nd==0.or.nd>20)return
  if(i<=n)then
   if(index('eEdD',s(i:i))==0)return
   i=i+1
   if(i<=n)then
    if(s(i:i)=='+'.or.s(i:i)=='-')i=i+1
   end if
   do while(i<=n)
    if(index('0123456789',s(i:i))==0)return
    ne=ne+1;i=i+1
   end do
   if(ne==0.or.ne>3)return
   ! Bound exponent before internal numeric conversion, even with FPE traps.
   block
    integer::exponent,e,start
    start=scan(lower(trim(s)),'ed')+1
    read(s(start:),*,iostat=ios)exponent
    if(ios/=0)return
    e=abs(exponent);if(e>100)return
   end block
  end if
  if(i/=n+1)return
  read(s,*,iostat=ios)v;if(ios/=0)return
  ok=ieee_is_finite(v)
 end function
 logical function position(s,v)result(ok)
  character(*),intent(in)::s
  integer,intent(out)::v
  integer::i,ios,n
  v=0;ok=.false.;n=len_trim(s)
  if(n<1.or.n>4)return
  do i=1,n
   if(index('0123456789',s(i:i))==0)return
  end do
  read(s,*,iostat=ios)v;ok=ios==0
 end function
 recursive subroutine parse_soil_n_amendment_tables(lines,origin_text,plan,status,error_line,error_column)
  character(*),intent(in)::lines(:),origin_text
  type(soil_n_amendment_calendar_t),intent(out)::plan
  integer,intent(out)::status,error_line
  integer,intent(out),optional::error_column
  type(b111_soil_n_material_t)::defs(20),selected(1000)
  real(real64)::dates(1000),doses(1000),origin,v(5),vol
  character(256)::w(8)
  character(12),parameter::material_header(7)=[character(12)::'matnum','matname','appage','orgmatfrac','orgnfrac','nh4nfrac','no3nfrac']
  character(16),parameter::event_header(4)=[character(16)::'smedate','imat','dosagekgha','volatfraction']
  integer::line,n,section,nmat,nevent,id,j,code
  logical::q(8),ok
  plan=soil_n_amendment_calendar_t();status=N_INPUT_INVALID;error_line=0
  if(present(error_column))error_column=1
  if(size(lines)>MAX_LINES)return
  call parse_soil_n_date(trim(origin_text),origin,code);if(code/=0)return
  section=0;nmat=0;nevent=0
  do line=1,size(lines)
   error_line=line
   call tokens(lines(line),w,q,n,ok);if(.not.ok)return
   if(n==0)cycle
   if(section==0)then
    if(n/=7.or.any(q))return
    if(any(lower(w(:7))/=material_header))return
    section=1;cycle
   end if
   if(section==1.and.lower(w(1))=='smedate')then
    if(n/=4.or.any(q).or.nmat==0)return
    if(any(lower(w(:4))/=event_header))return
    section=2;cycle
   end if
   if(section==1)then
    if(n/=7.or.nmat==20)return
    if(.not.q(2).or.any(q(3:7)).or.q(1))return
    if(present(error_column))error_column=2
    if(len_trim(w(2))<1.or.len_trim(w(2))>25)return
    if(present(error_column))error_column=1
    if(.not.position(w(1),id))return
    if(id/=nmat+1)return
    do j=1,5
     if(present(error_column))error_column=j+2
     if(.not.number(w(j+2),v(j)))return
     if(j==1)then
      if(v(j)<0d0.or.v(j)>100d0)return
     else
      if(v(j)<0d0.or.v(j)>1d0)return
     end if
    end do
    if(v(1)<0d0.or.v(1)>100d0.or.any(v(2:5)<0d0).or.any(v(2:5)>1d0))return
    nmat=nmat+1
    defs(nmat)=b111_soil_n_material_t(0d0,v(1),v(2),v(3),v(4),v(5),0d0)
   else
    if(n/=4.or.any(q).or.nevent==1000)return
    if(present(error_column))error_column=2
    if(.not.position(w(2),id))return
    if(id<1.or.id>nmat)return
    nevent=nevent+1
    if(present(error_column))error_column=1
    call parse_soil_n_date(trim(w(1)),dates(nevent),code);if(code/=0)return
    if(present(error_column))error_column=3
    if(.not.number(w(3),doses(nevent)))return
    if(doses(nevent)<0d0.or.doses(nevent)>5d5)return
    if(present(error_column))error_column=4
    if(.not.number(w(4),vol))return
    if(vol<0d0.or.vol>1d0)return
    selected(nevent)=defs(id);selected(nevent)%volatilization_fraction=vol
   end if
  end do
  if(section/=2)return
  call create_soil_n_amendment_calendar(origin,dates(:nevent),doses(:nevent),selected(:nevent),plan,code)
  if(code/=0)return
  status=N_INPUT_OK;error_line=0
 end subroutine
 subroutine read_soil_n_amendment_tables(path,origin_text,plan,status,error_line)
  character(*),intent(in)::path,origin_text
  type(soil_n_amendment_calendar_t),intent(out)::plan
  integer,intent(out)::status,error_line
  character(WIDTH),allocatable::lines(:)
  integer::unit,ios,n,count,close_status
  plan=soil_n_amendment_calendar_t();status=N_INPUT_IO;error_line=0
  open(newunit=unit,file=path,status='old',action='read',iostat=ios);if(ios/=0)return
  allocate(lines(MAX_LINES));n=0
  do
   if(n==MAX_LINES)then
    block
     character::extra
     read(unit,'(A)',iostat=ios)extra
    end block
    if(ios==iostat_end)exit
    close(unit,iostat=close_status);status=N_INPUT_INVALID;error_line=n+1;return
   end if
   ! Nonadvancing read makes an overlong record observable, never truncates it.
   read(unit,'(A)',advance='no',size=count,iostat=ios)lines(n+1)
   if(ios==iostat_end)exit
   if(ios/=iostat_eor)then
    close(unit,iostat=close_status);error_line=n+1
    if(ios==0)status=N_INPUT_INVALID
    return
   end if
   n=n+1
  end do
  close(unit,iostat=ios);if(ios/=0)return
  call parse_soil_n_amendment_tables(lines(:n),origin_text,plan,status,error_line)
 end subroutine
end module
