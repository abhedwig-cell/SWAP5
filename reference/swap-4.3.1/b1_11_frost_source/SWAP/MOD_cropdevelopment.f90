module MOD_cropdevelopment

   use MOD_arrays,         only: macrop, mayrs, macp, macroptb
   use MOD_swap_base,      only: pathcrop, swhea, swcalt, swsolu, swtill, swinco, unit_err
   use plant_interface,    only: unit_crp, crpfilnam, icrop, croptype, fl_start_croprotation, fl_start_cropemergence, fl_cropemergence, fl_cropharvest,     &
                                 swrd, swrdc, swwrtnonox, aeratecrit, fl_cropisreset, rd
   use MOD_grid,           only: ztopcp, zbotcp, dz, z
   use MOD_texture_orgmat, only: bdens
   use MOD_integral,       only: inqpotrot_day, inqredrot_day
   
   implicit none

   ! global variables

   ! crop activity
   
   logical, save :: fl_cropcalendar                   ! flag indicating that crop calendar is active
   logical, save :: fl_readcropfile                   ! flag indicating reading of input.crp

   ! limited root extension
   real(8), save :: rdmax                             ! soil limited root extension

   ! workability
   integer, save :: sw_prep
   logical, save :: fl_prep                           ! flag indicating if ploughing opportunity has been realized
   integer, save :: sw_sow
   logical, save :: fl_sow                            ! flag indicating if sowing opportunity has been realized
   integer, save :: sw_germ
   logical, save :: fl_germ                           ! flag indicating if germination has been realized
   integer, save :: delay_prep                        ! delay of preparation
   integer, save :: nodsow                            ! compartment number for monitoring sowing temperature
   integer, save :: delay_sow                         ! delay of delay
   real(8), save :: tsumgerm                          ! temperature sum during germination
   
   real(8), save :: adcrh                             ! level of high atmospheric demand (L/T)
   real(8), save :: adcrl                             ! level of low atmospheric demand (L/T)

   ! oxygen stress
   real(8), save :: hlim1                             ! pressure head above which root water uptake stops (L)
   real(8), save :: hlim2u                            ! pressure head below which optimum water uptake starts for top layer (L)
   real(8), save :: hlim2l                            ! pressure head below which optimum water uptake starts for sub layer (L)

   integer, save :: sw_oxygentype                     ! switch for method oxygen stress calculation: 1 = physical processes; 2 = repro functions
   real(8), save :: q10_microbial                     ! relative increase in microbial respiration at temperature increase of 10 degree C [1.0..4.0 -, R]
   real(8), save :: specific_resp_humus               ! respiration rate of humus at 25 degree C [0.0..1.0 kg O2/kg C/d, R] 
   
   real(8), save :: oxygenslope(6)                    ! parameters of reproduction function for oxygen stress according to Bartholomeus
   real(8), save :: oxygenintercept(6)                ! parameters of reproduction function for oxygen stress according to Bartholomeus
   real(8), save :: campbell_h100, campbell_h500      ! parameters to determine the slope of the soil water retention curve (default: h100=-100 cm; h500=-500 cm)
   real(8), save :: gfp_h100                          ! gass filled porosity at soil water pressure head (default: h100=-100 cm)

   ! drought and oxygen stress
   real(8), save :: rootradius_m                      ! root radius drought and oxygen stress (m)
   real(8), save :: srl                               ! specific root length [0.d0..1.d10 m root/kg root, R]

   ! salinity stress
   integer, save :: sw_salinity                       ! switch for salinity stress: 0 = no stress; 1 = Maas and Hoffman (1977)
   real(8), save :: saltmax                           ! threshold salt concentration in soil water  [0..100 mg/cm3, R]
   real(8), save :: saltslope                         ! decline of rootwater uptake above threshold [0..1.0 cm3/mg, R]

   ! compensation reduction root water uptake
   integer, save :: sw_compensate                     ! switch for method of compensation of root water uptake stress
   integer, save :: sw_stressor                       ! switch for stressor to compensate (1 = all stressors (default); 2 = drought stress, 3 = oxygen stress, 4 = salinity stress; 5 = frost stress)
   real(8), save :: alphacrit                         ! critical stress index for compensation of root water uptake (-)
   real(8), save :: dcritrtz                          ! threshold for rootzone to start compensation of root water uptake; Walsum (cm)

   ! root extension
   real(8), dimension(macroptb), save :: rdtb         ! root depth as function of development stage
   real(8), save :: rdi                               ! initial rooting depth (L)
   real(8), save :: rri                               ! maximum daily increase of rooting depth (L/T)
   real(8), save :: rdc                               ! maximum rooting depth of particular crop (L)
   real(8), dimension(macroptb), save :: rlwtb        ! root depth as function of root biomass

   real(8), save :: rdm                               ! Maximum rooting depth (minimum of soil profile and particular crop) (L)
   real(8), save :: rdpot                             ! Potential rooting depth (L)
   real(8), save :: rr                                ! Root extension (L)

   integer, save :: swdmi2rd                          ! limited root extension by ratio tact/tpot
   real(8), save :: rrimin                            ! minimum root extension in case of no reduction of root water uptake by drought stress (L/T)
   real(8), save :: extentcrit                        ! threshold for maximum root extension
    
   integer, save :: noddrz_old                        ! previous node depth root zone

   ! root distribution
   integer, save :: mxnoddrz
   real(8), dimension(macp), save :: cumdens_top, wroot_node, lrv_node, wroot_node_top

   ! global/public variables: so save
   real(8), dimension(macroptb), save :: rdctb        ! array with relative root density (-) as function of relative root depth (-)
   real(8), save :: wrtmin                            ! minimum dry weight of plant root at soil compartment (kg/ha)
   real(8), save :: fgwrt                             ! factor of growth rate of dry weight of plant root which is adaptive (-)
   real(8), save :: fdwrt                             ! factor of death rate of dry weight of plant root which is adaptive (-)
   integer, save :: swlrvconstant                     ! switch for forcing constant Lrv (1) or not (0; default)

   ! local variables

   ! preparation before crop growth
   real(8), save :: z_prep                            ! z-level for monitoring work-ability for the crop     
   real(8), save :: h_prep                            ! maximum pressure head during preparation
   integer, save :: max_delay_prep                    ! maximum delay of preparation (starting from begin of growing season)

   ! sowing before crop growth
   real(8), save :: z_sow                             ! z-level for monitoring work-ability for the crop
   real(8), save :: h_sow                             ! maximum pressure head during sowing
   real(8), save :: z_tempsow                         ! z-level for monitoring temperature for sowing   
   integer, save :: max_delay_sow                     ! maximum delay of sowing (starting from begin of growing season)
   real(8), save :: TempSow                           ! temperature for sowing   

   ! germination before crop growth
   real(8), save :: zgerm                             ! z-level for monitoring temperature for germination
   real(8), save :: agerm                             ! coefficient a of germination
   real(8), save :: cgerm                             ! coefficient c of germination
   real(8), save :: bgerm                             ! coefficient b of germination
   real(8), save :: hdrygerm                          ! criterium hdry of germination
   real(8), save :: hwetgerm                          ! criterium hwet of germination
   real(8), save :: tsumemeopt                        ! temperature sum for crop emergence under optimal conditions
   real(8), save :: tbasem                            ! lower threshold temp. for emergence (C)
   real(8), save :: teffmx                            ! max. eff. temp. for emergence (C)

   ! correction assimilation due to CO2
   integer, save :: sw_co2                            ! switch indicating correction of CO2
   real(8), dimension(macroptb), save :: co2amaxtb    ! array with factor to correct AMAX as function of CO2
   real(8), dimension(macroptb), save :: co2efftb     ! array with factors to correct EFF as function of CO2
   real(8), dimension(macroptb), save :: co2tratb     ! array with factors to correct TRA as function of CO2
   integer, dimension(mayrs * 10), save :: co2year    ! table with years for which CO2 concentrations are given
   real(8), dimension(mayrs * 10), save :: co2ppm     ! table with CO2 concentrations (ppm), for each year in co2year

   ! crop factor and height
   real(8), dimension(macroptb), save :: chtb         ! array with crop heights (cm) as function of development stage
   real(8), dimension(macroptb), save :: cftb         ! array with either crop factors (-) or crop height (L) as function of development stage

   ! root distribution
   real(8), dimension((macp+1)*2), save :: cumdens    ! cumulative root distribution
   
   ! RDS: read locally or avaialble globally
   logical, save :: do_read_rds = .TRUE.              ! TRUE: read locally; FALSE: do not read locally and RDmax is available globally
   
   ! everything is private
   private

   ! except for the following function/subroutine
   public :: croprotation, cropdevelopment, cropemergence, co2_effect, cropfactor, interception, reset_crop
   public :: read_droughtstress, read_oxygenstress, read_salinitystress, read_compensation

   ! except for the following variables
   public :: fl_cropcalendar, fl_start_croprotation, fl_readcropfile
   public :: rdmax, do_read_rds, get_rdm
   public :: fl_prep, fl_sow, fl_germ
   public :: delay_prep, delay_sow, tsumgerm
   public :: sw_prep, z_prep, h_prep, max_delay_prep
   public :: sw_sow, z_sow, h_sow, max_delay_sow, z_tempsow, tempsow, nodsow
   public :: sw_germ, zgerm, hdrygerm, hwetgerm, agerm, bgerm, cgerm
   public :: tsumemeopt, tbasem, teffmx

   public :: cftb, chtb

   public :: adcrh, adcrl
   public :: hlim1, hlim2u, hlim2l, sw_oxygentype, q10_microbial, specific_resp_humus, oxygenslope, oxygenintercept, campbell_h100, campbell_h500, gfp_h100
   public :: rootradius_m, srl
   public :: sw_salinity, saltmax, saltslope
   public :: sw_compensate, sw_stressor, alphacrit, dcritrtz

   public :: read_rootextension, initialize_rootextension, update_rootextension
   public :: rdm
   public :: rdpot, rr, noddrz_old
   public :: swdmi2rd

   public :: sw_co2, co2ppm, co2year, co2tratb, co2efftb, co2amaxtb
   
   public :: mxnoddrz
   public :: cumdens, cumdens_top, lrv_node, wroot_node, wroot_node_top
   public :: rdtb, rdi, rri, rdc, rrimin, extentcrit, rlwtb, rdctb, wrtmin, fgwrt, fdwrt
   
   public :: read_rootdistribution, initialize_rootdistribution, update_rootdistribution, reset_rootdistribution
   public :: preparation, sowing, germination, find_active_crop
   
   contains

