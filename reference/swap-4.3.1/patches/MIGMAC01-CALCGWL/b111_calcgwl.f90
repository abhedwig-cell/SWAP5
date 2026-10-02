module MOD_gwl

   logical :: no_deltaGWL_warning = .FALSE.
   private
   public :: calcgwl, no_deltaGWL_warning

contains

      ! File VersionID:
!   $Id: calcgwl.f90 341 2017-09-29 18:12:25Z kroes006 $
! ----------------------------------------------------------------------
      subroutine calcgwl ()
! ----------------------------------------------------------------------
!     date               : july 2002, updated april 2008
!     purpose            : search for the watertable and perched
!                          watertable (if existing).
!
!     update             : an unsaturated zone embedded in a saturated soil
!                          column should contain at least a total of 'CritAir' cm 
!                          of air to be recognized as really unsaturated
! ----------------------------------------------------------------------
      ! IN
      use MOD_swap_base, only: swmacro, i_instance !, i_iter, i_core, id_soil
      use MOD_grid,      only: disnod,numnod,z
      use variables,     only: swbotb,gwlinp,h,pond,t1900
      ! INOUT
      ! OUT
      use variables,     only: gwl,nodgwl,bpegwl,npegwl,pegwl,pegwl_bot, gwlm1, gwlconv
      
      use MOD_swap_mp,   only: CritUndSatVol             ! IN
      use MOD_swap_mp,   only: nodgwlflcpzo,gwlflcpzo    ! OUT

      implicit none
! --- global

! --- local
      integer              :: i, node, nodheq1
      logical              :: flsat
      character(len=200)   :: message
      character(len=19)    :: datexti
      character(len=19)    :: datetime
      character(len=10)    :: cval

      save
! ----------------------------------------------------------------------

! --- set initial values
      gwl          = 999.0d0
      pegwl        = 999.0d0
      pegwl_bot    = 999.0d0
      flsat        = .FALSE.
      nodgwl       = numnod+1
      nodheq1      = numnod
      node         = numnod
      nodgwlflcpzo = numnod+1
      gwlflcpzo    = gwl

! --- search for groundwater table
      if (h(numnod) >= 0.0d0) flsat  = .TRUE.
      
      do while (flsat .AND. node > 1)
         node = node - 1 
         if (swbotb == 1) then
            if (h(node) < 0.0d0) then
               gwl    = z(node+1) + h(node+1) / (h(node+1)-h(node)) * disnod(node+1)
               flsat  = .FALSE.
               nodgwl = nodlev (node,gwl)
            end if
         else 

            if (h(node) < 1.0d0 .AND. nodheq1 == numnod) nodheq1 = node

            if (h(node) < 0.0d0) then
               if (swmacro == 0) then
                  flsat  = .FALSE.
                  gwl    = gwlevel (1,node,nodheq1)
                  nodgwl = nodlev (node,gwl)
               else if (swmacro == 1) then
                  if (gwl > 990.0d0) then
                     gwl    = gwlevel (1,node,nodheq1) ! NOTE: was option 2, but option 2 may result in unexpected behaviour if h+1 and h-1 are far apart. nodheq1 only relevant if option 2 is chosen.
                     nodgwl = nodlev (node,gwl)
                  end if
                  call watertable (node,nodgwlflcpzo,nodheq1,0.0d0,flsat,gwlflcpzo) ! NOTE: given critunsatvol = 0.d0, gwlflcpzo and gwl are always identical and nodgwlflcpzo / gwlflcpzo may be omitted.
               end if
            end if
         end if
      end do

!   - whole profile saturated, then add ponding layer to groundwater level
      if (flsat) then
         if (h(1) > 0.0d0) then
            if (pond < 1.d-8) then
               gwl = min(z(1)+h(1),pond)
            else
               gwl = pond
            end if
         else
            gwl = 0.0d0
         end if
         nodgwl = 1
         if (swmacro == 1) then
            nodgwlflcpzo = 1
            gwlflcpzo    = gwl
         end if         
      end if         
 
! --- fatal error if gwl below profile and flux has to be calculated
      if ((swbotb == 3 .OR. swbotb == 4) .AND. gwl > 998.0d0) then
         message = 'The groundwater level descends below the lower boundary. This conflicts with bottom boundary condition 3 and 4. Extend soil profile!'
         call swap_error ('calcgwl', message)
      end if

