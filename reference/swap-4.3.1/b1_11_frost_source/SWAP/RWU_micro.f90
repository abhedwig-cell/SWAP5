!
!*****   Module RWU_micro   *****
!
! Feb. 2022; Marius Heinen, Wageningen Environmental Research
!
! This module contains the routines/functions that are needed in case root water uptake (RWU) needs to be calculated 
! according to either the microscopic RWU model of de Willigen et al. or the microscopic RWU model of de Jong van Lier et al.
!
! The public routine is: do_RWU_micro
!   * arguments input: Itask, iMicro_in, noddrz, Lrv, Tp
!   * arguments output: Upw, Alpha_micro_tot
!   * other input variables from module 'variables': h, dz
!
! Private routines are: RWU_micro, T_reduction, FG, myFun, get_MFLP_K; ZBREND2 (the latter based on Press et al.)
!
   
!!!module SoilPropertiesInfo
!!!   implicit none
!!!   real(8), dimension(:), allocatable, save  :: WCr
!!!   real(8), dimension(:), allocatable, save  :: WCs
!!!   real(8), dimension(:), allocatable, save  :: Alphad
!!!   real(8), dimension(:), allocatable, save  :: Nd
!!!   real(8), dimension(:), allocatable, save  :: Md
!!!   real(8), dimension(:), allocatable, save  :: Lab
!!!   real(8), dimension(:), allocatable, save  :: Ksat
!!!end module SoilPropertiesInfo

module mod_RWU_micro
   
use parameters, only: pi

implicit none

!  by default: all in this module is private (local)
   private
   
!  except for these public routines and variables
   public :: do_RWU_micro, read_rwu_micro_input, PP, PL, UpwPot, swAlpTot, M_table, K_table
   public :: Tol_2, myTolX, TolConv, factor, alptotal, Ntrial, iMicro, swTypeTred, swDoSatRel
   public :: swO2EcT, sw_mxdrought, RootRadius, RootRadius2, RootXylem, RootCoefA, RootCoefA2, Kroot, Lstem, Lstem_A0, Lstem_A1, PLhalf, CampA, RootEff, swHydrLift

   !real(8), save, protected :: Tpublicsave     ! better to save (must save) all public variables; protected means that it cannot be changed outside this module (only within)
   !real(8), save            :: Tprivatesave    ! forced to be saved
   !real(8)                  :: TprivateNOsave  ! saving is not guaranteed, and not needed

   integer,                            save  :: swAlpTot

   ! local data
   integer, parameter                        :: Init    =   1        ! Task: initialize
   integer, parameter                        :: Rate    =   2        ! Task: rate calculations
   integer, parameter                        :: iMethod =   2        ! 1: calculate M (and K) analytically each call
                                                                     ! 2: linear interpolation from pre-filled M-table and K-table

   ! control variables (saved)
   ! a) case for comparing numerical solution with 'analytical' (= repeat) solution : 1.0d-8, 1.0d-3, 1.0d-4, 1.0d-6
   ! b) case for implementation in SWAP                                             : 1.0d-8, 1.0d-6, 1.0d-6, 1.0d-4
   real(8),                            save  :: Tol_2                ! Convergence parameter for second round of xp guess (first round no longer used)
   real(8),                            save  :: myTolX               ! Convergence parameter for root finding in myFun
   real(8),                            save  :: TolConv              ! Overall convergence criterion
   real(8),                            save  :: factor               ! Multiplier/divisor for second round of xp guess
   real(8),                            save  :: alptotal
   integer,                            save  :: Ntrial               ! Maxmimum number of (Newton-Raphson) iterations
   integer,                            save  :: iMicro               ! Type of microscopic model: 1 = de Willigen et al; 2 = de Jong van Lier et al.
   integer,                            save  :: swTypeTred           ! type of reduction function: 1 = Campbell; 2 = linear; 3 = parabolic; default: 1
   integer,                            save  :: swDoSatRel           ! for layers with h >=0 RWU is proportional to Lrv in those layers; remaining Tpot is then solved by de Willigen model; default: 1 (yes)

   ! local allocatable arrays
   integer, dimension(:), allocatable, save  :: jLayer               ! Stored compartment number for active layers
   real(8), dimension(:), allocatable, save  :: X                    ! Vector with unknowns (cm)
   real(8), dimension(:), allocatable, save  :: delX                 ! Vector with changes in unknowns (cm)
   real(8), dimension(:), allocatable, save  :: Pav                  ! Absolute value of bulk pressure head (cm)
   real(8), dimension(:), allocatable, save  :: Prz                  ! Absolute value of pressure head at root-soil interface (cm)
   real(8), dimension(:), allocatable, save  :: Q                    ! Coefficient Q (1/d)
   real(8), dimension(:), allocatable, save  :: S                    ! Coefficient S (1/cm)
   real(8), dimension(:), allocatable, save  :: Phiav                ! Matric flux potential at PAV (cm2/d)

   ! locals; must be saved
   integer,                            save  :: swO2EcT              ! switch: which type of reduction to use for known stress in O2, Ec or T (frost): 
                                                                     ! 1: reduce Lrv; 2: reduce RWU uptak rate; 0: do not use reduction (not preferred)
   integer,                            save  :: sw_mxdrought         ! switch: determine drought stress as if optimal root activity
   real(8),                            save  :: RootRadius           ! Root radius (cm)
   real(8),                            save  :: RootRadius2          ! Root radius squared (cm2); help
   real(8),                            save  :: RootXylem            ! Xylem radius (cm)
   real(8),                            save  :: RootCoefA            ! Root coefficient a (-); e.g., CoefA = 0.53
   real(8),                            save  :: RootCoefA2           ! Root coefficient a squared (-); help
   real(8),                            save  :: Kroot                ! Root conductance (cm/d)
   real(8),                            save  :: Lstem                ! Stem conductance (1/d)
   real(8),                            save  :: Lstem_A0, Lstem_A1   ! Intercept (A0) and slope (A1) of Lstem(Tpot) linear relationship (1/d; 1/cm)
   real(8),                            save  :: PLhalf               ! Leaf water potential when Tact = Tpot/2 (cm); becomes root water potential in case LP = 0
   real(8),                            save  :: CampA                ! Exponent in Tact(Tpot) relationship of Campbell (-)
   real(8),                            save  :: RootEff              ! Root system efficiency factor (-); [0...1.0]
   integer,                            save  :: swHydrLift           ! Hydraulic lift allowed (1) or not allowed (0; default)

   ! MFLP and K tablkes as used for RWU_micro
   real(8), dimension(:,:), allocatable, save   :: M_table, K_table        ! 2D arryas with precalculated M and K values per soil horizon

   ! locals; not saved
   integer                                   :: Neq                  ! Number of unknowns
   integer                                   :: Neq1                 ! Neq - 1
   real(8)                                   :: xTpot                ! Local copy of Tpot (cm/d)
   real(8)                                   :: r1                   ! Radius of soil cylinder around root (cm)
   real(8)                                   :: rho                  ! r1/RootRadius (-)
   real(8)                                   :: rhoi
   real(8)                                   :: sumQ                 ! Sum of all Q values (1/d)
   real(8)                                   :: sumQX                ! Sum of all Q*X values (cm/d)
   real(8)                                   :: LP                   ! Resistance between root and leaf (1/d)
   real(8)                                   :: DPL                  ! Difference in pressure head betweenleaf and root (cm)
   real(8)                                   :: PP                   ! Root water potential (cm)
   real(8)                                   :: PL                   ! Leaf water potential (cm); PL = PP + DPL
   real(8)                                   :: xp                   ! local for PP: xp = PP = X(Neq)
   real(8), dimension(:), allocatable, save  :: UpwPot               ! Potential root water uptake rate per layer (cm/d)

   ! locals: counters, temporary dummies, etc.
   integer                                   :: j, k
   real(8)                                   :: xp1, xp2, fxp1, fxp2, fxp, funval
   
