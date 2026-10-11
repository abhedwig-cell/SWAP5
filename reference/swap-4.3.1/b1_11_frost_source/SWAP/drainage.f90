!submodule (MOD_drain) SMOD_drainage_basic

!   contains

! ----------------------------------------------------------------------
      subroutine drainage 
! ----------------------------------------------------------------------
!     Purpose            : calculate basic drainage rate variables 
! ----------------------------------------------------------------------
      use MOD_grid,   only: numnod
      use variables,  only: gwl, t1900
      use MOD_drain,  only: qdrain, nrlevs, qdra, qdrtot, swdivd, ksatcp, divdra
      implicit none

! --- Local
      integer              :: level
      character(len=19)    :: datetime
! ----------------------------------------------------------------------

! --- Reset fluxes to zero if groundwater level under soil profile and return
      if (gwl > 998.0d0) then
         qdrain(1:nrlevs)        = 0.0d0
         qdra(1:nrlevs,1:numnod) = 0.0d0   
         qdrtot                  = 0.0d0
         return
      end if

! --- Calculate total drainage rate and state variables
      call drainflux_basic()

! --- Partition drainage flux over compartments
      if (swdivd == 1) then
         call divdra(ksatcp,gwl)
      else
         do level = 1,nrlevs
            qdra(level,numnod) = qdrain(level)
         end do
      end if

! --- Aggregate fluxes to total drainwater exchange
      qdrtot = 0.0d0
      do level=1,nrlevs
         qdrtot = qdrtot + qdrain(level)
      end do
      
