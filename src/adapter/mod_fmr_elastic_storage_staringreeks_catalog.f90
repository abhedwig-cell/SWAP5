module mod_fmr_elastic_storage_staringreeks_catalog
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_elastic_storage_horizon_descriptor_builder, only: fmr_elastic_storage_retention_t
  implicit none
  private

  integer, parameter, public :: FMR_STARINGREEKS_CATALOG_OK = 0
  integer, parameter, public :: FMR_STARINGREEKS_CATALOG_NOT_FOUND = 1
  integer, parameter, public :: FMR_STARINGREEKS_CATALOG_YEAR = 2018
  integer, parameter, public :: FMR_STARINGREEKS_CATALOG_COUNT = 36
  character(len=*), parameter, public :: FMR_STARINGREEKS_SOURCE_SHA256 = &
       'ed2e47bcacdbb6e5fe18eb4f712c3ead996f26f97d647fa550dafd8683d64494'

  character(len=3), parameter :: CODES(FMR_STARINGREEKS_CATALOG_COUNT) = [ character(len=3) :: &
       'B01','B02','B03','B04','B05','B06','B07','B08','B09','B10','B11','B12', &
       'B13','B14','B15','B16','B17','B18','O01','O02','O03','O04','O05','O06', &
       'O07','O08','O09','O10','O11','O12','O13','O14','O15','O16','O17','O18' ]

  real(real64), parameter :: WCR(FMR_STARINGREEKS_CATALOG_COUNT) = [ &
       0.02000000_real64,0.02000000_real64,0.02000000_real64,0.02000000_real64, &
       0.01000000_real64,0.01000000_real64,0.00000000_real64,0.01000000_real64, &
       0.00000000_real64,0.01000000_real64,0.01000000_real64,0.01000000_real64, &
       0.01000000_real64,0.01000000_real64,0.01000000_real64,0.01000000_real64, &
       0.00000000_real64,0.00000000_real64,0.01000000_real64,0.02000000_real64, &
       0.01000000_real64,0.01000000_real64,0.01000000_real64,0.01000000_real64, &
       0.01000000_real64,0.00000000_real64,0.00000000_real64,0.01000000_real64, &
       0.00000000_real64,0.01000000_real64,0.01000000_real64,0.01000000_real64, &
       0.01000000_real64,0.00000000_real64,0.01000000_real64,0.01000000_real64 ]

  real(real64), parameter :: WCS(FMR_STARINGREEKS_CATALOG_COUNT) = [ &
       0.42749391_real64,0.43387803_real64,0.44279037_real64,0.46192638_real64, &
       0.38088059_real64,0.38481561_real64,0.40058182_real64,0.43265125_real64, &
       0.42953862_real64,0.44811194_real64,0.59128611_real64,0.52974855_real64, &
       0.41608364_real64,0.41677442_real64,0.52845807_real64,0.78606073_real64, &
       0.71862598_real64,0.76545233_real64,0.36584689_real64,0.38706390_real64, &
       0.33981025_real64,0.36407401_real64,0.33670050_real64,0.33343415_real64, &
       0.51312621_real64,0.45375142_real64,0.45824566_real64,0.47234331_real64, &
       0.44361666_real64,0.56070265_real64,0.57326800_real64,0.39387829_real64, &
       0.41005808_real64,0.88924579_real64,0.84863548_real64,0.58027825_real64 ]

  real(real64), parameter :: ALPHA(FMR_STARINGREEKS_CATALOG_COUNT) = [ &
       0.02165898_real64,0.02164487_real64,0.01499250_real64,0.01488005_real64, &
       0.04280723_real64,0.02092272_real64,0.01834939_real64,0.01047815_real64, &
       0.00696387_real64,0.01283449_real64,0.02162021_real64,0.01656167_real64, &
       0.00836212_real64,0.00541049_real64,0.02373064_real64,0.02107196_real64, &
       0.01906191_real64,0.02046830_real64,0.01598691_real64,0.01608317_real64, &
       0.01724264_real64,0.01364178_real64,0.03030449_real64,0.01595936_real64, &
       0.01198516_real64,0.01132406_real64,0.00971504_real64,0.01004814_real64, &
       0.01431555_real64,0.00881287_real64,0.02785405_real64,0.00328777_real64, &
       0.00775624_real64,0.00971073_real64,0.01192909_real64,0.01265676_real64 ]

  real(real64), parameter :: NPAR(FMR_STARINGREEKS_CATALOG_COUNT) = [ &
       1.73473668_real64,1.34877009_real64,1.50488028_real64,1.39684954_real64, &
       1.80780022_real64,1.24225002_real64,1.24827945_real64,1.27799235_real64, &
       1.26717854_real64,1.13525008_real64,1.10669523_real64,1.09067067_real64, &
       1.43702415_real64,1.30152771_real64,1.28234728_real64,1.27879843_real64, &
       1.13665830_real64,1.15070881_real64,2.16275113_real64,1.52441823_real64, &
       1.70339467_real64,1.48843957_real64,2.88750186_real64,1.28870487_real64, &
       1.15301795_real64,1.34596812_real64,1.37578384_real64,1.24569139_real64, &
       1.12600054_real64,1.15812806_real64,1.07995207_real64,1.61657253_real64, &
       1.28734271_real64,1.36357644_real64,1.27153561_real64,1.31617171_real64 ]

  public :: fmr_lookup_staringreeks_retention
  public :: fmr_staringreeks_code_at

contains

  subroutine fmr_lookup_staringreeks_retention(code, retention, catalog_index, status)
    character(len=*), intent(in) :: code
    type(fmr_elastic_storage_retention_t), intent(out) :: retention
    integer, intent(out) :: catalog_index
    integer, intent(out) :: status

    integer :: i

    retention = fmr_elastic_storage_retention_t()
    catalog_index = 0
    status = FMR_STARINGREEKS_CATALOG_NOT_FOUND

    if (len_trim(code) /= 3) return

    do i = 1, FMR_STARINGREEKS_CATALOG_COUNT
      if (trim(code) == CODES(i)) then
        retention%wcr = WCR(i)
        retention%wcs = WCS(i)
        retention%alpha_cm_inv = ALPHA(i)
        retention%npar = NPAR(i)
        catalog_index = i
        status = FMR_STARINGREEKS_CATALOG_OK
        return
      end if
    end do
  end subroutine fmr_lookup_staringreeks_retention

  subroutine fmr_staringreeks_code_at(catalog_index, code, status)
    integer, intent(in) :: catalog_index
    character(len=3), intent(out) :: code
    integer, intent(out) :: status

    code = '   '
    status = FMR_STARINGREEKS_CATALOG_NOT_FOUND
    if (catalog_index < 1 .or. catalog_index > FMR_STARINGREEKS_CATALOG_COUNT) return
    code = CODES(catalog_index)
    status = FMR_STARINGREEKS_CATALOG_OK
  end subroutine fmr_staringreeks_code_at

end module mod_fmr_elastic_storage_staringreeks_catalog
