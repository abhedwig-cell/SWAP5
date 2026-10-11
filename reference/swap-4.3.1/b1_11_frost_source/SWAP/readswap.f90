! File VersionID:
!   $Id: readswap.f90 379 2018-05-16 07:02:44Z heine003 $
! ----------------------------------------------------------------------
      subroutine readswap
! ----------------------------------------------------------------------
!     Date               : April 2014   
!     Purpose            : read main input file .SWP
! ----------------------------------------------------------------------
      use MOD_arrays
      use MOD_grid,                 only: zbotcp, numlay
      use MOD_swap_base,            only: iun_min2, iun_max2, swpfilnam, project, pathwork, unit_swp, unit_log, unit_err, fl_initialize, swinco, swcrop, swcropsnm,      &
                                          swhea, swsnow, swfrost, swdra, swmacro, swrunon, swirfix, swpondmx, swhyst, sw_multi_swap
      use plant_interface,          only: albedo, rsc, rsw
      use MOD_MvG,                  only: swsophy, ihwckmodel, paramvg, sw_use_elas, numtab, numtablay, ientrytab, ientrytablay, sptab, sptablay, h_enpr_global
      use MOD_MvG,                  only: fl_use_tables, wc_intercept, wc_slope, cap_intercept, cap_slope, con_intercept, con_slope, n_entries, fl_use_kh_power
      use MOD_snow,                 only: swsublim, snowinco, teprrain, teprsnow, snowcoef
      use MOD_frost,                only: tfroststa, tfrostend
      use MOD_drain,                only: drfil
      use MOD_swap_mp,              only: SwDrRap
      use MOD_macropore,            only: read_macropore
      use MOD_Kavg_Szym
      use SWAP_csv_output,          only: inlist_csv, tz_z1_z2, swdiscrvert, numnodnew, dznew, num_d
      use MOD_meteo,                only: swevap, cfevappond
      use MOD_runon,                only: read_runon
      use MOD_irrigation,           only: read_irrigation_fixed
      use variables,                only: outfil, swcsv, CritDevBalCp, CritDevBalTot, numbit_crit, fact_dt_increase, fact_dt_decrease, fact_dt_fldect,            &
                                          flmaxitertime, maxitertime, swcofqhc, cofqhc, hplate, tstart, iyear, imonth, tend, outdat, nprintday,flprintdt,         &
                                          outdatint, period, swres, swodat, swheader, swafo, swaun, critdevmasbal, swbal, swsba, swblc, htb, nhead, gwli, rsro,   &
                                          rsroexp, pondmxtab, pondmx, swcfbs, cfbs, rsoil, swredu, rsigni, cofred, tau, fhyst, flksatexm, ksatfit, ksatexm, dtmin,&
                                          dtmax, gwlconv, critdevponddt, critdevh1cp, critdevh2cp, maxit, maxbacktr, msteps, swkmean, swkimpl, gwltab, hbotab,    &
                                          qbotab, haqtab, swbotb, sw2, sinave, sinamp, sinmax, swbotb3impl, shape_3, hdrain, rimlay, swbotb3resvert, sw3, aqave,  &
                                          aqamp, aqtmax, aqper, sw4, swqhbot, cofqha, cofqhb, indeks
      use WC_K_models_04_11,        only: bimodal, novap
      use Wofost_Soil_Declarations, only: snmfil
      use MOD_cropdevelopment,      only: croprotation
      use doln
      use iso_fortran_env,          only: compiler_version, compiler_options
      use MOD_RIA,                  only: RIA_Reader
      use SHPvariables,             only: SWRCpars, UHCCpars

      
      implicit none

      integer i,datea(6)
      integer getun2, unit_bbc, unit_sol
      integer datefix(2),ifnd,swyrvar,swmonth
      integer swbbcfile
      integer lay
      integer j
      integer swvapor(maho)

      real(4) fsec
      real(8) elas(maho)         ! Array with elasticity (1/L) for each soil layer
      real(8) outdate1
      real(8) ores(maho),osat(maho),alfa(maho),npar(maho), h_power(maho), k_power(maho)
      real(8) alfa_2(maho),npar_2(maho),omega_1(maho)       ! for bi-modal MvG
      real(8) h0(maho), ha(maho), apar(maho), omega_K(maho) ! for PDI
      real(8) lexp(maho),alfaw(maho)
      real(8) dates(mabbc),gwlevel(mabbc)
      real(8) haquif (mabbc),hbottom(mabbc)
      real(8) hhtab(mabbc),qhtab(mabbc),qboti(mabbc)
      real(8) help,term1,term2,sc,se,m,relsatthr,ksatthr
      real(8) headtab(matab),thetatab(matab),conductab(matab)
      real(8) dydx(matab),pondmxtb(mairg),datepmx(mairg),sigma(matab)
      real(8) dum, dum1, dum2, dum3, dum4, dum5, dum6, dum7, dum8, dum9, dummy
      real(8), dimension(:), allocatable :: z_ini, h_ini
      character(len=200) filenamesophy(maho)
      character(len=200) filnam
      character(len=80)  filtext
      character(len=32)  bbcfil
      
      character(len=400) message
      logical            file_exists

      logical :: flsat, rdinqr, rdinar
      integer :: swetr, swdivide, swmetdetail, n_metdetail, swrain

      real(8), parameter :: vsmall = 1.d-16
      real(8), parameter :: nihil  = 1.d-24

      character(len=256)                  :: SWAP_SOILS_DB     ! name of database file with soil physical parameters
      character(len=40), dimension(maho)  :: SOILNAMES         ! names of soil from soils database to be used
      integer                             :: idb               ! for unit number to open SWAP_SOILS_DB
      character(len=1)                    :: cdum = "-"        ! dummy
      integer                             :: iunf
      real(8), dimension(:), allocatable  :: ardummy
      character(len=80), dimension(maho)  :: tabnames

!     pressure head where interpolation is used to calculate K from VG and ksatexm
      real(8), parameter :: hthr = -2.0d0
! ----------------------------------------------------------------------

! --- write message running to screen
      write (*,'(/,a)') '  running swap ....'

! --  write head to logfile
      filtext = 'Main input variables'
      call writehead(unit_log,1,swpfilnam,filtext,project)
      write (unit_log,*)
      write(unit_log,'(2A)') '* compiler version : ', compiler_version()
      write(unit_log,'(2A)') '* compiler options : ', compiler_options()
      write (unit_log,*)

! --- open swp file
      call rdinit(unit_swp,unit_err,swpfilnam)

! -   simulation period
      if (sw_multi_swap == 0) call rdstim('tstart',tstart)
      call dtdpar (tstart+0.1d0, datea, fsec)
      iyear = datea(1)
      imonth = datea(2)
      call dtdpar (tstart, datea, fsec)
      if (sw_multi_swap == 0) call rdstim('tend',tend)
! -   check begin and end date of simulation
      if ((tend - tstart) < 0.d0) call swap_error ('readswap', 'The end date of the simulation should be larger than the begin date!')

! -   Output dates for balances
      call rdsinr ('swyrvar',0,1,swyrvar)
      if (swyrvar == 0) then 
        call rdfinr('datefix',1,31,datefix,2,2)
        datea(1) = iyear
        datea(2) = datefix(2)
        datea(3) = datefix(1)
        fsec = 0.0
        call dtardp (datea, fsec, outdate1)
        if (outdate1 < tstart) then
          datea(1) = datea(1) + 1
          call dtardp (datea, fsec, outdate1)
        end if
        i = 1
        outdat(i) = outdate1
        datea(1) = datea(1) + 1
        call dtardp (datea, fsec, outdate1)
        do while (outdate1 < (tend + 0.1d0))
          i = i + 1
          outdat(i) = outdate1
          datea(1) = datea(1) + 1
          call dtardp (datea, fsec, outdate1)
        end do
      else
        call rdatim ('outdat',outdat,maout,ifnd)
      end if

! -   Intermediate output dates
      call rdsinr ('nprintday',1,1440,nprintday)

