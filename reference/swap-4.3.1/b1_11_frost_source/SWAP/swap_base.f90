module MOD_swap_base

   use MOD_arrays, only: macp, maho
   use MOD_grid,   only: isoillay, hsublay, hcomp, ncomp, nsublay, numlay
   
   implicit none

   ! special for coupling with ANIMO
   integer, save :: sw_animo = 0                            ! yes (1) or no (0) call ANIMO
   
   ! special for coupling with ANIMO
   integer, save :: sw_multi_swap    = 0                    ! switch indicating SWAP modus: 0 = SWAP stand-alone; 1 = multi-SWAP
   integer, save :: i_instance       = 0                    ! instance number in case of multiSWAP
   integer, save :: i_core           = 0                    ! core number in case of multiSWAP
   integer, save :: id_soil          = 0                    ! soil profile ID in soils database
   integer, save :: id_rotation      = 0                    ! rotation ID in crop calendar database
   integer, save :: id_crop          = 0                    ! crop type ID in crops database
   integer, save :: id_meteo         = 0                    ! meteo ID in meteo database
   integer, save :: id_meteo_station = 0                    ! meteo station ID in meteo database
   integer, save :: i_iter           = 0                    ! iteration counter

   logical, save :: fl_do_not_read_crpfile = .FALSE.        ! do not read crp files during simulation (set to TRUE when using crops database in multi-SWAP)

   ! SWAP default
   integer, save :: iun_min  = 100                          ! for getun: lowest possible unit number
   integer, save :: iun_max  = 790                          ! for getun: highest possible unit number
   integer, save :: iun_min2 = 800                          ! for getun2: lowest possible unit number
   integer, save :: iun_max2 = 990                          ! for getun2: highest possible unit number
   integer, save :: unit_swp = 0                            ! unit number of swp-file (main input)
   integer, save :: unit_log = 0                            ! unit number of log-file (logging)
   integer, save :: unit_wrn = 0                            ! unit number of wrn-file (warnings)
   logical, save :: first_wrn = .TRUE.                      ! logical for first warning
   integer, save :: unit_err = 0                            ! unit number of err-file (error)
   integer, save :: unit_ini = 0                            ! unit number of ini-file (initial conditions)
   
   character(len = 80), save :: swpfilnam, logfilnam, errfilnam, wrnfilnam, inifilnam
   character(len = 80), save :: project
   
   character(len = 80), save :: pathwork = ' '
   character(len = 80), save :: pathatm = ' '
   character(len = 80), save :: pathcrop = ' '
   character(len = 80), save :: pathdrain = ' '
   character(len = 80), save :: pathrunon = ' '
   character(len = 80), save :: pathsnm = ' '
   
   logical, save :: toscr                                   ! messages to screen (set by swerror)
   integer, save :: swscre     = 0                          ! switch of screen display: 0 = no display; 1 = summary water balance; 2 = daynumber
   integer, save :: swcrop     = 1                          ! switch for simulating crop growth: 0 = no; 1 = yes
   integer, save :: swcropsnm  = 0                          ! switch for simulating crop soil nitrogen: 0 = no; 1 = yes
   integer, save :: swhea      = 0                          ! switch for simulation of soil heat flow: 0 = no; 1 = yes
   integer, save :: swcalt     = 0                          ! switch for method of soil water heat flow simulation: 1 = analytical method; 2 = numerical method
   integer, save :: swsolu     = 0                          ! switch for simulation of solute transport: 0 = no; 1 = yes
   integer, save :: swtill     = 0                          ! switch: 0 = no tillage; 1 = tillage
   integer, save :: swfrost    = 0                          ! switch for reduction of hydraulic conductivity in case of frost: 0 = no; 1 = yes
   integer, save :: swsnow     = 0                          ! switch for simulation of snow accumulation and melt: 0 = no; 1 = yes
   integer, save :: swdra      = 0                          ! switch for simulation of lateral drainage: 0 = no drainage; 1 = use basic drainage routine; 2 = simulate drainage and surface water
   integer, save :: swmacro    = 0                          ! switch indicating macropore option active: 0 = no; 1 = yes
   integer, save :: swetr      = 0                          ! switch: 0 = use meteorological basic data; 1 = use daily Etref values
   integer, save :: swrain     = 0                          ! switch: 0 = use daily rain amounts; 1 = use daily amounts + mean intensity; 2 = use daily amounts + duration; 3 = use detailed rainfall data from separate file
   integer, save :: swmetdetail= 0                          ! switch: 0 = daily meteorological records; 1 = detailed records for both ET and rainfall
   integer, save :: swirfix    = 0                          ! Switch for fixed irrigation: 0 = no applications prescribed; 1 = applications are prescribed
   integer, save :: swrunon    = 0                          ! Consider runon: 0  not, 1 = yes
   integer, save :: swpondmx   = 0                          ! Switch for time dependent maximum amount of ponding (L) on soil surface before runoff starts
   integer, save :: swhyst     = 0                          ! Switch for hysteresis of soil moisture retention function:
                                                            !        0 = no hysteresis
                                                            !        1 = hysteresis, initial condition wetting
                                                            !        2 = hysteresis, initial condition drying

   integer, save :: swsolve    = 0                          ! switch for solution (solve) procedure: 
                                                            !        1 : solve Richards numerically (HeadCalc)
                                                            !        2 : use SSS (sequential Steady-State function)

   integer, save :: swinco = 2                              ! switch for initial soil moisture condition: 1 = pressure heads; 2 = hydrostatic equilibrium; 3 = final pressure heads from previous simulation
   integer, save :: sw_initype = 1                          ! Switch for type of output file *.END with end conditions of previous simulation: 1 = formatted; 2 = unformatted
   integer, save :: sw_end = 1                              ! Switch for output file *.END with end conditions: 0 = no; 1 = end of simulation; 2 = each day
   integer, save :: sw_endtype = 1                          ! Switch for type of output file *.END with end conditions: 1 = formatted; 2 = unformatted
   integer, save :: sw_endfilter = 0                        ! Switch for filter of output file *.END with end conditions: 0 = no filter; 1 = only if stress occured
   
   logical, save :: fl_initialize = .FALSE.                 ! flag, initialize conditions

   public
   private :: read_soil_layer, read_texture_orgmat, calcgrid
   
   contains
   
   subroutine swap_configuration(swp_file)
   implicit none
   ! global
   character(len=*), intent(in), optional :: swp_file

   if (sw_multi_swap == 0) then
      if (present(swp_file)) then
         call get_swp_file(swp_file = swp_file)
      else
         call get_swp_file
      end if
      call read_environment
      call check_obsolete_deprecated
      call read_switches
   end if
   
   if (id_soil == 0) then
      call read_soil_layer
      call read_texture_orgmat
      call calcgrid
   end if
   
   end subroutine swap_configuration
   
   subroutine get_swp_file(swp_file)
   use TTutilPrefs, only: FatalErrorMode, SetExceptionFile
   implicit none
   ! global
   character(len=*), intent(in), optional :: swp_file
   ! local
   integer :: getun, getun2
   integer :: PosArg, NumChar
   logical :: file_exists
   character(len=200) :: message
     
      if (present(swp_file)) then
         swpfilnam = swp_file
      else
   ! --- path and filename of executable through argument command line
         PosArg = 1
         Call Get_Command_Argument (PosArg, swpfilnam, NumChar)
         if (NumChar < 1) swpfilnam = 'swap'
         project = swpfilnam

         if (NumChar > 3) then
            if (swpfilnam(NumChar-3:NumChar) == '.swp' .OR. swpfilnam(NumChar-3:NumChar) == '.SWP') then
               swpfilnam = trim(swpfilnam)
            else
               swpfilnam = trim(swpfilnam) // '.swp'
            end if
         else 
           swpfilnam = trim(swpfilnam) // '.swp'
         end if

         ! pathwork as 2nd argument?
         PosArg = 2
         Call Get_Command_Argument (PosArg, pathwork, NumChar)
         if (NumChar < 1) pathwork = ' '
         
      end if
      Numchar = len(trim(swpfilnam))
      logfilnam = trim(pathwork)//swpfilnam(1:NumChar-4)//'.log'
      errfilnam = trim(pathwork)//swpfilnam(1:NumChar-4)//'.err'
      wrnfilnam = trim(pathwork)//swpfilnam(1:NumChar-4)//'.wrn'
      swpfilnam = trim(pathwork)//trim(swpfilnam)

      ! --- delete existing files: swap.ok, err, log, wrn
      call delfil ('swap.ok', .FALSE.)
      !call delfil (wrnfilnam, .FALSE.)

      ! open err-file
      if (unit_err == 0) then
         unit_err = getun (iun_min, iun_max)
         call fopens (unit_err, errfilnam, 'new', 'del')
      end if

