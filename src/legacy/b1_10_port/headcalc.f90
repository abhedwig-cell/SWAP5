! TO DO
! module MOD_solve_Richards met public subroutine headcalc
!
! aangeven per variabelel: lokaal, input, output
! sommige globale variabelen mogelijk alleen voor headcalc?
!

! ----------------------------------------------------------------------
subroutine headcalc(worker) 
! ----------------------------------------------------------------------
!     date               : April 2005 / Sept 2005
!     purpose            : calculate pressure heads, water contents,
!                          and conductivities for next time step
! ----------------------------------------------------------------------
   ! input
   use MOD_swap_base,      only: swmacro, i_instance
   use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_initialize_worker
   use MOD_arrays,         only: macp, mabbc
   use MOD_params,         only: nihil
   use MOD_grid,           only: numnod, z, dz, disnod
   use MOD_MvG,            only: watcon, hconduc, moiscap, dhconduc, cofgen
   use MOD_top,            only: q0, flrunoff, ftoph
   use MOD_meteo,          only: nraidt
   use MOD_macropore,      only: macropore
   use MOD_rootextraction, only: RootExtraction
   use MOD_snow,           only: melt
   use MOD_frost,          only: rfcp
   use MOD_top,            only: boundtop, pondrunoff, hsurf
   use MOD_drain,          only: qdra, nrlevs
   use MOD_irrigation,     only: qssdi, nird
   use variables,          only: fldaystart, swbotb, runon, epd, reva, pondm1, dt, runots, t1900, thetm1, qrot,      &
                                 swkimpl, swkmean, hplate, swbotb3impl, swbotb3resvert, deepgw, rimlay,              &
                                 sw4, qbotab, fldtmin, maxit, maxbacktr, critdevh2cp, critdevh1cp, critdevponddt,    &
                                 dtmin, nodgwl, gwlm1, hm1, CritDevBalCp, CritDevBalTot
   ! inout
   use variables,          only: h, theta, kmean, gwlinp, pond, dtold, qtop, qbot, hbot, itnumb
   ! output
   use variables,          only: fllowgwl, k, dimoca, numbit, fldecdt, gwl     ! note: K not always up-to-date at t+Dt

   ! macropore
   use MOD_swap_mp,        only: armpss, frarmtrx, qexcmpmtx, dfdhmp, ictopmp                        ! all input
   use MOD_swap_mp,        only: qmplatss, idecmprat                                                 ! input + output
   use MOD_swap_mp,        only: fldecmprat, fldecMPmbf                                              ! output
   implicit none

   type(a23bu_worker_context_t), target, intent(inout), optional :: worker

!  local
   type(a23bu_worker_context_t), target, save :: legacy_worker
   type(a23bu_worker_context_t), pointer :: ctx
   logical :: canonical_trial
   integer                          :: i, j, itry,  MaxIt1, NN, iBackTr, ierror
   real(8), dimension(macp)         :: dFdhL, dFdhM, dFdhU     ! elements of Lower, Main and Upper diagonals in coeffcient matrix
   real(8), dimension(macp)         :: difh, F                 ! arrays in solution procedure
   real(8), dimension(macp)         :: sink, source            ! sink/source terms in Richards equation
   real(8), dimension(macp)         :: hold
   real(8), dimension(macp+1)       :: qv, hgrad
   real(8)                          :: factor, Fmax
   real(8)                          :: factmax, factmax1, sump, sum1, sumold, deviat, q1
   logical                          :: flnonconv, flnonconv3
   logical, dimension(macp)         :: flnonconv1, flnonconv2
   logical, dimension(3)            :: flunsatok               ! Flag indicating the performance of the iteration process
   logical                          :: flboth, flok
   character(len=200)               :: message
   character(len=19)                :: datetime
   character(len=10)                :: cval

!  macropore related
   real(8)                          :: QMpLatSsSav

!  functions
   real(8)                          :: hcomean

!  criteria
   real(8), parameter               :: Critdz = 1.0d-5