! --- output each time interval dt
      flprintdt = .FALSE.
      if (rdinqr('flprintdt')) then
        call rdslog ('flprintdt',flprintdt)
      end if

      call rdsinr ('swmonth',0,1,swmonth)
      if (swmonth == 1) then 
        datea(1) = iyear
        datea(2) = imonth
        if (datea(2) < 12) then
          datea(2) = datea(2) + 1          
        else
          datea(1) = datea(1) + 1          
          datea(2) = 1          
        end if
        datea(3) = 1
        fsec = 0.0
        call dtardp (datea, fsec, outdate1)
        i = 0
        do while ((outdate1 - 1.d0) < (tend + 0.1d0))
          i = i + 1
          outdatint(i) = outdate1 - 1.d0
          if (datea(2) < 12) then
            datea(2) = datea(2) + 1          
          else
            datea(1) = datea(1) + 1          
            datea(2) = 1          
          end if
          call dtardp (datea, fsec, outdate1)
        end do
        period = 0
        swres  = 0
        swodat = 0
      else
        call rdsinr ('period',0,366,period)
        call rdsinr ('swres',0,1,swres)
        
        call rdsinr ('swodat',0,1,swodat)
        if (swodat == 1) then  
          call rdatim ('outdatint',outdatint,maout,ifnd)
        end if  
      end if

! -   output files
      call rdscha ('outfil',outfil)
      call rdsinr ('swheader',0,1,swheader)

      swafo = 0; if (rdinqr('swafo')) call rdsinr ('swafo',0,3,swafo)
      swaun = 0; if (rdinqr('swaun')) call rdsinr ('swaun',0,2,swaun)
      if (swaun >= 1 .OR. swafo >= 1) then
        call rdsinr ('swdiscrvert',0,1,swdiscrvert)
        if (swdiscrvert == 1) then
          call rdsinr ('numnodNew',1,macp,numnodNew)
          call rdfdor ('dzNew',1.0d-6,5.0d2,dzNew,macp,numnodNew)
        end if
        call rdsdor ('CritDevMasBal',1.0d-30, 1.0d0,CritDevMasBal)
      end if
      
      swcsv = 0
      if (rdinqr('swcsv')) then
        call rdsinr ('swcsv',0,3,swcsv)
        if (swcsv > 0) then
          call RDscha ('InList_csv', InList_csv)
          
          swdiscrvert = 0
          if (rdinqr('swdiscrvert')) call rdsinr ('swdiscrvert',0,1,swdiscrvert)
          if (swdiscrvert == 1) then
            call rdsinr ('numnodNew',1,macp,numnodNew)
            call rdfdor ('dzNew',1.0d-6,5.0d2,dzNew,macp,numnodNew)
          end if
          
          tz_z1_z2(1:2) = 99.9d0
          if (RDinqr('tz_z1_z2')) call RDfdor('tz_z1_z2', -1.0d4, 0.0d0, tz_z1_z2, 2, 2)

          num_d = 5            
          if (rdinqr('num_decimals')) call rdsinr ('num_decimals',5,12,num_d) 
        end if
      end if

      swbal = 0; if (rdinqr('swbal')) call rdsinr ('swbal',0,1,swbal)
      swsba = 0; if (rdinqr('swsba')) call rdsinr ('swsba',0,1,swsba)
      !sw_end = 1; if (rdinqr('swend')) call rdsinr ('swend',0,2,sw_end)
      !sw_end_type = 1; (rdinqr('swendtype')) call rdsinr ('swendtype',0,2,sw_end_type)
      swblc = 0; if (RDinqr('swblc')) call rdsinr ('swblc',0,1,swblc)

!     type of weather data
      call rdsinr ('swetr',0,1,swetr)
      if (swetr == 0) then
        call rdsinr ('swmetdetail',0,1,swmetdetail)
      else
        swmetdetail = 0
      end if   

      ! force zero evaporation (hidden option)
      swevap = 1
      if (rdinqr('swevap')) call rdsinr ('swevap',0,1,swevap)
      
      ! detailed meteo input as option
      if (swmetdetail == 0) then
        call rdsinr ('swrain',0,3,swrain)
      else  
        call rdsinr ('nmetdetail',24,96,n_metdetail)
        swrain = 0
      end if

! --- fixed irrigation events
      call rdsinr ('swirfix',0,1,swirfix)
      if (swirfix == 1) call read_irrigation_fixed

! =================================================================
!     Section soil profile

