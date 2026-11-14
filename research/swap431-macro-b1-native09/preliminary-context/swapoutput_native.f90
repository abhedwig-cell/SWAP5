! File VersionID:
!   $Id: swapoutput.f90 377 2018-04-04 10:57:55Z heine003 $
! ----------------------------------------------------------------------
      subroutine swapoutput(task)
! ----------------------------------------------------------------------
!     Date               : Aug 2004
!     Purpose            : open and write general swap output files
! ----------------------------------------------------------------------
      use MOD_swap_mp,   only: cqmpinintsatdm1, cqmpinintsatdm2, cqmpinmtxsatdm1, cqmpinmtxsatdm2, cqmpoutmtxsatdm1, cqmpoutmtxsatdm2, cqmpoutmtxunsdm1, cqmpoutmtxunsdm2
      use variables,     only: swbal, swblc, flbaloutput, bal, blc

      implicit none

      integer, intent(in)  :: task
      real(8)              :: CQMpExfMtx,CQMpInfMtx

      select case (task)
      case (1)

! === open output files ===============================

! --     bal file
         if (swbal == 1) call outbal (task)

! --     blc file
         if (swblc == 1) then
            CQMpExfMtx = (CQMpInIntSatDm1+CQMpInIntSatDm2+CQMpInMtxSatDm1+CQMpInMtxSatDm2)
            CQMpInfMtx = (CQMpOutMtxSatDm1+CQMpOutMtxSatDm2+CQMpOutMtxUnsDm1+CQMpOutMtxUnsDm2)
            call outblc(task,CQMpExfMtx,CQMpInfMtx)
         end if

         return

      case (2)

! ===    write actual data ===============================

         if (flbaloutput) then

! --        bal file
            if (swbal == 1) call outbal (task)

! --        blc file
         if (swblc == 1) then
            CQMpExfMtx = (CQMpInIntSatDm1+CQMpInIntSatDm2+CQMpInMtxSatDm1+CQMpInMtxSatDm2)
            CQMpInfMtx = (CQMpOutMtxSatDm1+CQMpOutMtxSatDm2+CQMpOutMtxUnsDm1+CQMpOutMtxUnsDm2)
            call outblc(task,CQMpExfMtx,CQMpInfMtx)
         end if

         end if

      return

      case (3)

! ===    close output files ================================

         close (bal)
         if (swblc == 1) close (blc)

      case default
         call swap_error ('swapoutput', 'Illegal value for Task')
      end select

      return
      end

! ----------------------------------------------------------------------
      subroutine soilwateroutput(task)
! ----------------------------------------------------------------------
!     Date               : Aug 2004
!     Purpose            : open and write soil water output files
! ----------------------------------------------------------------------

      use MOD_swap_base, only: sw_end
      use Variables,     only: SWCSV, SWAFO, SWAUN, t1900

      use SWAP_csv_output
      use MOD_out_PEARL_ANIMO
      implicit none

      integer, intent(in)  :: task
      character(len=10)    :: dtprint
      select case (task)

      case (1)
! ===    open output files and write headers ===============================

! --     user-defined variables in CSV file
         if (swcsv > 0) then
            call csv_out(1)
            call dtdpst ('year-month-day', t1900-0.1d0, dtprint)
            call csv_out(2, dtprint = dtprint)
         end if

! --     extensive (un)formatted output file for solute studies
         if (swafo > 0 .OR. swaun > 0) call out_PEARL_ANIMO(task)

      case (2)
! ===    write actual data ===============================

! --     user-defined variables in CSV file
         if (swcsv > 0) call csv_out(2)

! --     extensive (un)formatted output file for solute studies
         if (swafo > 0 .OR. swaun > 0) call out_PEARL_ANIMO(task)

      case (3)
! ===    write final values end of a simulation day ===========================

! ---    write final pressure heads, solute concentrations and soil temperatures
         if (sw_end >= 1) call inoutend (1)

      case (4)
! ===    close output files ===========================

! --     user-defined variables in CSV file
         if (swcsv > 0) call csv_out(3)

         if (swafo > 0 .OR. swaun > 0) call out_PEARL_ANIMO(task)
         
         if (sw_end >= 1) call inoutend (2)

      case default
         call swap_error ('soilwateroutput', 'Illegal value for Task')
      end select

      return
      end

! ----------------------------------------------------------------------
      subroutine outbal (task)
! ----------------------------------------------------------------------
!     date               : July 2002
!     purpose            : write overview balances to bal file
! ---------------------------------------------------------------------
      use MOD_swap_base, only: iun_min, iun_max, project, pathwork, swsolu, swsnow,swdra
      use MOD_Solute,    only: samini, sampro, sqprec, sqirrig, sqbot, dectot, rottot, sqdra
      use MOD_grid,      only: zbotcp, numnod
      use MOD_integral
      use MOD_snow,      only: snowinco,ssnow
      use MOD_drain,     only: nrlevs
      use MOD_swap_mp,   only: cQMpOutDrRap,WaSrDm1,WaSrDm2,WaSrDm1Ini,WaSrDm2Ini
      use variables,     only: bal,ioutdat,tstart,pond,volact,volini,t1900,outdat,outfil,PondIni
                               
      implicit none

! --- global
      integer, intent(in)  :: task

! --- local
      integer              :: i,getun
      real(8)              :: precip
      character(len=80)    :: filnam,filtext
      character(len=11)    :: datbegin,datend
! ----------------------------------------------------------------------

      select case (task)
      case (1)

      ! open output file
      filnam = trim(pathwork)//trim(outfil)//'.bal'
      bal = getun (iun_min, iun_max)
      call fopens(bal,filnam,'new','del')
      filtext='overview of actual water and solute balance components'
      call writehead (bal,1,filnam,filtext,project)

      return

      case (2)

! --- begin date of balance period
      if (ioutdat == 2) then
        call dtdpst ('year-month-day', tstart+0.1d0, datbegin)
      else
        call dtdpst ('year-month-day', outdat(ioutdat-2)+1.1d0, datbegin)
      end if

! --- end date of balance period
      call dtdpst ('year-month-day',t1900-0.9d0,datend)