! ------------------------------------------------------------------------

   subroutine croprotation (task)

      ! ------------------------------------------------------------------

      use MOD_grid,           only: zbotcp, numnod   
      use MOD_swap_base,      only: iun_min2, iun_max2, swpfilnam, unit_swp, fl_initialize, fl_do_not_read_crpfile
      use plant_interface,    only: cropstart, cropend, cropfil, lai, kdir, kdif, vcover
      use variables,          only: t1900, tstart
                  
      implicit  none
      
      ! locals
      integer, intent(in) :: task
      
      integer :: i, ifnd
      !!!real(8) :: lat
      character(len=200) :: message
      logical :: file_exists
      
      ! functions
      integer :: getun2
      
      ! ------------------------------------------------------------------
       
      select case (task)
      
      case (1)
      
         if (fl_do_not_read_crpfile) return
         
         ! open swp file
         call rdinit(unit_swp, unit_err, swpfilnam)
      
         ! crop calendar
         call rdatim ('cropstart',cropstart,macrop,ifnd)
         call rdftim ('cropend',cropend,macrop,ifnd)
         call rdfcha ('cropfil',cropfil,macrop,ifnd)
         call rdfinr ('croptype',1,2,croptype,macrop,ifnd)

         !!!call rdsdor ('lat',-90.0d0,90.0d0,lat)

         do i = 1,ifnd

            ! this is replaced to MOD_meteo
            !!!! check combination detailed crop with LAT>66.5
            !!!if (croptype(i) /= 1 .AND. abs(lat) > 66.5d0) then
            !!!   message = 'Fatal combination for crop '//trim(cropfil(i))//'; detailed crop module within polar circle (LAT>66.5)!'
            !!!   call swap_error ('croprotation', message)
            !!!end if

            ! check sequence of crops
            if (i < ifnd) then
               if ((cropstart(i+1) - cropend(i)) < 0.5d0) then
                  message = 'The begin date of crop '//trim(cropfil(i))//' should be larger than the end date of the former crop!'
                  call swap_error ('croprotation', message)
               end if
            end if

            ! check cropping period
            if ((cropend(i) - cropstart(i) + 1.d0) < 0.5d0) then
               message = 'The end date of crop '//trim(cropfil(i))//' should be larger than the start date!'
               call swap_error ('croprotation', message)
            end if
         
            ! check initial status
            if (tstart > cropstart(i) + 0.5d0 .AND. tstart < cropend(i) + 0.5d0 .AND. swinco /= 3) then
               message = 'Start of simulation (TSTART) begins in growing season with SWINCO 1 or 2!'
               call swap_error ('croprotation', message)
            end if

         end do

         ! rooting depth limitation (by soil conditions)
         if (do_read_rds) call rdsdor ('rds',1.d0,5000.0d0,rdmax)

         ! check if maximum rootdepth exceeds soil profile
         if (abs(zbotcp(numnod)) < rdmax) then
            message ='Maximum rooting depth (RDS) exceeds soil profile'
            call swap_error ('croprotation', message)
         end if
 
         icrop = 1
         fl_readcropfile = .TRUE.
         fl_cropemergence = .FALSE.
         fl_cropharvest = .FALSE.
         fl_cropisreset = .FALSE.
         
         ! close file
         close (unit_swp)

         ! find active crop (fl_cropcalendar needs to be set in case of SWINCO=3)
         call find_active_crop(tstart)
         
         ! set flag start of crop
         fl_start_croprotation = .FALSE.
         if (abs(tstart - cropstart(icrop)) < 1.d-3) fl_start_croprotation = .TRUE.

      case (2)

         ! find active crop
         call find_active_crop(t1900)
         
         ! check crop emergence
         fl_start_croprotation = .FALSE.
         if (fl_cropcalendar) then
            
            ! set flag start of crop             
            if (abs(t1900 - cropstart(icrop)) < 1.d-3) fl_start_croprotation = .TRUE.
            
            if (fl_initialize .OR. fl_start_croprotation) then
               
               fl_readcropfile = .TRUE.
               
               if (.NOT. fl_do_not_read_crpfile) then
                  crpfilnam = trim(pathcrop)//trim(cropfil(icrop))//'.crp'
                  inquire(file = crpfilnam, exist = file_exists)
                  if (.NOT. file_exists) then
                     message ='File '//trim(crpfilnam)//' does not exists!'
                     call swap_error ('croprotation', message)
                  end if        
                  unit_crp = getun2 (iun_min2, iun_max2, 2)
               end if
               
               if (.NOT. fl_initialize) then
                  fl_prep = .FALSE.
                  fl_sow = .FALSE.
                  fl_germ = .FALSE.
                  fl_cropemergence = .FALSE.
                  fl_cropharvest = .FALSE.
               end if
               
               fl_cropisreset = .FALSE.

            end if
            
            ! preparation, sowing and germination
            call cropemergence()

         end if

         ! set initial crop status
         if (fl_cropemergence) then
        
            if (fl_readcropfile) then

               fl_readcropfile = .FALSE.
               
               ! read crop development
               call cropdevelopment (1)
                  
               ! initialize crop development
               call cropdevelopment (2)
               
               !  initialize rootextraction
               call rootextraction_init()

            end if

            ! set correction assimilation due to CO2
            call co2_effect (2)

         end if

         ! set vegetation cover
         vcover = 1.d0 - dexp(-1.d0 * kdir * kdif * lai)
         
      case default
         
         call swap_error ('croprotation', 'Illegal value for TASK')
      
      end select
          
      return
   end subroutine croprotation    

! ------------------------------------------------------------------------

   subroutine find_active_crop(tcurrent)
      use plant_interface, only: cropstart, cropend
      implicit none
      ! global
      real(8), intent(in) :: tcurrent
      ! find active crop
      fl_cropcalendar = .FALSE.
      do while (.NOT. fl_cropcalendar) 
         if (tcurrent < cropstart(icrop) - 0.1d0 .OR. cropstart(icrop) < 1.d0) exit
         if (tcurrent - cropstart(icrop) > -0.1d0 .AND. tcurrent - cropend(icrop) < 0.1d0) then
            fl_cropcalendar = .TRUE.
         else
            icrop = icrop + 1
         end if
      end do
   end subroutine find_active_crop

