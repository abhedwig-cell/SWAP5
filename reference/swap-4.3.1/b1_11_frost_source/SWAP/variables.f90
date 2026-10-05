! File VersionID:
!   $Id: variables.f90 378 2018-05-08 13:50:52Z heine003 $
! ----------------------------------------------------------------------
! File Name:    variables.for
! Content:      common variables of modular SWAP code
! Sections:     time & control, meteo, irrigation, crop, soilwater, macropore, surfacewater, heat, snow, solute

module MOD_grid
   use MOD_arrays, only: maho, macp
   implicit none
   integer, dimension(maho),   save :: botcom       ! Array with number of bottom compartments in each soil layer
   integer, dimension(macp),   save :: isoillay     ! Number of soil layer, starting with 1 at the soil surface
   integer, dimension(macp),   save :: layer        ! Array with soil layer number for each compartment
   integer, dimension(macp),   save :: ncomp        ! Array with number of compartments in each sublayer
   integer, dimension(maho),   save :: nod1lay      ! node nr of first node of each soil layer (from top to bottom)
   integer,                    save :: nsublay      ! Number of sublayers in the soil profile
   integer,                    save :: numlay       ! Number of (physical) soil layers
   integer,                    save :: numnod       ! Number of nodes or compartments
   real(8), dimension(macp+1), save :: disnod       ! Distance between actual node and upper node (L)
   real(8), dimension(macp),   save :: dz           ! Compartment thickness (L)
   real(8), dimension(macp),   save :: hcomp        ! Array with prescribed height of numerical compartments (L) for each sublayer
   real(8), dimension(macp),   save :: hsublay      ! Array with prescribed height of sublayers (L)
   real(8), dimension(macp),   save :: inpola       ! Weight for interpolation between current node and upper node
   real(8), dimension(macp),   save :: inpolb       ! Weight for interpolation between current node and lower node
   real(8), dimension(macp),   save :: z            ! Depth of a node (L)
   real(8), dimension(macp),   save :: ztopcp       ! Depth of top    boundary of layer(node) (L)
   real(8), dimension(macp),   save :: zbotcp       ! Depth of bottom boundary of layer(node) (L)
end module MOD_grid

module MOD_texture_orgmat
   use MOD_arrays, only: maho
   implicit none
   ! per soil horizon or soil layer
   real(8), dimension(maho), save ::   orgmat       ! Array with gravimetric organic matter content (g/g mineral parts) for each soil layer
   real(8), dimension(maho), save ::   pclay        ! Array with gravimetric clay content (g/g mineral parts) for each soil layer
   real(8), dimension(maho), save ::   psand        ! Array with gravimetric sand content (g/g mineral parts) for each soil layer
   real(8), dimension(maho), save ::   psilt        ! Array with gravimetric silt content (g/g mineral parts) for each soil layer
   real(8), dimension(maho), save ::   bdens        ! Array with dry bulk density for each soil layer (M/L3)
end module MOD_texture_orgmat
   
module parameters
   implicit none
   real(8), parameter :: pi = 3.141592653589793238462643383279502884197d0
   real(8), parameter :: radial = pi / 180.d0
end module parameters

module MOD_re_global
   use MOD_arrays, only: macp
   public
   real(8), dimension(:),    allocatable, save  :: alpwet, alpsol, alpfrs, alpdry, alptot
   real(8), dimension(macp),              save  :: hroot              ! Pressure head of a compartment at the root-soil interface (L)
   real(8), dimension(macp),              save  :: mflux              ! Actual matric flux potential of each node (L2/T)
   real(8), dimension(macp),              save  :: mroot              ! Matrix flux head of a compartment at the root-soil interface (L2/T)
   real(8), dimension(macp),              save  :: qpotrot            ! Array with potential root water extraction flux for each compartment (L/T)
   real(8),                               save  :: qrosum             ! Total root water extraction flux (L/T)
   real(8),                               save  :: qredwetsum         ! Total reduction of root water extraction due to wet conditions (L/T)
   real(8),                               save  :: qreddrysum         ! Total reduction of root water extraction due to dry conditions (L/T)
   real(8),                               save  :: qredsolsum         ! Total reduction of root water extraction due to salt conditions (L/T)
   real(8),                               save  :: qredfrssum         ! Total reduction of root water extraction due to frost conditions (L/T)
   real(8), dimension(macp),              save  :: qredwet            ! Array with reduction of root water extraction due to wet conditions for each compartment (L/T) (SWDROUGHT=1)
   real(8), dimension(macp),              save  :: qreddry            ! Array with reduction of root water extraction due to dry conditions for each compartment (L/T) (SWDROUGHT=1)
   real(8), dimension(macp),              save  :: qredsol            ! Array with reduction of root water extraction due to salt conditions for each compartment (L/T) (SWDROUGHT=1)
   real(8), dimension(macp),              save  :: qredfrs            ! Array with reduction of root water extraction due to frost conditions for each compartment (L/T) (SWDROUGHT=1)
   real(8), dimension(macp),              save  :: qredrwu            ! Array with reduction of root water extraction due to sub-optimal conditions for each compartment (L/T) (SWDROUGHT=2 or SWDROUGHT=3)
   real(8),                               save  :: alpwetnoddrz       ! Amount of oxygenstress at bottom rootzone (-)
   real(8),                               save  :: alpdrynodrtz       ! Amount of drought stress in rootzone (-)