! --- initial water conditions
      if (swinco == 1) then
         !call rdador ('zi',-1.d5,0.d0,zi,macp,ifnd)
         !call rdfdor ('h',-1.d10,1.d4,h,macp,ifnd)
         !nhead = ifnd
        
        
         ! old procedure (deprecated)
         if (rdinqr('h')) then
           
            message = 'Usage of ZI and H are deprecated, use HTB instead'
            call swap_warning('readswap', message)
          
            call rdinne ('H',nhead)
            allocate(z_ini(nhead)); allocate(h_ini(nhead))
            if (allocated(htb)) deallocate(htb); allocate(htb(nhead*2)); htb = 0.d0
         
            call rdfdor ('zi',-1.0d5,0.0d0,z_ini,nhead,nhead)
            call rdfdor ('h',-1.0d10,1.0d4,h_ini,nhead,nhead)
         
            do i = 1, nhead
               htb(i*2) = h_ini(i)
               htb(i*2-1) = dabs(z_ini(i))
            end do
            nhead = nhead*2
           
            deallocate(z_ini, h_ini)
         
         ! new procedure
         else
            
            if (.NOT. rdinqr('htb')) call swap_error ('readswap', 'Variable HTB not present in file '//trim(swpfilnam))
            call rdinne ('htb',nhead)
            if (allocated(htb)) deallocate(htb); allocate(htb(nhead)); htb = 0.d0
            call rdadortb('htb', -1.0d5, 0.d0, -1.d10, 1.d4, htb, nhead, .TRUE.)
         
         end if            
        
      else if (swinco == 2) then
         call rdsdor ('gwli',-10000.0d0,1000.0d0,gwli)
      end if

! --- ponding
      swpondmx = 0
      if (rdinqr('swpondmx')) then
        call rdsinr ('swpondmx',0,1,swpondmx)
        if (swpondmx == 1) then
          message = 'Simulation with time dependent ponding-threshold'
          call swap_warning ('readswap', message)
          call rdatim ('datepmx',datepmx,mairg,ifnd)
! -     at least one date must be within simulation period
          call checkdate(ifnd,datepmx,tend,tstart,'datepmx ', 'readswap/swpondmx=1')
          call rdfdor('pondmxtb',0.0d0,1000.d0,pondmxtb,mairg,ifnd)
          do i = 1, ifnd
            pondmxtab(i*2-1) = datepmx(i)
            pondmxtab(i*2)   = pondmxtb(i)
          end do
          pondmx = pondmxtb(1)
        end if
      end if
      if (sw_multi_swap == 0) then
      if (swpondmx == 0) then
        call rdsdor ('pondmx',0.0d0,1000.0d0,pondmx)
      end if

! --  drainage resistance of surface runoff
      call rdsdor ('rsro',0.001d0,1.0d0,rsro)
      call rdsdor ('rsroexp',0.01d0,10.0d0,rsroexp)
      end if
      
! --  check combination of time-dependent ponding and runoff-resistance
      if (swpondmx == 1 .AND. rsro < 1.0d-02) call swap_error ('readswap', 'Fatal error: time-dependent threshold for ponding (SWPONDMX=1) requires resistance (RSRO) > 0.01 d-1!')

! --- soil evaporation
      cfbs = 1.0d0
      call rdsinr ('swcfbs',0,1,swcfbs)
      if (swcfbs == 1) then
        call rdsdor ('cfbs',0.0d0,1.5d0,cfbs)
      end if
   
      swdivide = 0
      if (rdinqr('swdivide')) call rdsinr ('swdivide',0,1,swdivide)
      if (swdivide == 1) call rdsdor ('rsoil',0.0d0,1.0d3,rsoil)
   
      call rdsinr ('swredu',0,2,swredu)
      if (swredu == 1) then
        call rdsdor ('rsigni',0.0d0,1.0d0,rsigni)  
        if (rdinqr('cofredbl')) then
          call rdsdor ('cofredbl',0.0d0,1.0d0,cofred)
        else
          call rdsdor ('cofred',0.0d0,1.0d0,cofred)
        end if
      else if (swredu == 2) then
        if (rdinqr('cofredbo')) then
          call rdsdor ('cofredbo',0.0d0,1.0d0,cofred)
        else
          call rdsdor ('cofred',0.0d0,1.0d0,cofred)
        end if
      end if
      cfevappond = 1.25d0
      if (rdinqr('cfevappond')) then
        call rdsdor ('cfevappond',0.0d0,3.0d0,cfevappond)
      end if 

      iHWCKmodel(1:numlay) = 1    ! default MvG analytical functions
   if (sw_multi_swap == 0) then
! --- Soil Hydraulic relation: as MVG-functions or as Tables
      swsophy = 0
      iHWCKmodel(1:numlay) = 1    ! default MvG analytical functions
      if (rdinqr('iHWCKmodel')) then
         if (rdinar('iHWCKmodel')) then
            call rdfinr ('iHWCKmodel',1,12,iHWCKmodel,maho,numlay)
         else
            call rdsinr ('iHWCKmodel',1,12,iHWCKmodel(1))
            iHWCKmodel(2:numlay) = iHWCKmodel(1)
         end if
         ! 1 = uni-modal MvG (default)
         ! 2 = exponential wc(h) and K(h) relationships for testing
         ! 3 = bi-modal MvG relationships
         ! 4-11 = 8 versions of PDI model
         ! 12 = RIA model by Gerrit de Rooij
      end if
! -   Tables for each soil layer
      if (rdinqr('swsophy')) then
        call rdsinr ('swsophy',-1,1,swsophy)
        if (swsophy == 1) then
!         not allowed: table-option combined with output with adjusted vertical discrectization (swdiscrvert=1)
          if (swdiscrvert == 1) call swap_error ('readswap', 'combi of sophys-tables (swsophy=1) and swdiscrvert=1 not allowed')
          if (numlay > 1) then
            call rdacha ('filenamesophy',filenamesophy,maho,numlay)
          else
            call rdscha ('filenamesophy',filenamesophy(1))
          end if
          call swap_warning ('readswap', 'Simulation with tables for soil hydraulic relations')
        end if
      end if
   end if
   
! --- hysteresis
      call rdsinr ('swhyst',0,2,swhyst)
      if (swhyst > 0) then
        call rdsdor ('tau',0.0d0,1.0d0,tau)
        fhyst = 1.0d0
        if (swhyst == 1) then
           ! start on main wetting curve
           indeks = 1
        else 
           ! start on main drying curve
           indeks = -1
        end if
      end if

!     combination of soilphysical tables and hysteresis is not possible
      if (swhyst >= 1 .AND. swsophy /= 0) call swap_error ('readswap', 'Combination of hysteresis (swhyst=1) and tabulated soil physics (swsophy=1) is not possible !')
      
! --- MVG-functions: parameters of functions of each soil layer
      alfa_2(1:maho) = 0.0d0
      npar_2(1:maho) = 1.0d0
      omega_1(1:maho) = 1.0d0
      h0(1:maho) = 0.0d0
      ha(1:maho) = 0.0d0
      apar(1:maho) = 0.0d0
      omega_K(1:maho) = 0.1d0

      fl_use_tables = .FALSE.
      !sw_use_elas = 0
      fl_use_kh_power = .false.
   if (sw_multi_swap == 0) then
      if (swsophy == -1) then
         if (numlay > 1) then
            call RDfcha('tabnames', tabnames, maho, numlay)
         else
            call RDscha('tabnames', tabnames(1))
         end if
         ! to do: check extension?

         close (unit_swp)   ! we must temporarily close main input file, so that other files can be accessed by RDinit
         iunf = getun2 (iun_min2, iun_max2, 2)
         do lay = 1, numlay
             inquire(file = tabnames(lay), exist = file_exists)
             if (.NOT. file_exists) then
                message ='File '//trim(tabnames(lay))//' does not exists!'
                call swap_error ('readswap', message)
             end if            
             call RDinit(iunf, unit_err, tabnames(lay))
               call RDsdor('ores',      0.0d0,    1.0d0, ores(lay))
               call RDsdor('osat',      0.0d0,    1.0d0, osat(lay))
               call RDsdor('alfa',      1.d-4,    1.0d2, alfa(lay))
               call RDsdor('npar',      1.001d0,  9.0d0, npar(lay))
               call RDsdor('lexp',    -25.0d0,   50.0d0, lexp(lay))
               call RDsdor('ksatfit',   1.0d-5,   1.0d5, ksatfit(lay))
               if (swmacro == 0) then
                  call RDsdor('h_enpr', -40.d0, 0.0d0, h_enpr_global(lay))
               else
                  call RDsdor('h_enpr', -40.d0, -0.1d0, h_enpr_global(lay))
               end if
               if (lay == 1) then
                  call RDinne("i", n_entries)
                  if (allocated(ardummy))       deallocate(ardummy);       allocate(ardummy(n_entries))
                  if (allocated(wc_intercept))  deallocate(wc_intercept);  allocate(wc_intercept(n_entries, numlay))
                  if (allocated(wc_slope))      deallocate(wc_slope);      allocate(wc_slope(n_entries, numlay))
                  if (allocated(cap_intercept)) deallocate(cap_intercept); allocate(cap_intercept(n_entries, numlay))
                  if (allocated(cap_slope))     deallocate(cap_slope);     allocate(cap_slope(n_entries, numlay))
                  if (allocated(con_intercept)) deallocate(con_intercept); allocate(con_intercept(n_entries, numlay))
                  if (allocated(con_slope))     deallocate(con_slope);     allocate(con_slope(n_entries, numlay))
               end if
               call RDfdou('wc_intercept',  ardummy, n_entries, n_entries); wc_intercept(1:n_entries, lay)  = ardummy(1:n_entries)
               call RDfdou('wc_slope',      ardummy, n_entries, n_entries); wc_slope(1:n_entries, lay)      = ardummy(1:n_entries)
               call RDfdou('cap_intercept', ardummy, n_entries, n_entries); cap_intercept(1:n_entries, lay) = ardummy(1:n_entries)
               call RDfdou('cap_slope',     ardummy, n_entries, n_entries); cap_slope(1:n_entries, lay)     = ardummy(1:n_entries)
               call RDfdou('con_intercept', ardummy, n_entries, n_entries); con_intercept(1:n_entries, lay) = ardummy(1:n_entries)
               call RDfdou('con_slope',     ardummy, n_entries, n_entries); con_slope(1:n_entries, lay)     = ardummy(1:n_entries)
            close (iunf)
         end do
         if (allocated(ardummy)) deallocate(ardummy)
         call rdinit(unit_swp,unit_err,swpfilnam)     ! re-open main input file again

!        assign sophy-values to paramvg (input of cofgen)
         flksatexm = .FALSE.
         paramvg = 0.0d0
         do lay = 1,numlay
            paramvg(1,lay) = ores(lay)
            paramvg(2,lay) = osat(lay)
            paramvg(3,lay) = ksatfit(lay)
            paramvg(4,lay) = alfa(lay)
            paramvg(5,lay) = lexp(lay)
            paramvg(6,lay) = npar(lay)
            paramvg(7,lay) = 1.d0 - (1.d0 / paramvg(6,lay))
            if (swhyst == 0) then
              paramvg(8,lay) = alfa(lay)
            else
              paramvg(8,lay) = alfaw(lay)
            end if
            paramvg(9,lay) = h_enpr_global(lay)
            paramvg(10,lay) = -999.d0     ! Ksatexm
            paramvg(11,lay) = 0.d0        ! relsatthr
            paramvg(12,lay) = 0.d0        ! ksatthr
            if (flksatexm) then
               if (ksatexm(lay) > ksatfit(lay)) then                          !## MH: 20180111 - only effectively use Ksatexm in case Ksatexm > Ksatfit
                  paramvg(10,lay) = ksatexm(lay)
                  help = abs(hthr * paramvg(4,lay))**paramvg(6,lay)
                  help = (1.0d0 + help) ** paramvg(7,lay)
                  relsatthr = 1.0d0/help
                  term1     = ( 1.0d0-relsatthr**(1.0d0/paramvg(7,lay)) )**paramvg(7,lay)
                  ksatthr   = paramvg(3,lay)*(relsatthr**paramvg(5,lay)) * (1.0d0-term1)*(1.0d0-term1)
                  if (ksatthr >= ksatexm(lay)) then
                     write(message,'(a,i2)') 'ksatexm < ksatthr for layer ',lay
                     call swap_error ('readswap', message)
                  end if
                  paramvg(11,lay) = relsatthr
                  paramvg(12,lay) = ksatthr
               end if
            end if
            paramvg(13,lay) = alfa_2(lay)
            paramvg(14,lay) = npar_2(lay)
            paramvg(15,lay) = 1.d0 - 1.d0 / npar_2(lay)
            paramvg(16,lay) = omega_1(lay)
            paramvg(17,lay) = 1.0d0 - omega_1(lay)
            paramvg(18,lay) = h0(lay)
            paramvg(19,lay) = ha(lay)
            paramvg(20,lay) = apar(lay)
            paramvg(21,lay) = omega_K(lay)
         end do
         swsophy = 0
         fl_use_tables = .TRUE.

         
      else if (swsophy == 0) then
!##: MH start
         if (rdinqr('SWAP_SOILS_DB')) then
            call rdscha ('SWAP_SOILS_DB', SWAP_SOILS_DB)          ! name of the soils database
            call rdfcha ('SoilNames', SoilNames, maho, numlay)    ! names of the soils per layer

            close (unit_swp)   ! we must close main input file, so that soils database can be accessed by rdinit
            
            idb = getun2 (iun_min2, iun_max2, 2)
            flksatexm  =.FALSE.
            inquire(file = SWAP_SOILS_DB, exist = file_exists)
            if (.NOT. file_exists) then
               message ='File '//trim(SWAP_SOILS_DB)//' does not exists!'
               call swap_error ('readswap', message)
            end if            
            call rdinit (idb, unit_err, SWAP_SOILS_DB)
!              store all data in database
               call gtsoil (1,idb,SWAP_SOILS_DB,cdum,dum1,dum2,dum3,dum4,dum5,dum6,dum7,dum8,dum9,flksatexm) ! initialize; most arguments are dummy
               do i = 1, numlay
!                 get values per soil layer
                  call gtsoil (2,idb,SWAP_SOILS_DB,SoilNames(i),Ores(i),Osat(i),Npar(i),Alfa(i),AlfaW(i),   &
                               Lexp(i),Ksatfit(i),KsatExm(i),h_enpr_global(i),flksatexm)
               end do
            close (idb)

            call rdinit(unit_swp,unit_err,swpfilnam)     ! open main input file again
!## MH: end

         else
            if (maxval(iHWCKmodel(1:numlay)) == 12) then
               ! use MOD_RIA
               if (swhyst > 0) call swap_error('readswap', 'Combination of MOD_RIA and hysteresis (SWHYST = 1) is not possible.')
               call RIA_Reader()
               call swap_warning ('readswap', 'Using RIA model (by Gerrit de Rooij) for soil physical properties')
            else
               call rdfdor ('osat',0.d0,1.0d0,osat,maho,numlay)
               call rdfdor ('ores',0.d0,1.0d0,ores,maho,numlay)
               call rdfdor ('alfa',1.d-4,100.d0,alfa,maho,numlay)
               if (swhyst > 0) then
                 call rdfdor ('alfaw',1.d-4,100.d0,alfaw,maho,numlay)
               end if
               call rdfdor ('npar',1.001d0,9.d0,npar,maho,numlay)
               call rdfdor ('lexp',-25.d0,50d0,lexp,maho,numlay)
               if (swmacro == 0) then
                  call rdfdor ('h_enpr',-40.d0,0.d0,h_enpr_global,maho,numlay)
               else
                  call rdfdor ('h_enpr',-40.d0,-0.1d0,h_enpr_global,maho,numlay)
               end if
   !           to allow downward compatibility from Swap3.2.23
               if (rdinqr('ksatfit')) then
                    call rdfdor ('ksatfit',1.d-5,1.d5,ksatfit,maho,numlay)
               else
                    call rdfdor ('ksat',1.d-5,1.d5,ksatfit,maho,numlay)
               end if
               flksatexm  =.FALSE.
               if (rdinqr('ksatexm')) then
                    call rdfdor ('ksatexm',1.d-5,1.d5,ksatexm,maho,numlay)
                    flksatexm  =.TRUE.
               end if
               elas = 1.0d-8
               if(rdinqr('elas')) then
                  call rdfdor ('elas',0.0d0,1.d-4,elas,maho,numlay)
                  sw_use_elas = 1
                  if (minval(elas) < 1.0d-12) sw_use_elas = 0
               else
                  sw_use_elas = 0
               end if
   !            if (iHWCKmodel == 3) then
               if (any(iHWCKmodel(1:numlay) ==  3) .OR. any(iHWCKmodel(1:numlay) ==  6) .OR. &
                   any(iHWCKmodel(1:numlay) ==  7) .OR. any(iHWCKmodel(1:numlay) == 10) .OR. &
                   any(iHWCKmodel(1:numlay) == 11)) then
                  call rdfdor ('alfa_2',1.d-4,100.d0,alfa_2,maho,numlay)
                  call rdfdor ('npar_2',1.001d0,9.d0,npar_2,maho,numlay)
                  call rdfdor ('omega_1',1.0d-4,0.9999d0,omega_1,maho,numlay)
               end if
               if (any(iHWCKmodel(1:numlay) == 5) .OR. any(iHWCKmodel(1:numlay) == 7)) then
                  call rdfdor ('h0',-5.0d7,-1.0d5,h0,maho,numlay); h0(1:numlay) = -h0(1:numlay)
               end if
               if (any(iHWCKmodel(1:numlay) ==  8) .OR. any(iHWCKmodel(1:numlay) ==  9) .OR. &
                   any(iHWCKmodel(1:numlay) == 10) .OR. any(iHWCKmodel(1:numlay) == 11)) then
                  call rdfdor ('h0',-5.0d7,-1.0d5,h0,maho,numlay); h0(1:numlay) = -h0(1:numlay)
                  call rdfdor ('ha',-1.0d5,0.0d0,ha,maho,numlay);  ha(1:numlay) = -ha(1:numlay)
                  do lay = 1, numlay
                     if (iHWCKmodel(lay) >= 8 .AND. iHWCKmodel(lay) <= 11) then
                        if (ha(lay) <= 0.0d0 .OR. ha(lay) >= h0(lay)) then
                           call swap_error ('readswap', 'PDI requires 0 < abs(HA) < abs(H0) for every PDI soil layer')
                        end if
                     end if
                  end do
                  call rdfdor ('apar',-5.0d0,0.0d0,apar,maho,numlay)
                  call rdfdor ('omega_K',1.0d-8,0.1d0,omega_K,maho,numlay)
                  call rdfinr ('swvapor',0,1,swvapor,maho,numlay)
               end if

               fl_use_kh_power = RDinqr('h_power')
               if (fl_use_kh_power) then
                  call rdfdor ('h_power', -1.d10, -50.0d0,  h_power, maho, numlay)
               else
                  h_power = 0.0d0
               end if
            end if
         end if      ! if (RDinqr('SWAP_SOILS_DB')) then

         if (flksatexm) then
            message = 'Simulation with additonal Ksat value (Ksatexm)'
            call swap_warning ('readswap', message)
         end if
         
         if (maxval(iHWCKmodel(1:numlay)) == 12) then
            ! set some van Gencuhten parameters erqual to MOD_RIA equivalents (for safety)
            ores(1:numlay)          = 0.0d0
            osat(1:numlay)          = dble(SWRCpars(1:numlay, 1))
            h_enpr_global(1:numlay) = dble(SWRCpars(1:numlay, 2))
            alfa(1:numlay)          = dble(SWRCpars(1:numlay, 4))
            npar(1:numlay)          = dble(SWRCpars(1:numlay, 5))
            ksatfit(1:numlay)       = dble(UHCCpars(1:numlay, 1))
            lexp(1:numlay)          = dble(UHCCpars(1:numlay, 6))
         end if
   
!        assign sophy-values to paramvg (input of cofgen)
         if (fl_use_kh_power) then
            do lay = 1, numlay
               if (h_power(lay) > h_enpr_global(lay)) call swap_error('readswap', 'h_power should be < h_enpr_global')
               m = 1.0d0 - 1.0d0/npar(lay)
               if (h_enpr_global(lay) < 0.0d0) then
                  sc           = (1.0d0 + dabs(alfa(lay) * h_enpr_global(lay))**npar(lay))**(-m) 
                  se           = ((1.0d0 + dabs(alfa(lay) * h_power(lay))**npar(lay))**(-m) ) / sc
                  term1        = (1.0d0 - (se * sc)**(1.0d0/m))**m
                  term2        = (1.0d0 - (sc)**(1.0d0/m))**m
                  k_power(lay) = ksatfit(lay) * se**lexp(lay) * ((1.0d0 - term1) / (1.0d0 - term2))**2
               else
                  se           = ((1.0d0 + dabs(alfa(lay) * h_power(lay))**npar(lay))**(-m))
                  term1        = (1.0d0 - se**(1.0d0/m))**m
                  k_power(lay) = ksatfit(lay) * se**lexp(lay) * (1.0d0 - term1)**2
               end if
            end do
         else
            k_power = 0.0d0
         end if

         paramvg = 0.0d0
         do lay = 1,numlay
            paramvg(1,lay) = ores(lay)
            paramvg(2,lay) = osat(lay)
            paramvg(3,lay) = ksatfit(lay)
            paramvg(4,lay) = alfa(lay)
            paramvg(5,lay) = lexp(lay)
            paramvg(6,lay) = npar(lay)
            paramvg(7,lay) = 1.d0 - (1.d0 / paramvg(6,lay))
            if (swhyst == 0) then
              paramvg(8,lay) = alfa(lay)
            else
              paramvg(8,lay) = alfaw(lay)
            end if
            paramvg(9,lay) = h_enpr_global(lay)
            paramvg(10,lay) = -999.d0     ! Ksatexm
            paramvg(11,lay) = 0.d0        ! relsatthr
            paramvg(12,lay) = 0.d0        ! ksatthr
            if (flksatexm) then
               if (ksatexm(lay) > ksatfit(lay)) then                          !## MH: 20180111 - only effectively use Ksatexm in case Ksatem > Ksatfit
                  paramvg(10,lay) = ksatexm(lay)
                  help = abs(hthr * paramvg(4,lay))**paramvg(6,lay)
                  help = (1.0d0 + help) ** paramvg(7,lay)
                  relsatthr = 1.0d0/help
                  term1     = ( 1.0d0-relsatthr**(1.0d0/paramvg(7,lay)) )**paramvg(7,lay)
                  ksatthr   = paramvg(3,lay)*(relsatthr**paramvg(5,lay)) * (1.0d0-term1)*(1.0d0-term1)
                  if (ksatthr >= ksatexm(lay)) then
                     write(message,'(a,i2)') 'ksatexm < ksatthr for layer ',lay
                     call swap_error ('readswap', message)
                  end if
                  paramvg(11,lay) = relsatthr
                  paramvg(12,lay) = ksatthr
               end if
            end if
            paramvg(13,lay) = alfa_2(lay)
            paramvg(14,lay) = npar_2(lay)
            paramvg(15,lay) = 1.d0 - 1.d0 / npar_2(lay)
            paramvg(16,lay) = omega_1(lay)
            paramvg(17,lay) = 1.0d0 - omega_1(lay)
            paramvg(18,lay) = h0(lay)
            paramvg(19,lay) = ha(lay)
            paramvg(20,lay) = apar(lay)
            paramvg(21,lay) = omega_K(lay)
            paramvg(22,lay) = h_power(lay)
            paramvg(23,lay) = k_power(lay)
            paramvg(24,lay) = elas(lay)
         end do
      end if
   end if ! sw_multi_swap == 0

!     determine/set BiModal and NoVap
      do i = 1, numlay
         BiModal(i) = .FALSE.
         if (iHWCKmodel(i) ==  3 .OR. iHWCKmodel(i) ==  6 .OR. iHWCKmodel(i) ==  7 .OR.   &
             iHWCKmodel(i) == 10 .OR. iHWCKmodel(i) == 11 ) BiModal(i) = .TRUE.
         NoVap(i) = .TRUE.
         if (iHWCKmodel(i) ==  8 .OR. iHWCKmodel(i) ==  9 .OR. iHWCKmodel(i) == 10 .OR. iHWCKmodel(i) == 11 ) then
            if (swvapor(i) == 0) then
               NoVap(i) = .TRUE.
            else
               NoVap(i) = .FALSE.
            end if
         end if
      end do
      
      ! soil nitrogen module
      if (swcropsnm /= 0) call rdscha ('snmfil',snmfil)
      
! -   preferential flow due to macropores
      call rdsinr ('swmacro',0,1,swmacro)
      if (swmacro == 1) call read_macropore()

! -   snow and frost conditions 
      call rdsinr ('swsnow',0,1,swsnow)
      if (swsnow == 1) then
        call rdsdor ('snowinco',0.0d0,1000.0d0,snowinco)
        call rdsdor ('teprrain',0.0d0,10.0d0,teprrain)
        call rdsdor ('teprsnow',-10.0d0,0.0d0,teprsnow)
        call rdsdor ('snowcoef',0.0d0,10.0d0,snowcoef)
        swsublim = 0
        if (rdinqr('swsublim')) then
          call rdsinr ('swsublim',0,1,swsublim)
        end if
      end if
      call rdsinr ('swfrost',0,1,swfrost)
      if (swfrost == 1) then
        call rdsdor ('tfroststa',-10.0d0,5.0d0,tfroststa)
        call rdsdor ('tfrostend',-10.0d0,5.0d0,tfrostend)
      end if
!     combination of frost and macropore-flow is not possible (yet)
      if (swfrost == 1 .AND. swmacro == 1) call swap_error ('readswap', 'Combination of frost (SWFROST=1) and macropore-flow (SWMACRO=1) is not operational !')

!     combination of snow and Et variation during the day
      if (swmetdetail == 1 .AND. swsnow == 1) then
        message = 'In case of snow the sublimation is not simulated correctly if short time meteorological records are used (SWMETDETAIL=1 and SWSNOW=1), please adapt input !'
        call swap_warning ('readswap', message)
      end if

! --- parameters numerical scheme
      call rdsdor ('dtmin', 1.0d-7,0.1d0,dtmin)
      call rdsdor ('dtmax', dtmin, 1.0d0,dtmax)
      call rdsdor ('gwlconv',1.0d-5,1000.0d0,gwlconv)
      call rdsdor ('CritDevPondDt',1.0d-6,1.0d-01,CritDevPondDt)
!     Convergence criteria (optional input)
      CritDevh1Cp   = 1.0d-2; if (rdinqr('CritDevh1Cp')) call rdsdor ('CritDevh1Cp',1.0d-10,1.0d3,CritDevh1Cp)
      CritDevh2Cp   = 1.0d-1; if (rdinqr('CritDevh2Cp')) call rdsdor ('CritDevh2Cp',1.0d-10,1.0d3,CritDevh2Cp)
      CritDevBalCp  = 1.0d-6; if (rdinqr('CritDevBalCp')) call rdsdor ('CritDevBalCp',1.0d-8,1.0d-3,CritDevBalCp)
      CritDevBalTot = 1.0d-5; if (rdinqr('CritDevBalTot')) call rdsdor ('CritDevBalTot',1.0d-7,1.0d-2,CritDevBalTot)
!     Maximum number of iterations [5,100]
      call rdsinr ('MaxIt',5,100,MaxIt)
!     Maximum number of back track cycles within an iteration cycle [1,10]
      call rdsinr ('MaxBackTr',1,10,MaxBackTr)
      numbit_crit      = 3;     if (rdinqr('numbit_crit'))      call rdsinr('numbit_crit',3,maxit,numbit_crit)
      fact_dt_increase = 2.0d0; if (rdinqr('fact_dt_increase')) call rdsdor('fact_dt_increase',1.1d0,10.0d0,fact_dt_increase)
      fact_dt_decrease = 0.5d0; if (rdinqr('fact_dt_decrease')) call rdsdor('fact_dt_decrease',1.0d-3,0.99d0,fact_dt_decrease)
      fact_dt_fldect   = 3.0d0; if (rdinqr('fact_dt_fldect'))   call rdsdor('fact_dt_fldect',2.0d0, 10.0d0,fact_dt_fldect)
!     Maximum number of iterations: no input
      msteps = 100000000
!     Switch for mean of hydraulic conductivity 
!        SwkMean=1,2:unweighted arithmic mean,weighted arithmic mean
!        SwkMean=3,4:unweighted geometric mean, weighted geometric mean
!        SwkMean=5,6:unweighted harmonic mean, weighted harmonic mean
      call rdsinr ('SWkmean',1,7,SWkmean)
      if (swkmean == 7) call sub_Kavg_Szym(1, 0, 0.0d0, 0.0d0, dum)      
!     Switch for implicit solution with hydraulic conductivity: 0 = explicit, 1 = implicit
      call rdsinr ('SwkImpl',0,1,SwkImpl)
      if (swkmean == 7 .AND. swkimpl == 1) call swap_error('readwsap', 'not allowed: swkmean = 7 .AND. swkimpl = 1')      
!     Maximum cputime, introduced to be able to interrupt (near) endless iterations
      flMaxIterTime = .FALSE.
      if (rdinqr('flMaxIterTime')) then
        call rdslog ('flMaxIterTime',flMaxIterTime)
        MaxIterTime = 2419200                ! 4 weeks = 60*60*24*7*4=2419200 secs)
        if (flMaxIterTime) then
          call rdsinr ('MaxIterTime',1,2419200,MaxIterTime)
        end if
      end if