!************************************************************************
! Note: subroutines/functions defined in a module after 'contains'
!       not need to be defined in an interface block elsewhere
   contains
   
subroutine do_RWU_micro(Itask, iMicro_in, noddrz, Lrv, Tp, alptot, fl_optrtz, Upw, Alpha_micro_tot)

!!!use SoilPropertiesInfo
use MOD_grid,   only: dz, numnod
!!!use MOD_MvG,    only: cofgen
use variables,  only: date, t1900, h

implicit none

! global
integer,                    intent(in)  :: Itask, iMicro_in, noddrz
real(8),                    intent(in)  :: Tp
real(8), dimension(noddrz), intent(in)  :: Lrv, alptot
logical,                    intent(in)  :: fl_optrtz
real(8),                    intent(out) :: Alpha_micro_tot
real(8), dimension(noddrz), intent(out) :: Upw

! local
integer                                :: NL             ! local copy of noddrz
real(8)                                :: Tact, Tact1, Tact2
logical, dimension(3)                  :: check
character (len=300)                    :: message

select case(ITask)

! initialization
case (1)

   if (allocated(UpwPot)) deallocate(UpwPot); allocate(UpwPot(numnod)); UpwPot = 0.0d0
   
   NL     = noddrz
   iMicro = iMicro_in
   if (iMicro /= 2) iMicro = 1      ! be sure that iMicro is either 1 (default) or 2
   
   !!!! Cofgen to SoilPropertiesInfo
   !!!if (iMethod == 1) call Store_Cofgen
   
   call RWU_micro (ITask, iMicro, NL, DZ(1:NL), H(1:NL), Lrv(1:NL), alptot(1:NL), fl_optrtz, Tp, Tact, Upw(1:NL), Alpha_micro_tot, Tact1, Tact2, check)

! prepare and perform for actual RWU calculations
case (2)
   
   NL = noddrz
   
   !!!! Cofgen to SoilPropertiesInfo
   !!!if (iMethod == 1) call Store_Cofgen

   ! compute RWU
   call RWU_micro (ITask, iMicro, NL, DZ(1:NL), H(1:NL), Lrv(1:NL), alptot(1:NL), fl_optrtz, Tp, Tact, Upw(1:NL), Alpha_micro_tot, Tact1, Tact2, check)
   
   if (.NOT. all(check(1:2))) then
      call swap_warning('d0_rwu_micro', 'Convergence problem encountered in RWU_micro')
      write(message,'(A, 3x, F20.8, 1P, 7E20.8, 3x, 3L1)') date, t1900, Tp, Tact, Tact1, Tact2, Alpha_micro_tot, PP, PL, check
      call swap_warning('d0_rwu_micro', message)
   end if
   
case default
   call swap_error('d0_rwu_micro', 'Illegal ITask value')

end select

end subroutine do_RWU_micro

subroutine RWU_micro(ITask, iMicro, NL, Dz, H, Lrv, alptot, fl_optrtz, Tpot, Tact, Upw, Alpha_micro_tot, Tact1, Tact2, check)
use MOD_arrays,       only: macp 
use MOD_grid,         only: numnod
use MOD_swap_base,    only: unit_log, unit_err, fl_do_not_read_crpfile
use plant_interface,  only: unit_crp, crpfilnam
use MOD_re_global,    only: hroot, mroot, mflux

implicit none
integer,                intent(in)        :: ITask             ! Task
integer,                intent(in)        :: iMicro            ! Type of microscopic model to use: 1 = de Willigen etal.; 2 = de Jong van Lier et al.
integer,                intent(in)        :: NL                ! Number of (rooted) layers (= noddrz)
real(8),                intent(in)        :: Tpot              ! Potential transpiration rate (cm/d)
real(8),                intent(out)       :: Tact              ! Actual transpiration rate (cm/d)
real(8),                intent(out)       :: Tact1             ! Actual transpiration rate: according to flow from bulk soil towards root-soil interface (cm/d)
real(8),                intent(out)       :: Tact2             ! Actual transpiration rate: according to flow across root wall (cm/d)
real(8),                intent(out)       :: Alpha_micro_tot   ! Total reduction factor (Tact/Tpot) that has been applied to Upw
real(8), dimension(NL), intent(in)        :: H                 ! Pressure head (cm)
real(8), dimension(NL), intent(in)        :: Lrv               ! Root length density (cm/cm3)
real(8), dimension(NL), intent(in)        :: alptot            ! Reduction factor for Lrv (-)
logical,                intent(in)        :: fl_optrtz         ! Flag to indicate optimal root activity
real(8), dimension(NL), intent(in)        :: Dz                ! Thickness of soil compartments (cm)
real(8), dimension(NL), intent(out)       :: Upw               ! Root water uptake rate per layer: flux across root wall (cm/d); NOTE: adapted based on Alpha_micro_tot
logical, dimension(3),  intent(out)       :: check             ! Check if solution has converged

! local
integer                                   :: it
real(8)                                   :: TotL, M
real(8), dimension(:), allocatable, save  :: Upw2              ! Root water uptake rate per layer: flux from bulk soil towards root (cm/d)
!!!real(8), dimension(:), allocatable, save  :: ALpha_dry_micro   ! Reduction per compartment
character(len=300)                        :: message
logical                                   :: reallocate
logical, dimension(MACP)                  :: mask

select case (ITask)