end module MOD_re_global

module MOD_integral_global
   use MOD_arrays, only: macp
!  Intermediate amount (since start of day), used in cropgrowth, rootdistribution   
   real(8),                       save ::   inqpotrot_day(macp) ! Array with intermediate amounts of potential extracted water by roots for each compartment since start of day (L)
   real(8),                       save ::   inqredrot_day(macp) ! Array with intermediate amounts of reduction of extracted water by roots for each compartment since start of day in case of no compensation (L)
   
   real(8),                       save ::   iqrot_day           ! Intermediate amount (since start of a day) of actual T (cm)
   real(8),                       save ::   iqreddry_day        ! Intermediate amount (since start of a day) of total T reduction due to drought  stress (cm)
   real(8),                       save ::   iqredsol_day        ! Intermediate amount (since start of a day) of total T reduction due to salinity stress (cm)
   real(8),                       save ::   iptra_day           ! Intermediate amount (since start of a day) of potential T (cm)
   
   real(8),                       save ::   ialpwet_day         ! Intermediate amount (since start of a day) of oxygen stress at the bottom of rootzone (-)
   real(8),                       save ::   ialpdry_day         ! Intermediate amount (since start of a day) of drought stress in rootzone (-)
end module MOD_integral_global

module MOD_solute_global
   use MOD_arrays, only: macp
   implicit none
!  solute+agetracer: used in outvap, outend, outcsv, irrigation, rootextraction
   real(8), dimension(macp),   save :: cml          ! Array with solute concentration (M/L3 water) in mobile region
   real(8), dimension(macp),   save :: ageml        ! Array with age mass solute concentration (M/L3 water)
end module MOD_solute_global
   
module MOD_swap_mp
   use MOD_arrays, only: macp, fillen
!  some macropore variables are used in other SWAP functions; in case macropore source is not compiled, these variables are still needed.
!  therefore, these variables are stored in this global module; locally initialized
   logical,                       save :: FlDecMpRat             = .FALSE. ! Flag indicating decrease of macropore fluxes when convergence is not reached
   logical,                       save :: fldecMPmbf             = .FALSE. ! Flag indicating time step is too large for change in macropore water level
   
   integer,                       save :: IcTopMP                = 0       ! Compartment with top layer with macropores (-)
   integer,                       save :: IDecMpRat              = 0       ! Counter for number of times macropore fluxes are decreased with factor 10 because convergence is not reached (-)
   integer,                       save :: NodGWlFlCpZo           = 0       ! Node directly above groundwater level of full capillary zone (-)
   integer,                       save :: NumLevRapDra           = 0       ! Number of drainage level connected to MB for rapid drainage
   integer,                       save :: SwDrRap                = 0       ! Switch for kind of drainage function (-) TEMPORARY: TEST option           
   integer,                       save :: SwMBF                  = 1       ! Type of flow considered in main bypass domain (1: usual, 2: kinematic wave)

   real(8),                       save :: ArMpSs                 = 0.0d0   ! Area fraction of macropores (dynamic) at soil surface (-)
   real(8),                       save :: CritUndSatVol          = 0.0d0   ! Critical value for undersaturation volume (L)
   real(8), dimension(macp),      save :: dFdhMp                 = 0.0d0   ! Contribution of macropores to derivative of compartment (1/T)
   real(8),                       save :: GWlFlCpZo              = 0.0d0   ! Groundwater level of full capillary zone (L) (only unsaturated zones with less than CritUndSatVol air)
   real(8),                       save :: KsMpSs                 = 0.0d0   ! Vertical hydraulic conductivity of macropores at soil surface (L/T) 
   real(8),                       save :: PndmxMp                = 0.0d0   ! Threshold value for ponding (L) on soil surface before overland flow into macropores starts    
   real(8), dimension(macp),      save :: QExcMpMtx              = 0.0d0   ! Water exchange flux between matrix and macropores per compartment (L/T) 
   real(8),                       save :: QMaPo                  = 0.0d0   ! Total exchange flux between matrix and macropores (L/T)
   real(8),                       save :: QMpLatSs               = 0.0d0   ! Macropore inflow flux at soil surface by lateral overland flow (L/T)
   real(8),                       save :: QRapDra                = 0.0d0   ! Total rapid drainage flux (L/T)             
   real(8),                       save :: ZDraBas                = 0.0d0   ! Level of drainage basis (drain depth or surface water level) for rapid drainage calculations (L)
   real(8), dimension(macp),      save :: FrArMtrx               = 1.0d0   ! Fraction of horizontal area of soil matrix per compartment, for static MP only (-)
   real(8),                       save :: WaSrDm1                = 0.0d0   ! Water storage in domain 1 (MB) (L)
   real(8),                       save :: WaSrDm1Ini             = 0.0d0   ! Initial water storage in domain 1 (MB) (L)
   real(8),                       save :: WaSrDm2                = 0.0d0   ! Water storage in domain 2 (IC) (L)
   real(8),                       save :: WaSrDm2Ini             = 0.0d0   ! Initial water storage in domain 2 (IC) (L)
   real(8), dimension(macp),      save :: WaUnMpDm1Cp            = 0.0d0   ! Water storage in domain 1 (MB), per compartment (L)
   real(8), dimension(macp),      save :: WaUnMpDm2Cp            = 0.0d0   ! Water storage in domain 2 (IC), per compartment (L)