!---------------------------------------------------------------------

   canonical_trial = present(worker)
   if (canonical_trial) then
      ctx => worker
   else
      ctx => legacy_worker
   end if
   if (ctx%active_nodes /= numnod) call a23bu_initialize_worker(ctx, numnod)
   ctx%diagnostics%headcalc_calls = ctx%diagnostics%headcalc_calls + 1

!  reset some variables at the start of a new day
   if (fldaystart) then
      ctx%history%flwarn = .TRUE.
      ctx%history%iwarn  = 0
   end if
 
!  summation of sink terms (constant for the current time step)
   iBackTr        = 0
   flunsatok(1:3) = .FALSE.
   do i = 1, numnod
      sink(i) = 0.0d0
      do j = 1, nrlevs
         sink(i) = sink(i) + qdra(j,i)
      end do
   end do 
   source(1:numnod) = qssdi(1:numnod)

!  special case: groundwater level specified
   if (swbotb == 1) then
      fllowgwl = .FALSE.
      if (gwlinp >= z(1)-1.0d-4) then

         q0 = (nraidt+nird+melt)*(1.0d0-ArMpSs) + runon - reva - epd
         call pondrunoff ()
         q1 = - q0 + (pond - pondm1)/dt + runots/dt
         theta(1) = watcon(1,gwlinp)
         kmean(1) = hconduc(1,gwlinp,theta(1),rfcp(1))
!        in case of static macropores FrArMtrx < 1
         if (swmacro == 1) kmean(1) = FrArMtrx(1) * kmean(1)

         qv(1) = q1
         do i = 1, numnod
            qv(i+1) = qv(i) + dz(i)*FrArMtrx(i)*(theta(i)-thetm1(i)) / dt + sink(i) - source(i) + qrot(i) 
         end do
         qbot = qv(numnod+1)
         h(1) = gwlinp + disnod(1)*(qv(1)/kmean(1) + 1.0d0)
         do i = 2, numnod
            h(i) = h(i-1) + disnod(i)*(qv(i)/kmean(i) + 1.0d0)    ! gaat dit goed: immers kmean(i) nog behorend bij oude tijd???, maar K(1) werd wel eerst opnieuw berekend
         end do

!        special case: SwKimpl = 1
         if (SwKimpl == 1) then
            do i = 1, numnod
               k(i) = hconduc(i,h(i),theta(i),rfcp(i))
               if (swmacro == 1)  k(i) = FrArMtrx(i) * k(i)
               if (i > 1) then
                  kmean(i)=hcomean(swkmean,k(i-1),k(i),dz(i-1),dz(i), i, h(i-1), h(i))
               end if
            end do
            kmean(numnod+1) = k(numnod)                  
         end if
         !call calcgwl () replaced to call soilwater(3)
!        ready
         return

      else
         NN = 0
         do while (z(NN+1) > gwlinp .AND. NN < numnod)
            NN = NN + 1
         end do
         if (z(NN+1) < (gwlinp+nihil)) then
!           groundwater within soil profile
            if ((z(NN)-gwlinp) < 1.0d-4 .AND. (NN > 0)) then
!              difference gwlinp with node to small to calculate gradient properly
               gwlinp = z(NN)
               NN     = NN-1
            end if
         else
!           groundwater below soil profile
            fllowgwl = .TRUE.
            hbot     = gwlinp - z(numnod) + 0.5d0*dz(numnod)
         end if
      end if

   else
!     for all other swbotb cases
      NN = numnod
      if (swbotb == 9) NN = numnod - 1
   end if

!  reset conductivities (k, kmean) to time level t
   do i = 1, numnod
      k(i) = hconduc(i,h(i),theta(i),rfcp(i))
!
      if (swmacro == 1)  k(i)     = FrArMtrx(i) * k(i)
      if (i > 1)         kmean(i) = hcomean(swkmean,k(i-1),k(i),dz(i-1),dz(i), i, h(i-1), h(i))
   end do
   kmean(numnod+1) = k(numnod)

