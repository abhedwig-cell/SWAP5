! File VersionID:
!   $Id: rootextraction.f90 374 2018-03-21 13:12:23Z heine003 $
! ----------------------------------------------------------------------

   
module MOD_rootextraction

   private
   public :: RootExtraction, reset_RootExtraction
   
   contains
   ! RootExtraction
   ! RootExtraction_MACRO
   ! RootExtraction_MICRO
   ! reset_RootExtraction
   ! p_func
   
subroutine RootExtraction(iTask)
! ----------------------------------------------------------------------
!     update    : August 2016: microscopic uptake according to JongvanLier(2013)
!     update    : August 2012: O2-stress according to Bartholomeus(2008)
!     update    : February 2011: macrosopic uptake extended with
!                                compensation according to Jarvis (1989)
!     date      : August 2004
!     purpose   : Calculate the root water extraction rate as function of soil
!                 water pressure head and salinity concentration for each node
! ----------------------------------------------------------------------
use plant_interface, only: sw_drought, fl_cropemergence
use variables,       only: qrot
use MOD_re_global,   only: qpotrot, qredwetsum, qreddrysum, qredsolsum, qredfrssum, qrosum

implicit none

! --- global variable
integer, intent(in) :: iTask

select case (iTask)
case(1)
   if (sw_drought == 1) call RootExtraction_MACRO(iTask)
   if (sw_drought == 2) call RootExtraction_MICRO(iTask)
   if (sw_drought == 3) call RootExtraction_MICRO(iTask)

case(2)
   if (.not.fl_cropemergence) then
      qpotrot    = 0.0d0
      qrot       = 0.0d0
      qrosum     = 0.0d0
      qreddrysum = 0.0d0
      qredwetsum = 0.0d0
      qredsolsum = 0.0d0
      qredfrssum = 0.0d0
      return
   end if
   if (sw_drought == 1) call RootExtraction_MACRO(iTask)
   if (sw_drought == 2) call RootExtraction_MICRO(iTask)
   if (sw_drought == 3) call RootExtraction_MICRO(iTask)

case default
   call swap_error ('rootextraction_micro', 'Illegal iTask value')
end select

return

end subroutine RootExtraction

!-------------------------------------
! Microscopic root water uptake
! Method: dW or dJvL
!-------------------------------------
subroutine RootExtraction_MICRO(iTask)

use MOD_grid,            only: dz, z, numnod, botcom
use MOD_swap_base,       only: swfrost
use variables,           only: qrot, h, theta, thetas
use MOD_re_global,       only: hroot, mroot, mflux, alpwet, alpsol, alpfrs, alpdry, alptot, qrosum, qpotrot,            &
                               qredwetsum, qreddrysum, qredsolsum, qredfrssum, qredrwu, alpwetnoddrz, alpdrynodrtz
use MOD_meteo,           only: ptra
use plant_interface,     only: sw_drought, sw_oxygen, swwrtnonox, noddrz, rd
use MOD_cropdevelopment, only: hlim1, hlim2u, hlim2l, sw_oxygentype, oxygenslope, oxygenintercept,                      &
                               sw_salinity, saltmax, saltslope,                                                         &
                               swdmi2rd, lrv_node
use mod_RWU_micro,       only: do_RWU_micro, UpwPot, PP, PL, swAlpTot, sw_mxdrought
use MOD_SoilTemperature, only: tsoil
use MOD_Solute,          only: cml

implicit none

! global variable
integer, intent(in)                       :: iTask

! --- local variables
integer                                   :: node
real(8)                                   :: hlim2, qred, dum
real(8)                                   :: pO2, pS, pT, qprosum
integer, save                             :: iMicro
real(8)                                   :: Alpha_micro_tot
real(8), dimension(:), allocatable, save  :: Upw
real(8), parameter                        :: vsmall = 1.0d-14
real(8), parameter                        :: nihil = 1.0d-10

logical                                   :: fl_optrtz
real(8)                                   :: qred_optrtz

select case (iTask)