! =================================================================
!     Lateral drainage section
!     extended or basic drainage
      call rdsinr ('swdra',0,2,swdra)
      if (swdra /= 0) call rdscha ('drfil',drfil)
      if (SwDrRap == 1 .AND. SwDra == 0) call swap_error ('readswap', ' There are no drainage levels, so rapid drainage is not possible!')

!     runon from external source (field)
      call rdsinr ('swrunon',0,1,swrunon)

! =================================================================
!     Bottom boundary section

! --- Initialise
      do i = 1,2*mabbc
        gwltab(i) = 0.0D0
        hbotab(i) = 0.0D0
        qbotab(i) = 0.0D0
        haqtab(i) = 0.0D0
      end do

! --- option for input of bottom boundary condition
      call rdsinr ('swbbcfile',0,1,swbbcfile)
      if (swbbcfile == 1) call rdscha ('bbcfil',bbcfil)

! -   fatal error when frost or snow is simulated without heat flow
      if ((swfrost == 1 .OR. swsnow == 1) .AND. swhea == 0) call swap_error ('readswap', 'In case of snow or frost the soil heat flow should be simulated! Adapt .swp input file.')

! =================================================================
!     Section bottom boundary condition

      if (swbbcfile == 1) then
        close (unit_swp)
        filnam = trim(pathwork)//trim(bbcfil)//'.bbc'
        inquire(file = filnam, exist = file_exists)
        if (.NOT. file_exists) then
           message ='File '//trim(filnam)//' does not exists!'
           call swap_error ('readswap', message)
        end if        
        unit_bbc = getun2 (iun_min2, iun_max2, 2)
        call rdinit(unit_bbc,unit_err,filnam)
      end if