!  lower and upper diagnal elements
   if (SwKimpl == 0) then
      dFdhU = 0.0d0
      dFdhL = 0.0d0
      do i = 2, numnod
         dFdhU(i)   = - kmean(i)  /disnod(i)
         dFdhL(i-1) = dFdhU(i)
      end do
   end if

!  gradient in h
   do i = 2, NN
      hgrad(i) = (h(i-1)-h(i))/disnod(i) + 1.0d0
   end do

!  calculate vector F (first time)
   F = 0.0d0
   call vector_F(1, hgrad)

!  initial estimate of F inner product
   sumold = 0.5d0 * dot_product(F(1:NN), F(1:NN))

!  start iteration loop, MaxIt specified in the input
   MaxIt1 = MaxIt
   if (fldtmin .OR. fldecmprat) MaxIt1 = 2*MaxIt
   sump = 0.d0
   do numbit = 1, MaxIt1
      ctx%diagnostics%nonlinear_iterations = ctx%diagnostics%nonlinear_iterations + 1

!     store hold and get moiscap
      do i = 1, NN
         hold(i)   = h(i)
         dimoca(i) = moiscap(i, h(i))
      end do

!     special case: SwKimpl = 1
      if (SwKimpl == 1) then
         do i = 1, NN
            ctx%headcalc%dkdh(i)= dhconduc(i,h(i),theta(i),dimoca(i),rfcp(i))
            if (swmacro == 1) ctx%headcalc%dkdh(i) = FrArMtrx(i) * ctx%headcalc%dkdh(i)
         end do
         do i = 2, NN
            dFdhU(i)   = - kmean(i) / disnod(i)
            dFdhL(i-1) = dFdhU(i)
         end do
      end if

!     incorporate Jacobian information in coefficient matrix elements
      ctx%diagnostics%jacobian_builds = ctx%diagnostics%jacobian_builds + 1
      call jacobian_F()

!     solve the tridiagonal matrix
      ctx%diagnostics%linear_solves = ctx%diagnostics%linear_solves + 1
      call tridag(NN, dFdhU, dFdhM, dFdhL, F, difh, ierror)

!     in the rare case that TRIDAG fails, use alternative solution
      if (ierror /= 0) then
         call dtdpst ('year-month-day', t1900+1.001d0, datetime)
         write(cval,'(I10)') i_instance
         message = cval//' Tri-band matrix in HeadCalc appeared to be singular at '//adjustl(trim(datetime))//' Alternative SOLVER chosen'
         if (.NOT.canonical_trial) call swap_warning ('headcalc', message)
         ctx%diagnostics%alternative_solver_calls = ctx%diagnostics%alternative_solver_calls + 1
         call alternative_solver()
      end if

!     back tracking cycle
      factor = 1.0d0
      do itry = 1, MaxBackTr
         iBackTr = iBackTr + 1
         ctx%diagnostics%backtracking_attempts = ctx%diagnostics%backtracking_attempts + 1
!        factor reduces the change of h (difh) calculated as a full Newton Raphson step

!        update h
         if (fldtmin .AND. numbit > MaxIt) then              
            factmax = 0.0d0
            do i = 1, NN
               if (dabs(hold(i) ) < 1.0d0 ) then
                  factmax = max(factmax, dabs(difh(i))) 
               else
                  factmax = max(factmax, dabs(difh(i) / hold(i)))
               end if
            end do
            factmax1 = min(1.0d0, 1.0d0 / factmax)
            do i = 1, NN
               h(i) = hold(i) - difh(i) * factmax1
            end do
         else
            do i = 1, NN
               h(i) = hold(i) - factor * difh(i)
            end do
         end if

!        update theta
         do i = 1, NN
           theta(i) = watcon(i,h(i))
         end do

!        update gradient in h
         do i = 2, NN
            hgrad(i) = (h(i-1)-h(i))/disnod(i) + 1.0d0
         end do