case(1)

   if (allocated(Upw))    deallocate(Upw);    allocate(Upw(numnod));    Upw    = 0.0d0
   if (allocated(alpwet)) deallocate(alpwet); allocate(alpwet(numnod)); alpwet = 1.0d0
   if (allocated(alpsol)) deallocate(alpsol); allocate(alpsol(numnod)); alpsol = 1.0d0
   if (allocated(alpfrs)) deallocate(alpfrs); allocate(alpfrs(numnod)); alpfrs = 1.0d0
   if (allocated(alpdry)) deallocate(alpdry); allocate(alpdry(numnod)); alpdry = 1.0d0
   if (allocated(alptot)) deallocate(alptot); allocate(alptot(numnod)); alptot = 1.0d0

   if (sw_drought == 2) iMicro = 2
   if (sw_drought == 3) iMicro = 1
   fl_optrtz = .FALSE.
   call do_RWU_micro(1, iMicro, noddrz, Lrv_node, ptra, alpwet, fl_optrtz, Upw, Alpha_micro_tot)

case(2)

! ----------------------------------------------------------------------

   ! reset root water extraction arrays
   qpotrot(1:numnod) = 0.d0
   qrot(1:numnod)   = 0.0d0
   qredrwu(1:numnod)= 0.0d0
   qrosum           = 0.0d0
   qreddrysum       = 0.0d0
   qredwetsum       = 0.0d0
   qredsolsum       = 0.0d0
   qredfrssum       = 0.0d0
   hroot(1:numnod)  = 0.0d0
   mroot(1:numnod)  = 0.0d0
   mflux(1:numnod)  = 0.0d0
   alpwet(1:numnod) = 1.0d0
   alpsol(1:numnod) = 1.0d0
   alpfrs(1:numnod) = 1.0d0
   alpdry(1:numnod) = 1.0d0
   alptot(1:numnod) = 1.0d0

   PP      = 0.0d0
   PL      = 0.0d0

! --- skip routine if there are no roots
   if (rd < vsmall) return

! --- skip routine if transpiration rate is zero
   if (ptra < nihil) return

! ---   reduction due to oxygen stress
   if (sw_oxygen /= 0) then

      oxygen: do node = 1, noddrz

         ! Feddes linear reduction based on pressure head
         if (sw_oxygen == 1) then
            if (node > botcom(1)) then
               hlim2 = hlim2l
            else
               hlim2 = hlim2u
            end if
            if (h(node) <= hlim1 .AND. h(node) > hlim2) then
               alpwet(node) = (hlim1 - h(node)) / (hlim1 - hlim2)
            end if
            if (h(node) > hlim1) then
               alpwet(node) = 0.0d0
            end if

         ! Bartholomeus non-linear reduction based on gas filled porosity
         else if (sw_oxygen == 2) then

            ! use physical processes
            if (sw_oxygentype == 1) then
               call OxygenStress(node, alpwet(node))

            else
               ! use reproduction functions
               call OxygenReproFunction (OxygenSlope, OxygenIntercept, theta, thetas, tsoil, node, z, dz, alpwet(node))
            end if
         end if

      end do oxygen

      ! stop root development in case of oxgenstress at noddrz
      alpwetnoddrz = 0.d0
      if (swwrtnonox == 1) then
         alpwetnoddrz = alpwet(noddrz)
      end if

   end if

! TO  BE IMPLEMENTED: effect of salinity and frost stress
   if (swfrost == 1) call swap_error ('rootextraction_micro', 'SWFROST not yet implemented')

! ---   reduction due to salt stress
   ! reduction according to Maas and Hoffman linear reduction function
   if (sw_salinity == 1) then
      do node = 1, noddrz
         if (cml(node) > saltmax) then
            alpsol(node) = 1.0d0 - (cml(node) - saltmax) * saltslope
            alpsol(node) = max(0.0d0, alpsol(node))
         end if
      end do
   end if

! ----  reduction due to frost conditions
   if (swfrost == 1) then
      do node = 1, noddrz
         alpfrs(node) = 1.0d0
         if (tsoil(node) < 0.0d0) alpfrs(node) = 0.0d0
      end do
   end if