! for output pearl_animo/swapoutput/outbal/outblc
   real(8),                       save :: cQMpInIntSatDm1        = 0.0d0   ! Cumulative amount of interflow out off perched groundwater into MP of domain 1 (MB) (L)
   real(8),                       save :: cQMpInIntSatDm2        = 0.0d0   ! Cumulative amount of interflow out off perched groundwater into MP of domain 2 (IC) (L)
   real(8),                       save :: cQMpInMtxSatDm1        = 0.0d0   ! Cumulative amount of exfiltration out off saturated matrix into MP of domain 1 (MB) (L)
   real(8),                       save :: cQMpInMtxSatDm2        = 0.0d0   ! Cumulative amount of exfiltration out off saturated matrix into MP of domain 2 (IC) (L)
   real(8),                       save :: cQMpInTopLatDm1        = 0.0d0   ! Cumulative amount of lateral overland flow into MP of domain 1 (MB) (L)
   real(8),                       save :: cQMpInTopLatDm2        = 0.0d0   ! Cumulative amount of lateral overland flow into MP of domain 2 (IC) (L)
   real(8),                       save :: cQMpInTopVrtDm1        = 0.0d0   ! Cumulative amount of vertical inflow at top of zone with MP into MP of domain 1 (MB) (L)
   real(8),                       save :: cQMpInTopVrtDm2        = 0.0d0   ! Cumulative amount of vertical inflow at top of zone with MP into MP of domain 2 (IC) (L)
   real(8),                       save :: cQMpOutDrRap           = 0.0d0   ! Cumulative amount of rapid drainage out off macropores of domain 1 (MB) (L)
   real(8),                       save :: cQMpOutMtxSatDm1       = 0.0d0   ! Cumulative amount of infiltration into saturated matrix out off MP of domain 1 (MB) (L) 
   real(8),                       save :: cQMpOutMtxSatDm2       = 0.0d0   ! Cumulative amount of infiltration into saturated matrix out off MP of domain 2 (IC) (L)
   real(8),                       save :: cQMpOutMtxUnsDm1       = 0.0d0   ! Cumulative amount of infiltration into unsaturated matrix out off MP of domain 1 (MB) (L) 
   real(8),                       save :: cQMpOutMtxUnsDm2       = 0.0d0   ! Cumulative amount of infiltration into unsaturated matrix out off MP of domain 2 (IC) (L) 
   real(8), dimension(macp),      save :: DiPoCp                 = 0.0d0   ! Diameter of soil matrix polygon per compartment (L)
   real(8), dimension(macp),      save :: IAvFrMpWlWtDm1         = 0.0d0   ! Incremental sum of average wet macropore wall fraction weighted for time step, for domain 1 (MB) (-)
   real(8), dimension(macp),      save :: IAvFrMpWlWtDm2         = 0.0d0   ! Incremental sum of average wet macropore wall fraction weighted for time step, for domain 2 (IC) (-)
   real(8), dimension(macp),      save :: iQExcMtxDm1Cp          = 0.0d0   ! Incremental amount of water exchange between matrix and MP of domain 1 (MB) (L)
   real(8), dimension(macp),      save :: iQExcMtxDm2Cp          = 0.0d0   ! Incremental amount of water exchange between matrix and MP of domain 2 (IC) (L)
   real(8),                       save :: iQInTopLatDm1          = 0.0d0   ! Incremental amount of lateral overland flow into MP of domain 1 (MB) (L)
   real(8),                       save :: iQInTopLatDm2          = 0.0d0   ! Incremental amount of lateral overland flow into MP of domain 2 (IC) (L)
   real(8),                       save :: iQInTopVrtDm1          = 0.0d0   ! Incremental amount of vertical inflow at top of zone with MP into MP of domain 1 (MB) (L)
   real(8),                       save :: iQInTopVrtDm2          = 0.0d0   ! Incremental amount of vertical inflow at top of zone with MP into MP of domain 2 (IC) (L)
   real(8), dimension(macp),      save :: iQInIntSatDm1cp        = 0.0d0   ! Incremental amount of infiltration from perched saturated matrix into MP of domain 1 (MB) (L)
   real(8), dimension(macp),      save :: iQInIntSatDm2cp        = 0.0d0   ! Incremental amount of infiltration from perched saturated matrix into MP of domain 2 (MB) (L)
   real(8), dimension(macp),      save :: iQInMtxSatDm1cp        = 0.0d0   ! Incremental amount of infiltration from saturated matrix into MP of domain 1 (MB) (L)
   real(8), dimension(macp),      save :: iQInMtxSatDm2cp        = 0.0d0   ! Incremental amount of infiltration from saturated matrix into MP of domain 2 (MB) (L)
   real(8),                       save :: iQMpOutDrRap           = 0.0d0   ! Incremental amount of rapid drainage out off macropores of domain 1 (MB) (L)
   real(8), dimension(macp),      save :: iQOutMtxSatDm1cp       = 0.0d0   ! Incremental amount of exfiltration from saturated MP into matrix of domain 1 (MB) (L)
   real(8), dimension(macp),      save :: iQOutMtxSatDm2cp       = 0.0d0   ! Incremental amount of exfiltration from saturated MP into matrix of domain 2 (MB) (L)
   real(8), dimension(macp),      save :: iQOutMtxUnsDm1cp       = 0.0d0   ! Incremental amount of exfiltration from (un)saturated MP into matrix of domain 1 (MB) (L)
   real(8), dimension(macp),      save :: iQOutMtxUnsDm2cp       = 0.0d0   ! Incremental amount of exfiltration from (un)saturated MP into matrix of domain 2 (MB) (L)
   real(8), dimension(macp),      save :: iQOutDrRapCp           = 0.0d0   ! Incremental amount of rapid drainage out off MP per compartment (L)
   real(8), dimension(macp),      save :: IQTopMpDm1Cp           = 0.0d0   ! Incremental amount of inflow at top of macropore compartment (positive downward) of domain 1 (MB) (L)
   real(8), dimension(macp),      save :: IQTopMpDm2Cp           = 0.0d0   ! Incremental amount of inflow at top of macropore compartment (positive downward) of domain 2 (IC) (L)
   real(8),                       save :: IWaSrDm1Beg            = 0.0d0   ! Water storage in MP of domain 1 (MB) at beginning of increment period (L)
   real(8),                       save :: IWaSrDm2Beg            = 0.0d0   ! Water storage in MP of domain 2 (IC) at beginning of increment period (L)
   real(8), dimension(macp),      save :: IWaUnDm1CpBeg          = 0.0d0   ! Water storage in MP of domain 1 (MP) at beginning of increment period, per compartment (L)
   real(8), dimension(macp),      save :: IWaUnDm2CpBeg          = 0.0d0   ! Water storage in MP of domain 2 (IC) at beginning of increment period, per compartment (L)
   real(8), dimension(macp),      save :: SubsidCp               = 0.0d0   ! Vertical subsidence of matrix per compartment (L)
   real(8),                       save :: VlMpDm1                = 0.0d0   ! Total macropore volume of domain 1 (MB) (L)
   real(8),                       save :: VlMpDm2                = 0.0d0   ! Total macropore volume of domain 2 (IC) (L)
   real(8), dimension(macp),      save :: VlMpDm1Cp              = 0.0d0   ! Macropore volume per compartment of domain 1 (MB) L
   real(8), dimension(macp),      save :: VlMpDm2Cp              = 0.0d0   ! Macropore volume per compartment of domain 2 (IC) L
   real(8), dimension(macp),      save :: VlMpDyCp               = 0.0d0   ! Dynamic macropore volume per compartment (L)
   real(8), dimension(macp),      save :: VlMpStDm1              = 0.0d0   ! Static macropore volume of domain 1 (MB) per compartment (L)
   real(8), dimension(macp),      save :: VlMpStDm2              = 0.0d0   ! Static macropore volume of domain 2 (IC) per compartment (L)
   real(8),                       save :: WaLevDm1               = 0.0d0   ! Water level in domain 1 (MB) (L)