!        special case: update k and kmean if SwKimpl = 1
         if (SwKimpl == 1) then
            call Rootextraction(2)
            do i = 1, NN
               k(i) = hconduc(i,h(i),theta(i),rfcp(i))
               if (swmacro == 1) k(i) = FrArMtrx(i) * k(i)
               if (i > 1) then
                  kmean(i) = hcomean(swkmean, k(i-1), k(i), dz(i-1), dz(i), i, h(i-1), h(i))
               end if
            end do
            kmean(NN+1) = k(NN)
         end if

!        re-calculate F-function
         call vector_F(2, hgrad)

!        calculate maximum deviation per compartment and new inner product
         sump = 0.5d0 * dot_product(F(1:NN), F(1:NN))
         sum1 = sum(F(1:NN))
         Fmax = maxval(dabs(F(1:NN)))

!        test for iteration progress, if Newton-step is too large: reduce dh by multiplication factor
         if (sump < sumold .OR. Fmax < CritDevBalCp) goto 1
         factor = factor / 3.0d0

      end do
 1    continue

!     check on convergence of solution

!     initialize flags
!     main flag for testing the convergence
      flnonconv = .FALSE.

!     flags introduced for debugging purposes
      flnonconv1(1:numnod) = .FALSE.
      flnonconv2(1:numnod) = .FALSE.
      flnonconv3 = .FALSE.

!     apply performance criteria per compartment
      do i = 1, NN

!        test for water balance deviation of soil compartments
         if (dabs(F(i)) >  CritDevBalCp) then
            flnonconv1(i) = .TRUE.
            flnonconv     = .TRUE.
         end if

!        test for change of pressure head
         if (dabs(hold(i)) < 1.0d0) then
            if (abs(h(i)-hold(i) ) > CritDevh2Cp) then
               flnonconv2(i) = .TRUE.
               flnonconv     = .TRUE.
            end if
         else
            if (abs(h(i)-hold(i) )/abs(hold(i)) > CritDevh1Cp) then
               flnonconv2(i) = .TRUE.
               flnonconv     = .TRUE.
            end if
         end if
    
      end do

!     test for waterbalance of ponding layer
      if (ftoph) then
         qtop = -kmean(1)*((hsurf - h(1))/disnod(1) + 1.0d0)
         if (.NOT.flnonconv .AND. (swmacro == 0 .OR. IcTopMp > 1)) then
            deviat = pond - pondm1 + epd*dt + reva*dt - (nraidt+nird+Melt)*dt - runon*dt + runots - qtop * dt
            if (abs(deviat) > CritDevPondDt) then
               flnonconv3 = .TRUE.
               flnonconv  = .TRUE.
            end if
         end if
      end if

!     in case of macropores
      if (swmacro == 1 .AND. IcTopMp == 1) then
         deviat = pond - pondm1 + epd*dt + reva*dt - (nraidt+nird+Melt)*dt - runon*dt + runots - qtop * dt + ArMpSs * (nraidt+nird+Melt)*dt + QMpLatSs
         if (abs(deviat) > CritDevPondDt) then
            flnonconv3 = .TRUE.
            flnonconv  = .TRUE.
         end if
      end if
      if (swmacro == 1 .AND. fldecMPmbf) then
         flnonconv = .TRUE.
      end if
      

!     implemented to improve iteration performance in case of macropores
      if (dt <  0.01d0 .AND. swmacro == 1 .AND. .NOT.flnonconv3) then 
         flok = .TRUE.
         if (dt > 10.d0*dtmin) then
            do i = 1, nodgwl
               if (h(i) > 0.0d0 .AND. flnonconv1(i) .AND. flnonconv2(i)) flok = .FALSE.
            end do
         else
            continue
         end if
         if (flok) then
            if (.NOT.flunsatok(1)) then
               flunsatok(1) = .TRUE.
            else if (.NOT. flunsatok(2)) then
               flunsatok(2) = .TRUE.
            else
               flunsatok(3) = .TRUE.                 
            end if
         else
            flunsatok(1:3) = .FALSE.
         end if
      end if

      if (dabs(sum1) > CritDevBalTot) flnonconv = .TRUE.

!     save sump voor next iteration
      sumold = sump

      if (.NOT.flnonconv) then      ! convergence has been reached
     
