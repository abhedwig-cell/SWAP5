module MOD_MvG

   use MOD_arrays, only: macp, maho, mcof
   use MOD_grid,   only: numnod

   ! from MOD_RIA
   use DoublePrec,   only: dp
   use MOD_RIA,      only: WCRIA, SingleKcomponents, RIAderivative, RIAKDerivativeFromState, RIAStencilCrossesBoundary
   use SHPvariables, only: iLayer

   implicit none

   integer, dimension(maho),               save :: iHWCKmodel     ! indicator what type of water retention and hydraulic conductivity model is used (per soil layer)
                                                                  !     1 = MvG (default)
                                                                  !     2 = exponential
                                                                  !     3 = MvG bi-modal
                                                                  !     4-11: 8 versions of PDI model
                                                                  !  other types may be added in the future

   integer,                                save :: swsophy        ! Switch for input of soil hydraulica properties as function parameters (0) or as table (1)
   integer,                                save :: sw_use_elas    ! switch indicating yes (1) or not (0) use user-supplied elastcicity value

   real(8), parameter                           :: h_crit         = -1.0d-2
   real(8), parameter                           :: hconode_vsmall =  1.0d-10
   real(8), dimension(mcof,macp), target,  save :: cofgen  = 0.0d0            ! Array soil hydraulic parameters according to Mualem - van Genuchten for each soil layer
   real(8), dimension(mcof,maho),          save :: paramvg = 0.0d0            ! Array with input values of soil hydraulic parameters according to Mualem - van Genuchten for each soil layer

   real(8), dimension(:),         pointer, save :: wcr, wcs, alfamg, alfamgwet, n, m, ksatfit, lambda, h_enpr, h_power, k_power, ksatexm, relsatthr, ksatthr, elas
   real(8), dimension(:),         pointer, save :: alfa_2, n_2, m_2, omega_1
   real(8), dimension(:),         pointer, save :: wcsMINwcr, wc_crit, c_crit, s_enpr, term_105_a, term_105_ab
   real(8), dimension(:),         pointer, save :: alfanm, nMIN1, mPLUS1, oneOVERm, n2mlambda, lambdaPLUS2, mMIN1, lambdaMIN1
   real(8), dimension(:),         pointer, save :: alfanm_2, nMIN1_2, mPLUS1_2, oneOVERm_2

   ! SWAP-011: lazy constitutive-state cache for hydraulic model 3.
   ! hconduc stores quantities it already needs for K(h). dhconduc reuses them
   ! only when the cached head is exactly the current head; otherwise it falls
   ! back to the uncached reference expressions. No dK/dh is evaluated eagerly.
   logical, dimension(macp), save :: m3_cache_valid = .false.
   real(8), dimension(macp), save :: m3_cache_head = 0.0d0
   real(8), dimension(macp), save :: m3_cache_s1 = 0.0d0, m3_cache_s2 = 0.0d0
   real(8), dimension(macp), save :: m3_cache_base1 = 0.0d0, m3_cache_base2 = 0.0d0
   real(8), dimension(macp), save :: m3_cache_a1 = 0.0d0, m3_cache_a2 = 0.0d0
   real(8), dimension(macp), save :: m3_cache_scomb = 0.0d0, m3_cache_q = 0.0d0
   ! SWAP-011: lazy constitutive-state cache for hydraulic model 12.
   ! hconduc stores state already produced by SingleKcomponents. dhconduc uses
   ! it only for the same node/head/temperature and only inside a smooth RIA
   ! branch. Boundary crossings and stale state retain the reference finite
   ! difference.
   logical, dimension(macp), save :: m12_cache_valid = .false.
   real(8), dimension(macp), save :: m12_cache_head = 0.0d0, m12_cache_temp = 0.0d0
   real(dp), dimension(macp), save :: m12_cache_kliq = 0.0_dp, m12_cache_kvap = 0.0_dp
   real(dp), dimension(macp), save :: m12_cache_theta_raw = 0.0_dp, m12_cache_kvap_t = 0.0_dp

   logical,                                save :: fl_use_kh_power

   real(8), dimension(macp),               save :: h_enpr_global     ! Soil water Entry Pressure head for Modified MualemVanGenuchten curve (L)

   ! for tabulated input
   integer, dimension(:),     allocatable, save ::    numtab         ! Number of table entries of soil physical values for each model compartment
   integer, dimension(:),     allocatable, save ::    numtablay      ! Number of table entries of soil physical values for each soil layer
   integer, dimension(:,:),   allocatable, save ::    ientrytab      ! Soil Physical functions (h,theta,k,dthetadh,dkdtheta) tabulated for each model compartment
   integer, dimension(:,:),   allocatable, save ::    ientrytablay   ! Soil Physical functions (h,theta,k,dthetadh,dkdtheta) tabulated for each soil layer
   real(8), dimension(:,:,:), allocatable, save ::    sptab          ! Soil Physical functions (h,theta,k,dthetadh,dkdtheta) tabulated for each model compartment
   real(8), dimension(:,:,:), allocatable, save ::    sptablay       ! Soil Physical functions (h,theta,k,dthetadh,dkdtheta) tabulated for each soil layer

   ! new tabulated MvG input
   real(8),           dimension(:,:), allocatable, save ::  wc_intercept,   wc_slope
   real(8),           dimension(:,:), allocatable, save :: cap_intercept,  cap_slope
   real(8),           dimension(:,:), allocatable, save :: con_intercept,  con_slope
   integer,                                        save :: n_entries
   logical,                                        save :: fl_use_tables
   real(8),           parameter                         :: fact_100 = 100.0d0

   private
   public :: swsophy, cofgen, paramvg, iHWCKmodel, sw_use_elas, h_enpr_global
   public :: numtab, numtablay, ientrytab, ientrytablay, sptab, sptablay
   public :: fl_use_tables, wc_intercept, wc_slope, cap_intercept, cap_slope, con_intercept, con_slope, n_entries, fl_use_kh_power
   public :: calc_cofgen_extra, fill_cofgen, set_cofgen_pointers
   public :: watcon, moiscap, hconduc, dhconduc, prhead
   public :: hconode_vsmall

   contains

      subroutine fill_cofgen
         use doln
         use MOD_arrays, only: matabentries
         use MOD_grid,   only: layer, numlay, nod1lay

         use variables,  only: ksatfit, thetsl, fluseksatexm, thetar, thetas

         implicit none
         ! local
         integer :: node, i, j, lay, imod

