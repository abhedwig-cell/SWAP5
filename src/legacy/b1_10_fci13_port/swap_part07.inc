   use MOD_meteo,             only: swdivide, epond, peva, ptra_dry, ptra, ptra_wet, reduceva, aintc, wfrac
   use MOD_meteo,             only: tmn, tmx, hum, win, etr, graidt, nraidt, tavd, fprecnosnow
   use MOD_cropdevelopment,   only: fl_cropcalendar
   use MOD_irrigation,        only: nod_ssdi, schedule, gird, nirri, irdate, irdepth, irtype, irconc, irrate, dt_irr_event
   use variables,             only: t1900, iyear, tstart, tend
   use atmosphere_interface,  only: rad, tav

   implicit none
   integer, intent(in)   :: task
   logical, intent(out)  :: flError
   ! local
   integer               :: swssdi
   integer, dimension(6) :: datea
   real                  :: fsec
   real(8), save         :: tlast

! NOTE: the optional arguments in argument list of swap cannot be saved automatically with the attribute SAVE.
!       Therefore, each time allocation is needed and basic information must be set again

   if (task < 30) fromswap%ierrorcode = 0

!  use tasks 11-19 to handle initial aspects
   if (task == 11) then
      ! some error checking
      if (swetr /= 0) then
         fromswap%ierrorcode = -1
         call swap_warning ('handle_exchange', 'SWETR /= 0')
      end if
      if (swdivide /= 1) then
         fromswap%ierrorcode = -2
         call swap_warning ('handle_exchange', 'SWDIVIDE /= 1')
      end if
      if (swmetdetail /= 0) then
         fromswap%ierrorcode = -3
         call swap_warning ('handle_exchange', 'SWMETDETAIL /= 0')
      end if
      if (swrain /= 0) then
         fromswap%ierrorcode = -4
         call swap_warning ('handle_exchange', 'SWRAIN /= 0')
      end if
      if (sw_inter /= 0) then
         fromswap%ierrorcode = -5
         call swap_warning ('handle_exchange', 'SWINTER /= 0')
      end if
      if (swsnow /= 0) then
         fromswap%ierrorcode = -6
         call swap_warning ('handle_exchange', 'SWSNOW /= 0')
      end if
!      if (swrain /= 0 .AND. swrain /= 2) then
!         fromswap%ierrorcode = -4
!         call swap_warning ('handle_exchange', 'SWRAIN /= 0 .AND. SWRAIN /= 2')
!      end if

      call fill_out()
      tlast = 0.0d0
   end if

!  use tasks 21-29 to handle dynamic aspects
   if (task == 21) then
      Tstart = toswap%tstart
      Tend   = toswap%tend

      ! check
      if (tlast > 0.0d0 .AND. dabs(tstart - tlast) > 1.0d-8) then
         fromswap%ierrorcode = 1
         call swap_warning ('handle_exchange', 'Unexpected timing error: TSTART /= TLAST')
      end if
      if (dabs(Tend - Tstart) > 1.0d-8) then
         fromswap%ierrorcode = 2
         call swap_warning ('handle_exchange', 'Only single day allowed: TEND must equal TSTART')
      end if

      ! need to re-initialize
      flrunend   = .FALSE.
      flDayStart = .TRUE.

      ! first set iyear for proper use in TimeControl; this allows for start any time, irrespective of tstart in swap.swp
      call dtdpar (Tstart, datea, fsec)
      iyear = datea(1)
      call call_timecontrol(1)

   end if

   ! set some weather records
   if (task == 22) then
      ! meteo data
      rad  = toswap%rad*1000.0d0               ! Convert radiation from kJ/m2/d to J/m2/d
      tmn  = toswap%tmin                       ! deg. C
      tmx  = toswap%tmax                       ! deg. C
      hum  = toswap%hum                        ! kPa
      win  = toswap%wind                       ! m/s
      graidt = toswap%rain*0.1d0                 ! from mm/d to cm/d
      nraidt = graidt
      etr  = toswap%etref*0.1d0                ! from mm/d to cm/d

      ! extra
      tav  = (tmx+tmn)*0.5d0
      tavd = (tmx+tav)*0.5d0
      ! swsnow mnust be zero (?)
      fprecnosnow = 1.d0

      ! irrigation
      flirrigate = .false.
      schedule = 0                     ! no scheduled irrigation
      swirfix  = int(toswap%swirfix)
      if (swirfix == 0) then
         ! for safety