!        special case for macropores
         if (swmacro == 1) then
            FlDecMpRat = .FALSE.
            if (IDecMpRat > 0) then
               if (ctx%history%nstep < 10) then
                  ctx%history%nstep = ctx%history%nstep + 1
               end if
               if (dt > dtold .OR. ctx%history%nstep >= 10) then
                  dtold = dt
                  ctx%history%nstep = 0
                  IDecMpRat = IDecMpRat - 1
               end if
            end if
         end if

!        special case swbotb = 1
         if (swbotb == 1 .AND. (.NOT.fllowgwl)) then
!           derive vertical flux profile in order to find qbot as a lower boundary condition for the saturated part of the soil system
            qv(1) = qtop
            do i = NN+1, numnod
               theta(i) = cofgen(2,i)
            end do
            do i = 1, numnod
              qv(i+1) = qv(i) + dz(i)*FrArMtrx(i)*(theta(i)-thetm1(i)) / dt + sink(i) - source(i) + qrot(i)
            end do
            qbot = qv(numnod+1)
!           h in saturated zone
            do i = NN+1, numnod
               h(i) = h(i-1) + disnod(i)*(qv(i)/kmean(i) + 1.0d0)
            end do
         end if
   
!        calculate new groundwater level
         !call calcgwl () replaced to call soilwater(3)

!        recording of number of iteration steps needed
         itnumb(min(100,numbit),1) = itnumb(min(100,numbit),1) + 1 
         itnumb(min(100,numbit),2) = itnumb(min(100,numbit),2) + iBackTr 

         ctx%control%last_numbit = numbit
         return
         
      end if
   ! end do numbit = 1, MaxIt1
   end do

!  Convergence could not been reached
   if (.NOT.fldtmin) then

!     reset soil state variables
      do j = 1, numnod
         h(j)     = hm1(j)
         theta(j) = thetm1(j)
      end do
      kmean(numnod+1) = k(numnod)
      gwl             = gwlm1
      pond            = pondm1

!     reset and continue iteration with smaller timestep!
      fldecdt = .TRUE.
      ctx%control%request_dt_reduction = .TRUE.
      ctx%diagnostics%internal_retries = ctx%diagnostics%internal_retries + 1

      return  

   else if (swmacro == 1 .AND. IDecMpRat < 3) then
!     in case of macropores, retry with reduction of exchange fluxes with matrix
      IDecMpRat  = IDecMpRat + 1
      ctx%diagnostics%internal_retries = ctx%diagnostics%internal_retries + 1
      FlDecMpRat = .TRUE.
      dtold      = dt
      fldtmin    = .FALSE.

      return         

   else
!     write warning to screen and log file
      if (ctx%history%flwarn) then
         ctx%history%iwarn = ctx%history%iwarn + 1
         call dtdpst('year-month-day,hour:minute:seconds',t1900,datetime)
         write(cval,'(I10)') i_instance
         message = cval//' No convergence was reached of Richards equation at '//datetime//' no more than 4 warnings per date - SWAP did continue!'
         if (.NOT.canonical_trial) call swap_warning ('headcalc', message)
         if (ctx%history%iwarn > 3) ctx%history%flwarn = .FALSE.  
      end if

!     continue without convergence !!!
      return

   end if

contains

!----------------------------------------------------------------------------------
! Alternative solution procedure in the rare case that TRIDAG failed.
!
! From Numerical Recipes, section 2.4:
! There is no pivoting in TRIDAG. It is for this reason that TRIDAG can fail
! (pause) even when the underlying matrix is nonsingular. In that case, 
! you can instead use the more general method for band diagonal systems,
! by using routines bandec and banbks, as is implemented here.
!----------------------------------------------------------------------------------
   subroutine alternative_solver()
   ! local
   integer                    :: i
   integer, dimension(macp)   :: indx
   real(8), dimension(macp,3) :: a 
   real(8), dimension(macp,1) :: a1
   real(8), dimension(macp)   :: b
   real(8)                    :: d

   do i = 1, NN
      a(i,1) = dFdhU(i)
      a(i,2) = dFdhM(i)
      a(i,3) = dFdhL(i)
   end do
   call bandec(a, NN, 1, 1, macp, 3, a1, 1, indx, d)
   b(1:NN) = F(1:NN)
   call banbks(a,nn,1,1,macp,3,a1,1,indx,b)
   difh(1:NN) = b(1:NN)
   return
   end subroutine alternative_solver

