module MOD_frost

   use MOD_arrays,    only: macp
   use MOD_swap_base, only: swfrost

   integer,                  save :: nodfrostbot = 0           ! Node nr of deepest node with frost conditions
   real(8), dimension(macp), save :: rfcp        = 0.0d0       ! Reduction factor for frozen conditions in each model compartment (-)
   real(8),                  save :: tfroststa   = 0.0d0       ! Soil temperature (oC) where reduction of water fluxes starts
   real(8),                  save :: tfrostend   = 0.0d0       ! Soil temperature (oC) where reduction of water fluxes ends
   real(8),                  save :: zfrostbot   = 0.0d0       ! Depth of bottom of frost layer (L)
   real(8),                  save :: zfrosttop   = 0.0d0       ! Depth of top of frost layer (L)

public

contains

! File VersionID:
!   $Id: frozencond.f90 368 2018-01-11 15:44:15Z heine003 $
! ----------------------------------------------------------------------
      subroutine FrozenCond(tsoil, tetop)
! ----------------------------------------------------------------------
!     date               : sept 2005
!     purpose            : if Soil temperatures are simulated, determine 
!                          the reduction factors and frozen depth for 
!                          frozen conditions
! ----------------------------------------------------------------------
      use MOD_grid, only : numnod, z, disnod
      implicit none
! global
      real(8),                  intent(in) :: tetop
      real(8), dimension(macp), intent(in) :: tsoil
! local
      integer                              :: node
      logical                              :: flthaw

! ----------------------------------------------------------------------

!    reduction factor
      do node=1,numnod
         rfcp(node) = 1.0d0
         if (swfrost == 1) then
           if (tsoil(node) >= tfroststa) then
              rfcp(node) = 1.0d0
           else if (tsoil(node) <= tfrostend) then
              rfcp(node) = 0.0d0
           else if (tsoil(node) < tfroststa .AND. tsoil(node) > tfrostend) then 
              rfcp(node) = (tsoil(node)-tfrostend)/(tfroststa-tfrostend)
           end if
         end if
      end do

 
!     frozen soil : frozen depth z and frozen node nr
      flthaw       = .TRUE.
      nodfrostbot  = -1
      zfrostbot    = 0.0d0
!      nodfrosttop  = -1
      zfrosttop    = 0.0d0

      node = numnod
      do while (flthaw .AND. node > 1)
         node = node - 1 
         if (tsoil(node) <= tfrostend+1.0d-6) then
            zfrostbot = z(node+1) + disnod(node+1) * (tfrostend-tsoil(node+1)) / (tsoil(node)-tsoil(node+1))
            flthaw      =.FALSE.
            nodfrostbot = node
         end if
      end do

      if (.NOT.flthaw) then
         flthaw  = .TRUE.
         node = 0
         do while (flthaw .AND. node < nodfrostbot)
            node = node + 1 
            if (tsoil(node) <= tfrostend+1.0d-6) then
               if (node == 1) then
                  if (tetop <= tfrostend) then
                     zfrosttop = 0.0d0
                  else
                     zfrosttop = z(node) - (z(node) - 0.0d0) * (tsoil(node)-tfrostend) / (tsoil(node)-tetop)
                  end if
               else
!                  zfrosttop = z(node) - (z(node) - z(node-1)) *         &
                  zfrosttop = z(node) + disnod(node) * (tsoil(node)-tfrostend) / (tsoil(node)-tsoil(node-1))
               end if
               zfrosttop = min(0.0d0,zfrosttop)
               flthaw      =.FALSE.
!               nodfrosttop = node
            end if
         end do
      end if

      return
      end subroutine FrozenCond
! ----------------------------------------------------------------------
      subroutine FrozenBounds
! ----------------------------------------------------------------------
!     date               : 20070206
!     purpose            : reduce or stop boundary (drainage and bottom) 
!                          fluxes under frost conditions
! ----------------------------------------------------------------------
!     Swap modules for data communication
      use MOD_arrays,    only: macp
      use MOD_grid,      only: numnod, dz, layer
      use MOD_swap_base, only: swdra, swmacro
      use MOD_MvG,       only: hconode_vsmall
      use MOD_drain,     only: nrlevs, zbotdr, qdra, qdrain, swdivd, qdrtot, divdra
      use variables,     only: thetas, theta, fluseksatexm, ksatexm, ksatfit
      use variables,     only: qbot, qbot_nonfrozen, gwl
      implicit none

!     local
      integer           :: node,level,leveldeepest
      real(8)           :: volair,ksatcp(macp),qdratot
      real(8)           :: zdeepest,ztop
      logical           :: frozencomp

! ----------------------------------------------------------------------

!     initialize qbot
      qbot = qbot_nonfrozen


! --  verify available air volume

      node = numnod
      volair = 0.0d0
      frozencomp = .TRUE.
      do while (frozencomp)
         volair = volair + dmax1(0.0d0, (thetas(node)-theta(node)))*dz(node)
         node = node - 1
         if (node == 0) then
            frozencomp = .FALSE.
         else
            if (rfcp(node) <= 0.01d0) then
               frozencomp = .FALSE.
            end if
         end if 
      end do

! --  consider reduction when volair is very low
!     reduction of drainage only when systems are present
      if (swdra == 0) then
         if (nodfrostbot > 1 .AND. volair < 0.01d0) then
            qbot = 0.0d0
         end if
      else
         if (nodfrostbot > 1 .AND. volair < 0.01d0) then

            leveldeepest = 0
            zdeepest     = 0.0d0
            do level=1,nrlevs
               if (zbotdr(level) < zdeepest) then
                  leveldeepest = level
                  zdeepest     = zbotdr(level)
               end if
            end do

            do node=1,numnod
               if (fluseksatexm(node) .AND. swmacro == 0) then
                 ksatcp(node)  = ksatexm(layer(node))*rfcp(node) + (1.0d0-rfcp(node))*hconode_vsmall
               else
                 ksatcp(node)  = ksatfit(layer(node))*rfcp(node) + (1.0d0-rfcp(node))*hconode_vsmall
               end if

               do level=1,nrlevs
                  if (zfrostbot < zbotdr(level)) then
                     qdra(level,node) = 0.0d0
                     qdrain(level) = 0.0d0
                  end if
               end do
            end do

            qdratot = 0.0d0
            do level = 1,nrlevs
               qdratot = qdratot + qdrain(level)
            end do

            if (abs(qdratot) < 1.0d-6) then
               if (zfrostbot < zbotdr(leveldeepest)) then
                  qbot = 0.0d0
               else
                  qdrain(leveldeepest) = qbot 
               end if
            else
               do level = 1,nrlevs
                  qdrain(level) = qdrain(level) * (1.0d0 + qbot/qdratot)
               end do
            end if

            if (swdivd == 1) then
               ztop = min(gwl,zfrostbot)
               call divdra (ksatcp,ztop)
            end if
            ! FROST-DRAIN-01: report the actual HeadCalc nodal sink owner.
            if (swdivd == 0 .and. swmacro == 0) then
               do level=1,nrlevs
                  qdrain(level) = sum(qdra(level,1:numnod))
               end do
            end if
         else

            do level = 1,nrlevs
               qdrain(level) = 0.0d0
               do node = 1,numnod
                  qdra(level,node) = qdra(level,node)*rfcp(node)
                  qdrain(level) = qdrain(level) + qdra(level,node)
               end do
            end do

         end if

         qdrtot = 0.0d0
         do level=1,nrlevs
             qdrtot = qdrtot + qdrain(level)
         end do

      end if

      return
      end subroutine FrozenBounds
end module MOD_frost