! --- DROUGHT REDUCTION ACCORDING TO DE JONG VAN LIER ET AL. (2012): iMicro = 2
! --- DROUGHT REDUCTION ACCORDING TO DE WILLIGEN ET AL.:             iMicro = 1
   if (swAlpTot == 1) then
      alptot(1:noddrz) = alpwet(1:noddrz) * alpsol(1:noddrz) * alpfrs(1:noddrz)
   else if (swAlpTot == 2) then
      alptot(1:noddrz) = min(alpwet(1:noddrz), alpsol(1:noddrz), alpfrs(1:noddrz))
   else  if (swAlpTot == 3) then
      alptot(1:noddrz) = alpwet(1:noddrz) * alpsol(1:noddrz) * alpfrs(1:noddrz)
      dum = 1.0d0
      do node = 1, noddrz
         if (alptot(node) > 0.0d0) dum = dum * alptot(node)
      end do
      alptot(1:noddrz) = dum
   end if

   ! rwu in case of optimal root activity (to determine maximum drought stress)
   qred_optrtz = 0.d0
   if (sw_mxdrought == 1) then
      fl_optrtz = .TRUE.
      call do_RWU_micro(2, iMicro, noddrz, Lrv_node, ptra, alptot, fl_optrtz, Upw, Alpha_micro_tot)
      qred_optrtz = max(0.0d0, sum(UpwPot(1:noddrz)) - sum(Upw(1:noddrz)))
   end if

   fl_optrtz = .FALSE.
   call do_RWU_micro(2, iMicro, noddrz, Lrv_node, ptra, alptot, fl_optrtz, Upw, Alpha_micro_tot)

!   qrot(1:noddrz) = Upw(1:noddrz)/Alpha_micro_tot
   qrot(1:noddrz)    = Upw(1:noddrz)
   qpotrot(1:noddrz) = UpwPot(1:noddrz)
   qredrwu(1:noddrz) = max(0.d0, UpwPot(1:noddrz) - Upw(1:noddrz))

! === COMBINATION OF OXYGEN, DROUGHT, SALT AND FROST STRESS ====

   qrosum  = sum(qrot(1:noddrz))
   qprosum = sum(qpotrot(1:noddrz))
   qred    = max(0.0d0, qprosum - qrosum)
   call p_func(noddrz, alpwet, alpsol, alpfrs, Lrv_node, dz, pO2, pS, pT)

   if (qred_optrtz > 0.0d0) then

      qredwetsum = qredwetsum + pO2 * (qred - qred_optrtz)
      qredsolsum = qredsolsum + pS  * (qred - qred_optrtz)
      qredfrssum = qredfrssum + pT  * (qred - qred_optrtz)
      qreddrysum = qreddrysum + qred_optrtz
      alpdry = Alpha_micro_tot                  ! for output only

   else

      if (pO2 > 0.0d0 .OR. pS > 0.0d0 .OR. pT > 0.0d0) then
         qredwetsum = qredwetsum + pO2 * qred
         qredsolsum = qredsolsum + pS  * qred
         qredfrssum = qredfrssum + pT  * qred
      else                                      ! if (pO2 == 0.0d0 .AND. pS == 0.0d0 .AND. pT == 0.0d0)
         qreddrysum = qreddrysum + qred
         alpdry = Alpha_micro_tot               ! for output only
      end if

   end if

   ! activate root extension in case of drought stress
   alpdrynodrtz = 0.d0
   if (swdmi2rd == 2) then
      alpdrynodrtz = 1.d0 - (qreddrysum / ptra)
   end if

case default
   call swap_error ('rootextraction_micro', 'Illegal iTask value')
end select

end subroutine RootExtraction_MICRO

!-------------------------------------
! Macroscopic root water uptake
! Method: Feddes
!-------------------------------------
subroutine RootExtraction_MACRO(iTask)

use MOD_grid,             only: dz, z, zbotcp, numnod, botcom
use MOD_frost,            only: swfrost
use variables,            only: qrot, h, theta, thetas
use MOD_meteo,            only: ptra
use plant_interface,      only: sw_oxygen, swwrtnonox, noddrz, hlim3l, hlim3h, hlim4, rd
use MOD_cropdevelopment,  only: adcrh, adcrl, hlim1, hlim2u, hlim2l, sw_oxygentype, oxygenslope, oxygenintercept,                &
                                sw_salinity, saltmax, saltslope,                                                                 &
                                sw_compensate, sw_stressor, alphacrit, dcritrtz,                                                 &
                                rdm, swdmi2rd, cumdens_top