! ---    Soil physics: tabulated or MualemVanGenuchten functions
         call set_cofgen_pointers
         if (swsophy == 1) then
            cofgen = 0.0d0
!           tabulated functions (h,theta,k,dthetadh,dkdtheta) tabulated
            do node = 1,numnod
               numtab(node) = numtablay(layer(node))
               do i=0,matabentries
                  ientrytab(node,i) = ientrytablay(layer(node),i) 
               end do
            end do
            do node = 1,numnod
               do i = 1,7
                  do j = 1, numtab(node)
                     sptab(i,node,j) = sptablay(i,layer(node),j)
                  end do
               end do
!              assign values to cofgen
               cofgen(1,node) = 0.0d0                          ! thetar
               cofgen(2,node) = sptab(2,node,numtab(node))     ! thetas
               cofgen(3,node) = sptab(3,node,numtab(node))     ! ksat
               if (do_ln_trans) cofgen(3,node) = dexp(cofgen(3,node))
            end do
            do lay = 1,numlay
               ksatfit(lay) = cofgen(3,nod1lay(lay))
               thetsl(lay) = cofgen(2,nod1lay(lay))
            end do
         else
!           MvanG functions 
            do node = 1,numnod
               lay = layer(node)
               cofgen(1:12,node) = paramvg(1:12,lay)
               if (cofgen(10,node) > cofgen(3,node)) fluseksatexm(node) = .TRUE.
               imod = iHWCKmodel(lay)
               if (imod ==  3 .OR. imod ==  6 .OR. imod ==  7 .OR. imod == 10 .OR. imod == 11)  cofgen(13:17,node) = paramvg(13:17,lay)
               if (imod ==  5 .OR. imod ==  7)                                                  cofgen(18,node)    = paramvg(18,lay)
               if (imod ==  8 .OR. imod ==  9 .OR. imod == 10 .OR. imod == 11)                  cofgen(18:21,node) = paramvg(18:21,lay)
                     cofgen(22:24,node) = paramvg(22:24,lay)
            end do
            thetsl(1:numlay) = paramvg(2,1:numlay)
         end if

! ---    saturated and residual watercontent of each node
         thetar(1:numnod) = cofgen(1,1:numnod)
         thetas(1:numnod) = cofgen(2,1:numnod)

         if (swsophy == 0) call calc_cofgen_extra(numnod)

      end subroutine fill_cofgen

      subroutine calc_cofgen_extra(node)
         use variables,  only: indeks
         ! global
         integer, intent(in)  :: node
         ! local
         integer              :: i, i1, i2
         real(8)              :: h105, t105, c105, a, b, alfa

         if (node < 0) then
            ! a single (node) calculation is to be performed
            i1 = -node
            i2 = -node
         else
            ! calculation for all (1:node) nodes
            i1 = 1
            i2 = node
         end if

         do i = i1, i2
            if (indeks(i) == -1) then
              alfa = cofgen(4,i)
            else 
              alfa = cofgen(8,i)
            end if

            cofgen(25,i) = cofgen(2,i) - cofgen(1,i)                 ! wcs - wcr
            ! wc_crit and c_crit
            cofgen(26,i) = cofgen(1,i) + cofgen(25,i) / ((1.0d0 + (dabs(alfa*h_crit))**cofgen(6,i))**cofgen(7,i))
            ! s_enpr
            cofgen(27,i) = (cofgen(2,i) - cofgen(26,i))/(-h_crit)
            cofgen(28,i) = (1.0d0 + (dabs(alfa*cofgen(9,i)))**cofgen(6,i))**(-cofgen(7,i))
            ! alpha*n*m, (n-1), (m+1), (1/m), n*(2+m*lambda), (2+lambda), (m-1), (lambda-1)
            cofgen(29,i) = cofgen(6,i)*cofgen(7,i)*alfa
            cofgen(30,i) = cofgen(6,i) - 1.0d0
            cofgen(31,i) = cofgen(7,i) + 1.0d0
            cofgen(32,i) = 1.0d0/cofgen(7,i)
            cofgen(33,i) = cofgen(6,i)*(2.0d0 + cofgen(7,i)*cofgen(5,i))
            cofgen(34,i) = cofgen(5,i) + 2.0d0
            cofgen(35,i) = cofgen(7,i) - 1.0d0
            cofgen(36,i) = cofgen(5,i) - 1.0d0
            ! alpha_2*n_2*m_2, (n_2-1), (m_2+1), (1/m_2)
            cofgen(37,i) = cofgen(14,i)*cofgen(15,i)*cofgen(13,i)
            cofgen(38,i) = cofgen(14,i) - 1.0d0
            cofgen(39,i) = cofgen(15,i) + 1.0d0
            if (cofgen(15,i) > 0.0d0) then
               cofgen(40,i) = 1.0d0/cofgen(15,i)
            else
               cofgen(40,i) = 0.0d0
            end if

            ! constants in polynome extension near h_enpr
            if (cofgen(9,i) < 0.0d0) then
               h105 = 1.05d0 * cofgen(9,i)
               t105 = cofgen(1,i) + (cofgen(2,i)-cofgen(1,i)) *                                   &
                      ((1.0d0 + (dabs(alfa*h_enpr(i)))**cofgen(6,i))**cofgen(7,i)) /              &
                      ((1.0d0 + (dabs(alfa*h105))**cofgen(6,i))**cofgen(7,i))
               c105 = (cofgen(2,i)-cofgen(1,i)) * alfa * cofgen(7,i) * cofgen(6,i) *              &
                      (dabs(alfa * h105)**(cofgen(6,i) - 1.0d0)) *                                &
                      ((1.0d0 + dabs(alfa * h_enpr(i))**cofgen(6,i))**cofgen(7,i)) /              &
                      ((1.0d0 + dabs(alfa * h105)**cofgen(6,i))**(cofgen(7,i) + 1.0d0))
               a = (t105 - cofgen(2,i) - c105*h105) / (c105*h105**2)
               b = (t105**2 - 2.0d0*t105*cofgen(2,i) + cofgen(2,i)**2)/(t105 - cofgen(2,i) - C105*h105)
            else
               a = 0.0d0
               b = 0.0d0
            end if
            cofgen(41,i) = a
            cofgen(42,i) = a*b

         end do

      end subroutine calc_cofgen_extra

      subroutine set_cofgen_pointers

         wcr(1:numnod)         => cofgen(1,1:numnod)
         wcs(1:numnod)         => cofgen(2,1:numnod)
         ksatfit(1:numnod)     => cofgen(3,1:numnod)
         alfamg(1:numnod)      => cofgen(4,1:numnod)
         lambda(1:numnod)      => cofgen(5,1:numnod)
         n(1:numnod)           => cofgen(6,1:numnod)
         m(1:numnod)           => cofgen(7,1:numnod)
         alfamgwet(1:numnod)   => cofgen(8,1:numnod)
         h_enpr(1:numnod)      => cofgen(9,1:numnod)
         ksatexm(1:numnod)     => cofgen(10,1:numnod)
         relsatthr(1:numnod)   => cofgen(11,1:numnod)
         ksatthr(1:numnod)     => cofgen(12,1:numnod)
         alfa_2(1:numnod)      => cofgen(13,1:numnod)
         n_2(1:numnod)         => cofgen(14,1:numnod)
         m_2(1:numnod)         => cofgen(15,1:numnod)
         omega_1(1:numnod)     => cofgen(16,1:numnod)
         h_power(1:numnod)     => cofgen(22,1:numnod)
         k_power(1:numnod)     => cofgen(23,1:numnod)
         elas(1:numnod)        => cofgen(24,1:numnod)

         wcsMINwcr(1:numnod)   => cofgen(25,1:numnod)
         wc_crit(1:numnod)     => cofgen(26,1:numnod)
         c_crit(1:numnod)      => cofgen(27,1:numnod)
         s_enpr(1:numnod)      => cofgen(28,1:numnod)

         alfanm(1:numnod)      => cofgen(29,1:numnod)
         nMIN1(1:numnod)       => cofgen(30,1:numnod)
         mPLUS1(1:numnod)      => cofgen(31,1:numnod)
         oneOVERm(1:numnod)    => cofgen(32,1:numnod)
         n2mlambda(1:numnod)   => cofgen(33,1:numnod)
         lambdaPLUS2(1:numnod) => cofgen(34,1:numnod)
         mMIN1(1:numnod)       => cofgen(35,1:numnod)
         lambdaMIN1(1:numnod)  => cofgen(36,1:numnod)
         alfanm_2(1:numnod)    => cofgen(37,1:numnod)
         nMIN1_2(1:numnod)     => cofgen(38,1:numnod)
         mPLUS1_2(1:numnod)    => cofgen(39,1:numnod)
         oneOVERm_2(1:numnod)  => cofgen(40,1:numnod)

         term_105_a(1:numnod)  => cofgen(41,1:numnod)
         term_105_ab(1:numnod) => cofgen(42,1:numnod)

      end subroutine set_cofgen_pointers