! --- write output record
      write (bal,20) datbegin,datend
      write (bal,22) -zbotcp(numnod)

      if (swsolu == 1) then
          write (bal,24) (volact+pond+WaSrDm1+WaSrDm2+ssnow),           &
                                                  sampro,               &
                        (volini+PondIni+WaSrDm1Ini+WaSrDm2Ini+snowinco),&
                                                   samini,              &
                        (volact+pond+WaSrDm1+WaSrDm2+ssnow-             &
                         volini-PondIni-WaSrDm1Ini-WaSrDm2Ini-snowinco),&
                                                  (sampro-samini)
      else
          write (bal,25) (volact+pond+WaSrDm1+WaSrDm2+ssnow),           &
                        (volini+PondIni+WaSrDm1Ini+WaSrDm2Ini+snowinco),&
                        (volact+pond+WaSrDm1+WaSrDm2+ssnow-             &
                         volini-PondIni-WaSrDm1Ini-WaSrDm2Ini-snowinco)
      end if

      precip = cgrai
      if (swsnow == 1) then
         precip = precip + cgsnow + csnrai
      end if

      if (swsnow == 1) then
         write (bal,26) precip,caintc,crunon,crunoff,cqssdi,cgird,cqrot,cqbot,(cepd+cevap+csubl),cQMpOutDrRap
      else
         write (bal,27) precip,caintc,crunon,crunoff,cqssdi,cgird,cqrot,cqbot,(cepd+cevap+csubl),cQMpOutDrRap
      end if

      if (swdra /= 0) then
        do i = 1,nrlevs
          write (bal,28) i,cqdrain(i)
        end do
      end if
      write(bal,30) (precip+cgird+cqbot+crunon+cqssdi),(caintc+crunoff+cqrot+cepd+cevap+csubl+cQMpOutDrRap+cqdra)

      if (swsolu == 1) then
        write (bal,34) sqprec,dectot,sqirrig,rottot,sqbot,sqdra
        write (bal,36) (sqprec+sqirrig+sqbot),(dectot+rottot+sqdra)
      end if

 20   format(/'Period',t20,':',t23,a11,' until  ',a11)
 22   format('Depth soil profile',t20,':',f8.2,' cm')
 24   format(/,T13,'Water storage',t36,'Solute storage',/,              &
         'Final',t9,':',t15,f8.2,' cm',t31,e12.4,' mg/cm2',/,           &
         'Initial',t9,':',t15,f8.2,' cm',t31,e12.4,' mg/cm2',/,         &
          t13,13('='),t33,17('='),/,                                    &
         'Change',t15,f8.2,' cm',t31,e12.4,' mg/cm2')
 25   format(/,T13,'Water storage',/,'Final',t9,':',t15,f8.2,' cm',/,   &
         'Initial',t9,':',t15,f8.2,' cm',/,                             &
          t13,13('='),/,'Change',t15,f8.2,' cm')
     26   format(//,'Water balance components (cm)',//,                 &
         'In',t30,'Out',/,25('='),t30,28('='),/,                        &
         'Rain',t16,':',f9.2,t30,'Interception',t48,':',f9.2,/,         &
         'Runon',t16,':',f9.2,t30,'Runoff',t48,':',f9.2,/,              &
         'SSDI',t16,':',f9.2,t30,/,            &
         'Irrigation',t16,':',f9.2,t30,'Transpiration',t48,':',f9.2,/,  &
         'Bottom flux',t16,':',f9.2,t30,'Soil evaporation',t48,':',f9.2,&
         /,t30,'Crack flux',t48,':',f9.2)
     27   format(//,'Water balance components (cm)',//,                 &
         'In',t30,'Out',/,25('='),t30,28('='),/,                        &
         'Rain + snow',t16,':',f9.2,t30,'Interception',t48,':',f9.2,/,  &
         'Runon',t16,':',f9.2,t30,'Runoff',t48,':',f9.2,/,              &
         'SSDI',t16,':',f9.2,t30,/,            &
         'Irrigation',t16,':',f9.2,t30,'Transpiration',t48,':',f9.2,/,  &
         'Bottom flux',t16,':',f9.2,t30,'Soil evaporation',t48,':',f9.2,&
         /,t30,'Crack flux',t48,':',f9.2)
 28   format(t30,'Drainage level',i2,t48,':',f9.2)
 30   format(25('='),t30,28('='),/,                                     &
         'Sum',t16,':',f9.2,t30,'Sum',t48,':',f9.2)
 34   format(//,'Solute balance components (mg/cm2)',//,                &
         'In',t30,'Out',/,25('='),t30,28('='),/,                        &
         'Rain',t13,':',e12.4,t30,'Decomposition',t45,':',e12.4,/,      &
         'Irrigation',t13,':',e12.4,t30,'Root uptake',t45,':',e12.4,/,  &
         'Bottom flux',t13,':',e12.4,/,t30,'Drainage',t45,':',e12.4)
 36   format(25('='),t30,28('='),/,                                     &
         'Sum',t13,':',e12.4,t30,'Sum',t45,':',e12.4,/)

      case default
         call swap_error ('outbal', 'Illegal value for Task')
      end select

      return
   end

   ! ---------------------------------------------------------------------
   
   subroutine inoutend (task)
      ! ------------------------------------------------------------------
      ! read or write final result (.end file)
      ! ------------------------------------------------------------------
      use MOD_swap_base,       only: iun_min, iun_max, pathwork, unit_err, fl_initialize, sw_initype, unit_ini, inifilnam, swhea, swsolu,       &
                                     swdra, swhyst, swsnow, sw_end, sw_endtype, sw_endfilter
      use plant_interface,     only: sw_drought, sw_oxygen, icrop, croptype, fl_cropemergence, fl_cropharvest,                                  &
                                     sw_inter, sicact, dvs, tsum, swrdc, noddrz, dmhrvpot, dmlosspot, dmhrv, dmloss, rd
      use MOD_wofost,          only: sw_wofost, nofd, atmin7, fl_anthesis, fl_vernalised, vern, s_pot, s_act, p_grs, t_tsumcum, m_pot, m_act
      use MOD_SoilTemperature, only: tsoil
      use MOD_Solute,          only: cml,ageml
      use MOD_cropdevelopment, only: fl_cropcalendar, fl_start_croprotation, fl_prep, fl_sow, fl_germ, delay_prep, delay_sow, tsumgerm,                                                &
                                     mxnoddrz, rdpot, cumdens_top, wroot_node, wroot_node_top, lrv_node
      use MOD_grid,            only: numnod
      use MOD_snow,            only: ssnow,slw
      use MOD_drain,           only: wls
      use MOD_irrigation,      only: flIrrigate, dayfix
      use variables,           only: tstart,t1900,h,pond,dt,swredu,ldwet,spev,saev,outfil,indeks,delp,fhyst,hm1
      use MOD_params,          only: nihil
      use MOD_integral,        only: iptra_day, iqrot_day
      use MOD_swap_base, only:swmacro
      implicit none