use MOD_re_global,        only: hroot, mroot, mflux,  qrosum,qpotrot, qredwetsum, qreddrysum, qredsolsum, qredfrssum,            &
                                qreddry, qredwet, qredsol, qredfrs, qredrwu, alpwetnoddrz, alpdrynodrtz
use MOD_RWU_micro,        only: PP, PL
use MOD_SoilTemperature,  only: tsoil
use MOD_Solute,           only: cml
implicit none

! global variable
integer, intent(in) :: iTask

! --- local variables
integer :: node
real(8) :: hlim3,hlim2,qred
real(8) :: alpdry,alpwet,alpsol,alpfrs,alptot
real(8) :: alpdrycom,alpwetcom,alpsolcom,alpfrscom,alptotcom
real(8) :: rd_noddrz, redtot

real(8), parameter :: vsmall = 1.0d-14
real(8), parameter :: nihil  = 1.0d-10

select case (iTask)

case(1)

   hroot(1:numnod) = 0.0d0
   mroot(1:numnod) = 0.0d0
   mflux(1:numnod) = 0.0d0
   PP = 0.0d0
   PL = 0.0d0
   qredrwu(1:numnod) = 0.0d0

case(2)

! ----------------------------------------------------------------------

   ! reset root water extraction array
   qpotrot(1:numnod) = 0.d0
   qrot(1:numnod) = 0.d0
   qredwet(1:numnod) = 0.d0
   qreddry(1:numnod) = 0.d0
   qredsol(1:numnod) = 0.d0
   qredfrs(1:numnod) = 0.d0

   qrosum = 0.d0
   qreddrysum = 0.d0
   qredwetsum = 0.d0
   qredsolsum = 0.d0
   qredfrssum = 0.d0

! --- skip routine if there are no roots
   if (rd < vsmall) return

! --- skip routine if transpiration rate is zero
   if (ptra < nihil) return

! --- DROUGHT REDUCTION ACCORDING TO FEDDES ET AL. (1978)
! --- calculate potential root extraction of the compartments
   ! 22-10-2018: bug repair signalled by Paul van Walsum: division not by rd but by depth bottom of last compartment where roots are present
   !             rd replaced by (newly calculated) rd_noddrz
   rd_noddrz = abs(zbotcp(noddrz))
   do node = 1,noddrz
      qrot(node) = (cumdens_top(node + 1)-cumdens_top(node)) * ptra
   end do

! --- calculating critical point hlim3 according to feddes
   if (ptra < adcrl) then
      hlim3 = hlim3l
   else if (ptra <= adcrh) then
      hlim3 = hlim3h + ((adcrh - ptra) / (adcrh - adcrl)) * (hlim3l - hlim3h)
   else
      hlim3 = hlim3h
   end if

! === COMBINATION OF OXYGEN, DROUGHT, SALT AND FROST STRESS ====
   qrosum = 0.0d0

   do node = 1, noddrz
      alpdry = 1.0d0
      alpwet = 1.0d0
      alpsol = 1.0d0
      alpfrs = 1.0d0

! ---   reduction due to oxygen stress
      if (sw_oxygen /= 0) then

          ! Feddes linear reduction based on pressure head
         if (sw_oxygen == 1) then

            if (node > botcom(1)) then
               hlim2 = hlim2l
            else
               hlim2 = hlim2u
            end if
            if (h(node) <= hlim1 .AND. h(node) > hlim2) then
               alpwet = (hlim1 - h(node)) / (hlim1 - hlim2)
            end if
            if (h(node) > hlim1) then
               alpwet = 0.0d0
            end if

          ! Bartholomeus non-linear reduction based on gas filled porosity
         else if (sw_oxygen == 2) then

            ! use physical processes
            if (sw_oxygentype == 1) then
               call OxygenStress(node,alpwet)

            ! use reproduction functions
            else
               call OxygenReproFunction (OxygenSlope,OxygenIntercept,theta,thetas,tsoil,node,z,dz,alpwet)
            end if

         end if

         ! stop root development in case of oxgenstress at noddrz
         alpwetnoddrz = 0.d0
         if (swwrtnonox == 1 .AND. node == noddrz) then
            alpwetnoddrz = alpwet
         end if

      end if

