program inf_guards
  use, intrinsic::iso_fortran_env,only:real64
  use, intrinsic::ieee_arithmetic,only:ieee_value,ieee_quiet_nan,ieee_positive_inf
  use mod_drainage_spatial_distribution,only:drainage_distribution_parameters_t
  use mod_process_hydraulic_view,only:process_hydraulic_view_t
  use mod_drainage_b19_separate_infiltration_adapter
  use mod_fmr_divdra_separate_infiltration_binding
  implicit none
  type(drainage_distribution_parameters_t)::p(2),bad(2)
  type(drainage_b19_separate_infiltration_parameters_t)::c(2),bc(2)
  type(process_hydraulic_view_t)::v,bv
  type(fmr_divdra_separate_infiltration_binding_diagnostics_t)::d
  real(real64),allocatable::f(:,:)
  real(real64)::q(2),bq(2)
  integer::i,j
  do i=1,2
    p(i)%active_nodes=2;p(i)%dz=[1.d0,1.d0];p(i)%zbotcp=[-1.d0,-2.d0]
    p(i)%saturated_conductivity=[2.d0,2.d0];p(i)%horizontal_anisotropy_factor=[1.d0,1.d0]
    p(i)%drain_spacing=4.d0
  end do
  v%groundwater_level=-.5d0;q=[-.003d0,.002d0]
  c%drain_level_cm=0;c%infiltration_depth_factor=.5d0
  do j=1,14
    bad=p;bc=c;bv=v;bq=q
    select case(j)
    case(1);deallocate(bad(1)%dz)
    case(2);bad(2)%zbotcp=[-1.d0]
    case(3);bad(1)%saturated_conductivity(1)=ieee_value(0.d0,ieee_quiet_nan)
    case(4);bad(1)%horizontal_anisotropy_factor(1)=ieee_value(0.d0,ieee_positive_inf)
    case(5);bad(1)%drain_spacing=ieee_value(0.d0,ieee_quiet_nan)
    case(6);bad(1)%dz(1)=0
    case(7);bv%groundwater_level=ieee_value(0.d0,ieee_quiet_nan)
    case(8);bq(1)=ieee_value(0.d0,ieee_quiet_nan)
    case(9);bq(1)=-1.d-10
    case(10);bc(2)%infiltration_depth_factor=2
    case(11);bc(1)%drain_level_cm=ieee_value(0.d0,ieee_quiet_nan)
    case(12);bc(1)%drain_level_cm=-1.5d0 ! negative rate against channel/GWL geometry
    case(13);bad(2)%saturated_conductivity(1)=3 ! different column conductivity ownership
    case(14);bv%groundwater_level=-1.d0-5.d-11 ! negative top thickness inside offset
    end select
    call fmr_bind_separate_infiltration(bad,bv,bq,bc,f,d)
    call require(.not.d%published.and..not.allocated(f),'invalid unpublished')
  end do
  call fmr_bind_separate_infiltration(p,v,q,c(:1),f,d)
  call require(.not.d%published.and..not.allocated(f),'control shape')
  call fmr_bind_separate_infiltration(p(:1),v,q,c,f,d)
  call require(.not.d%published.and..not.allocated(f),'rate shape')
  allocate(f(2,2));f=123
  call fmr_bind_separate_infiltration(p,v,q,c,f,d)
  call require(d%status==FMR_DIVDRA_INF_SPLIT_TARGET_ALREADY_BOUND.and.all(f==123),'target nonmutation')
  print '(A)','INF_SPLIT_GUARDS=PASS'
contains
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(*),intent(in)::label
    if(.not.ok)then
      print *,label
      error stop 1
    end if
  end subroutine
end program