! --- global
      integer, intent(in)  :: task

! --- local
      logical, save        :: unit_opened = .FALSE.
      
      integer              :: rw
      integer              :: getun
      integer              :: sw_ini, sw_value
      logical              :: rw_status, found
      character(len=300)   :: filnam
      character(len=10)    :: date
      
      ! ------------------------------------------------------------------

      select case (task)
      
      case (1)
      
         ! set modus
         if (fl_initialize) then
            ! reading modus
            rw = 1
         else
            ! writing modus
            rw = 2
         end if

         ! open unit
         if (.NOT. unit_opened) then
      
            ! connection for reading or writing
            if (rw == 1) then

               ! open inifile
               if (sw_initype == 1) then
                  call rdinit(unit_ini, unit_err, inifilnam)
               else
                  call fopeng (unit_ini, inifilnam, 'old', 'us', 0, ' ')
               end if

            end if
      
            if (rw == 2) then

               ! set filename end-file
               if (sw_end == 1 .OR. sw_endtype == 2) then
                  filnam = trim(pathwork)//trim(outfil)//'.end'
               else
                  call dtdpst ('year-month-day',t1900-0.5d0,date)
                  filnam = trim(pathwork)//trim(outfil)//'_'//date(1:4)//date(6:7)//date(9:10)//'.end'
               end if

               ! open unit
               unit_ini = getun (iun_min, iun_max)
               if (sw_endtype == 1) then
                  call fopeng (unit_ini, filnam, 'new', 'fs', 0, 'del')
               else
                  call fopeng (unit_ini, filnam, 'new', 'us', 0, 'del')
               end if

            end if
            
            unit_opened = .TRUE.
            
            ! check type and filter (in case unformatted type)
            if (rw == 1 .AND. sw_initype == 2) then
               call my_rwsint(unit_ini, rw, sw_ini, "SWEND")
               call my_rwsint(unit_ini, rw, sw_value, "SWENDFILTER")
               if (sw_value == 1) call swap_error ('read_ini', 'INIFIL incomplete (file contains crop status only)')
            end if
            
            if (rw == 2 .AND. sw_endtype == 2) then
               call my_rwsint(unit_ini, rw, sw_end, "SWEND")
               call my_rwsint(unit_ini, rw, sw_endfilter, "SWENDFILTER")
            end if
         
         end if

         ! check filter before writing end-conditions
         rw_status = .TRUE.
         if (rw == 2 .AND. sw_endfilter == 1) then
            if (fl_cropemergence) then
               if (iptra_day - iqrot_day < nihil) then
                  rw_status = .FALSE.
               end if
            end if
         end if

         ! read/write end-conditions
         if (rw_status) then

            found = .FALSE.
            do while (.NOT. found)

               ! check time of end-conditions for initialisation
               found = .TRUE.
               if (rw == 1 .AND. sw_ini == 2 .AND. sw_initype == 2) then
                  call my_rwsint(unit_ini, rw, sw_value, "TIME")
                  if (nint(tstart) /= sw_value) found = .FALSE.
                  if (sw_value > nint(tstart)) call swap_error ('read_ini', 'TSTART not found in ini-file')
               end if
               
               ! time of end-conditions
               if (rw == 2 .AND. sw_end == 2 .AND. sw_endtype == 2) then
                  sw_value = nint(t1900)
                  call my_rwsint(unit_ini, rw, sw_value, "TIME")
               end if
               
               if (.NOT. (rw == 2 .AND. sw_endfilter == 1)) then

                  ! number of compartments
                  if (rw == 2) sw_value = numnod
                  call my_rwsint(unit_ini, rw, sw_value, "NUMNOD")
                  if (numnod /= sw_value) call swap_error ('read_ini', 'DISCRETIZATION inconsistent with ini-file')

                  ! pressure head
                  call my_rwadou(unit_ini, rw, h, "H", size(h), numnod)

                  ! ponding layer
                  call my_rwsdou(unit_ini, rw, pond, "POND")

                  ! snow layer
                  if (rw == 2) sw_value = swsnow
                  call my_rwsint(unit_ini, rw, sw_value, "SWSNOW")
                  if (swsnow /= sw_value) call swap_error ('read_ini', 'SWSNOW inconsistent with ini-file')
                  if (swsnow == 1) then
                     call my_rwsdou(unit_ini, rw, ssnow, "SSNOW")
                     call my_rwsdou(unit_ini, rw, slw, "SLW")
                  end if

                  ! soil evaporation reservoirs
                  if (rw == 2) sw_value = swredu
                  call my_rwsint(unit_ini, rw, sw_value, "SWREDU")
                  if (swredu /= sw_value) call swap_error ('read_ini', 'SWREDU inconsistent with ini-file')
                  if (swredu == 1) then
                     call my_rwsdou(unit_ini, rw, ldwet, "LDWET")
                  else if (swredu == 2) then
                     call my_rwsdou(unit_ini, rw, spev, "SPEV")
                     call my_rwsdou(unit_ini, rw, saev, "SAEV")
                  end if

                  ! hysteresis
                  if (rw == 2) sw_value = swhyst
                  call my_rwsint(unit_ini, rw, sw_value, "SWHYST")
                  if (swhyst /= sw_value) call swap_error ('read_ini', 'SWHYST inconsistent with ini-file')
                  if (swhyst /= 0) then
                     call my_rwaint(unit_ini, rw, indeks, "INDEKS", size(indeks), numnod)
                     call my_rwadou(unit_ini, rw, delp, "DELP", size(delp), numnod)
                     call my_rwadou(unit_ini, rw, fhyst, "FHYST", size(fhyst), numnod)
                     call my_rwadou(unit_ini, rw, hm1, "HM1", size(hm1), numnod)
                  end if

                  ! soil temperatures
                  if (rw == 2) sw_value = swhea
                  call my_rwsint(unit_ini, rw, sw_value, "SWHEA")
                  if (swhea /= sw_value) call swap_error ('read_ini', 'SWHEA inconsistent with ini-file')
                  if (swhea > 0) call my_rwadou(unit_ini, rw, tsoil, "TSOIL", size(tsoil), numnod)

                  ! solute
                  if (rw == 2) sw_value = swsolu
                  call my_rwsint(unit_ini, rw, sw_value, "SWSOLU")
                  if (swsolu /= sw_value) call swap_error ('read_ini', 'SWSOLU inconsistent with ini-file')
                  if (swsolu == 1) call my_rwadou(unit_ini, rw, cml, "CML", size(cml), numnod)
                  if (swsolu == 2) call my_rwadou(unit_ini, rw, ageml, "AGEML", size(ageml), numnod)

                  ! surface water
                  if (rw == 2) sw_value = swdra
                  call my_rwsint(unit_ini, rw, sw_value, "SWDRA")
                  if (swdra /= sw_value) call swap_error ('read_ini', 'SWDRA inconsistent with ini-file')
                  if (swdra == 2) call my_rwsdou(unit_ini, rw, wls, "WLS")

                  ! length of final timestep (d)
                  call my_rwsdou(unit_ini, rw, dt, "DT")

                  ! irrigation
                  call my_rwslog(unit_ini, rw, flirrigate, "FLIRRIGATE")
                  if (flirrigate) call my_rwsint(unit_ini, rw, dayfix, "DAYFIX")

               end if

               ! Native accepted-state resume must consume crop state even when
               ! the unchanged original loading origin equals crop emergence.
               if(rw==1.and.sw_initype==2.and.swmacro==1) fl_start_croprotation=.false.
               ! crop section
               if (fl_cropcalendar) then

                  call my_rwslog(unit_ini, rw, fl_cropcalendar, "FL_CROPCALENDAR")
                  if (.NOT. fl_cropcalendar) call swap_error ('read_ini', 'no crop information in ini-file')

                  call my_rwslog(unit_ini, rw, fl_cropemergence, "FL_CROPEMERGENCE")
                  call my_rwslog(unit_ini, rw, fl_cropharvest, "FL_CROPHARVEST")

                  if (fl_start_croprotation .AND. rw == 1) then

                     fl_cropemergence = .FALSE.
                     fl_cropharvest = .FALSE.

                  else   

                     if (.NOT. fl_cropharvest) then

                        call my_rwslog(unit_ini, rw, fl_prep, "FL_PREP")
                        if (.NOT. fl_prep) call my_rwsint(unit_ini, rw, delay_prep, "DELAY_PREP")
                        call my_rwslog(unit_ini, rw, fl_sow, "FL_SOW")
                        if (.NOT. fl_sow) call my_rwsint(unit_ini, rw, delay_sow, "DELAY_SOW")
                        call my_rwslog(unit_ini, rw, fl_germ, "FL_GERM")
                        if (.NOT. fl_germ) call my_rwsdou(unit_ini, rw, tsumgerm, "TSUMGERM")

                     end if

                     ! write crop growth data of fixed crop growth
                     if (fl_cropemergence) then

                        ! interception
                        if (rw == 2) sw_value = sw_inter
                        call my_rwsint(unit_ini, rw, sw_value, "SWINTER")
                        if (sw_value == 3) call my_rwsdou(unit_ini, rw, sicact, "SIACT")

                        ! phenology
                        call my_rwsdou(unit_ini, rw, dvs, "DVS")
                        call my_rwsdou(unit_ini, rw, tsum, "TSUM")

                        if (rw == 2) sw_value = croptype(icrop)
                        call my_rwsint(unit_ini, rw, sw_value, "CROPTYPE")
                        if (sw_value == 2) then

                           ! minimum temperatures of last week
                           call my_rwsint(unit_ini, rw, nofd, "NOFD")
                           call my_rwadou(unit_ini, rw, atmin7, "ATMIN7", size(atmin7), nofd)

                           ! phenology (WOFOST)
                           call my_rwslog(unit_ini, rw, fl_anthesis, "FL_ANTHESIS")
                           call my_rwslog(unit_ini, rw, fl_vernalised, "FL_VERNALISED")
                           call my_rwsdou(unit_ini, rw, vern, "VERN")

                           ! potential crop development
                           if (.NOT. (rw == 2 .AND. sw_endfilter == 1)) then
                              call my_rwsdou(unit_ini, rw, s_pot%wrt, "WRTPOT")
                              call my_rwsdou(unit_ini, rw, s_pot%wst, "WSTPOT")
                              call my_rwsdou(unit_ini, rw, s_pot%wlv, "WLVPOT")
                              call my_rwsdou(unit_ini, rw, s_pot%wso, "WSOPOT")

                              call my_rwsdou(unit_ini, rw, s_pot%dwrt, "DWRTPOT")
                              call my_rwsdou(unit_ini, rw, s_pot%dwst, "DWSTPOT")
                              call my_rwsdou(unit_ini, rw, s_pot%dwlv, "DWLVPOT")

                              call my_rwsdou(unit_ini, rw, s_pot%laiexp, "LAIEXPPOT")
                              call my_rwsdou(unit_ini, rw, s_pot%lai, "LAIPOT")
                              call my_rwsint(unit_ini, rw, s_pot%ilv, "ILVPOT")

                              call my_rwadou(unit_ini, rw, s_pot%sla, "SLAPOT", size(s_pot%sla), s_pot%ilv)
                              call my_rwadou(unit_ini, rw, s_pot%lvage, "LVAGEPOT", size(s_pot%lvage), s_pot%ilv)
                              call my_rwadou(unit_ini, rw, s_pot%lv, "LVPOT", size(s_pot%lv), s_pot%ilv)
                           end if

                           ! actual crop development
                           call my_rwsdou(unit_ini, rw, s_act%wrt, "WRT")
                           call my_rwsdou(unit_ini, rw, s_act%wst, "WST")
                           call my_rwsdou(unit_ini, rw, s_act%wlv, "WLV")
                           call my_rwsdou(unit_ini, rw, s_act%wso, "WSO")

                           call my_rwsdou(unit_ini, rw, s_act%dwrt, "DWRT")
                           call my_rwsdou(unit_ini, rw, s_act%dwst, "DWST")
                           call my_rwsdou(unit_ini, rw, s_act%dwlv, "DWLV")

                           call my_rwsdou(unit_ini, rw, s_act%laiexp, "LAIEXP")
                           call my_rwsdou(unit_ini, rw, s_act%lai, "LAI")
                           call my_rwsint(unit_ini, rw, s_act%ilv, "ILV")

                           call my_rwadou(unit_ini, rw, s_act%sla, "SLA", size(s_act%sla), s_act%ilv)
                           call my_rwadou(unit_ini, rw, s_act%lvage, "LVAGE", size(s_act%lvage), s_act%ilv)
                           call my_rwadou(unit_ini, rw, s_act%lv, "LV", size(s_act%lv), s_act%ilv)

                           ! WOFOST (GRASS)
                           if (rw == 2) sw_value = sw_wofost
                           call my_rwsint(unit_ini, rw, sw_value, "SWWOFOST")
                           if (sw_value == 3) then

                              ! start of crop development
                              if (rw == 2) sw_value = p_grs%sw_tsum
                              call my_rwsint(unit_ini, rw, sw_value, "SWTSUM")
                              if (sw_value == 2) call my_rwsint(unit_ini, rw, t_tsumcum, "TSUMCUM")

                              ! management potential crop development
                              if (.NOT. (rw == 2 .AND. sw_endfilter == 1)) then
                                 call my_rwsdou(unit_ini, rw, dmhrvpot, "DMHRVPOT")
                                 call my_rwsdou(unit_ini, rw, dmlosspot, "DMLOSSPOT")
                              
                                 call my_rwsint(unit_ini, rw, m_pot%icut, "ICUTPOT")
                                 call my_rwsint(unit_ini, rw, m_pot%tcut, "TCUTPOT")
                                 call my_rwsint(unit_ini, rw, m_pot%tdelay, "TDELAYPOT")
                                 call my_rwslog(unit_ini, rw, m_pot%fl_grz, "FL_GRZPOT")
                                 call my_rwsint(unit_ini, rw, m_pot%tgrz, "TGRZPOT")
                                 call my_rwslog(unit_ini, rw, m_pot%fl_cutend, "FL_CUTENDPOT")
                              end if

                              ! management actual crop development
                              call my_rwsdou(unit_ini, rw, dmhrv, "DMHRV")
                              call my_rwsdou(unit_ini, rw, dmloss, "DMLOSS")

                              call my_rwsint(unit_ini, rw, m_act%icut, "ICUT")
                              call my_rwsint(unit_ini, rw, m_act%tcut, "TCUT")
                              call my_rwsint(unit_ini, rw, m_act%tdelay, "TDELAY")
                              call my_rwslog(unit_ini, rw, m_act%fl_grz, "FL_GRZ")
                              call my_rwsint(unit_ini, rw, m_act%tgrz, "TGRZ")
                              call my_rwslog(unit_ini, rw, m_act%fl_cutend, "FL_CUTEND")

                           end if

                        end if

                        ! root development
                        if (.NOT. (rw == 2 .AND. sw_endfilter == 1)) then
                           call my_rwsdou(unit_ini, rw, rdpot, "RDPOT")
                        end if
                        call my_rwsdou(unit_ini, rw, rd, "RD")
                     
                        if (.NOT. (rw == 2 .AND. sw_endfilter == 1)) then
                           call my_rwsint(unit_ini, rw, mxnoddrz, "MXNODDRZ")
                           call my_rwsint(unit_ini, rw, noddrz, "NODDRZ")
                           call my_rwadou(unit_ini, rw, cumdens_top(2:noddrz), "CUMDENS_TOP", size(cumdens_top), noddrz)
                        
                           if (rw == 2) sw_value = sw_drought
                           call my_rwsint(unit_ini, rw, sw_value, "SWDROUGHT")
                           if (rw == 1) sw_drought = sw_value
                           if (rw == 2) sw_value = sw_oxygen
                           call my_rwsint(unit_ini, rw, sw_value, "SWOXYGEN")
                           if (rw == 1) sw_oxygen = sw_value
                           if (rw == 2) sw_value = swrdc
                           call my_rwsint(unit_ini, rw, sw_value, "SWRDC")
                           if (rw == 1) swrdc = sw_value
                           if (swrdc == 1 .OR. sw_drought > 1 .OR. sw_oxygen == 2) then
                              call my_rwadou(unit_ini, rw, wroot_node_top, "WROOT_NODE_TOP", size(wroot_node_top), noddrz)
                              call my_rwadou(unit_ini, rw, wroot_node, "WROOT_NODE", size(wroot_node), noddrz)
                              call my_rwadou(unit_ini, rw, lrv_node, "LRV_NODE", size(lrv_node), noddrz)
                           end if
                        end if

                     end if
                     
                  end if

               else   

                  call my_rwslog(unit_ini, rw, fl_cropcalendar, "FL_CROPCALENDAR")

               end if
         
               if (sw_endfilter == 0) then
                  if ((rw==1.and.sw_initype==2).or.(rw==2.and.sw_endtype==2)) call native09_io(unit_ini,rw)
               end if
            end do
               
            ! close unit
            if (rw == 1 .OR. sw_end == 1 .OR. sw_endtype == 1) then
               close (unit_ini)
               unit_opened = .FALSE.
            end if

         end if

         return
      
      case (2)

         ! close unit
         if (unit_opened) then
            close (unit_ini)
            unit_opened = .FALSE.
         end if

         return
      
      case default

         call swap_error ('inoutend', 'Illegal value for TASK')

      end select
      
   end subroutine inoutend
   
   ! ---------------------------------------------------------------------
   
   subroutine my_rwslog(iun, rw, var, txt)
      
      use MOD_arrays,    only: fillen
      use MOD_swap_base, only: sw_initype, sw_endtype
      
      implicit none
      
      integer, intent(in)           :: iun, rw
      logical, intent(inout)        :: var
      character(len=*), intent(in)  :: txt
      
      character(len=fillen)         :: hlp
      integer                       :: vartmp

      if (rw == 1) then

         ! read modus
         if (sw_initype == 1) then
            call rdsint(txt, vartmp)
         else
            read(iun) vartmp
         endif

         var = vartmp == 1

      else

         ! write modus   
         if (var) then
            vartmp = 1
         else
            vartmp = 0
         end if

         if (sw_endtype == 1) then
            hlp = '("' // trim(txt) // ' = ",i1)'
            write(iun, hlp) vartmp
         else
            write(iun) vartmp
         endif
         

      endif
      
   end subroutine my_rwslog   
      
   ! ---------------------------------------------------------------------
   
   subroutine my_rwsdou(iun, rw, var, txt)
      
      use MOD_arrays,    only: fillen
      use MOD_swap_base, only: sw_initype, sw_endtype
      
      implicit none
      
      integer, intent(in)           :: iun, rw
      real(8), intent(inout)        :: var
      character(len=*), intent(in)  :: txt
      
      character(len=*), parameter   :: frm = 'e22.14'
      character(len=fillen)         :: hlp

      if (rw == 1) then

         ! read modus
         if (sw_initype == 1) then
            call rdsdou(txt, var)
         else
            read(iun) var
         endif

      else

         ! write modus   
         if (sw_endtype == 1) then
            hlp = '("' // trim(txt) // ' = ",'// '1P,' // trim(frm) // ')'
            write(iun, hlp) var
         else
            write(iun) var
         endif
         

      endif
      
   end subroutine my_rwsdou
   
   ! ---------------------------------------------------------------------
   
   subroutine my_rwadou(iun, rw, var, txt, ildec, il)
      
      use MOD_arrays,    only: fillen
      use MOD_swap_base, only: sw_initype, sw_endtype
      
      implicit none
      
      integer, intent(in)           :: iun, rw, ildec, il
      real(8), intent(inout)        :: var(ildec)
      character(len=*), intent(in)  :: txt
      
      character(len=*), parameter   :: frm = 'e22.14'
      integer, parameter            :: nrec = 25
      character(len=fillen)         :: hlp, itxt
      integer                       :: i, istart, istop

      if (rw == 1) then

         ! read modus
         if (sw_initype == 1) then
            if (il /= 1) then
               call rdadou(txt, var, ildec, il)
            else
               call rdsdou(txt, var(1))
            end if
         else
            read(iun) (var(i),i=1,il)
         endif

      else

         ! write modus   
         if (sw_endtype == 1) then
            istart = 1
            do while (istart <= il)
               istop = min(il, istart + nrec - 1)
               write(itxt,'(i8)') istop - istart + 1
               if (istart == 1) then
                  hlp = '("' // trim(txt) // ' = ",'// '1P,' // trim(itxt) // trim(frm) // ')'
               else
                  hlp = '(' // trim(itxt) // trim(frm) // ')'
               end if
               write(iun, hlp) (var(i),i=istart,istop)
               istart = istart + nrec
            end do
         else
            write(iun) (var(i),i=1,il)
         endif

      endif
      
   end subroutine my_rwadou
   
   ! ---------------------------------------------------------------------

   subroutine my_rwsint(iun, rw, var, txt)
      
      use MOD_arrays,    only: fillen
      use MOD_swap_base, only: sw_initype, sw_endtype
      
      implicit none
      
      integer, intent(in)           :: iun, rw
      integer, intent(inout)        :: var
      character(len=*), intent(in)  :: txt
      
      character(len=*), parameter   :: frm = 'i8'
      character(len=fillen)         :: hlp
      
      if (rw == 1) then
         
         ! read modus
         if (sw_initype == 1) then
            call rdsint(txt, var)
         else
            read(iun) var
         endif
      
      else
         
         ! write modus
         if (sw_endtype == 1) then
            hlp = '("' // trim(txt) // ' = ",'// trim(frm) // ')'
            write(iun, hlp) var
         else
            write(iun) var
         endif
      
      endif
      
   end subroutine my_rwsint   
   
   ! ---------------------------------------------------------------------
   
   subroutine my_rwaint(iun, rw, var, txt, ildec, il)
      
      use MOD_arrays,    only: fillen
      use MOD_swap_base, only: sw_initype, sw_endtype
      
      implicit none
      
      integer, intent(in)           :: iun, rw, ildec, il
      integer, intent(inout)        :: var(ildec)
      character(len=*), intent(in)  :: txt
      
      character(len=*), parameter   :: frm = 'i8'
      character(len=fillen)         :: hlp, iltxt
      integer :: i

      if (rw == 1) then

         ! read modus
         if (sw_initype == 1) then
            if (il /= 1) then
               call rdaint(txt, var, ildec, il)
            else
               call rdsint(txt, var(1))
            end if
         else
            read(iun) (var(i),i=1,il)
         endif

      else

         ! write modus   
         if (sw_endtype == 1) then
            write(iltxt,'(i8)') il
            hlp = '("' // trim(txt) // ' = ",'// trim(iltxt) // trim(frm) // ')'
            write(iun, hlp) (var(i),i=1,il)
         else
            write(iun) (var(i),i=1,il)
         endif

      endif
      
   end subroutine my_rwaint
   
