! Mechanically extracted B1.11 wofostnut.f90 lines279-311, no equation edits.
! Original SHA256071e65763be9e771b32b417252584d50874715d9ff11d3482c131826cc80bbb2.
module mod_harvest_oracle
 use iso_fortran_env,only:real64
 implicit none
contains
 subroutine literal_harvest(dm,n,fraction,pending_dm,pending_n,remaining_n)
  real(real64),intent(in)::dm(4),n(4),fraction(3)
  real(real64),intent(out)::pending_dm(4),pending_n(4),remaining_n(4)
  real(real64)::wrt,wlv,wst,wso,dwlv,dwst,anrt,anlv,anst,anso,nlossl,nlosss
  real(real64)::FraHarLosOrm_lv,FraHarLosOrm_st,FraHarLosOrm_so
  real(real64)::HarLosOrm_rt,HarLosOrm_lv,HarLosOrm_st,HarLosOrm_so,HarLosOrm_dwlv,HarLosOrm_dwst
  real(real64)::HarLosNit_rt,HarLosNit_lv,HarLosNit_st,HarLosNit_so,HarLosNit_dwlv,HarLosNit_dwst
  real(real64)::idwrt,idwlv,idwst,idwso,inlossr,inlossl,inlosss,inlosso
  wrt=dm(1);wlv=dm(2);wst=dm(3);wso=dm(4)
  anrt=n(1);anlv=n(2);anst=n(3);anso=n(4)
  FraHarLosOrm_lv=fraction(1);FraHarLosOrm_st=fraction(2);FraHarLosOrm_so=fraction(3)
  ! Explicit immediate-return profile: no retained dead canopy, no redebit of daily death.
  dwlv=0d0;dwst=0d0;nlossl=0d0;nlosss=0d0
  idwrt=0d0;idwlv=0d0;idwst=0d0;idwso=0d0
  inlossr=0d0;inlossl=0d0;inlosss=0d0;inlosso=0d0
            HarLosOrm_rt = wrt
            HarLosOrm_dwlv = FraHarLosOrm_lv * dwlv
            HarLosOrm_lv = FraHarLosOrm_lv * wlv + HarLosOrm_dwlv
            HarLosOrm_dwst = FraHarLosOrm_st * dwst
            HarLosOrm_st = FraHarLosOrm_st * wst + HarLosOrm_dwst
            HarLosOrm_so = FraHarLosOrm_so * wso

            !ckro_sup_20170714 : suppressed because it will happen after harvest
            ! wrt = wrt - HarLosOrm_rt
            ! wlv = wlv - FraHarLosOrm_lv * wlv
            ! wst = wst - FraHarLosOrm_st * wst
            ! wso = wso - FraHarLosOrm_so * wso
            idwrt = idwrt + HarLosOrm_rt
            idwlv = idwlv + HarLosOrm_lv
            idwst = idwst + HarLosOrm_st
            idwso = idwso + HarLosOrm_so
            HarLosNit_rt = anrt
            HarLosNit_dwlv = FraHarLosOrm_lv * NLOSSL 
            HarLosNit_lv = FraHarLosOrm_lv * anlv + HarLosNit_dwlv 
            HarLosNit_dwst = FraHarLosOrm_st * NLOSSS 
            HarLosNit_st = FraHarLosOrm_st * anst + HarLosNit_dwst 
            HarLosNit_so = FraHarLosOrm_so * anso
            
            inlossl = inlossl + HarLosNit_lv
            inlosss = inlosss + HarLosNit_st
            inlosso = inlosso + HarLosNit_so
            inlossr = inlossr + HarLosNit_rt
            
            anlv = anlv - FraHarLosOrm_lv * anlv
            anst = anst - FraHarLosOrm_st * anst
            anso = anso - FraHarLosOrm_so * anso
            anrt = anrt - HarLosNit_rt
  pending_dm=[idwrt,idwlv,idwst,idwso]
  pending_n=[inlossr,inlossl,inlosss,inlosso]
  remaining_n=[anrt,anlv,anst,anso]
 end subroutine
end module