! ------------------------------------------------------------------------

   subroutine cropemergence
   
      ! ------------------------------------------------------------------
      use MOD_swap_base, only: fl_do_not_read_crpfile
      
      implicit  none
   
      ! ------------------------------------------------------------------
      
      fl_start_cropemergence = .FALSE.
      
      ! preparation, sowing and germination of arable crop growth
      if (fl_cropcalendar .AND. .NOT. fl_cropharvest) then

         ! check crop preparation, sowing and germination (of previous day)
         if (.NOT. fl_cropemergence .AND. .NOT. fl_cropharvest) then
            if (fl_prep .AND. fl_sow .AND. fl_germ) then
               fl_start_cropemergence = .TRUE.
               fl_cropemergence = .TRUE.
               fl_readcropfile = .TRUE.
            end if
         end if

         ! initialize preparation, sowing and germination
         if (.NOT. fl_cropemergence .AND. .NOT. fl_cropharvest) then
            if (fl_readcropfile) then
               
               ! read
               if (.NOT.fl_do_not_read_crpfile) then
                  call preparation (1)
                  call sowing (1)
                  call germination (1)
               end if
               
               ! initialize
               call preparation (2)
               call sowing (2)
               call germination (2)
               
               ! set crop emergence
               if (fl_prep .AND. fl_sow .AND. fl_germ) then
                  fl_start_cropemergence = .TRUE.
                  fl_cropemergence = .TRUE.
               else
                  fl_cropemergence = .FALSE.
               end if
               
               if (.NOT. fl_cropemergence) fl_readcropfile = .FALSE.
            
            end if
         end if

         if (.NOT. fl_cropemergence .AND. .NOT. fl_cropharvest) then
          
            ! preparation before crop growth
            if (.NOT. fl_prep) then
               call preparation (3)
            end if
          
            ! sowing before crop growth
            if (fl_prep .AND. .NOT. fl_sow) then
               call sowing (3)
            end if

            ! germination of arable crop growth
            if (fl_prep .AND. fl_sow) then
               call germination (3)
            end if

         end if
      
      end if   
   end subroutine cropemergence

   ! ---------------------------------------------------------------------
    
   subroutine preparation (task)
    
      ! ------------------------------------------------------------------

      use plant_interface,only: dvs

      implicit none
 
      integer, intent(in) :: task

      real(8) :: dh_prep

      ! functions
      logical :: rdinqr
      real(8) :: h_average
            
      ! ------------------------------------------------------------------

      select case (task)

      case (1)

         ! open connection
         call rdinit(unit_crp, unit_err, crpfilnam)

         ! preparation before crop growth (default = 0)
         sw_prep = 0
         if (rdinqr('swprep')) then
           call rdsinr ('swprep',0,1,sw_prep)
         end if

         if (sw_prep == 1) then

            call rdsdor ('zPrep',-1.d2,0.0d0,z_prep)
            call rdsdor ('hPrep',-2.d2,0.0d0,h_prep)
            call rdsinr ('maxprepdelay',1,366,max_delay_prep)

         end if

         close (unit_crp)
         
         return
      
      case (2)

         if (fl_start_croprotation) then

            fl_prep = .TRUE.
            if (sw_prep == 1) then
               fl_prep = .FALSE.
               delay_prep = 0
            end if

         end if

         return

      case (3)  
      
         ! threshold pressure head
         dh_prep = h_average(z_prep) - h_prep
       
          fl_prep = .TRUE.
          if (dh_prep > 0.d0) then
             if (delay_prep < max_delay_prep) then
                dvs = -0.3d0
                fl_prep = .FALSE.
                delay_prep = delay_prep + 1
             end if
          end if
       
          delay_sow = delay_prep
       
          return        
     
      case default
         call swap_error ('preparation', 'Illegal value for TASK')
      end select

      return

   end subroutine preparation    
   
   ! ---------------------------------------------------------------------
    
   subroutine sowing (task)
    
      ! ------------------------------------------------------------------

      use MOD_SoilTemperature, only : tsoil
      use plant_interface, only: dvs

      implicit none
 
      integer, intent(in) :: task

      integer :: node
      real(8) :: dh_sow
      real(8) :: dtempsow
      character(len=200) message
      
      ! functions
      logical :: rdinqr
      real(8) :: h_average
      
            
      ! ------------------------------------------------------------------

      select case (task)

      case (1)

         ! open connection
         call rdinit(unit_crp, unit_err, crpfilnam)

         ! sowing before crop growth (default = 0)
         sw_sow = 0
         if (rdinqr('swsow')) then
           call rdsinr ('swsow',0,1,sw_sow)
         end if

         if (sw_sow == 1) then

            ! fatal error when sowing is simulated without heat flow
            if (swhea == 0) then
               message = 'In case sowing is calculated, soil heat flow should be simulated: SWHEA=1! Adapt .swp input file.'
               call swap_error ('sowing', message)
            end if

            call rdsdor ('zsow',-1.0d2,0.0d0,z_sow)
            call rdsdor ('hsow',-2.0d2,0.0d0,h_sow)
            call rdsdor ('ztempsow',-1.0d2,0.0d0,z_tempsow)
            call rdsdor ('tempsow',0.0d0,30.0d0,tempSow)
            call rdsinr ('maxsowdelay',1,366,max_delay_sow)

         end if

         close (unit_crp)
         
         return
      
      case (2)

         if (fl_start_croprotation) then

            fl_sow = .TRUE.
            if (sw_sow == 1) then
               fl_sow = .FALSE.
               delay_sow = 0
            end if

         end if
         
         ! determine compartment for sowing
         node = 1
         do 
            if (zbotcp(node) < (z_tempsow + 1.d-8)) exit
            node = node + 1
         end do
         nodsow = node
         
         return         

      case (3)  
     
         ! sowing before crop growth
         
         ! threshold pressure head
         dh_sow = h_average(z_sow) - h_sow
         
         ! threshold temperature
         dtempsow = tsoil(nodsow) - tempsow
       
         fl_sow = .TRUE.
         if (dtempsow < 0.d0 .OR. dh_sow > 0.d0) then
            if (delay_sow < max_delay_sow) then
               dvs = -0.2d0
               fl_sow = .FALSE.
               delay_sow = delay_sow + 1
            end if
         end if
       
         return        
       
      case default
         call swap_error ('sowing', 'Illegal value for TASK')
      end select

      return

   end subroutine sowing    
    
   ! ---------------------------------------------------------------------
    
   subroutine germination (task)
    
      ! ------------------------------------------------------------------

      use atmosphere_interface,only: tav
      use plant_interface, only: dvs

      implicit none
 
      integer, intent(in) :: task

      real(8) :: h_avg,pF_avg
      real(8) :: tsumemesub      
      character(len=200) message
      
      ! functions
      logical :: rdinqr
      real(8) :: h_average
            
      ! ------------------------------------------------------------------

      select case (task)

      case (1)

         ! open connection
         call rdinit(unit_crp, unit_err, crpfilnam)

         ! simulation of germination (default = 0)
         sw_germ = 0
         if (rdinqr('swgerm')) then
            call rdsinr ('swgerm',0,2,sw_germ)
         end if

         if (sw_germ >= 1) then
            
            call rdsdor ('tsumemeopt',0.0d0,1.0d3,tsumemeopt)
            call rdsdor ('tbasem',-20.0d0,4.0d1,tbasem)
            call rdsdor ('teffmx',0.0d0,4.0d1,teffmx)

         end if

         if (sw_germ == 2) then

            call rdsdor ('hdrygerm',-1000.0d0,-1.0d-2,hdrygerm)
            call rdsdor ('hwetgerm',-100.0d0,-1.0d-2,hwetgerm)
            
            zgerm = -1.0d1
            if (rdinqr('zgerm')) then
              call rdsdor ('zgerm',-1.0d2,0.0d0,zGerm)
            end if
            call rdsdor ('agerm',1.0d0,1.0d3,agerm)
            
            if (rdinqr('bgerm') .OR. rdinqr('cgerm')) then
              message = 'Variables bgerm and cgerm are determined by SWAP; they are no longer input (see additional doc)'
              call swap_warning ('germination',message)
            end if
            cgerm = - (tsumemeopt - agerm * log10(-1.d0 * hdrygerm))
            bgerm =   (tsumemeopt + agerm * log10(-1.d0 * hwetgerm))

         end if

         close (unit_crp)
         
         return
      
      case (2)

         if (fl_start_croprotation) then

            fl_germ = .TRUE.
            if (sw_germ >= 1) then
               fl_germ = .FALSE.
               tsumgerm = 0.d0
            end if

         end if

         return         

      case (3)

         ! optimal situation in case germination only depends on temperature
         if (sw_germ == 1) then
         
            tsumemesub = tsumemeopt
           
         ! germination depends on temperature and hydrological conditions
         else if (sw_germ == 2) then
         
            ! average pressure head of rootzone (h and pF)
            h_avg = h_average(zgerm)
            pF_avg = dlog10(max(1.d0,-h_avg))
            
            if (h_avg < hdrygerm) then
               ! dry situation
               tsumemesub = agerm * pF_avg - cgerm
            else if (h_avg >= hdrygerm .AND. h_avg <= hwetgerm) then       
               ! optimal situation
               tsumemesub = tsumemeopt
            else
               ! wet situation
               tsumemesub = -1.d0 * agerm * pF_avg + bgerm
            end if

         end if
       
         ! update of tsumgerm, for the time step of 1 day
         if (tav > tbasem) then
            if (tav < teffmx) then
               if (tsumemesub < 0.1d0) then
                  tsumgerm = tsumgerm + (tav - tbasem)
               else
                  tsumgerm = tsumgerm + (tsumemeopt / tsumemesub) * (tav - tbasem)
               end if
            else
               if (tsumemesub < 0.1d0) then
                  tsumgerm = tsumgerm + (teffmx - tbasem)
               else
                  tsumgerm = tsumgerm + (tsumemeopt / tsumemesub) * (teffmx - tbasem)
               end if
            end if
         end if
           
         ! delay growth until tsumgerm is reached
         fl_germ = .TRUE.
         if (tsumgerm < tsumemeopt) then
            dvs = -0.1d0 * max(1.d0 - (tsumgerm / tsumemeopt), 0.d0)
            fl_germ = .FALSE.
         else
            dvs = 0.d0
         end if
       
         return
       
      case default
         call swap_error ('germination', 'Illegal value for TASK')
      end select

      return

   end subroutine germination    

   ! ---------------------------------------------------------------------

   subroutine co2_effect (task)

      ! ------------------------------------------------------------------
      use MOD_swap_base,   only: iun_min2, iun_max2
      use plant_interface, only: co2, fco2amax, fco2eff, fco2tra
      use variables,       only: iyear
   
      implicit  none
      
      ! locals
      integer, intent(in) :: task
      
      integer :: ifnd
      character(len=200) :: message, filnam
      logical :: file_exists
      integer :: unit_atm
      integer :: sw_atmofil
      integer :: indexyr
      
      ! functions
      logical :: rdinqr
      real(8) :: afgen
      integer :: getun2, ifindi
       
      ! ----------------------------------------------------------------
       
      select case (task)
      
      case (1)
      
         ! open connection
         call rdinit(unit_crp, unit_err, crpfilnam)

         ! correction assimilation due to CO2
         sw_co2 = 0
         if (rdinqr('swco2')) then
           call rdsinr ('swco2',0,1,sw_co2)
         end if

         ! correction assimilation
         if (sw_co2 == 1) then
            
            if (croptype(icrop) == 2) then
               
               call rdadortb ('co2amaxtb',0.d0, 3000.d0, 0.d0, 2.d0, co2amaxtb, macroptb, .FALSE.)
               call rdadortb ('co2efftb',0.d0, 3000.d0, 0.d0, 2.d0, co2efftb, macroptb, .FALSE.)
               
            end if

            call rdadortb ('co2tratb',0.d0, 3000.d0, 0.d0, 2.d0, co2tratb, macroptb, .FALSE.)
            
            sw_atmofil = 1
            if (rdinqr('swatmofil')) then
               call rdsinr ('swatmofil',0,1,sw_atmofil)
            end if

            ! CO2 concentrations specified in current file
            if (sw_atmofil == 0) then
      
               call rdainr ('co2year', 1000, 3000, co2year, mayrs * 10, ifnd)
               call rdfdor ('co2ppm',  10.0d0, 3000.0d0, co2ppm, mayrs * 10, ifnd)
        
            else

               if (rdinqr('atmofil')) then
                  call rdscha ('atmofil', filnam)
                  filnam = trim(pathcrop)//trim(filnam)//'.co2'
               else
                  filnam = trim(pathcrop)//'atmospheric.co2'
               end if
          
            end if
      
         end if  
      
         ! close file with crop data
         close (unit_crp)
    
         ! CO2 concentrations specified in a separate file
         if (sw_co2 == 1 .AND. sw_atmofil == 1) then
         
            inquire(file = filnam, exist = file_exists)
            if (.NOT. file_exists) then
               message ='File '//trim(filnam)//' does not exists!'
               call swap_error ('co2_effect', message)
            end if        
            unit_atm = getun2 (iun_min2, iun_max2, 2)
            call rdinit(unit_atm, unit_err, filnam)
            call rdainr ('co2year', 1000, 3000, co2year, mayrs * 10, ifnd)
            call rdfdor ('co2ppm',  10.d0, 3000.d0, co2ppm, mayrs * 10, ifnd)
         
            close(unit_atm)

         end if
      
      case (2)

         ! initialize CO2 impact
         co2 = 360.d0
         fco2amax = 1.d0
         fco2eff  = 1.d0
         fco2tra  = 1.d0

         ! correction of CO2 impact
         if (sw_co2 == 1) then
        
            indexyr = ifindi (co2year, mayrs*10, 1, mayrs*10, iyear)
            if (indexyr < 1 .OR. indexyr > mayrs*10) then
               message ='Input CO2year or CO2ppm inconsistent, correct'
               call swap_error ('CO2-effect', message)
            end if
            
            co2 = CO2ppm(indexyr)
            if (croptype(icrop) == 2) then
               fco2amax = afgen(co2amaxtb, macroptb, co2)
               fco2eff = afgen(co2efftb, macroptb ,co2)
            end if
            fco2tra = afgen(co2tratb, macroptb, co2)
         
         end if
         
      case default
         
         call swap_error ('CO2-effect', 'Illegal value for TASK')
      
      end select
          
      return

   end subroutine co2_effect
   
   ! ---------------------------------------------------------------------

   subroutine cropdevelopment (task)

   ! ---------------------------------------------------------------------
      
      use plant_interface,    only: croptype, icrop, fl_cropharvestday
      use MOD_fixed,          only: cropfixed
      use MOD_wofost,         only: wofost
      use MOD_swap_base,      only: fl_do_not_read_crpfile
      use MOD_irrigation,     only: irrigation
