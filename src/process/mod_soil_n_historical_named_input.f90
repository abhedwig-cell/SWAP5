! Restricted named-field source export, NOT a full TTUTIL/SNM parser.
module mod_soil_n_historical_named_input
 use iso_fortran_env,only:real64,iostat_end,iostat_eor
 use ieee_arithmetic,only:ieee_is_finite
 use mod_soil_n_amendment_input,only:parse_soil_n_date
 use mod_soil_n_historical_activation,only:soil_n_historical_initial_t,soil_n_historical_rates_t
 implicit none
 private
 integer,parameter,public::N_NAMED_OK=0,N_NAMED_INVALID=1,N_NAMED_IO=2
 integer,parameter::COUNT=35
 character(32),parameter::names(COUNT)=[character(32):: &
 'FOM1_t', &
 'FOM2_t', &
 'FOM3_t', &
 'FOM4_t', &
 'FOM5_t', &
 'FOM6_t', &
 'FOM7_t', &
 'FOM8_t', &
 'Bio_t', &
 'Hum_t', &
 'cNH4_t', &
 'cNO3_t', &
 'Temp_ref', &
 'SorpCoef', &
 'RateConNitrif_ref', &
 'RateConDenitr_ref', &
 'WFPSCrit', &
 'WFPScrit2', &
 'CdissiHalf', &
 'TCSF_N', &
 'LaiCritNupt', &
 'dz_WSN', &
 'cNH4N_lat', &
 'cNO3N_lat', &
 'cNH4N_seep', &
 'cNO3N_seep', &
 'AppAgeRt', &
 'AppAgeLv', &
 'AppAgeSt', &
 'AppAgeSo', &
 'cNH4N_top','cNO3N_top','RateconHum_exp','tstartHumexp','flCropExt']
 type,public::soil_n_residue_age_t
   real(real64)::root=1.27d0,leaf=.99d0,stem=1.27d0,storage=1.27d0
 end type
 public::read_historical_soil_n_named_export,parse_historical_soil_n_named_lines
