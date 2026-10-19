module SWAP_csv_output
   use MOD_arrays,          only: macp, maho, fillen
      
   implicit none

   private

   public :: csv_out                                                  ! function
   public :: num_d, InList_csv, tz_z1_z2                              ! user input
   public :: swdiscrvert, numnodnew, dznew                            ! user input 
   public :: iuncsv, iuncsv_init                                      ! other
   public :: M_v, vars_v, output_vector                               ! for multi-SWAP storage  (output_vector added to prevent error message ForCheck)
   public :: botcomnew, fill_vector                                   ! for exchange with ANIMO

   ! global
   integer,                             save :: iuncsv                ! unit number csv/binary output
   integer,                             save :: iuncsv_init           ! unit number csv init output
   
   character(len=1024)                       :: InList_csv            ! character string with comma-separated list of  requested variables for output
   integer,                             save :: num_d = 5             ! number of decimals; default and user input in readswap
   real(8),    dimension(2)                  :: tz_z1_z2              ! depth range for time-depth output (default: top soil profile, bottom soil profile)
   
   integer                                   :: swdiscrvert           ! switch to convert vertical discretization for tz output: 0 = no; 1 = yes
   integer                                   :: numnodnew             ! number of desired nodes for tz output in case swdiscrvert == 1
   real(8), dimension(macp)                  :: dznew                 ! thickness (L) of compartments for tz output in case swdiscrvert == 1
   
   ! local
   ! definition of scalar output type
   integer,              parameter           :: M_s = 177             ! total number of variables present in predefined scalar list
   
   type output_scalar
      character(len=12), dimension(M_s)      :: name                  ! base name of variable
      character(len=12), dimension(M_s)      :: unit                  ! units of variable
      integer,           dimension(M_s)      :: iyes                  ! yes (1) or no (0) variable is requested for output
      real(8),           dimension(M_s)      :: value                 ! value of variable
   end type output_scalar
   
   ! definition of vector output type
   integer,              parameter           :: M_v = 58              ! total number of variables present in predifined vector list 
      
   type :: nod_array
!DEC$ IF DEFINED (multiswap)
      integer                                :: nod(macp+1,2)         ! Allocatable array for storage of relevant nodes
!DEC$ ELSE
      integer,           allocatable         :: nod(:,:)              ! Allocatable array for storage of relevant nodes
