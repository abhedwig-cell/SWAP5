module mod_b1_10_legacy_trial_capsule
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_arrays, only: macp, madr
  use variables, only: dt, dtold, t, t1900, tcum, timjan1, tstart, tend, &
       daycum, daynr, imonth, iyear, ioutdat, ioutdatint, isteps, nprintcount, cntper, outper, date, &
       fldayend, fldaystart, fldecdt, fldtmin, fldtreduce, flbaloutput, flheader, floutput, &
       floutputshort, flrunend, flzerocumu, flzerointr, volini, pondini, ivolbeg, ipondbeg, issnowbeg, isicbeg, ithetabeg
  use MOD_integral_global, only: inqpotrot_day, inqredrot_day, iqrot_day, iqreddry_day, iqredsol_day, iptra_day, ialpwet_day, ialpdry_day
  use MOD_meteo, only: meteo_rec, rain_rec, i_metdetail, fl_update_meteo
  use MOD_irrigation, only: dayfix, nirri, irrigevent, isua, cirr, dt_irr_event, gird, nird, &
       qssdi, qssdisum, flirrigate
  use MOD_integral, only: inqrot, inq, inqssdi, inqpotrot, inqredrot, iqdo, iqup, &
       iqrot, iqssdi, iqredwet, iqreddry, iqredsol, iqredfrs, iintc, isintc, iepd, ipeva, iptra, ievap, &
       iruno, irunon, iqbot, iqbdo, iqbup, iqtdo, iqtup, igrai, inrai, igird, inird, &
       cgrai, cnrai, caintc, cqrot, cqbot, cqbotdo, cqbotup, cqssdi, cqtdo, cqtup, crunoff, crunon, &
       cevap, cepd, cpeva, cptra, cinund, cqprai, cgird, cnird, cqdra, cqdrain, cqdrainin, cqdrainout, &
       inqdra, inqdra_in, inqdra_out, iqdra, cgsnow, cmelt, csnrai, csubl, isnrai, igsnow, isubl
  implicit none
  private

  type, public :: b1_10_legacy_trial_capsule_t
    ! Numerical / retry state: worker-local snapshot only, never persistent column physics.
    real(real64) :: dt = 0.0_real64
    real(real64) :: dtold = 0.0_real64
    logical :: fldecdt = .false.
    logical :: fldtmin = .false.
    logical :: fldtreduce = .false.

    ! Legacy calendar projection and reporting progress.
    real(real64) :: t = 0.0_real64
    real(real64) :: t1900 = 0.0_real64
    real(real64) :: tcum = 0.0_real64
    real(real64) :: timjan1 = 0.0_real64
    real(real64) :: tstart = 0.0_real64
    real(real64) :: tend = 0.0_real64
    integer :: daycum = 0, daynr = 0, imonth = 0, iyear = 0
    integer :: ioutdat = 0, ioutdatint = 0, isteps = 0, nprintcount = 0, cntper = 0
    real(real64) :: outper = 0.0_real64
    character(len=11) :: date = ''
    logical :: fldayend = .false., fldaystart = .false., flrunend = .false.
    logical :: flbaloutput = .false., flheader = .false., floutput = .false., floutputshort = .false.
    logical :: flzerocumu = .false., flzerointr = .false.
    real(real64) :: volini = 0.0_real64, pondini = 0.0_real64
    real(real64) :: ivolbeg = 0.0_real64, ipondbeg = 0.0_real64, issnowbeg = 0.0_real64, isicbeg = 0.0_real64
    real(real64), allocatable :: ithetabeg(:)

    ! Forcing cursors. Forcing values themselves are not persisted here.
    integer :: meteo_rec = 0, rain_rec = 0, i_metdetail = 0
    logical :: fl_update_meteo = .false.

    ! Irrigation continuation + event workspace required to make trial replay deterministic.
    integer :: dayfix = 0, nirri = 0, irrigevent = 0, isua = 0
    real(real64) :: cirr = 0.0_real64, dt_irr_event = 0.0_real64
    real(real64) :: gird = 0.0_real64, nird = 0.0_real64, qssdisum = 0.0_real64
    logical :: flirrigate = .false.
    real(real64), allocatable :: qssdi(:)

    ! Day accumulators consumed by crop/root processes. Roll back for non-calendar trial boundaries.
    real(real64), allocatable :: inqpotrot_day(:), inqredrot_day(:)
    real(real64) :: iqrot_day = 0.0_real64, iqreddry_day = 0.0_real64, iqredsol_day = 0.0_real64
    real(real64) :: iptra_day = 0.0_real64, ialpwet_day = 0.0_real64, ialpdry_day = 0.0_real64

    ! Intermediate and cumulative water accounting. These are rollback data, not physical continuation state.
    real(real64), allocatable :: inqrot(:), inq(:), inqssdi(:), inqpotrot(:), inqredrot(:), iqdo(:), iqup(:)
    real(real64), allocatable :: cqdrain(:), cqdrainin(:), cqdrainout(:)
    real(real64), allocatable :: inqdra(:,:), inqdra_in(:,:), inqdra_out(:,:)
    real(real64) :: iqrot = 0.0_real64, iqssdi = 0.0_real64
    real(real64) :: iqredwet = 0.0_real64, iqreddry = 0.0_real64, iqredsol = 0.0_real64, iqredfrs = 0.0_real64
    real(real64) :: iintc = 0.0_real64, isintc = 0.0_real64, iepd = 0.0_real64
    real(real64) :: ipeva = 0.0_real64, iptra = 0.0_real64, ievap = 0.0_real64
    real(real64) :: iruno = 0.0_real64, irunon = 0.0_real64, iqbot = 0.0_real64
    real(real64) :: iqbdo = 0.0_real64, iqbup = 0.0_real64, iqtdo = 0.0_real64, iqtup = 0.0_real64
    real(real64) :: igrai = 0.0_real64, inrai = 0.0_real64, igird = 0.0_real64, inird = 0.0_real64
    real(real64) :: cgrai = 0.0_real64, cnrai = 0.0_real64, caintc = 0.0_real64, cqrot = 0.0_real64
    real(real64) :: cqbot = 0.0_real64, cqbotdo = 0.0_real64, cqbotup = 0.0_real64, cqssdi = 0.0_real64
    real(real64) :: cqtdo = 0.0_real64, cqtup = 0.0_real64, crunoff = 0.0_real64, crunon = 0.0_real64
    real(real64) :: cevap = 0.0_real64, cepd = 0.0_real64, cpeva = 0.0_real64, cptra = 0.0_real64
    real(real64) :: cinund = 0.0_real64, cqprai = 0.0_real64, cgird = 0.0_real64, cnird = 0.0_real64
    real(real64) :: cqdra = 0.0_real64, iqdra = 0.0_real64
    real(real64) :: cgsnow = 0.0_real64, cmelt = 0.0_real64, csnrai = 0.0_real64, csubl = 0.0_real64
    real(real64) :: isnrai = 0.0_real64, igsnow = 0.0_real64, isubl = 0.0_real64
  end type b1_10_legacy_trial_capsule_t

  public :: capture_b1_10_legacy_trial_capsule, restore_b1_10_legacy_trial_capsule