!----------------------------------------------------------------------------------
! Function F: calculate right-hand-side vector F
!----------------------------------------------------------------------------------
subroutine vector_F(iTask, hgrad)
!  global
   integer, intent(in)        :: iTask
   real(8), dimension(macp+1) :: hgrad
!  local
!  functions
   real(8)                    :: afgen

!  top layer
   F(1) = (theta(1) - thetm1(1)) * FrArMtrx(1) * dz(1) / dt + sink(1) - source(1) + qrot(1) + kmean(2) * hgrad(2)

!  depending on iTask
   if (iTask == 2 .AND. swmacro == 1) QMpLatSsSav = QMpLatSs

!  take care of top BC
   call boundtop(2)

!  depending on iTask
   if (swmacro == 1) then
      if (iTask == 1 .OR. .NOT. flunsatok(3)) then 
         call MACROPORE(2)
      else
         QMpLatSs = QMpLatSsSav
      end if
   end if

!  take care of top BC: ponding, runoff
   if (FlRunoff .OR. ArMpSs > 0.0d0) call pondrunoff ()

!  first layer, continued
   if (ftoph) then
      hgrad(1) = (hsurf-h(1))/disnod(1) + 1.d0
      F(1)     = F(1) - kmean(1) * hgrad(1)
   else
      F(1) = F(1) + qtop
   end if

!  layers 2 to (NN-1)
   do i = 2, NN-1
      F(i) = (theta(i) - thetm1(i)) * FrArMtrx(i) * dz(i) / dt + sink(i) - source(i) + qrot(i) - kmean(i) * hgrad(i) + kmean(i+1) * hgrad(i+1)
   end do

!  for bottom BC
   if (swbotb == 1 .AND. (.NOT.fllowgwl)) then
      hgrad(NN+1) = h(NN)/(z(nn)-gwlinp) + 1.0d0
   else if (swbotb == 5 .OR. (swbotb == 1 .AND. fllowgwl)) then
      hgrad(NN+1) = (h(NN) - hbot) / disnod(NN+1) + 1.0d0
   else if (swbotb == 9) then
      hgrad(NN+1) = (h(NN) - h(NN+1)) / disnod(NN+1) + 1.0d0
   end if