end module MOD_swap_mp

module variables

   use MOD_arrays
   implicit none
   save
   private :: MACP, MADR, MAHO, MAIRG, MABBC, MAOWL, MAWLP, MAWLS, MACROP, MAOUT, MASCALE, MADM, MAMP, MADAY, MAGRS, MRAIN, MASTEQ, MATAB, MATABENTRIES, MAYRS, NMETFILE, MAMTE, MASME

! --- time & control variables
   integer                    :: nprintday          ! Number of output times during one day
   logical                    :: flprintdt          ! Flag indicating output every dt 
   logical                    :: flprintshort       ! Flag indicating several output times during a day
   logical                    :: floutputshort      ! Flag indicating time for output during a day is reached
   integer                    :: nprintcount        ! Counter for output during a day
   integer                    :: cntper             ! Day number of intermediate period
   integer                    :: daycum             ! Day number from start of simulation
   integer                    :: daynr              ! Day number of calendar year
   integer                    :: imonth             ! Month number of calendar year
   integer                    :: ioutdat            ! Counter of output date for water and solute balance
   integer                    :: ioutdatint         ! Counter of intermediate output date
   integer                    :: isteps             ! Number of time steps from the start of the day
   integer                    :: iyear              ! Year number of calendar year
   integer                    :: numbit_crit        ! number of iteration below which time step increase is performed (default: numbit_crit = 3; range [3,maxit])
   integer                    :: period             ! Length of prescribed output interval (T)
   integer                    :: swheader           ! Switch for printing of header in output files at each balance period: 0 = no; 1 = yes
   integer                    :: swodat             ! Switch for extra, specific output dates in the input file: 0 = no; 1 = yes
   integer                    :: swres              ! Switch for counter of output interval: 0 = no reset; 1 = reset at start of calendar year

   real(8)                    :: dt                 ! Time step (T)
   real(8)                    :: dtmax              ! Maximum time step (T)
   real(8)                    :: dtmin              ! Minimum time step (T)
   real(8)                    :: dtold              ! Length of previous Time step (T)
   real(8)                    :: fact_dt_increase   ! multiplication factor for dt increase (default: fact_dt_increase = 2; range [1.1,10])
   real(8)                    :: fact_dt_decrease   ! multiplication factor for dt decrease (default: fact_dt_decrease = 0.5; range [1.0d-3, 0.99])
   real(8)                    :: fact_dt_fldect     ! factor for dt in case this is requested to be decreased by headcalc or surfacewater (default: fact_dt_fldect = 3; range [2,10])
   real(8), dimension(maout)  :: outdat             ! Array with output dates for water and solute balances
   real(8), dimension(maout)  :: outdatint          ! Array with intermediate output dates
   real(8)                    :: outper             ! Length of actual output interval (T)
   real(8)                    :: t                  ! Time since start of calendar year (T)
   real(8)                    :: t1900              ! Time since 1900 (T)
   real(8)                    :: tcum               ! Time since start of simulation (T)
   real(8)                    :: timjan1            ! January first of meteo year as number of day since 1-1-1900(T) 
   real(8)                    :: tend               ! End date of simulation run
   real(8)                    :: tstart             ! Start date of simulation run

   logical                    :: flbaloutput        ! Flag indicating time for output of water and solute balance
   logical                    :: fldayend           ! Flag indicating end of day
   logical                    :: fldaystart         ! Flag indicating that this time step is the first one of a day
   logical                    :: fldecdt            ! Flag indicating decrease of time step
   logical                    :: fldtmin            ! Flag indicating that the time step is equal to the minimum time step
   logical                    :: fldtreduce
   logical                    :: flheader           ! Flag indicating that header should be printed in output file
   logical                    :: floutput           ! Flag indicating time for ouput
   logical                    :: flrunend           ! Flag indicating end of run
   logical                    :: flzerocumu         ! Flag indicating that cumulative fluxes should be reset to zero
   logical                    :: flzerointr         ! Flag indicating that intermediate fluxes should be reset to zero

   character(len=11)          :: date               ! Current date
   character(len=fillen)      :: outfil             ! Name of output file