! --- option for bottom boundary condition
      call rdsinr ('swbotb',1,9,swbotb)

! --- given groundwaterlevel
      if (swbotb == 1) then
        call rdatim ('date1',dates,mabbc,ifnd)
        call rdfdor ('gwlevel',-10000.0d0,1000.d0,gwlevel,mabbc,ifnd)

        ! check: at least one date must be within simulation period
        call checkdate(ifnd,dates,tend,tstart,'date1 ','readswap//swbotb=1      ')

        ! check if gwlevel is too high
        flsat = .FALSE.
        do i = 1,ifnd
          if (gwlevel(i) > zbotcp(5))  flsat = .TRUE.
        end do
        if (flsat) then
           message = 'Prescribed groundwater level (SWBOTB=1) is too close to the soil surface, at least 5 compartments (NCOMP) should remain unsaturated. Suggestion: use SWBOTB=5'
           call swap_error ('readswap', message)
        end if

! -     store values in gwltab
        do i = 1,ifnd
          gwltab(i*2) = gwlevel(i) 
          gwltab(i*2-1) = dates(i)
        end do
      end if

! --- regional bottom flux is given                             
      if (swbotb == 2) then
        call rdsinr ('sw2',1,2,sw2)
        if (sw2 == 1) then
          call rdsdor ('sinave',-10.0d0,10.0d0,sinave)
          call rdsdor ('sinamp',-10.0d0,10.0d0,sinamp)
          call rdsdor ('sinmax',0.d0,366.d0,sinmax)
        else
