program test_mixed
  use, intrinsic :: iso_fortran_env,only:real64,int64
  use mod_macropore_dynamic_shrinkage
  implicit none
  type(dynamic_shrinkage_config_t)::c
  type(clay_kim_shrinkage_t)::kim
  type(peat_shrinkage_t)::peat
  real(real64)::kd,kd_a,kd_b
  real(real64)::zz(4)=[-5.0_real64,-15.0_real64,-25.0_real64,-35.0_real64]
  real(real64)::fraction(4)=[1.0_real64,0.5_real64,0.3_real64,0.7_real64]
  real(real64)::static(4)=[1.0_real64,1.0_real64,1.0_real64,1.0_real64]
  real(real64)::diam(4)=[4.0_real64,4.0_real64,4.0_real64,4.0_real64]
  logical::ok
  real(real64),parameter::dz(4)=[10.0_real64,10.0_real64,10.0_real64,10.0_real64]
  real(real64),parameter::dry_theta(4)=[0.1_real64,0.1_real64,0.1_real64,0.1_real64]
  real(real64),parameter::wet_theta(4)=[0.49_real64,0.49_real64,0.49_real64,0.49_real64]
  call prepare_clay_kim_option1(0.5_real64,0.2_real64,2.0_real64,1.2_real64,kim,ok)
  call check(ok,'Kim initialized')
  peat%void_ratio_zero=0.2_real64;peat%transition_moisture_ratio=0.6_real64
  peat%alpha=1.2_real64;peat%beta=3.0_real64;peat%p=0.1_real64
  peat%intermediate_moisture_ratio=0.2_real64;peat%intermediate_void_ratio=0.4_real64
  c%enabled=.true.;c%surface_crack_area_node_supplied=.true.;c%surface_crack_area_node=2
  c%theta_s=[0.5_real64,0.5_real64,0.5_real64,0.5_real64]
  c%theta_crack=[0.3_real64,0.3_real64,0.3_real64,0.3_real64]
  c%geometry_factor=[3.0_real64,3.0_real64,3.0_real64,3.0_real64]
  c%law=[SHRINK_RIGID,SHRINK_KIM,SHRINK_PEAT_DIRECT,SHRINK_PEAT_SEGMENTS]
  c%kim=[kim,kim,kim,kim];c%peat=[peat,peat,peat,peat]
  call derive_dynamic_minimum_subsidence(c,dz,ok)
  call check(ok .and. c%valid_for_nodes(4),'mixed config valid')
  call evaluate_reference(-40.0_real64,-40.0_real64,2,dry_theta,kd_a)
  call check(abs(kd_a-0.206815483619374335222650_real64)<1.0e-13_real64,'independent Decimal mixed KD')
  call evaluate_reference(-40.0_real64,-10.0_real64,2,dry_theta,kd)
  call check(abs(kd-0.300877703805948277300411_real64)<1.0e-13_real64,'independent all-law reference KD')
  call evaluate_reference(-40.0_real64,-40.0_real64,2,wet_theta,kd_b)
  call check(kd_b<kd_a,'wet hydrostatic reference smaller KD')
  call evaluate_reference(-40.0_real64,-40.0_real64,2,dry_theta,kd)
  call check(transfer(kd,0_int64)==transfer(kd_a,0_int64),'reference A/B/A exact')
  call check(all(c%law==[SHRINK_RIGID,SHRINK_KIM,SHRINK_PEAT_DIRECT,SHRINK_PEAT_SEGMENTS]),'immutable law config')
  ! The inclusive source barrier scan includes the static-bottom node.
  c%law(2)=SHRINK_RIGID
  call evaluate_reference(-20.0_real64,-40.0_real64,1,dry_theta,kd)
  call check(kd==0.0_real64,'tube isolated by rigid layer')
  call evaluate_reference(-20.0_real64,-40.0_real64,2,dry_theta,kd)
  call check(kd>0.0_real64,'open drain remains connected above barrier')
  c%law(2)=SHRINK_KIM
  call evaluate_reference(-20.0_real64,-40.0_real64,2,c%theta_s,kd)
  call check(kd>0.0_real64,'source 0.99 saturation cap valid')
  ! Same node under the legacy 0.01 cm lower-face tolerance.
  call evaluate_reference(-40.0_real64,-20.005_real64,2,dry_theta,kd_a)
  call evaluate_reference(-40.0_real64,-20.0_real64,2,dry_theta,kd_b)
  call check(kd_a==kd_b,'source node tolerance mapping')
  call prepare_rapid_drain_reference_kd(c,zz,dz,dry_theta,static,fraction,diam, &
       -40.0_real64,-41.0_real64,2,3.0_real64,kd,ok)
  call check(.not.ok.and.kd==0.0_real64,'out of grid fails closed')
  call prepare_rapid_drain_reference_kd(c,zz,dz,dry_theta(:3),static,fraction,diam, &
       -40.0_real64,-40.0_real64,2,3.0_real64,kd,ok)
  call check(.not.ok,'shape invalid fails closed')
  fraction(3)=2.0_real64
  call prepare_rapid_drain_reference_kd(c,zz,dz,dry_theta,static,fraction,diam, &
       -40.0_real64,-40.0_real64,2,3.0_real64,kd,ok)
  call check(.not.ok,'invalid fraction fails closed')
  print '(a)','PPA_WU05_MIGMAC06_INDEPENDENT_REFERENCE_KD=PASS'
contains
  subroutine evaluate_reference(sb,dr,typ,theta,value)
    real(real64),intent(in)::sb,dr,theta(:)
    integer,intent(in)::typ
    real(real64),intent(out)::value
    call prepare_rapid_drain_reference_kd(c,zz,dz,theta,static,fraction,diam,sb,dr,typ,3.0_real64,value,ok)
    call check(ok,'reference preparation valid')
  end subroutine evaluate_reference
  subroutine check(condition,label)
    logical,intent(in)::condition
    character(*),intent(in)::label
    if(.not.condition)then
      print '(a)',label
      error stop 1
    end if
  end subroutine
end program