! ----------------------------------------------------------------------
   subroutine outblc(task,CQMpExfMtx,CQMpInfMtx)
! ----------------------------------------------------------------------
!     date               : December 2004
!     purpose            : Write detailed overview of water balance
! ---------------------------------------------------------------------
      
      use MOD_swap_base,  only: iun_min, iun_max, project, pathwork, swmacro, swirfix
      use MOD_grid,       only: zbotcp, numnod
      use MOD_integral
      use MOD_snow,       only: snowinco,ssnow
      use MOD_drain,      only: nrlevs
      use MOD_swap_mp,    only: IcTopMp,CQMpInTopVrtDm1,CQMpInTopVrtDm2,CQMpInTopLatDm1,CQMpInTopLatDm2
      use MOD_irrigation, only: schedule
      use variables,      only: blc,outfil,volact,volini,ioutdat,t1900,outdat,tstart,pond,pondini
                               
      implicit none

!     global
      integer, intent(in)     :: task
      real(8), intent(inout)  :: CQMpInfMtx, CQMpExfMtx

!    local
      integer                 :: getun,level

      real(8)                 :: CQMpInTop,soilout
      real(8)                 :: plantin,plantout,snowin,snowout,pondin,pondout,soilin

      character(len=300)      :: filnam
      character(len=11)       :: datbegin,datend
      character(len=80)       :: filtext