!DEC$ END IF
   end type nod_array
   
   type :: val_array
      real(8),           allocatable         :: val(:)                ! Allocatable array for storage of relevant values
   end type val_array
   
   type output_vector
      character(len=12), dimension(M_v)      :: name                  ! base name of variable
      character(len=12), dimension(M_v)      :: unit                  ! units of variable
      integer,           dimension(M_v)      :: iyes                  ! yes (1) or no (0) variable is requested for output
      integer,           dimension(M_v)      :: conv                  ! type of conversion for subreg or dznew (1: weighed average, 2: integration, 3: top node, 4: bot node, 5: function (pressure head))
      integer,           dimension(M_v)      :: itzq                  ! is variable defined at center of node (0) or at top of the node (1)
      integer,           dimension(M_v)      :: subr                  ! is variable defined as regular (0) or subregion (1) 
      integer,           dimension(M_v)      :: nnod                  ! number of nodes defined for output
      integer,           dimension(M_v)      :: nval                  ! number of values defined for output (nval = nnod or nval = nnod + 1)
      type(nod_array),   dimension(M_v)      :: nodes                 ! requested node numbers of variable
      type(val_array),   dimension(M_v)      :: value                 ! actual value of variable
   end type output_vector

   ! definition of shortnames (aliases)
   integer,              parameter           :: M_a = 14              ! Maximum number of aliases
   integer,              parameter           :: M_an = 57             ! Maximum number of entries for one shortname
   
   type shortnames
      integer,           dimension(M_a)      :: n                     ! number of entries per alias
      character(len=12), dimension(M_a)      :: alias                 ! base name of alias
      character(len=12), dimension(M_a,M_an) :: names                 ! all names in type output associated to alias
   end type shortnames

   ! all variables related information
   type(output_scalar),                 save :: vars_s
   type(output_vector),                 save :: vars_v
   type(shortnames),                    save :: shorts

   ! local helpers
   character(len=fillen),               save :: filcsv                ! filename csv/binary output
   character(len=fillen),               save :: filcsv_init           ! filename csv init output
   character(len=2096)                       :: InList
   character(len=128), dimension(M_s+M_v)    :: userlist
   character(len=100)                        :: message
   integer                                   :: nlist, i
   integer                                   :: nod_1, nod_2, nnodes
   integer,                             save :: parlen
   logical,                             save :: out_s, out_v          ! is any scalar or vector output requested         
   integer, dimension(maho)                  :: botcomnew
   integer, dimension(macp,2),          save :: nodenew
   real(8), dimension(macp),            save :: znew, zbotnew, ztopnew
   real(8), dimension(macp+1),          save :: disnodnew
   
   

   ! initialization of output types:
   ! allowed list of input and units that apply; this sequence determines sequence in output file. MUST be uppercase
   ! scalar output
   data (vars_s%name(i),  vars_s%unit(i), i = 1, M_s) /&
         ! fluxes top
         'RAIN',        '(cm)',        &
         'RAIN_NET',    '(cm)',        &
         'SNOW',        '(cm)',        &
         'IRRIG',       '(cm)',        &
         'IRRIG_NET',   '(cm)',        &
         'RUNON',       '(cm)',        &
         'RUNOFF',      '(cm)',        &
         'EIC',         '(cm)',        &
         'EPD',         '(cm)',        &   
         'EPOT',        '(cm)',        &
         'EACT',        '(cm)',        &
         'ESUBLIM',     '(cm)',        &
         'TOP_IN',      '(cm)',        &
         'TOP_OUT',     '(cm)',        &
         'TOP',         '(cm)',        &
         ! fluxes side
         'TPOT',        '(cm)',        &
         'TACT',        '(cm)',        &
         'TREDDRY',     '(cm)',        &
         'TREDWET',     '(cm)',        &
         'TREDSOL',     '(cm)',        &
         'TREDFRS',     '(cm)',        &
         'DRN',         '(cm)',        &
         'DRN_1',       '(cm)',        &
         'DRN_2',       '(cm)',        &
         'DRN_3',       '(cm)',        &
         'DRN_4',       '(cm)',        &
         'DRN_5',       '(cm)',        &
         'SSDI',        '(cm)',        &
         ! fluxes bottom
         'BOT_IN',      '(cm)',        &
         'BOT_OUT',     '(cm)',        &
         'BOT',         '(cm)',        &
         ! storage
         'GWL',         '(cm)',        &
         'PGWL',        '(cm)',        &
         'PGWL_BOT',    '(cm)',        &
         'PD_VOL',      '(cm)',        &
         'SNOW_VOL',    '(cm)',        &
         'IC_VOL',      '(cm)',        &
         'WTOT',        '(cm)',        &
         'DSTOR',       '(cm)',        &
         'BALDEV',      '(cm)',        &
         ! macropore
         'MP_WVOL_1',   '(cm)',        &
         'MP_TVOL_1',   '(cm)',        &
         'MP_EXF_1',    '(cm)',        &
         'MP_INF_1',    '(cm)',        &
         'MP_TOP_1',    '(cm)',        &
         'MP_TOPD_1',   '(cm)',        &
         'MP_TOPL_1',   '(cm)',        &
         'MP_DRN_1',    '(cm)',        &
         'MP_GWL_1',    '(cm)',        &
         'MP_BALDEV_1', '(cm)',        &
         'MP_WVOL_2',   '(cm)',        &
         'MP_TVOL_2',   '(cm)',        &
         'MP_EXF_2',    '(cm)',        &
         'MP_INF_2',    '(cm)',        &
         'MP_TOP_2',    '(cm)',        &
         'MP_TOPD_2',   '(cm)',        &
         'MP_TOPL_2',   '(cm)',        &
         'MP_BALDEV_2', '(cm)',        &
         'MP_VOLDYN',   '(cm)',        &
         'MP_SUBSID',   '(cm)',        &
         ! crop
         'CH',          '(cm)',        &
         'CF',          '(-)',         &
         'TSUM',        '(deg C)',     &
         'DVS',         '(-)',         &
         'LAIPOT',      '(m2/m2)',     &
         'PWSO',        '(kg/ha)',     &
         'PWLV',        '(kg/ha)',     &
         'PWST',        '(kg/ha)',     &
         'PWRT',        '(kg/ha)',     &
         'PDWLV',       '(kg/ha)',     &
         'PDWST',       '(kg/ha)',     &
         'PDWRT',       '(kg/ha)',     &
         'PTWLV',       '(kg/ha)',     &
         'PTWST',       '(kg/ha)',     &
         'PTWRT',       '(kg/ha)',     &
         'PWDM',        '(kg/ha)',     &
         'RDPOT',       '(cm)',        &
         'ICUTPOT',     '(-)',         &
         'TCUTPOT',     '(d)',         &
         'PHRVDM',      '(kg/ha)',     &
         'PLOSSDM',     '(kg/ha)',     &
         'VCOVER',      '(-)',         &
         'LAI',         '(m2/m2)',     &
         'WSO',         '(kg/ha)',     &
         'WLV',         '(kg/ha)',     &
         'WST',         '(kg/ha)',     &
         'WRT',         '(kg/ha)',     &
         'DWLV',        '(kg/ha)',     &
         'DWST',        '(kg/ha)',     &
         'DWRT',        '(kg/ha)',     &
         'TWLV',        '(kg/ha)',     &   
         'TWST',        '(kg/ha)',     &
         'TWRT',        '(kg/ha)',     &
         'WDM',         '(kg/ha)',     &
         'RD',          '(cm)',        &
         'ICUT',        '(-)',         &
         'TCUT',        '(d)',         &
         'HRVDM',       '(kg/ha)',     &
         'LOSSDM',      '(kg/ha)',     &
         'PGASSTPOT',   '(kg/ha)',     &
         'PGASST',      '(kg/ha)',     &
         'GASSTPOT',    '(kgch/ha)',   &
         'GASST',       '(kgch/ha)',   &
         'MRESTPOT',    '(kgch/ha)',   &
         'MREST',       '(kgch/ha)',   &
         'PP',          '(cm)',        &
         'PL',          '(cm)',        &
         'MAX_RESP',    '(-)',         &
         ! solute
         'S_RAIN',      '(mg/cm2)',     &
         'S_IRRIG',     '(mg/cm2)',     &
         'S_BOT',       '(mg/cm2)',     &
         'S_DRN',       '(mg/cm2)',     &
         'S_DEC',       '(mg/cm2)',     &
         'S_UPT',       '(mg/cm2)',     &
         'S_STOT',      '(mg/cm2)',     &
         'S_BALDEV',    '(mg/cm2)',     &
         'S_DSTOR',     '(mg/cm2)',     &
         ! temperature
         'T_ATM',       '(deg C)',     &
         'T_TOP',       '(deg C)',     &
         'T_BOT',       '(deg C)',     &
         ! nutrients
         'FOM',         '(kg/ha)',     &
         'FOM_ADD',     '(kg/ha)',     &
         'FOM_CRES',    '(kg/ha)',     &
         'FOM2BIO',     '(kg/ha)',     &
         'FOM2HUM',     '(kg/ha)',     &
         'FOM_DIS',     '(kg/ha)',     &
         'BIO',         '(kg/ha)',     &
         'BIO2BIO',     '(kg/ha)',     &
         'BIO2HUM',     '(kg/ha)',     &
         'BIO_DIS',     '(kg/ha)',     &
         'HUM',         '(kg/ha)',     &
         'HUM_ADD',     '(kg/ha)',     &
         'HUM_CRES',    '(kg/ha)',     &
         'HUM2BIO',     '(kg/ha)',     &
         'HUM2HUM',     '(kg/ha)',     &
         'HUM_DIS',     '(kg/ha)',     &
         'CDISSI',      '(kg/ha)',     &
         'NFOM',        '(kg/ha)',     &
         'NFOM_ADD',    '(kg/ha)',     &
         'NFOM_CRES',   '(kg/ha)',     &
         'NFOM2BIO',    '(kg/ha)',     &
         'NFOM2HUM',    '(kg/ha)',     &
         'NFOM_MIN',    '(kg/ha)',     &
         'NBIO',        '(kg/ha)',     &
         'NBIO2BIO',    '(kg/ha)',     &
         'NBIO2HUM',    '(kg/ha)',     &
         'NBIO_MIN',    '(kg/ha)',     &
         'NHUM',        '(kg/ha)',     &
         'NHUM_ADD',    '(kg/ha)',     &
         'NHUM_CRES',   '(kg/ha)',     &
         'NHUM2BIO',    '(kg/ha)',     &
         'NHUM2HUM',    '(kg/ha)',     &
         'NHUM_MIN',    '(kg/ha)',     &
         'NH4_MINER',   '(kg/ha)',     &
         'NH4',         '(kg/ha)',     &
         'NH4N_AMEND',  '(kg/ha)',     &
         'NH4N_CRES',   '(kg/ha)',     &
         'NH4_INTOP',   '(kg/ha)',     &
         'NH4_INLAT',   '(kg/ha)',     &
         'NH4_INBOT',   '(kg/ha)',     &
         'NH4_UPT',     '(kg/ha)',     &
         'NH4_OUT',     '(kg/ha)',     &
         'NH4N_VOLAT',  '(kg/ha)',     &
         'NH4_NITRIF',  '(kg/ha)',     &
         'NO3',         '(kg/ha)',     &
         'NO3N_AMEND',  '(kg/ha)',     &
         'NO3N_CRES',   '(kg/ha)',     &
         'NO3_INTOP',   '(kg/ha)',     &
         'NO3_INLAT',   '(kg/ha)',     &
         'NO3_INBOT',   '(kg/ha)',     &
         'NO3_UPT',     '(kg/ha)',     &
         'NO3_OUT',     '(kg/ha)',     &
         'NO3_DENITR',  '(kg/ha)',     &
         'WFLUX_INTOP', '(mm)',        &
         'N_DEMAND',    'kg/ha',       &
         'N_UPTAKE',    'kg/ha',       &
         'N_STRESS',    '(-)'          &
         /

   ! vector output
   ! aliases
   data shorts%n(1:14)       /21,9,11,16,13,9,28,8,7,10,54,7,53,57/
   data shorts%alias(1:14)   /"WATBAL", "SOLBAL", "ETTERMS", "MACROPORE", "MACROPORECP", "CROP", "WOFOST", "GRASS", "SUBREG_MIN",    & 
                              "SUBREG_ALL", "NUTRIENTS", "DRAIN_ALL", "ANIMO", "PEARL"/
   data shorts%names(1,1:21) /"RAIN", "SNOW", "RUNON", "RUNOFF", "IRRIG", "TPOT", "TACT", "EIC", "EPD", "EPOT", "EACT", "ESUBLIM",   & ! WATBAL
                              "SSDI", "BOT", "DRN", "WTOT", "SNOW_VOL", "PD_VOL", "IC_VOL","DSTOR", "BALDEV"/
   data shorts%names(2,1:9)  /"S_RAIN", "S_IRRIG", "S_BOT", "S_DEC", "S_UPT", "S_DRN", "S_STOT", "S_BALDEV", "S_DSTOR"/                ! SOLBAL
   data shorts%names(3,1:11) /"TPOT", "TACT", "TREDDRY", "TREDWET", "TREDSOL", "TREDFRS", "EPD", "EPOT", "EACT", "EIC", "ESUBLIM"/     ! ETTERMS
   data shorts%names(4,1:16) /"MP_WVOL_1", "MP_TVOL_1", "MP_EXF_1", "MP_INF_1", "MP_TOP_1", "MP_BALDEV_1", "MP_DRN_1", "MP_GWL_1",   & ! MACROPORE
                              "MP_WVOL_2", "MP_TVOL_2", "MP_EXF_2", "MP_INF_2", "MP_TOP_2", "MP_BALDEV_2", "MP_VOLDYN", "MP_SUBSID"/
   data shorts%names(5,1:13) /"MPC_QEXC_1", "MPC_WVOL_1", "MPC_TVOL_1", "MPC_WET_1", "MPC_Q_1", "MPC_QDRN_1",                        & ! MACROPORECP
                              "MPC_QEXC_2", "MPC_WVOL_2", "MPC_TVOL_2", "MPC_WET_2", "MPC_Q_2", "MPC_VOLDYN", "MPC_SUBSID"/
   data shorts%names(6,1:9)  /"TSUM", "DVS", "CH", "CF", "LAIPOT", "LAI", "RDPOT", "RD", "VCOVER"/                                     ! CROP
   data shorts%names(7,1:28) /"PGASSTPOT", "PGASST", "GASSTPOT", "GASST", "MRESTPOT", "MREST", "PWDM", "WDM", "PWSO", "WSO", "PWLV", & ! WOFOST
                              "WLV", "PWST", "WST", "PWRT", "WRT", "PDWLV", "DWLV", "PDWST", "DWST", "PDWRT", "DWRT", "PTWLV",       &
                              "TWLV", "PTWST", "TWST", "PTWRT", "TWRT"/
   data shorts%names(8,1:8)  /"ICUTPOT", "ICUT", "TCUTPOT", "TCUT", "PHRVDM", "HRVDM", "PLOSSDM", "LOSSDM"/                            ! GRASS
   data shorts%names(9,1:7)  /"SR_WTOT", "SR_DSTOR", "SR_RWU", "SR_SSDI", "SR_TOP", "SR_BOT", "SR_DRN"/                                ! SUBREG_MIN
   data shorts%names(10,1:10)/"SR_WTOT", "SR_DSTOR", "SR_RWU", "SR_SSDI",                                                            & ! SUBREG_ALL
                              "SR_TOP_IN", "SR_TOP_OUT", "SR_BOT_IN", "SR_BOT_OUT", "SR_DRN_IN","SR_DRN_OUT"/
   data shorts%names(11,1:54)/"FOM", "FOM_ADD", "FOM_CRES", "FOM2BIO", "FOM2HUM", "FOM_DIS", "BIO", "BIO2BIO", "BIO2HUM", "BIO_DIS", & ! NUTRIENTS
                              "HUM", "HUM_ADD", "HUM_CRES", "HUM2BIO", "HUM2HUM", "HUM_DIS", "CDISSI", "NFOM", "NFOM_ADD",           &
                              "NFOM_CRES", "NFOM2BIO", "NFOM2HUM", "NFOM_MIN", "NBIO", "NBIO2BIO", "NBIO2HUM", "NBIO_MIN",           &
                              "NHUM", "NHUM_ADD", "NHUM_CRES", "NHUM2BIO", "NHUM2HUM", "NHUM_MIN", "NH4_MINER", "NH4", "NH4N_AMEND", &
                              "NH4N_CRES", "NH4_INTOP", "NH4_INLAT", "NH4_INBOT", "NH4_UPT", "NH4_OUT", "NH4N_VOLAT", "NH4_NITRIF",  &
                              "NO3", "NO3N_AMEND", "NO3N_CRES", "NO3_INTOP", "NO3_INLAT", "NO3_INBOT", "NO3_UPT", "NO3_OUT",         &
                              "NO3_DENITR", "WFLUX_INTOP"/
   data shorts%names(12,1:7) /"DRN", "DRN_1", "DRN_2", "DRN_3", "DRN_4", "DRN_5", "MP_DRN_1"/                                          ! DRAIN_ALL
   data shorts%names(13,1:53)/"RAIN", "SNOW", "IRRIG", "SSDI", "EIC", "ESUBLIM", "EACT", "EPD", "EPOT", "TPOT", "RUNON", "RUNOFF",   & ! ANIMO
                              "GWL", "PD_VOL","SNOW_VOL", "IC_VOL", "BALDEV", "T_ATM",                                               &
                              "MP_TVOL_1", "MP_WVOL_1", "MP_TOPD_1", "MP_TOPL_1", "MP_GWL_1",                                        &
                              "MP_TVOL_2", "MP_WVOL_2", "MP_TOPD_2", "MP_TOPL_2",                                                    &
                              "H", "WC", "T", "Q", "QSSDI", "RWU", "QDRN_1", "QDRN_2", "QDRN_3", "QDRN_4", "QDRN_5",                 &
                              "MPC_Q_1", "MPC_QEXC_1", "MPC_WVOL_1", "MPC_TVOL_1", "MPC_WET_1", "MPC_QDRN_1",                        &
                              "MPC_Q_2", "MPC_QEXC_2", "MPC_WVOL_2", "MPC_TVOL_2", "MPC_WET_2",                                      &
                              "MPC_VOLSTA_1", "MPC_VOLSTA_2", "MPC_DIPO", "MPC_FRARMTRX"/
   data shorts%names(14,1:57)/"RAIN", "SNOW", "IRRIG", "SSDI", "EIC", "ESUBLIM", "EACT", "EPD", "EPOT", "TPOT", "RUNON", "RUNOFF",   & ! PEARL
                              "GWL", "PD_VOL","SNOW_VOL", "IC_VOL", "BALDEV", "T_ATM", "VCOVER", "LAI", "RD", "CF",                  &
                              "MP_TVOL_1", "MP_WVOL_1", "MP_TOPD_1", "MP_TOPL_1", "MP_GWL_1",                                        &
                              "MP_TVOL_2", "MP_WVOL_2", "MP_TOPD_2", "MP_TOPL_2",                                                    &
                              "H", "WC", "T", "Q", "QSSDI", "RWU", "QDRN_1", "QDRN_2", "QDRN_3", "QDRN_4", "QDRN_5",                 &
                              "MPC_Q_1", "MPC_QEXC_1", "MPC_WVOL_1", "MPC_TVOL_1", "MPC_WET_1", "MPC_QDRN_1",                        &
                              "MPC_Q_2", "MPC_QEXC_2", "MPC_WVOL_2", "MPC_TVOL_2", "MPC_WET_2",                                      &
                              "MPC_VOLSTA_1", "MPC_VOLSTA_2", "MPC_DIPO", "MPC_FRARMTRX"/
   
   contains

   subroutine init_vector_metadata()
      vars_v%name(1)='H'; vars_v%unit(1)='(cm)'
      vars_v%conv(1)=5; vars_v%subr(1)=0; vars_v%itzq(1)=0
      vars_v%name(2)='WC'; vars_v%unit(2)='(cm3/cm3)'
      vars_v%conv(2)=1; vars_v%subr(2)=0; vars_v%itzq(2)=0
      vars_v%name(3)='K'; vars_v%unit(3)='(cm/d)'
      vars_v%conv(3)=5; vars_v%subr(3)=0; vars_v%itzq(3)=0
      vars_v%name(4)='C'; vars_v%unit(4)='(1/cm)'
      vars_v%conv(4)=5; vars_v%subr(4)=0; vars_v%itzq(4)=0
      vars_v%name(5)='T'; vars_v%unit(5)='(deg C)'
      vars_v%conv(5)=1; vars_v%subr(5)=0; vars_v%itzq(5)=0
      vars_v%name(6)='HEACAP'; vars_v%unit(6)='(J/m3/K)'
      vars_v%conv(6)=1; vars_v%subr(6)=0; vars_v%itzq(6)=0
      vars_v%name(7)='HEACON'; vars_v%unit(7)='(W/m/K)'
      vars_v%conv(7)=1; vars_v%subr(7)=0; vars_v%itzq(7)=0
      vars_v%name(8)='Q'; vars_v%unit(8)='(cm)'
      vars_v%conv(8)=3; vars_v%subr(8)=0; vars_v%itzq(8)=1
      vars_v%name(9)='QSSDI'; vars_v%unit(9)='(cm)'
      vars_v%conv(9)=2; vars_v%subr(9)=0; vars_v%itzq(9)=0
      vars_v%name(10)='RWU'; vars_v%unit(10)='(cm)'
      vars_v%conv(10)=2; vars_v%subr(10)=0; vars_v%itzq(10)=0
      vars_v%name(11)='PRWU'; vars_v%unit(11)='(cm)'
      vars_v%conv(11)=2; vars_v%subr(11)=0; vars_v%itzq(11)=0
      vars_v%name(12)='RRWU'; vars_v%unit(12)='(cm)'
      vars_v%conv(12)=2; vars_v%subr(12)=0; vars_v%itzq(12)=0
      vars_v%name(13)='QDRN'; vars_v%unit(13)='(cm)'
      vars_v%conv(13)=2; vars_v%subr(13)=0; vars_v%itzq(13)=0
      vars_v%name(14)='QDRN_1'; vars_v%unit(14)='(cm)'
      vars_v%conv(14)=2; vars_v%subr(14)=0; vars_v%itzq(14)=0
      vars_v%name(15)='QDRN_2'; vars_v%unit(15)='(cm)'
      vars_v%conv(15)=2; vars_v%subr(15)=0; vars_v%itzq(15)=0
      vars_v%name(16)='QDRN_3'; vars_v%unit(16)='(cm)'
      vars_v%conv(16)=2; vars_v%subr(16)=0; vars_v%itzq(16)=0
      vars_v%name(17)='QDRN_4'; vars_v%unit(17)='(cm)'
      vars_v%conv(17)=2; vars_v%subr(17)=0; vars_v%itzq(17)=0
      vars_v%name(18)='QDRN_5'; vars_v%unit(18)='(cm)'
      vars_v%conv(18)=2; vars_v%subr(18)=0; vars_v%itzq(18)=0
      vars_v%name(19)='O2TOP'; vars_v%unit(19)='(kg/m3)'
      vars_v%conv(19)=3; vars_v%subr(19)=0; vars_v%itzq(19)=1
      vars_v%name(20)='RDENS'; vars_v%unit(20)='(-)'
      vars_v%conv(20)=1; vars_v%subr(20)=0; vars_v%itzq(20)=0
      vars_v%name(21)='LRV'; vars_v%unit(21)='(cm/cm3)'
      vars_v%conv(21)=1; vars_v%subr(21)=0; vars_v%itzq(21)=0
      vars_v%name(22)='HROOT'; vars_v%unit(22)='(cm)'
      vars_v%conv(22)=1; vars_v%subr(22)=0; vars_v%itzq(22)=0
      vars_v%name(23)='MROOT'; vars_v%unit(23)='(cm2/d)'
      vars_v%conv(23)=1; vars_v%subr(23)=0; vars_v%itzq(23)=0
      vars_v%name(24)='MFLUX'; vars_v%unit(24)='(cm2/d)'
      vars_v%conv(24)=1; vars_v%subr(24)=0; vars_v%itzq(24)=0
      vars_v%name(25)='WROOT'; vars_v%unit(25)='kg/ha'
      vars_v%conv(25)=2; vars_v%subr(25)=0; vars_v%itzq(25)=0
      vars_v%name(26)='S_CONC'; vars_v%unit(26)='(mg/cm3 w)'
      vars_v%conv(26)=1; vars_v%subr(26)=0; vars_v%itzq(26)=0
      vars_v%name(27)='S_CONCADS'; vars_v%unit(27)='(mg/cm3)'
      vars_v%conv(27)=1; vars_v%subr(27)=0; vars_v%itzq(27)=0
      vars_v%name(28)='S_QSOL'; vars_v%unit(28)='(mg/cm2)'
      vars_v%conv(28)=3; vars_v%subr(28)=0; vars_v%itzq(28)=1
      vars_v%name(29)='MPC_Q_1'; vars_v%unit(29)='(cm)'
      vars_v%conv(29)=3; vars_v%subr(29)=0; vars_v%itzq(29)=1
      vars_v%name(30)='MPC_QEXC_1'; vars_v%unit(30)='(cm)'
      vars_v%conv(30)=2; vars_v%subr(30)=0; vars_v%itzq(30)=0
      vars_v%name(31)='MPC_QDRN_1'; vars_v%unit(31)='(cm)'
      vars_v%conv(31)=2; vars_v%subr(31)=0; vars_v%itzq(31)=0
      vars_v%name(32)='MPC_WVOL_1'; vars_v%unit(32)='(cm)'
      vars_v%conv(32)=2; vars_v%subr(32)=0; vars_v%itzq(32)=0
      vars_v%name(33)='MPC_TVOL_1'; vars_v%unit(33)='(cm)'
      vars_v%conv(33)=2; vars_v%subr(33)=0; vars_v%itzq(33)=0
      vars_v%name(34)='MPC_WET_1'; vars_v%unit(34)='(-)'
      vars_v%conv(34)=1; vars_v%subr(34)=0; vars_v%itzq(34)=0
      vars_v%name(35)='MPC_Q_2'; vars_v%unit(35)='(cm)'
      vars_v%conv(35)=3; vars_v%subr(35)=0; vars_v%itzq(35)=1
      vars_v%name(36)='MPC_QEXC_2'; vars_v%unit(36)='(cm)'
      vars_v%conv(36)=2; vars_v%subr(36)=0; vars_v%itzq(36)=0
      vars_v%name(37)='MPC_WVOL_2'; vars_v%unit(37)='(cm)'
      vars_v%conv(37)=2; vars_v%subr(37)=0; vars_v%itzq(37)=0
      vars_v%name(38)='MPC_TVOL_2'; vars_v%unit(38)='(cm)'
      vars_v%conv(38)=2; vars_v%subr(38)=0; vars_v%itzq(38)=0
      vars_v%name(39)='MPC_WET_2'; vars_v%unit(39)='(-)'
      vars_v%conv(39)=1; vars_v%subr(39)=0; vars_v%itzq(39)=0
      vars_v%name(40)='MPC_VOLDYN'; vars_v%unit(40)='(cm)'
      vars_v%conv(40)=2; vars_v%subr(40)=0; vars_v%itzq(40)=0
      vars_v%name(41)='MPC_SUBSID'; vars_v%unit(41)='(cm)'
      vars_v%conv(41)=2; vars_v%subr(41)=0; vars_v%itzq(41)=0
      vars_v%name(42)='MPC_VOLSTA_1'; vars_v%unit(42)='(cm)'
      vars_v%conv(42)=2; vars_v%subr(42)=0; vars_v%itzq(42)=0
      vars_v%name(43)='MPC_VOLSTA_2'; vars_v%unit(43)='(cm)'
      vars_v%conv(43)=2; vars_v%subr(43)=0; vars_v%itzq(43)=0
      vars_v%name(44)='MPC_DIPO'; vars_v%unit(44)='(cm)'
      vars_v%conv(44)=1; vars_v%subr(44)=0; vars_v%itzq(44)=0
      vars_v%name(45)='MPC_FRARMTRX'; vars_v%unit(45)='(cm)'
      vars_v%conv(45)=1; vars_v%subr(45)=0; vars_v%itzq(45)=0
      vars_v%name(46)='SR_WTOT'; vars_v%unit(46)='(cm)'
      vars_v%conv(46)=2; vars_v%subr(46)=1; vars_v%itzq(46)=0
      vars_v%name(47)='SR_DSTOR'; vars_v%unit(47)='(cm)'
      vars_v%conv(47)=2; vars_v%subr(47)=1; vars_v%itzq(47)=0
      vars_v%name(48)='SR_RWU'; vars_v%unit(48)='(cm)'
      vars_v%conv(48)=2; vars_v%subr(48)=1; vars_v%itzq(48)=0
      vars_v%name(49)='SR_TOP'; vars_v%unit(49)='(cm)'
      vars_v%conv(49)=3; vars_v%subr(49)=1; vars_v%itzq(49)=0
      vars_v%name(50)='SR_BOT'; vars_v%unit(50)='(cm)'
      vars_v%conv(50)=4; vars_v%subr(50)=1; vars_v%itzq(50)=0
      vars_v%name(51)='SR_DRN'; vars_v%unit(51)='(cm)'
      vars_v%conv(51)=2; vars_v%subr(51)=1; vars_v%itzq(51)=0
      vars_v%name(52)='SR_SSDI'; vars_v%unit(52)='(cm)'
      vars_v%conv(52)=2; vars_v%subr(52)=1; vars_v%itzq(52)=0
      vars_v%name(53)='SR_TOP_IN'; vars_v%unit(53)='(cm)'
      vars_v%conv(53)=3; vars_v%subr(53)=1; vars_v%itzq(53)=0
      vars_v%name(54)='SR_TOP_OUT'; vars_v%unit(54)='(cm)'
      vars_v%conv(54)=3; vars_v%subr(54)=1; vars_v%itzq(54)=0
      vars_v%name(55)='SR_BOT_IN'; vars_v%unit(55)='(cm)'
      vars_v%conv(55)=4; vars_v%subr(55)=1; vars_v%itzq(55)=0
      vars_v%name(56)='SR_BOT_OUT'; vars_v%unit(56)='(cm)'
      vars_v%conv(56)=4; vars_v%subr(56)=1; vars_v%itzq(56)=0
      vars_v%name(57)='SR_DRN_IN'; vars_v%unit(57)='(cm)'
      vars_v%conv(57)=2; vars_v%subr(57)=1; vars_v%itzq(57)=0
      vars_v%name(58)='SR_DRN_OUT'; vars_v%unit(58)='(cm)'
      vars_v%conv(58)=2; vars_v%subr(58)=1; vars_v%itzq(58)=0
   end subroutine init_vector_metadata



! ----------------------------------------------------------------------  
   subroutine set_values_scalar()
