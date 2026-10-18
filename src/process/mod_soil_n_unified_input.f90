! Strict bounded single-file management + nutrient named export.
! Explicit sections are an export contract, not the original TTUTIL syntax.
module mod_soil_n_unified_input
 use iso_fortran_env,only:real64,iostat_end,iostat_eor
 use mod_soil_n_amendment_calendar,only:soil_n_amendment_calendar_t
 use mod_soil_n_amendment_input,only:parse_soil_n_amendment_tables,N_INPUT_OK
 use mod_soil_n_historical_activation,only:soil_n_historical_initial_t,soil_n_historical_rates_t
 use mod_soil_n_historical_named_input,only:parse_historical_soil_n_named_lines,N_NAMED_OK,soil_n_residue_age_t
 implicit none
 private
 integer,parameter,public::N_UNIFIED_OK=0,N_UNIFIED_INVALID=1,N_UNIFIED_IO=2
 public::read_soil_n_unified_export,read_soil_n_snm_keyword_file
contains
 subroutine read_soil_n_unified_export(path,origin,plan,initial,rates,status,error_line,ages)
 character(*),intent(in)::path,origin
 type(soil_n_residue_age_t),intent(out),optional::ages
 type(soil_n_amendment_calendar_t),intent(out)::plan
 type(soil_n_historical_initial_t),intent(out)::initial
 type(soil_n_historical_rates_t),intent(out)::rates
 integer,intent(out)::status,error_line
 type(soil_n_amendment_calendar_t)::candidate_plan
 type(soil_n_historical_initial_t)::candidate_initial
 type(soil_n_historical_rates_t)::candidate_rates
 type(soil_n_residue_age_t)::candidate_ages
 character(2048)::line
 character(2048)::tables(4096)
 character(512)::parameters(512)
 integer::unit,ios,read_size,close_code,section,nmat,nparam,code
 plan=soil_n_amendment_calendar_t();initial=soil_n_historical_initial_t()
 rates=soil_n_historical_rates_t();status=N_UNIFIED_IO;error_line=0
 if(present(ages))ages=soil_n_residue_age_t()
 nmat=0;nparam=0;section=0
 ! The source-grounded bounded .snm keyword-array route is distinct from
 ! the bracketed modern export contract. No hidden grammar autodetection.
 if(len_trim(path)>=4)then
  if(path(len_trim(path)-3:len_trim(path))=='.snm')then
   call read_soil_n_snm_keyword_file(path,origin,plan,initial,rates,status,error_line,ages)
   return
  end if
 end if
 open(newunit=unit,file=path,status='old',action='read',iostat=ios)
 if(ios/=0)return
 do
   read(unit,'(A)',advance='no',size=read_size,iostat=ios)line
   if(ios==iostat_end)exit
   error_line=error_line+1
   if(ios/=iostat_eor)exit
   if(trim(adjustl(line))=='[management]'.and.section==0)then
     section=1;cycle
   end if
   if(trim(adjustl(line))=='[soil_n_parameters]'.and.section==1)then
     section=2;cycle
   end if
   if(section==1)then
     if(nmat==4096)exit
     nmat=nmat+1;tables(nmat)=line
   else if(section==2)then
     if(nparam==512.or.len_trim(line)>512)exit
     nparam=nparam+1;parameters(nparam)=line
   else
     exit
   end if
 end do
 close(unit,iostat=close_code)
 if(ios/=iostat_end.or.close_code/=0.or.section/=2.or.nmat==0.or.nparam==0)then
   status=N_UNIFIED_INVALID;return
 end if
 call parse_soil_n_amendment_tables(tables(:nmat),origin,candidate_plan,code,error_line)
 if(code/=N_INPUT_OK)then
   status=N_UNIFIED_INVALID;return
 end if
 call parse_historical_soil_n_named_lines(parameters(:nparam),candidate_initial,candidate_rates,code,error_line,candidate_ages)
 if(code/=N_NAMED_OK)then
   status=N_UNIFIED_INVALID;error_line=error_line+nmat+2;return
 end if
 plan=candidate_plan;initial=candidate_initial;rates=candidate_rates
 if(present(ages))ages=candidate_ages
 status=N_UNIFIED_OK;error_line=0
 end subroutine

 ! Bounded keyword-array subset of original management_soil.f90 rdainr/
 ! rdfcha/rdatim/rdfinr/rdfdor input calls, not a claim of full TTUTIL syntax.
 ! All 11 management arrays must be complete, single-line, and equal-sized.
 ! Source nutrient scalars retain existing strict named-export validation.
 subroutine read_soil_n_snm_keyword_file(path,origin,plan,initial,rates,status,error_line,ages)
  character(*),intent(in)::path,origin
  type(soil_n_amendment_calendar_t),intent(out)::plan
  type(soil_n_historical_initial_t),intent(out)::initial
  type(soil_n_historical_rates_t),intent(out)::rates
  integer,intent(out)::status,error_line
  type(soil_n_residue_age_t),intent(out),optional::ages
  character(16),parameter::keys(11)=[character(16):: &
   'MatNum','MatName','AppAge','OrgMatFrac','OrgNFrac','NH4NFrac','NO3NFrac', &
   'smedate','iMat','Dosagekgha','VolatFraction']
  character(256),allocatable::values(:,:)
  character(2048),allocatable::rows(:)
  character(512)::parameters(512),line
  character(256)::word,field,chunk(1000)
  integer::value_line(11,1000),active_key,header(11),newheader(11),nh,col,idx
  logical::is_header
  integer::nvalues(11),nparam,nmat,nevt,unit,ios,nbytes,code,closed,record,j,k,eq,nt
  integer::parameter_source_line(512),parameter_error_line
  logical::ok
  type(soil_n_amendment_calendar_t)::candidate_plan
  type(soil_n_historical_initial_t)::candidate_initial
  type(soil_n_historical_rates_t)::candidate_rates
  type(soil_n_residue_age_t)::candidate_ages
  plan=soil_n_amendment_calendar_t();initial=soil_n_historical_initial_t()
  rates=soil_n_historical_rates_t();candidate_ages=soil_n_residue_age_t()
  if(present(ages))ages=soil_n_residue_age_t()
  status=N_UNIFIED_IO;error_line=0
  allocate(values(11,1000),rows(1002));values='';rows='';parameters=''
  nvalues=-1;nparam=0;record=0;active_key=0;nh=0;value_line=0
  open(newunit=unit,file=path,status='old',action='read',iostat=ios)
  if(ios/=0)return
  status=N_UNIFIED_INVALID
  do
   read(unit,'(A)',advance='no',size=nbytes,iostat=ios)line
   if(ios==iostat_end)exit
   record=record+1;error_line=record
   if(ios/=iostat_eor)exit
   word=adjustl(line)
   if(len_trim(word)==0.or.word(1:1)=='!'.or.word(1:1)=='*')cycle
   eq=index(line,'=')
   if(eq==0)then
    if(trim(word)==';')then
     active_key=0;nh=0;cycle
    end if
    call read_snm_array_line(trim(line),chunk,nt,ok)
    if(.not.ok.or.nt==0)exit
    is_header=.true.
    do col=1,nt
     if(col>11)then
      is_header=.false.;exit
     end if
     newheader(col)=snm_key(chunk(col),keys)
     if(newheader(col)==0)is_header=.false.
    end do
    if(is_header)then
     header=newheader
     ! TTUTIL table columns are named identifiers, independently of order.
     if(nt/=7.and.nt/=4)exit
     if(nt==7.and.any(newheader(:nt)>7))exit
     if(nt==4.and.any(newheader(:nt)<8))exit
     do col=1,nt
      idx=header(col)
      if(nvalues(idx)/=-1)exit
      nvalues(idx)=0
     end do
     if(col<=nt)exit
     nh=nt;active_key=0;cycle
    end if
    if(nh>0)then
     if(nt/=nh)exit
     do col=1,nh
      idx=header(col)
      if(nvalues(idx)==1000)exit
      nvalues(idx)=nvalues(idx)+1
      values(idx,nvalues(idx))=chunk(col);value_line(idx,nvalues(idx))=record
     end do
     if(col<=nh)exit
    else
     if(active_key==0)exit
     if(nvalues(active_key)+nt>1000)exit
     j=nvalues(active_key)
     values(active_key,j+1:j+nt)=chunk(:nt)
     value_line(active_key,j+1:j+nt)=record
     nvalues(active_key)=j+nt
    end if
   else
    if(eq<=1.or.eq>256)exit
    nh=0
    field=adjustl(line(:eq-1));j=snm_key(field,keys)
    if(j>0)then
     if(nvalues(j)/=-1)exit
     call read_snm_array_line(line(eq+1:),values(j,:),nt,ok)
     if(.not.ok)exit
     nvalues(j)=nt;value_line(j,:nt)=record;active_key=j
    else
     active_key=0
     if(nparam==512.or.len_trim(line)>512)exit
     nparam=nparam+1;parameters(nparam)=line
     parameter_source_line(nparam)=record
    end if
   end if
  end do
  close(unit,iostat=closed)
  if(ios/=iostat_end.or.closed/=0)return
  if(any(nvalues<0).or.nparam==0)return
  nmat=nvalues(1);nevt=nvalues(8)
  if(nmat<1.or.nmat>20.or.nevt>1000)return
  if(any(nvalues(2:7)/=nmat).or.any(nvalues(9:11)/=nevt))return
  rows(1)='MatNum MatName AppAge OrgMatFrac OrgNFrac NH4NFrac NO3NFrac'
  do k=1,nmat
   rows(k+1)=trim(values(1,k))//' '//trim(values(2,k))//' '//trim(values(3,k))// &
    ' '//trim(values(4,k))//' '//trim(values(5,k))//' '//trim(values(6,k))//' '//trim(values(7,k))
  end do
  rows(nmat+2)='smedate iMat Dosagekgha VolatFraction'
  if(nmat+2+nevt>size(rows))return
  do k=1,nevt
   rows(nmat+2+k)=trim(values(8,k))//' '//trim(values(9,k))//' '// &
      trim(values(10,k))//' '//trim(values(11,k))
  end do
  call parse_soil_n_amendment_tables(rows(:nmat+2+nevt),origin,candidate_plan,code,error_line)
  if(code/=N_INPUT_OK)then
   ! A normalized row retains the physical table row / first array item line.
   if(error_line>=2.and.error_line<=nmat+1)then
    error_line=value_line(1,error_line-1)
   else if(error_line>=nmat+3.and.error_line<=nmat+2+nevt)then
    error_line=value_line(8,error_line-nmat-2)
   end if
   return
  end if
  call parse_historical_soil_n_named_lines(parameters(:nparam),candidate_initial, &
    candidate_rates,code,parameter_error_line,candidate_ages,native_snm=.true.)
  if(code/=N_NAMED_OK)then
    ! The named parser counts only extracted nutrient fields. Report the
    ! physical source file record instead, including interleaved TTUTIL arrays.
    if(parameter_error_line>=1.and.parameter_error_line<=nparam) &
      error_line=parameter_source_line(parameter_error_line)
    return
  end if
  plan=candidate_plan;initial=candidate_initial;rates=candidate_rates
  if(present(ages))ages=candidate_ages
  status=N_UNIFIED_OK;error_line=0
 end subroutine

 pure function snm_lower(s)result(v)
  character(*),intent(in)::s
  character(len(s))::v
  integer::i,c
  v=s
  do i=1,len(s)
   c=iachar(s(i:i));if(c>=65.and.c<=90)v(i:i)=achar(c+32)
  end do
 end function
 integer function snm_key(field,keys)result(j)
  character(*),intent(in)::field,keys(:)
  integer::k
  j=0
  do k=1,size(keys)
   if(trim(snm_lower(field))==trim(snm_lower(keys(k))))j=k
  end do
 end function

 subroutine read_snm_array_line(line,words,n,ok)
  ! Strict comma/whitespace tokens, with single or double quoted names.
  character(*),intent(in)::line
  character(256),intent(out)::words(:)
  integer,intent(out)::n
  logical,intent(out)::ok
  integer::i,j,k,l
  character::quote
  logical::need_value,has_value
  n=0;ok=.false.;words='';l=len_trim(line);i=1
  need_value=.false.;has_value=.false.
  do while(i<=l)
   if(line(i:i)==' '.or.line(i:i)==achar(9))then
    i=i+1;cycle
   end if
   if(line(i:i)=='!')exit
   if(line(i:i)==',')then
    ! Empty elements and consecutive/trailing separators must not silently
    ! change the historic material or event array cardinality.
    if(.not.has_value.or.need_value)return
    need_value=.true.;has_value=.false.;i=i+1;cycle
   end if
   if(n==size(words))return
   n=n+1;j=i
   if(line(i:i)==achar(39).or.line(i:i)=='"')then
    quote=line(i:i);i=i+1
    do while(i<=l)
     if(line(i:i)==quote)exit
     i=i+1
    end do
    if(i>l)return
    i=i+1
   else
    do while(i<=l)
     if(line(i:i)==' '.or.line(i:i)==achar(9).or.line(i:i)==','.or.line(i:i)=='!')exit
     i=i+1
    end do
   end if
   k=i-j
   if(k<1.or.k>256)return
   words(n)=line(j:i-1)
   if(i<=l)then
    if(line(i:i)=='!')then
     has_value=.true.;need_value=.false.;exit
    end if
    if(line(i:i)/=' '.and.line(i:i)/=achar(9).and.line(i:i)/=',')return
   end if
   has_value=.true.;need_value=.false.
  end do
  if(need_value)return
  ok=.true.
 end subroutine
end module
