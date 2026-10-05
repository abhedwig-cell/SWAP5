program test_migmac03
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan
  use mod_macropore_dynamic_shrinkage
  implicit none
  type(peat_shrinkage_t)::p,bad
  type(dynamic_shrinkage_config_t)::c
  real(real64)::shrink,low,high,nan
  real(real64),allocatable::a(:),b(:),again(:),subs(:)
  logical::ok
  integer::i
  real(real64),parameter::theta(6)=[0.0_real64,0.1_real64,0.2_real64,0.3_real64,0.4_real64,0.5_real64]
  ! Decimal 60-digit evaluation of the source formula; these are fixed independent values.
  real(real64),parameter::expected(6)=[0.4_real64,0.301700861174006611252298123246_real64, &
       0.223668533461811313638610853592_real64,0.16_real64,0.08_real64,0.0_real64]
  p%void_ratio_zero=0.2_real64;p%transition_moisture_ratio=0.6_real64
  p%alpha=1.2_real64;p%beta=3.0_real64;p%p=0.1_real64
  do i=1,6
    call evaluate_peat_shrinkage_fraction(theta(i),0.5_real64,p,SHRINK_PEAT_DIRECT,shrink,ok)
    call check(ok,'direct valid')
    call check(abs(shrink-expected(i))<2.0e-14_real64,'Hendriks independent decimal oracle')
  end do
  call evaluate_peat_shrinkage_fraction(0.3_real64-1.0e-10_real64,0.5_real64,p,SHRINK_PEAT_DIRECT,low,ok)
  call check(ok,'transition left')
  call evaluate_peat_shrinkage_fraction(0.3_real64+1.0e-10_real64,0.5_real64,p,SHRINK_PEAT_DIRECT,high,ok)
  call check(ok .and. abs(high-low)<1.0e-8_real64,'Hendriks continuity')
  p%intermediate_moisture_ratio=0.2_real64;p%intermediate_void_ratio=0.4_real64
  call evaluate_peat_shrinkage_fraction(0.05_real64,0.5_real64,p,SHRINK_PEAT_SEGMENTS,shrink,ok)
  call check(ok .and. abs(shrink-0.35_real64)<1.0e-14_real64,'lower segment')
  call evaluate_peat_shrinkage_fraction(0.2_real64,0.5_real64,p,SHRINK_PEAT_SEGMENTS,shrink,ok)
  call check(ok .and. abs(shrink-0.23_real64)<1.0e-14_real64,'middle segment')
  call evaluate_peat_shrinkage_fraction(0.4_real64,0.5_real64,p,SHRINK_PEAT_SEGMENTS,shrink,ok)
  call check(ok .and. abs(shrink-0.08_real64)<1.0e-14_real64,'upper segment')
  do i=1,2
    low=0.1_real64
    if(i==2)low=0.3_real64
    call evaluate_peat_shrinkage_fraction(low-1.0e-10_real64,0.5_real64,p,SHRINK_PEAT_SEGMENTS,shrink,ok)
    call check(ok,'piecewise transition left')
    call evaluate_peat_shrinkage_fraction(low+1.0e-10_real64,0.5_real64,p,SHRINK_PEAT_SEGMENTS,high,ok)
    call check(ok .and. abs(high-shrink)<1.0e-8_real64,'piecewise continuity')
  end do
  nan=ieee_value(0.0_real64,ieee_quiet_nan)
  bad=p;bad%beta=bad%alpha
  call evaluate_peat_shrinkage_fraction(0.1_real64,0.5_real64,bad,SHRINK_PEAT_DIRECT,shrink,ok)
  call check(.not.ok,'degenerate denominator rejected')
  bad=p;bad%p=nan
  call evaluate_peat_shrinkage_fraction(0.1_real64,0.5_real64,bad,SHRINK_PEAT_DIRECT,shrink,ok)
  call check(.not.ok,'NaN parameter rejected')
  bad=p;bad%intermediate_moisture_ratio=0.6_real64
  call evaluate_peat_shrinkage_fraction(0.1_real64,0.5_real64,bad,SHRINK_PEAT_SEGMENTS,shrink,ok)
  call check(.not.ok,'zero segment width rejected')
  call evaluate_peat_shrinkage_fraction(nan,0.5_real64,p,SHRINK_PEAT_DIRECT,shrink,ok)
  call check(.not.ok,'NaN moisture rejected')
  c%enabled=.true.;c%surface_crack_area_node_supplied=.true.
  c%theta_s=[0.5_real64,0.5_real64,0.5_real64]
  c%theta_crack=[0.3_real64,0.3_real64,0.3_real64]
  c%geometry_factor=[3.0_real64,3.0_real64,3.0_real64]
  c%law=[SHRINK_RIGID,SHRINK_PEAT_DIRECT,SHRINK_PEAT_SEGMENTS];c%peat=[p,p,p]
  call derive_dynamic_minimum_subsidence(c,[10.0_real64,10.0_real64,10.0_real64],ok)
  call check(ok .and. c%minimum_subsidence_cm(1)==0.0_real64,'rigid minimum subsidence defined')
  call check(c%valid_for_nodes(3),'mixed peat/rigid config without Kim')
  call evaluate_dynamic_crack_profile(c,[0.1_real64,0.1_real64,0.1_real64], &
       [0.4_real64,0.4_real64,0.4_real64],[10.0_real64,10.0_real64,10.0_real64], &
       [0.9_real64,0.9_real64,0.9_real64],[0.0_real64,0.0_real64,0.0_real64],a,ok,subs)
  call check(ok .and. a(1)==0.0_real64 .and. subs(1)==0.0_real64,'rigid geometry zero')
  call check(all(a(2:)>0.0_real64),'peat dry growth')
  call evaluate_dynamic_crack_profile(c,[0.49_real64,0.49_real64,0.49_real64], &
       [0.1_real64,0.1_real64,0.1_real64],[10.0_real64,10.0_real64,10.0_real64], &
       [0.9_real64,0.9_real64,0.9_real64],a,b,ok)
  call check(ok .and. all(b(2:)<a(2:)),'peat wet contraction')
  call evaluate_dynamic_crack_profile(c,[0.1_real64,0.1_real64,0.1_real64], &
       [0.4_real64,0.4_real64,0.4_real64],[10.0_real64,10.0_real64,10.0_real64], &
       [0.9_real64,0.9_real64,0.9_real64],[0.0_real64,0.0_real64,0.0_real64],again,ok)
  call check(ok .and. all(transfer(again,[0_int64],3)==transfer(a,[0_int64],3)),'mixed A/B/A')
  c%law=SHRINK_RIGID
  call evaluate_dynamic_crack_profile(c,[0.1_real64,0.1_real64,0.1_real64], &
       [0.4_real64,0.4_real64,0.4_real64],[10.0_real64,10.0_real64,10.0_real64], &
       [0.9_real64,0.9_real64,0.9_real64],a,b,ok,subs)
  call check(ok .and. all(b==0.0_real64) .and. all(subs==0.0_real64),'all rigid closes accepted cracks')
  call evaluate_dynamic_crack_profile(c,[0.1_real64,0.1_real64,0.1_real64], &
       [nan,0.4_real64,0.4_real64],[10.0_real64,10.0_real64,10.0_real64], &
       [0.9_real64,0.9_real64,0.9_real64],a,b,ok)
  call check(.not.ok,'rigid cannot hide invalid accepted history')
  call evaluate_dynamic_crack_profile(c,[0.1_real64,0.1_real64,0.1_real64], &
       [0.4_real64,0.4_real64,0.4_real64],[10.0_real64,10.0_real64,10.0_real64], &
       [0.9_real64,0.9_real64,0.9_real64],[0.0_real64],b,ok)
  call check(.not.ok .and. size(b)==3,'history shape rejection preserves output shape')
  c%law(2)=99
  call check(.not.c%valid_for_nodes(3),'unsupported law fails closed')
  print '(a)','PPA_WU05_MIGMAC03_CONSTITUTIVE_ORACLES=PASS'
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