! ----------------------------------------------------------------------  
   use MOD_integral
   use MOD_grid,                 only: numnod
   use plant_interface,          only: fl_cropharvest, fl_cropharvestday, dvs, tsum, cf, ch, sicact, vcover,                                                                          &
                                       lai, wrt, wst, wlv, wso, dwrt, dwst, dwlv, ipgass, igass, imres,                                            &
                                       laipot, wrtpot, wstpot, wlvpot, wsopot, dwrtpot, dwstpot, dwlvpot, ipgasspot, igasspot, imrespot,           &
                                       icut, tcut, dmhrv, dmloss, icutpot, tcutpot, dmhrvpot, dmlosspot, rd, max_resp_factor
   use MOD_swap_base,            only: swcrop

   use MOD_cropdevelopment,      only: fl_cropcalendar, rdpot
   use MOD_snow,                 only: ssnow
   use mod_RWU_micro,            only: PP, PL
   use MOD_SoilTemperature,      only: tetop, tebot
   use Wofost_Soil_Declarations, only: fom_end, fom_add, fom_cres, fom2bio, fom2hum, fom_dis, bio_end, bio2bio, bio2hum, bio_dis,                  &
                                       hum_end, hum_add, hum_cres, hum2bio, hum2hum, hum_dis, cdissi,                                              &
                                       nfom_end, nfom_add, nfom_cres, nfom2bio, nfom2hum, nfom_min, nbio_end, nbio2bio, nbio2hum, nbio_min,        &
                                       nhum_end, nhum_add, nhum_cres, nhum2bio, nhum2hum,nhum_min, nh4_miner,                                      &
                                       nh4_end, nh4n_amend, nh4n_cres, nh4_intop, nh4_inlat, nh4_inbot, nh4_upt, nh4_out, nh4n_volat, nh4_nitrif,  &
                                       no3_end, no3n_amend, no3n_cres, no3_intop, no3_inlat, no3_inbot, no3_upt, no3_out, no3_denitr,              &
                                       wflux_inTop
   use wofost_soil_interface,    only: NdemandSOIl, NsupplySoil
   use MOD_wofost_nut,           only: fstr
   use MOD_swap_mp,              only: wasrdm1, wasrdm2, iwasrdm1beg, iwasrdm2beg, vlmpdm1, vlmpdm2, walevdm1,                           &
                                       iqoutmtxsatdm1cp, iqoutmtxsatdm2cp, iqoutmtxunsdm1cp, iqoutmtxunsdm2cp, iqmpoutdrrap,                       &
                                       iqinintsatdm1cp, iqinintsatdm2cp, iqinmtxsatdm1cp, iqinmtxsatdm2cp, iqintoplatdm1, iqintoplatdm2,           &
                                       iqintopvrtdm1, iqintopvrtdm2, vlmpdycp, subsidcp
   use MOD_solute,               only: imsqprec, imsqirrig, imsqbot, imsqdra, imdectot, imrottot, sampro, sbaldev, sdstor
   use variables,                only: pond, gwl, pegwl, pegwl_bot, volact, ivolbeg, ipondbeg, issnowbeg, isicbeg
   use atmosphere_interface,     only: tav
   
   implicit none
   
   ! global
   ! local
   integer           :: i
   character(len=12) :: name
   real(8)           :: value, dstor, baldev
   real(8)           :: dstor_1, dstor_2, baldev_1, baldev_2
   
   ! mass balance calculations for output
   dstor        = (volact + pond + ssnow + sicact + wasrdm1 + wasrdm2) -                     & 
                  (ivolbeg + ipondbeg + issnowbeg + isicbeg + iwasrdm1beg + iwasrdm2beg)
   baldev       = (igrai+isnrai+igsnow+igird+irunon + iqssdi + iqbup) - dstor -              &
                  (iintc+iruno+iqrot+iepd+ievap+isubl+iqdra+iQMpOutDrRap+iqbdo)
   dstor_1    = wasrdm1 - iwasrdm1beg
   dstor_2    = wasrdm2 - iwasrdm2beg
   baldev_1   = (sum(iqinintsatdm1cp(1:numnod))  + sum(iqinmtxsatdm1cp(1:numnod)) + iqintopvrtdm1 + iqintoplatdm1) - &
                (sum(iqoutmtxsatdm1cp(1:numnod)) + sum(iqoutmtxunsdm1cp(1:numnod)) + iqmpoutdrrap) - dstor_1
   baldev_2   = (sum(iqinintsatdm2cp(1:numnod))  + sum(iqinmtxsatdm2cp(1:numnod)) + iqintopvrtdm2 + iqintoplatdm2) - &
                (sum(iqoutmtxsatdm2cp(1:numnod)) + sum(iqoutmtxunsdm2cp(1:numnod))) - dstor_2
   
   ! this provides the actual link between user-supplied name and internal variable name (MUST be uppercase)
   do concurrent (i = 1:M_s, vars_s%iyes(i) == 1)
      
      ! reset value
      value = -999.999d0
      
      name = vars_s%name(i)
      
      ! fluxes top
      if (name == 'RAIN')         value = igrai + isnrai
      if (name == 'RAIN_NET')     value = inrai
      if (name == 'SNOW')         value = igsnow
      if (name == 'IRRIG')        value = igird
      if (name == 'IRRIG_NET')    value = inird
      if (name == 'RUNON')        value = irunon
      if (name == 'RUNOFF')       value = iruno
      if (name == 'EIC')          value = iintc
      if (name == 'EPD')          value = iepd
      if (name == 'EPOT')         value = ipeva
      if (name == 'EACT')         value = ievap
      if (name == 'ESUBLIM')      value = isubl
      if (name == 'TOP_IN')       value = iqtdo
      if (name == 'TOP_OUT')      value = iqtup
      if (name == 'TOP')          value = iqtdo + iqtup
      

      ! fluxes side
      if (name == 'TPOT')         value = iptra
      if (name == 'TACT')         value = iqrot
      if (name == 'TREDDRY')      value = iqreddry
      if (name == 'TREDWET')      value = iqredwet
      if (name == 'TREDSOL')      value = iqredsol
      if (name == 'TREDFRS')      value = iqredfrs
      if (name == 'DRN')          value = iqdra + iQMpOutDrRap
      if (name == 'DRN_1')        value = sum(inqdra(1,1:numnod))
      if (name == 'DRN_2')        value = sum(inqdra(2,1:numnod))
      if (name == 'DRN_3')        value = sum(inqdra(3,1:numnod))
      if (name == 'DRN_4')        value = sum(inqdra(4,1:numnod))
      if (name == 'DRN_5')        value = sum(inqdra(5,1:numnod))
      if (name == 'SSDI')         value = iqssdi
      

      ! fluxes bottom
      if (name == 'BOT_IN')       value = iqbup
      if (name == 'BOT_OUT')      value = iqbdo
      if (name == 'BOT')          value = - iqbdo + iqbup
      

      ! storage
      if (name == 'GWL')          value = gwl
      if (name == 'PGWL')         value = pegwl
      if (name == 'PGWL_BOT')     value = pegwl_bot
      if (name == 'PD_VOL')       value = pond
      if (name == 'SNOW_VOL')     value = ssnow
      if (name == 'IC_VOL')       value = sicact
      if (name == 'WTOT')         value = volact
      if (name == 'DSTOR')        value = dstor
      if (name == 'BALDEV')       value = baldev
      

      ! macropore
      if (name == 'MP_WVOL_1')    value = wasrdm1
      if (name == 'MP_TVOL_1')    value = vlmpdm1
      if (name == 'MP_EXF_1')     value = sum(iqoutmtxsatdm1cp(1:numnod)) + sum(iqoutmtxunsdm1cp(1:numnod))
      if (name == 'MP_INF_1')     value = sum(iqinintsatdm1cp(1:numnod))  + sum(iqinmtxsatdm1cp(1:numnod))
      if (name == 'MP_TOP_1')     value = iqintopvrtdm1 + iqintoplatdm1
      if (name == 'MP_TOPD_1')    value = iqintopvrtdm1
      if (name == 'MP_TOPL_1')    value = iqintoplatdm1
      if (name == 'MP_DRN_1')     value = iqmpoutdrrap
      if (name == 'MP_GWL_1')     value = walevdm1
      if (name == 'MP_BALDEV_1')  value = baldev_1
      if (name == 'MP_WVOL_2')    value = wasrdm2
      if (name == 'MP_TVOL_2')    value = vlmpdm2
      if (name == 'MP_EXF_2')     value = sum(iqoutmtxsatdm2cp(1:numnod)) + sum(iqoutmtxunsdm2cp(1:numnod))
      if (name == 'MP_INF_2')     value = sum(iqinintsatdm2cp(1:numnod))  + sum(iqinmtxsatdm2cp(1:numnod))
      if (name == 'MP_TOP_2')     value = iqintopvrtdm2 + iqintoplatdm2
      if (name == 'MP_TOPD_2')    value = iqintopvrtdm2
      if (name == 'MP_TOPL_2')    value = iqintoplatdm2
      if (name == 'MP_BALDEV_2')  value = baldev_2
      if (name == 'MP_VOLDYN')    value = sum(vlmpdycp(1:numnod))
      if (name == 'MP_SUBSID')    value = sum(subsidcp(1:numnod))
      

      ! crop
      if (name == 'VCOVER')       value = vcover

      

      ! only if crop growth is activated

      if (swcrop == 1 .AND. fl_cropcalendar .AND. (.NOT. fl_cropharvest .OR. fl_cropharvestday)) then

      

         if (name == 'CH')           value = ch
         if (name == 'CF')           value = cf
         if (name == 'RDPOT')        value = rdpot

         if (name == 'RD')           value = rd
         if (name == 'LAIPOT')       value = laipot      

         if (name == 'LAI')          value = lai
         if (name == 'TSUM')         value = tsum
         if (name == 'DVS')          value = dvs
         if (name == 'PP')           value = PP
         if (name == 'PL')           value = PL
      
         ! crop (WOFOST)
         if (name == 'PWSO')         value = wsopot
         if (name == 'WSO')          value = wso

         if (name == 'PWLV')         value = wlvpot
         if (name == 'WLV')          value = wlv

         if (name == 'PWST')         value = wstpot
         if (name == 'WST')          value = wst

         if (name == 'PWRT')         value = wrtpot
         if (name == 'WRT')          value = wrt

         if (name == 'PDWLV')        value = dwlvpot
         if (name == 'DWLV')         value = dwlv

         if (name == 'PDWST')        value = dwstpot
         if (name == 'DWST')         value = dwst

         if (name == 'PDWRT')        value = dwrtpot
         if (name == 'DWRT')         value = dwrt

         if (name == 'PTWLV')        value = wlvpot + dwlvpot

         if (name == 'TWLV')         value = wlv + dwlv
         if (name == 'PTWST')        value = wstpot + dwstpot
         if (name == 'TWST')         value = wst + dwst

         if (name == 'PTWRT')        value = wrtpot + dwrtpot
         if (name == 'TWRT')         value = wrt + dwrt

         if (name == 'PWDM')         value = wsopot + wstpot + dwstpot + wlvpot + dwlvpot
         if (name == 'WDM')          value = wso + wst + dwst + wlv + dwlv


         if (name == 'PGASSTPOT')    value = ipgasspot
         if (name == 'PGASST')       value = ipgass
         if (name == 'GASSTPOT')     value = igasspot
         if (name == 'GASST')        value = igass
         if (name == 'MRESTPOT')     value = imrespot
         if (name == 'MREST')        value = imres
      
         ! crop (GRASS)
         if (name == 'ICUTPOT')      value = dble(icutpot)
         if (name == 'ICUT')         value = dble(icut)

         if (name == 'TCUTPOT')      value = dble(tcutpot)
         if (name == 'TCUT')         value = dble(tcut)

         if (name == 'PHRVDM')       value = dmhrvpot
         if (name == 'HRVDM')        value = dmhrv

         if (name == 'PLOSSDM')      value = dmlosspot
         if (name == 'LOSSDM')       value = dmloss
      
         if (name == 'MAX_RESP')     value = max_resp_factor

      end if

      
      ! solute
      if (name == 'S_RAIN')       value = imsqprec
      if (name == 'S_IRRIG')      value = imsqirrig
      if (name == 'S_BOT')        value = imsqbot
      if (name == 'S_DRN')        value = imsqdra
      if (name == 'S_DEC')        value = imdectot
      if (name == 'S_UPT')        value = imrottot
      if (name == 'S_STOT')       value = sampro
      if (name == 'S_BALDEV')     value = sbaldev
      if (name == 'S_DSTOR')      value = sdstor
      

      ! temperature
      if (name == 'T_ATM')        value = tav
      if (name == 'T_TOP')        value = TeTop
      if (name == 'T_BOT')        value = TeBot
      

      ! nutrients
      if (name == 'FOM')          value = fom_end * 1.0d+4
      if (name == 'FOM_ADD')      value = fom_add * 1.0d+4
      if (name == 'FOM_CRES')     value = fom_cres * 1.0d+4
      if (name == 'FOM2BIO')      value = fom2bio * 1.0d+4
      if (name == 'FOM2HUM')      value = fom2hum * 1.0d+4
      if (name == 'FOM_DIS')      value = fom_dis * 1.0d+4
      if (name == 'BIO')          value = bio_end * 1.0d+4
      if (name == 'BIO2BIO')      value = bio2bio * 1.0d+4
      if (name == 'BIO2HUM')      value = bio2hum * 1.0d+4
      if (name == 'BIO_DIS')      value = bio_dis * 1.0d+4
      if (name == 'HUM')          value = hum_end * 1.0d+4
      if (name == 'HUM_ADD')      value = hum_add * 1.0d+4
      if (name == 'HUM_CRES')     value = hum_cres * 1.0d+4
      if (name == 'HUM2BIO')      value = hum2bio * 1.0d+4
      if (name == 'HUM2HUM')      value = hum2hum * 1.0d+4
      if (name == 'HUM_DIS')      value = hum_dis * 1.0d+4
      if (name == 'CDISSI')       value = cdissi * 1.0d+4    
      if (name == 'NFOM')         value = nfom_end * 1.0d+4
      if (name == 'NFOM_ADD')     value = nfom_add * 1.0d+4
      if (name == 'NFOM_CRES')    value = nfom_cres * 1.0d+4
      if (name == 'NFOM2BIO')     value = nfom2bio * 1.0d+4
      if (name == 'NFOM2HUM')     value = nfom2hum * 1.0d+4
      if (name == 'NFOM_MIN')     value = nfom_min * 1.0d+4
      if (name == 'NBIO')         value = nbio_end * 1.0d+4
      if (name == 'NBIO2BIO')     value = nbio2bio * 1.0d+4
      if (name == 'NBIO2HUM')     value = nbio2hum * 1.0d+4
      if (name == 'NBIO_MIN')     value = nbio_min * 1.0d+4
      if (name == 'NHUM')         value = nhum_end * 1.0d+4
      if (name == 'NHUM_ADD')     value = nhum_add * 1.0d+4
      if (name == 'NHUM_CRES')    value = nhum_cres * 1.0d+4
      if (name == 'NHUM2BIO')     value = nhum2bio * 1.0d+4
      if (name == 'NHUM2HUM')     value = nhum2hum * 1.0d+4
      if (name == 'NHUM_MIN')     value = nhum_min * 1.0d+4
      if (name == 'NH4_MINER')    value = nh4_miner * 1.0d+4
      if (name == 'NH4')          value = nh4_end * 1.0d+4
      if (name == 'NH4N_AMEND')   value = nh4n_amend * 1.0d+4
      if (name == 'NH4N_CRES')    value = nh4n_cres * 1.0d+4
      if (name == 'NH4_INTOP')    value = nh4_intop * 1.0d+4
      if (name == 'NH4_INLAT')    value = nh4_inlat * 1.0d+4
      if (name == 'NH4_INBOT')    value = nh4_inbot * 1.0d+4
      if (name == 'NH4_UPT')      value = nh4_upt * 1.0d+4
      if (name == 'NH4_OUT')      value = nh4_out * 1.0d+4
      if (name == 'NH4N_VOLAT')   value = nh4n_volat * 1.0d+4
      if (name == 'NH4_NITRIF')   value = nh4_nitrif * 1.0d+4
      if (name == 'NO3')          value = no3_end * 1.0d+4
      if (name == 'NO3N_AMEND')   value = no3n_amend * 1.0d+4
      if (name == 'NO3N_CRES')    value = no3n_cres * 1.0d+4
      if (name == 'NO3_INTOP')    value = no3_intop * 1.0d+4
      if (name == 'NO3_INLAT')    value = no3_inlat * 1.0d+4
      if (name == 'NO3_INBOT')    value = no3_inbot * 1.0d+4
      if (name == 'NO3_UPT')      value = no3_upt * 1.0d+4
      if (name == 'NO3_OUT')      value = no3_out * 1.0d+4
      if (name == 'NO3_DENITR')   value = no3_denitr * 1.0d+4
      if (name == 'WFLUX_INTOP')  value = Wflux_inTop * 1.0d+3
      if (name == 'N_DEMAND')     value = NdemandSoil
      if (name == 'N_UPTAKE')     value = NsupplySoil
      if (name == 'N_STRESS')     value = fstr

      vars_s%value(i) = value
   

   end do
   
   end subroutine set_values_scalar
   
! ----------------------------------------------------------------------  
   subroutine set_values_vector()