!-----------------------------------------------------------------------
      real(8) function watcon (node,head)
! ----------------------------------------------------------------------
!     UpDate             : 20090630
!     Date               : 20060208
!     Purpose            : calc. water content from pressure head HEAD
!     Subroutines called : -
!     Functions called   : -                                           
!     File usage         : -
! ----------------------------------------------------------------------
      use MOD_grid,  only: layer
      use MOD_swap_base, only: swhyst
      use variables, only: indeks, fhyst
      use doln
      use WC_K_models_04_11, only: functionvalue_04_11
      implicit none

! --- global 
      integer, intent(in)  :: node
      real(8), intent(in)  :: head

! --- local
      integer              :: imod, i_entry
      real(8)              :: help, h105, dum, lochead
      real(8)              :: moiscap, alfa
! ----------------------------------------------------------------------
      if (swsophy == 0) then

         if (fl_use_tables) then
            if (head >= 0.0d0) then
               watcon = wcs(node)
            else if (head > h_crit) then
               watcon = wc_crit(node) + c_crit(node)*(head-h_crit) 
               watcon = min(watcon,wcs(node)) 
            else
              if (head > -1.0d0) then
                i_entry = min(n_entries, 1 + int(fact_100*dabs(head)))
              else
                i_entry = min(n_entries, 101 + int(fact_100*log10(dabs(head))))
              end if
              watcon = wc_intercept(i_entry, layer(node)) + wc_slope(i_entry, layer(node)) * dabs(head)
            end if
            return  ! ready
         end if

         imod = iHWCKmodel(layer(node))
         if (imod == 2) then
            ! exponential relationships; special for testing against analytical solutions
            watcon = dmax1(1.0000001*wcr(node), wcr(node) + wcsMINwcr(node)*dexp(alfamg(node)*head))
            
         else if (imod == 3) then
            ! bi-modal MvG relationships; basic form without air-entry h_enpr or h_crit
            if (head < 0.0d0) then
               watcon = omega_1(node)/(1.0d0+(dabs(alfamg(node)*head))**n(node))**m(node)
               watcon = watcon + (1.0d0-omega_1(node))/(1.0d0+(dabs(alfa_2(node)*head))**n_2(node))**m_2(node)
               watcon = wcr(node) + wcsMINwcr(node)*watcon
            else
               watcon = wcs(node)
            end if

         else if (imod > 3 .AND. imod < 12) then
            watcon = functionvalue_04_11 (1, node, iHWCKmodel, cofgen, head)    ! 1st arg means wc; 4th + 5th args not needed)
         else if (imod == 12) then
            iLayer = layer(node)
            watcon = dble(WCRIA(head*1.0_dp))
            
         else  ! use default MvG
         
            if (head >= 0.0d0) then
! ---   saturated moisture content
              if (sw_use_elas == 1) then
                watcon = wcs(node) + head * elas(node)
              else
                watcon = wcs(node)
              end if
            else
              if (indeks(node) == 1) then
                alfa = alfamgwet(node)
              else
                alfa = alfamg(node)
              end if

              if (h_enpr(node) > h_crit) then
                if (head > h_crit) then
                  watcon = wc_crit(node) + c_crit(node)*(head-h_crit) 
                  watcon = min(watcon,wcs(node))  
                else 
                  help = dabs(alfa*head)**n(node)
                  help = (1.0d0 + help)**m(node)
                  watcon = wcr(node) + wcsMINwcr(node)/help 
                end if
              else
                h105 = 1.05d0 * h_enpr(node)
                if (head >= h105) then
                  watcon = wcs(node) + term_105_ab(node)*head/(1.0d0+term_105_a(node)*head)
                else 
                  help = dabs(alfa*head)**n(node)
                  help = (1.0d0 + help)**m(node)
                  watcon = wcr(node)+wcsMINwcr(node)/(help * s_enpr(node))
                end if
              end if
            end if
            if (swhyst /= 0) then
              if (indeks(node) == 1) then
                watcon = wcs(node) + fhyst(node) * (watcon - wcs(node))
              else
                watcon = wcr(node) + fhyst(node) * (watcon - wcr(node))
              end if              
            end if
         end if