! --- warning error if there is inconsistency between defined gwl and soil physics
      if (swbotb == 1 .AND. (gwlinp  >= z(1) .OR. gwl > 998.0d0)) then
!        determine date and date-time
         call dtdpst('year-month-day,hour:minute:seconds',t1900,datexti)
         message = 'No groundwater level because unsaturation at bottom compartment at '//trim(datexti)//'. This is caused by inconsistency between given gwl and soil physical parameters'
         call swap_warning ('calcgwl', message)
      end if
      
!     warning
      if (.NOT. no_deltaGWL_warning) then
         if (swbotb /= 1 .AND. abs(gwl-gwlm1) >= gwlconv .AND. abs(gwl-999.0d0) > 1.d0 .AND. abs(gwlm1-999.0d0) > 1.d0) then
            call dtdpst ('year-month-day',t1900+1.001d0,datetime)
            write(cval,'(I10)') i_instance
            message = cval//' Change of groundwater level exceeds criterion at '//adjustl(trim(datetime))//'. Consider reduction of dtMin'
            call swap_warning ('calcgwl',message)
            !write (750+i_core,'(6I6, 62E15.5)') i_instance, i_iter, id_soil, swbotb, numnod, node, gwl, gwlm1, h(1:numnod)
         end if
      end if

! --- search for perched groundwater table

      if (flsat) then
         ! whole profile is saturated and gwl >= 0: no perched gwl
         pegwl     = 999.d0
         pegwl_bot = 999.d0
         npegwl    = -1
         bpegwl    = -1
         return
      end if

!   - first, search for first saturated compartment (i) above groundwater level
      do i = min(nodgwl,numnod), 1, -1
         if (h(i) >= 0.0d0) exit
      end do
      if (i == 1 .AND. h(1) < 0.0d0) i = 0

!   - if saturated compartment above gwl exists, then find perched groundwater table
      if (i /= 0) then

!        extra: find z-position of bottom of the perched saturated region; it lies between z(i) and (z(i+1))
         if (i < numnod) then
            pegwl_bot = gwlevel (3,i,i)
         else
            pegwl_bot = 999.0d0
         end if

         flsat   = .TRUE.
         bpegwl  = nodlev (i,pegwl_bot)
         node    = bpegwl
         nodheq1 = bpegwl

         do while (flsat .AND. node > 1)
            node = node - 1 

            if (h(node) < 1.0d0 .AND. nodheq1 == bpegwl) nodheq1 = node

            if (h(node) < 0.0d0) then
               if (swmacro == 0) then
                  flsat  = .FALSE.
                  pegwl  = gwlevel (1,node,nodheq1)
                  npegwl = nodlev (node,pegwl)
               else if (swmacro == 1) then
                  call watertable (node,npegwl,nodheq1,CritUndSatVol,flsat,pegwl)
               end if
            end if
         end do
!
!   - whole profile saturated, then add ponding layer to perched groundwater level
         if (flsat) then
            if (h(1) > 0.0d0) then
               if (pond < 1.d-8) then
                  pegwl = min(z(1)+h(1),pond)
               else
                  pegwl = pond
               end if
            else
               pegwl = 0.0d0
            end if
            npegwl = 1
         end if 
      else
         pegwl     = 999.d0
         pegwl_bot = 999.d0
         bpegwl    = -1
         npegwl    = -1
      end if



contains
!*****************************************************************************************************

!-----------------------------------------------------------------------
      function gwlevel(swoptlev,node,nodheq1)
! ----------------------------------------------------------------------
!     Date               : april 2008
!     Purpose            : calc. water level from pressure head
! ----------------------------------------------------------------------
      use MOD_grid,  only: dz, zbotcp
      implicit none
      
! --- global 
      integer, intent(in)  :: node, nodheq1, swoptlev
      real(8)              :: gwlevel
! --- local
      integer              :: i
      real(8)              :: levm1, levp1
! ----------------------------------------------------------------------

      if (swoptlev == 1) then
!        groundwater level equals elevation head where h = 0
         if (h(node+1) >= 0.0d0) then
            gwlevel = z(node+1) + h(node+1) / (h(node+1)-h(node)) * disnod(node+1)
         else   
            gwlevel = zbotcp(node) - h(node)
            gwlevel = min(z(node),max(zbotcp(node),gwlevel))
         end if

      else if (swoptlev == 3) then