!DEC$ IF DEFINED (multiswap)
      use MOD_swap_base,      only: id_rotation, id_crop
!DEC$ END IF

      implicit none

      integer, intent(in) :: task

      ! ------------------------------------------------------------------

      select case (task)
      
      case (1)
         
         if (.NOT. fl_do_not_read_crpfile) then

            if (croptype(icrop) == 1) call cropfixed (1)
            if (croptype(icrop) == 2) call wofost (1)

            ! crop factor or crop height
            call cropfactor (1)
         
            ! crop stressor settings
            call read_droughtstress ()
            call read_oxygenstress ()
            call read_salinitystress ()
            call read_compensation ()
      
            ! interception
            call interception (1)

            ! root development
            call read_rootextension()
            call read_rootdistribution ()

            ! CO2 effect
            call co2_effect (1)

            ! irrigation
            call irrigation(1)
         else
!DEC$ IF DEFINED (multiswap)
            call get_all_crop(id_rotation, id_crop)
            !!!call get_all_soil_crop(id_soil, id_crop)
!DEC$ END IF
         end if
         
      case (2)
         
         if (croptype(icrop) == 1) call cropfixed (2)
         if (croptype(icrop) == 2) call wofost (2)

         ! initial crop factor or crop height
         call cropfactor (2)
         
         ! initial interception capacity
         call interception (2)
         
         ! root development
!DEC$ IF DEFINED (multiswap)
            call get_all_crop(id_rotation, id_crop)
            !!!call get_all_soil_crop(id_soil, id_crop)
!DEC$ END IF
         call initialize_rootextension()
         call initialize_rootdistribution()

         ! irrigation
         call irrigation (2)
         
      case (3)
         
         if (croptype(icrop) == 1) call cropfixed (3)
         if (croptype(icrop) == 2) call wofost (3)
         
         ! update crop factor or crop height
         call cropfactor (2)
         
         ! update interception capacity
         call interception (2)
         
         ! root development
         call update_rootextension()
         call update_rootdistribution()
      
      case (4)
         
         if (croptype(icrop) == 1) call cropfixed (4)
         if (croptype(icrop) == 2) call wofost (4)
         
         ! reset root water extraction in case of harvest
         if (fl_cropharvest) then
            fl_cropharvestday = .TRUE.
            call rootextraction_reset()
            call interception (3)
         end if

      case default
      
         call swap_error ('crop development', 'Illegal value for TASK')
      
      end select

      return

   end subroutine cropdevelopment

   ! ---------------------------------------------------------------------
   
   subroutine reset_crop ()
      ! ------------------------------------------------------------------
      ! reset crop status
      ! ------------------------------------------------------------------
      use plant_interface,    only: albedo, rsc, rsw, lai, cf, ch, kdif, kdir,                                  &
                                    sicact, siccap, crsflx_in, crsflx_out, siccaploss,                          &
                                    dvs, tsum, wrt, wst, wlv, wso, dwrt, dwst, dwlv,                            &
                                    grrt, drrt,                                                                 &
                                    laipot, wrtpot, wstpot, wlvpot, wsopot, dwrtpot, dwstpot, dwlvpot,          &
                                    icut, tcut, dmhrv, dmloss, icutpot, tcutpot, dmhrvpot, dmlosspot
      use MOD_wofost,         only: reset_wofost_states_rates
      implicit none
      
      ! ------------------------------------------------------------------

      if (fl_cropisreset) return
      
      ! default values for ETref
      albedo = 0.23d0
      rsc = 70.d0
      rsw = 0.d0

      cf = 0.d0; ch = 0.d0
      kdif = 0.d0; kdir = 0.d0
      
      ! canopy reservoir (Rutter)
      siccap = 0.d0
      sicact = 0.d0
      crsflx_in = 0.d0
      crsflx_out = 0.d0
      siccaploss = 0.d0
      
      ! reset development stage
      dvs  = 0.d0
      tsum = 0.d0
      
      ! reset actual crop status
      laipot = 0.d0; lai = 0.d0 
      wrtpot = 0.d0; wrt = 0.d0; wstpot = 0.d0; wst = 0.d0; wlvpot = 0.d0; wlv = 0.d0; wsopot = 0.d0; wso = 0.d0
      dwrtpot = 0.d0; dwrt = 0.d0; dwstpot = 0.d0; dwst = 0.d0; dwlvpot = 0.d0; dwlv = 0.d0
      
      ! reset WOFOST states and rates
      call reset_wofost_states_rates()
      
      ! reset root development
      grrt = 0.d0; drrt = 0.d0
      call reset_rootextension()
      call reset_rootdistribution()
      
      ! reset root extraction
      call rootextraction_reset()

      ! reset harvest (grass)
      icutpot = 0; icut = 0
      tcutpot = 0; tcut = 0
      dmhrvpot = 0.0d0; dmhrv = 0.0d0
      dmlosspot = 0.d0; dmloss = 0.d0
      
      !fl_cropharvest = .FALSE.
      fl_cropisreset = .TRUE.
      
      return

   end subroutine reset_crop
   
   ! ---------------------------------------------------------------------
   
   subroutine cropfactor (task)

      ! ------------------------------------------------------------------

      use MOD_swap_base, only: swetr
      use plant_interface, only: dvs, swcf, albedo, rsc, rsw, ch, cf
      
      implicit  none
      
      integer, intent(in) :: task
      
      ! locals
      real(8), allocatable :: idx_array(:), val_array(:)
      integer :: i, ifnd
      
      character(len=200) :: message

      ! functions
      logical :: rdinqr
      real(8) :: afgen
       
      ! ----------------------------------------------------------------

      select case (task)
      
      case (1)
       
         ! open connection
         call rdinit(unit_crp, unit_err, crpfilnam)

         ! crop factor or crop height
         call rdsinr ('swcf', 1, 2, swcf)

         ! check use of crop factors in case of ETref
         if (swetr == 1 .AND. swcf == 2) then
            message = 'If ETref is used (SWETR = 1), always define crop factors (SWCF = 1)' 
            call swap_error ('cropfactor', message)
         end if

         if (swcf == 1) then
         
            ! old procedure (deprecated)
            if (rdinqr('dvs')) then
           
               message = 'Usage of DVS and CF are deprecated, use CFTB instead'
               call swap_warning('cropfactor', message)
          
               call rdinne ('dvs', ifnd)
               allocate(idx_array(ifnd))
               allocate(val_array(ifnd))

               call rdfdor ('dvs',0.d0, 2.d0, idx_array, ifnd, ifnd)
               call rdfdor ('cf',0.d0, 2.d0, val_array, ifnd, ifnd)

               cftb(:) = 0.d0
               do i = 1, ifnd
                  cftb(i*2) = val_array(i)
                  cftb(i*2-1) = idx_array(i)
               end do

               deallocate(idx_array, val_array)

            ! new procedure
            else

               call rdadortb('cftb',0.d0, 2.d0, 0.d0, 2.d0, cftb, macroptb, .FALSE.)

            end if          
          
         else
         
            ! old procedure (deprecated)
            if (rdinqr('dvs')) then
           
               message = 'Usage of DVS and CH are deprecated, use CHTB instead'
               call swap_warning('cropfactor', message)
          
               call rdinne ('dvs', ifnd)
               allocate(idx_array(ifnd))
               allocate(val_array(ifnd))

               call rdfdor ('dvs',0.d0, 2.d0, idx_array, ifnd, ifnd)
               call rdfdor ('ch',0.d0, 1.d4, val_array, ifnd, ifnd)

               chtb = 0.d0
               do i = 1, ifnd
                  chtb(i*2) = val_array(i)
                  chtb(i*2-1) = idx_array(i)
               end do

               deallocate(idx_array, val_array)

            ! new procedure
            else

               call rdadortb('chtb',0.d0, 2.d0, 0.d0, 1.d4, chtb, macroptb, .FALSE.)

            end if

         end if

         ! reflection coefficient and crop resistance
         if (swcf == 1) then
         
            ! default values for ETref
            albedo = 0.23d0
            rsc = 70.d0
            rsw = 0.d0
      
         else
         
            ! crop specific values
            call rdsdor ('albedo', 0.d0, 1.d0, albedo)
            call rdsdor ('rsc', 0.d0, 1.d6, rsc)
            call rdsdor ('rsw', 0.d0, 1.d6, rsw)
      
         end if
      
         ! close file with crop data
         close (unit_crp)
         
      case (2)
          
         ! update crop factor or crop height
         if (swcf == 1) then
            cf = afgen (cftb, macroptb, dvs)
         else
            ch = afgen (chtb, macroptb, dvs)
         end if
      
      case default
         
         call swap_error ('cropfactor', 'Illegal value for TASK')
      
      end select

      return
   end subroutine cropfactor

   ! ---------------------------------------------------------------------
   
   subroutine read_droughtstress ()

      ! ------------------------------------------------------------------
      use plant_interface, only: sw_drought, wroottb, hlim3l, hlim3h, hlim4
      
      implicit  none
      
      ! functions
      logical :: rdinqr
       
      ! ----------------------------------------------------------------
       
      ! open connection
      call rdinit(unit_crp, unit_err, crpfilnam)

      ! drought stress
      sw_drought = 1
      if (rdinqr('swdrought')) then
         call rdsinr ('swdrought',1,3,sw_drought)
      end if
      if (sw_drought > 1) then
         call rdsdor ('srl', 1.0d-3, 1.0d10, srl)
         if (croptype(icrop) == 1) then
            call rdadortb('wroottb',0.d0, 2.d0, 1.d0, 1.d4, wroottb, macroptb, .FALSE.)
         end if   
      end if

      if (sw_drought == 1) then                                          
        
         ! drought stress according to Feddes
         call rdsdor ('hlim3h',-10000.0d0,100.0d0,hlim3h)
         call rdsdor ('hlim3l',-10000.0d0,100.0d0,hlim3l)
         call rdsdor ('hlim4' ,-20000.0d0,100.0d0,hlim4)
         call rdsdor ('adcrh',0.0d0,5.0d0,adcrh)
         call rdsdor ('adcrl',0.0d0,5.0d0,adcrl)

      end if
      
      ! close file with crop data
      close (unit_crp)

      return
   end subroutine read_droughtstress

   ! ---------------------------------------------------------------------

   subroutine read_oxygenstress ()

      ! ------------------------------------------------------------------
      use plant_interface, only: sw_oxygen, mrftb, wroottb, q10_root, c_mroot, f_senes
      
      implicit  none
      
      ! locals
      integer :: ifnd
      real(8) :: rootradius
      character(len=200) :: message

      ! functions
      logical :: rdinqr
       
      ! ----------------------------------------------------------------
       
      ! open connection
      call rdinit(unit_crp, unit_err, crpfilnam)

      ! oxygen stress
      sw_oxygen = 1
      if (rdinqr('swoxygen')) then
         call rdsinr ('swoxygen',0,2,sw_oxygen)

         ! fatal error when physical oxygen stress is simulated without numerical heat flow
         if (sw_oxygen == 2 .AND. (swhea == 0 .OR. swcalt == 1)) then
            message = 'In case oxygen stress is calculated according to' // &
            ' physical approach (SWOXYGEN=2), soil heat flow should be' //  &
            ' numerically simulated: SWCALT=2! Adapt .swp input file.'
            call swap_error ('read_stressors', message)
         end if

         ! fatal error when physical oxygen stress is simulated without realistic bdens value
         if (sw_oxygen == 2) then