!     Use tabulated function. 
      else if (swsophy == 1) then
         dum = head
         if (do_ln_trans .AND. head < 0.0d0) dum = -dlog(-head+1.0d0)
         if (head >= -1.0d-9) then
            watcon = sptab(2,node,numtab(node))
         else if (dum < sptab(1,node,1)) then
            watcon = sptab(2,node,1)
         else
           lochead = head
            call EvalTabulatedFunction(0,numtab(node),1,2,4,node,sptab,ientrytab,lochead,watcon,moiscap,1)
         end if
      end if
      return
      end function watcon

! ----------------------------------------------------------------------
      real(8) function moiscap (node,head)
! ----------------------------------------------------------------------
!     UpDate             : 20090630
!     Date               : 20060208
!     Purpose            : calculate the differential moisture         
!                          capacity (as a function of pressure head)
!     Subroutines called : -                                           
!     Functions called   : watcon                                     
!     File usage         : -                                           
! ----------------------------------------------------------------------
      use MOD_grid,  only: layer
      use MOD_swap_base, only: swhyst
      use variables, only: dt, indeks, fhyst
      use doln
      use WC_K_models_04_11, only: functionvalue_04_11

      implicit none

! --- global 
      integer, intent(in)  :: node
      real(8), intent(in)  :: head

! --- local
      integer              :: imod, i_entry
      real(8)              :: alphah, h105, term1, term2, dum, lochead, dummy
! ----------------------------------------------------------------------

!     Use analytical expression. 
      if (swsophy == 0) then

         if (fl_use_tables) then
            if (head >= 0.0d0) then
              moiscap = dt * 1.0d-7
            elseif  (head > h_crit) then
              moiscap = max(c_crit(node), dt * 1.0d-7)
            else 
              if (head > -1.0d0) then
                i_entry = min(n_entries, 1 + int(fact_100*dabs(head)))
              else
                i_entry = min(n_entries, 101 + int(fact_100*log10(dabs(head))))
              end if
              moiscap = cap_intercept(i_entry, layer(node)) + cap_slope(i_entry, layer(node)) * dabs(head)
              if (head > -1.0d0 .AND. moiscap < (dt * 1.0d-7)) moiscap = dt * 1.0d-7
            end if
            return  ! ready
         end if

         imod = iHWCKmodel(layer(node))
         if (imod == 2) then
            ! exponential relationships; special for testing against analytical solutions
            moiscap = alfamg(node)*wcsMINwcr(node)*dexp(alfamg(node)*head)
            
         else if (imod == 3) then
            ! bi-modal MvG relationships; basic form without air-entry h_enpr or h_crit
            if (head < 0.0d0) then
               moiscap = omega_1(node)*alfanm(node)*(dabs(alfamg(node)*head))**nMIN1(node) * (1.0d0+(dabs(alfamg(node)*head))**n(node))**(-mPLUS1(node))
               moiscap = moiscap + (1.0d0-omega_1(node))*alfanm_2(node)*(dabs(alfa_2(node)*head))**nMIN1_2(node) * (1.0d0+(dabs(alfa_2(node)*head))**n_2(node))**(-mPLUS1_2(node))
               moiscap = wcsMINwcr(node) * moiscap
            else
               moiscap = 0.0d0
            end if

         else if (imod > 3 .AND. imod < 12) then
            moiscap = functionvalue_04_11 (3, node, iHWCKmodel, cofgen, head)    ! 1st arg means c; 4th + 5th args not needed)
         else if (imod == 12) then
            iLayer = layer(node)
            moiscap = dble(RIAderivative(head*1.0_dp))

         else  ! use default MvG

            if (head >=  0.0d0) then
              if (sw_use_elas == 1) then
                  moiscap = elas(node)
              else
                  moiscap = dt * 1.0d-7
              end if
            else 
              if (indeks(node) == 1) then
                alphah = dabs(alfamgwet(node)*head)
              else
                alphah = dabs(alfamg(node)*head)
              end if
              if (h_enpr(node) > h_crit) then
                if (head > h_crit) then
                  moiscap = c_crit(node)
                else
                  term1 = alphah**nMIN1(node)
                  term2 = wcsMINwcr(node) / ((1.0d0 + term1 * alphah)**mPLUS1(node))
                  moiscap = alfanm(node) * term2 * term1
                end if
              else
                h105 = 1.05d0 * h_enpr(node)
                if (head >= h105) then
                  moiscap = term_105_ab(node)/((1.0d0+term_105_a(node)*head)**2)
                else
                  term1 = alphah**nMIN1(node)
                  term2 = (1.0d0 + term1 * alphah)**mPLUS1(node)
                  term2 = wcsMINwcr(node) / term2
! --- For modified VanGenuchten model:
                  moiscap = alfanm(node)*term2*term1/s_enpr(node)
                end if 
              end if  
              if (head > -1.0d0 .AND. moiscap < (dt * 1.0d-7)) moiscap = dt * 1.0d-7
            end if
         end if

!     Use tabulated function. 
      else if (swsophy == 1) then
         dum = head
         if (do_ln_trans .AND. head < 0.0d0) dum = -dlog(-head+1.0d0)
         if (head >= -1.0d-9) then
            moiscap = dt*1.0d-7
         else if (dum < sptab(1,node,1)) then
            moiscap = 0.0d0
         else
           lochead = head
            call EvalTabulatedFunction(0,numtab(node),1,2,4,node,sptab,ientrytab,lochead,dummy,moiscap,3)
         end if
      end if

 !    In case of hysteresis multiply with fhyst     
      if (swhyst /= 0) then
        moiscap = fhyst(node) * moiscap
      end if

      return
      end function moiscap

! ----------------------------------------------------------------------
      real(8) function hconduc (node,head,theta,rfcp)