!        level of bottom of perched saturated zone equals elevation head where h = 0
         if (h(node+1) <= 0.0d0) then
            gwlevel = z(node+1) + h(node+1) / (h(node+1)-h(node)) * disnod(node+1)
         else   
            gwlevel = zbotcp(node) + h(node)
            gwlevel = min(z(node),max(zbotcp(node),gwlevel))
         end if

      else if (swoptlev == 2) then
!        for macropore:
!        groundwater level equals average of elevation heads of h = -1 and h = +1
         
!        * elevation head of h = +1
         i = nodheq1
         if (nodheq1 == numnod) then
            levp1 = z(i) - 0.5d0 * dz(i)
         else
            levp1 = z(i) - (1.d0-h(i)) / (h(i+1)-h(i)) * disnod(node+1)
         end if
!        * elevation head of h = -1
         i = node
         do while (h(i) > -1.d0 .AND. i > 1)
            i = i - 1
         end do
         if (i == 1 .AND. h(1) > -1.d0 .AND. node > 1) then
!           no compartment with pressure head < -1 cm in top of profile:
!           use elevation head of h = 0 as estimation for groundwater level
            levm1 = z(node+1) + h(node+1) / (h(node+1)-h(node)) * disnod(node+1)
            levp1 = levm1
         else
            levm1 = z(i+1) + (1.d0+h(i+1)) / (h(i+1)-h(i)) * disnod(node+1)
         end if
!        groundwater level = average of levp1 and levm1
         gwlevel = (levp1 + levm1) / 2.d0
      end if

      return
      end function gwlevel
      
!-----------------------------------------------------------------------
      function nodlev(node,lev)
! ----------------------------------------------------------------------
!     Date               : july 2025
!     Purpose            : calculate node in which water level is situated
! ----------------------------------------------------------------------
      use MOD_grid,  only: dz
      implicit none
      
! --- global 
      integer, intent(in)  :: node
      real(8), intent(in)  :: lev
      integer              :: nodlev
! --- local
      integer              :: i

! ----------------------------------------------------------------------
      
       i = max(node-2,1)        
       do while(z(i)-0.5d0*dz(i) > lev .AND. i < numnod) ! .AND. i > 2 
          i = i + 1
       end do
       nodlev = min(max(i,1),numnod)
       
       return
       end function nodlev

! ----------------------------------------------------------------------
      subroutine watertable (node,nodwaterlev,nodheq1,CritUndSatVol,flsat,waterlevel)
! ----------------------------------------------------------------------
!     date               : april 2008
!     purpose            : search for watertable and perched
!                          watertable (if existing).
! ----------------------------------------------------------------------
      use MOD_grid,  only: dz
      use variables, only: Theta, ThetaS
      implicit none

! --- global                                                          in
      integer, intent(in)     :: nodheq1
      real(8), intent(in)     :: CritUndSatVol
!                                                                  inout
      integer, intent(inout)  :: node
      logical, intent(inout)  :: flsat
!                                                                    out
      integer, intent(out)    :: nodwaterlev
      real(8), intent(out)    :: waterlevel
! ----------------------------------------------------------------------
! --- local
      integer i
      real(8) TotUndSatVol
      logical flsat2
! ----------------------------------------------------------------------
!     Initialize
      TotUndSatVol = 0.0d0
      flsat2       = .FALSE. 
      i            = node

!     Calculate unsaturated volume above given water level
      do while (TotUndSatVol < CritUndSatVol .AND. .NOT.flsat2 .AND. i > 0)
         TotUndSatVol = TotUndSatVol + dmax1(0.0d0, (ThetaS(i) - Theta(i))) * dz(i)
         if (h(i) > -1.d-7) flsat2 = .TRUE.
         i = i - 1
      end do

      if (i == 0 .OR. TotUndSatVol > CritUndSatVol-1.d-8) then
!        Unsaturated volume exceeds critical volume or top of soil column is reached
         flsat = .FALSE.
!        Find groundwater level and containing node   
         if (CritUndSatVol > 0.d0) then  
            waterlevel = gwlevel (1,node,nodheq1)
         else
            waterlevel = gwlevel (1,node,nodheq1) ! NOTE: was option 2
         end if
         nodwaterlev = nodlev (node,waterlevel)
      else if (flsat2) then
!        Unsaturated volume between two saturated volumes does not exceed critical volume:
!        continue in calcgwl with given position of node
         node   = i + 1
      end if

      return
      end subroutine watertable

      end subroutine calcgwl

end module MOD_gwl