! -       read tabular data
          call rdatim ('date2',dates,mabbc,ifnd)
          call rdfdor ('qbot2',-100.0d0,100.0d0,qboti,mabbc,ifnd)
! -     at least one date must be within simulation period
          call checkdate(ifnd,dates,tend,tstart,'date2 ','readswap//swbotb=2      ')
! -       fill qbotab table
          do i = 1,ifnd
            qbotab(i*2) = qboti(i) 
            qbotab(i*2-1) = dates(i)
          end do
        end if
      end if

! --- calculated flux through the bottom of the profile
      if (swbotb == 3) then

!       Switch for implicit solution with lower boundary option 3 (Cauchy): 0 = explicit, 1 = implicit
        call rdsinr ('swbotb3Impl',0,1,swbotb3Impl)

        call rdsdor ('shape_3',0.0d0,1.0d0,shape_3)
        if (swbotb3Impl == 1 .AND. abs(shape_3-1.0d0) > 1.0d-7) then
          message = 'Possible lower boundary inconsistency using SwBotb=3: Combination of swbotb3Impl AND shape_3 not equal 1.0. This is not recommended. Suggestion is: swbotb3Impl=0'
          call swap_warning ('readswap', message)
        end if

        call rdsdor ('hdrain',-1.0d4,0.0d0,hdrain)
        call rdsdor ('rimlay',0.0d0,1.0d5,rimlay)

!       Switch to suppress addition of vertical resistance 
!                      between bottom of model and groundwater level
        call rdsinr ('SwBotb3ResVert ',0,1,SwBotb3ResVert)

        call rdsinr ('sw3',1,2,sw3)
        if (sw3 == 1) then
          call rdsdor ('aqave',-10000.0d0,1000.0d0,aqave)
          call rdsdor ('aqamp',0.0d0,1000.0d0, aqamp)
          call rdsdor ('aqtmax',0.0d0,366.d0,aqtmax)
          call rdsdor ('aqper',0.0d0,366.0d0,aqper)
        else
! -       read tabular data
          call rdatim ('date3',dates,mabbc,ifnd)
          call rdfdor ('haquif',-10000.0d0,1000.d0,haquif,mabbc,ifnd)
! -     at least one date must be within simulation period
          call checkdate(ifnd,dates,tend,tstart,'date3 ','readswap//swbotb=3      ')
! -       fill haqtab table
          do i = 1,ifnd
            haqtab(i*2) = haquif (i) 
            haqtab(i*2-1) = dates(i)
          end do
        end if
        call rdsinr ('sw4',0,1,sw4)
        if (sw4 == 1) then
          if (swbotb3Impl == 1) call swap_warning ('readswap', 'Implicit solution of Cauchy, combined with fluxes is active !(swbotb3Impl=1 AND sw4=1)')
! -       read tabular data
          call rdatim ('date4',dates,mabbc,ifnd)
          call rdfdor ('qbot4',-100.0d0,100.d0,qboti,mabbc,ifnd)
! -     at least one date must be within simulation period
          call checkdate(ifnd,dates,tend,tstart,'date4 ','readswap//swbotb=3/sw4=1')
! -       fill qbotab table
          do i = 1,ifnd
            qbotab(i*2) = qboti(i) 
            qbotab(i*2-1) = dates(i)
          end do
        end if
      end if

! --- flux-groundwater level relationship 
      if (swbotb == 4) then
        call rdsinr ('swqhbot',1,2,swqhbot)
        if (swqhbot == 1) then
          call rdsdor ('cofqha',-100.0d0,100.0d0,cofqha)
          call rdsdor ('cofqhb',-1.0d0,1.0d0,cofqhb)
          swcofqhc = 0
          cofqhc = 0.0d0
          if (rdinqr('cofqhc')) then
            swcofqhc = 1
            call rdsdor ('cofqhc',-10.0d0,10.0d0,cofqhc)
          end if
        else if (swqhbot == 2) then
          call rdador ('qtab',-100.0d0,100.d0,qhtab,mabbc,ifnd)
          call rdfdor ('htab', -1.0d4, 0.0d0, hhtab,mabbc,ifnd)
          do i = 1,ifnd
            qbotab(i*2) = qhtab(i) 
            qbotab(i*2-1) = abs(hhtab(i))
          end do
        end if
      end if