!  for swbotb = 8, depending on iTask
   if (iTask == 1) then
      if (swbotb == 8 .AND. h(NN) >  Critdz - disnod(NN+1) + hplate) then
         hgrad(NN+1) = (h(NN) - hplate) / disnod(NN+1) + 1.0d0
         flboth = .TRUE.
      else
         flboth = .FALSE.
      end if
   else
      if (swbotb == 8 .AND. flboth) then
         hgrad(NN+1) = (h(NN) - hplate) / disnod(NN+1) + 1.0d0
      end if
   end if

   ! for bottom BC, continued
   if (swbotb == 1 .AND. (.NOT.fllowgwl)) then
      theta(NN) = watcon(NN,h(NN))
      k(NN)     = hconduc(NN,h(NN),theta(NN),rfcp(NN))
      ! in case of static macropores FrArMtrx < 1
      if (swmacro == 1) k(NN) = FrArMtrx(NN) * k(NN)
      kmean(NN+1) = hcomean(swkmean, k(NN), cofgen(3,(NN+1)), dz(NN), dz(NN+1), NN, h(NN), 0.0d0)
      F(NN)       = (theta(NN) - thetm1(NN))*FrArMtrx(NN)*dz(NN)/dt - kmean(NN) * hgrad(NN) + kmean(NN+1) * hgrad(NN+1) + sink(NN) - source(NN) + qrot(NN)
   else
      F(NN) = (theta(NN) - thetm1(NN))*FrArMtrx(NN)*dz(NN)/dt - kmean(NN) * hgrad(NN) + sink(NN) - source(NN) + qrot(NN) 
      if (swbotb == 3 .AND. swbotb3Impl == 1) then
         
         ! Cauchy-relation, implemented as head boundary
         if (SwBotb3ResVert == 0) then
            qbot = - (h(NN)+z(NN)-deepgw) / (disnod(NN+1)/kmean(NN+1)+rimlay)
         else if (SwBotb3ResVert == 1) then
            qbot = - (h(NN)+z(NN)-deepgw) / rimlay
         end if
         
         ! extra groundwater flux might be added
         if (sw4 == 1) qbot = qbot + afgen(qbotab,mabbc*2,t1900+dt)
         F(NN) = F(NN) - qbot     
      
      else if (swbotb == 5 .OR. (swbotb == 1 .AND. fllowgwl)) then
         
         ! pressure head at lower boundary specified
         F(NN) = F(NN) + kmean(NN+1) * hgrad(NN+1)

      else if (swbotb == 9) then
         
         ! pressure head at lower boundary specified
         F(NN) = F(NN) + kmean(NN+1) * hgrad(NN+1)
         !!!F(NN) = F(NN) - qbot
      
      else if (swbotb == 7 .OR. swbotb == -2) then 
         
         ! free drainage option
         kmean(numnod+1) = hconduc(numnod,h(numnod),theta(numnod),rfcp(numnod))
         if (swmacro == 1) kmean(numnod+1) = FrArMtrx(numnod) * kmean(numnod+1)
         qbot = -1.0d0 * kmean(numnod+1)
         F(NN) = F(NN) - qbot
      
      else if (swbotb == 8) then                                  
         
         ! lysimeter option
         if (flboth) then
            hbot = hplate
            F(NN) = F(NN) + kmean(NN+1) * hgrad(NN+1)
         else
            qbot = 0.0d0
         end if
      
      else
         
          ! flux bottom boundary
         F(NN) = F(NN) - qbot
      
      end if

   end if

   if (swmacro == 1) F(1:NN) = F(1:NN) - QExcMpMtx(1:NN)

end subroutine vector_F

subroutine jacobian_F()

!  first layer
   dFdhM(1) = dimoca(1)*FrArMtrx(1)*dz(1)/dt - dFdhL(1)
 
!  if the head boundary condition applies: add the k1/(0.5*dz1) term to the first element of the main diagonal 
   if (ftoph) dFdhM(1) = dFdhM(1) + kmean(1)/disnod(1)  

!  layers 2 to (NN-1)
   do i = 2, NN-1
      dFdhM(i) = dimoca(i)*FrArMtrx(i)*dz(i)/dt - dFdhU(i) - dFdhL(i) 
   end do

!  last layer: handle bottom BC
   dFdhM(NN) = dimoca(NN)*FrArMtrx(NN)*dz(NN)/dt - dFdhU(NN) 
   if (swbotb == 1 .AND. (.NOT.fllowgwl)) then
      dFdhM(NN) = dFdhM(NN) + kmean(NN+1)/(z(NN)-gwlinp) 
   else if (swbotb == 3 .AND. swbotb3Impl == 1) then ! Cauchy
      if (SwBotb3ResVert == 0) then
         dFdhM(NN) = dFdhM(NN) + 1.0d0 / (disnod(NN+1)/kmean(NN+1) + rimlay)   
      else if (SwBotb3ResVert == 1) then
         dFdhM(NN) = dFdhM(NN) + 1.0d0 / rimlay
      end if
   else if (swbotb == 5 .OR. (swbotb == 1 .AND. fllowgwl) .OR. swbotb == 9) then
      dFdhM(NN) = dFdhM(NN) + kmean(NN+1)/disnod(NN+1)         
   else if (swbotb == 7 .OR. swbotb == -2) then ! implicitly: kmean(NN+1)
      dFdhM(NN) = dFdhM(NN) + ctx%headcalc%dkdh(NN) * 0.5d0
   else if (swbotb == 8 .AND. flboth) then
      dFdhM(NN) = dFdhM(NN) + kmean(NN+1)/disnod(NN+1)
   end if