! ----------------------------------------------------------------------
!     Update             : 20090630
!     Date               : 19990929
!     Purpose            : calculate hydraulic conductivity (as a     
!                          function of THETA)
!     Subroutines called : -
!     Functions called   : -
!     File usage         : -
! ----------------------------------------------------------------------
      use doln
      
      use MOD_grid,  only: layer
      use MOD_swap_base, only: swfrost, swmacro
      use variables, only: fluseksatexm, indeks
      use MOD_SoilTemperature, only: tsoil
      use WC_K_models_04_11, only: functionvalue_04_11

      implicit none

! --- global 
      integer, intent(in)  :: node
      real(8), intent(in)  :: head,theta,rfcp

! --- local
      integer              :: imod, i_entry
      real(8)              :: term1,term2,relsat,dummy,lochead,s1,s2,se ! ,relsatm,relsat1,thetam
      real(8)              :: m3_base1,m3_base2,m3_a1,m3_a2,m3_scomb,m3_denom,m3_q
      real(dp)             :: K, m12_kliq, m12_kvap, m12_theta_raw, m12_kvap_t
! ----------------------------------------------------------------------
      if (swsophy == 0) then

         if (fl_use_tables) then
            relsat = (theta - wcr(node)) / wcsMINwcr(node)
            if (head < -1.0d14) then
               hconduc = hconode_vsmall
               return
            end if
            if (relsat > (1.0d0-1.0d-6)) then
               hconduc = ksatfit(node)
               return ! ready
            end if
            if (head > -1.0d0) then
               i_entry = min(n_entries, 1 + int(fact_100*dabs(head)))
            else
               i_entry = min(n_entries, 101 + int(fact_100*log10(dabs(head))))
            end if
            hconduc = con_intercept(i_entry, layer(node)) + con_slope(i_entry, layer(node)) * dabs(head)
            return  ! ready
         end if

         imod = iHWCKmodel(layer(node))
         
         if (imod == 2) then
            ! exponential relationships; special for testing against analytical solutions
            relsat  = (theta-wcr(node))/wcsMINwcr(node)
            hconduc = ksatfit(node)*relsat

         else if (imod == 3) then
            ! bi-modal MvG relationships; basic form without air-entry h_enpr or h_crit
            ! Retain quantities already evaluated for K for the subsequent derivative.
            relsat  = (theta-wcr(node))/wcsMINwcr(node)
            if (relsat < 1.0d0) then
               m3_base1 = 1.0d0+(dabs(alfamg(node)*head))**n(node)
               m3_base2 = 1.0d0+(dabs(alfa_2(node)*head))**n_2(node)
               s1 = m3_base1**(-m(node))
               s2 = m3_base2**(-m_2(node))
               m3_a1 = 1.0d0-s1**oneOVERm(node)
               m3_a2 = 1.0d0-s2**oneOVERm_2(node)
               term1 = omega_1(node)*alfamg(node)*m3_a1**m(node)
               term2 = (1.0d0-omega_1(node))*alfa_2(node)*m3_a2**m_2(node)
               m3_scomb = omega_1(node)*s1+(1.0d0-omega_1(node))*s2
               m3_denom = omega_1(node)*alfamg(node)+(1.0d0-omega_1(node))*alfa_2(node)
               m3_q = 1.0d0-(term1+term2)/m3_denom
               hconduc = ksatfit(node) * m3_scomb**lambda(node)
               hconduc = hconduc * m3_q**2

               m3_cache_head(node)  = head
               m3_cache_s1(node)    = s1
               m3_cache_s2(node)    = s2
               m3_cache_base1(node) = m3_base1
               m3_cache_base2(node) = m3_base2
               m3_cache_a1(node)    = m3_a1
               m3_cache_a2(node)    = m3_a2
               m3_cache_scomb(node) = m3_scomb
               m3_cache_q(node)     = m3_q
               m3_cache_valid(node) = .true.
            else
               hconduc = ksatfit(node)
               m3_cache_valid(node) = .false.
            end if
            
         else if (imod > 3 .AND. imod < 12) then
            hconduc = functionvalue_04_11 (2, node, iHWCKmodel, cofgen, head, wc=theta,temp=tsoil(node))    ! 1st arg means k)
         else if (imod == 12) then
            iLayer = layer(node)
            call SingleKcomponents(head*1.0_dp, tsoil(node)*1.0_dp, K, m12_kliq, m12_kvap, m12_theta_raw, m12_kvap_t)
            hconduc = dble(K)
            m12_cache_head(node)      = head
            m12_cache_temp(node)      = tsoil(node)
            m12_cache_kliq(node)      = m12_kliq
            m12_cache_kvap(node)      = m12_kvap
            m12_cache_theta_raw(node) = m12_theta_raw
            m12_cache_kvap_t(node)    = m12_kvap_t
            m12_cache_valid(node)     = .true.
            
         else  ! use default MvG

            relsat = (theta-wcr(node))/wcsMINwcr(node)







            if (fluseksatexm(node) .AND. relsat > relsatthr(node) .AND. swmacro == 0) then

               term1   = (relsat-relsatthr(node))/(1.0d0-relsatthr(node))
               hconduc = term1 * ksatexm(node) + (1.0d0-term1) * ksatthr(node)
            else
               if (h_enpr(node) > h_crit) then




                  if (head < -1.0d14) then
                     hconduc = hconode_vsmall
                  else if (relsat > (1.0d0-1.0d-6)) then
                     hconduc = ksatfit(node)
                  else
                     if (head > h_power(node) .OR. .NOT.fl_use_kh_power) then
                        term1   = ( 1.0d0-relsat**oneOVERm(node) )**m(node)
                        hconduc = ksatfit(node) * (relsat**lambda(node)) * (1.0d0-term1)**2
                     else
                        hconduc = k_power(node) * (dabs(h_power(node))/dabs(head))**n2mlambda(node)
                     end if
                  end if

               else
! --- For modified VanGenuchten model 
                  if (head < -1.0d14) then
                     hconduc = hconode_vsmall
                  else
                     if (head >= h_enpr(node)) then
                        hconduc = ksatfit(node)
                     else
                        if (head > h_power(node) .OR. .NOT.fl_use_kh_power) then
                           if (indeks(node) == 1) then
                             se = ((1.0d0 + dabs(alfamgwet(node) * head)**n(node))**(-m(node)) ) / s_enpr(node)
                           else
                             se = ((1.0d0 + dabs(alfamg(node) * head)**n(node))**(-m(node)) ) / s_enpr(node)
                           end if
                           term1   = (1.0d0 - (se * s_enpr(node))**oneOVERm(node))**m(node)
                           term2   = (1.0d0 - s_enpr(node)**oneOVERm(node))**m(node)
                           hconduc = ksatfit(node) * se**lambda(node) * ((1.0d0 - term1) / (1.0d0 - term2))**2
                        else
                           hconduc = k_power(node) * (dabs(h_power(node)) / dabs(head))**n2mlambda(node)
                        end if
                     end if
                  end if

               end if
               hconduc = min(hconduc,ksatfit(node))
            end if
         end if

