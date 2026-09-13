         
         if (swmacro == 1) call macropore(5)
         
      end if

   case (3)  ! perform integrations

! --- potential transpiration of this timestep
      ptrats = ptra * dt

! --- ponding evaporation of this timestep
      epdts = epd * dt
      
! --- potential soil evaporation of this timestep
      pevats = peva * dt

! --- reduced soil evaporation of this timestep
      revats = reva * dt

! --- flux lower boundary of this timestep
      qbotts = qbot*dt

! --- total root extraction of this timestep
      qrotts = qrosum * dt

! --- total drainage flux of this timestep
      qdrats = qdrtot * dt

! --- F-CI11: unrounded external water-flux accounting for a transaction trial.
!     The accumulator is passed explicitly and is therefore worker/job-local.
!     Snow/macropore profiles remain fail-closed until their storage state is admitted.
      if (present(trial_mass)) then
         if (swsnow /= 0 .or. swmacro /= 0) then
            call invalidate_b1_10_trial_mass(trial_mass)
         else
            trial_drain_in = 0.0d0
            trial_drain_out = 0.0d0
            if (swdra > 0) then
               do level = 1, nrlevs
                  if (qdrain(level) < 0.0d0) trial_drain_in = trial_drain_in - qdrain(level)*dt
                  if (qdrain(level) > 0.0d0) trial_drain_out = trial_drain_out + qdrain(level)*dt
               end do
            end if
            if (sw_inter /= 3) then
               trial_interception = aintcdt * dt
            else
               trial_interception = crsflx_out * dt
            end if
            call record_b1_10_trial_mass_step(trial_mass, graidt*dt, gird*dt, runon*dt, qssdisum*dt, qbotts, &
                 trial_drain_in, trial_drain_out, trial_interception, runots, qrotts, epdts, revats)
         end if
      end if

! --- add time step fluxes to intermediate totals
      iqrot = iqrot + qrotts
      do node = 1,noddrz
        inqrot(node)        = inqrot(node) + qrot(node) * dt
        inqpotrot(node)     = inqpotrot(node) + qpotrot(node) * dt
        inqredrot(node)     = inqredrot(node) + (qredwet(node) + qreddry(node) + qredsol(node) + qredfrs(node) + qredrwu(node)) * dt
        inqpotrot_day(node) = inqpotrot_day(node) + qpotrot(node) * dt
        inqredrot_day(node) = inqredrot_day(node) + (qredwet(node) + qreddry(node) + qredsol(node) + qredfrs(node) + qredrwu(node)) * dt
      end do
      do node = 1,numnod
        inqssdi(node) = inqssdi(node) + qssdi(node) * dt
        iqssdi        = iqssdi + qssdi(node) * dt
      end do
      iqredwet     = iqredwet + qredwetsum*dt
      iqreddry     = iqreddry + qreddrysum*dt
      iqredsol     = iqredsol + qredsolsum*dt
      iqredfrs     = iqredfrs + qredfrssum*dt
      iqreddry_day = iqreddry_day + qreddrysum*dt
      iqredsol_day = iqredsol_day + qredsolsum*dt
      iqrot_day    = iqrot_day + qrotts
      iptra_day    = iptra_day + ptra * dt
      
      ialpwet_day = ialpwet_day + alpwetnoddrz * dt
      ialpdry_day = ialpdry_day + alpdrynodrtz * dt

      if (sw_inter /= 3) then
         iintc  = iintc + aintcdt * dt
      else
         iintc  = iintc + crsflx_out * dt
      end if

      iptra  = iptra + ptrats
      iepd   = iepd + epdts
      ipeva  = ipeva + pevats
      ievap  = ievap + revats
      iruno  = iruno + runots
      irunon = irunon + runon*dt
      igrai  = igrai + graidt*dt
      igird  = igird + gird*dt