! ---   reduction due to drought stress
      ! Feddes linear reduction based on pressure head
      if (h(node) < hlim4) then
         alpdry = 0.0d0
      else if (h(node) <= hlim3) then
         alpdry = (hlim4 - h(node)) / (hlim4 - hlim3)
      end if

! ---   reduction due to salt stress
        ! reduction according to Maas and Hoffman linear reduction function
      if (sw_salinity == 1) then
         if (cml(node) > saltmax) then
            alpsol = 1.0d0 - (cml(node) - saltmax) * saltslope
            alpsol = max(0.0d0,alpsol)
          end if
      end if
! ---   mind: in case of salt stress with osmotic head, microscopic root water extraction
! ---         according to JongvanLier (2013) should be used (swsalinity = 2); in that case
! ---         salinity stress is included in drought stress and not separately specified
! ---         in output file *.STR

! ----  reduction due to frost conditions
      if (swfrost == 1 .AND. tsoil(node) < 0.0d0) then
         alpfrs = 0.0d0
      end if

! ----  overall reduction
      qpotrot(node) = qrot(node)
      qrot(node)    = qrot(node) * alpwet * alpdry * alpsol * alpfrs
      !qrosum = qrot(node) + qrosum

! ----  apportionment to different types stresses (cm)
      qred = qpotrot(node) - qrot(node)
      if (dabs(qred) < vsmall) then

         ! no stress
         qredwet(node) = 0.d0
         qreddry(node) = 0.d0
         qredsol(node) = 0.d0
         qredfrs(node) = 0.d0
         qred          = 0.d0
         qrot(node)    = qpotrot(node)

      else

         ! multiplication of stressors
         alptot = (1.0d0 - alpwet) + (1.0d0 - alpdry) + (1.0d0 - alpsol) + (1.0d0 - alpfrs)

         ! contribution of each stressor (linear approach)
         qredwet(node) = (1.0d0 - alpwet) / alptot * qred
         qreddry(node) = (1.0d0 - alpdry) / alptot * qred
         qredsol(node) = (1.0d0 - alpsol) / alptot * qred
         qredfrs(node) = (1.0d0 - alpfrs) / alptot * qred

         ! sum of each stressor (rootzone)
         qredwetsum = qredwetsum + qredwet(node)
         qreddrysum = qreddrysum + qreddry(node)
         qredsolsum = qredsolsum + qredsol(node)
         qredfrssum = qredfrssum + qredfrs(node)

      end if
      qrosum = qrot(node) + qrosum

   end do ! all nodes

   ! stop root extension in case of oxgenstress at noddrz
   alpwetnoddrz = 0.d0
   if (swwrtnonox == 1) then
      alpwetnoddrz = alpwet
   end if

   ! activate root extension in case of drought stress
   alpdrynodrtz = 0.d0
   if (swdmi2rd == 2) then
      alpdrynodrtz = 1.d0 - (qreddrysum / ptra)
   end if

