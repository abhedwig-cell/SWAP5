module MOD_wofost81_n_stress

   use iso_fortran_env, only: real64
   use ieee_arithmetic, only: ieee_is_finite
   implicit none
   private

   integer, parameter, public :: WOFNSTR81_OK = 0
   integer, parameter, public :: WOFNSTR81_INVALID_INPUT = 1

   public :: compute_wofost81_n_stress

contains

   pure subroutine compute_wofost81_n_stress(nmaxlv, nmaxst_fr, nmaxso, rgrlai, rgrlai_min, &
                                              wlv, wst, wso, namountlv, namountst, namountso, &
                                              nstress_index_dlv, rfrgrl, status)
      real(real64), intent(in) :: nmaxlv, nmaxst_fr, nmaxso, rgrlai, rgrlai_min
      real(real64), intent(in) :: wlv, wst, wso, namountlv, namountst, namountso
      real(real64), intent(out) :: nstress_index_dlv, rfrgrl
      integer, intent(out) :: status

      real(real64) :: nmaxst, namount_abg, namount_abgmx, ratio
      real(real64) :: nconc_lv, nstress_index_rgrlai
      real(real64) :: values(11)

      nstress_index_dlv = 1.0_real64
      rfrgrl = 1.0_real64
      status = WOFNSTR81_OK

      values = [nmaxlv, nmaxst_fr, nmaxso, rgrlai, rgrlai_min, wlv, wst, wso, &
                namountlv, namountst, namountso]
      if (.not. all(ieee_is_finite(values)) .or. any(values < 0.0_real64) .or. &
          nmaxlv <= 0.0_real64 .or. rgrlai <= 0.0_real64 .or. rgrlai_min > rgrlai) then
         status = WOFNSTR81_INVALID_INPUT
         return
      end if

      nmaxst = nmaxst_fr*nmaxlv
      namount_abg = namountlv + namountst + namountso
      namount_abgmx = wlv*nmaxlv + wst*nmaxst + wso*nmaxso
      if (namount_abg <= 0.0_real64) then
         status = WOFNSTR81_INVALID_INPUT
         return
      end if

      ratio = namount_abgmx/namount_abg
      if (ratio <= 1.0_real64) then
         nstress_index_dlv = 1.0_real64
      else if (ratio > 2.0_real64) then
         nstress_index_dlv = 2.0_real64
      else
         nstress_index_dlv = ratio
      end if

      if (wlv > 0.0_real64) then
         nconc_lv = namountlv/wlv
      else
         nconc_lv = 0.0_real64
      end if
      nstress_index_rgrlai = max(0.0_real64, min(1.0_real64, &
                                   (nconc_lv - 0.9_real64*nmaxlv)/(0.1_real64*nmaxlv)))
      rfrgrl = 1.0_real64 - (1.0_real64 - nstress_index_rgrlai)*(rgrlai - rgrlai_min)/rgrlai
   end subroutine compute_wofost81_n_stress

end module MOD_wofost81_n_stress