case (Init)

   if (allocated(Upw2)) deallocate(Upw2); allocate(Upw2(numnod)); Upw2 = 0.0d0

   ! open connection
   if (.NOT. fl_do_not_read_crpfile) then
      call rdinit(unit_crp, unit_err, crpfilnam)
         call read_rwu_micro_input()
      close(unit_crp)
   end if
   
   if (swDoSatRel == 1) call swap_error ('rwu_micro', 'In test phase: cannot use SWDOSATREL = 1')
   
   ! initialize (return) variables
   Tact            = 0.0d0
   PP              = 0.0d0
   PL              = 0.0d0
   hroot           = 0.0d0
   mroot           = 0.0d0
   mflux           = 0.0d0
   Upw             = 0.0d0
   UpwPot          = 0.0d0
   Alpha_micro_tot = 1.0d0
   !!!ALpha_dry_micro = 1.0d0
   check           = .TRUE.
   
   DPL             = 0.0d0
   sumQ            = 0.0d0
   sumQX           = 0.0d0

   call get_MFLP_K (1)

case (Rate)

   ! Return if Tpot too small (check with small value in SWAP)
   if (Tpot < 1.0D-9) then
      Tact            = Tpot
      PP              = 0.0D0
      PL              = 0.0D0
      hroot(1:numnod) = 0.0d0
      mroot(1:numnod) = 0.0d0
      mflux(1:numnod) = 0.0d0
      TotL = sum(Lrv(1:NL)*dz(1:NL))
      do j = 1, NL
         !if (H(j) > 0.0d0) then
            UPW(j) = Lrv(j)*dz(j)/TotL * Tpot
         !end if
      end do
      UpwPot          = 0.0D0
      Alpha_micro_tot = 1.0d0
      !!!ALpha_dry_micro = 1.0d0
      check           = .TRUE.
      return
   end if

   ! Roots in saturated compartments: uptake relative to Lrv/sum(Lrv)
   UPW = 0.0d0
   !if (swDoSatRel == 1 .AND. maxval(H(1:NL)) > 0.0d0 .AND. maxval(alptot(1:NL)) > 0.0d0) then
   if (fl_optrtz .AND. maxval(H(1:NL)) > 0.0d0) then
      TotL = sum(Lrv(1:NL)*dz(1:NL))
      do j = 1, NL
         if (H(j) > 0.0d0) then
            UPW(j) = Lrv(j)*dz(j)/TotL * Tpot
         end if
      end do
      continue
   end if
   UPW2  = UPW
   xTpot = Tpot - sum(UPW(1:NL))
   
   ! Neq is total number of unknowns, i.e. NL values for PRS (= X) and 1 for PP (= xp)
   mask = .FALSE.
   if (.NOT. fl_optrtz) then
      it = 0
      do j = 1, NL
         if (H(j) < 0.0d0 .AND. alptot(j) > 0.0d0) then
            it = it + 1   ! counter for active soil layers
            mask(j) = .TRUE.
         end if
      end do
      Neq  = it + 1
      Neq1 = it
   else 

      it = 0
      do j = 1, NL
         if (H(j) < 0.0d0) then
            it = it + 1   ! counter for active soil layers
            mask(j) = .TRUE.
         end if
      end do
      if (it == 0) then
      
         Tact            = Tpot
         TotL            = sum(Lrv(1:NL)*Dz(1:NL))
         UPW(1:NL)       = Lrv(1:NL)*Dz(1:NL)/TotL * Tpot
         UpwPot(1:NL)    = UPW(1:NL)
         hroot(1:numnod) = 0.0d0
         mroot(1:numnod) = 0.0d0
         mflux(1:numnod) = 0.0d0
         PP              = 0.0d0
         PL              = 0.0d0
         Alpha_micro_tot = 1.0d0
         !!!ALpha_dry_micro = 1.0d0
         check           = .TRUE.
         return
      end if
      
      Neq  = it + 1
      Neq1 = it
      
   end if
   
   
   ! no active soil layers? return
   if (it == 0) then
      if (swDoSatRel == 1 .AND. maxval(alptot(1:NL)) > 0.0d0) then
         Tact            = Tpot
         TotL            = sum(alptot(1:NL)*Lrv(1:NL)*Dz(1:NL))
         UPW(1:NL)       = alptot(1:NL)*Lrv(1:NL)*Dz(1:NL)/TotL * Tpot
         UpwPot(1:NL)    = UPW(1:NL)
         hroot(1:numnod) = 0.0d0
         mroot(1:numnod) = 0.0d0
         mflux(1:numnod) = 0.0d0
         PP              = 0.0d0
         PL              = 0.0d0
         Alpha_micro_tot = 1.0d0
         !!!ALpha_dry_micro = 1.0d0
         check           = .TRUE.
      else
         Tact            = 0.0d0
         Upw             = 0.0d0
         TotL            = sum(Lrv(1:NL)*Dz(1:NL))
         UpwPot(1:NL)    = Lrv(1:NL)*Dz(1:NL)/TotL * Tpot
         hroot(1:numnod) = 0.0d0
         mroot(1:numnod) = 0.0d0
         mflux(1:numnod) = 0.0d0
         PP              = 0.0d0
         PL              = 0.0d0
         Alpha_micro_tot = 0.0d0
         !!!ALpha_dry_micro = 1.0d0
         check           = .TRUE.
      end if
      return
   end if

   ! Since Neq may not be constant during computations (due to growing root system) we need to check the allocated size each time.
   reallocate = .FALSE.
   if (allocated(jLayer)) then
      if (size(jLayer) /= Neq1) reallocate = .TRUE.
   else
      reallocate = .TRUE.
   end if   
   if (reallocate) then
      if (allocated(jLayer)) deallocate(jLayer); allocate (jLayer(Neq1)); jLayer = 0
      if (allocated(X))      deallocate(X);      allocate (X(Neq));       X      = 0.0d0
      if (allocated(delX))   deallocate(delX);   allocate (delX(Neq));    delX   = 0.0d0
      if (allocated(PAV))    deallocate(PAV);    allocate (PAV(Neq1));    Pav    = 0.0d0
      if (allocated(Phiav))  deallocate(Phiav);  allocate (Phiav(Neq1));  Phiav  = 0.0d0
      if (allocated(Q))      deallocate(Q);      allocate (Q(Neq1));      Q      = 0.0d0
      if (allocated(S))      deallocate(S);      allocate (S(Neq1));      S      = 0.0d0
   end if

   reallocate = .FALSE.
   if (allocated(Prz)) then
      if (size(Prz) /= NL) reallocate = .TRUE.
   else
      reallocate = .TRUE.
   end if   
   if (reallocate) then
      if (allocated(Prz)) deallocate(Prz); allocate (Prz(NL)); Prz = 0.0d0
   end if

   ! start
   Tact  = 0.0d0
   check = .TRUE.
   it    = 0
   alptotal = alptot(1)
   do j = 1, NL
      if (mask(j)) then
         it         = it + 1                    ! counter for active soil layers
         if (swO2ECT == 1 .AND. .NOT. fl_optrtz) then
            r1 = 1.0d0/dsqrt(pi*alptot(j)*Lrv(j))
         else
            r1 = 1.0d0/dsqrt(pi*Lrv(j))
         end if
         rho        = r1/RootRadius
         Pav(it)    = -H(j)                     ! for convenience all equations have been expressed in P = -H (so P > 0 if unsaturated; PP > 0, Prz > 0; X > 0)
         X(it)      = Pav(it)                   ! first estimate of the pressure at root surface
         if (iMicro == 1) then
            if (swO2ECT == 1 .AND. .NOT. fl_optrtz) then
               Q(it)      = alptot(j)*Lrv(j) * Kroot * DZ(j)
               S(it)      = DZ(j) * pi * alptot(j)*Lrv(j) * (rho**2-1.d0)/fg(rho)
            else if (swO2ECT == 2 .AND. .NOT. fl_optrtz) then
               Q(it)      = Lrv(j) * alptot(j)*Kroot * DZ(j)
               S(it)      = DZ(j) * pi * Lrv(j) * (rho**2-1.d0)/fg(rho)
            else 
               Q(it)      = Lrv(j) * Kroot * DZ(j)
               S(it)      = DZ(j) * pi * Lrv(j) * (rho**2-1.d0)/fg(rho)
            end if
         else
            rhoi       = 4.0d0/(RootRadius2 - RootCoefA2*r1*r1 + 2.0d0*(RootRadius2 + r1*r1)*dlog(RootCoefA*rho))
            if (swO2ECT == 2 .AND. .NOT. fl_optrtz) then
               Q(it)      = rhoi * r1*r1 * dlog(RootRadius/RootXylem)/(2.0d0 * alptot(j)*Kroot)
               S(it)      = DZ(j) * rhoi * RootEff
            else
               Q(it)      = rhoi * r1*r1 * dlog(RootRadius/RootXylem)/(2.0d0 * Kroot)
               S(it)      = DZ(j) * rhoi * RootEff
            end if
         end if
         jLayer(it) = j
         call get_MFLP_K (2, -Pav(it), jLayer(it), Phiav(it))

         !if (swO2ECT == 0) write(120, '(A,3x,F20.12, 2I5, 1P, 3E20.12)') date, t1900, j, it, alptot(j), Q(it), S(it)
         !if (swO2ECT == 1) write(121, '(A,3x,F20.12, 2I5, 1P, 3E20.12)') date, t1900, j, it, alptot(j), Q(it), S(it)
         !if (swO2ECT == 2) write(122, '(A,3x,F20.12, 2I5, 1P, 3E20.12)') date, t1900, j, it, alptot(j), Q(it), S(it)
         !if (date == "1977-07-18") write(123, '(A,3x,F20.12, 2I5, 1P, 3E20.12)') date, t1900, j, it, alptot(j), Q(it), S(it)
      end if
   end do
   
   DPL = 0.0D0
   if (iMicro == 1) then
      ! LP  : resistance for flow between root and leaf (1/d)
      ! DPL : gradient in pressure head from root to leaf (cm)
      LP  = Lstem_A1 * xTpot + Lstem_A0
      if (LP > 0.0D0) DPL = xTpot/LP
   end if
   
   ! Guessed range for PP: x1 ... x2
   if (iMicro == 1) then
      sumQ  = sum(Q(1:Neq1))
      sumQX = sum(Q(1:Neq1) * X(1:Neq1))
      xp1   = (sumQX + xTpot) / sumQ
      xp2   = sumQX / sumQ
   else
      xp1 = minval(Pav)
      xp2 = maxval(Pav)
   end if
   ! start iterations in findinf xp (= PP)
   k     = 0
   fxp1  = myFun(xp1)
   fxp2  = myFun(xp2)
   xp    = 0.5d0*(xp1+xp2)
   
   ! do while loop: when fxp1*fxp2 < 0 we have found two values xp1 and xp2 inbetween the true value for xp will be present
   do
      !if (fxp1*fxp2 <= 0.0d0 .OR. dabs(fxp1) < Tol_2 .OR. dabs(fxp2) < Tol_2) exit
      if (fxp1*fxp2 <= 0.0d0) exit
      if (k > Ntrial) then
         write(message,'(A,6F15.5)') "k > Ntrial", xTpot, H(1), xp1, xp2, fxp1, fxp2
         call swap_warning ('rwu_micro', message)
         exit
      end if
      funval = myFun(xp)
      if (funval > 0.0d0) then
         xp2  = xp
         xp   = xp/factor
         fxp2 = funval
      else
         xp1  = xp
         xp   = xp*factor
         fxp1 = funval
      end if
      k = k + 1
      if (dabs(fxp1) < Tol_2 .OR. dabs(fxp2) < Tol_2) exit
   end do
   
   ! xp in range [xp1...xp2]
   ! we prefer the final evaluation of myFun once again to be sure that the values for X and xp are up-to-date, and to check convergence
   if (dabs(fxp1) < Tol_2) then
      ! xp1 is close enough to real zero-point: accept as solution
      xp  = xp1
      fxp = fxp1
   else if (dabs(fxp2) < Tol_2) then
      ! xp2 is close enough to real zero-point: accept as solution
      xp  = xp2
      fxp = fxp2
   else
      xp  = zbrend2(myFun, xp1, xp2, fxp1, fxp2, Tol_2)
      fxp = myFun(xp)                                    ! should be nearly zero (< Tol_2)
   end if
   
   ! convergence reached (NB: we assume TolConv > Tol_2)
   if (.NOT. (fxp < TolConv)) then
      check(1) = .FALSE.

      !!!write(123,'(1P,4E20.12)') xp1, xp2, myfun(xp1), myfun(xp2)
      !!!xp = xp1
      !!!do
      !!!   fxp = myfun(xp)
      !!!   write(123,'(1P,2E20.12)') xp, fxp
      !!!   xp = xp - (xp1 - xp2)/100.0d0
      !!!   if (xp < xp2) exit
      !!!end do
      !!!stop
      
   end if

   ! no convergence within Ntrial iterations
   ! TO DO: write message to swap log-file
   if (k > Ntrial) then
      write (unit_log,*) 'rwu_micro: no convergence within NTRIAL iterations.'
      check(2) = .FALSE.
   end if

   ! Final calculations: set return variables 
   ! Tact
   Tact = T_reduction(xp)

   ! Fill Prz and Upw and Upw2
   it = 0
   do j = 1, NL
      if (mask(j)) then
         it      = it + 1                                ! counter for active soil layers
         Prz(j)  = X(it)
         call get_MFLP_K (2, -X(it), jLayer(it), M)
         hroot(it) = -X(it)
         mroot(it) = M
         mflux(it) = Phiav(it)
         if (iMicro == 1) then
            Upw(j) = Q(it) * (xp - X(it))
         else
            !!!Upw(j) = S(it) * (Phiav(it) - M)
            if (swHydrLift == 1) then
               Upw(j) = S(it) * (Phiav(it) - M)
            else
               if (M > Phiav(it)) then
                  Upw(j) = 0.0d0
               else
                  Upw(j) = S(it) * (Phiav(it) - M)
               end if
            end if
         end if
         if (swHydrLift == 1) then
            Upw2(j) = S(it) * (Phiav(it) - M)
         else
            if (M > Phiav(it)) then
               Upw2(j) = 0.0d0
            else
               Upw2(j) = S(it) * (Phiav(it) - M)
            end if
         end if
      end if
   end do
   
   ! Tact2 = sum(Upw2) = sumu must equal Tact1 = sum(Upw) = sumv
   Tact1 = sum(Upw(1:NL))
   Tact2 = sum(Upw2(1:NL))
   if (Tact1 > 0.0d0) then
      if (dabs(Tact1-Tact2)/Tact1 > 0.01d0) then
         check(3) = .FALSE.  ! we should never get here when above proper convergence was reached
      end if
   end if

   ! root water potential, leaf water potential
   if (iMicro == 1) then
      PP = xp
      PL = PP + DPL
   else
      PL = xp
      PP = xp - Tact/Lstem
   end if

   ! Total reduction: needed in rootextraction.f90
   if (Tact1 > 0.0d0) then
      Alpha_micro_tot = Tact1/Tpot
      ! in (unlikely) case Tact1 is slightly larger than Tpot: adapt UPW by ratio Tpot/Tact1
      if (Alpha_micro_tot > 1.0d0) then
         Upw(1:NL)       = Upw(1:NL) / Alpha_micro_tot
         Tact1           = Tact1 / Alpha_micro_tot
         Alpha_micro_tot = 1.0d0
      end if

      ! final return value: note that by returning UPW/Alpha this can be interpreteed as some guess for potential UPW
      !!!Upw(1:NL) = Upw(1:NL)/Alpha_micro_tot
   else
      Alpha_micro_tot = 1.0d0
   end if

   ! Total reduction per compartment
   TotL = sum(Lrv(1:NL)*dz(1:NL))
   do j = 1, NL
      UPWpot(j)          = Lrv(j)*dz(j)/TotL * Tpot
   !!!   ALpha_dry_micro(j) = UPW(j)/UPWpot(j)
   end do