contains
 subroutine read_historical_soil_n_named_export(path,initial,rates,status,error_line,ages)
   character(*),intent(in)::path
   type(soil_n_residue_age_t),intent(out),optional::ages
   type(soil_n_historical_initial_t),intent(out)::initial
   type(soil_n_historical_rates_t),intent(out)::rates
   integer,intent(out)::status,error_line
   type(soil_n_historical_initial_t)::candidate_initial
   type(soil_n_historical_rates_t)::candidate_rates
   character(512)::line,field,token
   logical::seen(COUNT)
   real(real64)::v(COUNT),x
   integer::unit,ios,n,pos,field_index,i,close_code,read_size
   initial=soil_n_historical_initial_t();rates=soil_n_historical_rates_t()
   status=N_NAMED_IO;error_line=0;seen=.false.;v=0d0
   open(newunit=unit,file=path,status='old',action='read',iostat=ios)
   if(ios/=0)return
   n=0
   block
     character(512)::lines(512)
     lines=''
     do
       if(n==512)then
         read(unit,'(A)',iostat=ios)line
         if(ios/=iostat_end)exit
         exit
       end if
       read(unit,'(A)',advance='no',size=read_size,iostat=ios)line
       if(ios==iostat_end)exit
       if(ios/=iostat_eor)exit
       n=n+1;lines(n)=line
     end do
     close(unit,iostat=close_code)
     if(ios/=iostat_end.or.close_code/=0)then
       status=N_NAMED_INVALID;error_line=n+1;return
     end if
     call parse_historical_soil_n_named_lines(lines(:n),initial,rates,status,error_line,ages)
   end block
 end subroutine
 subroutine parse_historical_soil_n_named_lines(lines,initial,rates,status,error_line,ages,native_snm)
   character(*),intent(in)::lines(:)
   type(soil_n_residue_age_t),intent(out),optional::ages
   type(soil_n_historical_initial_t),intent(out)::initial
   type(soil_n_historical_rates_t),intent(out)::rates
   integer,intent(out)::status,error_line
   character(512)::line,field,token
   logical,intent(in),optional::native_snm
   logical::native
   logical::seen(COUNT)
   real(real64)::v(COUNT),x
   integer::i,n,pos,field_index,ios,comment,j,c
   character(32)::name_lower
   integer::source_line(COUNT)
   initial=soil_n_historical_initial_t();rates=soil_n_historical_rates_t()
   status=N_NAMED_INVALID;error_line=0;seen=.false.;v=0d0
   if(present(ages))ages=soil_n_residue_age_t()
   native=.false.;if(present(native_snm))native=native_snm
   source_line=0
   if(size(lines)>512)return
   do n=1,size(lines)
     error_line=n
     if(len(lines(n))>512)return
     line=adjustl(lines(n))
     if(len_trim(line)==0.or.line(1:1)=='!')cycle
     if(native)then
      if(line(1:1)=='*')cycle
      comment=index(line,'!');if(comment>0)line=line(:comment-1)
     end if
     pos=index(line,'=')
     if(pos<=1.or.pos>=len_trim(line))return
     field=adjustl(line(:pos-1));token=adjustl(line(pos+1:))
     field_index=0
     do i=1,COUNT
       if(native)then
        name_lower=names(i)
        do j=1,len_trim(name_lower)
         c=iachar(name_lower(j:j));if(c>=65.and.c<=90)name_lower(j:j)=achar(c+32)
        end do
        token=adjustl(line(pos+1:))
        block
         character(512)::field_lower
         field_lower=field
         do j=1,len_trim(field_lower)
          c=iachar(field_lower(j:j));if(c>=65.and.c<=90)field_lower(j:j)=achar(c+32)
         end do
         if(trim(field_lower)==trim(name_lower))field_index=i
        end block
       else
        if(trim(field)==trim(names(i)))field_index=i
       end if
     end do
     if(field_index==0)return
     if(seen(field_index))return
     if(scan(trim(token),' /,;*!')/=0)return
     if(len_trim(token)>32.or.len_trim(token)==0)return
     if(native.and.field_index==35)then
      ! Original rdslog accepts .FALSE. case-insensitively. Explicit false
      ! is equivalent to omission; true requires the unadmitted output owner.
      do j=1,len_trim(token)
       c=iachar(token(j:j));if(c>=65.and.c<=90)token(j:j)=achar(c+32)
      end do
      if(trim(token)/='.false.')return
      x=0d0
     else if(native.and.field_index==34)then
      call parse_soil_n_date(trim(token),x,ios)
      if(ios/=0)return
     else
      if(native.and.scan(trim(token),'.eEdD')==0)return
      read(token,*,iostat=ios)x
      if(ios/=0)return
      if(.not.ieee_is_finite(x).or.x<0d0.or.x>1d6)return
     end if
     if(native)then
      ! management_soil.f90 rdsdor source ranges. Physical activation has
      ! additional admissibility constraints; those are not historical defaults.
      if(field_index<=20.or.field_index>=22.and.field_index<=26.or.field_index>=31.and.field_index<=32)then
       if(x>1000d0)return
      end if
      if(field_index==33.and.x>100d0)return
      if(field_index==21.and.x>10d0)return
      if(field_index>=27.and.field_index<=30.and.x>100d0)return
      ! The two top concentrations have an explicit immutable owner binding.
     else
      if(field_index>=31)return
     end if
     source_line(field_index)=n
     seen(field_index)=.true.;v(field_index)=x
   end do
   if(any(.not.seen(:20)).or.any(.not.seen(22:26)))return
   if(native)then
    if(any(.not.seen(31:32)))return
    if(seen(33).neqv.seen(34))then
     error_line=max(source_line(33),source_line(34));return
    end if
   end if
   if(any(seen(27:30).and.v(27:30)>100d0))return
   initial%fom_kg_m3(1)=v(1)
   initial%fom_kg_m3(2)=v(2)
   initial%fom_kg_m3(3)=v(3)
   initial%fom_kg_m3(4)=v(4)
   initial%fom_kg_m3(5)=v(5)
   initial%fom_kg_m3(6)=v(6)
   initial%fom_kg_m3(7)=v(7)
   initial%fom_kg_m3(8)=v(8)
   initial%bio_kg_m3=v(9)
   initial%hum_kg_m3=v(10)
   initial%cnh4_kg_m3=v(11)
   initial%cno3_kg_m3=v(12)
   rates%temp_ref=v(13)
   rates%sorpcoef=v(14)
   rates%ratecon_nitrif_ref=v(15)
   rates%ratecon_denitr_ref=v(16)
   rates%wfpscrit=v(17)
   rates%wfpscrit2=v(18)
   rates%cdissi_half=v(19)
   rates%tcsf_n=v(20)
   rates%lai_crit_nupt=v(21)
   rates%depth_m=v(22)
   rates%nh4_lat=v(23)
   rates%no3_lat=v(24)
   rates%nh4_seep=v(25)
   rates%no3_seep=v(26)
   rates%nh4_top=v(31);rates%no3_top=v(32)
   if(seen(33))then
    rates%hum_exp_per_year=v(33);rates%hum_exp_start_day=v(34)
   end if
   if(present(ages))then
     if(seen(27))ages%root=v(27)
     if(seen(28))ages%leaf=v(28)
     if(seen(29))ages%stem=v(29)
     if(seen(30))ages%storage=v(30)
   end if
   status=N_NAMED_OK;error_line=0
 end subroutine
end module
