program test_mixed
  use, intrinsic :: iso_fortran_env,only:real64,int64
  use mod_macropore_dynamic_shrinkage
  implicit none
  type(dynamic_shrinkage_config_t)::c
  type(clay_kim_shrinkage_t)::kim
  type(peat_shrinkage_t)::peat
  real(real64)::accepted(4),saved(4)
  real(real64),allocatable::dry(:),wet(:),replay(:),subs(:)
  logical::ok
  real(real64),parameter::dz(4)=[10.0_real64,10.0_real64,10.0_real64,10.0_real64]
  real(real64),parameter::area(4)=[0.9_real64,0.85_real64,0.8_real64,0.95_real64]
  real(real64),parameter::dry_theta(4)=[0.1_real64,0.1_real64,0.1_real64,0.1_real64]
  real(real64),parameter::wet_theta(4)=[0.49_real64,0.49_real64,0.49_real64,0.49_real64]
  ! Independent Decimal values of each law and geometry at these exact inputs.
  real(real64),parameter::expected(4)=[0.0_real64,1.200284951087133242959040_real64, &
       1.349532011181015345259982_real64,1.583333333333333333333333_real64]
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
  accepted=0.0_real64;saved=accepted
  call evaluate_dynamic_crack_profile(c,dry_theta,wet_theta,dz,area,accepted,dry,ok,subs)
  call check(ok .and. maxval(abs(dry-expected))<1.0e-13_real64,'independent mixed geometry values')
  call check(all(transfer(accepted,[0_int64],4)==transfer(saved,[0_int64],4)),'dry trial preserves accepted history')
  accepted=dry;saved=accepted
  call evaluate_dynamic_crack_profile(c,wet_theta,dry_theta,dz,area,accepted,wet,ok)
  call check(ok .and. all(abs(wet)<1.0e-14_real64),'wetting closes all mixed cracks')
  call check(all(transfer(accepted,[0_int64],4)==transfer(saved,[0_int64],4)),'wet trial preserves accepted history')
  call evaluate_dynamic_crack_profile(c,dry_theta,wet_theta,dz,area,accepted,replay,ok)
  call check(ok .and. all(transfer(dry,[0_int64],4)==transfer(replay,[0_int64],4)),'mixed A/B/A geometry identity')
  call evaluate_dynamic_crack_profile(c,dry_theta,wet_theta,dz,area,accepted,replay,ok,active_node=2)
  call check(ok .and. all(abs(replay(3:))<1.0e-14_real64),'cutoff crosses peat law interface')
  c%law(3)=99
  call evaluate_dynamic_crack_profile(c,dry_theta,wet_theta,dz,area,accepted,replay,ok)
  call check(.not.ok,'invalid law fails composite trial closed')
  call check(all(transfer(accepted,[0_int64],4)==transfer(saved,[0_int64],4)),'invalid composite leaves accepted authority')
  print '(a)','PPA_WU05_MIGMAC05_MIXED_INDEPENDENT_GEOMETRY=PASS'
  print '(a,4es24.16)','PPA_WU05_MIGMAC05_DRY_CAPACITY_CM=',dry
contains
  subroutine check(condition,label)
    logical,intent(in)::condition
    character(*),intent(in)::label
    if(.not.condition)then
      print '(a)',label
      error stop 1
    end if
  end subroutine
end program