case default

   call swap_error ('rwu_micro', 'Illegal TASK')

end select

end subroutine RWU_micro

subroutine read_rwu_micro_input()
   use plant_interface, only: sw_oxygen
   ! function
   logical :: rdinqr
   
   ! for both iMicro
   Tol_2      =   1.0d-6
   myTolX     =   1.0d-7
   TolConv    =   1.0d-4
   factor     =   1.25d0
   Ntrial     = 500
   swDoSatRel =   0
   swTypeTred =   1
   swHydrLift =   0
   sw_mxdrought = 0
   if (rdinqr('Tol_2'))      call rdsdor ('Tol_2',      1.0d-10, 1.0d-3, Tol_2)
   if (rdinqr('myTolX'))     call rdsdor ('myTolX',     1.0d-10, 1.0d-3, myTolX)
   if (rdinqr('TolConv'))    call rdsdor ('TolConv',    1.0d-10, 1.0d-3, TolConv)
   if (rdinqr('factor'))     call rdsdor ('factor',     1.001d0, 10.0d0, factor)
   if (rdinqr('Ntrial'))     call rdsinr ('Ntrial',     10,      10000,  Ntrial)
   if (rdinqr('swTypeTred')) call rdsinr ('swTypeTred', 1,       2,      swTypeTred)
   if (rdinqr('swDoSatRel')) call rdsinr ('swDoSatRel', 0,       1,      swDoSatRel)
   if (rdinqr('swHydrLift')) call rdsinr ('swHydrLift', 0,       1,      swHydrLift)
   if (swHydrLift > 0 .AND. sw_oxygen > 0) call swap_error ('rwu_micro', 'Hydraulic redistribution combined with oxygenstress is not (yet) allowed.')
   call rdsdor ('HLhalf', -5.0d4, -1.0d3, PLhalf)
   PLhalf = -PLhalf           ! we work with positive values
   PLhalf = 1.0d0/PLhalf      ! for convenience
   if (swTypeTred == 1) call RDsdor ('pcamp',  1.0d0,   5.0d2,  CampA)

   ! for iMicro = 1 or 2
   call rdsdor ('ROOTRADIUS', 1.0d-4,  1.0d0,  RootRadius);     RootRadius2 = RootRadius*RootRadius
   call rdsdor ('KROOT',      1.0d-10, 1.0d-1, Kroot)
   call rdsinr ('swAlpTot',   1,       3,      swAlpTot)
   call rdsinr ('swO2ECT',    0,       3,      swO2EcT)
   if (swO2ECT == 0) call swap_warning('rwu_micro', 'SWO2ECT = 0 is not preferred')
   if (swO2ECT == 3 .AND. swAlpTot /= 3) call swap_error ('rwu_micro', 'SWO2ECT = 3 only in combination with SWALPTOT = 3')
   if (rdinqr('swmxdrought')) call rdsinr ('swmxdrought', 0, 1, sw_mxdrought)

   ! for iMicro = 1
   if (iMicro == 1) then
      call RDsdor ('LSTEM_A1',   1.0d-6,  1.0d-2, Lstem_A1)
      call RDsdor ('LSTEM_A0',   1.0d-6,  1.0d-2, Lstem_A0)
   end if

   ! for iMicro = 2
   if (iMicro == 2) then
      call rdsdor ('ROOTCOEFA',  0.0d0,   1.0d0,  RootCoefA);  RootCoefA2 = RootCoefA*RootCoefA
      call rdsdor ('LSTEM',      1.0d-10, 1.0d1,  Lstem)
      call rdsdor ('ROOTEFF',    0.0d0,   1.0d0,  RootEff)
      call rdsdor ('ROOTXYLEM',  1.0d-4,  1.0d0,  RootXylem)
      if (RootXylem >= RootRadius) call swap_error ('rwu_micro', 'ROOTXYLEM must be less then ROOTRADIUS, e.g. ROOTXYLEM = 0.4 * ROOTRADIUS')
      if (RootXylem >= 0.9d0*RootRadius) call swap_error ('rwu_micro', 'ROOTXYLEM very close to ROOTRADIUS ...')
   end if
