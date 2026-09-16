program test_wofost81_n_stress_driver
   use iso_fortran_env, only: real64
   use MOD_wofost81_n_stress, only: compute_wofost81_n_stress
   implicit none
   integer :: ios,status
   real(real64) :: nmaxlv,nmaxst_fr,nmaxso,rgrlai,rgrlai_min,wlv,wst,wso,nlv,nst,nso,idx,rfr
   do
      read(*,*,iostat=ios) nmaxlv,nmaxst_fr,nmaxso,rgrlai,rgrlai_min,wlv,wst,wso,nlv,nst,nso
      if(ios<0) exit
      if(ios>0) error stop 1
      call compute_wofost81_n_stress(nmaxlv,nmaxst_fr,nmaxso,rgrlai,rgrlai_min,wlv,wst,wso,nlv,nst,nso,idx,rfr,status)
      write(*,'(*(G0,1X))') status,idx,rfr
   end do
end program