! ----------------------------------------------------------------------

      select case (task)
      case (1)
! --- open output file
      filnam = trim(pathwork)//trim(outfil)//'.blc'
      blc = getun (iun_min, iun_max)
      call fopens(blc,filnam,'new','del')
      filtext='detailed overview of water balance components (cm)'
      call writehead (blc,1,filnam,filtext,project)

      return

      case (2)

! --- begin date of balance period
      if (ioutdat == 2) then
        call dtdpst ('year-month-day', tstart+0.1d0, datbegin)
      else
        call dtdpst ('year-month-day', outdat(ioutdat-2)+1.1d0, datbegin)
      end if

! --- end date of balance period
      call dtdpst ('year-month-day',t1900-0.9d0,datend)

! --- initialize macropore variables
      if (swmacro == 0) then
         CQMpInfMtx = 0.0d0
         CQMpExfMtx = 0.0d0
         CQMpInTop = 0.0d0
      else
         if (IcTopMp == 1) then
            CQMpInTop = CQMpInTopVrtDm1 + CQMpInTopVrtDm2 + CQMpInTopLatDm1 + CQMpInTopLatDm2
         else
            CQMpInTop = 0.d0
         end if
      end if

! --- write output record
      write (blc,20) datbegin,datend
      write (blc,22) -zbotcp(numnod)
      write (blc,40)
      write (blc,41) snowinco,pondini,volini,ssnow,pond,volact
      write (blc,42) cgrai
      write (blc,44) csnrai,cqprai,cnrai
      if (swirfix == 1 .OR. schedule == 1) then
        write (blc,46) cgird
        write (blc,67) cnird,cnird
      end if
      write (blc,45) caintc
      write (blc,43) cgsnow
      write (blc,47) cmelt,cmelt
      write (blc,68) csubl
      write (blc,48) cqssdi, cqrot
      write (blc,491) cevap+cepd
      write (blc,492) crunon,crunoff
      write (blc,50) cinund
      write (blc,52) cqtdo,cqtdo
      write (blc,53) cqtup,cqtup
      if (swmacro == 1)  write(blc,54) CQMpInTop, CQMpInfMtx, CQMpExfMtx

      if (nrlevs >= 1) then
        write (blc,55)
        do level=1,nrlevs
          write (blc,56) level,cqdrainin(level),level, cqdrainout(level)
        end do
      end if
      write (blc,61) cqbotup,cqbotdo