! ----------------------------------------------------------------------  
   use MOD_grid,              only: numnod, dz
   use MOD_integral
   use variables,             only: h, theta, k, dimoca, ithetabeg
   use MOD_soiltemperature,   only: tsoil, heacap, heacon
   use O2_pars,               only: c_top
   use MOD_cropdevelopment,   only: cumdens_top, lrv_node, wroot_node
   use MOD_re_global,         only: hroot, mroot, mflux
   use MOD_solute,            only: imqsol, cml, cmsy
   use MOD_drain,             only: nrlevs
   use MOD_swap_mp,           only: iqexcmtxdm1cp, iqexcmtxdm2cp,iqtopmpdm1cp,iqtopmpdm2cp,iqoutdrrapcp,waunmpdm1cp,          &
                                    waunmpdm2cp,iavfrmpwlwtdm1,iavfrmpwlwtdm2,vlmpdycp,subsidcp,frarmtrx,vlmpdm1cp,vlmpdm2cp
   
   implicit none
   
   ! global
   ! local
   integer :: i

   do i = 1, M_v
      if (vars_v%iyes(i) == 1) then
         
         select case (trim(vars_v%name(i)))
      
         ! water states
         case ('H')            ; call fill_vector(h,                                 vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod, theta)
         case ('WC')           ; call fill_vector(theta,                             vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('K')            ; call fill_vector(K,                                 vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('C')            ; call fill_vector(dimoca,                            vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         ! soil temperature
         case ('T')            ; call fill_vector(tsoil,                             vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('HEACAP')       ; call fill_vector(heacap/1.0d-6,                     vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('HEACON')       ; call fill_vector(heacon/864.0d0,                    vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         ! fluxes
         case ('Q')            ; call fill_vector(inq,                               vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('QSSDI')        ; call fill_vector(inqssdi,                           vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('RWU')          ; call fill_vector(inqrot,                            vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('PRWU')         ; call fill_vector(inqpotrot,                         vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('RRWU')         ; call fill_vector(inqredrot,                         vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('QDRN')         ; call fill_vector(sum(inqdra(1:nrlevs,:), dim=1),    vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('QDRN_1')       ; call fill_vector(inqdra(1,:),                       vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('QDRN_2')       ; call fill_vector(inqdra(2,:),                       vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('QDRN_3')       ; call fill_vector(inqdra(3,:),                       vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('QDRN_4')       ; call fill_vector(inqdra(4,:),                       vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('QDRN_5')       ; call fill_vector(inqdra(5,:),                       vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         ! crop
         case ('O2TOP')        ; call fill_vector(c_top,                             vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod) ! NOTE: is this variable defined at top of node?
         case ('RDENS')        ; call fill_vector(cumdens_top(2:numnod+1)-cumdens_top(1:numnod), vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('LRV')          ; call fill_vector(lrv_node,                          vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('HROOT')        ; call fill_vector(hroot,                             vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('MROOT')        ; call fill_vector(mroot,                             vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('MFLUX')        ; call fill_vector(mflux,                             vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('WROOT')        ; call fill_vector(wroot_node,                        vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         ! solute
         case ('S_CONC')       ; call fill_vector(cml,                               vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('S_CONCADS')    ; call fill_vector(cmsy,                              vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('S_QSOL')       ; call fill_vector(imqsol,                            vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         ! macropore
         case ('MPC_Q_1')      ; call fill_vector(iqtopmpdm1cp,                      vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('MPC_QEXC_1')   ; call fill_vector(iqexcmtxdm1cp,                     vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('MPC_QDRN_1')   ; call fill_vector(iqoutdrrapcp,                      vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('MPC_WVOL_1')   ; call fill_vector(waunmpdm1cp,                       vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('MPC_TVOL_1')   ; call fill_vector(VlMpDm1Cp,                         vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('MPC_WET_1')    ; call fill_vector(iavfrmpwlwtdm1,                    vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('MPC_Q_2')      ; call fill_vector(iqtopmpdm2cp,                      vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('MPC_QEXC_2')   ; call fill_vector(iqexcmtxdm2cp,                     vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('MPC_WVOL_2')   ; call fill_vector(waunmpdm2cp,                       vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('MPC_TVOL_2')   ; call fill_vector(VlMpDm2cp,                         vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('MPC_WET_2')    ; call fill_vector(iavfrmpwlwtdm2,                    vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('MPC_VOLDYN')   ; call fill_vector(vlmpdycp,                          vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('MPC_SUBSID')   ; call fill_vector(subsidcp,                          vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('MPC_VOLSTA_1') ; continue ! static parameter; need only be calculated once in init_vars()
         case ('MPC_VOLSTA_2') ; continue ! static parameter; need only be calculated once in init_vars()
         case ('MPC_DIPO')     ; continue ! static parameter; need only be calculated once in init_vars()
         case ('MPC_FRARMTRX') ; continue ! static parameter; need only be calculated once in init_vars()
            
         ! subregion             (NB: SR_DSTOR only works for constant frarmtrx)
         case ('SR_WTOT')      ; call fill_vector(theta*dz*frarmtrx,                 vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('SR_DSTOR')     ; call fill_vector((theta - ithetabeg)*dz*frarmtrx,   vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('SR_RWU')       ; call fill_vector(inqrot,                            vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('SR_TOP')       ; call fill_vector(-inq,                              vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('SR_BOT')       ; call fill_vector(-inq,                              vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod) 
         case ('SR_DRN')       ; call fill_vector(sum(inqdra(1:nrlevs,:), dim=1),    vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('SR_SSDI')      ; call fill_vector(inqssdi,                           vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('SR_TOP_IN')    ; call fill_vector(iqdo,                              vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod) 
         case ('SR_TOP_OUT')   ; call fill_vector(iqup,                              vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('SR_BOT_IN')    ; call fill_vector(iqup,                              vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('SR_BOT_OUT')   ; call fill_vector(iqdo,                              vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('SR_DRN_IN')    ; call fill_vector(sum(inqdra_in(1:nrlevs,:), dim=1), vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
         case ('SR_DRN_OUT')   ; call fill_vector(sum(inqdra_out(1:nrlevs,:), dim=1),vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
           
         case default
            message = 'Error: unrecognized variable name ' // trim(vars_v%name(i)) // '. Adjust inlist_csv!'
            call swap_error('set_values_tz',message)
         end select
         
      end if   
   end do

   end subroutine set_values_vector
   
! ---------------------------------------------------------------------- 
   subroutine fill_vector(inval,outval,name,nnod,conv,itzq,subr,nodes,inval2)
! ---------------------------------------------------------------------- 
   use MOD_MvG,    only: prhead, cofgen
   use MOD_arrays, only: mcof
   use MOD_grid,   only: dz
   
   implicit none
   
   ! global
   character(len=*),        intent(in)            :: name
   integer,                 intent(in)            :: nnod,conv,itzq,subr
   integer, dimension(:,:), intent(in)            :: nodes
   real(8), dimension(:), intent(in)            :: inval
   real(8), dimension(:), intent(in), optional  :: inval2
   real(8), dimension(:), intent(out)           :: outval
   ! local
   real(8)                              :: dztot, disnodtot
   real(8), dimension(macp)             :: tempval
   real(8), dimension(mcof,macp)        :: cofgennew
   integer                              :: i, j, k, cof

   
   outval(:) = 0.0d0
   tempval(:) = 0.0d0
   

   
   ! i = refers to node index in output
   ! j = for subregions: output aggregation based on subregions. nodes(i,1:2) refer to start and end node of subregion AFTER grid conversion (see k)
   ! k = for swdiscrvert: output aggregation based on grid conversion with dznew. k refers to node nr of original grid

   if (subr == 0 .AND. swdiscrvert == 0) then
      ! No conversion of discretization: copy paste
      outval(1:nnod) = inval(nodes(1:nnod,1))
      if (nnod == numnodnew .AND. itzq == 1) then
         outval(nnod+1) = inval(nnod+1)
      end if
   else
      ! Handle conversion of discretization AND/OR subregions
      if (conv == 1) then ! Weighed average
         do i = 1, nnod
            dztot = sum(dznew(nodes(i,1):nodes(i,2)))
            do j = nodes(i,1), nodes(i,2)
               do k = nodenew(j,1),nodenew(j,2)
                  outval(i) = outval(i) + inval(k)*dz(k)/dztot
               end do
            end do
         end do
      else if (conv == 2) then ! Integration/summation
         do i = 1, nnod
            do j = nodes(i,1), nodes(i,2)
               do k = nodenew(j,1), nodenew(j,2)
                  outval(i) = outval(i) + inval(k)
               end do
            end do
         end do
      else if (conv == 3) then ! Top value
         do i = 1, nnod
            j = nodes(i,1)
            k = nodenew(j,1)
            if (j == numnodnew + 1) k = nodenew(numnodnew,2) + 1
            outval(i) = inval(k)
         end do
         if (itzq == 1 .AND. subr == 0 .AND. size(outval) == nnod+1) then 
            ! provide bottom value for tzq ONLY if last of the requested values is at the bottom of soil column
            j = nodes(nnod,2)
            k = nodenew(j,2)
            outval(nnod+1) = inval(k+1) 
         end if
      else if (conv == 4) then ! Bot value
         do i = 1, nnod
            j = nodes(i,2)
            k = nodenew(j,2)
            outval(i) = inval(k+1)
         end do
      else if (conv == 5) then ! Special cases
         do i = 1, nnod ! Weighed average of inval2
            dztot = sum(dznew(nodes(i,1):nodes(i,2)))
            disnodtot = sum(disnodnew(nodes(i,1):nodes(i,2)))
            do j = nodes(i,1), nodes(i,2)
               do k = nodenew(j,1),nodenew(j,2)
                  tempval(i) = tempval(i) + inval2(k)*dz(k)/dztot
               end do
            end do
            
            do cof = 1, 9
               cofgennew(cof,i) = cofgen(cof, nodenew(nodes(i,2),2)) ! assumes properties of bottom node of given interval
            end do

            if (trim(name) == 'H') outval(i) = prhead (i, disnodtot, tempval(i), cofgennew, outval) 
            ! moiscap not available
            ! hconduc not available
         end do
      else        

         message = "Illegal conversion type for converting discretization of variable " // trim(name) // "."
         call swap_error ("csv_tz_write", message)
      end if
   end if
   
   end subroutine fill_vector

! ----------------------------------------------------------------------  
   subroutine csv_out(iTask, dtprint)
! ----------------------------------------------------------------------  
   use MOD_swap_base, only: iun_min, iun_max, pathwork
   use variables,     only: outfil, date, t1900, flprintshort, swcsv
   
   implicit none

   ! global
   integer,                    intent(in)  :: iTask
   character(len=*), optional, intent(in)  :: dtprint
   ! local
   integer              :: i, j, il, pos, nvars
   character(len=19)    :: datexti
   character(len=20)    :: form
   character(len=30)    :: myval
   character(:), allocatable, save         :: line      ! ascii output
   real(4),      allocatable, save         :: buffer(:) ! binary output
   ! functions
   integer              :: getun

   select case (iTask)
   case (1)
            
      call init_vector_metadata()

      ! initialize vertical discretization for output
      call init_discr()
      
      ! set format for output
      call what_form(1)

      ! to be based on user input information
!      InList = 'H[-10.0;4;5], RAIN, WC[2;3;6], H[4], WTOT[0:-15.0;4:6], Tact, WC[1], WC[-2], WC[1], rain,GWL, RWU[1;2;3;4;5;6], QTRANS[1:3;4:6], qtopin[0:-30]'
      Inlist = InList_csv

      ! extract all individual vars from InList;
      call make_userlist(InList)
      ! merge same vars with [] in single var with []; determine required nodenumbers; remove double entries
      call merge_items()
      ! determine which vars are required; allocate and initialize; fill static output
      call init_vars()
      
      ! total nr of output parameters
      parlen = 1 ! DATE
      if (out_s) parlen = parlen + sum(vars_s%iyes)
      if (out_v) then
         do i = 1, M_v
            if (vars_v%iyes(i) == 1) parlen = parlen + vars_v%nval(i) !!!size(vars_v%value(i)%val)
         end do
      end if
      
      ! output file; write header and initial information for binary file
      iuncsv = getun (iun_min, iun_max)
      if (swcsv < 3) then ! ascii
!DEC$ IF DEFINED (multiswap)
         if (allocated(line)) deallocate(line); allocate(character(len=parlen*(num_d+7)) :: line)
!DEC$ ELSE
         allocate(character(len=parlen*(num_d+7)) :: line)
!DEC$ END IF
         filcsv = trim(pathwork) // trim(outfil) // '_output.csv'
         open(unit=iuncsv, file=filcsv, status="replace", action="write")
      else if (swcsv == 3) then ! binary
!DEC$ IF DEFINED (multiswap)
         if (allocated(buffer)) deallocate(buffer); allocate(buffer(parlen-1))
!DEC$ ELSE
         allocate(buffer(parlen-1))
!DEC$ END IF
         filcsv = trim(pathwork) // trim(outfil) // '_output.bin'
         open(unit=iuncsv, file=filcsv, status='replace', action='write',form='unformatted',access='stream')
      end if
      
      call make_header(iuncsv, filcsv)

   case (2)
      ! dynamic
      if (out_s) call set_values_scalar()
      if (out_v) call set_values_vector()
      
      if (swcsv < 3) then ! ascii
         line = repeat(' ', parlen*(num_d+7)) ; il=0
   
         ! datetime
         if (.NOT. flprintshort) then
            if (present(dtprint)) then
               call addstr(line, il, trim(dtprint)); call addstr(line, il, ",")
            else
               call addstr(line, il, trim(date)); call addstr(line, il, ",")
            end if
         else
            call dtdpst ('year-month-day hour:minute:seconds', t1900, datexti)
            call addstr(line, il, trim(datexti)); call addstr(line, il, ",")
         end if
  
         ! scalar
         if (out_s) then
            do i = 1, M_s
               if (vars_s%iyes(i) == 1) then
                  call what_form(2,    vars_s%value(i), form)
                  write (myval, form)  vars_s%value(i)
                  line = line(1:il) // trim(adjustl(myval)); il = len_trim(line)
               end if
            end do
         end if
   
         ! vector
         if (out_v) then
            do i = 1, M_v
               if (vars_v%iyes(i) == 1) then
                  do j = 1, vars_v%nval(i) !!!size(vars_v%value(i)%val)
                        call what_form(2,    vars_v%value(i)%val(j), form)
                        write (myval, form)  vars_v%value(i)%val(j)
                        line = line(1:il) // trim(adjustl(myval)); il = len_trim(line)
                     end do
               end if
            end do
         end if

         ! write result (skip last character which is a comma)
         write(iuncsv,'(A)') line(1:il-1)
      
      else if (swcsv == 3) then ! binary
         ! datetime
         if (.NOT. flprintshort) then
            if (present(dtprint)) then
               datexti = trim(dtprint)
            else
               datexti = trim(date)
            end if
         else
            call dtdpst ('year-month-day hour:minute:seconds', t1900, datexti)
         end if
      
         pos = 0
      
         ! scalar
         if (out_s) then
            do i = 1, M_s
               if (vars_s%iyes(i) == 1) then
                  pos = pos + 1
                  buffer(pos) = real(vars_s%value(i))
               end if
            end do
         end if

         ! vector
         if (out_v) then
            do i = 1, M_v
               if (vars_v%iyes(i) == 1) then
                  nvars = vars_v%nval(i) !!!size(vars_v%value(i)%val)
                  buffer(pos+1:pos+nvars) = real(vars_v%value(i)%val)
                  pos = pos + nvars
               end if
            end do
         end if
      
         ! write result
         write(iuncsv) datexti, buffer
      end if

   case (3)
      
      close (unit=iuncsv)

   case default
      
      call swap_error ("csv_out", "Illegal iTask")

   end select

   end subroutine csv_out
   
! ----------------------------------------------------------------------
   subroutine init_discr()
! ----------------------------------------------------------------------
   use MOD_grid, only: z, dz, disnod, zbotcp, ztopcp, botcom, numnod
   
   implicit none
   
   ! global
   ! local
   integer :: k
   
   if (swdiscrvert == 1) then
   ! adjust vertical discretization (for output only)
      call checkdiscrvert()
      call convertdiscrvert()
      zbotnew = znew-0.5d0*dznew
      ztopnew = znew+0.5d0*dznew
   else 
   ! create copies
      znew = z
      dznew = dz
      disnodnew = disnod
      zbotnew = zbotcp
      ztopnew = ztopcp
      botcomnew = botcom
      numnodnew = numnod
      nodenew(1:numnod,:) = spread([(k, k = 1,numnod)],dim=2,ncopies=2)
   end if
      
   if (tz_z1_z2(1) >= 0.0d0 .AND. tz_z1_z2(2) >= 0.0d0) then
      ! max range for output
      nod_1 = 1
      nod_2 = numnodnew
   else
      ! limit output range for tz output (applies only when no [] supplied)
      if (tz_z1_z2(2) > tz_z1_z2(1)) call swap_error("swap_csv","tz_z2 is larger than tz_z1. Adjust input of tz_z1_z2!")

      nod_1 = nodenumber(real(tz_z1_z2(1)),1)
      nod_2 = nodenumber(real(tz_z1_z2(2)),2)
   end if

   nnodes = nod_2-nod_1+1
   
   end subroutine init_discr
   
! ----------------------------------------------------------------------
   subroutine init_vars()
! ----------------------------------------------------------------------
   use MOD_swap_base, only: swmacro
   use MOD_swap_mp,   only: vlmpstdm1, vlmpstdm2, dipocp, frarmtrx
   
   implicit none
   
   ! global
   ! local
   integer                  :: i,j,k,ipos1,ipos2,nnod
   integer, dimension(macp) :: nodstart, nodend
   character(len=48)        :: str
   logical                  :: found
   
   ! initialize
   vars_s%iyes  = 0
   vars_s%value = -999.d0
      
   vars_v%iyes  = 0
   vars_v%nnod  = 0
   
   ! determine which vars are required
   do i = 1, nlist
      ipos1 = index(userlist(i), "[")
      found = .FALSE.
      ! scalar
      do j = 1, M_s
         if (ipos1 == 0) then
            if (trim(userlist(i)) == trim(vars_s%name(j))) then
               vars_s%iyes(j) = 1
               out_s = .TRUE.
               found = .TRUE.
               exit
            end if
         else
            if (userlist(i)(1:ipos1-1) == trim(vars_s%name(j))) then
               vars_s%iyes(j) = 1
               userlist(i) = userlist(i)(1:ipos1-1) ! remove []
               out_s = .TRUE.
               found = .TRUE.
               exit
            end if
         end if
      end do
      if (found) cycle
      ! vector
      do j = 1, M_v
         if (swdiscrvert == 1) then
            if (userlist(i) == 'K') call swap_error ('swap_csv','K can currently not be rescaled to new grid (swdiscrvert == 1). Consider removing K from inlist_csv.')
            if (userlist(i) == 'C') call swap_error ('swap_csv','C can currently not be rescaled to new grid (swdiscrvert == 1). Consider removing C from inlist_csv.')
         end if
         
         if (ipos1 == 0) then 
         ! all available nodes
            if (trim(userlist(i)) == trim(vars_v%name(j))) then
               if (vars_v%subr(j) == 1) call swap_error ("swap_csv", "Variable for subregions supplied without specifying subregions between [].")

!DEC$ IF DEFINED (multiswap)
               !if (allocated(vars_v%nodes(j)%nod)) deallocate(vars_v%nodes(j)%nod); allocate (vars_v%nodes(j)%nod(macp,2))
               if (allocated(vars_v%value(j)%val)) deallocate(vars_v%value(j)%val); allocate (vars_v%value(j)%val(macp+vars_v%itzq(j)))
!DEC$ ELSE
               allocate (vars_v%nodes(j)%nod(nnodes,2))
               allocate (vars_v%value(j)%val(nnodes+vars_v%itzq(j)))
!DEC$ END IF

               vars_v%nodes(j)%nod(1:nnodes,1) = [(k, k = nod_1, nod_2)]
               vars_v%nodes(j)%nod(1:nnodes,2) = [(k, k = nod_1, nod_2)]
               vars_v%value(j)%val = -999.d0
               vars_v%iyes(j) = 1
               vars_v%nnod(j) = nnodes
               vars_v%nval(j) = nnodes + vars_v%itzq(j)
                  
               out_v = .TRUE.
               exit
            end if
         else
         ! selection of nodes
            if (userlist(i)(1:ipos1-1) == trim(vars_v%name(j))) then
               ipos2 = index(userlist(i), "]")
               str = userlist(i)(ipos1+1:ipos2-1)
               call det_nodes(str,vars_v%subr(j),vars_v%itzq(j),nnod,nodstart,nodend)            
               call my_piksrt(nnod, nodstart(1:nnod), nodend(1:nnod))

!DEC$ IF DEFINED (multiswap)
               !if (allocated(vars_v%nodes(j)%nod)) deallocate(vars_v%nodes(j)%nod); allocate (vars_v%nodes(j)%nod(macp,2))
               if (allocated(vars_v%value(j)%val)) deallocate(vars_v%value(j)%val); allocate (vars_v%value(j)%val(macp+1))   
!DEC$ ELSE
               allocate (vars_v%nodes(j)%nod(nnod,2))
               allocate (vars_v%value(j)%val(nnod))
!DEC$ END IF

               vars_v%nodes(j)%nod(1:nnod,1) = nodstart(1:nnod)
               vars_v%nodes(j)%nod(1:nnod,2) = nodend(1:nnod)
               vars_v%value(j)%val = -999.d0
               vars_v%iyes(j) = 1
               vars_v%nnod(j) = nnod
               vars_v%nval(j) = nnod
                  
               out_v = .TRUE.
               exit               
            end if
         end if
      end do
   end do   
   
   ! initialize static variables for macropore output. Are only written to file if swcsv > 1.
   if (out_v .AND. swmacro == 1) then
      do i = 1, M_v
         if      (vars_v%name(i) == 'MPC_VOLSTA_1' .AND. vars_v%iyes(i) == 1) then 
            call fill_vector(vlmpstdm1, vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
            vars_v%iyes(i) = 0
         else if (vars_v%name(i) == 'MPC_VOLSTA_2' .AND. vars_v%iyes(i) == 1) then
            call fill_vector(vlmpstdm2, vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
            vars_v%iyes(i) = 0
         else if (vars_v%name(i) == 'MPC_DIPO'     .AND. vars_v%iyes(i) == 1) then
            call fill_vector(dipocp,    vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
            vars_v%iyes(i) = 0
         else if (vars_v%name(i) == 'MPC_FRARMTRX' .AND. vars_v%iyes(i) == 1) then
            call fill_vector(frarmtrx,  vars_v%value(i)%val, vars_v%name(i), vars_v%nnod(i), vars_v%conv(i), vars_v%itzq(i), vars_v%subr(i), vars_v%nodes(i)%nod)
            vars_v%iyes(i) = 0
         end if
      end do
   end if
   
   end subroutine init_vars
   
! ----------------------------------------------------------------------
   subroutine checkDiscrVert()
! ----------------------------------------------------------------------
   use MOD_grid,  only: dz, numnod
   
   implicit none

!  global
!  local
   integer                   :: inew,iold,iotmp
   real(8)                   :: cumdzOld,cumdzNew
   real(8), dimension(macp)  :: cumdzN

   real(8), parameter        :: small = 0.0001d0

!  Boundary of new compartments must equal boundaries of old compartments: new size is sum of old sizes
   cumdzN = 0.d0
   iotmp = 0
   do inew = 1, numnodNew
      do iold = 1, numnod
         if (iold > iotmp .AND. cumdzN(inew) < dzNew(inew)) then
            cumdzN(inew) = cumdzN(inew) + dz(iold)
            iotmp = iold
         end if
      end do
   end do
   do inew = 1, numnodNew
      if (abs(dzNew(inew)-cumdzN(inew)) > small) then
         write(message,'(a,i5)') 'New discretization has error in size of new compartment ', inew
         call swap_error ('checkdiscrvert',message)
      end if
   end do

!  Cumulative thickness
   cumdzOld = sum(dz(1:numnod))
   cumdzNew = sum(dznew(1:numnodnew))
   if (abs(cumdzNew-cumdzOld) > small) then
      write(message,'(a,f10.5)') 'New discretization is wrong, total length differs > ', small
      call swap_error ('checkdiscrvert',message)
   end if
   
   end subroutine checkDiscrVert

! ----------------------------------------------------------------------
   subroutine convertDiscrVert()
! ----------------------------------------------------------------------
   use MOD_grid,   only: dz, numlay, botcom, numnod
   
   implicit none
   
!  global
!  local
   integer :: lay,node,nodeN
   real(8) :: total
   
!  Calculate zNew = depth at bottom of new compartment
   Total = 0.0d0
   do node = 1, numnodNew
      Total      = Total + dzNew(node)
      zNew(node) = Total
   end do
!  Fill array NodeNew(Numnod,1) = top old compartment and NodeNew(Numnod,2) = bottom old comp. in new comp. 
   NodeN = 1
   Node  = 1
   Total = 0.0d0
   do while (node <= numnod) 
      Total = Total + dz(node) 
      if (abs(zNew(NodeN)-Total) < 1.0D-6) then
         NodeNew(NodeN,2) = Node
         NodeN            = NodeN+1
      end if
      node = node+1
   end do
   NodeNew(1,1) = 1
   do node = 2, numnodNew
      NodeNew(Node,1) = NodeNew(Node-1,2)+1
   end do
!  BotcomNew (for output)
   do lay = 1, numlay
      do node = 1, numnodNew
         if (NodeNew(Node,2) == botcom(lay)) then
            botcomNew(lay) = node
         end if
      end do
   end do

!  recalculate znew (= position of nodal points) and distances between them
   zNew(1)      = -0.5d0*dzNew(1)
   disnodNew(1) = -zNew(1)
   do node = 2, numnodNew
      zNew(node)      = zNew(node-1)-0.5d0*(dzNew(node-1)+dzNew(node))
      disnodNew(node) = zNew(node-1)-zNew(node)
   end do
   
   end subroutine convertDiscrVert

! ----------------------------------------------------------------------  
   subroutine det_nodes(str,issub,istzq,nnod,nodstart,nodend)
! ----------------------------------------------------------------------  
   implicit none
   
   ! global
   character(len=*),      intent(in)  :: str
   integer,               intent(in)  :: issub
   integer,               intent(in)  :: istzq
   integer,               intent(out) :: nnod
   integer, dimension(:), intent(out) :: nodstart
   integer, dimension(:), intent(out) :: nodend
   ! local
   integer, parameter       :: ilw = 1000
   integer, dimension(ilw)  :: iwbeg, iwend
   integer                  :: ifnd, ipos, i, j, k
   integer                  :: iwar, num1, num2
   character(len=9)         :: tmp 
   logical                  :: found
                  
   call words (str, ilw, ';', iwbeg, iwend, ifnd)
   
   nnod = 0
                  
   do i = 1, ifnd
      tmp = str(iwbeg(i):iwend(i))
      ipos = index(tmp,":")
      if (ipos > 0) then 
         ! range of nodes OR subregion
         call decint(iwar, tmp(1:ipos-1), num1)
         call decint(iwar, tmp(ipos+1:), num2)
         if ((istzq == 0 .AND. num2 > numnodnew) .OR. (istzq == 1 .AND. num2 > numnodnew+1)) then
            message = "Requested output node nr " // tmp(ipos+1:) // " exceeds maximum number of nodes. Adjust inlist_csv!"
            call swap_error ("det_nodes", message)
         end if
         if (issub == 0) then
            do j = 1, num2-num1+1
               nodstart(nnod+j) = num1+j-1
               nodend(nnod+j) = num1+j-1
            end do
            nnod = nnod + num2-num1+1
         else
            nnod = nnod + 1
            nodstart(nnod) = num1
            nodend(nnod) = num2
         end if
      else
         ! single node
         call decint(iwar, tmp, num1)
         if ((istzq == 0 .AND. num1 > numnodnew) .OR. (istzq == 1 .AND. num1 > numnodnew+1)) then
            message = "Requested output node nr " // tmp // " exceeds maximum number of nodes. Adjust inlist_csv!"
            call swap_error ("det_nodes", message)
         end if
         nnod = nnod + 1
         nodstart(nnod) = num1
         nodend(nnod) = num1
      end if
   end do   
   
   ! remove duplicates
   k = 0
   do i = 1, nnod
      found = .FALSE.
      do j = 1, k
         if (nodstart(i) == nodstart(j) .AND. nodend(i) == nodend(j)) then 
            found = .TRUE.
            exit
         end if
      end do
      if (.NOT. found) then
         k = k + 1
         if (.NOT. (i == k)) then
            nodstart(k) = nodstart(i)
            nodend(k) = nodend(i)
         end if
      end if
   end do
   
   nnod = k
   
   end subroutine det_nodes
   
! ----------------------------------------------------------------------  
   subroutine what_form(iTask, var, form)
! ----------------------------------------------------------------------  
   implicit none
   
   ! global
   integer,          intent(in)            :: iTask
   real(8),          intent(in),  optional :: var
   character(len=*), intent(out), optional :: form
   ! local
   ! when to automatically switch from F to E formatting
   integer,           parameter           :: expo = 4
   real(8),           parameter           :: t1 = 1.0d0/(10.0d0**expo)
   real(8),           parameter           :: t2 = 10.0d0**expo
   character(len=2)                       :: cval1, cval2
   character(len=20), save                :: form_rea_F1, form_rea_E1,form_rea_F0

   if (iTask == 1) then
      ! some basic info
      !  Note: field width of zero in I and F edit descriptors is allowed as of Fortran95 to ensure as little space usage
      !        in output file as possible (Metcalf et al., 2004, Fortran 95/2003 explained, Oxford Univ. Prrss, p. 199)
      write (cval1,'(I0)') num_d
      write (cval2,'(I0)') num_d + 7
      form_rea_F0 = '(F0.0,",")'
      form_rea_F1 = '(F0.' // trim(cval1) // ',",")'
      form_rea_E1 = '(1P,E' // trim(cval2) // '.' // trim(cval1) // ',",")'
   else
      if (abs(var) < 1.0D-10) then
         form = form_rea_F0
      else if (abs(var) < t1 .OR. abs(var) > t2) then
         form = form_rea_E1
      else
         form = form_rea_F1
      end if
   end if
   
   end subroutine what_form

! ----------------------------------------------------------------------  
   subroutine make_header(iuncsv, filcsv)
! ----------------------------------------------------------------------  
   use MOD_grid,      only: numlay, botcom
   use MOD_swap_base, only: project, swmacro
   use variables,     only: thetas, flprintshort, swcsv
   use MOD_mvg,       only: watcon
   
   implicit none
   
   ! global
   integer,          intent(in) :: iuncsv
   character(len=*), intent(in) :: filcsv
   ! local
   character(len=:),  allocatable :: csv_units, csv_names
   character(len=24), allocatable :: bin_names(:)               ! note: do not adjust character len for binary output
   character(len=10)              :: zdum1, zdum2
   character(len=*),  parameter   :: form = '(F8.2)'
   integer                        :: il1, il2, i, j, pos
   integer, dimension(4)          :: varpos

   ! write universal header (+ pre-table information for binary output)
   if (swcsv < 3) then ! ascii
      
      if (swcsv == 2) call csv_out_init()
      
      call writehead (iuncsv, 1, filcsv, 'specified output data of SWAP', project)

   else if (swcsv == 3) then ! binary
      
      call writehead (iuncsv, 0, filcsv, 'specified output data of SWAP', project)
      write(iuncsv) numnodnew, numlay, swmacro, parlen
   
      write(iuncsv) botcomnew(1:numlay)
      write(iuncsv) real(thetas(botcom(1:numlay)))
      do i = 1, numlay ; write(iuncsv) real(watcon(botcom(i),-100.d0)) ; end do
      do i = 1, numlay ; write(iuncsv) real(watcon(botcom(i),-15849.0d0)) ; end do
      write(iuncsv) real(dznew(1:numnodnew))
      
      if (swmacro == 1) then
         do i = 1, M_v
           if (vars_v%name(i) == 'MPC_VOLSTA_1')  varpos(1) = i
           if (vars_v%name(i) == 'MPC_VOLSTA_2')  varpos(2) = i
           if (vars_v%name(i) == 'MPC_DIPO')     varpos(3) = i
           if (vars_v%name(i) == 'MPC_FRARMTRX') varpos(4) = i
         end do
         
         do i = 1, 4
            if (.NOT. (size(vars_v%value(varpos(i))%val) == numnodnew)) then 
               call swap_error ("make_header", "Variable length of static macropore variables does not match numnodnew for binary output!")
            end if
            write(iuncsv) real(vars_v%value(varpos(i))%val(1:numnodnew))
         end do
      end if
   end if
   
   ! datetime
   if (swcsv < 3) then ! ascii
!DEC$ IF DEFINED (multiswap)
      if (allocated(csv_units)) deallocate(csv_units); allocate(character(len=parlen*12+12) :: csv_units)
      if (allocated(csv_names)) deallocate(csv_names); allocate(character(len=parlen*24+12) :: csv_names)
!DEC$ ELSE
      allocate(character(len=parlen*12+12) :: csv_units)
      allocate(character(len=parlen*24+12) :: csv_names)
!DEC$ END IF
      csv_units = repeat(' ', parlen*12+12); il1 = 0
      csv_names = repeat(' ', parlen*24+12); il2 = 0
      if (.NOT. flprintshort) then
         call addstr(csv_units, il1,'* (yyyy-mm-dd)')
         call addstr(csv_names, il2,'DATE')
      else
         call addstr(csv_units, il1,'* (yyyy-mm-dd hh:mm:ss)')
         call addstr(csv_names, il2,'DATETIME')
      end if
   else if (swcsv == 3) then ! binary
!DEC$ IF DEFINED (multiswap)
      if (allocated(bin_names)) deallocate(bin_names); allocate(bin_names(parlen))
!DEC$ ELSE
      allocate(bin_names(parlen))
!DEC$ END IF
      if (.NOT. flprintshort) then ! ensure 24 character length!
         bin_names(1) = 'DATE                    '
      else
         bin_names(1) = 'DATETIME                '
      end if
      pos = 2
   end if
   
   ! scalar
   do i = 1, M_s
      if (vars_s%iyes(i) == 1) then
         if (swcsv < 3) then ! ascii
            call addstr(csv_units, il1, "," // vars_s%unit(i))
            call addstr(csv_names, il2, "," // vars_s%name(i))
         else if (swcsv == 3) then ! binary
            bin_names(pos) = vars_s%name(i) 
            pos = pos + 1
         end if
      end if
   end do
   
   ! vector
   do i = 1, M_v
       if (vars_v%iyes(i) == 1) then
         do j = 1, vars_v%nnod(i)
            if (vars_v%itzq(i) == 1 .OR. vars_v%subr(i) == 1) then
               write(zdum1,form) ztopnew(vars_v%nodes(i)%nod(j,1))
            else
                write(zdum1,form) znew(vars_v%nodes(i)%nod(j,1))
            end if
            if (vars_v%subr(i) == 1) write(zdum2,form) zbotnew(vars_v%nodes(i)%nod(j,2))
            if (vars_v%itzq(i) == 1 .AND. vars_v%nodes(i)%nod(j,2) == numnodnew + 1) write(zdum1,form) zbotnew(numnodnew)
            
            if (swcsv < 3) then ! ascii
               call addstr(csv_units, il1, "," // vars_v%unit(i))
               if (vars_v%subr(i) == 1) then
                  call addstr(csv_names, il2, "," // trim(vars_v%name(i)) // "[" // trim(adjustl(zdum1)) // ":" // trim(adjustl(zdum2)) // "]")
               else
                  call addstr(csv_names, il2, "," // trim(vars_v%name(i)) // "[" // trim(adjustl(zdum1)) //"]")
               end if
            else if (swcsv == 3) then ! binary
               if (vars_v%subr(i) == 1) then
                  bin_names(pos) = trim(vars_v%name(i)) // "[" // trim(adjustl(zdum1)) // ":" // trim(adjustl(zdum2)) // "]"
               else
                  bin_names(pos) = trim(vars_v%name(i)) // "[" // trim(adjustl(zdum1)) // "]"
               end if
               pos = pos + 1
            end if
         end do
         if (vars_v%nval(i) > vars_v%nnod(i) .AND. vars_v%itzq(i) == 1) then   !!! size(vars_v%value(i)%val)
            j = vars_v%nnod(i)
            write(zdum1,form) zbotnew(vars_v%nodes(i)%nod(j,2))
            
            if (swcsv < 3) then ! ascii
               call addstr(csv_units, il1, "," // vars_v%unit(i))
               call addstr(csv_names, il2, "," // trim(vars_v%name(i)) // "[" // trim(adjustl(zdum1)) // "]")
            else if (swcsv == 3) then ! binary
               bin_names(pos) = trim(vars_v%name(i)) // "[" // trim(adjustl(zdum1)) // "]"
               pos = pos + 1
            end if
         end if
      end if
   end do
   
   if (swcsv < 3) then ! ascii
      write(iuncsv,'(A)') trim(csv_units)
      write(iuncsv,'(A)') trim(csv_names)
   else if (swcsv == 3) then ! binary
      write(iuncsv) bin_names
   end if
      
   end subroutine make_header

! ----------------------------------------------------------------------  
   subroutine make_userlist(InList)
! ----------------------------------------------------------------------
   implicit none
   
   ! global
   character(len=*), intent(inout) :: InList
   ! local
   integer                   :: i, j, k, ipos1, ipos2, il
   integer, parameter        :: ilw = 1000
   integer, dimension(ilw)   :: iwbeg, iwend
   character(len=2096)       :: InListShort, InListTmp
   character(len=1024)       :: str_insert
   character(len=256)        :: str_sqr, str_item
   logical                   :: bracket, first, present

   ! remove spaces from string
   call remove_spaces(Inlist)
   
   ! replace , inside [] by ;
   ipos2 = 1
1  continue
   ipos1 = index(trim(InList(ipos2:)), "[") + (ipos2-1)
   if (ipos1 > ipos2) then
      ipos2 = index(trim(InList(ipos1:)),"]") + (ipos1-1)
      if (ipos2 == 0) call swap_error ("make_userlist", "Unmatched []")
      do i = ipos1+1,ipos2-1
         if (InList(i:i) == ",") then
            ! currently: warning; in future this may become an error ...
            call swap_warning ('make_userlist', 'Preferred item-separator between [] is ; (not ,)')
            InList(i:i) = ";"
         end if
      end do
      go to 1
   end if
   call upperc(Inlist)

   ! some short names should be discarded in certain cases
   call remove_non_simulated_alias(InList)
   
   ! replace shortnames (alias) by all accompanying names
   first = .TRUE.
   InListShort = ""
   call words(trim(InList), ilw, ",", iwbeg, iwend, nlist)
   do i = 1, nlist
     
     str_item = Inlist(iwbeg(i):iwend(i))
     
     ! check for brackets
     bracket = .FALSE.
     ipos1 = index(str_item, "[")
     if (ipos1 > 0) then
       bracket = .TRUE.
       str_sqr = str_item(ipos1:len_trim(str_item))
       str_item = str_item(1:(ipos1 - 1))
     end if
     
     ! check all shortnames
     do j = 1, M_a
       
       ipos1 = index(trim(str_item), trim(shorts%alias(j)))
       if (ipos1 == 1 .AND. len_trim(str_item) == len_trim(shorts%alias(j))) then
         
         iwbeg(i) = 0
           
         ! replacement string
         str_insert = ""; il = len_trim(str_insert)
         do k = 1, shorts%n(j)
           call addstr(str_insert, il, shorts%names(j,k))
           if (bracket) call addstr(str_insert, il, str_sqr)
           if (k < shorts%n(j)) call addstr(str_insert, il, ",")
         end do
         
         ! add items to InlistShort
         if (first) then
           first = .FALSE.
           InListShort = trim(str_insert)
         else
           InListShort = trim(InListShort) // "," // trim(str_insert)
         end if
       
       end if
     end do
   end do

   ! remove non-simulated variables from alias-list
   if (len_trim(InListShort) > 0) call remove_non_simulated_items(InListShort)

   ! combine Inlist and InlistShort (if needed)
   if (.NOT. first) then
     first = .TRUE.
     InListTmp = ""
     do i = 1, nlist
       if (iwbeg(i) > 0) then
         str_item = Inlist(iwbeg(i):iwend(i))
         if (first) then
           first = .FALSE.
           InListTmp = trim(str_item)
         else
           InListTmp = trim(InListTmp) // "," // trim(str_item)
         end if
       end if
     end do
     InList = trim(InListTmp) // "," // trim(InListShort)
   end if
   
   ! call remove_non_simulated_items(InList)                       ! Note: this statement also removes user-defined output variables that are not simulated. do we want that?
   
   ! replace input in single string by list of individual items
   call words(trim(InList), ilw, ",", iwbeg, iwend, nlist)
   do i = 1, nlist
      userlist(i) = trim(adjustl(InList(iwbeg(i):iwend(i))))
      present = STRinARSTR(userlist(i), vars_s%name, M_s)
      if (.NOT. present) present = STRinARSTR(userlist(i), vars_v%name, M_v)
      if (.NOT. present) then
         message = "Item " // trim(userlist(i)) // " in userlist not known in vars%name. Adjust inlist_csv!"
         call swap_error ("csv_write", message)
      end if
   end do

   end subroutine make_userlist

! ----------------------------------------------------------------------  
   subroutine merge_items()
! ----------------------------------------------------------------------  
   implicit none
   
   ! global
   ! local
   integer                            :: i, j, k, m, ipos1, ipos2, ipos3, ifnd
   character(len=256)                 :: ctmp, hlp1, hlp2
   character(len=24)                  :: istr1, istr2
   integer,            parameter      :: ilw = 20
   integer,            dimension(ilw) :: iwbeg, iwend
   integer                            :: iwar
   real                               :: rv1, rv2

   ! remove double entries
1  continue
   do i = 1, nlist-1
      do j = i+1, nlist
         if (userlist(i) == userlist(j)) then
            do k = j, nlist-1
               userlist(k) = userlist(k+1)
            end do
            nlist = nlist - 1
            userlist(nlist+1) = ""
            go to 1
         end if
      end do
   end do
   
   ! remove entry with square brackets in case also entire depth range for parameter is given
2  continue
   do i = 1, nlist-1
      ipos1 = index(userlist(i), "[")
      if (ipos1 > 0) then
         do j = 1, nlist
            if (userlist(i)(1:ipos1-1) == userlist(j)(1:ipos1-1)) then
               if (len_trim(userlist(j)) == ipos1-1) then
                  do k = i, nlist - 1
                     userlist(k) = userlist(k+1)
                  end do
                  nlist = nlist - 1
                  userlist(nlist+1) = ""
                  go to 2
               end if
            end if
         end do
      end if
   end do

   ! merge within []
3  continue
   do i = 1, nlist-1
      ipos1 = index(userlist(i), "[")
      if (ipos1 > 0) then
         do j = i+1, nlist
            if (userlist(i)(1:ipos1) == userlist(j)(1:ipos1)) then
               ipos2 = index(userlist(i), "]")
               ipos3 = index(userlist(j), "]")
               userlist(i) = userlist(i)(1:ipos2-1) // ";" // userlist(j)(ipos1+1:ipos3)
               do k = j, nlist-1
                  userlist(k) = userlist(k+1)
               end do
               nlist = nlist - 1
               userlist(nlist+1) = ""
               go to 3
            end if
         end do
      end if
   end do
   
   ! replace depths by node numbers inside []
   do i = 1, nlist
      ipos1 = index(userlist(i), "[")
      if (ipos1 > 0) then
         ctmp = userlist(i)(1:ipos1)
         ipos2 = index(userlist(i), "]")
         hlp1 = userlist(i)(ipos1+1:ipos2-1)
         call words(trim(hlp1), ilw, ";", iwbeg, iwend, ifnd)
         do j = 1, ifnd
            hlp2 = hlp1(iwbeg(j):iwend(j))
            ipos3 = index(hlp2,":")
            if (ipos3 > 0) then
               call decrea (iwar, hlp2(1:ipos3-1), rv1)
               if (rv1 <= 0.0d0) rv1 = real(nodenumber(rv1, 1))                  
               write(istr1, '(I0)') nint(rv1)
               call decrea (iwar, hlp2(ipos3+1:), rv2)
               if (rv2 <= 0.0d0) rv2 = real(nodenumber(rv2, 2))
               write(istr2, '(I0)') nint(rv2)
               if (rv1 > rv2) then
                  ctmp = trim(ctmp) // trim(istr2) // ":" // trim(istr1) // ";"
               else
                  ctmp = trim(ctmp) // trim(istr1) // ":" // trim(istr2) // ";"
               end if
            else
               call decrea (iwar, hlp2, rv1)
               if (rv1 <= 0.0d0) rv1 = real(nodenumber(rv1, 1))
               write(istr1, '(I0)') nint(rv1)
               ctmp = trim(ctmp) // trim(istr1) // ";" 
            end if
         end do
         ctmp = trim(ctmp(1:len_trim(ctmp)-1)) // "]"
         userlist(i) = trim(ctmp)
      end if
   end do

   ! check doubles inside []
   do i = 1, nlist
      ipos1 = index(userlist(i), "[")
      if (ipos1 > 0) then
         ipos2 = index(userlist(i), "]")
         hlp1 = userlist(i)(ipos1+1:ipos2-1)
         call words(trim(hlp1), ilw, ";", iwbeg, iwend, ifnd)
4        continue
         do j = 1, ifnd-1
            do k = j+1, ifnd
               if (hlp1(iwbeg(j):iwend(j)) == hlp1(iwbeg(k):iwend(k))) then
                  do m = k, ifnd-1
                     iwbeg(m) = iwbeg(m+1)
                     iwend(m) = iwend(m+1)
                  end do
                  ifnd = ifnd - 1
                  goto 4
               end if
            end do
         end do
         ctmp = userlist(i)(1:ipos1)
         do k = 1, ifnd
            ctmp = trim(ctmp) // hlp1(iwbeg(k):iwend(k)) // ";"
         end do
         ctmp = trim(ctmp(1:len_trim(ctmp)-1)) // "]"
         userlist(i) = trim(ctmp)
      end if
   end do

   end subroutine merge_items

! ----------------------------------------------------------------------  
   subroutine remove_non_simulated_alias(InList)
! ----------------------------------------------------------------------  
   use MOD_swap_base, only: swsolu, swcrop, swmacro, swdra, swcropsnm
   implicit none
   
   ! global
   character(len=*), intent(inout) :: InList
   ! local
   
   if (swsolu == 0) then
      call remove_from_list(InList, "SOLBAL")
   end if
   if (swcrop == 0) then
      call remove_from_list(InList, "CROP")
      call remove_from_list(InList, "WOFOST")
      call remove_from_list(InList, "GRASS")
   end if
   if (swmacro == 0) then
      call remove_from_list(InList, "MACROPORE")
      call remove_from_list(InList, "MACROPORECP")
   end if
   if (swdra == 0) then
      call remove_from_list(InList, "DRAIN_ALL")
   end if
   if (swcropsnm == 0) then
      call remove_from_list(InList, "NUTRIENTS")
   end if

   end subroutine remove_non_simulated_alias
   
! ----------------------------------------------------------------------  
   subroutine remove_non_simulated_items(InListShort)
! ----------------------------------------------------------------------  
   use MOD_swap_base,   only: swcrop, swsolu, swsnow, swfrost, swdra, swrunon, swmacro, swhea
   use MOD_Solute,      only: swdc
   !use MOD_irrigation,  only: flirrigate
   use MOD_drain,       only: nrlevs
   use variables,       only: swbotb
   
   implicit none
   
   ! global
   character(len=*), intent(inout)  :: InListShort
   ! local
   integer           :: lev
   character(len=10) :: name

   if (swsnow == 0) then
      call remove_from_list(InListShort, "SNOW")
      call remove_from_list(InListShort, "ESUBLIM")
      call remove_from_list(InListShort, "SNOW_VOL")
   end if
   
   if (swhea == 0) then
      call remove_from_list(InListShort, "T")
   end if
   
   if (swcrop == 0) then
      call remove_from_list(InListShort, "EIC")
      call remove_from_list(InListShort, "IC_VOL")
      call remove_from_list(InListShort, "TPOT")
      call remove_from_list(InListShort, "TACT")
      call remove_from_list(InListShort, "TREDDRY")
      call remove_from_list(InListShort, "TREDWET")
      call remove_from_list(InListShort, "TREDSOL")
      call remove_from_list(InListShort, "TREDFRS")
      call remove_from_list(InListShort, "VCOVER")
      call remove_from_list(InListShort, "LAI")
      call remove_from_list(InListShort, "LAIPOT")
      call remove_from_list(InListShort, "RD")
      call remove_from_list(InListShort, "RDPOT")
      call remove_from_list(InListShort, "CF")
      call remove_from_list(InListShort, "CH")
      call remove_from_list(InListShort, "S_UPT")
      
      call remove_from_list(InListShort, "RWU")
      call remove_from_list(InListShort, "SR_RWU")
   end if
   
   if (swfrost == 0) then
      call remove_from_list(InListShort, "TREDFRS")
   end if

   if (swsolu == 0) then
      call remove_from_list(InListShort, "TREDSOL")
      call remove_from_list(InListShort, "S_DRN")
      call remove_from_list(InListShort, "S_STOT")
      call remove_from_list(InListShort, "S_DEC")
      call remove_from_list(InListShort, "S_DSTOR")
      call remove_from_list(InListShort, "S_IRRIG")
      call remove_from_list(InListShort, "S_RAIN")
      call remove_from_list(InListShort, "S_BOT")
      call remove_from_list(InListShort, "S_UPT")
      call remove_from_list(InListShort, "S_BALDEV")
   end if

   if (swdra == 0) then
      call remove_from_list(InListShort, "DRN")
      call remove_from_list(InListShort, "DRN_1")
      call remove_from_list(InListShort, "DRN_2")
      call remove_from_list(InListShort, "DRN_3")
      call remove_from_list(InListShort, "DRN_4")
      call remove_from_list(InListShort, "DRN_5")
      call remove_from_list(InListShort, "MP_DRN_1")

      call remove_from_list(InListShort, "SR_DRN")
      call remove_from_list(InListShort, "SR_DRN_IN")
      call remove_from_list(InListShort, "SR_DRN_OUT")
      call remove_from_list(InListShort, "S_DRN")
      
      call remove_from_list(InListShort, "QDRN_1")
      call remove_from_list(InListShort, "QDRN_2")
      call remove_from_list(InListShort, "QDRN_3")
      call remove_from_list(InListShort, "QDRN_4")
      call remove_from_list(InListShort, "QDRN_5")
      call remove_from_list(InListShort, "MPC_DRN_1")
   else if (nrlevs < 5) then
      do lev = nrlevs+1, 5
         write(name, '("DRN_",I1)') lev
         call remove_from_list(InListShort, name)
         write(name, '("QDRN_",I1)') lev
         call remove_from_list(InListShort, name)
      end do
   end if

   if (swrunon == 0) then
      call remove_from_list(InListShort, "RUNON")
   end if

   if (swbotb == 6) then
      call remove_from_list(InListShort, "BOT")
      call remove_from_list(InListShort, "S_BOT")
   end if

   if (swdc == 0) then
      call remove_from_list(InListShort, "S_DEC")
   end if
   
   ! Wrong check: irrigation can be activated by crop
   !if (.NOT. flirrigate) then
   !   call remove_from_list(InListShort, "IRRIG")
   !   call remove_from_list(InListShort, "SSDI")
   !   call remove_from_list(InListShort, "S_IRRIG")
   !   
   !   call remove_from_list(InListShort, "QSSDI")
   !   call remove_from_list(InListShort, "SR_SSDI")
   !end if
      
   if (swmacro == 0) then
      call remove_from_list(InListShort, "MP_WVOL_1")
      call remove_from_list(InListShort, "MP_WVOL_2")
      call remove_from_list(InListShort, "MP_TVOL_1")
      call remove_from_list(InListShort, "MP_TVOL_2")
      call remove_from_list(InListShort, "MP_EXF_1")
      call remove_from_list(InListShort, "MP_EXF_2")
      call remove_from_list(InListShort, "MP_INF_1")
      call remove_from_list(InListShort, "MP_INF_2")
      call remove_from_list(InListShort, "MP_TOP_1")
      call remove_from_list(InListShort, "MP_TOP_2")
      call remove_from_list(InListShort, "MP_TOPD_1")
      call remove_from_list(InListShort, "MP_TOPD_2")
      call remove_from_list(InListShort, "MP_TOPL_1")
      call remove_from_list(InListShort, "MP_TOPL_2")
      call remove_from_list(InListShort, "MP_DRN_1")
      call remove_from_list(InListShort, "MP_GWL_1")
      call remove_from_list(InListShort, "MP_BALDEV_1")
      call remove_from_list(InListShort, "MP_BALDEV_2")
      call remove_from_list(InListShort, "MP_VOLDYN")
      call remove_from_list(InListShort, "MP_SUBSID")
      
      call remove_from_list(InListShort, "MPC_Q_1")
      call remove_from_list(InListShort, "MPC_Q_2")
      call remove_from_list(InListShort, "MPC_QEXC_1")
      call remove_from_list(InListShort, "MPC_QEXC_2")
      call remove_from_list(InListShort, "MPC_QDRN_1")
      call remove_from_list(InListShort, "MPC_WVOL_1")
      call remove_from_list(InListShort, "MPC_WVOL_2")
      call remove_from_list(InListShort, "MPC_TVOL_1")
      call remove_from_list(InListShort, "MPC_TVOL_2")
      call remove_from_list(InListShort, "MPC_WET_1")
      call remove_from_list(InListShort, "MPC_WET_2")
      call remove_from_list(InListShort, "MPC_VOLDYN")
      call remove_from_list(InListShort, "MPC_SUBSID")
      call remove_from_list(InListShort, "MPC_VOLSTA_1")
      call remove_from_list(InListShort, "MPC_VOLSTA_2")
      call remove_from_list(InListShort, "MPC_DIPO")
      call remove_from_list(InListShort, "MPC_FRARMTRX")
   end if
   
   end subroutine remove_non_simulated_items
   
! ----------------------------------------------------------------------  
   subroutine remove_from_list(InList, name)
! ----------------------------------------------------------------------  
   implicit none
   
   ! global
   character(len=*), intent(inout) :: InList
   character(len=*), intent(in)    :: name
   ! local
   integer, parameter              :: ilw = 1000
   integer                         :: nlist, ipos1
   character(len=999)              :: NewList
   character(len=96)               :: tmp
   integer, dimension(ilw)         :: iwbeg, iwend
   logical, dimension(ilw)         :: remove
   logical                         :: first, found

   ! initialize
   remove(:) = .FALSE.
   found     = .FALSE.
   call words(trim(InList), ilw, ",", iwbeg, iwend, nlist)
   
   ! look for item(s) to be removed
   do i = 1, nlist
      tmp = InList(iwbeg(i):iwend(i))
      ipos1 = index(tmp, "[")
      if (ipos1 == 0) ipos1 = len_trim(tmp) + 1
      if (tmp(1:ipos1-1) == trim(name)) then
         remove(i) = .TRUE.
         found     = .TRUE.
      end if
   end do
   
   ! remove item(s)
   if (found) then
      first = .TRUE.
      do i = 1, nlist
         if (.NOT. remove(i)) then
            if (first) then
               first = .FALSE.
               NewList = InList(iwbeg(i):iwend(i))
            else
               NewList = trim(NewList)//","//InList(iwbeg(i):iwend(i))
            end if
         end if
      end do
      InList = trim(NewList)
   end if
   
   end subroutine remove_from_list
   
! ---------------------------------------------------------------------- 
   subroutine csv_out_init()
! ---------------------------------------------------------------------- 
   use MOD_swap_base,      only: iun_min, iun_max, pathwork, project, swmacro
   use variables,          only: outfil, tstart, tend, thetas, thetar
   use MOD_grid,           only: numlay, botcom
   use MOD_drain,          only: nrlevs
   use MOD_Mvg,            only: watcon, cofgen
   use MOD_texture_orgmat, only: bdens,orgmat
   
   implicit none
   
   ! global
   ! local
   integer                 :: bruny, eruny, brund, erund
   integer, dimension(6)   :: datea
   real(8)                 :: timjan1
   real(4)                 :: fsec
   
   integer                 :: lay, node, i, il
   integer, dimension(4)   :: varpos
   character(len=100)      :: line
   character(len=20)       :: form
   character(len=30)       :: myval
   
   ! function
   integer        :: getun
   
   iuncsv_init = getun(iun_min, iun_max)
   filcsv_init = trim(pathwork)//trim(outfil)//'_input.csv'
   open(unit=iuncsv_init, file=filcsv_init, status='replace', action='write')
   
   ! write universal SWAP header
   call writehead (iuncsv_init, 1, filcsv_init, 'specified output data of SWAP', project)
   
   ! determine and write single parameter simulation characteristics
   call dtdpar (tstart, datea, fsec)
   bruny    = datea(1)
   datea(2) = 1
   datea(3) = 1
   fsec     = 0.0
   call dtardp (datea, fsec, timjan1)
   brund = nint (tstart - timjan1 + 1.0d0)
   call dtdpar (tend, datea, fsec)
   eruny    = datea(1)
   datea(2) = 1
   datea(3) = 1
   fsec     = 0.0
   call dtardp (datea, fsec, timjan1)
   erund = nint (tend - timjan1 + 1.0d0)
   
   write(iuncsv_init,'(A)') '* Single parameter simulation characteristics'
   write(iuncsv_init,'(A)') '* (yyyy),(yyyy),(doy),(doy),(-),(-),(-),(-)'
   write(iuncsv_init,'(A)') 'BRUNY,ERUNY,BRUND,ERUND,NUMNOD,NUMLAY,NRLEVS,SWMACRO'
   write(iuncsv_init,'(*(g0,:,","))') bruny, eruny, brund-1, erund, numnodnew, numlay, nrlevs, swmacro
   
   ! determine and write static parameters per layer   
   write(iuncsv_init,'(A)') '* Static parameters per horizon'
   write(iuncsv_init,'(A)') '* (-),(-),(cm3/cm3),(cm3/cm3),(cm3/cm3),(cm3/cm3),(cm3/cm3),(cm/d),(mg/cm3),(g/g dry soil)'
   write(iuncsv_init,'(A)') 'ISOILLAY,BOTCOM,WCS,WC20,WC32,WC42,WCR,KSAT,BDENS,ORGMAT'
   
   do lay=1,numlay
     write (myval, '(G0)') lay
     line = trim(adjustl(myval)) // ','; il = len_trim(line)
     
     write (myval, '(G0)') botcomnew(lay)
     line = line(1:il) // trim(adjustl(myval)) // ','; il = len_trim(line)
     
     call what_form(2,   thetas(botcomnew(lay)), form)
     write (myval, form) thetas(botcomnew(lay))
     line = line(1:il) // trim(adjustl(myval)); il = len_trim(line)

     call what_form(2,   watcon(botcom(lay), -100.d0), form)
     write (myval, form) watcon(botcom(lay), -100.d0)
     line = line(1:il) // trim(adjustl(myval)); il = len_trim(line)
     
     call what_form(2,   watcon(botcom(lay), -1584.9d0), form)
     write (myval, form) watcon(botcom(lay),-1584.9d0)
     line = line(1:il) // trim(adjustl(myval)); il = len_trim(line)
     
     call what_form(2,   watcon(botcom(lay), -15849.0d0), form)
     write (myval, form) watcon(botcom(lay),-15849.0d0)
     line = line(1:il) // trim(adjustl(myval)); il = len_trim(line)
     
     call what_form(2,   thetar(botcom(lay)), form)
     write (myval, form) thetar(botcom(lay))
     line = line(1:il) // trim(adjustl(myval)); il = len_trim(line)
     
     call what_form(2,   cofgen(3,botcom(lay)), form)
     write (myval, form) cofgen(3,botcom(lay))
     line = line(1:il) // trim(adjustl(myval)); il = len_trim(line)
     
     call what_form(2,   bdens(lay), form)
     write (myval, form) bdens(lay)
     line = line(1:il) // trim(adjustl(myval)); il = len_trim(line)
     
     call what_form(2,   orgmat(lay), form)
     write (myval, form) orgmat(lay)
     line = line(1:il) // trim(adjustl(myval)); il = len_trim(line)
     
     write(iuncsv_init,'(A)') line(1:il-1)
   end do
   
   ! determine and write static parameters per node
   write(iuncsv_init,'(A)') '* Static parameters per node'
   if (swmacro == 0) then
     write(iuncsv_init,'(A)') '* (cm),(cm)'
     write(iuncsv_init,'(A)') 'DEPTH,DZ'
   else
     write(iuncsv_init,'(A)') '* (cm),(cm),(cm),(cm),(cm),(cm)'
     write(iuncsv_init,'(A)') 'DEPTH,DZ,MPC_VOLSTA_1,MPC_VOLSTA_2,MPC_DIPO,MPC_FRARMTRX'
   end if
   
   do i = 1, M_v !!! size(vars_v%name)
     if (vars_v%name(i) == 'MPC_VOLSTA_1') varpos(1) = i
     if (vars_v%name(i) == 'MPC_VOLSTA_2') varpos(2) = i
     if (vars_v%name(i) == 'MPC_DIPO')       varpos(3) = i
     if (vars_v%name(i) == 'MPC_FRARMTRX')   varpos(4) = i
   end do
   
   do node = 1, numnodnew
     write(myval,'(F8.2)') znew(node)
     line = trim(adjustl(myval)) // ',' ; il = len_trim(line)
     
     call what_form(2,   dznew(node), form)
     write (myval, form) dznew(node)
     line = line(1:il) // trim(adjustl(myval)); il = len_trim(line)
     
     if (swmacro == 1) then
       do i = 1, size(varpos)
         call what_form(2,   vars_v%value(varpos(i))%val(node), form)
         write (myval, form) vars_v%value(varpos(i))%val(node)
         line = line(1:il) // trim(adjustl(myval)); il = len_trim(line)
       end do
     end if
     
     write(iuncsv_init,'(A)') line(1:il-1)
   end do

   close(unit=iuncsv_init)

   end subroutine csv_out_init
   
! ----------------------------------------------------------------------  
   subroutine my_piksrt(n,arr,brr)
! ----------------------------------------------------------------------  
! adapted after Numerical Recipes routine piksr2 (inputs now 2 integer aarrays)
   implicit none
   
   ! global
   integer,               intent(in)    :: n
   integer, dimension(n), intent(inout) :: arr, brr
   ! local
   integer                              :: i, j, a, b
   
   do j = 2, n
      a = arr(j)
      b = brr(j)
      do i = j-1, 1, -1
         if (arr(i) <= a) goto 10
         arr(i+1) = arr(i)
         brr(i+1) = brr(i)
      end do
      i = 0
10    arr(i+1) = a
      brr(i+1) = b
   end do

   end subroutine my_piksrt
   
! ----------------------------------------------------------------------  
   function nodenumber(depth, iway) result(node)
! ----------------------------------------------------------------------  
   implicit none
   
   ! global
   real,    intent(in) :: depth
   integer, intent(in) :: iway
   integer             :: node
   ! local
   integer             :: i

   i = 1
   if (iway == 1) then
      do while (real(zbotnew(i)) > depth - 1.0d-5)
         i = i + 1
         if (i > numnodnew) then
            if (real(zbotnew(i-1)) > depth + 1.0d-5) call swap_error ("nodenumber", "Depth exceeds bottom node")
            exit
         end if
      end do
   else
      do while (real(zbotnew(i)) > depth + 1.0d-5)
         i = i + 1
         if (i > numnodnew) call swap_error ("nodenumber", "Depth exceeds bottom node")
      end do
   end if
   
   node = i
   
   end function nodenumber
   
! ----------------------------------------------------------------------  
   function STRinARSTR(string, arraystring, N) result(found)
! ----------------------------------------------------------------------  
   implicit none
   
   ! global
   integer,          intent(in)               :: N
   character(len=*), intent(in)               :: string
   character(len=*), dimension(N), intent(in) :: arraystring
   logical                                    :: found
   ! local
   integer                                    :: i, il, ip

   found = .FALSE.
   do i = 1, N
      il = len_trim(trim(string))
      ip = index(string, "[")
      if (ip > 0) il = ip-1
      if (trim(string(1:il)) == trim(arraystring(i))) then
         found = .TRUE.
         exit
      end if
   end do
   end function STRinARSTR

end module SWAP_csv_output

!! ---------------------------------------------------------------------- 
!module read_SWAP_csv ! Temporary test module
!! ---------------------------------------------------------------------- 
!   use MOD_arrays,         only: fillen
!   use variables,          only: flprintshort
!   implicit none
!
!   private
!
!   public process_data_swap, filcsv_init, filcsv_data, iuncsv_init,iuncsv_data
!
!   ! SWAP initial file
!   character(len=fillen),  save :: filcsv_init, filcsv_data
!   integer,                save :: iuncsv_init, iuncsv_data
!   integer,                save :: bruny_i, eruny_i, brund_i, erund_i, numnod_i, numlay_i, nrlevs_i, swmacro_i
!   
!   ! SWAP data file
!   integer,                save :: swap_ncols
!   integer, parameter           :: M_rd = 53   ! maximum number of possible variable groups, must match nr entries in swap_inp
!
!   type :: idx_array
!      integer, allocatable :: val(:)
!   end type idx_array
!   
!   type :: val_array
!      real(8), allocatable :: val(:)
!   end type val_array
!   
!   type :: swap_variables
!      character(len=24), dimension(M_rd)      :: name       ! variable group names (e.g., 'H', 'WC', 'TEMP')
!      character(len=24), dimension(M_rd)      :: unit       ! the unit obtained from SWAP
!      integer, dimension(M_rd)                :: required   ! 1 if required, 0 if optional
!      integer, dimension(M_rd)                :: vtype      ! 1=scalar, 2=NUMNOD, 3=NUMNOD+1
!      integer, dimension(M_rd)                :: present    ! 1 if found in file, 0 if missing
!      type(idx_array), dimension(M_rd)        :: idx        ! index in swap file
!      character(len=19)                       :: date       ! current timestep
!      type(val_array), dimension(M_rd)        :: values     ! values of variable for current timestep
!   end type swap_variables
!   
!   type(swap_variables),                 save :: swap_inp
!   
!   ! dummy
!   integer              :: i
!   character(len=100)   :: message
!
!   data (swap_inp%name(i), swap_inp%required(i), swap_inp%vtype(i), i = 1, M_rd) / &
!         'DATE',           1,1,& ! may be updated to DATETIME internally
!         'RAIN',           1,1,&
!         'EACT',           1,1,&
!         'EPD',            1,1,&
!         'EPOT',           1,1,&
!         'RUNOFF',         1,1,&
!         'GWL',            1,1,&
!         'POND',           1,1,&
!         'BALDEV',         1,1,&
!         'TAV',            1,1,&
!         'SNOW',           0,1,& ! swsnow == 1
!         'SUBLIM',         0,1,& ! swsnow == 1
!         'SSNOW',          0,1,& ! swsnow == 1
!         'IRRIG',          0,1,& ! fl_irrigate == 1
!         'SSDI',           0,1,& ! fl_irrigate == 1
!         'RUNON',          0,1,& ! swrunon == 1
!         'INTERC',         0,1,& ! swcrop == 1
!         'INTERC_VOL',     0,1,& ! swcrop == 1
!         'VCOVER',         0,1,& ! swcrop == 1
!         'LAI',            0,1,& ! swcrop == 1
!         'RD',             0,1,& ! swcrop == 1
!         'CRPFAC',         0,1,& ! swcrop == 1
!         'MPGWL_1',        0,1,& ! swcrop == 1
!         'MPTVOL_1',       0,1,& ! swmacro == 1
!         'MPWVOL_1',       0,1,& ! swmacro == 1
!         'MPTOPD_1',       0,1,& ! swmacro == 1
!         'MPTOPL_1',       0,1,& ! swmacro == 1
!         'MPTVOL_2',       0,1,& ! swmacro == 1
!         'MPWVOL_2',       0,1,& ! swmacro == 1
!         'MPTOPD_2',       0,1,& ! swmacro == 1
!         'MPTOPL_2',       0,1,& ! swmacro == 1
!         'H',              1,2,&
!         'WC',             1,2,&
!         'Q',              1,3,&
!         'TEMP',           0,2,& ! swhea == 1
!         'QSSDI',          0,2,& ! fl_irrigate == 1
!         'RWU',            0,2,& ! swcrop == 1
!         'QDRAIN_1',       0,2,& ! swdra == 1, 1:nrlevs
!         'QDRAIN_2',       0,2,& ! swdra == 1, 1:nrlevs
!         'QDRAIN_3',       0,2,& ! swdra == 1, 1:nrlevs
!         'QDRAIN_4',       0,2,& ! swdra == 1, 1:nrlevs
!         'QDRAIN_5',       0,2,& ! swdra == 1, 1:nrlevs
!         'MPCQEXC_1',      0,2,& ! swmacro == 1
!         'MPCQDRN_1',      0,2,& ! swmacro == 1
!         'MPCTVOL_1',      0,2,& ! swmacro == 1
!         'MPCWVOL_1',      0,2,& ! swmacro == 1
!         'MPCWET_1',       0,2,& ! swmacro == 1
!         'MPCQ_1',         0,3,& ! swmacro == 1
!         'MPCQEXC_2',      0,2,& ! swmacro == 1
!         'MPCTVOL_2',      0,2,& ! swmacro == 1
!         'MPCWVOL_2',      0,2,& ! swmacro == 1
!         'MPCWET_2',       0,2,& ! swmacro == 1
!         'MPCQ_2',         0,3 & ! swmacro == 1
!   /
!         
!   contains
!! ---------------------------------------------------------------------- 
!   subroutine process_data_swap(itask)
!! ---------------------------------------------------------------------- 
!      use MOD_swap_base, only: iun_min, iun_max, pathwork
!      use variables,     only: outfil
!      implicit none
!   
!      ! global
!      integer, intent(in) :: itask
!      ! local
!      integer             :: ios
!      ! function
!      integer             :: getun
!      
!      select case (itask)
!      ! initial
!      case(1)
!      iuncsv_init = getun (iun_min, iun_max)
!      filcsv_init = trim(pathwork)//trim(outfil)//'_input.csv'
!      
!      call read_swap_init()
!      
!      iuncsv_data = getun (iun_min, iun_max)
!      filcsv_data = trim(pathwork)//trim(outfil)//'_output.csv'
!      
!      !call read_swap_header()
!      !call writecsvtest(1)
!      
!      ! dynamic
!      case(2)  ! Read one timestep
!         !call read_swap_timestep()
!         !call writecsvtest(2)
!   
!      ! closure
!      case(3)  ! Close data file
!         ! Check if file unit is open
!         inquire(unit=iuncsv_data, opened=ios)
!         if (ios == 1) then
!            close(iuncsv_data)
!         else
!            write(message,'(A,I0,A)') "Data file unit ", iuncsv_data," already closed or not open."
!            call swap_error('process_data_swap', message)
!         end if
!         
!         !call writecsvtest(3)
!    
!      case default
!         write(message,'(A,I0,A)') "Unknown task ", itask, " in process_data_swap."
!         call swap_error('process_data_swap', message)
!      end select
!      
!   end subroutine process_data_swap
!
!! ---------------------------------------------------------------------- 
!   subroutine read_swap_init()
!! ---------------------------------------------------------------------- 
!      implicit none
!      ! global
!      ! local
!      integer              :: ios
!      character(len=1024)  :: line
!      
!
!      open(unit=iuncsv_init, file=filcsv_init, status='old', action='read', iostat=ios)
!      if (ios /= 0) then
!         message = "Cannot open swap_initial file: "//trim(filcsv_init)//"."
!         call swap_error ('read_swap_init',message)   
!      end if
!
!      ! Skip comment lines (start with *)
!      do
!         read(iuncsv_init,'(A)',iostat=ios) line
!         if (ios /= 0) then
!            message = "Unexpected EOF before data section in init file: "//trim(filcsv_init)//"."
!            call swap_error ('read_swap_init',message)   
!         end if
!         if (line(1:1) /= '*') exit
!      end do
!
!      ! Then read the actual numeric data line
!      read(iuncsv_init,*,iostat=ios) bruny_i, eruny_i, brund_i, erund_i, numnod_i, numlay_i, nrlevs_i, swmacro_i
!      if (ios /= 0) then
!         message = "Failed reading numeric data from init file: "//trim(filcsv_init)//"."
!         call swap_error ('read_swap_init',message)   
!      end if
!      
!      ! do do: Read other data (per horizon, per node)
!
!      close(iuncsv_init)
!   end subroutine read_swap_init
!   
!! ---------------------------------------------------------------------- 
!   subroutine read_swap_header()
!! ---------------------------------------------------------------------- 
!      implicit none
!      ! global
!      ! local
!      character(len=24), allocatable   :: vars(:), units(:)
!      character(len=200000)            :: line
!      character(len=200000)            :: line_unit,line_vars
!      integer                          :: ios, i
!
!      ! Open file and skip metadata lines until we find CSV units and header
!      open(unit=iuncsv_data, file=filcsv_data, status='old', action='read', iostat=ios)
!      if (ios /= 0) then
!         message = "Cannot open swap_output file: "//trim(filcsv_data)//"."
!         call swap_error ('read_swap_header',message)   
!      end if
!
!      do
!         read(iuncsv_data, '(A)',iostat=ios) line
!         if (ios /= 0) then
!            message = "Unexpected EOF reading header line in swap_output file: "//trim(filcsv_data)//"."
!            call swap_error ('read_swap_header',message)   
!         end if
!         if (line(1:1) == '*') then
!            if (index(line, '(') > 0 .AND. index(line, ')') > 0) then 
!               line_unit = adjustl(line(2:)) 
!               exit
!            end if
!         end if
!      end do
!      
!      read(iuncsv_data, '(A)',iostat=ios) line_vars
!      if (ios /= 0) then
!         message = "Missing variable name line after unit line in: "//trim(filcsv_data)//"."
!         call swap_error ('read_swap_header',message)   
!      end if 
!
!      ! Split header lines by commas
!      swap_ncols = count([(line_vars(i:i) == ',', i=1,len_trim(line_vars))]) + 1
!      allocate(vars(swap_ncols))
!      allocate(units(swap_ncols))
!      
!      call split_csv_line(trim(line_vars), vars)
!      call split_csv_line(trim(line_unit), units)
!      
!      call detect_swap_variables(vars,units)
!      
!      do i = 1, M_rd
!         if (swap_inp%present(i) == 1) then
!            if (allocated(swap_inp%values(i)%val)) deallocate(swap_inp%values(i)%val)
!            allocate(swap_inp%values(i)%val(size(swap_inp%idx(i)%val)))
!            swap_inp%values(i)%val = 0.0
!         end if
!      end do
!      
!   end subroutine read_swap_header
!
!
!! ---------------------------------------------------------------------- 
!   subroutine detect_swap_variables(vars,units)
!! ---------------------------------------------------------------------- 
!      implicit none
!      ! global
!      character(len=*), dimension(:), intent(in) :: vars
!      character(len=*), dimension(:), intent(in) :: units
!
!      ! local
!      integer              :: i
!      integer, allocatable :: temp_idx(:)
!      character(len=32)    :: pattern
!
!      do i = 1, M_rd
!         swap_inp%present(i) = 0
!         
!         ! Special case for first variable (DATE/DATETIME)
!         if (i == 1) then
!            if (trim(vars(1)) == 'DATETIME') then
!               swap_inp%name(1) = 'DATETIME'
!            else if (trim(vars(1)) == 'DATE') then
!               swap_inp%name(1) = 'DATE'
!            else
!               message = "Error: neither DATE or DATETIME found in file: "//trim(filcsv_data)//"."
!               call swap_error ('detect_swap_variables',message) 
!            end if
!         end if
!         
!         ! find columns matching pattern of variable i
!         pattern = trim(swap_inp%name(i))! // "["
!         call find_columns(vars, pattern, temp_idx)
!
!         ! if variable found in swap file, check length and determine which columns are relevant
!         if (size(temp_idx) > 0) then
!            swap_inp%present(i) = 1
!            call check_expected_length(i, size(temp_idx))
!            
!            if (allocated(swap_inp%idx(i)%val)) deallocate(swap_inp%idx(i)%val)
!            allocate(swap_inp%idx(i)%val(size(temp_idx)))
!            swap_inp%idx(i)%val = temp_idx
!            
!            swap_inp%unit(i) = adjustl(units(temp_idx(1)))
!         ! if variable not found in swap file, check if variable was required
!         else
!            if (swap_inp%required(i) == 1) then
!               message = "Error: required variable "//trim(swap_inp%name(i))//" not found in file: "//trim(filcsv_data)//"."
!               call swap_error ('detect_swap_variables',message) 
!            else ! to do: write this in a particular location? 
!               write(*,*) "Note: optional variable ", trim(swap_inp%name(i)), " not present."
!            end if
!         end if
!      end do
!   end subroutine detect_swap_variables
!
!! ---------------------------------------------------------------------- 
!   subroutine find_columns(vars, pattern, idx)
!! ---------------------------------------------------------------------- 
!   implicit none
!   character(len=*), dimension(:), intent(in) :: vars
!   character(len=*), intent(in)               :: pattern
!   integer, allocatable, intent(out)          :: idx(:)
!   integer :: i, len_pattern, n
!   integer, allocatable :: tmp(:)
!
!   len_pattern = len_trim(pattern)
!   allocate(tmp(size(vars)))   ! maximum possible size
!   n = 0
!
!   ! allocate maximum possible size (all vars)
!   do i = 1, size(vars)
!      if (len_trim(vars(i)) >= len_pattern) then
!         if (vars(i)(1:len_pattern) == pattern) then
!            if (len_trim(vars(i)) == len_pattern .OR. vars(i)(len_pattern+1:len_pattern+1) == '[') then
!               n = n + 1
!               tmp(n) = i
!            end if
!         end if
!      end if
!   end do
!
!   ! Resize to actual number of matches
!   if (n > 0) then
!      allocate(idx(n))
!      idx = tmp(1:n)
!   else
!      allocate(idx(0))
!   end if
!
!   deallocate(tmp)
!   
!end subroutine find_columns
!   
!! ---------------------------------------------------------------------- 
!   subroutine check_expected_length(i, found_len)
!! ---------------------------------------------------------------------- 
!      implicit none
!      ! global
!      integer, intent(in)                 :: i, found_len
!      ! local
!      integer :: expected
!
!      select case (swap_inp%vtype(i))
!      case (1)
!         expected = 1
!      case (2)
!         expected = numnod_i
!      case (3)
!         expected = numnod_i + 1
!      end select
!
!      if (found_len /= expected) then
!         write(message, '(A,I0,A,I0,A)') "Warning: variable ", trim(swap_inp%name(i)), &
!                        " expected: ", expected, " columns but found: ", found_len, "."
!         call swap_error ('detect_swap_variables',message) 
!      end if
!   end subroutine check_expected_length
!
!! ---------------------------------------------------------------------- 
!   subroutine read_swap_timestep()
!! ---------------------------------------------------------------------- 
!      implicit none
!      ! global
!      ! local
!      character(len=200000)               :: line
!      character(len=32), allocatable      :: fields(:)
!      integer                             :: ios, i, j, ncols_i
!
!      read(iuncsv_data, '(A)', iostat=ios) line
!      if (ios /= 0) then
!         if (ios < 0) then
!            message = "Unexpected end of file before all timesteps read: "//trim(filcsv_data)//"."
!            call swap_error('read_swap_timestep', message)
!         else
!            message = "Error reading timestep line in file "//trim(filcsv_data)//"."
!            call swap_error('read_swap_timestep', message)
!         end if
!      end if
!
!      ! Split line into fields
!      allocate(fields(swap_ncols))
!      call split_csv_line(trim(line), fields)
!
!      ! Set values
!      do i = 1, M_rd
!         if (swap_inp%present(i) == 1) then
!            ncols_i = size(swap_inp%idx(i)%val(:))
!            if (trim(swap_inp%name(i)) == 'DATE' .or. trim(swap_inp%name(i)) == 'DATETIME') then
!               swap_inp%values(i)%val(1) = 0.0d0 ! dummy, may want to have numeric time here.
!               swap_inp%date = trim(fields(swap_inp%idx(i)%val(1)))
!            else
!               do j = 1, ncols_i
!                  read(fields(swap_inp%idx(i)%val(j)), *, iostat=ios) swap_inp%values(i)%val(j)
!                  if (ios /= 0) swap_inp%values(i)%val(j) = -9999.0
!               end do
!            end if
!         end if
!      end do
!
!      deallocate(fields)
!      
!      end subroutine read_swap_timestep
!
!! ---------------------------------------------------------------------- 
!   subroutine split_csv_line(line, fields)
!! ---------------------------------------------------------------------- 
!      implicit none
!      ! global
!      character(len=*), intent(in)                 :: line
!      character(len=*), dimension(:), intent(out)  :: fields
!      ! local
!      integer :: i, start, idx
!      
!      fields = ''
!      
!      start = 1; idx = 1
!      do i = 1, len_trim(line)
!         if (line(i:i) == ',') then
!            fields(idx) = adjustl(line(start:i-1))
!            idx = idx + 1
!            start = i + 1
!         end if
!      end do
!      fields(idx) = adjustl(line(start:))
!      
!   end subroutine split_csv_line
!   
!! ---------------------------------------------------------------------- 
!   subroutine writecsvtest(itask)
!! ---------------------------------------------------------------------- 
!   use MOD_swap_base, only: iun_min, iun_max, pathwork
!   use variables,     only: outfil
!   use SWAP_csv_output, only: what_form
!   implicit none
!   
!   integer, intent(in)     :: itask
!   
!   integer,           save :: iuncsv_test
!   character(fillen), save :: filcsv_test
!   character(len=200000)   :: line
!   integer                 :: il, j
!   character(len=20)       :: form
!   character(len=30)       :: myval
!   
!   integer :: getun
!   
!   select case(itask)
!      
!   case(1)
!   iuncsv_test = getun (iun_min, iun_max)
!   filcsv_test = trim(pathwork)//trim(outfil)//'_output_test.csv'
!   open(unit=iuncsv_test, file=filcsv_test, status='unknown', action='write')
!   call makeheader_test(iuncsv_test,filcsv_test)
!   
!   case(2) 
!   ! line contains results in comma-separated format; il is its length
!   ! time is first value
!   line = ""; il = 0
!   !if (.NOT. flprintshort) then
!   !   if (present(dtprint)) then
!   !      call addstr(line, il, trim(dtprint)); call addstr(line, il, ",")
!   !   else
!   !      call addstr(line, il, trim(date)); call addstr(line, il, ",")
!   !   end if
!   !else
!   !   ! determine date-time
!   !   call dtdpst ('year-month-day hour:minute:seconds', t1900, datexti)
!   !   call addstr(line, il, trim(datexti)); call addstr(line, il, ",")
!   !end if
!
!   ! next: add all desired values
!   do j = 1, M_rd
!      if (swap_inp%present(j) == 1) then
!         do i = 1, size(swap_inp%idx(j)%val)
!         call what_form(2, swap_inp%values(j)%val(i), form)
!         write (myval, form) swap_inp%values(j)%val(i)
!            line = line(1:il) // trim(adjustl(myval)); il = len_trim(line)
!         end do
!      end if
!   end do
!
!   ! write result (skip last character which is a comma)
!   write(iuncsv_test,'(A)') line(1:il-1)
!   
!   case(3)
!   
!   close (unit=iuncsv_test)
!   
!   end select 
!   
!   end subroutine writecsvtest
!   
!! ---------------------------------------------------------------------- 
!   subroutine makeheader_test(iuncsv,filcsv)
!! ----------------------------------------------------------------------  
!   use MOD_swap_base, only: project
!   implicit none
!   ! global
!   integer, intent(in)           :: iuncsv
!   character(len=*), intent(in)  :: filcsv
!   ! local
!   character(len=200000)           :: header_units, header_names
!   integer                       :: il1, il2, j
!
!   ! write universal SWAP header
!   call writehead (iuncsv, 1, filcsv, 'specified output data of SWAP', project)
!
!   ! column header
!   
!   header_units = '* '
!   header_names = ''
!   
!   do j = 1, M_rd
!      if (swap_inp%present(j) == 1) then
!         do i = 1, size(swap_inp%idx(j)%val)
!            call addstr(header_units, il1, "," // swap_inp%unit(j))
!            call addstr(header_names, il2, "," // swap_inp%name(j))   
!         end do
!      end if
!   end do
!
!   write (iuncsv,'(A)') trim(header_units)
!   write (iuncsv,'(A)') trim(header_names) 
!
!   return
!   end subroutine makeheader_test
!
!   
! end module read_swap_csv