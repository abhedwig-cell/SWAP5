         gird         = 0.0d0
         nirri        = 1
         dt_irr_event = 1.0d0
      else
         irdate       = toswap%irdate
         irrate       = toswap%irdepth*0.1d0         ! from mm/d to cm/d
         irdepth      = irrate
         irtype       = int(toswap%irtype)
         nirri        = 1
         irconc       = 0.0d0
         flirrigate   = .true.
         dt_irr_event = 1.0d0
      end if

      swssdi = int(toswap%swssdi)
      if (swssdi == 0) then
         ! for safety
         gird         = 0.0d0
         nirri        = 1
         dt_irr_event = 1.0d0
      else
         irdate       = toswap%ssdi_date
         irrate       = toswap%ssdi_rate_f*0.1d0*24.0d0       ! from mm/h to cm/d
         irdepth      = toswap%ssdi_amount_f*0.1d0            ! from mm   to cm
         nod_ssdi     = int(toswap%ssdi_node)
         nirri        = 1
         flirrigate   = .true.
         if (irdepth(1) > irrate(1)) then
            call swap_warning('irrigation', 'irdepth/irrate > 1.0d0; irrate temporarily adapted')
            irrate       = irdepth
            dt_irr_event = 1.0d0
         else
            dt_irr_event = irdepth(1)/irrate(1)
         end if
         call call_timecontrol(9)
      end if

   end if

   ! set some crop status vars
   if (task == 23) then
      lai = toswap%lai                                ! m2/m2
      ch  = toswap%ch                                 ! cm
      rd  = toswap%zroot                              ! cm

      ! set crop status
      fl_cropcalendar = toswap%icrop /= 0
      fl_cropemergence = toswap%icrop /= 0
      fl_cropharvest = toswap%icrop == 0

   end if

   ! force PTRANS and PEVAP
   if (task == 24) then
      if (toswap%ipet == 1) then
         ptra_dry = 0.1d0 * toswap%ptrans            ! from mm/d to cm/d
         ptra     = ptra_dry
         ptra_wet = 0.0d0
         aintc    = 0.0d0
         wfrac    = 0.0d0
         peva     = 0.1d0 * toswap%pevap             ! from mm/d to cm/d
         ! hoe hier mee om te gaan?
         empreva  = peva
         epond    = peva
         call reduceva(toswap%rain*0.1d0)
      end if
   end if

   if (task == 29) then
      call fill_out()
      tlast = t1900
   end if

!  use tasks 31-39 to handle closure aspects
   if (task == 31) then
   end if

!  set return flerror
   flError = .FALSE.
   if (task < 30) flError = fromswap%iErrorCode /= 0

   end subroutine handle_exchange

   subroutine fill_out()
      use MOD_grid,              only : numnod, dz
      use MOD_integral,          only: inq, inqrot, iptra, iqrot, iepd, ipeva, ievap, inqdra
      use variables,             only: Tstart, Tend, h, theta, gwl
      use MOD_integral,          only: igird, iqssdi
      use MOD_SoilTemperature,   only: tsoil
      
      fromswap%tstart          = Tstart
      fromswap%tend            = Tend
      fromswap%numnodes        = numnod
      fromswap%tpot            = iptra
      fromswap%tact            = iqrot
      fromswap%epot            = ipeva
      fromswap%eact            = ievap+iepd
      fromswap%gwl             = gwl
      fromswap%dz(1:numnod)    = dz(1:numnod)
      fromswap%h(1:numnod)     = h(1:numnod)
      fromswap%wc(1:numnod)    = theta(1:numnod)
      fromswap%rwu(1:numnod)   = inqrot(1:numnod)
      fromswap%tsoil(1:numnod) = tsoil(1:numnod)
      fromswap%q(1:numnod)     = inq(1:numnod)
      fromswap%qdra(1:numnod)  = inqdra(1, 1:numnod) + inqdra(2, 1:numnod) + inqdra(3, 1:numnod) + inqdra(4, 1:numnod) + inqdra(5, 1:numnod)
      !if (.NOT.allocated(fromswap%dz))  allocate(fromswap%dz(numnod));  fromswap%dz(1:numnod)  = dz(1:numnod)
      !if (.NOT.allocated(fromswap%wc))  allocate(fromswap%wc(numnod));  fromswap%wc(1:numnod)  = theta(1:numnod)
      !if (.NOT.allocated(fromswap%rwu)) allocate(fromswap%rwu(numnod)); fromswap%rwu(1:numnod) = 0.0d0
      fromswap%igird           = igird
      fromswap%iqssdi          = iqssdi
   end subroutine fill_out

   end subroutine swap