end subroutine read_rwu_micro_input

function T_reduction(xp)
real(8), intent(in)  :: xp
real(8)              :: T_reduction, hrel
select case (swTypeTred)
case (1)
      if (xp + DPL < 0.0d0) then
         T_reduction = xTpot
      else
         if (swO2EcT < 3) then
            T_reduction = xTpot/(1.0d0 + ((xp+DPL)*PLhalf)**CampA)
         else
            T_reduction = xTpot/(1.0d0 + ((xp+DPL)*(PLhalf/alptotal))**CampA)
         end if
      end if
   case (2)
      if (iMicro == 1) hrel = (xp+DPL)*PLhalf
      if (iMicro == 2) hrel = xp*PLhalf
      if (hrel < 1.0d0) then
         T_reduction = xTpot
      else if (hrel > 1.0d0) then
         T_reduction = 0.0d0
      else
         T_reduction = sum(Q(1:neq1)*(xp - X(1:neq1)))
      end if
!!!case (3)
!!!   T_reduction = xTpot
!!!   if (xp > 0.5d0/PLhalf) T_reduction = xTpot * max(0.0d0, 1.0d0 - (xp*PLhalf - 0.5d0))
!!!case (4)
!!!   T_reduction = xTpot
!!!   if (xp > 5000.0d0) T_reduction = xTpot * max(0.0d0, 1.0d0 - 1.0d-8*(xp - 5000.0d0)**2)
case default
   call swap_error ('t_reduction', 'Illeal value for iType_Tred')