!     Use tabulated function. "hconduc" is calculated as a function of "head"
      else if (swsophy == 1) then
         if (theta >= sptab(2,node,numtab(node))-1.0d-9) then
            hconduc = sptab(3,node,numtab(node))
            if (do_ln_trans) hconduc = dexp(hconduc)
         else if (theta <= sptab(2,node,1)+1.0d-9) then
            hconduc = sptab(3,node,1)            
            if (do_ln_trans) hconduc = dexp(hconduc)
         else
           lochead = head
            call EvalTabulatedFunction(0,numtab(node),1,3,5,node,sptab,ientrytab,lochead,hconduc,dummy,2)
         end if
      end if

! --- in case of frost conditions
      if (swfrost == 1) then
         hconduc = hconduc * rfcp + hconode_vsmall * (1.0d0 - rfcp)
      end if

      return
      end function hconduc
      
!!!function Kvap_func (WC, h, WCs, Temp)
!!!! Temp in degree Celsius
!!!real(8), intent(in)    :: WC, h, WCs, Temp
!!!real(8)                :: Kvap_func, ksi, D, Hr
!!!real(8)                :: fKvap, Da, MgRT, Rho_sv, tk
!!!real(8), parameter     :: p = 7.0d0/3.0d0
!!!! M : molecular weight of water;  kg/mol
!!!! g : gravitational acceleration; m/s2
!!!! R : universal gas constant;     J/mol/K; J = kg.m2/s2
!!!real(8), parameter     :: MgR = 0.018015d0*9.81d0/8.314d0  ! (kg/mol * m/s2) / (kg.m2/s2)
!!!real(8), parameter     :: Rho_w = 1000.0d0                 ! density of water; kg/m3
!!!
!!!if (h > 0.0d0) then
!!!   Kvap_func = 0.0d0
!!!   return
!!!end if
!!!
!!!tk        = Temp+273.15d0
!!!MgRT      = MgR/tk
!!!Da        = 2.14d-5*(tk/273.15d0)**2                                    ! diffusivity of water vapor in air; m2/s
!!!Rho_sv    = 1.0d-3*dexp(31.3716d0 - 6014.79d0/tk - 7.92495d-3*tk)/tk    ! saturated vapor density; kg/m3
!!!fKvap     = Rho_sv/Rho_w * MgRT
!!!ksi       = (WCs-WC)**p/WCs**2
!!!D         = ksi*(WCs-WC)*Da
!!!Hr        = dexp(h/100.0d0*MgRT)     ! h must be in m, thus h (cm) is idvided by 100
!!!Kvap_func = fKvap*D*Hr
!!!end function Kvap_func

! ----------------------------------------------------------------------
      real(8) function dhconduc (node,head,theta,dimocap,rfcp)
! ----------------------------------------------------------------------
!     Fast SWAP-011 candidate: analytical bimodal derivative plus direct
!     finite differences of the actual K(h) implementations, avoiding
!     redundant watcon/hconduc dispatch where possible.
! ----------------------------------------------------------------------
      use MOD_grid,      only: layer
      use MOD_swap_base, only: swfrost
      use MOD_SoilTemperature, only: tsoil
      use WC_K_models_04_11, only: functionvalue_04_11, derivativevalue_04_11, NoVap
      implicit none

      integer, intent(in)  :: node
      real(8), intent(in)  :: dimocap,theta,head,rfcp

      integer              :: imod
      real(8)              :: term0,term1,term2,term3,term4,relsat,dummy,lochead
      real(8)              :: dh_num,hplus,hminus,thetap,thetam,kplus,kminus,kzero
      real(8)              :: s1,s2,ds1,ds2,scomb,dscomb,f1,f2,df1,df2,tcond,dtcond,denom,q,dq
      real(dp)             :: kria_plus,kria_minus,kria_zero
      character(len=200)   :: message

      if (swsophy == 0) then
         imod = iHWCKmodel(layer(node))
         if (imod == 2) then
            dhconduc = alfamg(node)*ksatfit(node)*dexp(alfamg(node)*head)

         else if (imod == 3) then
            if (head >= 0.0d0) then
               dhconduc = 1.0d-12
            else if (m3_cache_valid(node) .AND. m3_cache_head(node) == head) then
               ! Lazy cache hit: derivative-only terms are evaluated now, while
               ! K-state from the preceding hconduc call is reused.
               s1 = m3_cache_s1(node)
               s2 = m3_cache_s2(node)
               ds1 = alfamg(node)*n(node)*m(node)*(alfamg(node)*dabs(head))**(n(node)-1.0d0) * &
                     m3_cache_base1(node)**(-m(node)-1.0d0)
               ds2 = alfa_2(node)*n_2(node)*m_2(node)*(alfa_2(node)*dabs(head))**(n_2(node)-1.0d0) * &
                     m3_cache_base2(node)**(-m_2(node)-1.0d0)
               scomb  = m3_cache_scomb(node)
               dscomb = omega_1(node)*ds1 + (1.0d0-omega_1(node))*ds2
               df1 = -m3_cache_a1(node)**(m(node)-1.0d0) * &
                     s1**(oneOVERm(node)-1.0d0) * ds1
               df2 = -m3_cache_a2(node)**(m_2(node)-1.0d0) * &
                     s2**(oneOVERm_2(node)-1.0d0) * ds2
               denom = omega_1(node)*alfamg(node)+(1.0d0-omega_1(node))*alfa_2(node)
               dtcond = omega_1(node)*alfamg(node)*df1 + (1.0d0-omega_1(node))*alfa_2(node)*df2
               q = m3_cache_q(node)
               dq = -dtcond/denom
               dhconduc = ksatfit(node) * ( lambda(node)*scomb**(lambda(node)-1.0d0)*dscomb*q*q + &
                            2.0d0*scomb**lambda(node)*q*dq )
            else
               ! Safe fallback: the uncached reference expressions when another hconduc
               ! call has overwritten or invalidated this node's cached state.
               s1 = (1.0d0+(dabs(alfamg(node)*head))**n(node))**(-m(node))
               s2 = (1.0d0+(dabs(alfa_2(node)*head))**n_2(node))**(-m_2(node))
               ds1 = alfamg(node)*n(node)*m(node)*(alfamg(node)*dabs(head))**(n(node)-1.0d0) * &
                     (1.0d0+(alfamg(node)*dabs(head))**n(node))**(-m(node)-1.0d0)
               ds2 = alfa_2(node)*n_2(node)*m_2(node)*(alfa_2(node)*dabs(head))**(n_2(node)-1.0d0) * &
                     (1.0d0+(alfa_2(node)*dabs(head))**n_2(node))**(-m_2(node)-1.0d0)
               scomb  = omega_1(node)*s1 + (1.0d0-omega_1(node))*s2
               dscomb = omega_1(node)*ds1 + (1.0d0-omega_1(node))*ds2
               f1 = (1.0d0-s1**oneOVERm(node))**m(node)
               f2 = (1.0d0-s2**oneOVERm_2(node))**m_2(node)
               df1 = -(1.0d0-s1**oneOVERm(node))**(m(node)-1.0d0) * &
                     s1**(oneOVERm(node)-1.0d0) * ds1
               df2 = -(1.0d0-s2**oneOVERm_2(node))**(m_2(node)-1.0d0) * &
                     s2**(oneOVERm_2(node)-1.0d0) * ds2
               denom = omega_1(node)*alfamg(node)+(1.0d0-omega_1(node))*alfa_2(node)
               tcond = omega_1(node)*alfamg(node)*f1 + (1.0d0-omega_1(node))*alfa_2(node)*f2
               dtcond = omega_1(node)*alfamg(node)*df1 + (1.0d0-omega_1(node))*alfa_2(node)*df2
               q = 1.0d0 - tcond/denom
               dq = -dtcond/denom
               dhconduc = ksatfit(node) * ( lambda(node)*scomb**(lambda(node)-1.0d0)*dscomb*q*q + &
                            2.0d0*scomb**lambda(node)*q*dq )
            end if

         else if (imod >= 5 .AND. imod <= 11) then
            dhconduc = derivativevalue_04_11(node,iHWCKmodel,cofgen,head,theta,tsoil(node),dimocap)

         else if (imod == 12) then
            if (head >= 0.0d0) then
               dhconduc = 1.0d-12
            else
               iLayer = layer(node)
               dh_num = dmax1(1.0d-7, dabs(head)*1.0d-5)
