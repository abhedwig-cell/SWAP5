! File VersionID:

!   $Id: boundbottom.f90 362 2018-01-08 13:08:33Z kroes006 $
! ----------------------------------------------------------------------
      subroutine BoundBottom
! ----------------------------------------------------------------------
!     date               : August 2004 / Sept 2005
!     purpose            : determine soil profile bottom boundary conditions
! ----------------------------------------------------------------------
      use MOD_grid,      only: numnod, ztopcp, zbotcp, dz, disnod
      use MOD_swap_base, only: swmacro, i_instance
      use MOD_frost,     only: rfcp
      use MOD_swap_mp,   only: frarmtrx
      use variables,     only: shape_3, swbotb, gwlinp, gwltab, dt, h, date, sw2, qbot, sinave, sinamp, t, sinmax, qbotab,                 &
                               kmean, hdrain, gwl, sw3, deepgw, aqave, aqamp, aqper, aqtmax, haqtab, swbotb3resvert, t1900,                &
                               rimlay, sw4, swqhbot, cofqha, cofqhb, swcofqhc, cofqhc, hbot, hbotab, qbot_nonfrozen, kbot, theta, k
      use MOD_arrays,     only: mabbc
      use MOD_MvG,        only: watcon, hconduc, cofgen

      implicit none

! --- local variables
      integer node, nodnumgwl 

      real(8) cvalprof,gwlmean, thetabot, twopi, freq
      real(8) satnodgwl,dabsgwl
      real(8) afgen
      character(len=300) message
      character(len=10)    :: cval

! ----------------------------------------------------------------------
      twopi = 8.0d0*datan(1.0d0)
      freq  = twopi/365.0d0
! ----------------------------------------------------------------------
! --- interpolation between daily values of given groundwaterlevel
      if (swbotb == 1) then
          gwlinp = afgen(gwltab,mabbc*2,t1900+dt)
      end if

! --- regional bottom flux is given
      if (abs(swbotb) == 2) then
 
! Comment PietG (8-1-08):
! ---   if the moisture content in the soil profile is depleted by 
!       a combination of inconsistent boundary conditions, and 
!       the pressure head at the bottom tends to very low values,
!       then the choice for swbotb=2 is not appropriate. 

        if (h(numnod) < -1.0d+7) then ! oven dry conditions at bottom
           if (swbotb == 2) then
              write(cval,'(I10)') i_instance
              message = cval//' Oven dry conditions in lowest compartment therefore switched to free drainage at date '//trim(date)
              call swap_warning ('boundbottom', message)
           end if
           swbotb = -2
        else
           swbotb = 2
        end if

        if (swbotb == 2) then
           if (sw2 == 1) then
! ---     sine function is used
             qbot = sinave + sinamp * dcos( freq * (t-sinmax))        
           else
! ---     table is used
             qbot = afgen (qbotab,mabbc*2,t1900+dt)
           end if
        end if

! ---   free drainage assumed in case of h(numnod) < -1.0E7
        if (swbotb == -2) qbot = -1.0d0 * kmean(numnod+1)

      end if

! --- seepage or infiltration from/to deep groundwater
      if (swbotb == 3) then
        gwlmean = hdrain + shape_3*(gwl - hdrain)
! ---   determine hydraulic head of deep aquifer
        if (sw3 == 1) then
          deepgw = aqave + aqamp * dcos( twopi/aqper*(t - aqtmax))
        else
          deepgw = afgen (haqtab,mabbc*2,t1900+dt)
        end if

! ---   determine C-value (vertical resistance) in saturated part of modelled profile 
        if (SwBotb3ResVert == 0) then
!     -   find number node with groundwater level
          node = numnod
          do while (gwlmean > ztopcp(node) .AND. node > 1)
            node = node - 1
          end do
          nodnumgwl = node
          satnodgwl = gwlmean - zbotcp(nodnumgwl)
          cvalprof = satnodgwl/cofgen(3,nodnumgwl)
          do node = nodnumgwl+1, numnod
            cvalprof = cvalprof + dz(node)/cofgen(3,node)
          end do
        else if (SwBotb3ResVert == 1) then
          cvalprof = 0.0d0
        end if
!
        qbot   = (deepgw - gwlmean)/(rimlay+cvalprof)

! ---   extra groundwater flux might be added
        if (sw4 == 1) qbot = qbot + afgen (qbotab,mabbc*2,t1900+dt)
      end if

! --- flux calculated as function of h
      if (swbotb == 4 ) then
        if (swqhbot == 1) then
          qbot = cofqha * dexp(cofqhb * dabs(gwl))
          if (swcofqhc == 1) qbot = qbot + cofqhc
        else if (swqhbot == 2) then
          dabsgwl = dabs(gwl)
          qbot = afgen(qbotab,mabbc*2,dabsgwl)
        end if
      end if

! --- interpolation between daily values of given pressurehead
      if (swbotb == 5) then
        hbot           = afgen (hbotab,mabbc*2,t1900+dt)
        thetabot = watcon(numnod,hbot)
                   
        kmean(numnod+1)= hconduc(numnod,hbot,thetabot,rfcp(numnod))
        if (swmacro == 1) then
          kmean(numnod+1) = FrArMtrx(numnod) * kmean(numnod+1)
        end if
      end if

! --- zero flux at the bottom
      if (swbotb == 6) qbot = 0.0d0

! --- free drainage
      if (swbotb == 7) then
         thetabot = watcon(numnod,h(numnod))
         kmean(numnod+1) = hconduc(numnod,h(numnod),thetabot,rfcp(numnod))
         qbot = -1.0d0 * kmean(numnod+1)
      end if

! --- lysimeter with free drainage
      if (swbotb == 8) qbot = 0.0d0

      ! simultaneously: fixed h and fixed q at bottom
      if (swbotb == 9) then
         qbot            = afgen (qbotab,mabbc*2,t1900+dt)
         hbot            = afgen (hbotab,mabbc*2,t1900+dt)
         thetabot        = watcon(numnod,hbot)
         kbot            = hconduc(numnod,hbot,thetabot,rfcp(numnod))
         kmean(numnod+1) = kbot
         h(numnod)       = hbot - (qbot/kbot + 1.0d0) * disnod(numnod+1)
         theta(numnod)   = watcon(numnod,h(numnod))
         k(numnod)       = hconduc(numnod,h(numnod),theta(numnod),rfcp(numnod))
      end if

      qbot_nonfrozen = qbot

      return
      end subroutine BoundBottom