contains

  subroutine capture_b1_10_legacy_trial_capsule(c)
    type(b1_10_legacy_trial_capsule_t), intent(inout) :: c
    c%dt=dt; c%dtold=dtold; c%fldecdt=fldecdt; c%fldtmin=fldtmin; c%fldtreduce=fldtreduce
    c%t=t; c%t1900=t1900; c%tcum=tcum; c%timjan1=timjan1; c%tstart=tstart; c%tend=tend
    c%daycum=daycum; c%daynr=daynr; c%imonth=imonth; c%iyear=iyear
    c%ioutdat=ioutdat; c%ioutdatint=ioutdatint; c%isteps=isteps; c%nprintcount=nprintcount; c%cntper=cntper
    c%outper=outper; c%date=date
    c%fldayend=fldayend; c%fldaystart=fldaystart; c%flrunend=flrunend
    c%flbaloutput=flbaloutput; c%flheader=flheader; c%floutput=floutput; c%floutputshort=floutputshort
    c%flzerocumu=flzerocumu; c%flzerointr=flzerointr
    c%volini=volini; c%pondini=pondini; c%ivolbeg=ivolbeg; c%ipondbeg=ipondbeg; c%issnowbeg=issnowbeg; c%isicbeg=isicbeg
    c%ithetabeg=ithetabeg
    c%inqpotrot_day=inqpotrot_day; c%inqredrot_day=inqredrot_day; c%iqrot_day=iqrot_day; c%iqreddry_day=iqreddry_day
    c%iqredsol_day=iqredsol_day; c%iptra_day=iptra_day; c%ialpwet_day=ialpwet_day; c%ialpdry_day=ialpdry_day
    c%meteo_rec=meteo_rec; c%rain_rec=rain_rec; c%i_metdetail=i_metdetail; c%fl_update_meteo=fl_update_meteo
    c%dayfix=dayfix; c%nirri=nirri; c%irrigevent=irrigevent; c%isua=isua; c%cirr=cirr
    c%dt_irr_event=dt_irr_event; c%gird=gird; c%nird=nird; c%qssdisum=qssdisum; c%flirrigate=flirrigate
    c%qssdi = qssdi
    c%inqrot=inqrot; c%inq=inq; c%inqssdi=inqssdi; c%inqpotrot=inqpotrot; c%inqredrot=inqredrot
    c%iqdo=iqdo; c%iqup=iqup
    c%iqrot=iqrot; c%iqssdi=iqssdi; c%iqredwet=iqredwet; c%iqreddry=iqreddry; c%iqredsol=iqredsol; c%iqredfrs=iqredfrs
    c%iintc=iintc; c%isintc=isintc; c%iepd=iepd; c%ipeva=ipeva; c%iptra=iptra; c%ievap=ievap
    c%iruno=iruno; c%irunon=irunon; c%iqbot=iqbot; c%iqbdo=iqbdo; c%iqbup=iqbup; c%iqtdo=iqtdo; c%iqtup=iqtup
    c%igrai=igrai; c%inrai=inrai; c%igird=igird; c%inird=inird
    c%cgrai=cgrai; c%cnrai=cnrai; c%caintc=caintc; c%cqrot=cqrot; c%cqbot=cqbot; c%cqbotdo=cqbotdo; c%cqbotup=cqbotup
    c%cqssdi=cqssdi; c%cqtdo=cqtdo; c%cqtup=cqtup; c%crunoff=crunoff; c%crunon=crunon
    c%cevap=cevap; c%cepd=cepd; c%cpeva=cpeva; c%cptra=cptra; c%cinund=cinund; c%cqprai=cqprai; c%cgird=cgird; c%cnird=cnird
    c%cqdra=cqdra; c%cqdrain=cqdrain; c%cqdrainin=cqdrainin; c%cqdrainout=cqdrainout
    c%inqdra=inqdra; c%inqdra_in=inqdra_in; c%inqdra_out=inqdra_out; c%iqdra=iqdra
    c%cgsnow=cgsnow; c%cmelt=cmelt; c%csnrai=csnrai; c%csubl=csubl; c%isnrai=isnrai; c%igsnow=igsnow; c%isubl=isubl
  end subroutine capture_b1_10_legacy_trial_capsule

  subroutine restore_b1_10_legacy_trial_capsule(c)
    type(b1_10_legacy_trial_capsule_t), intent(in) :: c
    if (.not. allocated(c%qssdi) .or. .not. allocated(c%inqrot) .or. .not. allocated(c%inq) .or. &
        .not. allocated(c%cqdrain) .or. .not. allocated(c%inqdra) .or. .not. allocated(c%ithetabeg) .or. &
        .not. allocated(c%inqpotrot_day) .or. .not. allocated(c%inqredrot_day)) then
      error stop 'B1.10 legacy trial capsule: incomplete snapshot'
    end if
    if (size(c%qssdi) /= macp .or. size(c%inqrot) /= macp .or. size(c%inq) /= macp+1 .or. &
        size(c%cqdrain) /= madr .or. size(c%inqdra,1) /= madr .or. size(c%inqdra,2) /= macp .or. &
        size(c%ithetabeg) /= macp .or. size(c%inqpotrot_day) /= macp .or. size(c%inqredrot_day) /= macp) then
      error stop 'B1.10 legacy trial capsule: shape mismatch'
    end if
    dt=c%dt; dtold=c%dtold; fldecdt=c%fldecdt; fldtmin=c%fldtmin; fldtreduce=c%fldtreduce
    t=c%t; t1900=c%t1900; tcum=c%tcum; timjan1=c%timjan1; tstart=c%tstart; tend=c%tend
    daycum=c%daycum; daynr=c%daynr; imonth=c%imonth; iyear=c%iyear
    ioutdat=c%ioutdat; ioutdatint=c%ioutdatint; isteps=c%isteps; nprintcount=c%nprintcount; cntper=c%cntper
    outper=c%outper; date=c%date
    fldayend=c%fldayend; fldaystart=c%fldaystart; flrunend=c%flrunend
    flbaloutput=c%flbaloutput; flheader=c%flheader; floutput=c%floutput; floutputshort=c%floutputshort
    flzerocumu=c%flzerocumu; flzerointr=c%flzerointr
    volini=c%volini; pondini=c%pondini; ivolbeg=c%ivolbeg; ipondbeg=c%ipondbeg; issnowbeg=c%issnowbeg; isicbeg=c%isicbeg
    ithetabeg=c%ithetabeg
    inqpotrot_day=c%inqpotrot_day; inqredrot_day=c%inqredrot_day; iqrot_day=c%iqrot_day; iqreddry_day=c%iqreddry_day
    iqredsol_day=c%iqredsol_day; iptra_day=c%iptra_day; ialpwet_day=c%ialpwet_day; ialpdry_day=c%ialpdry_day
    meteo_rec=c%meteo_rec; rain_rec=c%rain_rec; i_metdetail=c%i_metdetail; fl_update_meteo=c%fl_update_meteo
    dayfix=c%dayfix; nirri=c%nirri; irrigevent=c%irrigevent; isua=c%isua; cirr=c%cirr
    dt_irr_event=c%dt_irr_event; gird=c%gird; nird=c%nird; qssdisum=c%qssdisum; flirrigate=c%flirrigate
    qssdi=c%qssdi
    inqrot=c%inqrot; inq=c%inq; inqssdi=c%inqssdi; inqpotrot=c%inqpotrot; inqredrot=c%inqredrot; iqdo=c%iqdo; iqup=c%iqup
    iqrot=c%iqrot; iqssdi=c%iqssdi; iqredwet=c%iqredwet; iqreddry=c%iqreddry; iqredsol=c%iqredsol; iqredfrs=c%iqredfrs
    iintc=c%iintc; isintc=c%isintc; iepd=c%iepd; ipeva=c%ipeva; iptra=c%iptra; ievap=c%ievap
    iruno=c%iruno; irunon=c%irunon; iqbot=c%iqbot; iqbdo=c%iqbdo; iqbup=c%iqbup; iqtdo=c%iqtdo; iqtup=c%iqtup
    igrai=c%igrai; inrai=c%inrai; igird=c%igird; inird=c%inird
    cgrai=c%cgrai; cnrai=c%cnrai; caintc=c%caintc; cqrot=c%cqrot; cqbot=c%cqbot; cqbotdo=c%cqbotdo; cqbotup=c%cqbotup
    cqssdi=c%cqssdi; cqtdo=c%cqtdo; cqtup=c%cqtup; crunoff=c%crunoff; crunon=c%crunon
    cevap=c%cevap; cepd=c%cepd; cpeva=c%cpeva; cptra=c%cptra; cinund=c%cinund; cqprai=c%cqprai; cgird=c%cgird; cnird=c%cnird
    cqdra=c%cqdra; cqdrain=c%cqdrain; cqdrainin=c%cqdrainin; cqdrainout=c%cqdrainout
    inqdra=c%inqdra; inqdra_in=c%inqdra_in; inqdra_out=c%inqdra_out; iqdra=c%iqdra
    cgsnow=c%cgsnow; cmelt=c%cmelt; csnrai=c%csnrai; csubl=c%csubl; isnrai=c%isnrai; igsnow=c%igsnow; isubl=c%isubl
  end subroutine restore_b1_10_legacy_trial_capsule

end module mod_b1_10_legacy_trial_capsule
