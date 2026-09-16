module MOD_integral

   use MOD_arrays, only: madr, macp
   use MOD_integral_global
   
   implicit none

   ! interfaces to main entries of subroutine integral
   !!!interface
   !!!   subroutine integral(iTask, trial_mass)
   !!!      integer, intent(in) :: iTask
!!!      ! F-CI11 optional trial_mass omitted from this historical commented interface.
   !!!   end subroutine integral
   !!!end interface
    
   real(8), dimension(macp),      save ::   inqrot              ! Array with intermediate amounts of extracted water by roots for each compartment (L)
   real(8), dimension(macp+1),    save ::   inq                 ! Array with intermediate amounts of water flow between current and upper compartment (L)
   real(8), dimension(macp),      save ::   inqssdi             ! Array with intermediate amounts of subsurface drip irrigation for each compartment (L)
   real(8), dimension(macp),      save ::   inqpotrot           ! Array with intermediate amounts of potential extracted water by roots for each compartment (L)
   real(8), dimension(macp),      save ::   inqredrot           ! Array with intermediate amounts of reduction of extracted water by roots for each compartment in case of no compensation (L)
   real(8), dimension(macp+1),    save ::   iqdo, iqup
   
   real(8),                       save ::   iqrot               ! Intermediate amount of extracted water by roots (L)
   real(8),                       save ::   iqssdi              ! Intermediate amount of water input via subsurface drip irrigation (L)
   real(8),                       save ::   iqredwet            ! Intermediate amount of reduced root water extraction due to wet conditions (L)
   real(8),                       save ::   iqreddry            ! Intermediate amount of reduced root water extraction due to dry conditions (L)
   real(8),                       save ::   iqredsol            ! Intermediate amount of reduced root water extraction due to salt conditions (L)
   real(8),                       save ::   iqredfrs            ! Intermediate amount of reduced root water extraction due to frost conditions (L)
   real(8),                       save ::   iintc               ! Intermediate amount of evaporation from canopy (L)
   real(8),                       save ::   isintc              ! Intermediate amount of evaporation from canopy reservoir (L)
   real(8),                       save ::   iepd                ! Intermediate amount of ponding evaporation (L)
   real(8),                       save ::   ipeva               ! Intermediate amount of potential soil evaporation (L)
   real(8),                       save ::   iptra               ! Intermediate amount of potential transpiration (L)
   real(8),                       save ::   ievap               ! Intermediate amount of actual soil evaporation (L)
   real(8),                       save ::   iruno               ! Intermediate amount of runoff (L)
   real(8),                       save ::   irunon              ! Intermediate amount of runon (L)
   real(8),                       save ::   iqbot               ! Intermediate amount of water flow through bottom of simulated soil column (L)
   real(8),                       save ::   iqbdo,iqbup         ! Intermediate amount of water flow through bottom of simulated soil column (L)