!     redirect TTutil error messages to own error file
      FatalErrorMode = 3
      call SetExceptionFile (unit_err, errfilnam)

      ! open log-file
      if (unit_log > 0) then
         close(unit_log, status = 'delete')
      else
         unit_log = getun (iun_min, iun_max)
      end if
      call fopens(unit_log,logfilnam,'new','del')
      
      ! close old wrn-file (in case of re-run)
      if (unit_wrn > 0) then
         close(unit_wrn, status = 'delete')
         first_wrn = .TRUE.
      end if

      ! open swp-file
      inquire(file = swpfilnam, exist = file_exists)
      if (.NOT. file_exists) then
         message ='File '//trim(swpfilnam)//' does not exists!'
         call swap_error ('swap', message)
      end if
      unit_swp = getun2 (iun_min2, iun_max2, 2)
      call rdinit(unit_swp, unit_err, swpfilnam)
      close(unit_swp)

   end subroutine get_swp_file   

   subroutine read_environment
   
      implicit none
   
      logical :: rdinqr
   
      call rdinit(unit_swp, unit_err, swpfilnam)
      
      call rdscha ('project', project)
      !call rdscha ('pathwork', pathwork)
      
      if (rdinqr('pathatm')) then
         call rdscha ('pathatm', pathatm)
      else
         pathatm = ''
      end if
      
      if (rdinqr('pathcrop')) then
         call rdscha ('pathcrop', pathcrop)
      else
         pathcrop = ''
      end if
      
      if (rdinqr('pathdrain')) then
         call rdscha ('pathdrain', pathdrain)
      else
         pathdrain = ''
      end if
      
      if (rdinqr('pathrunon')) then
         call rdscha ('pathrunon', pathrunon)
      else
         pathrunon = ''
      end if
      
      if (rdinqr('pathsnm')) then
         call rdscha ('pathsnm', pathsnm)
      else
         pathsnm = ''
      end if

      close(unit_swp)

   end subroutine read_environment
   
   subroutine read_switches

      implicit none
   
      ! local
      integer              :: swerror
      character(len=400)   :: message
      logical              :: file_exists
   
      ! functions
      integer              :: getun2
      logical              :: rdinqr
   
      ! open connection (swp-file)
      call rdinit(unit_swp, unit_err, swpfilnam)

      if (rdinqr('id_soil')) call rdsint ('id_soil', id_soil)
      
      call rdsinr ('swscre',0,2,swscre)
      call rdsinr ('swerror',0,1,swerror); toscr = swerror == 1
      call messini(toscr,.FALSE.,0)
      
      if (rdinqr('swcrop')) call rdsinr ('swcrop',0,1,swcrop)
      
      if (swcrop == 1) then
         if (rdinqr('swcropsnm')) call rdsinr ('swcropsnm',0,1,swcropsnm)
      end if
      
      call rdsinr('swhea', 0, 1, swhea)
      if (swhea == 1) call rdsinr ('swcalt', 1, 2, swcalt)
      call rdsinr('swsolu', 0, 2, swsolu)
      if (RDinqr('swtill')) call RDsinr('swtill', 0, 1, swtill)
      call rdsinr ('swsnow',0,1,swsnow)
      call rdsinr ('swfrost',0,1,swfrost)
      call rdsinr ('swdra',0,2,swdra)
      call rdsinr ('swmacro',0,1,swmacro)
      call rdsinr ('swhyst',0,2,swhyst)
      call rdsinr ('swpondmx',0,1,swpondmx)
      swsolve = 1
      if (rdinqr('swsolve')) call rdsinr ('swsolve',1,2,swsolve)

      if (rdinqr('swetr'))       call rdsinr ('swetr',0,1,swetr)
      if (rdinqr('swrain'))      call rdsinr ('swrain',0,3,swrain)
      if (rdinqr('swmetdetail')) call rdsinr ('swmetdetail',0,1,swmetdetail)

      ! initial conditions
      call rdsinr ('swinco', 0, 3, swinco)
      if (swinco == 3) then
        call rdscha ('inifil', inifilnam)
        if (rdinqr('swinitype')) call rdsinr ('swinitype',1,2,sw_initype)
      end if

      if (rdinqr('swend')) call rdsinr ('swend',0,2,sw_end)
      if (rdinqr('swendtype')) call rdsinr ('swendtype',1,2,sw_endtype)
      if (rdinqr('swendfilter')) call rdsinr ('swendfilter',0,1,sw_endfilter)
      
      close(unit_swp)

      fl_initialize = .FALSE.

      if (swinco == 3) then

         fl_initialize = .TRUE.

         inquire(file = inifilnam, exist = file_exists)
         if (.NOT. file_exists) then
            message ='File ' // trim(inifilnam) // ' does not exists!'
            call swap_error ('readswap', message)
         end if        

         unit_ini = getun2 (iun_min2, iun_max2, 2)
         if (sw_endtype == 1) then
            call rdinit(unit_ini, unit_err, inifilnam)
            close(unit_ini)
         end if

      end if

   end subroutine read_switches
   
   subroutine check_obsolete_deprecated
   implicit none
   ! local
   ! functions
   logical :: RDinqr
   call rdinit(unit_swp, unit_err, swpfilnam)
      if (RDinqr('flagetracer')) call swap_error('check_obsolete_deprecated', 'flagetracer is obsolete; you must specify swsolu = 2 instead')
   close(unit_swp)

   end subroutine check_obsolete_deprecated

   subroutine read_soil_layer
   
   implicit none
   
   ! local
   integer                  :: i, ifnd
   integer, dimension(macp) :: isublay
   character(len=132)       :: message
   
   call rdinit(unit_swp, unit_err, swpfilnam)
   
   ! vertical discretization of soil profile
   call rdainr ('isoillay', 1,    maho,     isoillay, maho, ifnd)
   call rdfinr ('isublay',  1,    macp,     isublay,  macp, ifnd)
   call rdfdor ('hsublay',  0.d0, 10000.d0, hsublay,  macp, ifnd)
   call rdfinr ('ncomp',    0,    macp,     ncomp,    macp, ifnd)
   
   close(unit_swp)
   
      nsublay = ifnd
      numlay = isoillay(ifnd)


      do i = 1, nsublay

         ! set thickness of compartments in sublayer (hcomp)
         hcomp(i) = hsublay(i) / dble(ncomp(i))
         if (hcomp(i) > 1000.d0) then
            message = 'HCOMP exceeding maximum thickness [0..1000,cm]: adjust NCOMP'
            call swap_error ('read_soil_layer', message)
         end if
         
         ! check sequence soil layers
         if (i == 1) then
            
            if (isublay(1) /= 1) then
               message = 'Adjust vert.discr. soil profile: ISUBLAY(1) must be 1'
               call swap_error ('read_soil_layer', message)
            end if
            
            if (isoillay(1) /= 1) then
               message = 'Adjust vert.discr.soil profile: ISOILLAY(1) must be 1'
               call swap_error ('read_soil_layer', message)
            end if
         
         else

            if (isublay(i) - isublay(i-1) /= 1) then
              message = 'Adjust vert. discr. soil profile: ISUBLAY must be in increasing order (step = 1)'
              call swap_error ('read_soil_layer', message)
            end if
           
            if (isoillay(i) - isoillay(i-1) /= 0 .AND. isoillay(i) - isoillay(i-1) /= 1) then
              message = 'Adjust vert. discr. soil profile: ISOILLAY must be in increasing order (step = 0 or 1)'
              call swap_error ('read_soil_layer', message)
            end if

         end if
         
      end do

   end subroutine read_soil_layer

   subroutine read_texture_orgmat
   
   use MOD_texture_orgmat, only: orgmat, pclay, psand, psilt, bdens
   implicit none
   logical :: rdinqr, rdinar
   
   if (swhea == 1 .AND. swcalt == 2) then
      
      ! allocate