! --- sum
      plantin = cgrai+cgird
      snowin = snowinco+cgsnow+csnrai
      pondin = pondini+cqprai+cnird+cmelt+cinund+cqtup+crunon
      soilin = volini+cqtdo+cqbotup+CQMpInfMtx
      do level = 1,nrlevs
        soilin = soilin + cqdrainin(level)
      end do
      plantout = cnrai+caintc+cnird
      snowout = cmelt+ssnow+csubl
      pondout = pond+crunoff+cqtdo+cevap+cepd+CQMpInTop
      soilout = volact+cqrot+cqtup+cqbotdo+CQMpExfMtx-cqssdi
      do level = 1,nrlevs
        soilout = soilout + cqdrainout(level)
      end do

      write (blc,63) plantin,snowin,pondin,soilin,plantout,snowout,pondout,soilout
      write (blc,64) (ssnow-snowinco),(pond-pondini),(volact-volini)
      write (blc,65) (plantout-plantin),(snowout-snowin),(pondout-pondin),(soilout-soilin)

 20   format(/'Period',t20,':',t23,a11,' until  ',a11)
 22   format('Depth soil profile',t20,':',f8.2,' cm')
 40   FORMAT(49('='),'+',49('='),/,'INPUT',t50,'|',t52,'OUTPUT',/,t17,  &
      '   PLANT    SNOW    POND    SOIL',t50,'|',t67,                   &
      '   PLANT    SNOW    POND    SOIL',/,49('='),'+',49('='))
 41   FORMAT('Initially Present',t25,3f8.2,t50,'|',t52,                 &
             'Finally present',t75,3f8.2)
 42   FORMAT('Gross Rainfall',t17,f8.2,t50,'|')
 43   FORMAT('Snowfall',t25,f8.2,t50,'|')
 44   FORMAT('Nett Rainfall',t25,2f8.2,t50,'|',t52,'Nett Rainfall',     &
              t67,f8.2)
 45   FORMAT(t50,'|',t52,'Interception',t67,f8.2)
 46   FORMAT('Gross Irrigation',t17,f8.2,t50,'|')
 67   FORMAT('Nett Irrigation',t33,f8.2,t50,'|',t52,'Nett Irrigation',  &
              t67,f8.2)
 47   FORMAT('Snowmelt',t33,f8.2,t50,'|',t52,'Snowmelt',t75,f8.2)
 68   FORMAT(t50,'|',t52,'Sublimation',t75,f8.2)
 48   FORMAT('SSDI',t41,f8.2,t50,'|',t52,'Plant Transpiration',t91,f8.2)
 491  FORMAT(t50,'|',t52,'Soil Evaporation',t83,f8.2)
 492  FORMAT('Runon',t33,f8.2,t50,'|',t52,'Runoff',t83,f8.2)
 50   FORMAT('Inundation',t33,f8.2,t50,'|')
 52   FORMAT('Infiltr. Soil Surf.',t41,f8.2,t50,'|',t52,                &
             'Infiltr. Soil Surf.',t83,f8.2)
 53   FORMAT('Exfiltr. Soil Surf.',t33,f8.2,t50,'|',t52,                &
             'Exfiltr. Soil Surf.',t91,f8.2)
 54   FORMAT(t50,'|',t52,'Inflow top macroprs',t83,f8.2,/,              &
             'Infiltr. macropores',t41,f8.2,t50,'|',t52,                &
             'Exfiltr. macropores',t91,f8.2)
 55   FORMAT('Infiltr. subsurf.',t50,'|',t52,'Drainage')
 56   FORMAT('- system',i2,t41,f8.2,t50,'|',t52,'- system',i2,t91,f8.2)
 61   FORMAT('Upward seepage',t41,f8.2,t50,'|',t52,'Downward seepage',  &
              t91,f8.2,/,49('='),'+',49('='))
 63   FORMAT('Sum',t17,4f8.2,t50,'|',t52,'Sum',t67,4f8.2,/,49('='),'+', &
              49('='))
 64   FORMAT('Storage Change',t25,3f8.2)
 65   FORMAT('Balance Deviation',t18,f7.2,3f8.2,/,99('='),/)

      case default
         call swap_error ('outbLc', 'Illegal value for Task')
      end select

      return
      end