!  special case when SwKimpl = 1
   if (SwKimpl == 1) then
      if (swbotb == 9) call swap_error ('headcalc', 'swbotb = 9 AND swkimpl = 1 not yet implemented')
!     first layer
      dFdhM(1) = dFdhM(1) + ctx%headcalc%dkdh(1) * hgrad(2) * dkmean(swkmean,k(1),k(2),dz(1),dz(2))
      if (ftoph) dFdhM(1) = dFdhM(1) - ctx%headcalc%dkdh(1) * hgrad(1) * 0.5d0
      dFdhL(1) = dFdhL(1) + ctx%headcalc%dkdh(2) * hgrad(2) * dkmean(swkmean,k(2),k(1),dz(2),dz(1)) 
!     layers 2 to (NN-1)
      do i = 2, NN-1
         dFdhU(i) = dFdhU(i) - ctx%headcalc%dkdh(i-1) * hgrad(i) * dkmean(swkmean,k(i-1),k(i),dz(i-1),dz(i)) 
         dFdhM(i) = dFdhM(i) - ctx%headcalc%dkdh(i) * hgrad(i) * dkmean(swkmean,k(i),k(i-1),dz(i),dz(i-1)) + ctx%headcalc%dkdh(i) * hgrad(i+1) * dkmean(swkmean,k(i),k(i+1),dz(i),dz(i+1))
         dFdhL(i) = dFdhL(i) + ctx%headcalc%dkdh(i+1) * hgrad(i+1) * dkmean(swkmean,k(i+1),k(i),dz(i+1),dz(i)) 
      end do
!     last layer
      dFdhU(NN) = dFdhU(NN) - ctx%headcalc%dkdh(NN-1) * hgrad(NN) * dkmean(swkmean,k(NN-1),k(NN),dz(NN-1),dz(NN)) 
      dFdhM(NN) = dFdhM(NN) - ctx%headcalc%dkdh(NN) * hgrad(NN) * dkmean(swkmean,k(NN),k(NN-1),dz(NN),dz(NN-1))

      if (swbotb == 1 .OR. swbotb == 5 .OR. swbotb == 8 .AND. flboth) then
         dFdhM(NN) = dFdhM(NN) + 0.5d0 * ctx%headcalc%dkdh(NN) * hgrad(NN+1)
      end if
   end if

!  special case macropore
   if (swmacro == 1 .AND. .NOT.flunsatok(3)) then
      call MACROPORE(3)
      dFdhM(1:NN) = dFdhM(1:NN) - dFdhMp(1:NN)
   end if

end subroutine jacobian_F


      function dkmean(swkmean,kmain,ksub,dzmain,dzsub)
!     d(hcomean)/d(kmain); note kmain = kup in hcomean and ksub = klow in hcomean; dzmain = dzup in hcomena, and dzub = dzlow in hcomean
      implicit none
      ! global
      integer, intent(in)  :: swkmean
      real(8), intent(in)  :: kmain, ksub, dzmain, dzsub
      real(8)              :: dkmean
      ! local
      real(8)              :: a

      if (swkmean == 1) then
         dkmean = 0.5d0
      else if (swkmean == 2) then
         dkmean = dzmain/(dzmain+dzsub)
      else if (swkmean == 3) then
         dkmean = 0.5d0 * dsqrt(ksub / kmain)
      else if (swkmean == 4) then
         a = dzmain/(dzmain+dzsub)
         dkmean = a * (ksub / kmain) ** (1.0d0 - a)
      else if (swkmean == 5) then
         dkmean = 0.5d0/(((0.5d0/kmain)+(0.5d0/ksub))**2 * kmain**2)
      else if (swkmean == 6) then
         a = dzmain/(dzmain+dzsub)
         dkmean = a/(((a/kmain)+((1.0d0-a)/ksub))**2 * kmain**2)
      end if
      return
      end function dkmean

end subroutine headcalc