!      if (allocated(orgmat)) deallocate(orgmat); allocate(orgmat(numlay))
!      if (allocated(pclay))  deallocate(pclay);  allocate(pclay(numlay))
!      if (allocated(psand))  deallocate(psand);  allocate(psand(numlay))
!      if (allocated(psilt))  deallocate(psilt);  allocate(psilt(numlay))
   
      ! load settings
      call rdinit(unit_swp, unit_err, swpfilnam)
         call rdfdor ('psand', 0.0d0,1.0d0,psand, numlay,numlay)
         call rdfdor ('psilt', 0.0d0,1.0d0,psilt, numlay,numlay)
         call rdfdor ('pclay', 0.0d0,1.0d0,pclay, numlay,numlay)
         call rdfdor ('orgmat',0.0d0,1.0d0,orgmat,numlay,numlay)
      close(unit_swp)
   
   end if
   
   ! bulk density required for oxygen stress and solute transport
   call rdinit(unit_swp, unit_err, swpfilnam)
   if (rdinqr('bdens')) then
!      if (allocated(bdens))  deallocate(bdens);  allocate(bdens(numlay))
      if (rdinar('bdens')) then
         call rdfdor ('bdens',100.0d0,10000.0d0,bdens,numlay,numlay)
      else
         call rdsdor ('bdens',100.0d0,10000.0d0,bdens(1)); if (numlay > 1) bdens(2:numlay) = bdens(1)
      end if
   end if
   close(unit_swp)
   
   end subroutine read_texture_orgmat

