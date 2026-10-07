program test_swap431_drain_multilevel
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_drain, only: DIVDRA, legacy_qdra=>qdra, legacy_qdrain=>qdrain, legacy_spacing=>Lspacing, legacy_aniso=>cofani
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t
  use mod_drainage_multilevel_distribution, only: drainage_multilevel_diagnostics_t, &
       distribute_multilevel_signed_divdra, DRAIN_MULTI_OK
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  implicit none
  type(drainage_distribution_parameters_t)::p
  type(process_hydraulic_view_t)::h
  type(drainage_multilevel_diagnostics_t)::d
  real(real64),allocatable::got(:,:)
  real(real64)::k(8),q(3),spacing(3),gwl,err
  integer::i,c
  p%active_nodes=8
  allocate(p%dz(8),p%zbotcp(8),p%saturated_conductivity(8),p%horizontal_anisotropy_factor(8))
  p%dz=1._real64;p%zbotcp=[(-real(i,real64),i=1,8)]
  k=[1._real64,4._real64,1._real64,4._real64,1._real64,4._real64,1._real64,4._real64]
  p%saturated_conductivity=k
  h%active_nodes=8;allocate(h%pressure_head(8),h%water_content(8));h%pressure_head=0._real64;h%water_content=.4_real64

  do c=1,5
    select case(c)
    case(1);gwl=-.3_real64;q=[.03_real64,.02_real64,.01_real64];spacing=[30._real64,12._real64,5._real64];p%horizontal_anisotropy_factor=1._real64
    case(2);gwl=-1.4_real64;q=[-.03_real64,.02_real64,-.01_real64];spacing=[30._real64,12._real64,5._real64];p%horizontal_anisotropy_factor=1.7_real64
    case(3);gwl=-2.2_real64;q=[.01_real64,0._real64,-.04_real64];spacing=[8._real64,40._real64,15._real64];p%horizontal_anisotropy_factor=.65_real64
    case(4);gwl=-.9_real64;q=[-.012_real64,-.007_real64,.025_real64];spacing=[7._real64,7._real64,22._real64];p%horizontal_anisotropy_factor=1.25_real64
    case(5);gwl=-3.1_real64;q=[.002_real64,-.003_real64,.004_real64];spacing=[4._real64,9._real64,17._real64];p%horizontal_anisotropy_factor=[.8_real64,1.3_real64,.8_real64,1.3_real64,.8_real64,1.3_real64,.8_real64,1.3_real64]
    end select
    p%drain_spacing=spacing(1);h%groundwater_level=gwl
    legacy_qdrain=q;legacy_spacing=spacing
    if(c/=5)then
      legacy_aniso=p%horizontal_anisotropy_factor(1)
    else
      ! Legacy owner has layer-based anisotropy: case 5 uses alternating layer values.
      legacy_aniso=[.8_real64,1.3_real64]
    end if
    legacy_qdra=0._real64
    call DIVDRA(k,gwl)
    call distribute_multilevel_signed_divdra(p,h,q,spacing,got,d)
    call require(d%status==DRAIN_MULTI_OK.and.d%evaluated,'typed accepted')
    err=maxval(abs(got-legacy_qdra))
    call require(err<2.e-13_real64,'source parity')
    do i=1,3
      call require(abs(sum(got(i,:))-q(i))<2.e-13_real64,'row mass closure')
    end do
    write(*,'(A,I0,A,ES12.4)')'SW431_MULTI_CASE=',c,' ERR=',err
    deallocate(got)
  end do
  print '(A)','SW431_DRAIN_DIV_MULTI_SOURCE_PARITY=PASS'
  print '(A)','SW431_DRAIN_DIV_MULTI_MASS=PASS'
contains
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      write(*,'(A,1X,A)')'SW431_MULTI_FAIL',trim(label);error stop 81
    end if
  end subroutine
end program