! --- Check for consistency in drainage water balance
      if (dabs(sum(qdra(1:nrlevs,1:numnod)) - qdrtot) > 1.d-5) then
         call dtdpst ('year-month-day', t1900+1.001d0, datetime)
         call swap_warning ('drainage_basic', 'Individual drain fluxes do not add up to total drain exchange at time '//adjustl(trim(datetime))//'.')
      end if

      return
      end subroutine drainage

! ----------------------------------------------------------------------
      subroutine drainflux_basic ()
! ----------------------------------------------------------------------
!     Purpose            : calculate lateral drainage fluxes
! ----------------------------------------------------------------------  
      use parameters,    only: pi
      use MOD_swap_base, only: swmacro
      use MOD_swap_mp,   only: NumLevRapDra,ZDraBas, swdrrap
      use variables,     only: gwl, t1900, dt
      use MOD_drain,     only: dramet, qdrtab, zbotdr, shape, basegw, lspacing, qdrain, diffl, khtop, entres, wetper, zintf, khbot, kvtop, kvbot, &
                               nrlevs, owltab, nowltab, geofac, drainl, swdtyp, swnrsrf, cofintfl, expintfl, drares, swallo, swliminf, infres, ipos
      implicit none

! --- Local
      real(8)               :: afgen
      integer               :: i,lev
      real(8)               :: zimp,dbot,totres,x,fx,eqd,rver,rhor,rrad
! ----------------------------------------------------------------------

! --- Drainage flux from table with gwlevel - flux data pairs
      if (dramet == 1) then
         
         qdrain(1) = afgen (qdrtab, 50, abs(gwl))
         
! --- Drainage flux calculated according to Hooghoudt or Ernst
      else if (dramet == 2) then
         
         diffl(1) = (gwl-zbotdr(1)) / shape

         ! Contributing layer below drains limited to 1/4 L
         zimp = max (basegw,zbotdr(1)-0.25d0*Lspacing(1))
         dbot = (zbotdr(1)-zimp)  
         if (dbot < 0.0d0) call swap_error ('drainflux_basic', 'At the drainage section, the level of the impervious layer is higher than the level of the drain bottom. Adapt drain input!')
              
         ! No infiltration allowed
         if (diffl(1) < 1.0d-10) then
            qdrain(1) = 0.0d0
            return
         end if

! ---    CASE 1: homogeneous, on top of impervious layer
         if (ipos == 1) then
            
            totres = Lspacing(1)*Lspacing(1)/(4.d0*khtop*abs(diffl(1))) + entres

! ---    CASE 2,3: in homogeneous profile or at interface of 2 layers
         else if (ipos == 2 .OR. ipos == 3) then

            ! Calculation of equivalent depth
            x = 2.d0 * pi * dbot / Lspacing(1)
            if (x > 0.5d0) then
               fx = 0.0d0
               do i = 1,5,2
                  fx = fx + (4.d0 * exp(-2.d0 * i * x)) / (i * (1.0d0 - exp(-2.d0 * i * x)))
               end do
               eqd = pi * Lspacing(1) / 8.d0 / (log(Lspacing(1) / wetper) + fx)
            else
               if (x < 1.0d-6) then
                  eqd = dbot
               else
                  fx = pi**2 / (4.d0 * x) + log(x / (2.d0 * pi))
                  eqd = pi * Lspacing(1) / 8.d0 / (log(Lspacing(1) / wetper) + fx)
               end if
            end if 
            if (eqd > dbot) eqd = dbot

            ! Calculation of drainage resistance
            if (ipos == 2) then
               totres = Lspacing(1) * Lspacing(1) / (8.d0 * khtop * eqd + 4.d0 * khtop * abs(diffl(1))) + entres 
            else if (ipos == 3) then
               totres = Lspacing(1) * Lspacing(1)/(8.d0 * khbot * eqd + 4.d0 * khtop * abs(diffl(1))) + entres
            end if

! ---    CASE 4: drain in bottom layer
         else if (ipos == 4) then
            
            if (zbotdr(1) > zintf) call swap_error ('drainflux_basic', 'At the drainage section, the level of the impervious layer is higher than the level of the drain bottom. Adapt drain input!')
            rver = max(gwl - zintf, 0.0d0) / kvtop + (min(zintf, gwl) - zbotdr(1)) / kvbot
            rhor = Lspacing(1) * Lspacing(1) / (8.d0 * khbot * dbot) 
            rrad = Lspacing(1) / (pi * dsqrt(khbot*kvbot)) * log(dbot / wetper)
            totres = rver + rhor + rrad + entres

! ---    CASE 5: drain in top layer
         else if (ipos == 5) then
            
            if (zbotdr(1) < zintf) call swap_error ('drainflux_basic', 'At the drainage section, the level of the impervious layer is higher than the level of the drain bottom. Adapt drain input!')
            rver = (gwl-zbotdr(1))/kvtop
            rhor = Lspacing(1) * Lspacing(1) / (8.d0 * khtop * (zbotdr(1) - zintf) + 8.d0 * khbot * (zintf - zimp))
            rrad = Lspacing(1) / (pi * dsqrt(khtop * kvtop)) * log((geofac * (zbotdr(1) - zintf)) / wetper)
            totres = rver + rhor + rrad + entres
            
         end if

         ! Drainage flux for all cases
         qdrain(1) = diffl(1)/totres 

! --- Drainage flux calculation using given drainage/infiltration resistance; multilevel
      else if (dramet == 3) then
         
         do lev = 1,nrlevs

            ! Water level in drain and head difference
            drainl(lev) = afgen(owltab(lev, 1:2 * nowltab(lev)), 2 * nowltab(lev), t1900 + dt - 1.d0)
            if (drainl(lev) < zbotdr(lev)) drainl(lev) = zbotdr(lev)
            diffl(lev) = gwl - drainl(lev)
            
            ! Drainage basis for rapid drainage through macropores
            if (swmacro == 1) then
               if (swdrrap == 1) then
                  if (lev == numlevrapdra .AND. swdtyp(lev) == 2) then
                     zdrabas = drainl(lev)
                  end if
               end if
            end if

! ---       Drainage              
            if (diffl(lev) >= 0.0d0) then

               if ((lev == nrlevs) .AND. (swnrsrf == 1)) then ! Interflow
                  qdrain(lev) = cofintfl * diffl(lev)**expintfl              
               else
                  qdrain(lev) = diffl(lev) / drares(lev)
               end if
               
               if (swallo(lev) == 2) qdrain(lev) = 0.0d0

! ---       Infiltration
            else

               ! Limit the infiltration head (-dh, dh<0. here) to the waterdepth in the channel
               if (swdtyp(lev) == 2 .AND. swliminf == 1) then
                  diffl(lev) = max(diffl(lev), (zbotdr(lev) - drainl(lev)))
               end if

               qdrain(lev) = diffl(lev) / infres(lev)
               
               if (swallo(lev) == 3 .OR. zbotdr(lev) >= drainl(lev)) qdrain(lev) = 0.0d0
            end if
            
         end do
      end if

      return
      end subroutine drainflux_basic
   
! ----------------------------------------------------------------------
      subroutine read_drainage_basic()
! ----------------------------------------------------------------------
!     Purpose            : read input data for basic drainage    
! ----------------------------------------------------------------------
      use MOD_arrays,    only: maho, madr, maowl
      use MOD_swap_base, only: iun_min2, iun_max2, pathdrain, unit_err, swmacro, swsolu
      use MOD_swap_mp,   only: swdrrap, numlevrapdra, zdrabas
      use MOD_grid,      only: numlay, layer, numnod
      use variables,     only: t1900, ksatexm, ksatfit, fluseksatexm
      use MOD_drain,     only: dramet, qdrtab, zbotdr, shape, basegw, lspacing, khtop, entres, wetper, zintf, khbot, kvtop, kvbot, nrlevs, owltab,    &
                                nowltab, geofac, swdtyp, swnrsrf, cofintfl, expintfl, drares, swallo, swliminf, infres, ipos, drfil, swdivd, ksatcp,  &
                                cofani, swdivdinf, facdpthinf, swdislay, swtopdislay, ztopdislay, ftopdislay, swtopnrsrf
      implicit none

! --- Local
      integer            :: unit_dra
      integer            :: ifnd, i, ilevel, node
      real(8)            :: datowl(maowl), level(maowl), qdrain_in(25), gwl_in(25)
      character(len=80)  :: filnam
      character(len=200) :: message
      character(len=5)   :: clev
      character(len=15)  :: cvar
      logical            :: file_exists
      logical            :: rdinqr, rdinar
      real(8)            :: afgen
      integer            :: getun2
! ----------------------------------------------------------------------

! --- Open file with drainage data
      filnam = trim(pathdrain)//trim(drfil)//'.dra'
      inquire(file = filnam, exist = file_exists)
      if (.NOT. file_exists) then
         message ='File '//trim(filnam)//' does not exists!'
         call swap_error ('readswap', message)
      end if        
      unit_dra = getun2 (iun_min2, iun_max2, 2)
      call rdinit(unit_dra,unit_err,filnam)

! --- Method to establish drainage/infiltration fluxes
      call rdsinr ('dramet',1,3,dramet) 
      if (dramet == 3) call rdsinr ('nrlevs',1,Madr,nrlevs)

! --- Division of drainage fluxes
      call rdsinr ('swdivd',0,1,swdivd)
      if (swdivd == 0 .AND. swsolu > 0) then ! No proper representation of lateral fluxes for solute transport
          write(message,'(3a)') ' Variabel SWDIVD=0 and SWSOLU>0 in input file :',trim(filnam),' this yields incorrect results for solute transport'
          call swap_error ('read_drainage', message)
      end if
      if (swdivd == 0) then
          write(message,'(3a)') ' Variabel SWDIVD=0 in input file : ',trim(filnam), ' this is not recommended and may cause numerical instability'
          call swap_warning ('read_drainage', message)
      end if
      if (swdivd == 1) then     
         ! Initialize ksatcp and read cofani for use in divdra
         do node = 1,numnod
            if (fluseksatexm(node) .AND. swmacro == 0) then
               ksatcp(node) = ksatexm(layer(node))
            else
               ksatcp(node) = ksatfit(layer(node))
            end if
         end do
         
         if (rdinar('cofani')) then
            call rdfdor ('cofani',1.d-4,1000.d0,cofani,maho,numlay)
         else
            call rdsdor ('cofani',1.d-4,1000.d0,cofani(1)); if (numlay > 1) cofani(2:numlay) = cofani(1)
         end if
         
         ! Divide infiltration fluxes different compared to drainage
         if (rdinqr('swdivdinf')) call rdsinr ('swdivdinf',0,1,swdivdinf)
         if (swdivdinf == 1) then 
            call rdsdor ('FacDpthInf',0.d0,1.d0,FacDpthInf)
            if (dramet /= 3) then ! No infiltration for dramet == 2, no definition of 'diffl' for dramet == 1
               write(message,'(3a,i3)') ' Variabel SWDIVDINF=1 and DRAMET not 3 in inputfile :',trim(filnam),' this option is not allowed for drainage method (dramet)= ',dramet
               call swap_error ('read_drainage', message)
            end if
         end if
         
         ! Adjust top of model dicharge layer, determined by factor or direct input
         call rdsinr ('swdislay',0,2,swdislay)
         if (swdislay == 1) then
            call rdfinr ('swtopdislay',0,1,swtopdislay,madr,nrlevs)
            call rdfdor('ztopdislay',-1.0d4,0.0d0,ztopdislay,madr,nrlevs)
         else if (swdislay == 2) then
            if (dramet == 1) then ! No definition of 'diffl'
               write(message,'(3a,i3)') ' Variabel SWDISLAY=2 and DRAMET=1 in input file :',trim(filnam),' this is not allowed for drainage method (dramet)= ',dramet
               call swap_error ('read_drainage', message)
            end if
            call rdfinr ('swtopdislay',0,1,swtopdislay,madr,nrlevs)
            call rdfdor('ftopdislay',0.0d0,1.0d0,ftopdislay,madr,nrlevs)
         end if
      end if
      
! --- Input table of drainage flux as function of groundwater level
      if (dramet == 1) then  
         if (swdivd == 1) then
            call rdsdor ('lm1',1.0d0,1000.d0,Lspacing(1))
            Lspacing(1) = 100.0d0*Lspacing(1)
         end if
         call rdador ('gwl',-10000.0d0,10.0d0,gwl_in,25,ifnd)
         call rdfdor ('qdrain',-100.d0,1000.0d0,qdrain_in,25,ifnd)

         do i = 1,ifnd
            qdrtab(i*2-1) = abs(gwl_in(i))
            qdrtab(i*2) = qdrain_in(i)
         end do

         ! In case of rapid drainage due to macropore flow: read zbotdr
         if (swmacro == 1) then
            if (swdrrap == 1) then
               call rdsinr ('swdtyp' ,1,2,swdtyp(1))
               call rdsdor ('zdrabas',-1000.0d0,0.0d0,zbotdr(1))
            end if
         end if

! --- Input drainage formula of Hooghoudt or Ernst
      else if (dramet == 2) then
   
         ! Read drain characteristics
         call rdsdor ('lm2',1.0d0,1000.0d0,Lspacing(1))
         Lspacing(1) = 100.0d0*Lspacing(1)
         call rdsdor ('shape',1.0d-6,1.0d0,shape)
         call rdsdor ('wetper',0.0d0,1000.0d0,wetper)
         call rdsdor ('zbotdr',-1000.0d0,0.0d0,zbotdr(1))
         call rdsdor ('entres',0.0d0,1000.0d0,entres)

         ! Read profile characteristics
         call rdsinr ('ipos',1,5,ipos)
         call rdsdor ('basegw',-1.0d4,0.0d0,basegw)
         call rdsdor ('khtop',0.0d0,1000.0d0,khtop)

         if (ipos >= 3) then
            call rdsdor ('khbot',0.0d0,1000.0d0,khbot)
            call rdsdor ('zintf',-1.0d4,0.0d0,zintf)
         end if
         if (ipos >= 4) then
            call rdsdor ('kvtop',0.0d0,1000.0d0,kvtop)
            call rdsdor ('kvbot',0.0d0,1000.0d0,kvbot)  
         end if
         if (ipos == 5) then
            call rdsdor ('geofac',0.0d0,100.0d0,geofac)
         end if

! --- Drainage and infiltration resistance
      else if (dramet == 3) then

         ! Highest drainage level calculated as interflow?
         call rdsinr ('swintfl',0,1,swnrsrf) 
         if (swnrsrf == 1) then
            call rdsdor ('cofintflb',0.01d0,10.0d0,cofintfl)     
            call rdsdor ('expintflb',0.1d0,1.0d0,expintfl) 
         end if

         ! Adjust top of discharge layer in case of interflow?
         if (swdivd == 1) then
            if (swnrsrf == 1)  call rdsinr ('SwTopnrsrf',0,1,SwTopnrsrf)
         end if

         ! Drainage information for each level
         do ilevel = 1, nrlevs
            write(clev,'(I5)') ilevel; clev = adjustl(clev)
            cvar = 'drares'//trim(clev); call rdsdor (trim(cvar), 1.0d0, 1.0d5, drares(ilevel))
            cvar = 'infres'//trim(clev); call rdsdor (trim(cvar), 0.0d0, 1.0d5, infres(ilevel))
            cvar = 'swallo'//trim(clev); call rdsinr (trim(cvar), 1,     3,     swallo(ilevel))
            if (swdivd == 1) then
               cvar = 'l'//trim(clev); call rdsdor (trim(cvar), 1.0d0, 1.0d5, Lspacing(ilevel))
               Lspacing(ilevel) = 100.0d0*Lspacing(ilevel)
            end if
            cvar = 'zbotdr'//trim(clev); call rdsdor (trim(cvar), -1.0d4, 0.0d0, zbotdr(ilevel))
            cvar = 'swdtyp'//trim(clev); call rdsinr (trim(cvar),  1,     2,     swdtyp(ilevel))
            ! Always read surface water levels to allow adaptive drainage
            cvar = 'datowl'//trim(clev); call rdatim (trim(cvar),                  datowl,  maowl, ifnd)
            cvar =  'level'//trim(clev); call rdfdor (trim(cvar), -1.0d4, 200.0d0, level,   maowl, ifnd)
            ! Store values in table
            do i = 1, ifnd
               owltab(ilevel,i*2)   = level(i)
               owltab(ilevel,i*2-1) = datowl(i)
            end do
            nowltab(ilevel) = ifnd
         end do
         
         if (swallo(nrlevs) == 2 .AND. swnrsrf == 1) then
            write(message,'(i3)') 'swnrsrf == 1 whilst no drainage is allowed from drainage system nr', nrlevs, '.'
            call swap_error('read_drainage',message)
         end if

         ! Limit infiltration to head difference in channel / drain
         if (rdinqr('swliminf')) then
            call rdsinr ('swliminf',0,1,swliminf)
         end if 
      end if 

! --- Initialize drainage base ZDraBas for rapid drainage in case of macropores
      if (swmacro == 1) then
         if (swdrrap == 1) then
            if (NumLevRapDra > nrlevs) call swap_error('read_drainage','NUMLEVRAPDRA greater then NRLEVS')
            if (dramet < 3) then
               ZDraBas = zbotdr(1)
            else
               if (swdtyp(NumLevRapDra) == 1) then ! Drain
                  ZDraBas = zbotdr(NumLevRapDra)
               else ! Open water
                  ZDraBas = afgen(owltab(NumLevRapDra,1:2*nowltab(NumLevRapDra)),2*nowltab(NumLevRapDra),t1900)
               end if
            end if
         end if
      end if     
      
      close (unit_dra)         

      return
      end subroutine read_drainage_basic

!end submodule SMOD_drainage_basic