! ----------------------------------------------------------------------
   subroutine calcgrid 
! ----------------------------------------------------------------------
!     Date               : Aug 2004   
!     Purpose            : calculate grid parameters
! ----------------------------------------------------------------------
      use MOD_grid
      implicit none
      
      integer              :: i,j,lay,node,layold
      character(len=200)   :: message
      character(len=11)    :: tmp

! --- check correct input of number and height of soil compartments
      do i = 1, nsublay
        if (abs(ncomp(i)*hcomp(i) - hsublay(i)) > 1.d-5) then
! ---     error in input data
          write(tmp,'(i11)') i
          tmp = adjustl(tmp)
          message = 'The height of soil layer hsublay does not correspond to the product of height and number of compartments at layer ' // trim(tmp)
          call swap_error ('calcgrid', message)
        end if
      end do

! --- position of nodal points and distances between them; also layer 
! --- of each node
      node = 0
      do i = 1, nsublay
        do j = 1, ncomp(i)
          node     = node + 1
          dz(node) = hcomp(i)          
          if (node == 1) then
            z(node)      = - 0.5d0 * dz(node)
            disnod(node) = - z(node)
            layer(node)  = isoillay(i)
          else
            z(node)      = z(node-1) - 0.5d0*(dz(node-1)+dz(node))
            disnod(node) = z(node-1)-z(node)
            layer(node)  = isoillay(i)
          end if
        end do
      end do
      numnod           = node
      disnod(numnod+1) = 0.5d0*dz(numnod)