! ----------------------------------------------------------------------
    subroutine swap_ok(swp_ok)
      
      use MOD_swap_base, only: iun_min, iun_max, project, pathwork
      use MOD_arrays,    only: fillen
      implicit none
      character(len=*), intent(in), optional :: swp_ok
      character(len=fillen)                  :: fout
      integer                                :: getun
      integer                                :: unit_ok
      
      fout = trim(pathwork)//'swap.ok'
      if (present(swp_ok)) fout = swp_ok
      unit_ok = getun (iun_min, iun_max)
      open(unit = unit_ok, file = fout, status = 'unknown')
      call writehead(unit_ok, 1, 'swap.ok', 'simulation succesfully terminated', project)
      close (unit_ok)

      return
    end    
    
! ----------------------------------------------------------------------
    subroutine swap_warning (routine, message)
      
      use MOD_swap_base, only: iun_min, iun_max, swscre, toscr, unit_wrn, first_wrn, wrnfilnam
      
      implicit none
      integer                       :: getun
      character(len=*), intent(in)  :: routine, message
      
      ! initial part of procedure
      
      if (first_wrn) then

         first_wrn = .FALSE.

         ! open warning file
         unit_wrn = getun (iun_min, iun_max)
         call fopens (unit_wrn, wrnfilnam, 'new', 'del')
      
      end if
      
      ! main part of the procedure
      
      ! overrule log-file with warning-file
      call messini (toscr, .TRUE., unit_wrn)

      ! warning message
      call warning (routine, message)
      
      ! back to default settings
      call messini (toscr, .FALSE., 0)
      
      ! message to screen (optional)
      if (swscre > 0) then
         write (*,'(2x,4a)') 'WARNING module '//routine//': '//trim(message)
      end if

    end

