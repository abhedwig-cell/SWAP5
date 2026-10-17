! Strict bounded single-file management + nutrient named export.
! Explicit sections are an export contract, not the original TTUTIL syntax.
module mod_soil_n_unified_input
 use iso_fortran_env,only:real64,iostat_end,iostat_eor
 use mod_soil_n_amendment_calendar,only:soil_n_amendment_calendar_t
 use mod_soil_n_amendment_input,only:parse_soil_n_amendment_tables,N_INPUT_OK
 use mod_soil_n_historical_activation,only:soil_n_historical_initial_t,soil_n_historical_rates_t
 use mod_soil_n_historical_named_input,only:parse_historical_soil_n_named_lines,N_NAMED_OK
 implicit none
 private
 integer,parameter,public::N_UNIFIED_OK=0,N_UNIFIED_INVALID=1,N_UNIFIED_IO=2
 public::read_soil_n_unified_export
contains
 subroutine read_soil_n_unified_export(path,origin,plan,initial,rates,status,error_line)
 character(*),intent(in)::path,origin
 type(soil_n_amendment_calendar_t),intent(out)::plan
 type(soil_n_historical_initial_t),intent(out)::initial
 type(soil_n_historical_rates_t),intent(out)::rates
 integer,intent(out)::status,error_line
 type(soil_n_amendment_calendar_t)::candidate_plan
 type(soil_n_historical_initial_t)::candidate_initial
 type(soil_n_historical_rates_t)::candidate_rates
 character(2048)::line
 character(2048)::tables(4096)
 character(512)::parameters(512)
 integer::unit,ios,read_size,close_code,section,nmat,nparam,code
 plan=soil_n_amendment_calendar_t();initial=soil_n_historical_initial_t()
 rates=soil_n_historical_rates_t();status=N_UNIFIED_IO;error_line=0
 nmat=0;nparam=0;section=0
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
 call parse_historical_soil_n_named_lines(parameters(:nparam),candidate_initial,candidate_rates,code,error_line)
 if(code/=N_NAMED_OK)then
   status=N_UNIFIED_INVALID;error_line=error_line+nmat+2;return
 end if
 plan=candidate_plan;initial=candidate_initial;rates=candidate_rates
 status=N_UNIFIED_OK;error_line=0
 end subroutine
end module