! --- pressure head of lowest compartment is given 
      if (swbotb == 5) then
        call rdatim ('date5',dates,mabbc,ifnd)
        call rdfdor('hbot5',-1.0d10,1000.d0,hbottom,mabbc,ifnd)
! -     at least one date must be within simulation period
        call checkdate(ifnd,dates,tend,tstart,'date5 ','readswap//swbotb=5      ')
! -     store pressure head values in hbotab
        do i = 1, ifnd
          hbotab(i*2) = hbottom(i) 
          hbotab(i*2-1) = dates(i)
        end do
      end if

! --- free outflow (lysimeter, suction candle possible) 
      if (swbotb == 8) then
        if (rdinqr('hplate')) then
          call rdsdor('hplate',-1000.d0,0.0d0,hplate)
        else
          hplate = 0.0d0
        end if     
      end if

      ! simultaneously: fixed h and fixed q at bottom
      if (swbotb == 9) then
         call rdatim ('date9a',dates,mabbc,ifnd)
         call rdfdor('hbot9',-1.0d10,1000.d0,hbottom,mabbc,ifnd)
! -      at least one date must be within simulation period
         call checkdate(ifnd,dates,tend,tstart,'date9a','readswap//swbotb=9      ')
! -      store pressure head values in hbotab
         do i = 1, ifnd
            hbotab(i*2)   = hbottom(i) 
            hbotab(i*2-1) = dates(i)
         end do
         call rdatim ('date9b',dates,mabbc,ifnd)
         call rdfdor('qbot9',-100.0d0,100.d0,hbottom,mabbc,ifnd)
! -      at least one date must be within simulation period
         call checkdate(ifnd,dates,tend,tstart,'date9b','readswap//swbotb=9      ')
! -      store flux values in qbotab
         do i = 1, ifnd
            qbotab(i*2)   = hbottom(i) 
            qbotab(i*2-1) = dates(i)
         end do
      end if

      if (swbbcfile == 0) then
        close (unit_swp)
      else if (swbbcfile == 1) then
        close (unit_bbc)
      end if
      
         
      ! default ETref settings
      albedo = 0.23d0
      rsc = 70.0d0
      rsw = 0.0d0
      
      ! crop rotation
      if (swcrop == 1) call croprotation(1)
     

! -   Tables for each soil layer
      if (swsophy == 1) then
         
         ! allocate memory
         if (.not. allocated(numtablay))    allocate(numtablay(maho));                   numtablay = 0
         if (.not. allocated(numtab))       allocate(numtab(macp));                      numtab    = 0
         if (.not. allocated(ientrytablay)) allocate(ientrytablay(maho,0:matabentries)); ientrytablay = 0
         if (.not. allocated(ientrytab))    allocate(ientrytab(macp,0:matabentries));    ientrytab    = 0
         if (.not. allocated(sptablay))     allocate(sptablay(7,maho,matab));            sptablay = 0
         if (.not. allocated(sptab))        allocate(sptab(7,macp,matab));               sptab    = 0
         
          ientrytablay = 0
          do lay = 1,numlay
            filnam = filenamesophy(lay)
            inquire(file = filnam, exist = file_exists)
            if (.NOT. file_exists) then
               message ='File '//trim(filnam)//' does not exist!'
               call swap_error ('readswap', message)
            end if        
            unit_sol = getun2 (iun_min2, iun_max2, 2)
            call rdinit(unit_sol,unit_err,filnam)
            call rdador ('headtab',-1.0d15,1.0d15,headtab,matab,ifnd)
            call rdfdor ('thetatab',0.0d0,1.0d0,thetatab,matab,ifnd)
            call rdfdor ('conductab',0.0d0,10000.0d0,conductab,matab,ifnd)
            close (unit_sol)
            numtablay(lay) = ifnd

            ! verify incremental sequence of values
            do i = 2,numtablay(lay)
               if ((headtab(i)-headtab(i-1)) <= nihil) then
                  message = 'No incremental values for head soil physic in input file '//trim(filnam)
                  call swap_error ('readswap', message)
               end if
               if ((thetatab(i)-thetatab(i-1)) <= vsmall) then
                  message = 'No incremental values for theta soil physic in input file '//trim(filnam)
                  call swap_error ('readswap', message)
               end if
               if ((conductab(i)-conductab(i-1)) <= nihil**2) then
                  message = 'No incremental values for conduc soil physic in input file '//trim(filnam)
                  call swap_error ('readswap', message)
               end if
            end do

!           preprocess table
!---- sorting of arrays to an ascending sequence

!## MH start
            ! ln-transformation of h and K if global flag do_ln_trans = true
            ! works only if all headtab values are < 0
            if (do_ln_trans) then
               do i = 1, numtablay(lay)
                  headtab(i)   = -dlog(-headtab(i)+1.0d0)     ! minus, so that table remains in stricly increasing order
                  conductab(i) =  dlog(conductab(i))
               end do
            end if
!## MH end

            Do i=1,numtablay(lay)-1
               Do j=i+1,numtablay(lay)
                  if (headtab(i) > headtab(j)) then
                     Dum          = headtab(j)
                     headtab(j)   = headtab(i)
                     headtab(i)   = Dum
                     Dum          = thetatab(j)
                     thetatab(j)  = thetatab(i)
                     thetatab(i)  = Dum
                     Dum          = conductab(j)
                     conductab(j) = conductab(i)
                     conductab(i) = Dum
                  End If
               End Do
            End Do
            ientrytablay(lay,0)=numtablay(lay)
            do i = 1,numtablay(lay)

!## MH start
              !if (headtab(i) > -1.0d-1) then
              !   j=0
              !else
              !   j = int(1000*(log10(-headtab(i))+1.d0))+1
              !end if
              if (do_ln_trans) then
                  dummy = -(dexp(-headtab(i))-1.0d0)
              else
                  dummy = headtab(i)
              end if
              if (dummy > -1.0d-5) then
                 j=0
              else
                 j = int(1000*(log10(-dummy)+1.d0))+4001    ! +4001 to ensure proper functioning for near-zero entries of pressure head (say -1.0d-5 and lower)
              end if
!## MH end

              ientrytablay(lay,j) = i
              sptablay(1,lay,i) = headtab(i)
              sptablay(2,lay,i) = thetatab(i)
              sptablay(3,lay,i) = conductab(i)
            end do
            ientrytablay(lay,1) = 0
            do j=matabentries-1,1,-1
               if (ientrytablay(lay,j) == 0) ientrytablay(lay,j) = ientrytablay(lay,j+1)
!## MH: additional check should be: all integers between 0 and n-1 should be included in table ientrytablay for best performance ???
            end do
            call PreProcTabulatedFunction(1,numtablay(lay),headtab,thetatab,dydx,sigma)
            do i = 1,numtablay(lay)
              sptablay(4,lay,i) = dydx(i)
              sptablay(6,lay,i) = sigma(i)   !## MH: new
            end do
            call PreProcTabulatedFunction(2, numtablay(lay),headtab,conductab,dydx,sigma)
            do i = 1,numtablay(lay)
              sptablay(5,lay,i) = dydx(i)
              sptablay(7,lay,i) = sigma(i)   !## MH: new
            end do

            ! tables must have values for a head=0
            if (sptablay(1,lay,numtablay(lay)) < -1.d-20) then
               message = 'No values for head=0 in tabulated soil physic in input file '//trim(filnam)
               call swap_error ('readswap', message)
            end if
          end do
      end if

! =================================================================
!     Read data of drainage input file
!      if (swdra == 1) call rddrb ()

! =================================================================
! --- read data from file with results from previous simulation
! --- set initial ponding conditions
      
      if (fl_initialize) then
        
        call inoutend (1)
         
        ! macropore variables
        if (swmacro == 1) call swap_warning ('readswap', 'I/O of macropore variables from file (SWINCO=3) not implemented yet!')

      end if