! --- compensated root water uptake according to Jarvis (1989) or Walsum (2020)
   if (sw_compensate > 0) then

      ! compensated root water uptake according to Walsum
      if (sw_compensate == 2) then
         alphacrit = min((dcritrtz + rdm - rd_noddrz) / rdm, 1.0d0)
      end if

      alptot = qrosum / ptra
      qred   = ptra - qrosum
      if (abs(alphacrit - 1.0d0) >= vsmall .AND. qred > vsmall .AND. alptot >= vsmall) then
         ! Only compensation when rootextraction and transpiration reduction is greater than vsmall
         ! and when alptot > 0.05, i.e. when there is less than 95% stress reduction. This minimum is
         ! also important for the approximation of alp... in the next 4 lines.
         alpdry = alptot**(qreddrysum/qred)
         alpwet = alptot**(qredwetsum/qred)
         alpsol = alptot**(qredsolsum/qred)
         alpfrs = alptot**(qredfrssum/qred)

         if (sw_stressor == 1) then
            alptotcom = min(alptot / alphacrit, 1.d0)
            alpdrycom = alpdry
            alpwetcom = alpwet
            alpsolcom = alpsol
            alpfrscom = alpfrs
         else
            alpdrycom = alpdry
            alpwetcom = alpwet
            alpsolcom = alpsol
            alpfrscom = alpfrs
            if (sw_stressor == 2) then
              alpdrycom = min(alpdry / alphacrit, 1.d0)
            else if (sw_stressor == 3) then
              alpwetcom = min(alpwet / alphacrit, 1.d0)
            else if (sw_stressor == 4) then
              alpsolcom = min(alpsol / alphacrit, 1.d0)
            else if (sw_stressor == 5) then
              alpfrscom = min(alpfrs / alphacrit, 1.d0)
            end if
            alptotcom = alpwetcom * alpdrycom * alpsolcom * alpfrscom
         end if

         ! Change the abstraction of the roots
         do node = 1, noddrz
            qrot(node) = qrot(node) * alptotcom / alptot
         end do

          ! Change the sum-parameters
         qrosum = ptra * alptotcom
         qred = ptra - qrosum
         if (qred < vsmall) then
            ! There is no stress.
            qredwetsum = 0.0d0
            qreddrysum = 0.0d0
            qredsolsum = 0.0d0
            qredfrssum = 0.0d0
         else
            redtot     = (1.0d0 - alpwetcom) + (1.0d0 - alpdrycom) + (1.0d0 - alpsolcom) + (1.0d0 - alpfrscom)
            qredwetsum = (1.0d0 - alpwetcom) / redtot * qred
            qreddrysum = (1.0d0 - alpdrycom) / redtot * qred
            qredsolsum = (1.0d0 - alpsolcom) / redtot * qred
            qredfrssum = (1.0d0 - alpfrscom) / redtot * qred
         end if
      end if

   end if

case default
   call swap_error ('rootextraction', 'Illegal iTask value')

end select

end subroutine RootExtraction_MACRO

subroutine p_func(noddrz, alpwet, alpsol, alpfrs, Lrv, dz, pO2, pS, pT)
!use variables, only: t1900
! global
integer,                    intent(in)  :: noddrz
real(8), dimension(noddrz), intent(in)  :: alpwet, alpsol, alpfrs, Lrv, dz
real(8),                    intent(out) :: pO2, pS, pT
! local
integer :: i
real(8) :: sum1, sum2, sum3, denom

sum1= 0.0d0; sum2 = 0.0d0; sum3 = 0.0d0
do i = 1, noddrz
   sum1 = sum1 + (1.0d0 - alpwet(i)) * Lrv(i) * dz(i)
   sum2 = sum2 + (1.0d0 - alpsol(i)) * Lrv(i) * dz(i)
   sum3 = sum3 + (1.0d0 - alpfrs(i)) * Lrv(i) * dz(i)
end do

denom = sum1 + sum2 + sum3
if (denom > 0.0d0) then
   pO2 = sum1 / denom
   pS  = sum2 / denom
   pT  = sum3 / denom
else
   pO2 = 0.0d0
   pS  = 0.0d0
   pT  = 0.0d0
end if

end subroutine p_func

subroutine reset_rootextraction
   use MOD_grid,      only: numnod
   use variables,     only: qrot
   use MOD_re_global, only: qpotrot, qreddrysum, qredwetsum, qredsolsum, qredfrssum, qrosum, qreddry, qredwet, qredsol, qredfrs
   implicit none

   qpotrot(1:numnod) = 0.d0
   qrot(1:numnod)    = 0.d0
   qredwet(1:numnod) = 0.d0
   qreddry(1:numnod) = 0.d0
   qredsol(1:numnod) = 0.d0
   qredfrs(1:numnod) = 0.d0

   qrosum     = 0.d0
   qreddrysum = 0.d0
   qredwetsum = 0.d0
   qredsolsum = 0.d0
   qredfrssum = 0.d0

   return

end subroutine reset_rootextraction

end module MOD_rootextraction

! two help routines for MOD_cropdevelopment (to circumvent circular reference of modules)
subroutine rootextraction_init()
   use MOD_rootextraction, only: rootextraction
   call rootextraction(1)
end subroutine rootextraction_init

subroutine rootextraction_reset()
   use MOD_rootextraction, only: reset_rootextraction
   call reset_rootextraction
end subroutine rootextraction_reset
   