!     store top and bottom depths of each compartment (2019-05-17, MH)
      do i = 1, numnod
         if (i == 1) then
            ztopcp(i) = 0.0d0
            zbotcp(i) = -dz(i)
         else
            ztopcp(i) = zbotcp(i-1)
            zbotcp(i) = zbotcp(i-1) - dz(i)
         end if
      end do      
      
! --- determine bottom compartment of each soil layer
      layold = 1
      do node = 1, numnod
        if (layer(node) > layold) then
          botcom(layold) = node - 1
          layold         = layold + 1
        end if
      end do
      numlay         = layold
      botcom(numlay) = numnod

! --- linear interpolation values between nodes
      inpolb(1) = 0.5d0*dz(1)/disnod(2)
      do node = 2,numnod-1
        inpola(node) = 0.5d0*dz(node)/disnod(node)
        inpolb(node) = 0.5d0*dz(node)/disnod(node+1)
      end do
      inpola(numnod) = 0.5d0*dz(numnod)/disnod(numnod)

! --- find first Node of the Layer
      do lay = 1,numlay
        Node = 1
        do while(Layer(Node) /= lay)
           Node = Node + 1
        end do
        nod1lay(lay) = node
      end do

      return
   end subroutine calcgrid

   subroutine swap_invoke
      use MOD_description
      ! local
      integer              :: posarg, numchar
      character(len = 50)  :: argument
      posarg = 1
      call get_command_argument (posarg, argument, numchar)
      if (numchar > 0) then
         argument = adjustl(trim(argument))
         if (trim(argument) == '-version' .OR. trim(argument) == '--version') then
            write(*,*) 
            write(*,*) 'You are using SWAP version ',  adjustl(trim(version))
            write(*,*) 
            stop
         else if (trim(argument) == '-help' .OR. trim(argument) == '--help' .OR. trim(argument) == '-?' .OR. trim(argument) == '--?') then
            write(*,*) 
            write(*,*) 'SWAP version ', adjustl(trim(version))
            write(*,*) 
            write(*,*) 'When SWAP is started without argument it runs from local directory'
            write(*,*) 'and expects a local data file named swap.swp.'
            write(*,*) 
            write(*,*) 'When SWAP is started with one argument representing the name of the' 
            write(*,*) 'main data input file it uses that file.'
            write(*,*) '   If no extension is present in the user-upplied main input file'
            write(*,*) '   SWAP assumes .swp as extension.'
            write(*,*) 
            write(*,*) 'For details regarding starting SWAP and the contents of the input files,'
            write(*,*) 'the user is referred to the manual.'
            write(*,*) 
            write(*,*) 'When SWAP is started with argument -version or --version, '
            write(*,*) '     SWAP returns it version number and the program halts.'
            write(*,*) 
            write(*,*) 'When SWAP is started with argument -help or --help, '
            write(*,*) '     SWAP returns the current screen and the program halts.'
            write(*,*) 
            stop
         end if
      end if
      return
   end subroutine swap_invoke

end module MOD_swap_base
