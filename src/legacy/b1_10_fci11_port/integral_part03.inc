   real(8), dimension(madr),      save ::   cqdrainin          ! Cumulative infiltration flux (L) for each drainage level
   real(8), dimension(madr),      save ::   cqdrainout         ! Cumulative drainage flux (L) for each drainage level
   real(8), dimension(madr,macp), save ::   inqdra             ! Array with intermediate amounts of lateral drainage for each level and compartment (L)
   real(8), dimension(madr,macp), save ::   inqdra_in, inqdra_out
   real(8),                       save ::   iqdra              ! Intermediate amount of lateral drainage (L)

   ! snow
   real(8),                       save ::   cgsnow              ! Cumulative amount of gross snow fall (L water)
   real(8),                       save ::   cmelt               ! Cumulative amount of melted snow (L water)
   real(8),                       save ::   csnrai              ! Cumulative amount of net snow fall (L water)
   real(8),                       save ::   csubl               ! Cumulative amount of sublimated snow (L water)
   real(8),                       save ::   isnrai              ! Incremental amount of net snow fall (L water)
   real(8),                       save ::   igsnow              ! Incremental amount of gross snow fall (L water)
   real(8),                       save ::   isubl               ! Incremental amount of sublimated snow (L water)

   public

   contains

! File VersionID:
!   $Id: integral.f90 341 2017-09-29 18:12:25Z kroes006 $
! ----------------------------------------------------------------------
      subroutine integral(iTask, trial_mass)
! ----------------------------------------------------------------------
!     Date:    November 2004
!     Purpose: calculation of intermediate and cumulative fluxes
! ----------------------------------------------------------------------
      use plant_interface, only: noddrz, ipgass, igass, imres, ipgasspot, igasspot, imrespot, sw_inter, sicact, siccap, crsflx_in, crsflx_out, siccaploss
      use MOD_grid,        only: numnod
      use MOD_swap_base,   only: swsnow, swdra, swmacro
      use MOD_meteo,       only: peva, ptra, graidt, nraidt, aintcdt
      use MOD_snow,        only: gsnow, melt, subl, snrai, snowinco, ssnow
      use MOD_drain,       only: qdrtot, nrlevs, qdra, qdrain
      use MOD_irrigation,  only: qssdisum, qssdi, gird, nird
      use MOD_macropore,   only: macropore
      use variables,       only: flzerocumu, flzerointr, fldaystart, dt, epd, reva, qbot, qrot, runots,runon, q, volini, volact, pondini, pond, theta, ivolbeg, ipondbeg, issnowbeg, isicbeg, ithetabeg
      use MOD_re_global,   only: qpotrot, qredwetsum, qreddrysum, qredsolsum, qredfrssum, qrosum, qredwet, qreddry, qredsol, qredfrs, qredrwu, alpwetnoddrz, alpdrynodrtz
      use mod_b1_10_trial_mass, only: b1_10_trial_mass_t, invalidate_b1_10_trial_mass, &
           record_b1_10_trial_mass_step, record_b1_10_trial_interception_loss
      implicit none
!     global
      integer, intent(in) :: iTask
      type(b1_10_trial_mass_t), intent(inout), optional :: trial_mass

! --- local variables
      integer node,level
      real(8) qrotts,qdrats,ptrats,epdts,pevats,revats,qbotts
      real(8) trial_drain_in, trial_drain_out, trial_interception
! ----------------------------------------------------------------------

   select case(iTask)

   case (1,2)   ! initialization or resets
      