!            if (.NOT. allocated(bdens)) call swap_error ('oxygenstress', 'BDENS not allocated')
            if (bdens(1) < 100.d0) then
               message = 'In case oxygen stress is calculated according to'//&
               ' physical approach (SWOXYGEN=2), bulk density must have'//  &
               ' realistic values; adjust BDENS-value(s) in .swp input file.'
               call swap_error ('read_stressors', message)
            end if
         end if
         
         ! fatal error when physical oxygen stress is simulated in combination with tillage
         if (sw_oxygen == 2 .AND. swtill == 1) then
            message = 'In case oxygen stress is calculated according to'//&
            ' physical approach (SWOXYGEN=2), tillage (SWTILL=1) is not (yet) allowed'
            call swap_error ('read_stressors', message)
         end if

      end if

      ! oxygen stress according to Feddes
      if (sw_oxygen == 1) then
         
         call rdsdor ('hlim1' ,-100.0d0,100.0d0,hlim1)
         call rdsdor ('hlim2u',-1000.0d0,100.0d0,hlim2u)
         call rdsdor ('hlim2l',-1000.0d0,100.0d0,hlim2l)
      
      end if

      ! oxygen stress according to Bartholomeus
      if (sw_oxygen == 2) then
         
         sw_oxygentype = 1
         if (rdinqr('swoxygentype')) then
            call rdsinr ('swoxygentype',1,2,sw_oxygentype)
         end if

         ! use physical processes
         if (sw_oxygentype == 1) then

            call rdsdor ('q10_microbial', 1.d0, 4.d0, q10_microbial)
            call rdsdor ('specific_resp_humus', 0.d0, 1.d0, specific_resp_humus)
            call rdsdor ('srl', 1.d-3, 1.d10, srl)
            call rdsdor ('rootradius',1.d-4, 1.d0, rootradius); rootradius_m = rootradius * 0.01d0
            
            campbell_h100 = -100.0d0
            if (rdinqr('campbell_h100')) call rdsdor ('campbell_h100',-16000.d0, 0.d0, campbell_h100)
            campbell_h500 = -500.0d0
            if (rdinqr('campbell_h500')) call rdsdor ('campbell_h500',-16000.d0, campbell_h100, campbell_h500)
            gfp_h100 = -100.0d0
            if (rdinqr('gpf_h100')) call rdsdor ('gpf_h100',-16000.d0, 0.d0, gfp_h100)
            
            if (croptype(icrop) == 1) then
               call rdsdor ('q10_root', 1.d0, 4.d0, q10_root)
               call rdsdor ('c_mroot', 0.d0, 1.d0, c_mroot)
               call rdsdor ('f_senes', 0.d0, 1.d0, f_senes)         

               call rdadortb('mrftb',0.d0, 2.d0, 0.d0, 1.d2, mrftb, macroptb, .FALSE.)
               call rdadortb('wroottb',0.d0, 2.d0, 1.d0, 1.d4, wroottb, macroptb, .FALSE.)

            end if

         else
            
            ! use reproduction functions
             
            call rdador ('oxygenslope',-1.d4,1.d4,oxygenslope,6,ifnd)
            call rdador ('oxygenintercept',-1.d3,1.d3,oxygenintercept,6,ifnd)
         
         end if
      
      end if

      ! close file with crop data
      close (unit_crp)

      return
   end subroutine read_oxygenstress
   
   ! ---------------------------------------------------------------------
   
   subroutine read_salinitystress ()

      ! ------------------------------------------------------------------

      implicit  none
      
      ! functions
      logical :: rdinqr
       
      ! ----------------------------------------------------------------
       
      ! open connection
      call rdinit(unit_crp, unit_err, crpfilnam)

      ! salinity stress
      if (swsolu == 1) then

         if (rdinqr('swsalinity')) then
            call rdsinr ('swsalinity',0,1,sw_salinity)
         end if

         ! input for Maas and Hoffman salt reduction function
         if (sw_salinity == 1) then

            call rdsdor ('saltmax',0.0d0,100.0d0,saltmax)
            call rdsdor ('saltslope',0.0d0,1.0d0,saltslope)

         end if
      end if

      ! close file with crop data
      close (unit_crp)

      return
   end subroutine read_salinitystress
   
   ! ---------------------------------------------------------------------
   
   subroutine read_compensation ()

      ! ------------------------------------------------------------------

      use plant_interface, only: sw_drought
   
      implicit  none
      
      ! locals
      character(len=200) :: message
      integer :: sw_jarvis      

      ! functions
      logical :: rdinqr
       
      ! ----------------------------------------------------------------
       
      ! open connection
      call rdinit(unit_crp, unit_err, crpfilnam)

      ! compensation of root water uptake stress (-)
      sw_compensate = 0
      sw_jarvis = 0
      if (rdinqr('swcompensate')) then
         call rdsinr ('swcompensate',0,2,sw_compensate)
      else
         if (rdinqr('swjarvis')) then
            message = 'SWJARVIS is deprecated, use SWCOMPENSATE instead'
            call swap_warning ('read_stressors', message)
            call rdsinr ('swjarvis',0,4,sw_jarvis)
            if (sw_jarvis > 0) then
               if (sw_jarvis /= 4) then
                  message = 'SWJARVIS is applied to all forms of stresses'
                  call swap_warning ('read_stressors', message)
               end if
               sw_compensate = 1
            end if
         end if
      end if
      
      ! check if compensation is combined with microscopic RWU (SWDROUGHT>1)
      if (sw_compensate > 0 .AND. sw_drought > 1) then
         sw_compensate = 0
         message = 'Compensation (SWCOMPENSATE>0) is not allowed in combination with microscopic RWU (SWDROUGHT>1)'
         call swap_error ('read_stressors', message)
      end if
           
      ! selection of stressors to compensate (default: all stressors)
      sw_stressor = 1
      if (sw_compensate > 0) then
         if (rdinqr('swstressor')) call rdsinr ('swstressor',1,5,sw_stressor)
      end if

      ! compensated root water uptake according to Jarvis (1989)
      if (sw_compensate == 1) then
         
         ! criticial stress index for compensation of root water uptake (-)
         alphacrit = 1.0d0
         call rdsdor ('alphacrit',0.2d0,1.0d0,alphacrit)
     
      ! compensated root water uptake according to Walsum (2020)
      else if (sw_compensate == 2) then
        
         ! threshold rootzone depth for compensation of root water uptake (cm)
         dcritrtz = 0.0d0
         call rdsdor ('dcritrtz',0.02d0,100.0d0,dcritrtz)

      end if
      
      ! close file with crop data
      close (unit_crp)

      return
   end subroutine read_compensation

   ! ---------------------------------------------------------------------
    
   subroutine interception (task)

      ! ------------------------------------------------------------------

      use plant_interface, only: sw_inter, cofab, pfreetb, pstemtb, scanopytb, avevaptb, avprectb, siccaplai, sicact, siccap, siccaploss, lai
      use MOD_swap_base, only: swmetdetail, swrain
      implicit  none
      
      integer, intent(in) :: task
      
      ! locals
      integer :: i, ifnd
      real(8), allocatable :: tinter(:), pfree(:), pstem(:), scanopy(:), avprec(:), avevap(:)
      character(len=200) :: message

      ! functions
      logical :: rdinqr
       
      ! ----------------------------------------------------------------
       
      select case (task)
      
      case (1)
      
         ! open connection
         call rdinit(unit_crp, unit_err, crpfilnam)

         ! interception
         call rdsinr ('swinter', 0, 3, sw_inter)
      
         ! check usage of Gash
         if (croptype(icrop) /=1 .AND. sw_inter == 2) then
            message = 'Interception by Gash is not allowed in case of WOFOST (CROPTYPE = 2) or GRASS (CROPTYPE = 3)' 
            call swap_error ('read_interception', message)
         end if
      
         ! check usage of detailed meteo
         if (swmetdetail == 1 .AND. (sw_inter == 1 .OR. sw_inter == 2)) then
            message = 'In case of detailed meteorological conditions (SWMETDETAIL=1)'// &
            ' interception by Von Hoyningen-Hune and Braden (SWINTER=1) or by Gash (SWINTER=2) is not allowed, adapt .crp input file.'
            call swap_error ('read_interception', message)
         end if
      
         ! check usage of detailed rainfall
         if (swrain == 3 .AND. (sw_inter == 1 .OR. sw_inter == 2)) then
            message = 'In case of detailed rainfall (SWRAIN=3)'// &
            ' interception by Von Hoyningen-Hune and Braden (SWINTER=1) or by Gash (SWINTER=2) is not allowed, adapt .crp input file.'
            call swap_error ('read_interception', message)
         end if
      
         if (sw_inter == 1) then
            call rdsdor ('cofab', 1.d-6, 2.d0, cofab)
         else if (sw_inter == 2) then
         
            if (.NOT. rdinqr('t')) call swap_error ('read_interception', 'Variable T not present in file '//trim(crpfilnam))
            call rdinne('t', ifnd)
         
            ! temporary allocate variables
            allocate(tinter(ifnd))
            allocate(pfree(ifnd))
            allocate(pstem(ifnd))
            allocate(scanopy(ifnd))
            allocate(avprec(ifnd))
            allocate(avevap(ifnd))

            call rdfdor ('t', 0.d0, 366.d0, tinter, ifnd, ifnd)
            call rdfdor ('pfree', 0.d0, 1.d0, pfree, ifnd, ifnd)
            call rdfdor ('pstem', 0.d0, 1.d0, pstem, ifnd, ifnd)
            call rdfdor ('scanopy', 0.d0, 10.d0, scanopy, ifnd, ifnd)
            call rdfdor ('avprec', 0.d0, 100.d0, avprec, ifnd, ifnd)
            call rdfdor ('avevap', 0.d0, 10.d0, avevap, ifnd, ifnd)
         
            pfreetb(:) = 0.d0; pstemtb(:) = 0.d0; scanopytb(:) = 0.d0; avprectb(:) = 0.d0; avevaptb(:) = 0.d0
            do i = 1, ifnd
               pfreetb(i*2) = pfree(i)
               pfreetb(i*2-1) = tinter(i)
               pstemtb(i*2) = pstem(i)
               pstemtb(i*2-1) = tinter(i)
               scanopytb(i*2) = scanopy(i)
               scanopytb(i*2-1) = tinter(i)
               avprectb(i*2) = avprec(i)
               avprectb(i*2-1) = tinter(i)
               avevaptb(i*2) = avevap(i)
               avevaptb(i*2-1) = tinter(i)
            end do

            ! deallocate temporary variables
            deallocate(tinter)
            deallocate(pfree)
            deallocate(pstem)
            deallocate(scanopy)
            deallocate(avprec)
            deallocate(avevap)
         
         else if (sw_inter == 3) then
            call rdsdor ('siccaplai', 0.d0, 0.5d0, siccaplai)
            sicact = 0.d0
         end if
      
         ! close file with crop data
         close (unit_crp)

      case (2)   
      
         ! update canopy reservoir capacity
         if (sw_inter == 3) then
            siccap = siccaplai * lai
            
            ! check decrease of reservoir capacity (falling leaves)
            if (sicact > siccap) then
               siccaploss = sicact - siccap
               sicact = siccap
            end if

         end if
      
      case (3)

         ! reset canopy reservoir capacity
         if (sw_inter == 3) then
            siccaploss = siccaploss + sicact
         end if
         
      case default
         
         call swap_error ('interception', 'Illegal value for TASK')
      
      end select
         
      return
   end subroutine interception

   ! ---------------------------------------------------------------------
   ! Section: root extension
   ! ---------------------------------------------------------------------

   subroutine read_rootextension ()
   
      use MOD_grid, only: layer
      use MOD_texture_orgmat, only: orgmat
      use plant_interface, only: sw_oxygen, wrtmax
      use MOD_swap_base, only: swpfilnam, unit_swp
      implicit none
   
      ! local variables
      integer                       :: node
      character(len=200)            :: message
   
      ! functions
      logical                       :: rdinqr

      ! ----------------------------------------------------------------
      
      ! open connection
      call rdinit(unit_crp, unit_err, crpfilnam)

      ! switch development root extension
      swrd = 1
      if (rdinqr('swrd')) then
        call rdsinr ('swrd',1,3,swrd)
      end if
      
      ! check root extension based on root biomass
      if (croptype(icrop) == 1 .AND. swrd == 3) then
         call swap_error ('rootextension', 'Root extension based on available root biomass is not possible with simple cropgrowth module.')
      end if
      
      ! root extension depends on development stage
      if (swrd == 1) then
        
         call rdadortb ('rdtb',0.d0, 3.d0, 0.d0, 1000.d0, rdtb, macroptb, .FALSE.)
          
      ! root extension depends on maximum daily increase
      else if (swrd == 2) then
        
        call rdsdor ('rdi',0.0d0,1000.0d0,rdi)
        call rdsdor ('rri',0.0d0,100.0d0,rri)
        call rdsdor ('rdc',0.0d0,1000.0d0,rdc)

        ! rooting depth influenced by dry matter increase (transpiration)
        swdmi2rd = 0
        if (rdinqr('swdmi2rd')) call rdsinr ('swdmi2rd',0,2,swdmi2rd)
        
        ! threshold for maximum root extension
        if (swdmi2rd == 2) then
           call rdsdor ('rrimin',0.d0,rri,rrimin)
           call rdsdor ('extentcrit',1.d-5,1.d0,extentcrit)
        end if
      
      ! root extension on available root biomass  
      else if (swrd == 3) then
        
         call rdadortb ('rlwtb',0.d0, 5000.d0, 0.d0, 5000.d0, rlwtb, macroptb, .FALSE.)
         
        call rdsdor ('wrtmax',0.d0,100000.d0,wrtmax)

      end if      
      
      ! check oxygen stress for development root extension
      swwrtnonox = 0
      if (sw_oxygen > 0) then

         if (rdinqr('swwrtnonox')) then
            call rdsinr ('swwrtnonox',0,1,swwrtnonox)
         end if

         aeratecrit = 0.0001d0
         if (swWrtNonox == 1) then
            call rdsdor ('aeratecrit',1.d-4,1.d0,aeratecrit)
         end if
      end if
      
      close(unit_crp)

      ! open swp file
      call rdinit(unit_swp, unit_err, swpfilnam)

         ! rooting depth limitation (by soil conditions)
         if (do_read_rds) call rdsdor ('rds',1.d0,5000.0d0,rdmax)

         ! check if maximum rootdepth exceeds soil profile
!         if (abs(zbotcp(numnod)) < rdmax) then
!            message ='Maximum rooting depth (RDS) exceeds soil profile'
!            call swap_error ('croprotation', message)
!         end if
      close(unit_swp)

      ! determine maximum rooting depth
      rdm = get_rdm()
      
      ! check organic matter (in case of SWOXYGEN=2)
      if (sw_oxygen == 2) then
         node = 1
         do 
            if (zbotcp(node) < (-rdm + 1.d-8)) exit
            if (.NOT.(orgmat(layer(node)) > 0.d0)) then
               message ='Rootzone should contain organic matter in case of SWOXYGEN=2.'
               call swap_error ('root_development', message)
            end if
            node = node + 1
         end do
      end if

   end subroutine read_rootextension

   function get_rdm() result(rdm)
      use plant_interface, only: wrtmax
      implicit none
      real(8) :: rdm
      real(8) :: afgen
      if (swrd == 1) then
         rdm = rdmax
      else if (swrd == 2) then
         rdm = min(rdmax, rdc)
      else if (swrd == 3) then
         rdc = afgen (rlwtb, macroptb, wrtmax)
         rdm = min(rdmax,rdc)
      end if
   end function get_rdm
   
   ! ---------------------------------------------------------------------
    
   subroutine initialize_rootextension ()

      ! ------------------------------------------------------------------

      use plant_interface, only: fl_start_cropemergence, dvs, noddrz, wrt

      implicit none
   
      ! local variables
      integer                       :: node
   
      ! functions
      real(8)                       :: afgen
      
      ! ------------------------------------------------------------------

      if (fl_start_cropemergence) then
      
         ! actual and potential rooting depth
         if (swrd == 1) then
            rd = afgen (rdtb, macroptb, dvs)
            rd = min(rd, rdm)
         else if (swrd == 2) then
            rd = min(rdi, rdm)
         else if (swrd == 3) then
            rdi = afgen (rlwtb, macroptb, wrt)
            rd = min(rdi, rdm)
         end if
         rdpot = rd
      end if

      ! determine lowest compartment containing roots
      node = 1
      do 
         if (zbotcp(node) < (-1.d0 * rd + 1.d-8)) exit
         node = node + 1
      end do
      noddrz = node
      return
        
   end subroutine initialize_rootextension

   ! ---------------------------------------------------------------------

   subroutine update_rootextension ()
      
      ! ------------------------------------------------------------------
      
      use MOD_params, only: nihil, tiny, small
      use MOD_arrays, only: macroptb
      use plant_interface, only: dvs, noddrz, wrt, grrt, wrtpot, grrtpot, sw_oxygen, sw_drought
      use MOD_integral, only: iptra_day, iqrot_day, ialpdry_day, ialpwet_day
      
      implicit none
      
      ! local variables
      integer :: node
      real(8) :: rrpot
      logical :: fl_rootextension
      real(8) :: grrt_needed
      
      ! functions
      real(8) :: afgen
   
      ! ----------------------------------------------------------------
   
      ! check if potential root extension is allowed (only in case of SWRD=2)
      if (swrd == 2) then
      
         fl_rootextension = .TRUE.
          
         ! stop rootextension in case of zero transpiration or if no assimilates have been allocated to roots
         if (iptra_day < nihil) fl_rootextension = .FALSE.
         if (croptype(icrop) == 1 .AND. (swrdc == 1 .OR. sw_drought > 1 .OR. sw_oxygen == 2)) then
            if (grrtpot < tiny)  fl_rootextension = .FALSE.
         else if (croptype(icrop) == 2) then
            if (grrtpot < tiny) fl_rootextension = .FALSE.
         end if
      
      end if
      
      ! update potential root extension
      if (swrd == 1) then
      
         rdpot = afgen (rdtb, macroptb, dvs)
         rdpot = min(rdpot, rdm)
      
      else if (swrd == 2) then
        
         rrpot = min (rdm - rdpot, rri)
         if (rrpot > 0.d0 .AND. fl_rootextension) then
            rdpot = rdpot + rrpot
         end if

      else if (swrd == 3) then
        
         rdpot = afgen (rlwtb, macroptb, wrtpot)
         rdpot = min(rdpot, rdm)
      
      end if
      
      
      ! check if actual root extension is allowed (only in case of SWRD=2)
      if (swrd == 2) then

         fl_rootextension = .TRUE.

         ! stop rootextension in case of zero transpiration or if no assimilates have been allocated to roots
         if (iptra_day < nihil) fl_rootextension = .FALSE.
         if (croptype(icrop) == 1 .AND. (swrdc == 1 .OR. sw_drought > 1 .OR. sw_oxygen == 2)) then
            if (grrt < tiny)  fl_rootextension = .FALSE.
         else if (croptype(icrop) == 2) then
            if (grrt < tiny) fl_rootextension = .FALSE.
         end if
         
         ! stop root extension in case oxgenstress exceeds aeratecrit
         if (swwrtnonox == 1) then
            if (ialpwet_day < aeratecrit) fl_rootextension = .FALSE.
         end if

      end if   
      
      ! update actual root extension
      if (swrd == 1) then
      
        rd = rdpot
      
      else if (swrd == 2) then
        
         rr = min(rdm - rd, rri)
         if (rr > 0.d0 .AND. fl_rootextension) then
            if (iptra_day >= nihil) then
               if (swdmi2rd == 1) rr = rr * iqrot_day / iptra_day
               if (swdmi2rd == 2) then
                  rr = max(min(rr, rrimin), rr * min(1.d0, (1.d0 - ialpdry_day) / extentcrit))

                  ! reduce downward growth if not enough assimilates to roots
                  grrt_needed = (wroot_node(noddrz) / (rd + ztopcp(noddrz))) * rr
                  if (grrt_needed > grrt) then
                     rr = rr * (grrt / grrt_needed)
                  end if
               end if
               if (rr < small) rr = 0.d0
               rd = rd + rr
            end if   
         else
            rr = 0.d0 
         end if
         
      else if (swrd == 3) then
        
         rd = afgen (rlwtb, macroptb, wrt)
         rd = min(rd, rdm)
      
      end if
      
      ! determine lowest compartment containing roots
      noddrz_old = noddrz
      node = 1
      do 
         if (zbotcp(node) + rd < nihil) exit
         node = node + 1
      end do
      noddrz = node
      
   end subroutine update_rootextension
   
   ! ---------------------------------------------------------------------
   
   subroutine reset_rootextension

      use plant_interface, only: noddrz

      implicit none

      ! ------------------------------------------------------------------

      rd = 0.d0
      rdpot = 0.d0
      
      noddrz = 0
      
      return
      
   end subroutine reset_rootextension

   ! ---------------------------------------------------------------------
   ! Section: root distribution
   ! ---------------------------------------------------------------------

   subroutine read_rootdistribution ()
   
      use plant_interface, only: wroottb
      use MOD_arrays, only: macroptb
      use MOD_params, only: nihil
      
      implicit none
   
      ! local
      integer                       :: ifnd
   
      ! functions
      logical                       :: rdinqr

      ! ----------------------------------------------------------------
      
      ! open connection
      call rdinit(unit_crp, unit_err, crpfilnam)

      ! development root density (default: static)
      swrdc = 0
      if (rdinqr ('swrdc')) then
        
         ! switch for adaptive root density
         call rdsinr ('swrdc',0,1,swrdc)
        
         ! set factor of growth root weight which is adaptive (swrcd=1)
         if (swrdc == 1) then

            wrtmin = 1.d0
            if (rdinqr ('wrtmin')) call rdsdor ('wrtmin',0.1d0,100.d0,wrtmin)
          
            fgwrt = 0.d0
            if (rdinqr ('fgwrt')) call rdsdor ('fgwrt',0.0d0,1.0d0,fgwrt)
        
            fdwrt = 0.d0
            if (rdinqr ('fdwrt')) call rdsdor ('fdwrt',0.0d0,1.0d0,fdwrt)

            ! set root weight in case of static crop growth
            if (croptype(icrop) == 1) then
               call rdadortb('wroottb',0.d0, 2.d0, 1.d0, 1.d4, wroottb, macroptb, .FALSE.)
            end if

        end if
        
      end if
      
      ! hidden switch: keep Lrv constant (default: 0 = no)
      swLrvconstant = 0
      if (rdinqr('swLrvconstant')) call rdsinr ('swLrvconstant', 0, 1, swLrvconstant)

      ! root density
      call rdadortb ('rdctb',0.d0, 3.d0, 0.d0, 100.d0, rdctb, macroptb, .FALSE.)
      call rdinne('rdctb', ifnd)
      
      ! check specified root density
      if (abs(rdctb(1)) >= nihil .OR. abs(rdctb(ifnd - 1)  - 1.d0) >= nihil) call swap_error ('rootdistribution', 'relative depth should be specified for range 0.0 - 1.0 (RDCTB)')
      
      close(unit_crp)
      
   end subroutine read_rootdistribution
   
   ! ---------------------------------------------------------------------

   subroutine initialize_rootdistribution
   
      use plant_interface, only: fl_start_cropemergence, sw_drought, sw_oxygen
      
      implicit none
   
      ! ------------------------------------------------------------------

      ! cumulative root density profile
      call initialize_cumdens()
      
      if (fl_start_cropemergence) then

         ! initialize cumulative root density profile
         call initialize_cumdens()
      
         ! update cumulative root density at each compartment
         cumdens_top(:) = 0.d0
         call update_cumdens_top()
          
         ! update weight root at each compartment
         if (swrdc == 1 .OR. sw_drought > 1 .OR. sw_oxygen == 2) then
         
            ! reset wroot_node, wroot_node_top and lrv_node
            wroot_node(:) = 0.d0
            wroot_node_top(:) = 0.d0
            lrv_node(:) = 0.d0
      
            call finalize_wroot_node()
         end if
      
      end if

   end subroutine initialize_rootdistribution

   ! ---------------------------------------------------------------------   
   
   subroutine update_rootdistribution ()

      use plant_interface, only: sw_drought, sw_oxygen

      implicit none
      
      ! ----------------------------------------------------------------
      
      ! in case of adaptive root growth
      if (swrdc == 1) then
         ! update root weight based on root extraction or stress (cumdens)
         call update_wroot_node()
         
         ! update normalized cumulative root density (cumdens)
         call update_cumdens()
      end if

      ! update cumulative root density at each compartments
      call update_cumdens_top()
          
      ! update weight of roots at each compartment
      if (swrdc == 1 .OR. sw_drought > 1 .OR. sw_oxygen == 2) call finalize_wroot_node()
      
   end subroutine update_rootdistribution

   ! ---------------------------------------------------------------------
    
   subroutine initialize_cumdens()

      ! ----------------------------------------------------------------
      ! Purpose: initialize the normalized cumulative root density 
      !          distribution.
      ! ----------------------------------------------------------------

      ! local
      implicit none
 
      integer :: i
      real(8) :: afgen
      real(8) :: rdepth, sum
      real(8), allocatable :: rootdist(:)

      ! determine number of nodes in maximum rootzone
      i = 1
      do
        if (zbotcp(i) < (-rdm + 1.d-8)) exit
        i = i + 1
      end do
      mxnoddrz = i

      ! allocate and initialize rootdist and cumdens
      allocate(rootdist((mxnoddrz+1)*2))
      rootdist(:) = 0.d0
      cumdens(:) = 0.d0
      
      ! specify rootdist based on modelinput (rdctb)
      rootdist(2) = afgen(rdctb, macroptb, 0.d0)
      do i = 1,mxnoddrz
        rdepth = min(1.d0, abs(zbotcp(i) / rdm))
        rootdist(i*2+1) = rdepth
        rootdist(i*2+2) = afgen(rdctb, macroptb, rdepth)
      end do
      
      ! set cumulative root density
      sum = 0.d0
      cumdens(2) = 0.d0
      do i = 1,mxnoddrz
        sum = sum + (rootdist(i*2) + rootdist(i*2+2)) * 0.5d0 * (rootdist(i*2+1) - rootdist(i*2-1))
        cumdens(i*2+1) = rootdist(i*2+1)
        cumdens(i*2+2) = sum
      end do
      
      ! normalize cumulative root density
      do i = 1,mxnoddrz
        cumdens(i*2+2) = cumdens(i*2+2) / sum
      end do        
      
      ! clean up
      deallocate(rootdist)
      return
   end

   ! ---------------------------------------------------------------------
   
   subroutine update_wroot_node()

      ! ------------------------------------------------------------------
      !     Purpose: update weight of roots at each node. The weight
      !              is modified by growth of root biomass based on
      !              relative root water extraction or stress 
      !              (for uncompensated situation).
      ! ------------------------------------------------------------------
      
      use plant_interface, only: noddrz, wrt, grrt, drrt
      
      implicit none
 
      integer :: node
      real(8) :: wrt_old, rd_old
      real(8) :: qrotrtz, qredrtz_pos
      real(8) :: grrt_oldnod, grrt_newnod, f_rootextension
      
      ! ------------------------------------------------------------------
      
      ! reconstruct root weight and depth rootzone at start of day
      wrt_old = wrt - grrt + drrt
      rd_old = rd - rr
      
      ! split root growth in old nodes and in new nodes (root extension)
      grrt_newnod = min((wroot_node(noddrz_old) / (rd_old + ztopcp(noddrz_old))) * rr, grrt)
      grrt_oldnod = grrt - grrt_newnod
      
      ! determine (reduction of) transpiration of rootzone
      qrotrtz = sum(inqpotrot_day(1:noddrz) - max(0.0d0, inqredrot_day(1:noddrz)))
      qredrtz_pos = sum(max(0.0d0, inqredrot_day(1:noddrz)))
      
      ! update weight of roots at existing rootzone
      do node = 1, noddrz_old

        ! growth of roots
        if (grrt > 0.d0) then
           if (qrotrtz > 0.d0) then
              wroot_node(node) = wroot_node(node) + ((1.0d0 - fgwrt) * wroot_node(node) / wrt_old &
                                                  + fgwrt * max(0.0d0, (inqpotrot_day(node) - max(0.0d0, inqredrot_day(node)))) / qrotrtz) * grrt_oldnod
           else
              wroot_node(node) = wroot_node(node) + wroot_node(node) / wrt_old * grrt_oldnod
           end if
        end if

        ! death of roots
        if (drrt > 0.d0) then
           if (qredrtz_pos > 0.d0) then
              wroot_node(node) = wroot_node(node) - ((1.0d0 - fdwrt) * wroot_node(node) / (wrt_old + grrt_oldnod) &
                                                     + fdwrt * max(0.0d0, inqredrot_day(node)) / qredrtz_pos) * drrt
           else
              wroot_node(node) = wroot_node(node) - (wroot_node(node) / (wrt_old + grrt_oldnod) * drrt)
           end if
           wroot_node(node) = max(min(dz(node), rd_old + ztopcp(node)) * wrtmin, wroot_node(node))
        end if
      end do
      
      ! update weight of roots at root extension
      if (rr > 0.d0) then
         
         ! growth of roots
         do node = noddrz_old, noddrz, 1
            
            ! fraction of total root extension
            f_rootextension = 0.d0
            if (rd_old + zbotcp(node) < 0.d0 .AND. rr > 0.d0) then
               f_rootextension = (min(dz(node), rd + ztopcp(node)) - max(0.d0, rd_old + ztopcp(node))) / rr
            end if
            
            wroot_node(node) = wroot_node(node) + f_rootextension * grrt_newnod
         
         end do
      end if    
      
      return
   end
    
   ! ---------------------------------------------------------------------

   subroutine update_cumdens()

      ! ------------------------------------------------------------------
      ! update the normalized cumulative root density distribution
      ! ------------------------------------------------------------------

      use plant_interface, only: noddrz
      
      implicit none
 
      integer :: node
      real(8) :: cwrt, twrt
      real(8) :: rdepth
      real(8) :: rd_noddrz
      
      ! reset cumulative root density
      cumdens(:) = 0.d0
      
      ! update weight of roots at each compartment
      twrt = 0.d0
      do node = 1, noddrz
        twrt = twrt + wroot_node(node)
      end do
      
      ! update normalized cumulative root density
      rd_noddrz = abs(zbotcp(noddrz))
      cumdens(2) = 0.d0
      cwrt = 0.d0
      do node = 1,noddrz
        rdepth = abs(zbotcp(node) / rd_noddrz)
        cwrt = cwrt + wroot_node(node)
        cumdens(node*2+1) = rdepth
        cumdens(node*2+2) = cwrt / twrt
      end do
      
      return
   end
    
   ! ---------------------------------------------------------------------

   subroutine update_cumdens_top()

      ! ------------------------------------------------------------------
      ! update cumulative root density distribution at top of each node
      ! ------------------------------------------------------------------

      use plant_interface, only: noddrz
      
      implicit none
 
      integer :: node 
      real(8) :: afgen
      real(8) :: rdepth, rd_noddrz
      
      ! update cumulative root density at each compartments
      cumdens_top(1) = 0.d0
      rd_noddrz = abs(zbotcp(noddrz))
      do node = 1,noddrz
        rdepth = abs(zbotcp(node) / rd_noddrz)  
        cumdens_top(node + 1) = afgen(cumdens, (macp+1)*2, rdepth)
      end do
      return
   end
    
   ! ---------------------------------------------------------------------
   
   subroutine reset_rootdistribution

      ! ------------------------------------------------------------------

      ! local
      implicit none
      
      cumdens(:) = 0.d0
      cumdens_top(:) = 0.d0
      wroot_node(:) = 0.d0; wroot_node_top(:) = 0.d0; lrv_node(:) = 0.d0
      
      return
      
   end subroutine reset_rootdistribution

   ! ---------------------------------------------------------------------
    
    subroutine finalize_wroot_node()

      ! ----------------------------------------------------------------
      ! Date: Dec 2021
      ! Purpose: update weight of roots at each compartment.
      ! ----------------------------------------------------------------

      use plant_interface, only: noddrz, wrt
      
      implicit none
      
      real(8) :: rd_noddrz, afgen
      integer :: node 
      
      ! ----------------------------------------------------------------
      
      ! update weight of roots at each compartment
      do node = 1, noddrz
        wroot_node(node) = (cumdens_top(node + 1) - cumdens_top(node)) * wrt
        lrv_node(node) = wroot_node(node) * SRL / (1.0d6 * dz(node))               ! LRV: cm cm-3; NOTE: SRL is input in m/kg !
      end do
      do node = 2, noddrz
        wroot_node_top(node) = 0.5d0 * (wroot_node(node-1) / dz(node-1) + wroot_node(node) / dz(node))
      end do
      wroot_node_top(1) = max(0.d0, wroot_node(1) / dz(1) + (wroot_node(1) / dz(1) - wroot_node_top(2) / dz(2)))
     
      ! convert unit from kg ha-1 to kg m-3 (needed for oxygenstress)
      wroot_node_top(1:noddrz) = wroot_node_top(1:noddrz) * 1.0d-4 / (1.0d-2 * dz(1:noddrz))
      
      ! in case Lrv is forced to be constant (at least at soil surface)
      if (swLrvconstant == 1) then
         rd_noddrz = abs(zbotcp(noddrz))
         do node = 1, noddrz
            lrv_node(node) = dmax1(0.01d0, afgen(rdctb, macroptb, -1.d0 * z(node) / rd_noddrz))
         end do
      end if
      
    return
    
    end subroutine finalize_wroot_node

! ------------------------------------------------------------------------
    
end module MOD_cropdevelopment