! --- runon from external file
      if (swrunon == 1) then
         
        call read_runon()
         
      end if

!     final checks (typically for bi-modal situation
      if (any(iHWCKmodel(1:numlay) > 1)) then
         if (swhyst >= 1)                   call swap_error ('readswap', 'Combination of hysteresis (swhyst=1 or 2) and iHWCKmodel > 1 is not possible!')
         if (swsophy == 1)                  call swap_error ('readswap', 'Combination of tabulated input (swsophy=1) and iHWCKmodel > 1 is impossible!')
         if (swdiscrvert == 1)              call swap_error ('readswap', 'Combination of output coarse discretization (swdiscrvert=1) and iHWCKmodel > 1 is not (yet) possible!')
         if (swmacro == 1)                  call swap_error ('readswap', 'Combination of macro-pore option (swmacro == 1) and iHWCKmodel > 1 is impossible!')
         if (minval(h_enpr_global) < 0.0d0) call swap_warning ('readswap', 'User-input of h_enpr_global < 0 not used in combination with iHWCKmodel > 1.')
      end if

      return
      end subroutine readswap

! ----------------------------------------------------------------------
      subroutine checkdate(ifnd,dates,tend,tstart,namedat,topic) 
! ----------------------------------------------------------------------
!     Date               : April 2006   
!     Purpose            : check range of input dates to range of simulation period
! ----------------------------------------------------------------------
      implicit none

! --- global
      integer, intent(in)           :: ifnd
      real(8), intent(in)           :: dates(ifnd), tend, tstart
      character(len=5), intent(in)  :: namedat
      character(len=*), intent(in)  :: topic
      character(len=200) message

! ----------------------------------------------------------------------
! --- local
      integer i
      logical fldaterr

! ----------------------------------------------------------------------

!   - at least one input date must be within simulation period or 
!     simulation period should be completely within range of input dates
      fldaterr = .TRUE.
      i = 1
      do while (fldaterr .AND. i <= ifnd)
         if (dates(i) > tstart-1.d-6 .AND. dates(i) < tend+1.d-6) fldaterr=.FALSE.
         i = i + 1
      end do
      if (fldaterr) then
         if (dates(1) < tstart+1.d-6 .AND. dates(ifnd) > tend-1.d-6) fldaterr=.FALSE.
      end if
      if (fldaterr) then
        message = 'Fatal '//namedat//', no input date within simulation period'
        call swap_error(topic, message)
      end if

      return
      end subroutine checkdate

   subroutine gtsoil (itask,iunit,filnam,sname,wcr,wcs,nd,alpha,alphaw,l,ks,ksat,he,flksatexm)

      ! Version taken from FUSSIM, and adapted for use in SWAP
      ! December 2017, Marius Heinen
      !
      !-----------------------------------------------------------------------*
      ! Subroutine GTSOIL                                                     *
      !                                                                       *
      ! Author  : Marius Heinen, Kees Rappoldt AB-DLO, Haren                  *
      ! Date    : July 1995                                                   *
      ! Purpose : Get parameters of the Van Genuchten-Mualem functions for    *
      !           hydraulic properties for the specified soil name from soil  *
      !           database.                                                   *
      !                                                                       *
      ! Oct. 1999: two additional variables for extended van Genuchten-Mualem *
      !            functions, i.e. TKK and TWCK. see explanation in:          *
      ! Heinen M., 1999. Extension to the van Genuchten-Mualem description    *
      !    of the hydraulic properties in FUSSIM2. AB, internal note, 7 p.    *
      !                                                                       *
      !                                                                       *
      !  FORMAL PARAMETERS:  (I=input,O=output,C=control,IN=init,T=time)      *
      !  name   type   meaning                                  units  class  *
      !  ----   ----   -------                                  -----  -----  *
      !  IUNIT  I      unit number used (and IUNIT+1)             -      I    *
      !  FILNAM CH*    Name of input file                         -      I    *
      !  SNAME  CH*    name of soil for which the parameters                  *
      !                have to be returned                        -      I    *
      !  KS     R8     hydraulic conductivity at saturation     cm/d     O    *
      !  N      R8     curve shape parameter                      -      O    *
      !  L      R8     curve shape parameter                      -      O    *
      !  WCS    R8     saturated volumetric water content         -      O    *
      !  WCR    R8     residual volumetric water content          -      O    *
      !  ALPHA  R8     curve shape parameter                    1/cm     O    *
      !  ALPHAW R8     curve shape parameter of main wetting                  *
      !                curve                                    1/cm     O    *
      !  KSAT   R8     KsatExm                                  cm/d     O    *
      !  HE     R8     h_enpr_global                            cm       O    *
      !                                                                       *
      ! Functions and subroutines used:                                       *
      ! from TTUTIL : RD* routines, UPPERC, IFINDC                            *
      !                                                                       *
      !-----------------------------------------------------------------------*
   
      use MOD_swap_base, only: unit_err, swmacro
   
      implicit none
   
      ! global parameters
      integer, intent(in)                    :: iunit,itask
      real(8), intent(out)                   :: ks,nd,l,wcs,wcr,alpha,alphaw,ksat,he
      character(len=*), intent(in)           :: filnam,sname
      logical, intent(out)                   :: flksatexm

      ! local parameters
      integer                                :: il,I,IS
      integer,             parameter         :: idecl = 500
      real(8),             dimension(idecl)  :: tks,tnd,tl,twcs,tksat,the,twcr,talp,talpw
      character(len=40),   dimension(idecl)  :: tbname
      character(len=40)                      :: lname
      logical                                :: rdinqr

      ! functions
      integer                                :: ifindc
      save

      select case (itask)

      case (1)
   
         !  read all soil names and parameters input section ; analyse input file
         call rdinit (iunit, unit_err, filnam)
         ! get values from file
         ! soilName ores osat npar alfa alfaw lexp ksat h_enpr ksatExm
         call rdacha ('soilname', tbname, idecl, il)
         call rdfdor ('ores', 0.d0, 1.d0, twcr, idecl, il)
         call rdfdor ('osat', 0.d0, 1.d0, twcs, idecl, il)
         call rdfdor ('npar', 1.001d0, 9.d0, tnd, idecl, il)
         call rdfdor ('alfa', 1.d-4, 100.d0, talp, idecl, il)
         call rdfdor ('alfaw', 1.0d-4, 100.d0, talpw, idecl, il)
         call rdfdor ('lexp', -25.d0,  50.d0, tl, idecl, il)
         if (rdinqr ('ksatfit')) then      ! to allow downward compatibility
            call rdfdor ('ksatfit', 1.d-5, 1.d5, tks, idecl, il)
         else
            call rdfdor ('ksat', 1.d-5 , 1.d5, tks, idecl, il)
         end if
         if (rdinqr ('ksatexm')) then
            flksatexm = .TRUE.
            call rdfdor ('ksatexm',  -1.d5, 1.d5, tksat, idecl, il)
         end if
         if (swmacro == 0) then
            call rdfdor ('H_enpr', -40.d0, 0.d0, the, idecl, il)
         else
            call rdfdor ('H_enpr', -40.d0, -0.1d0, the, idecl, il)
         end if
         do i = 1, il
            call upperc (tbname(i))
         end do
         close (iunit)

      case (2)

         !  check name length
         i = len_trim (sname)
         if (i > len(lname)) call swap_error ('gtsoil', 'Soil name too long')

         !  convert sname tolocal and all names to uppercase
         lname = sname
         call upperc (lname)

         !  find position of LNAME in TBNAME and store as IS; check
         is = ifindc (tbname, idecl, 1, il, lname)
         if (is == 0) call swap_error ('gtsoil', 'Unknown soil')

         !  set output variables
         wcr = twcr (is)
         wcs = twcs (is)
         alpha = talp (is)
         alphaw = talpw (is)
         nd = tnd (is)
         l = tl (is)
         ks = tks (is)       ! Ksatfit
         ksat = tksat (is)     ! Ksatexm
         he = the (is)       ! air-entry value

      case default
         call swap_error ('gtsoil', 'Illegal value for iTask')
      end select

      ! ready
      return
   
   end subroutine gtsoil
   
   ! ---------------------------------------------------------------------
   

   