!              Retain the reference finite difference near zero, at every RIA
!              branch crossing, or if the per-node K state is stale. Only a
!              valid same-state branch-interior evaluation takes the lazy
!              analytical path.
               if (head + dh_num >= -1.0d-12 .OR. RIAStencilCrossesBoundary(head*1.0_dp,dh_num*1.0_dp) .OR. &
                   .NOT.m12_cache_valid(node) .OR. m12_cache_head(node) /= head .OR. m12_cache_temp(node) /= tsoil(node)) then
                  if (head + dh_num < -1.0d-12) then
                     hplus  = head + dh_num
                     hminus = head - dh_num
                     call SingleKcomponents(hplus*1.0_dp,tsoil(node)*1.0_dp,kria_plus)
                     call SingleKcomponents(hminus*1.0_dp,tsoil(node)*1.0_dp,kria_minus)
                     dhconduc = dble((kria_plus-kria_minus)/(2.0_dp*dh_num))
                  else
                     hminus = head - dh_num
                     call SingleKcomponents(head*1.0_dp,tsoil(node)*1.0_dp,kria_zero)
                     call SingleKcomponents(hminus*1.0_dp,tsoil(node)*1.0_dp,kria_minus)
                     dhconduc = dble((kria_zero-kria_minus)/dh_num)
                  end if
               else
                  dhconduc = dble(RIAKDerivativeFromState(head*1.0_dp, m12_cache_kliq(node), m12_cache_kvap(node), &
                               m12_cache_theta_raw(node), m12_cache_kvap_t(node)))
               end if
            end if

         else
            relsat = (theta-wcr(node))/wcsMINwcr(node)
            if (cofgen(10,node) > 0.0d0 .AND. relsat > cofgen(11,node)) then
               message = 'Linear interpolation option for examined ksat not yet implemented for implicit hydraulic conductivity (swKimpl=1) in iteration scheme'
               call swap_error ('dhconduc', message)
            end if
            if (relsat < 0.001d0) then
               dhconduc = 0.0d0
            else if (head >= 0.0d0 .OR. relsat > s_enpr(node)) then
               dhconduc = 1.0d-12
            else
               if (head > h_power(node) .OR. .NOT.fl_use_kh_power) then
                  dhconduc = dimocap / wcsMINwcr(node)
                  term0    = (s_enpr(node)*relsat)**oneOVERm(node)
                  term1    = 1.0d0 - term0
                  term2    = lambdaPLUS2(node)*term0 - lambda(node)
                  term3    = term1**mMIN1(node)
                  term4    = 1.d0 - (1.d0 - s_enpr(node)**oneOVERm(node))**m(node)
                  dhconduc = dhconduc * ksatfit(node) * relsat**lambdaMIN1(node)
                  dhconduc = dhconduc * (1.0d0 - term1**m(node))
                  dhconduc = dhconduc * (lambda(node) + term2 * term3)
                  dhconduc = dhconduc / (term4**2)
               else
                  dhconduc = k_power(node) * (dabs(h_power(node))/dabs(head))**n2mlambda(node) * n2mlambda(node) / dabs(head)
               end if
            end if
         end if

      else if (swsophy == 1) then
         if (theta >= sptab(2,node,numtab(node))-1.0d-9) then
            dhconduc = 1.0d+08
         else
            lochead = head
            call EvalTabulatedFunction(0,numtab(node),1,3,5,node,sptab,ientrytab,lochead,dummy,dhconduc,4)
         end if
      end if

      if (swfrost == 1) then
         dhconduc = dhconduc * rfcp
      end if
      return
      end function dhconduc


! ----------------------------------------------------------------------
      real(8) function prhead (node,disnod,wcon,cofgen_in,h_in)