! --- soilwater variables

   integer                    :: bal                ! Internal number of output file *.BAL with overview of water balance
   integer                    :: blc                ! Internal number of output file *.BLC with all water balance components in detail
   integer                    :: bpegwl             ! Node at bottom of perched groundwater
   integer, dimension(macp)   :: indeks             ! Index denoting wetting or drying curve in case of hysteresis: 1 = wetting; -1 = drying
   integer, dimension(100,2)  :: Itnumb
   integer                    :: MaxBackTr
   integer                    :: MaxIt
   integer                    :: MaxIterTime        ! Maximum cputime (secs), introduced to be able to interrupt (near) endless iterations
   integer                    :: msteps             ! Maximum number of iteration steps during a day to solve Richards equation
   integer                    :: nhead              ! Number of initial soil water pressure heads as provided in the input  (times 2; incl. index)
   integer                    :: nodgwl             ! Node at top of groundwater level
   integer                    :: npegwl             ! Node at top of perched groundwater level
   integer                    :: numbit             ! Iteration number for solving Richards equation
   integer                    :: sw2                ! Switch for prescribed bottom flux: 1 = sine function; 2 = table
   integer                    :: sw3                ! Switch for prescribed hydraulic head of deep aquifer: 1 = sine function; 2 = table
   integer                    :: sw4                ! Switch for extra groundwater flux as function of time: 0 = no extra flux; 1 = include extra flux
   integer                    :: swafo              ! Switch for extra output file with formatted data for water quality models: 
                                                    !       0 = no output; 1 = output to file *.AFO; 2 = output to file *.BFO
   integer                    :: swaun              ! Switch for extra output file with unformatted data for water quality models: 
                                                    !       0 = no output; 1 = output to file *.AUN; 2 = output to file *.BUN
   integer                    :: swbal              ! Switch for output file with yearly water balance *.BAL: 0 = no; 1 = yes
   integer                    :: swblc              ! Switch for output file with detailed yearly water balance *.BLC: 0 = no
   integer                    :: swbotb             ! Switch for bottom boundary condition (see *.SWP input file for overview)
   integer                    :: swbotb3Impl        ! Switch for implicit solution with lower boundary option 3 (Cauchy): 0 = explicit, 1 = implicit
   integer                    :: SwBotb3ResVert     ! Switch to suppress addition of vertical resistance between bottom of model and groundwater level
   integer                    :: swcfbs             ! Switch for use of coefficient CFBS to convert potential ET into potential E: 0 = no; 1 = yes
   integer                    :: swcofqhc           ! Switch for additional flux added to exponential flux-groundwater level relationship: 0 = no, 1 = yes
   integer                    :: swcsv              ! Switch for CSV output specified by user; default = 0: no output; 1: regular output. 2: regular + init file. 3: binary output
   integer                    :: swkimpl            ! Switch for implicit solution with hydraulic conductivity: 0 = explicit, 1 = implicit
   integer                    :: swkmean            ! Switch for mean of hydraulic conductivity: 1 = unweighted arithmic mean, 2 = weighted arithmic mean
                                                    !                                            3 = unweighted geometric mean,4 = weighted geometric mean
                                                    !                                            5 = unweighted harmonic mean, 6 = weighted harmonic mean
   integer                    :: swqhbot            ! Switch for flux-groundwater level relationship: 1 = exponential function; 2 = tabular function
   integer                    :: swredu             ! Switch for reduction of soil evaporation: 0 = no empirical function; 1 = use function of Black; 
                                                    !                                           2 = use function of Boesten/Stroosnijder
   integer                    :: swsba              ! Switch for output file with daily solute balance *.SBA: 0 = no; 1 = yes; 1 = yes

   real(8)                    :: aqamp              ! Amplitude of prescribed sine wave of hydraulic head in deep aquifer (T)
   real(8)                    :: aqave              ! Average hydraulic head in deep aquifer (L)
   real(8)                    :: aqper              ! Period of prescribed sine wave of hydraulic head in deep aquifer (T)
   real(8)                    :: aqtmax             ! Time with maximum hydraulic head in deep aquifer (T)
   real(8)                    :: cfbs               ! Coefficient (-) to convert potential evapotranspiration into potential evaporation
   real(8)                    :: cofqha             ! Coefficient A in exponential relationship between drainage flux and groundwater level (L/T)
   real(8)                    :: cofqhb             ! Coefficient B in exponential relationship between drainage flux and groundwater level (/T)
   real(8)                    :: cofqhc             ! Coefficient C (flux) in exponential relationship between drainage flux and groundwater level (L/T)
   real(8)                    :: cofred             ! Soil evaporation coefficient of Black or Boesten/Stroosnijder
   real(8)                    :: CritDevBalCp       ! Convergence criterion for deviation in water balance for the solution of the Richards equation per individual layer (default: 1.0d-6; range [1.0d-8,1.0d-03])
   real(8)                    :: CritDevBalTot      ! Convergence criterion for solution of Richards equation for all layers together (default 1.0d-5; range [1.0d-7,1.0d-02])
   real(8)                    :: CritDevh1Cp        ! Convergence criterium for Richards equation: relative difference in pressure heads (-)
   real(8)                    :: CritDevh2Cp        ! Convergence criterium for Richards equation: absolute difference in pressure heads (L)
   real(8)                    :: CritDevMasBal      ! Maximum error in water balance (L)
   real(8)                    :: CritDevPondDt
   real(8)                    :: CriterHr           ! Maximum difference of Hroot between iterations; convergence criterium  (L)
   real(8)                    :: deepgw             ! hydraulic head in aquifer (L)
   real(8), dimension(macp)   :: delp               ! Change in soil water pressure head (L), to determine change in hysteresis scanning curve
   real(8), dimension(macp)   :: dimoca             ! Differential soil moisture capacity (/L)
   real(8), dimension(macp)   :: dznew              ! Desired thickness of compartments for soil water quality models (L)
   real(8), dimension(macp)   :: fhyst              ! Hysteresis factor determining the scanning curve (-)
   real(8)                    :: gwl                ! Groundwater level (L)
   real(8)                    :: gwlconv            ! Maximum difference of groundwater levels between iterations to solve Richards equation
   real(8)                    :: gwli               ! Groundwater level (L) at start of simulation
   real(8)                    :: gwlinp             ! Prescribed groundwater level (L) for current time
   real(8)                    :: gwlm1              ! Groundwater level (L) at former time level
   real(8), dimension(mabbc*2):: gwltab             ! Array with prescribed groundwater level (L) as function of time (T)
   real(8), dimension(:), allocatable :: htb        ! Array with initial soil water pressure head as function of soil depth
   real(8), dimension(macp)   :: h                  ! Soil water pressure head (L)
   real(8), dimension(mabbc*2):: haqtab             ! Array with specified hydraulic head in deep aquifer (L) as function of time (T)
   real(8)                    :: hbot               ! Soil water pressure head (L) at bottom of soil column
   real(8), dimension(mabbc*2):: hbotab             ! Array with specified pressure head of lowest compartment (L) as function of time (T)
   real(8)                    :: hdrain             ! Mean drainage level (L) to derive regional average groundwater level for bottom boundary condition
   real(8), dimension(macp)   :: hm1                ! Soil water pressure head (L) at former time level
   real(8)                    :: hplate             ! Pressure head of ceramic plate below lysimeter
   real(8)                    :: ivolbeg            ! Water volume in soil matrix at start of intermediate period for csv output (L)
   real(8)                    :: ipondbeg           ! Water volume in ponding storage at start of intermediate period for csv output (L)
   real(8)                    :: isicbeg            ! Water volume in interception storage at start of intermediate period for csv output (L) 
   real(8)                    :: issnowbeg          ! Water volume in snow storage at start of intermediate period for csv output (L)
   real(8), dimension(macp)   :: ithetabeg          ! Array with water volume fraction in soil matrix at start of intermediate period for csv output (L)
   real(8), dimension(macp+1) :: k                  ! Array with soil hydraulic conductivity (L/T) for each numerical compartment
   real(8)                    :: kbot               ! Soil hydraulic condictivity (L/T) at bottom of soil column
   real(8), dimension(macp+1) :: kmean              ! Array with mean soil hydraulic conductivity (L/T) at the interface of current and upper compartment
   real(8), dimension(maho)   :: ksatfit            ! Array with saturated hydraulic conductivity (L/T) for each soil layer: fitted on VG based on lab data
   real(8), dimension(maho)   :: ksatexm            ! Array with saturated hydraulic conductivity (L/T) for each soil layer: examined in lab or field 
   real(8)                    :: ldwet              ! Length of dry period (L) as used in Black's model for reduction of soil evaporation
   real(8)                    :: pegwl              ! Perched groundwater level (L)
   real(8)                    :: pegwl_bot          ! Bottom position of perched groundwater region (L)
   real(8)                    :: pond               ! Height of ponding layer (L)
   real(8)                    :: pondini            ! Ponding water layer (L) on soil surface at start of current water balance period
   real(8)                    :: pondm1             ! Ponding water layer (L) on soil surface at former time level
   real(8)                    :: pondmx             ! Maximum amount of ponding (L) on soil surface before runoff starts
   real(8), dimension(mairg*2):: pondmxtab          ! Table with time-dependent input (date,value) for maximum amount of ponding (L) on soil surface before runoff starts
   real(8), dimension(macp+1) :: q                  ! Soil water flux between current compartment and upper compartment (L/T)
   real(8)                    :: qbot               ! Water flux through bottom of simulated soil column (L/T)
   real(8), dimension(mabbc*2):: qbotab             ! Array with specified bottom flux (L/T) as function of time (T)
   real(8)                    :: qbot_nonfrozen     ! Water flux through bottom of non-frozen soil column (L/T)
   real(8), dimension(macp)   :: qimmob             ! Soil water flux between mobile and immobile fraction in case of fingered flow (L/T)
   real(8), dimension(macp)   :: qrot               ! Array with root water extraction flux for each compartment (L/T)
   real(8)                    :: qtop               ! Water flux through soil surface (L/T)
   real(8)                    :: epd                ! Ponding evaporation rate (L/T)
   real(8)                    :: reva               ! Actual soil evaporation rate (L/T)
   real(8)                    :: rimlay             ! Vertical resistance of aquitard (T)
   real(8)                    :: rsigni             ! Minimum amount of rainfall (L) which resets the empirical soil evaporation reduction models
   real(8)                    :: rsoil              ! Soil resistance of wet soil of PMdirect (T/L)
   real(8)                    :: rsro               ! Drainage resistance for surface runoff (T)
   real(8)                    :: rsroexp            ! Exponent to calculate surface runoff (T)
   real(8)                    :: runon              ! Water runon flux (L/T)
   real(8)                    :: runots             ! Amount of runoff during a time step (L)
   real(8)                    :: saev               ! Cumulative actual evaporation (L) as used in the model of Boesten/Stroosnijder for reduction of E
   real(8)                    :: shape_3            ! Shape factor to derive average groundwater level (-; 0...1)
   real(8)                    :: sinamp             ! Amplitude of prescribed bottom flux (L/T) in case of sine function
   real(8)                    :: sinave             ! Average value of prescribed bottom flux (L/T) in case of sine function
   real(8)                    :: sinmax             ! Time of the year with maximum bottom flux in case of prescribed sine function
   real(8)                    :: spev               ! Cumulative potential evaporation (L) as used in the model of Boesten/Stroosnijder for reduction of E
   real(8)                    :: tau                ! Minimum pressure head difference (L) to change from wetting to drying in case of hysteresis
   real(8), dimension(macp)   :: theta              ! Volumetric soil water content (-)
   real(8), dimension(macp)   :: thetar             ! Residual volumetric soil water content (-) for each numerical compartment
   real(8), dimension(macp)   :: thetas             ! Saturated volumetric soil water content (-) for each numerical compartment
   real(8), dimension(macp)   :: thetm1             ! Volumetric soil water content (-) at former time level
   real(8), dimension(maho)   :: thetsl             ! Saturated volumetric water content (-) for each soil layer
   real(8)                    :: volact             ! Water storage (L) of soil column at current time level
   real(8)                    :: volini             ! Water storage (L) of soil column at start of simulation
   real(8)                    :: volm1              ! Water storage (L) of soil column at former time level
   real(8), dimension(macp)   :: zi                 ! Array with soil depths (L) used to specify initial soil water pressure heads

   logical                    :: flksatexm          ! flag Ksatexm variable present in input file 
   logical                    :: fllowgwl           ! Flag indicating precribed groundwater level below bottom soil column
   logical, dimension(macp)   :: fluseksatexm       ! flag per node: yes/no make use of Ksatexm (Ksat examined in lab or field) extension in h-range [-2,0]
   logical                    :: flMaxIterTime      ! flag to enable input of Maximum cputime

end module variables