! ----------------------------------------------------------------------
    subroutine swap_error (routine, message)
      
      use MOD_swap_base, only: toscr, unit_err
      
      implicit none
      
      character(len=*), intent(in) :: routine, message
      
      ! overrule log-file with err-file
      call messini (toscr, .TRUE., unit_err)

      ! error message
      call fatalerr (routine, message)

    end
    
    subroutine writehead(outf,ftype,filnam,filtext,project)!,savetime)
!-----------------------------------------------------------------------
!      Date    : January 2006
!      Purpose : Writes a header to output files of SWAP

!-----------------------------------------------------------------------
      use MOD_description, only: version
      implicit none

!     global
      integer,          intent(in)  :: outf,ftype
      !integer, optional,intent(in)  :: savetime
      character(len=*), intent(in)  :: project,filnam,filtext

!    local
      integer                       :: date_time(6)
      real(8)                       :: dpactualtime
      real(4)                       :: dum
      character(len=80)             :: model_id,dtstring,String
!-----------------------------------------------------------------------

! --- Version nr of model, to appear in all output files
!     together with revision nr

      model_id = 'Swap '//trim(Version)

! --- get actual time
      call dtnow (date_time)
      dum = 0.0
      call dtardp (date_time, dum, dpactualtime)
      call dtdpst ('year-month-day hour:min:sec', dpactualtime, dtstring)

      if (outf == 5) then
! ---   write to screen
        write (*,16)  trim(project)
        write (*,17)  trim(filtext)
        write (*,19)  trim(model_id)
        write (*,20)  trim(dtstring)
      else if (ftype == 1) then
!       write formatted output file
        write (outf,16)  trim(project)
        write (outf,17)  trim(filtext)
        write (outf,18)  trim(filnam)
        write (outf,19)  trim(model_id)
        write (outf,20)  trim(dtstring)
      else
!       write unformatted output file (header has fixed length of 80 characters)
        write (String,'(a80)')  '* Project:       '//trim(project)
        write (outf)  adjustl(String)
        write (String,'(a80)')  '* File content:  '//trim(filtext)
        write (outf)  adjustl(String)
        write (String,'(a80)')  '* File name:     '//trim(filnam)
        write (outf)  adjustl(String)
        write (String,'(a80)')  '* Model version: '//trim(model_id)
        write (outf)  adjustl(String)
        write (String,'(a80)')  '* Generated at:  '//trim(dtstring)
        write (outf)  adjustl(String)
      end if

 16   format('* Project:       ',a)
 17   format('* File content:  ',a)
 18   format('* File name:     ',a)
 19   format('* Model version: ',a)
 20   format('* Generated at:  ',a)

      return
      end

! ----------------------------------------------------------------------
      subroutine CloseTempFil
! ----------------------------------------------------------------------
!     date               : Aug 2004
!     purpose            : delete temporary files of TTUTIL
! ----------------------------------------------------------------------
      implicit  none
      integer  :: cexf,getun

      ! delete temporary files
      cexf = getun (50000, 60000)
      call rddtmp(cexf)

      return
      end