end select

end function T_reduction

function FG (r)
implicit none
real(8), intent(in)  :: r
real(8)              :: FG, r2
r2 = r*r
FG = 0.5d0*((1.0d0-3.0d0*r2)*0.25d0+r2*r2*dlog(r)/(r2-1.0d0))
end function FG

function myFun (xp)
real(8), intent(in)  :: xp
real(8)              :: myFun
integer              :: k
real(8)              :: b, con, eact, sumu, errX, sumv
real(8)              :: M

if (iMicro == 1) then
   ! initial guess
   X(1:Neq1) = Pav(1:Neq1)
   eact      = T_reduction(xp)

   ! find improved solution
   do k = 1, Ntrial
   
      do j = 1, Neq1
         call get_MFLP_K (2, -X(j), jLayer(j), M, con)
         if (swHydrLift == 1) then
            b       = Q(j)*(xp - X(j)) - S(j)*(Phiav(j) - M)
            delX(j) = -b/(-q(j)-s(j)*con)
         else
            if (M > Phiav(j) .OR. X(j) > xp) then
               x(j)    = xp
               delX(j) = 0.0d0
            else
               b       = Q(j)*(xp - X(j)) - S(j)*(Phiav(j) - M)
               delX(j) = -b/(-q(j)-s(j)*con)
            end if
         end if
      end do
   
      X(1:Neq1) = X(1:Neq1) + delX(1:Neq1)

      ! convergence check: is delX about zero
      errX = sum(dabs(delX(1:Neq)))
      if (errX <= myTolX) exit

   end do

   ! TO DO
   ! what if k > Ntrial or errX > myTolX?
   ! return a large value for myFun???
   ! if (errX > myTolX) write (*,*) "???"

   ! solution found for current guess of xp
   sumu = sum(Q(1:Neq1) * (xp - X(1:Neq1)))

   ! because this function is also used in a zero-root-finding procedure, we subtract eact from sumu (ideally: sumu = sumv = eact)
   if (eact > 0.0d0) then
      myFun = sumu - eact
   else
      sumv = 0.0d0
      do j = 1, Neq1
         call get_MFLP_K (2, -X(j), jLayer(j), M)
         sumv = sumv + S(j)*(Phiav(j) - M)
      end do
      myFun = sumu - sumv
   end if

else if (iMicro == 2) then
   ! initial guess
   X(1:Neq1)    = Pav(1:Neq1)
   eact         = T_reduction(xp)
   delX(1:Neq1) = X(1:Neq1)

   ! find improved solution
   do k = 1, Ntrial
   
      do j = 1, Neq1
         call get_MFLP_K (2, -X(j), jLayer(j), M, con)
         if (swHydrLift == 1) then
            b       = X(j) - xp + Q(j)*(Phiav(j) - M) + eact/Lstem
            delX(j) = -b/(1.0d0 + Q(j)*con)
         else
            if (M > Phiav(j) .OR. X(j) > xp - eact/Lstem) then
               x(j)    = Pav(j)
               delX(j) = 0.0d0
            else  
               b       = X(j) - xp + Q(j)*(Phiav(j) - M) + eact/Lstem
               delX(j) = -b/(1.0d0 + Q(j)*con)
            end if
         end if
      end do
   
      X(1:Neq1) = X(1:Neq1) + delX(1:Neq1)

      ! convergence check: is delX about zero
      errX = sum(dabs(delX(1:Neq)))
      if (errX <= myTolX) exit

   end do

   ! TO DO
   ! what if k > Ntrial or errX > myTolX?
   ! return a large value for myFun???
   ! if (errX > myTolX) write (*,*) "???"

   ! solution found for current guess of xp
   sumu = 0.0d0
   do j = 1, Neq1
      !if (swHydrLift == 1) then
         call get_MFLP_K (2, -X(j), jLayer(j), M)
         sumu = sumu + S(j) * (Phiav(j) - M)
      !end if
   end do

   ! because this function is also used in a zero-root-finding procedure, we subtract eact from sumu (ideally: sumu = eact)
   if (eact > 0.0d0) then
      myFun = sumu - eact
   else
      sumv = 0.0d0
      do j = 1, Neq1
         !!!call get_MFLP_K (2, -X(j), jLayer(j), M)
         !!!X(j) = 1.0d0/PLhalf
         !!!sumv = sumv + Lstem*((xp - X(j)) - Q(j)*(Phiav(j) - M))
         if (swHydrLift == 1) then
            sumv = sumv + S(j) * (Phiav(j))
         end if
      end do
      myFun = sumu - sumv
   end if

end if

! end
end function myFun

!     Adapted: initial FA and FB are input
      real(8) FUNCTION ZBREND2 (FUNC,X1,X2,FA,FB,TOL)
      IMPLICIT NONE
      real(8), intent(in)     :: X1,X2,TOL
      real(8), intent(inout)  :: FA,FB
      real(8)                 :: FUNC
      integer, parameter      :: ITMAX = 100
      real(8), parameter      :: EPS   = 3.D-16
      INTEGER                 :: ITER
      real(8)                 :: A,B,FC,C,D,E,XM,TOL1,P,Q,R,S

      A=X1
      B=X2
!      FA=FUNC(A)
!      FB=FUNC(B)
!      IF (FB*FA > 0.D0) PAUSE 'Root must be bracketed for ZBREND2.'
      FC=FB
      DO ITER=1,ITMAX
        if (FB*FC > 0.D0) THEN
          C=A
          FC=FA
          D=B-A
          E=D
        end if
        if (DABS(FC) < DABS(FB)) THEN
          A=B
          B=C
          C=A
          FA=FB
          FB=FC
          FC=FA
        end if
        TOL1=2.D0*EPS*DABS(B)+0.5D0*TOL
        XM=.5D0*(C-B)
        if (DABS(XM) <= TOL1 .OR. .NOT.(DABS(FB) > 0.D0)) then
          ZBREND2=B
          RETURN
        end if
        if (DABS(E) >= TOL1 .AND. DABS(FA) > DABS(FB)) THEN
          S=FB/FA
          if (.NOT.(DABS(A - C) > 0.0D0)) THEN
            P=2.D0*XM*S
            Q=1.D0-S
          ELSE
            Q=FA/FC
            R=FB/FC
            P=S*(2.D0*XM*Q*(Q-R)-(B-A)*(R-1.D0))
            Q=(Q-1.D0)*(R-1.D0)*(S-1.D0)
          end if
          if (P > 0.D0) Q=-Q
          P=DABS(P)
          if (2.D0*P < DMIN1(3.D0*XM*Q-DABS(TOL1*Q),DABS(E*Q))) THEN
            E=D
            D=P/Q
          ELSE
            D=XM
            E=D
          end if
        ELSE
          D=XM
          E=D
        end if
        A=B
        FA=FB
        if (DABS(D) > TOL1) THEN
          B=B+D
        ELSE
          B=B+SIGN(TOL1,XM)
        end if
        FB=FUNC(B)
      END DO
