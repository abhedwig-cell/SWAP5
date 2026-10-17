! Restricted named-field source export, NOT a full TTUTIL/SNM parser.
module mod_soil_n_historical_named_input
 use iso_fortran_env,only:real64,iostat_end,iostat_eor
 use ieee_arithmetic,only:ieee_is_finite
 use mod_soil_n_historical_activation,only:soil_n_historical_initial_t,soil_n_historical_rates_t
 implicit none
 private
 integer,parameter,public::N_NAMED_OK=0,N_NAMED_INVALID=1,N_NAMED_IO=2
 integer,parameter::COUNT=26
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
 'cNO3N_seep']
 public::read_historical_soil_n_named_export
contains
 subroutine read_historical_soil_n_named_export(path,initial,rates,status,error_line)
   character(*),intent(in)::path
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
   do
     ! Nonadvancing read rejects overlong records rather than truncating them.
     read(unit,'(A)',advance='no',size=read_size,iostat=ios)line
     if(ios==iostat_end)exit
     n=n+1
     if(ios/=iostat_eor.or.n>512)exit
     if(len_trim(line)==0.or.line(1:1)=='!')cycle
     pos=index(line,'=')
     if(pos<=1.or.pos>=len_trim(line))exit
     field=adjustl(line(:pos-1));token=adjustl(line(pos+1:))
     field_index=0
     do i=1,COUNT
       if(trim(field)==trim(names(i)))field_index=i
     end do
     if(field_index==0)exit
     if(seen(field_index))exit
     if(scan(trim(token),' /,;*!')/=0)exit
     if(len_trim(token)>32.or.len_trim(token)==0)exit
     ! Internal Fortran reads are bounded and nonfinite results are rejected.
     read(token,*,iostat=ios)x
     if(ios/=0)exit
     if(.not.ieee_is_finite(x).or.x<0d0.or.x>1d6)exit
     seen(field_index)=.true.;v(field_index)=x
   end do
   close(unit,iostat=close_code)
   if(ios/=iostat_end.or.close_code/=0.or..not.all(seen))then
     status=N_NAMED_INVALID;error_line=n
     return
   end if
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
   status=N_NAMED_OK
 end subroutine
end module