! ----------------------------------------------------------------------
!     update             : 20090630
!     date               : 19990912
!     purpose            : calculate pressure head at nodal      
!                          point node from water content
!     description of coefficient for van Genuchten relation
!        cofgen(1,node) = ores
!        cofgen(2,node) = osat
!        cofgen(3,node) = ksatfit
!        cofgen(4,node) = alfa
!        cofgen(5,node) = lexp
!        cofgen(6,node) = npar
!        cofgen(7,node) = 1.d0 - (1.d0 / npar) = mpar
!        cofgen(8,node) = alfawet
!        cofgen(9,node) = h_enpr
!        cofgen(10,node)= ksatexm
! MH: since in routine convertdiscrvert prhead needs to be called with NEW distribution of cofgen and h,
!     cofgen_in and h_in are requied as input (and cannot be imported from variables as cofgen and h)
! ----------------------------------------------------------------------
      use MOD_arrays, only: macp, mcof
      use variables, only: indeks
      use MOD_grid,  only: layer
      use WC_K_models_04_11, only: functionvalue_04_11
      implicit none

! --- global
      integer, intent(in)  :: node
      real(8), intent(in)  :: wcon,disnod
      real(8), intent(in)  :: h_in(macp)
      real(8), intent(in)  :: cofgen_in(mcof,macp)

! --- local
      integer              :: imod, iter
      real(8)              :: s_enpr,relsat,help,dummy,prh,locwcon
      real(8)              :: thetar, thetas, alfamg, npar, mpar, h_enpr
      real(8)              :: hlow,hhigh,hmid,wclow,wcmid,omega1,alpha2,npar2,mpar2
! ----------------------------------------------------------------------

      ! since we use pars from cofgen_in, we cannot use global pointers here
      thetar = cofgen_in(1,node)
      thetas = cofgen_in(2,node)
      if (indeks(node) == 1) then
        alfamg = cofgen_in(8,node)
      else
        alfamg = cofgen_in(4,node)
      end if

      npar   = cofgen_in(6,node)
      mpar   = cofgen_in(7,node)
      h_enpr = cofgen_in(9,node)

      if (swsophy == 0) then
         imod = iHWCKmodel(layer(node))

         if (imod == 2) then
            ! exponential relationships; special for testing against analytical solutions
            relsat = (wcon-thetar)/(thetas-thetar)
            prhead = dlog(relsat)/alfamg
            
         else if (imod == 3 .OR. imod >= 5) then
            ! These models do not share the analytical inverse of default MvG.
            ! Invert their actual retention relation by robust bisection.
            if (thetas-wcon < 1.0d-6) then
               if (node == 1) then
                  prhead = disnod
               else
                  prhead = h_in(node-1) + disnod
               end if
               prhead = dmax1(prhead,0.0d0)
            else
               hhigh = 0.0d0
               if ((imod == 5 .OR. imod == 7 .OR. (imod >= 8 .AND. imod <= 11)) .AND. cofgen_in(18,node) > 0.0d0) then
                  hlow = -cofgen_in(18,node)
               else
                  hlow = -1.0d12
               end if

               if (imod == 3) then
                  omega1 = cofgen_in(16,node)
                  alpha2 = cofgen_in(13,node)
                  npar2  = cofgen_in(14,node)
                  mpar2  = cofgen_in(15,node)
                  wclow = thetar + (thetas-thetar) * &
                          (omega1/(1.0d0+dabs(alfamg*hlow)**npar)**mpar + &
                          (1.0d0-omega1)/(1.0d0+dabs(alpha2*hlow)**npar2)**mpar2)
               else if (imod >= 5 .AND. imod <= 11) then
                  wclow = functionvalue_04_11(1,node,iHWCKmodel,cofgen_in,hlow)
               else
                  iLayer = layer(node)
                  wclow = dble(WCRIA(hlow*1.0_dp))
               end if

               if (wcon <= wclow + 1.0d-10) then
                  prhead = hlow
               else
                  do iter = 1, 100
                     hmid = 0.5d0*(hlow+hhigh)
                     if (imod == 3) then
                        wcmid = thetar + (thetas-thetar) * &
                                (omega1/(1.0d0+dabs(alfamg*hmid)**npar)**mpar + &
                                (1.0d0-omega1)/(1.0d0+dabs(alpha2*hmid)**npar2)**mpar2)
                     else if (imod >= 5 .AND. imod <= 11) then
                        wcmid = functionvalue_04_11(1,node,iHWCKmodel,cofgen_in,hmid)
                     else
                        iLayer = layer(node)
                        wcmid = dble(WCRIA(hmid*1.0_dp))
                     end if
                     if (wcmid > wcon) then
                        hhigh = hmid
                     else
                        hlow = hmid
                     end if
                     if (dabs(hhigh-hlow) <= dmax1(1.0d-8,1.0d-10*dabs(hmid))) exit
                  end do
                  prhead = 0.5d0*(hlow+hhigh)
               end if
            end if

         else  ! use analytical default MvG inverse (models 1 and 4)

            if (thetas-wcon < 1.0d-6) then

! --- saturated pressure head
               if (node == 1) then
                  prhead = disnod
               else
                  prhead = h_in(node-1) + disnod
               end if
               prhead = dmax1(prhead,h_enpr)
            else
               if (wcon-thetar < 1.0d-6) then
                  prhead = -1.0d12
               else

! --- For modified VanGenuchten model:
!     - S_enpr: relative saturation at Entry Pressure h_enpr 
                  s_enpr = (abs(alfamg*h_enpr))**npar
                  s_enpr = (1.0d0 + s_enpr)**(-mpar)
                  help = (thetas - thetar) / (wcon - thetar) / s_enpr
                  help = help**(1.0d0 / mpar)
                  help = (help - 1.0d0)**(1.0d0 / npar)
                  prhead = -1.0d0 * abs(help/alfamg)
               end if
            end if
         end if

      else if (swsophy == 1) then
         if (sptab(2,node,numtab(node))-wcon < 1.0d-6) then

! --- saturated pressure head
            if (node == 1) then
              prhead = disnod
            else
              prhead = h_in(node-1) + disnod
            end if
            prhead = dmax1(prhead,0.0d0)
         else
           locwcon = wcon
            call EvalTabulatedFunction(1,numtab(node),1,2,4,node,sptab,ientrytab,prh,locwcon,dummy,1)
            prhead = prh
         end if
      end if

      return
      end function prhead

end module MOD_MvG