!      PAUSE 'ZBREND2 exceeding maximum iterations.'
      write (*,*) 'ZBREND2 exceeding maximum iterations.'
      read (*,*)
      ZBREND2=B
      RETURN
      END FUNCTION ZBREND2

! Subroutine get_MFLP_K.
! Based on routine MatricFlux that was available in RootExtraction in version 4.2.0 (and earlier).
! Here extended so that corresponding hydraulic conductivity can be output as well.
! Feb. 2022; Marius Heinen; WENR
!
! NOTE: this routine pre-computes a table with M and K values from which later M and K can be obtained via 
!       lineair interpolation based on input of pressure head H.
!       It has been compared to a situation where M and K were obtained from analytical expressions.
!       The simulated results (tranpiration, yield) were (almost) identical, and, therefore, only the tabulated
!       functionality is active.
!       In case analytical option is required: 
!           - change iMethod to 1 
!           - uncomment some lines
!           - uncomment functions MyMFLP_anal and condd
!           - add file hyp_2F1.f90 to your project
!
subroutine get_MFLP_K (iTask, H, jLayer, M, K)

use MOD_grid,  only: layer, numlay, nod1lay
use MOD_MvG,   only: watcon, hconduc
use variables, only: ksatfit

implicit none

! global
integer,     intent(in)                      :: iTask                   ! Task to perform: 1 = initialize; 2 = obtain M and K
integer,     intent(in),  optional           :: jLayer                  ! Compartment number
real(8),     intent(in),  optional           :: H                       ! Pressure head at which M and K should be determined (cm)
real(8),     intent(out), optional           :: M                       ! Matric flux potential (cm2/d)
real(8),     intent(out), optional           :: K                       ! Hydraulic conductivity (cm/d)

! local
integer, parameter                           :: Mcount    =    801      ! maximum number of entries in M_table/K-table
real(8), parameter                           :: wiltpoint = -20000.0d0  ! lower boundary pressure head in M_table/K-table
integer                                      :: lay, count, start, i
real(8)                                      :: logphead, c0, c1, phead1, phead2, wcontent, conduc1, conduc2
logical                                      :: Kpresent

select case (iTask)
case(1)
   ! initialize M_table (only relevant if iMethod = 2)
   if (iMethod == 2) then
      if (allocated(K_table)) deallocate(K_table); allocate(K_table(Mcount, numlay))
      if (allocated(M_table)) deallocate(M_table); allocate(M_table(Mcount, numlay))
      start = int(100.d0*dlog10(-wiltpoint))
      if (start > Mcount) call swap_error ("get_mflp_k", "Adapt Mcount or wiltpoint in source code.")
      do lay = 1, numlay
         phead1 = -10.d0**(dble(start)/100.d0)
         ! find first Node of the Layer
         i        = nod1lay(lay)
         wcontent = watcon(i, phead1)
         conduc1  = hconduc(i, phead1, wcontent, 10.d0)
         M_table(start,lay) = 0.0d0
         do count = start-1, 1, -1
            phead2             = -10.d0**(dble(count)/100.d0)
            wcontent           = watcon(i, phead2)
            conduc2            = hconduc(i, phead2, wcontent, 10.d0)
            K_table(count,lay) = conduc2
            M_table(count,lay) = M_table(count+1,lay) + 0.5d0 * (conduc1 + conduc2) * (phead2 - phead1) 
            phead1             = phead2
            conduc1            = conduc2
         end do
      end do
   end if

case(2)
   Kpresent = present(K)
   if (iMethod == 1) then
!      M = MyMFLP_anal (H, jLayer)
!      if (Kpresent) K = condd (H, jLayer)
   else
      lay = layer(jLayer)
!     matric flux potential based on soil water pressure head
      if (H < wiltpoint) then
!        very dry range 
         M = 0.0d0
         if (Kpresent) K = 0.0d0
      else if (H > -1.023293d0) then
!        very wet range (> -10^0.01)
         M = M_table(1,lay) + (H+1.023293d0)*ksatfit(lay)
         if (Kpresent) K = ksatfit(lay)
      else  
!        direct access table, with linear interpolation
         logphead = 100.d0*dlog10(-H)
         count    = int(logphead)
         c0       = dble(count)
         c1       = dble(count+1)
         M        = (logphead-c0)*M_table(count+1,lay) + (c1-logphead)*M_table(count,lay)
         if (Kpresent) K = (logphead-c0)*K_table(count+1,lay) + (c1-logphead)*K_table(count,lay)
      end if
   end if

case default
   call swap_error ('get_mflp_k', 'Illegal iTask value')

end select

end subroutine get_MFLP_K
   
