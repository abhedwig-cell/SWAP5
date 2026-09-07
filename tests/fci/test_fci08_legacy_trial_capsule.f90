program test_fci08_legacy_trial_capsule
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_arrays, only: macp, madr
  use variables, only: dt,t1900,fldecdt
  use MOD_meteo, only: meteo_rec
  use MOD_SoilTemperature, only: ipos_qtop,ipos_tetop,ipos_tebot
  use MOD_Solute, only: imdectot,imsqprec,imqsol,sbaldev,samini,isqtop
  use MOD_irrigation, only: schedule,dayfix,nirri,qssdi
  use MOD_integral, only: inqrot,inq,inqdra,cgrai,cqdrain
  use mod_b1_10_legacy_trial_capsule, only: b1_10_legacy_trial_capsule_t, &
       capture_b1_10_legacy_trial_capsule, restore_b1_10_legacy_trial_capsule
  implicit none
  type(b1_10_legacy_trial_capsule_t) :: c
  integer :: i

  dt=0.125_real64; t1900=40000.5_real64; fldecdt=.true.; meteo_rec=31
  ipos_qtop=11; ipos_tetop=12; ipos_tebot=13
  schedule=1; dayfix=6; nirri=2
  do i=1,macp
    qssdi(i)=real(i,real64)*1.e-5_real64
    inqrot(i)=real(i,real64)*2.e-5_real64
  end do
  do i=1,macp+1
    inq(i)=real(i,real64)*3.e-5_real64
    imqsol(i)=real(i,real64)*4.e-5_real64
  end do
  inqdra=0.004_real64; cgrai=1.1_real64; cqdrain=0.12_real64
  imdectot=1.0_real64; imsqprec=6.0_real64; sbaldev=7.0_real64; samini=17.0_real64; isqtop=18.0_real64

  call capture_b1_10_legacy_trial_capsule(c)

  dt=-9; t1900=-9; fldecdt=.false.; meteo_rec=-9
  ipos_qtop=-9; ipos_tetop=-9; ipos_tebot=-9; schedule=-9; dayfix=-9; nirri=-9
  qssdi=-9; inqrot=-9; inq=-9; inqdra=-9; cgrai=-9; cqdrain=-9
  imdectot=-9; imsqprec=-9; imqsol=-9; sbaldev=-9; samini=-9; isqtop=-9

  call restore_b1_10_legacy_trial_capsule(c)

  call chk(dt,0.125_real64,'dt'); call chk(t1900,40000.5_real64,'t1900')
  if(.not.fldecdt .or. meteo_rec/=31) error stop 'legacy rollback control/forcing'
  if(ipos_qtop/=11 .or. ipos_tetop/=12 .or. ipos_tebot/=13) error stop 'thermal forcing cursor rollback'
  if(schedule/=1 .or. dayfix/=6 .or. nirri/=2) error stop 'irrigation config/process rollback copy'
  call chk(qssdi(macp),real(macp,real64)*1.e-5_real64,'qssdi')
  call chk(inqrot(macp),real(macp,real64)*2.e-5_real64,'inqrot')
  call chk(inq(macp+1),real(macp+1,real64)*3.e-5_real64,'inq')
  call chk(inqdra(madr,macp),0.004_real64,'inqdra')
  call chk(cgrai,1.1_real64,'cgrai'); call chk(cqdrain(madr),0.12_real64,'cqdrain')
  call chk(imdectot,1.0_real64,'imdectot'); call chk(imsqprec,6.0_real64,'imsqprec')
  call chk(imqsol(macp+1),real(macp+1,real64)*4.e-5_real64,'imqsol')
  call chk(sbaldev,7.0_real64,'sbaldev'); call chk(samini,17.0_real64,'samini'); call chk(isqtop,18.0_real64,'isqtop')

  print *, 'FCI08_LEGACY_TRIAL_CAPSULE PASS'
contains
  subroutine chk(a,b,label)
    real(real64),intent(in)::a,b
    character(len=*),intent(in)::label
    if(abs(a-b)>1.e-12_real64) then
      print *,trim(label),a,b
      error stop 'FCI08 capsule comparison'
    end if
  end subroutine chk
end program test_fci08_legacy_trial_capsule
