program test_fci07_legacy_trial_capsule
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_arrays, only: macp, madr
  use variables, only: dt, dtold, t, t1900, tcum, daycum, daynr, iyear, date, &
       fldaystart, fldayend, fldecdt, fldtmin, fldtreduce, floutput, flzerointr
  use MOD_meteo, only: meteo_rec, rain_rec, i_metdetail, fl_update_meteo
  use MOD_irrigation, only: dayfix, nirri, irrigevent, isua, cirr, dt_irr_event, gird, nird, qssdi, qssdisum, flirrigate
  use MOD_integral, only: inqrot, inq, inqdra, iqrot, igrai, cgrai, cqbotdo, crunoff, cevap, cqdra, cqdrain, cgsnow
  use mod_b1_10_legacy_trial_capsule, only: b1_10_legacy_trial_capsule_t, &
       capture_b1_10_legacy_trial_capsule, restore_b1_10_legacy_trial_capsule
  implicit none
  type(b1_10_legacy_trial_capsule_t) :: c
  integer :: i

  dt=0.125_real64; dtold=0.25_real64; t=3.5_real64; t1900=40000.5_real64; tcum=9.25_real64
  daycum=17; daynr=123; iyear=2003; date='2003-05-03'
  fldaystart=.true.; fldayend=.false.; fldecdt=.true.; fldtmin=.false.; fldtreduce=.true.; floutput=.true.; flzerointr=.true.
  meteo_rec=31; rain_rec=7; i_metdetail=4; fl_update_meteo=.true.
  dayfix=6; nirri=2; irrigevent=1; isua=1; cirr=0.44_real64; dt_irr_event=0.2_real64
  gird=0.7_real64; nird=0.6_real64; qssdisum=0.3_real64; flirrigate=.true.
  do i=1,macp; qssdi(i)=real(i,real64)*1.0e-5_real64; inqrot(i)=real(i,real64)*2.0e-5_real64; end do
  do i=1,macp+1; inq(i)=real(i,real64)*3.0e-5_real64; end do
  inqdra=0.004_real64; iqrot=0.8_real64; igrai=0.9_real64
  cgrai=1.1_real64; cqbotdo=1.2_real64; crunoff=1.3_real64; cevap=1.4_real64; cqdra=1.5_real64
  cqdrain=0.12_real64; cgsnow=0.17_real64

  call capture_b1_10_legacy_trial_capsule(c)

  dt=-9; dtold=-9; t=-9; t1900=-9; tcum=-9; daycum=-9; daynr=-9; iyear=-9; date='POISONED   '
  fldaystart=.false.; fldayend=.true.; fldecdt=.false.; fldtmin=.true.; fldtreduce=.false.; floutput=.false.; flzerointr=.false.
  meteo_rec=-9; rain_rec=-9; i_metdetail=-9; fl_update_meteo=.false.
  dayfix=-9; nirri=-9; irrigevent=-9; isua=-9; cirr=-9; dt_irr_event=-9; gird=-9; nird=-9; qssdisum=-9; flirrigate=.false.
  qssdi=-9; inqrot=-9; inq=-9; inqdra=-9; iqrot=-9; igrai=-9
  cgrai=-9; cqbotdo=-9; crunoff=-9; cevap=-9; cqdra=-9; cqdrain=-9; cgsnow=-9

  call restore_b1_10_legacy_trial_capsule(c)

  call assert_close(dt,0.125_real64,'dt'); call assert_close(dtold,0.25_real64,'dtold')
  call assert_close(t1900,40000.5_real64,'t1900'); call assert_close(tcum,9.25_real64,'tcum')
  if (daycum/=17 .or. daynr/=123 .or. iyear/=2003 .or. date/='2003-05-03') error stop 'time projection restore'
  if (.not.fldaystart .or. fldayend .or. .not.fldecdt .or. fldtmin .or. .not.fldtreduce) error stop 'control flags restore'
  if (.not.floutput .or. .not.flzerointr) error stop 'reporting flags restore'
  if (meteo_rec/=31 .or. rain_rec/=7 .or. i_metdetail/=4 .or. .not.fl_update_meteo) error stop 'forcing cursor restore'
  if (dayfix/=6 .or. nirri/=2 .or. irrigevent/=1 .or. isua/=1 .or. .not.flirrigate) error stop 'irrigation cursor restore'
  call assert_close(cirr,0.44_real64,'cirr'); call assert_close(dt_irr_event,0.2_real64,'dt_irr_event')
  call assert_close(qssdi(macp),real(macp,real64)*1.0e-5_real64,'qssdi')
  call assert_close(inqrot(macp),real(macp,real64)*2.0e-5_real64,'inqrot')
  call assert_close(inq(macp+1),real(macp+1,real64)*3.0e-5_real64,'inq')
  call assert_close(inqdra(madr,macp),0.004_real64,'inqdra')
  call assert_close(cgrai,1.1_real64,'cgrai'); call assert_close(cqbotdo,1.2_real64,'cqbotdo')
  call assert_close(crunoff,1.3_real64,'crunoff'); call assert_close(cevap,1.4_real64,'cevap')
  call assert_close(cqdra,1.5_real64,'cqdra'); call assert_close(cqdrain(madr),0.12_real64,'cqdrain')
  call assert_close(cgsnow,0.17_real64,'cgsnow')

  print *, 'FCI07_LEGACY_TRIAL_CAPSULE PASS'
contains
  subroutine assert_close(a,b,label)
    real(real64), intent(in) :: a,b
    character(len=*), intent(in) :: label
    if (abs(a-b)>1.0e-12_real64) then
      print *, trim(label), a, b
      error stop 'assert_close'
    end if
  end subroutine assert_close
end program test_fci07_legacy_trial_capsule