!!!function MyMFLP_anal (H, jLayer)
!!!!
!!!! Computation of matric flux potential according to:
!!!! De Jong Van Lier, Q. D.D. Neto, and K. Metselaar. 2009. 
!!!!     Modeling of transpiration reduction in van Genuchten-Mualem type soils
!!!!     WATER RESOURCES RESEARCH, VOL. 45, W02422, doi:10.1029/2008WR006938
!!!! Their equations [A-10] to [A-14]. However, their Eq. [A-10] (and [A-11]) contained an error, 
!!!! their f1 and f2 should be used both with their THETA_a and THETA_w.
!!!!
!!!! The Gauss hypergeometric functions f1 and f2 are here calculated according to:
!!!! Michel, N., and M.V. Stoitsov. 2007.
!!!!     Fast computation of the Gauss hypergeometric function with all its parameters
!!!!     complex with application to the Poschl-Teller-Ginocchio potential wave functions.
!!!!     Computer Physics Communications 178 (2008) 535-551. doi:10.1016/j.cpc.2007.11.007.
!!!! The authors made available the sources of routines to do the computations (Hyp_2F1.f90).
!!!! 
!!!
!!!use SoilPropertiesInfo
!!!
!!!implicit none
!!!
!!!integer,     intent(in) :: jLayer
!!!real(8),     intent(in) :: H
!!!
!!!complex(8)    :: cKs, cn, cm, calpha, clambda, nu, help
!!!complex(8)    :: Sref, Fref
!!!!real(8)       :: test1, test2
!!!complex(8)    :: Se, Phi
!!!real(8)       :: MyMFLP_anal
!!!
!!!!MyMFLP = Ksat/alpha*dexp(-alpha*dabs(H)); return
!!!
!!!! soil parameters: we need complex values
!!!calpha  = dcmplx(Alphad(jLayer))
!!!cn      = dcmplx(Nd(jLayer))
!!!cm      = dcmplx(Md(jLayer))
!!!clambda = dcmplx(Lab(jLayer))
!!!cKs     = dcmplx(Ksat(jLayer))
!!!
!!!! help variables (all complex)
!!!!!!cm     = (1.0d0,0.0d0)-(1.0d0,0.0d0)/cn
!!!nu     = cm*(clambda+(1.0d0,0.0d0))
!!!help   = cKs*((1.0d0,0.0d0)-cm)/(calpha*(nu-(1.0d0,0.0d0)))
!!!
!!!! S and F at reference pressure head, here chosen to be 10^7
!!!Sref   = ((1.0d0,0.0d0) + (calpha*cmplx(10.0d0**12,0.0d0))**cn)**(-cm)
!!!Fref   = Sref**((1.0d0,0.0d0)-(1.0d0,0.0d0)/cm+clambda) * (f1(Sref)+f2(Sref)-(2.0d0,0.0d0))
!!!
!!!! current degree of saturation (Se) and matric flux potential (Phi)  (complex)
!!!if (H <= 0.0d0) then
!!!   Se  = ((1.0d0,0.0d0) + (calpha*dcmplx(dabs(h),0.0d0))**cn)**(-cm)
!!!   Phi = help*(Se**((1.0d0,0.0d0)-(1.0d0,0.0d0)/cm+clambda) * (f1(Se)+f2(Se)-(2.0d0,0.0d0))- Fref)
!!!else
!!!! if saturated, then add Ksat*dabs(H)
!!!   Se  = ((1.0d0,0.0d0) + (calpha*dcmplx(0.0d0,0.0d0))**cn)**(-cm)
!!!   Phi = help*(Se**((1.0d0,0.0d0)-(1.0d0,0.0d0)/cm+clambda) * (f1(Se)+f2(Se)-(2.0d0,0.0d0))- Fref)
!!!   Phi = Phi + cKs * dcmplx(H,0.0d0)
!!!end if
!!!
!!!! set output value; and we are ready
!!!MyMFLP_anal = dble(Phi)
!!!
!!!!if (dabs(Test1) > 1.0d-06 .OR. dabs(Test2) > 1.0d-06) then
!!!!   write (124,'(1P,9E20.12)') h, dble(Phi), phi2, phi3, test1, test2
!!!!   write (124,'(1P,9E20.12)') h, dble(Phi), test1, test2
!!!!end if
!!!
!!!!***********************************************************
!!!contains
!!!
!!!function f1(x)
!!!implicit none
!!!!real(8) :: TEST_2F1
!!!complex(8) :: f1, x
!!!complex(8) :: hyp_2f1  !, hypgeo
!!!!f1=hypgeo(-cm,nu-(1.0d0,0.0d0),nu,x**((1.0d0,0.0d0)/cm))
!!!f1=hyp_2f1(-cm,nu-(1.0d0,0.0d0),nu,x**((1.0d0,0.0d0)/cm))
!!!!TEST1=TEST_2F1(-cm,nu-(1.0d0,0.0d0),nu,x**((1.0d0,0.0d0)/cm),f1)
!!!end function f1
!!!
!!!function f2(x)
!!!implicit none
!!!!real(8) :: TEST_2F1
!!!complex(8) :: f2, x
!!!complex(8) :: hyp_2f1  !, hypgeo
!!!!f2=hypgeo(cm,nu-(1.0d0,0.0d0),nu,x**((1.0d0,0.0d0)/cm))
!!!f2=hyp_2f1(cm,nu-(1.0d0,0.0d0),nu,x**((1.0d0,0.0d0)/cm))
!!!!TEST2=TEST_2F1(cm,nu-(1.0d0,0.0d0),nu,x**((1.0d0,0.0d0)/cm),f2)
!!!end function f2
!!!
!!!end function MyMFLP_anal
!!!
!!!!-----------------------------------------------------------------------*
!!!! Function CONDD                                                        *
!!!!                                                                       *
!!!! Purpose   : Calculation of hydraulic conductivity from pressure head  *
!!!!             by van Genuchten function.                                *
!!!!                          {(1 + |ALPHA*H|^N)^M - |ALPHA*H|^(N-1)}^2    *
!!!! Equation  : CONDD = KS * -----------------------------------------    *
!!!!                                 (1+|ALPHA*H|^N)^((L+2)*M)             *
!!!!             M     = 1.-1./N, N > 1                                    *
!!!!                                                                       *
!!!!  FORMAL PARAMETERS:  (I=input,O=output,C=control,IN=init,T=time)      *
!!!!  name   type meaning                                    units  class  *
!!!!  ----   ---- -------                                    -----  -----  *
!!!!  N      R8   curve shape parameter                      -       I     *
!!!!  ALPHA  R8   curve shape parameter                      cm-1    I     *
!!!!  KS     R8   saturated hydraulic conductivity           cm/d    I     *
!!!!  H      R8   pressure head (<= 0)                       cm      I     *
!!!!  CONDD  R8   hydraulic conductivity                     cm/d    O     *
!!!!                                                                       *
!!!! Subroutines/functions called: none.                                   *
!!!!                                                                       *
!!!!-----------------------------------------------------------------------*
!!!
!!!!---- declarations
!!!function CONDD(H, jLayer)
!!!
!!!use SoilPropertiesInfo
!!!implicit none
!!!
!!!! global
!!!integer, intent(in) :: jLayer
!!!real(8), intent(in) :: H
!!!real(8)             :: CONDD
!!!! locals
!!!real(8)             :: ah, h1, h2, denom
!!!      
!!!! if pressure head is positive or zero then saturated conductivity
!!!if (h >= 0.d0) then
!!!   CONDD = Ksat(jLayer)
!!!   return
!!!end if
!!!
!!!! compute some dummies and conductivity
!!!ah    = Alphad(jLayer)*dabs(h)
!!!h1    = (1.d0 + ah**Nd(jLayer))**Md(jLayer)
!!!h2    = ah**(Nd(jLayer) - 1.d0)
!!!denom = (1.d0 + ah**Nd(jLayer))**(Md(jLayer) * (Lab(jLayer) + 2.d0))
!!!CONDD = Ksat(jLayer) * (h1-h2)**2/denom
!!!
!!!!condd = Ksat(jLayer)*dexp(-ALPHAD(jLayer)*dabs(H))
!!!
!!!! end
!!!return
!!!end function CONDD

end module mod_RWU_micro
